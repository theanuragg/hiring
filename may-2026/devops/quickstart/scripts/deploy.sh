#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INFRA="${ROOT}/infra"
ENV_FILE="${ROOT}/.deploy.env"

die() { echo "ERROR: $*" >&2; exit 1; }

if [[ ! -f "${ENV_FILE}" ]]; then
  cp "${ROOT}/.deploy.env.example" "${ENV_FILE}"
  die "Created ${ENV_FILE} — edit DIGITALOCEAN_TOKEN and GITHUB_USER, then run again."
fi

SAVED_DO_TOKEN="${DIGITALOCEAN_TOKEN:-}"
# shellcheck disable=SC1090
source "${ENV_FILE}"
if [[ -n "${SAVED_DO_TOKEN}" && "${SAVED_DO_TOKEN}" != *"REPLACE_ME"* ]]; then
  DIGITALOCEAN_TOKEN="${SAVED_DO_TOKEN}"
fi

[[ -n "${DIGITALOCEAN_TOKEN:-}" ]] || die "Set DIGITALOCEAN_TOKEN in .deploy.env or: export DIGITALOCEAN_TOKEN=dop_v1_..."
[[ -n "${GITHUB_USER:-}" ]] || die "Set GITHUB_USER in .deploy.env"
GITHUB_USER="${GITHUB_USER%/}"
[[ "${GITHUB_USER}" != "your-github-username" ]] || die "Set GITHUB_USER=theanuragg in .deploy.env"
[[ "${DIGITALOCEAN_TOKEN}" != *"REPLACE_ME"* ]] || die "Set a real DIGITALOCEAN_TOKEN in .deploy.env"

command -v terraform >/dev/null 2>&1 || die "Install terraform: brew tap hashicorp/tap && brew install hashicorp/tap/terraform"

[[ -n "${GIT_REF:-}" ]] || GIT_REF=main
[[ -n "${REGION:-}" ]] || REGION=blr1
[[ -n "${SSH_PUBLIC_KEY_PATH:-}" ]] || SSH_PUBLIC_KEY_PATH="${HOME}/.ssh/id_ed25519.pub"
[[ -f "${SSH_PUBLIC_KEY_PATH/#\~/${HOME}}" ]] || die "SSH key not found: ${SSH_PUBLIC_KEY_PATH}"

if [[ -z "${ADMIN_CIDR:-}" ]]; then
  MY_IP="$(curl -4 -s ifconfig.me || true)"
  [[ -n "${MY_IP}" ]] || die "Set ADMIN_CIDR=your.ip/32 in .deploy.env"
  ADMIN_CIDR="${MY_IP}/32"
  echo "Using ADMIN_CIDR=${ADMIN_CIDR}"
fi

REPO_URL="https://github.com/${GITHUB_USER}/hiring.git"
SSH_PATH="${SSH_PUBLIC_KEY_PATH/#\~/${HOME}}"

cat > "${INFRA}/terraform.tfvars" <<EOF
ssh_public_key_path = "${SSH_PATH}"
admin_cidr_blocks   = ["${ADMIN_CIDR}"]
repo_clone_url      = "${REPO_URL}"
repo_ref            = "${GIT_REF}"
region              = "${REGION}"
EOF

echo "Wrote ${INFRA}/terraform.tfvars"
echo "  repo_clone_url = ${REPO_URL}"

export DIGITALOCEAN_TOKEN
cd "${INFRA}"
terraform init -input=false
if [[ "${AUTO_APPROVE:-0}" == "1" ]]; then
  terraform apply -auto-approve
else
  terraform apply
fi

echo ""
terraform output
echo ""
echo "Wait 10-20 min, then: ${ROOT}/scripts/test-api.sh"
