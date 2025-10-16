#!/bin/bash
set -e

# Script to create GCS backend bucket for Terraform state

if [ $# -lt 2 ]; then
    echo "Usage: $0 <project-id> <environment>"
    echo "Example: $0 my-project dev"
    exit 1
fi

PROJECT_ID=$1
ENVIRONMENT=$2
BUCKET_NAME="${PROJECT_ID}-tfstate-${ENVIRONMENT}"
REGION="us-central1"

echo "Creating GCS bucket for Terraform state..."
echo "Project: ${PROJECT_ID}"
echo "Environment: ${ENVIRONMENT}"
echo "Bucket: ${BUCKET_NAME}"

# Create bucket
gcloud storage buckets create gs://${BUCKET_NAME} \
    --project=${PROJECT_ID} \
    --location=${REGION} \
    --uniform-bucket-level-access

# Enable versioning
gcloud storage buckets update gs://${BUCKET_NAME} \
    --versioning

echo "✓ Backend bucket created successfully!"
echo ""
echo "Update your backend.tf with:"
echo "  bucket = \"${BUCKET_NAME}\""
