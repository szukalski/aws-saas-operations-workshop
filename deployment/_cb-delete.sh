#!/bin/bash -x
# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

delete_workshop() {
    bootstrap_cdk
    get_c9_id
    if [[ "$C9_ID" != "None" ]]; then
        aws ec2 start-instances --instance-ids "$C9_ID"
        wait_for_instance_ssm "$C9_ID"
        # run_ssm_command "cd ~/environment/$REPO_NAME/deployment && ./delete-workshop.sh -s | tee .workshop.out"
        ./delete-workshop.sh -s
    else
        cd ..
        ./delete-workshop.sh -s
        cd cloud9
    fi
    
    aws ec2 create-tags --resources $C9_ID --tags "Key=Workshop,Value=${WORKSHOP_NAME}Old"
    cd cloud9
    echo "Starting cdk destroy..."
    cdk destroy --all --force --context "workshop=$WORKSHOP_NAME"
    echo "Done cdk destroy!"
}
