#!/usr/bin/env bash
set -euo pipefail

REPOSITORY_NAME="${REPOSITORY_NAME:-guestbook-app}"
IMAGE_TAG="${IMAGE_TAG:-lambda}" 
DDB_TABLE="${DDB_TABLE:-guestbook}"
AWS_REGION="${AWS_REGION:-us-east-1}"
NODE_NAME="${NODE_NAME:-local-test}"
CONTAINER_NAME="${CONTAINER_NAME:-guestbook-local-test}"

ACCOUNT="$(aws sts get-caller-identity --query Account --output text 2>/dev/null || echo "")"
ECR_REG="${ACCOUNT:+${ACCOUNT}.dkr.ecr.${AWS_REGION}.amazonaws.com}"
ECR_IMAGE_URI="${ECR_REG:+${ECR_REG}/${REPOSITORY_NAME}:${IMAGE_TAG}}"

# sanity check
docker image inspect "$ECR_IMAGE_URI" >/dev/null 2>&1 || { echo "Image not found: $ECR_IMAGE_URI"; exit 1; }

BROWSER_PORT="8080"
CONTAINER_PORT="8080"

# Stop and remove existing container if it exists
if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    echo "⚠️  Removing existing container: ${CONTAINER_NAME}"
    docker rm -f "${CONTAINER_NAME}" >/dev/null 2>&1
fi

# Cleanup function
cleanup() {
    echo -e "\n🧹 Cleaning up container ${CONTAINER_NAME}..."
    docker rm -f "${CONTAINER_NAME}" >/dev/null 2>&1 || true
    echo "✅ Container removed"
}
# Set trap to cleanup on script exit
trap cleanup EXIT INT TERM

echo "🚀 Container '${CONTAINER_NAME}' starting"
URL="http://127.0.0.1:${BROWSER_PORT}/"
echo "📝 Open: ${URL}"

docker run \
  --name "${CONTAINER_NAME}" \
  -p ${BROWSER_PORT}:${CONTAINER_PORT} \
  -e DDB_TABLE=${DDB_TABLE} \
  -e AWS_REGION=${AWS_REGION} \
  -e NODE_NAME=${NODE_NAME} \
  ${AWS_ACCESS_KEY_ID:+-e AWS_ACCESS_KEY_ID="$AWS_ACCESS_KEY_ID"} \
  ${AWS_SECRET_ACCESS_KEY:+-e AWS_SECRET_ACCESS_KEY="$AWS_SECRET_ACCESS_KEY"} \
  ${AWS_SESSION_TOKEN:+-e AWS_SESSION_TOKEN="$AWS_SESSION_TOKEN"} \
  ${ECR_IMAGE_URI}



# URL="http://127.0.0.1:${BROWSER_PORT}/"
# echo "📝 Open: ${URL}"
# if command -v open >/dev/null 2>&1; then open "$URL"; fi
# if command -v xdg-open >/dev/null 2>&1; then xdg-open "$URL"; fi

