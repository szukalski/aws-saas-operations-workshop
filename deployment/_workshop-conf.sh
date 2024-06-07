#!/bin/bash
# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

## Defines workshop configuration shared amongst scripts

## Variables
WORKSHOP_ID="21"
WORKSHOP_NAME="SaaSOps"$WORKSHOP_ID
REPO_NAME="aws-saas-operations-workshop"
CDK_VERSION="2.144.0"
BUILD_C9_INSTANCE_PROFILE_PARAMETER_NAME="/"$WORKSHOP_NAME"/Cloud9/BuildInstanceProfileName"
PARTICIPANT_C9_INSTANCE_PROFILE_PARAMETER_NAME="/"$WORKSHOP_NAME"/Cloud9/ParticipantInstanceProfileName"
TARGET_USER="ec2-user"
DELAY=15 # Used to sleep in functions. Tweak as desired.
