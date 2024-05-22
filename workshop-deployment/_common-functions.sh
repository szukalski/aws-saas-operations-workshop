#!/bin/bash -x
# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

function retry {
  local n=1
  local max=3
  local delay=10
  while true; do
    "$@" && break || {
      if [[ $n -lt $max ]]; then
        ((n++))
        echo "Command failed. Attempt $n/$max:"
        sleep $delay;
      else
        echo "The command has failed after $n attempts."
        exit 1
      fi
    }
  done
}

run_ssm_command() {
    SSM_COMMAND="$1"
    parameters=$(jq -n --arg cm "runuser -l \"$TARGET_USER\" -c \"$SSM_COMMAND\"" '{executionTimeout:["3600"], commands: [$cm]}')
    comment=$(echo "$SSM_COMMAND" | cut -c1-100)
    # send ssm command to instance id in C9_ID
    sh_command_id=$(aws ssm send-command \
        --targets "Key=InstanceIds,Values=$C9_ID" \
        --document-name "AWS-RunShellScript" \
        --parameters "$parameters" \
        --timeout-seconds 3600 \
        --comment "$comment" \
        --output text \
        --query "Command.CommandId")

    command_status="InProgress" # seed status var
    while [[ "$command_status" == "InProgress" || "$command_status" == "Pending" || "$command_status" == "Delayed" ]]; do
        sleep 15
        command_invocation=$(aws ssm get-command-invocation \
            --command-id "$sh_command_id" \
            --instance-id "$C9_ID")
        echo -E "$command_invocation" | jq # for debugging purposes
        command_status=$(echo -E "$command_invocation" | jq -r '.Status')
    done

    if [ "$command_status" != "Success" ]; then
        echo "failed executing $SSM_COMMAND : $command_status" && exit 1
    else
        echo "successfully completed execution!"
    fi
}

wait_for_instance_ssm() {
    INSTANCE_ID="$1"
    echo "Waiting for instance $INSTANCE_ID to become available"
    aws ec2 wait instance-status-ok --instance-ids "$INSTANCE_ID"
    echo "Instance $INSTANCE_ID is available"
    ssm_status=$(aws ssm describe-instance-information --filters "Key=InstanceIds,Values=$INSTANCE_ID" --query 'InstanceInformationList[].PingStatus' --output text)
    while [[ "$ssm_status" != "Online" ]]; do
        echo "Instance $INSTANCE_ID is not online in SSM yet. Waiting 15 seconds"
        sleep 15
        ssm_status=$(aws ssm describe-instance-information --filters "Key=InstanceIds, Values=$INSTANCE_ID" --query 'InstanceInformationList[].PingStatus' --output text)
    done
    echo "Instance $INSTANCE_ID is online in SSM"
}

replace_instance_profile() {
    echo "Replacing instance profile"
    association_id=$(aws ec2 describe-iam-instance-profile-associations --filter "Name=instance-id,Values=$C9_ID" --query 'IamInstanceProfileAssociations[].AssociationId' --output text)
    if [ ! association_id == "" ]; then
        aws ec2 disassociate-iam-instance-profile --association-id $association_id
        command_status=$(aws ec2 describe-iam-instance-profile-associations --filter "Name=instance-id,Values=$C9_ID" --query 'IamInstanceProfileAssociations[].State' --output text)
        while [[ "$command_status" == "disassociating" ]]; do
            sleep 15
            command_status=$(aws ec2 describe-iam-instance-profile-associations --filter "Name=instance-id,Values=$C9_ID" --query 'IamInstanceProfileAssociations[].State' --output text)
        done
    fi
    aws ec2 associate-iam-instance-profile --instance-id $C9_ID --iam-instance-profile Name=$C9_INSTANCE_PROFILE_NAME
    command_status=$(aws ec2 describe-iam-instance-profile-associations --filter "Name=instance-id,Values=$C9_ID" --query 'IamInstanceProfileAssociations[].State' --output text)
    while [[ "$command_status" == "associating" ]]; do
        sleep 15
        command_status=$(aws ec2 describe-iam-instance-profile-associations --filter "Name=instance-id,Values=$C9_ID" --query 'IamInstanceProfileAssociations[].State' --output text)
    done
    echo "Instance profile replaced. Rebooting instance"
    aws ec2 reboot-instances --instance-ids "$C9_ID"
    wait_for_instance_ssm "$C9_ID"
    echo "Instance rebooted"
}