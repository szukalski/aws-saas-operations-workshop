#!/bin/bash -x
# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

## Defines workshop configuration shared amongst scripts

## Variables
WORKSHOP_ID="21"
WORKSHOP_NAME="SaaSOps"$WORKSHOP_ID
REPO_NAME=$(echo $REPO_URL|sed 's#.*/##'|sed 's/\.git//')
CDK_VERSION="2.142.1"
BUILD_C9_INSTANCE_PROFILE_PARAMETER_NAME="/"$WORKSHOP_NAME"/Cloud9/BuildInstanceProfileName"
PARTICIPANT_C9_INSTANCE_PROFILE_PARAMETER_NAME="/"$WORKSHOP_NAME"/Cloud9/ParticipantInstanceProfileName"
TARGET_USER="ec2-user"

## Functions
FUNCTIONS=( _workshop-shared-functions.sh )
for FUNCTION in "${FUNCTIONS[@]}"; do
    if [ -f $FUNCTION ]; then
        source $FUNCTION
    else
        echo "ERROR: $FUNCTION not found"
    fi
done
