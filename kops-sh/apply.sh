#!/bin/bash

export AWS_ACCESS_KEY_ID=$(aws configure get aws_access_key_id)
export AWS_SECRET_ACCESS_KEY=$(aws configure get aws_secret_access_key)
export EDITOR="gedit"
export KOPS_NAME=server.example.com
export KOPS_STATE_STORE=s3://example-kubernetes-state


# Restart cluster to apply changes
function restartCluster {
  read -p "Restart cluster? (y/n)" -n 1 -r
  echo # move to a new line
  if [[ $REPLY =~ ^[Yy]$ ]]
  then
    /usr/local/bin/kops rolling-update cluster $KOPS_NAME --state=$KOPS_STATE_STORE --yes
  fi
}

restartCluster