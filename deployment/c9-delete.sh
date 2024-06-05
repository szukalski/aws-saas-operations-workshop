#!/bin/bash -x
# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

source ./_c9-delete.sh
echo "Deleting workshop resources"

TRAILS=( "saas-ops-ddb-access-trails" "saas-ops-management-trails" )
STACKS_1=( "saas-operations-controlplane")
STACKS_2=( "saas-operations-pipeline" "saasOpsWorkshop-saasOperationsDashboard")
CODECOMMIT_REPOS=( "saas-operations-workshop" )

for TRAIL in "${TRAILS[@]}"; do
    stop_cloudtrail "${TRAIL}"
done
delete_tenant_stacks &
wait_for_background_jobs
delete_buckets
for STACK in "${STACKS_1[@]}"; do
    delete_stack "${STACK}"
done
for STACK in "${STACKS_2[@]}"; do
    delete_stack "${STACK}" &
done
for REPO in "${CODECOMMIT_REPOS[@]}"; do
    delete_codecommit_repo "${REPO}" &
done
delete_log_groups &
delete_user_pools &
delete_api_keys &
wait_for_background_jobs

echo "Workshop deleted"
