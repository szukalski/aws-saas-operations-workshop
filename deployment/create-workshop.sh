#!/bin/bash -x
# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

# Do some stuff to create your workshop
# This is run on the Cloud9 instance

echo "Creating workshop"

## Define helper functions
# Retry command with backoff.
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

## Define variables
REGION=$(aws ec2 describe-availability-zones --output text --query 'AvailabilityZones[0].[RegionName]')
REPO_NAME="aws-saas-operations-workshop"
REPO_DESCRIPTION="SaaS Operations architecture repository"
REPO_PATH="/home/ec2-user/environment/${REPO_NAME}"
REPO_URL="codecommit::${REGION}://${REPO_NAME}"

## Install dependencies
echo "Installing dependencies"
echo "Enabling yarn"
corepack enable || retry npm install --global yarn
echo "yarn enabled"
echo "Installing isolation test packages"
cd ${REPO_PATH}/App/isolation-test/
retry npm install
echo "Isolation test packages installed"
echo "Dependencies installed"

# Create CodeCommit repository
echo "Creating CodeCommit repository"
cd ${REPO_PATH}
git init -b main
git config --global --add safe.directory ${REPO_PATH}
git add -A
git commit -m "Base code"
if ! aws codecommit get-repository --repository-name ${REPO_NAME}
then
    echo "${REPO_NAME} codecommit repo is not present, will create one now"
    CREATE_REPO=$(aws codecommit create-repository --repository-name ${REPO_NAME} --repository-description "${REPO_DESCRIPTION}")
    echo "${CREATE_REPO}"
fi
if ! git remote add cc "${REPO_URL}"
then
    echo "Setting url to remote cc"
    git remote set-url cc "${REPO_URL}"
fi
git push cc "$(git branch --show-current)":main
echo "CodeCommit repository created"
