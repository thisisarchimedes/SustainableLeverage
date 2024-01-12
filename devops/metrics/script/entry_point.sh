#!/bin/bash

# Load environment variables
set -a
source .env
set +a

aws configure set aws_access_key_id $AWS_ACCESS_KEY_ID
aws configure set aws_secret_access_key $AWS_SECRET_ACCESS_KEY
aws configure set default.region $AWS_DEFAULT_REGION

# Start Gunicorn
exec gunicorn -b 0.0.0.0:8000 "src.event_processor.entry_flask:app"
