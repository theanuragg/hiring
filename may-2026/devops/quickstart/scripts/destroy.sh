#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ROOT}/.deploy.env"
[[ -f "${ENV_FILE}" ]] && source "${ENV_FILE}"
export DIGITALOCEAN_TOKEN="${DIGITALOCEAN_TOKEN:?Set DIGITALOCEAN_TOKEN}"
cd "${ROOT}/infra"
terraform destroy
