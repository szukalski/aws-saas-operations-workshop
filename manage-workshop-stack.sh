#!/bin/bash -x
# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

for file in _common-functions.sh _workshop-config.sh; do
    if [[ -f workshop-deployment/$file ]]; then
        source workshop-deployment/$file
        echo "Loaded $file"
    else
        echo "File $file not found"
        exit 1
    fi
done

STACK_OPERATION="$1"

for i in {1..3}; do
    echo "iteration number: $i"
    if manage_workshop_stack "$STACK_OPERATION"; then
        echo "successfully completed execution"
        exit 0
    else
        sleep "$((15*i))"
    fi
done

echo "failed to complete execution"
exit 1
