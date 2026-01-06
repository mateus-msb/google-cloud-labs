
#!/bin/bash

# Exit on any error
set -e

# Declare variables
ZONE="us-central1-a"
REGION="${ZONE%-*}"
PROJECT_ID="qwiklabs-gcp-03-73d09f153196"

# Set the default region and zone
gcloud config set compute/region $REGION
gcloud config set compute/zone $ZONE

# Create Cloud Run
mkdir gcf_hello_world && cd $_

# Package dependencies
npm install

# Deploy the function to Cloud Run
gcloud functions deploy nodejs-pubsub-function \
  --gen2 \
  --runtime=nodejs20 \
  --region=$REGION \
  --source=. \
  --entry-point=helloPubSub \
  --trigger-topic cf-demo \
  --stage-bucket $PROJECT_ID-bucket \
  --service-account cloudfunctionsa@$PROJECT_ID.iam.gserviceaccount.com \
  --allow-unauthenticated

# Verify deployment
gcloud functions describe nodejs-pubsub-function --region=$REGION