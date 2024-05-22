#!/bin/bash -x
# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

# Per workshop variables
WORKSHOP="SaaSOps"
REPONAME=$(echo $REPO_URL||sed 's#.*/##'|sed 's/\.git//')
CDK_VERSION="2.142.1"

# Static variables
C9_ATTR_ARN_PARAMETER_NAME="/"$WORKSHOP"/Cloud9/AttrArn"
C9_INSTANCE_PROFILE_PARAMETER_NAME="/"$WORKSHOP"/Cloud9/InstanceProfileName"
TARGET_USER="ec2-user"
CDK_C9_STACK=$WORKSHOP"-Cloud9Stack"
ARTILLERY_VERSION="2.0.7"
TARGET_USER="ec2-user"

manage_workshop_stack() {
    STACK_OPERATION=$(echo "$1" | tr '[:upper:]' '[:lower:]')

    npm install --force --global aws-cdk@$CDK_VERSION

    cd workshop-deployment/cloud9
    npm install
    cdk bootstrap

    if [[ "$STACK_OPERATION" == "create" || "$STACK_OPERATION" == "update" ]]; then
        echo "Starting cdk deploy..."
        cdk deploy $CDK_C9_STACK \
            --require-approval never
        echo "Done cdk deploy!"
    fi

    C9_ENV_ID=$(aws ssm get-parameter \
        --name "$C9_ATTR_ARN_PARAMETER_NAME" \
        --output text \
        --query "Parameter.Value"|cut -d ":" -f 7)
    C9_ID=$(aws ec2 describe-instances \
        --filter "Name=tag:aws:cloud9:environment,Values=$C9_ENV_ID" \
        --query 'Reservations[].Instances[].{Instance:InstanceId}' \
        --output text)
    C9_INSTANCE_PROFILE_NAME=$(aws ssm get-parameter \
        --name "$C9_INSTANCE_PROFILE_PARAMETER_NAME" \
        --output text \
        --query "Parameter.Value")

    if [[ "$STACK_OPERATION" == "create" ]]; then
        aws ec2 start-instances --instance-ids "$C9_ID"
        aws ec2 wait instance-status-ok --instance-ids "$C9_ID"
        echo $C9_ID "ready"
        replace_instance_profile
        run_ssm_command "cd ~/environment ; git clone --branch $REPO_BRANCH_NAME $REPO_URL || echo 'Repo already exists.'"
        run_ssm_command "rm -vf ~/.aws/credentials"
        run_ssm_command "npm install --force --global artillery@$ARTILLERY_VERSION"
        run_ssm_command "cd ~/environment/$REPONAME/workshop-deployment/cloud9 && ./resize-cloud9-ebs-vol.sh"
        run_ssm_command "cd ~/environment/$REPONAME/workshop-deployment && ./deploy-saas-application.sh"
    elif [ "$STACK_OPERATION" == "delete" ]; then

        if [[ "$C9_ID" != "None" ]]; then
            aws ec2 start-instances --instance-ids "$C9_ID"
            wait_for_instance_ssm "$C9_ID"
            run_ssm_command "cd ~/environment/$REPONAME/workshop-deployment && ./destroy-saas-application.sh"
        else
            cd ..
            ./destroy-saas-application.sh
            cd cloud9
        fi

        echo "Starting cdk destroy..."
        cdk destroy --all --force
        echo "Done cdk destroy!"

        echo "Deleting code build log group"
        aws logs delete-log-group --log-group-name "/aws/codebuild/install-workshop-stack-codebuild"
        echo "Deleted code build log group"
    else
        echo "Invalid stack operation!"
        exit 1
    fi
}
