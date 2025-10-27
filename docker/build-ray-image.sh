#!/bin/bash

# Build and push custom Ray image for AI Platform
# This script builds the Ray image with NumPy compatibility fixes

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Configuration
IMAGE_NAME="${IMAGE_NAME:-ray-ai-platform}"
IMAGE_TAG="${IMAGE_TAG:-latest}"
REGISTRY="${REGISTRY:-gcr.io}"
PROJECT_ID="${GCP_PROJECT:-your-project-id}"

FULL_IMAGE="${REGISTRY}/${PROJECT_ID}/${IMAGE_NAME}:${IMAGE_TAG}"

echo -e "${YELLOW}🐳 Building Ray AI Platform Image${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${YELLOW}Image:${NC} ${FULL_IMAGE}"
echo ""

# Build image
echo -e "${YELLOW}📦 Building Docker image...${NC}"
docker build \
    -f docker/ray-ai-platform.Dockerfile \
    -t ${FULL_IMAGE} \
    -t ${REGISTRY}/${PROJECT_ID}/${IMAGE_NAME}:$(git rev-parse --short HEAD) \
    .

echo ""
echo -e "${GREEN}✅ Image built successfully!${NC}"
echo ""

# Test image
echo -e "${YELLOW}🧪 Testing image...${NC}"
docker run --rm ${FULL_IMAGE} python -c "
import ray
import numpy
import pandas
import openai
import anthropic
print('✅ All imports successful')
print(f'Ray version: {ray.__version__}')
print(f'NumPy version: {numpy.__version__}')
print(f'Pandas version: {pandas.__version__}')
"

echo ""
echo -e "${GREEN}✅ Image test passed!${NC}"
echo ""

# Push image
read -p "Push image to registry? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}📤 Pushing image to registry...${NC}"
    docker push ${FULL_IMAGE}
    docker push ${REGISTRY}/${PROJECT_ID}/${IMAGE_NAME}:$(git rev-parse --short HEAD)
    echo ""
    echo -e "${GREEN}✅ Image pushed successfully!${NC}"
    echo ""
    echo -e "${YELLOW}📋 Update your values-dev.yaml:${NC}"
    echo "  rayCluster:"
    echo "    image:"
    echo "      repository: '${REGISTRY}/${PROJECT_ID}/${IMAGE_NAME}'"
    echo "      tag: '${IMAGE_TAG}'"
    echo "      pullPolicy: 'Always'"
fi

echo ""
echo -e "${GREEN}🎉 Done!${NC}"
