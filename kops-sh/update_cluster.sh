#!/bin/bash

export AWS_ACCESS_KEY_ID=$(aws configure get aws_access_key_id)
export AWS_SECRET_ACCESS_KEY=$(aws configure get aws_secret_access_key)
export EDITOR="gedit"
export KOPS_NAME=server.exampleapp.com
export KOPS_STATE_STORE=s3://example-kubernetes-state


# Enable verbose: -v10
/usr/local/bin/kops upgrade cluster --name=$KOPS_NAME --state=$KOPS_STATE_STORE --yes

/usr/local/bin/kops update cluster --name=$KOPS_NAME --state=$KOPS_STATE_STORE --yes
