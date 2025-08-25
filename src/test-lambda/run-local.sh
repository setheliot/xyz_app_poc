#!/usr/bin/env bash
set -euo pipefail

# Minimal local test runner: Lambda container + tiny HTTP proxy
# Assumes lambda_proxy.py exists in the same folder and the image tag below exists locally.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

REPOSITORY_NAME="${REPOSITORY_NAME:-guestbook-app}"
IMAGE_TAG="${IMAGE_TAG:-lambda}" 
DDB_TABLE="${DDB_TABLE:-guestbook}"
AWS_REGION="${AWS_REGION:-us-east-1}"
NODE_NAME="${NODE_NAME:-local-test}"

ACCOUNT="$(aws sts get-caller-identity --query Account --output text 2>/dev/null || echo "")"
ECR_REG="${ACCOUNT:+${ACCOUNT}.dkr.ecr.${AWS_REGION}.amazonaws.com}"
ECR_IMAGE_URI="${ECR_REG:+${ECR_REG}/${REPOSITORY_NAME}:${IMAGE_TAG}}"

LAMBDA_PORT="${LAMBDA_PORT:-9000}"   # container's /2015-03-31... endpoint mapped here
PROXY_PORT="${PROXY_PORT:-3000}"     # browser goes here

# sanity check
docker image inspect "$ECR_IMAGE_URI" >/dev/null 2>&1 || { echo "Image not found: $ECR_IMAGE_URI"; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo "python3 not found"; exit 1; }

# recycle old containers/processes
docker rm -f xyzapp-lambda-local >/dev/null 2>&1 || true

# -----------------------------
# Start Lambda container
# -----------------------------
echo "Starting Lambda container: $ECR_IMAGE_URI"
docker run -d --name xyzapp-lambda-local -p "${LAMBDA_PORT}:8080" \
  -e DDB_TABLE="$DDB_TABLE" \
  -e AWS_REGION="$AWS_REGION" \
  -e NODE_NAME="$NODE_NAME" \
  ${AWS_ACCESS_KEY_ID:+-e AWS_ACCESS_KEY_ID="$AWS_ACCESS_KEY_ID"} \
  ${AWS_SECRET_ACCESS_KEY:+-e AWS_SECRET_ACCESS_KEY="$AWS_SECRET_ACCESS_KEY"} \
  ${AWS_SESSION_TOKEN:+-e AWS_SESSION_TOKEN="$AWS_SESSION_TOKEN"} \
  "$ECR_IMAGE_URI" >/dev/null

# Wait for Lambda runtime: use a REST v1-shaped ping to avoid awsgi KeyError
PING_PAYLOAD='{"httpMethod":"GET","path":"/","headers":{},"requestContext":{"stage":"prod"},"isBase64Encoded":false}'
echo -n "Waiting for Lambda runtime on :${LAMBDA_PORT} ..."
for i in {1..30}; do
  if curl -fsS -XPOST "http://127.0.0.1:${LAMBDA_PORT}/2015-03-31/functions/function/invocations" -d "$PING_PAYLOAD" >/dev/null 2>&1; then
    echo " up."
    break
  fi
  sleep 1; echo -n "."
  if [[ $i -eq 30 ]]; then
    echo " timeout."; docker logs xyzapp-lambda-local || true; exit 1
  fi
done

# Quick check for proxy deps (user should run in venv)
python3 - <<'PY' 2>/dev/null || { echo "Installing proxy deps (flask, requests)"; python3 -m pip install -q flask requests; }
import flask, requests
print("ok")
PY

# Start the HTTP proxy (translates browser → Lambda event)
echo "Starting proxy on :${PROXY_PORT}"
LAMBDA_PORT="$LAMBDA_PORT" PROXY_PORT="$PROXY_PORT" python3 ./lambda_proxy.py &
PROXY_PID=$!

cleanup() {
  echo; echo "Shutting down…"
  kill "$PROXY_PID" >/dev/null 2>&1 || true
  docker rm -f xyzapp-lambda-local >/dev/null 2>&1 || true
}
trap cleanup EXIT

URL="http://127.0.0.1:${PROXY_PORT}/"
echo "Open: ${URL}"
if command -v open >/dev/null 2>&1; then open "$URL"; fi
if command -v xdg-open >/dev/null 2>&1; then xdg-open "$URL"; fi

# keep foreground while proxy runs
wait "$PROXY_PID"
