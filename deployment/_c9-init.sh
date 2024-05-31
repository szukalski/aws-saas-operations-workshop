#!/bin/bash -x
# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

source ./_workshop-conf.sh

rm -vf ~/.aws/credentials
cd ~/environment/$REPO_NAME/deployment/cloud9 && ./resize-cloud9-ebs-vol.sh
cd ~/environment/$REPO_NAME/deployment && ./configure-logs.sh
