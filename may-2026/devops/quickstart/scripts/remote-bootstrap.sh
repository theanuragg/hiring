#!/usr/bin/env bash
# Run bootstrap on all VMs from your laptop (requires SSH access).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INFRA="${ROOT}/infra"

cd "${INFRA}"
API_IP="$(terraform output -raw api_public_ip)"
CALLER_IP="$(terraform output -raw caller_worker_private_ip)"
INFER_IP="$(terraform output -raw inference_worker_private_ip)"

echo "=== Gateway ${API_IP} ==="
ssh -o StrictHostKeyChecking=accept-new "root@${API_IP}" bash -s <<'REMOTE'
set -euo pipefail
if [[ ! -d /opt/alchemyst-hiring/.git ]]; then
  git clone https://github.com/theanuragg/hiring.git /opt/alchemyst-hiring
fi
cd /opt/alchemyst-hiring
git fetch origin main
git checkout main
git pull origin main
bash may-2026/devops/quickstart/deploy/scripts/bootstrap-api-gateway.sh
echo "--- gateway services ---"
systemctl is-active iii-engine alchemyst-api caddy || true
curl -sf http://127.0.0.1:8000/healthz && echo " (FastAPI ok)" || echo "FastAPI not ready"
curl -sf http://127.0.0.1/healthz && echo " (Caddy ok)" || echo "Caddy not ready"
REMOTE

echo ""
echo "=== Caller worker ${CALLER_IP} (via gateway) ==="
ssh "root@${API_IP}" bash -s <<REMOTE
set -euo pipefail
ssh -o StrictHostKeyChecking=no root@${CALLER_IP} bash -s <<'INNER'
set -euo pipefail
cd /opt/alchemyst-hiring 2>/dev/null || git clone https://github.com/theanuragg/hiring.git /opt/alchemyst-hiring
cd /opt/alchemyst-hiring && git pull origin main
bash may-2026/devops/quickstart/deploy/scripts/bootstrap-caller-worker.sh
systemctl is-active alchemyst-caller-worker || true
INNER
REMOTE

echo ""
echo "=== Inference worker ${INFER_IP} (via gateway) ==="
ssh "root@${API_IP}" bash -s <<REMOTE
set -euo pipefail
ssh -o StrictHostKeyChecking=no root@${INFER_IP} bash -s <<'INNER'
set -euo pipefail
cd /opt/alchemyst-hiring 2>/dev/null || git clone https://github.com/theanuragg/hiring.git /opt/alchemyst-hiring
cd /opt/alchemyst-hiring && git pull origin main
bash may-2026/devops/quickstart/deploy/scripts/bootstrap-inference-worker.sh
systemctl is-active alchemyst-inference-worker || true
INNER
REMOTE

echo ""
echo "=== Public test from laptop ==="
sleep 3
curl -sv "http://${API_IP}/healthz" 2>&1 | tail -20
echo ""
echo "Inference may take 10-20 min on first boot. Then run:"
echo "  curl -s http://${API_IP}/infer -H 'Content-Type: application/json' -d '{\"prompt\":\"Hello\",\"max_tokens\":16}'"
