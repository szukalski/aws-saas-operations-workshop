#!/bin/bash -x
# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

aws logs tail --follow /aws/codebuild/install-workshop-stack-codebuild
