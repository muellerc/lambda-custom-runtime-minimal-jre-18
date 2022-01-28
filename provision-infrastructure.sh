#!/bin/sh
set -e

# navigate into the infrastructure sub-directory
cd infrastructure

# synthesize the AWS CDK
cdk synth

# deploy the AWS infrastructure
cdk deploy --outputs-file target/outputs.json

# test the Amazon API Gateway endpoint
# we should see an HTTP 200 status code
curl -i $(cat target/outputs.json | jq -r '.LambdaCustomRuntimeMinimalJRE18InfrastructureStack.apiendpoint')/custom-runtime-jre-18
