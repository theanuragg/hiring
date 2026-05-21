#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INFRA="${ROOT}/infra"
ENV_FILE="${ROOT}/.deploy.env"

[[ -f "${ENV_FILE}" ]] && source "${ENV_FILE}"
export DIGITALOCEAN_TOKEN="${DIGITALOCEAN_TOKEN:?Set DIGITALOCEAN_TOKEN}"

cd "${INFRA}"
API_IP="$(terraform output -raw api_public_ip)"
BASE="http://${API_IP}"

echo "API: ${BASE}"
echo "=== GET /healthz ==="
for i in $(seq 1 30); do
  if curl -sf "${BASE}/healthz" >/dev/null 2>&1; then
    curl -s "${BASE}/healthz"
    echo ""
    break
  fi
  echo "  not ready (${i}/30), retry in 10s..."
  sleep 10
  [[ "${i}" -eq 30 ]] && exit 1
done

echo "=== POST /infer ==="
curl -s "${BASE}/infer" \
  -H "Content-Type: application/json" \
  -d '{"prompt":"Hello from Alchemyst","max_tokens":32,"temperature":0.7}'
echo ""
