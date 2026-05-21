#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INFRA="${ROOT}/infra"

echo "--- Starting Deployment Validation ---"

cd "${INFRA}"
API_IP=$(terraform output -raw api_public_ip)
BASE_URL="http://${API_IP}"

echo "Validating API Gateway at ${BASE_URL}..."

# 1. Check healthz
echo "Checking /healthz..."
for i in {1..20}; do
  if curl -sf "${BASE_URL}/healthz" > /dev/null; then
    echo "  [OK] /healthz is up"
    break
  fi
  if [ $i -eq 20 ]; then
    echo "  [FAIL] /healthz timed out after 20 attempts"
    exit 1
  fi
  echo "  Waiting for API gateway... ($i/20)"
  sleep 10
done

# 2. Check end-to-end inference
echo "Checking /infer (end-to-end)..."
RESPONSE=$(curl -s -X POST "${BASE_URL}/infer" \
  -H "Content-Type: application/json" \
  -d '{"prompt": "Hello", "max_tokens": 10}')

if echo "${RESPONSE}" | grep -q "completion"; then
  echo "  [OK] /infer returned a valid response"
  echo "  Trace ID: $(echo "${RESPONSE}" | jq -r .trace_id)"
else
  echo "  [FAIL] /infer failed or returned invalid response"
  echo "  Response: ${RESPONSE}"
  exit 1
fi

echo "--- Validation Successful ---"
