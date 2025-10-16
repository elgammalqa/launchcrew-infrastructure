#!/bin/bash
set -e

# Deployment script for Terraform

if [ $# -lt 1 ]; then
    echo "Usage: $0 <environment> [action]"
    echo "Example: $0 dev plan"
    echo "Example: $0 prod apply"
    exit 1
fi

ENVIRONMENT=$1
ACTION=${2:-plan}
ENV_DIR="environments/${ENVIRONMENT}"

if [ ! -d "$ENV_DIR" ]; then
    echo "Error: Environment '${ENVIRONMENT}' not found"
    exit 1
fi

cd $ENV_DIR

echo "=== Terraform ${ACTION} for ${ENVIRONMENT} ==="

# Initialize
terraform init

# Validate
terraform validate

# Format check
terraform fmt -check

# Run action
case $ACTION in
    plan)
        terraform plan -var-file="terraform.tfvars"
        ;;
    apply)
        terraform apply -var-file="terraform.tfvars"
        ;;
    destroy)
        echo "WARNING: This will destroy all resources!"
        read -p "Are you sure? (yes/no): " confirm
        if [ "$confirm" = "yes" ]; then
            terraform destroy -var-file="terraform.tfvars"
        fi
        ;;
    *)
        echo "Unknown action: ${ACTION}"
        exit 1
        ;;
esac
