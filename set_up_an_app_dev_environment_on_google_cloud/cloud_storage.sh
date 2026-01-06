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

# Create a bucket
gcloud storage buckets create gs://$PROJECT_ID

# Download ada image
curl https://upload.wikimedia.org/wikipedia/commons/thumb/a/a4/Ada_Lovelace_portrait.jpg/800px-Ada_Lovelace_portrait.jpg --output ada.jpg

# Upload ada image to the bucket
gcloud storage cp ada.jpg gs://$PROJECT_ID

# Clean up local file
rm ada.jpg

# Download the image back from the bucket to verify
gcloud storage cp -r gs://$PROJECT_ID/ada.jpg .

# Create folder and copy the image into it
gcloud storage cp gs://$PROJECT_ID/ada.jpg gs://$PROJECT_ID/image-folder/


# List contents of the bucket
gcloud storage ls gs://$PROJECT_ID

gcloud storage ls -l gs://$PROJECT_ID/ada.jpg


# Make object publicly accessible
gsutil acl ch -u AllUsers:R gs://$PROJECT_ID/ada.jpg

# Remove public access
gsutil acl ch -d AllUsers gs://$PROJECT_ID/ada.jpg