#!/bin/bash
# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

B="/aws/codebuild/install-workshop-stack-codebuild"
T="/aws/api-gateway/access-logs-saas-operations-tenant-api--pooled"

if [[ ! -n $1 ]]; then
    aws logs tail --follow ${B}
    exit
fi

case "${1}"
    in
    -b) aws logs tail --follow ${B};;
    -t) aws logs tail --follow ${T};;
    \?)
        echo "Invalid option: -${1}" >&2
        exit;;
esac

echo "End"