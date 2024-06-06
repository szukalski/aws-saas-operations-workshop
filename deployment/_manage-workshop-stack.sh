#!/bin/bash -x
# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

create_workshop() {
    bootstrap_cdk
    cd cloud9
    echo "Starting Cloud9 cdk deploy..."
    cdk deploy --all --require-approval never --context "workshop=$WORKSHOP_NAME"
    echo "Done Cloud9 cdk deploy!"

    get_c9_id
    echo "Waiting for " $C9_ID
    aws ec2 start-instances --instance-ids "$C9_ID"
    aws ec2 wait instance-status-ok --instance-ids "$C9_ID"
    echo $C9_ID "ready"

    replace_instance_profile $BUILD_C9_INSTANCE_PROFILE_PARAMETER_NAME
    run_ssm_command "cd ~/environment ; git clone --branch $REPO_BRANCH_NAME $REPO_URL || echo 'Repo already exists.'"
    run_ssm_command "cd ~/environment/$REPO_NAME/deployment && ./create-workshop.sh $REPO_URL | tee .ws-create.log"

    replace_instance_profile $PARTICIPANT_C9_INSTANCE_PROFILE_PARAMETER_NAME
}

delete_workshop() {
    get_c9_id
    aws ec2 create-tags --resources $C9_ID --tags "Key=Workshop,Value=${WORKSHOP_NAME}Old"
    echo "Deleting workshop"

    TRAILS=( "saas-ops-ddb-access-trails" "saas-ops-management-trails" )
    STACKS_1=()
    STACKS_2=( "saas-operations-controlplane" "saas-operations-pipeline" "saasOpsWorkshop-saasOperationsDashboard" "${WORKSHOP_NAME}-C9")
    CODECOMMIT_REPOS=( "saas-operations-workshop" )

    for TRAIL in "${TRAILS[@]}"; do
        stop_cloudtrail "${TRAIL}"
    done
    delete_tenant_stacks
    delete_buckets
    for STACK in "${STACKS_1[@]}"; do
        delete_stack "${STACK}"
    done
    for STACK in "${STACKS_2[@]}"; do
        delete_stack "${STACK}" &
    done
    wait_for_background_jobs
    for REPO in "${CODECOMMIT_REPOS[@]}"; do
        delete_codecommit_repo "${REPO}" &
    done
    delete_log_groups &
    delete_user_pools &
    delete_api_keys &
    wait_for_background_jobs

    echo "Workshop deleted"
}
