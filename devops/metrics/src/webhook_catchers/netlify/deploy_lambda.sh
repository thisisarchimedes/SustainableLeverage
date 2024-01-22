#!/usr/bin/env bash

sam build -t deploy_lambda.yaml
sam package --output-template-file packaged.yaml --resolve-s3
sam deploy --template-file packaged.yaml --stack-name metrics-netlify-webhook-catcher --capabilities CAPABILITY_IAM
