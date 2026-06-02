#!/bin/bash
# Creates the local S3 bucket when LocalStack is ready.
awslocal s3 mb s3://certificate-assistant-local --region us-east-1
echo "LocalStack: bucket certificate-assistant-local created."
