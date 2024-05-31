#!/bin/bash -x
# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

source ./_workshop-conf.sh

## Variables
REGION=$(aws ec2 describe-availability-zones --output text --query 'AvailabilityZones[0].[RegionName]')
REPO_DESCRIPTION="SaaS Operations architecture repository"
REPO_PATH="/home/ec2-user/environment/${REPO_NAME}"
REPO_URL="codecommit::${REGION}://${REPO_NAME}"

## Dependencies
install_dependencies() {
    echo "Installing dependencies"
    echo "Enabling yarn"
    corepack enable || retry npm install --global yarn
    echo "yarn enabled"
    echo "Installing isolation test packages"
    cd ${REPO_PATH}/App/isolation-test/
    retry npm install
    echo "Isolation test packages installed"
    echo "Installing artillery"
    retry npm install -g artillery
    echo "Installed artillery"
    echo "Dependencies installed"
}

# Create CodeCommit repository
create_codecommit() {
    echo "Creating CodeCommit repository"
    cd ${REPO_PATH}
    git init -b main
    git config --global --add safe.directory ${REPO_PATH}
    git add -A
    git commit -m "Base code"
    if ! aws codecommit get-repository --repository-name ${REPO_NAME}
    then
        echo "${REPO_NAME} codecommit repo is not present, will create one now"
        CREATE_REPO=$(aws codecommit create-repository --repository-name ${REPO_NAME} --repository-description "${REPO_DESCRIPTION}")
        echo "${CREATE_REPO}"
    fi
    if ! git remote add cc "${REPO_URL}"
    then
        echo "Setting url to remote cc"
        git remote set-url cc "${REPO_URL}"
    fi
    git push cc "$(git branch --show-current)":main
    echo "CodeCommit repository created"
}

# Deploy tenant pipeline
create_tenant_pipeline() {
    echo "Deploying tenant pipeline"
    cd ${REPO_PATH}/App/server/TenantPipeline || exit 
    retry npm install
    npm run build
    cdk bootstrap
    cdk deploy --require-approval never
    echo "Tenant pipeline deployed"
}

# Create application
create_bootstrap() {
    echo "Deploying application"
    cd ${REPO_PATH}/App/server
    DEFAULT_SAM_S3_BUCKET=$(grep s3_bucket samconfig-bootstrap.toml | cut -d'=' -f2 | cut -d \" -f2)
    if ! aws s3 ls "s3://${DEFAULT_SAM_S3_BUCKET}"
    then
        echo "S3 Bucket: ${DEFAULT_SAM_S3_BUCKET} specified in samconfig-bootstrap.toml is not readable."
        echo "So creating a new S3 bucket and will update samconfig-bootstrap.toml with new bucket name."
        UUID=$(uuidgen | awk '{print tolower($0)}')
        SAM_S3_BUCKET=sam-bootstrap-bucket-${UUID}
        aws s3 mb "s3://${SAM_S3_BUCKET}" --region "${REGION}"
        aws s3api put-bucket-encryption \
            --bucket "${SAM_S3_BUCKET}" \
            --server-side-encryption-configuration '{"Rules": [{"ApplyServerSideEncryptionByDefault": {"SSEAlgorithm": "AES256"}}]}'
        if [[ $? -ne 0 ]]
        then
            echo "bootstrap bucket deployment failed"
            exit 1
        fi
        # Update samconfig-bootstrap.toml with new bucket name
        ex -sc '%s/s3_bucket = .*/s3_bucket = \"'"${SAM_S3_BUCKET}"'\"/|x' samconfig-bootstrap.toml
    fi
    sam build -t bootstrap-template.yaml --use-container --region="$REGION"
    sam deploy --config-file samconfig-bootstrap.toml --region="$REGION" --no-confirm-changeset
    if [[ $? -ne 0 ]]
    then
        echo "Error! bootstrap-template.yaml deploy failed"
        exit 1
    fi
    echo "Application deployed"
}

# Deploy dashboards
deploy_dashboards() {
    echo "Deploying dashboards"
    cd ${REPO_PATH}/App/server/dashboards
    ./deploy.sh
    echo "Dashboards deployed"
}

create_tenant() {
    ADMIN_APIGATEWAYURL=$1
    TENANT_NAME=$2
    TENANT_EMAIL=$3
    TENANT_TIER=$4
    data=$(cat <<EOF
{
    "tenantName": "${TENANT_NAME}",
    "tenantEmail": "${TENANT_EMAIL}",
    "tenantTier": "${TENANT_TIER}",
    "tenantPhone": null,
    "tenantAddress": null
}
EOF
    )
    REQUEST=$(curl -X POST -H 'Content-type:application/json' --data "$data" "${ADMIN_APIGATEWAYURL}registration")
    echo $REQUEST
}

create_tenants() {
    echo "Creating tenants"
    basicTenants=("PooledTenant1" "PooledTenant2" "PooledTenant3" "PooledTenant4" "BasicTestTenant1" "BasicTestTenant2")
    for i in "${basicTenants[@]}"
    do
        create_tenant $ADMIN_APIGATEWAYURL $i "success+$i@simulator.amazonses.com" Basic
    done

    platinumTenants=("SiloedTenant1" "PlatinumTestTenant")
    for i in "${platinumTenants[@]}"
    do
        create_tenant $ADMIN_APIGATEWAYURL $i "success+$i@simulator.amazonses.com" Platinum
    done
    echo "Tenants created"
}

create_tenant_users() {
    echo "Creating tenant users"
    TENANTS=("SiloedTenant1" "PooledTenant1" "PooledTenant2" "PooledTenant3" "PooledTenant4")
    for tenant in ${TENANTS[@]}; do
        TENANTUSERPOOL=$(curl "${ADMIN_APIGATEWAYURL}/tenant/init/${tenant}" | jq -r '.userPoolId')
        TENANTID=$(aws cognito-idp list-users --user-pool-id $TENANTUSERPOOL | jq -r --arg id "${tenant}@" '.Users[] | select(.Attributes[] | .Value | contains($id)) | .Attributes[] | select(.Name == "custom:tenantId") | .Value')

        USERSCOUNT=$((1 + $RANDOM % 50))
        for (( i=1 ; i<=${USERSCOUNT} ; i++ )); 
            do
            USERPREFIX=$(date +%s)
            aws cognito-idp admin-create-user \
                --user-pool-id ${TENANTUSERPOOL} \
                --username success+${tenant}_user_${USERPREFIX}@simulator.amazonses.com  \
                --user-attributes Name=email,Value=success+${tenant}_user_${USERPREFIX}@simulator.amazonses.com Name=email_verified,Value=true Name=custom:tenantId,Value=${TENANTID} Name=custom:userRole,Value=TenantUser 1> /dev/null 

            sleep 1
        done
    done
    echo "Tenant users created"
}

execute_pipeline() {
    # Start CI/CD pipeline which loads tenant stack
    echo "Starting CI/CD pipeline"
    PIPELINE_EXECUTION_ID=$(aws codepipeline start-pipeline-execution --name saas-operations-pipeline | jq -r '.pipelineExecutionId')
    ADMIN_APIGATEWAYURL=$(aws cloudformation list-exports --query "Exports[?Name=='SaaS-Operations-AdminApiGatewayUrl'].Value" --output text)
    echo "Finished CI/CD pipeline"
}

## Create SaaS application
echo "Creating workshop"
install_dependencies
create_codecommit
create_tenant_pipeline &
create_bootstrap &
deploy_dashboards &
wait_for_background_jobs
execute_pipeline
create_tenants
create_tenant_users
echo "Success - Workshop created!"
