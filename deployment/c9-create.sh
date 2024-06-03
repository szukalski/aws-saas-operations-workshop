#!/bin/bash -x
# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

REPO_URL=$1
source ./_workshop-conf.sh
source ./_c9-create.sh

## Variables
REGION=$(aws ec2 describe-availability-zones --output text --query 'AvailabilityZones[0].[RegionName]')
REPO_DESCRIPTION="SaaS Operations architecture repository"
REPO_PATH="/home/ec2-user/environment/${REPO_NAME}"
CC_REPO_URL="codecommit::${REGION}://${REPO_NAME}"

## Create SaaS application
echo "Creating workshop"
install_dependencies
create_codecommit
create_tenant_pipeline 
create_bootstrap 
#wait_for_background_jobs
execute_pipeline
deploy_admin_ui &
deploy_application_ui &
deploy_landing_ui &
deploy_dashboards &
wait_for_background_jobs
create_tenants
create_tenant_users
echo "Success - Workshop created!"
