#!/bin/bash

# Configuration
REPOSITORY_NAME="guestbook-app"
IMAGE_TAG="lambda"
TEMPLATE_FILE="template.yaml"

# Get AWS account info
echo "Getting AWS account information..."
ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
REGION=${AWS_REGION:-us-east-1}

# Full image URI
IMAGE_URI="${ACCOUNT}.dkr.ecr.${REGION}.amazonaws.com/${REPOSITORY_NAME}:${IMAGE_TAG}"

echo "========================================="
echo "Lambda Container Test Setup"
echo "========================================="
echo "AWS Account: ${ACCOUNT}"
echo "AWS Region:  ${REGION}"
echo "Image URI:   ${IMAGE_URI}"
echo "========================================="
echo ""

# Check if SAM CLI is installed
if ! command -v sam &> /dev/null; then
    echo "❌ SAM CLI is not installed."
    echo "Install it with: brew install aws-sam-cli (Mac) or pip install aws-sam-cli"
    exit 1
fi

# Check if image already exists locally
echo "Checking for local image..."
if docker image inspect ${IMAGE_URI} &> /dev/null; then
    echo "✅ Image already exists locally"
else
    echo "📥 Image not found locally. Pulling from ECR..."
    
    # Login to ECR
    echo "Logging into ECR..."
    aws ecr get-login-password --region ${REGION} | \
        docker login --username AWS --password-stdin ${ACCOUNT}.dkr.ecr.${REGION}.amazonaws.com
    
    # Pull the image
    echo "Pulling image..."
    docker pull ${IMAGE_URI}
    
    if [ $? -ne 0 ]; then
        echo "❌ Failed to pull image. Make sure the image exists in ECR."
        exit 1
    fi
    echo "✅ Image pulled successfully"
fi

# Create SAM template
echo ""
echo "Creating SAM template..."
cat > ${TEMPLATE_FILE} << EOF
AWSTemplateFormatVersion: '2010-09-09'
Transform: AWS::Serverless-2016-10-31

Globals:
  Function:
    Timeout: 30
    MemorySize: 512
    Environment:
      Variables:
        DDB_TABLE: guestbook
        AWS_REGION: ${REGION}
        NODE_NAME: local-test
        KUBERNETES_POD_NAME: local-lambda
  Api:
    BinaryMediaTypes:
      - '*/*'
    Cors:
      AllowOrigin: "'*'"
      AllowHeaders: "'*'"
      AllowMethods: "'*'"

Resources:
  GuestbookFunction:
    Type: AWS::Serverless::Function
    Properties:
      FunctionName: GuestbookFunction
      PackageType: Image
      ImageUri: ${IMAGE_URI}
      Events:
        RootApi:
          Type: Api
          Properties:
            Path: /
            Method: ANY
        ProxyApi:
          Type: Api
          Properties:
            Path: /{proxy+}
            Method: ANY
EOF

echo "✅ Template created: ${TEMPLATE_FILE}"

# Start SAM local API directly (skip build for container images)
echo ""
echo "Starting SAM local API..."
echo "========================================="
echo "🚀 Your Flask app will be available at:"
echo "   http://localhost:3000"
echo ""
echo "Press Ctrl+C to stop"
echo "========================================="
echo ""

# For container images, we skip the build step
sam local start-api --skip-pull-image --warm-containers EAGER

# Cleanup function
cleanup() {
    echo ""
    echo "Cleaning up..."
    printf "Remove template.yaml? (y/n): "
    read REMOVE_TEMPLATE
    if [ "$REMOVE_TEMPLATE" = "y" ] || [ "$REMOVE_TEMPLATE" = "Y" ]; then
        rm -f ${TEMPLATE_FILE}
        echo "✅ Template removed"
    fi
}

# Set up cleanup on exit
trap cleanup EXIT