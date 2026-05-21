#!/usr/bin/env bash
set -euo pipefail

readonly APP_USER="alchemyst"
readonly APP_GROUP="alchemyst"
readonly REPO_DIR="/opt/alchemyst-hiring"
readonly PROJECT_ROOT="/opt/alchemyst-hiring/may-2026/devops/quickstart"
readonly VENV_ROOT="/opt/alchemyst-venvs"

export DEBIAN_FRONTEND=noninteractive

log() {
  printf '[%s] %s\n' "$(date -Iseconds)" "$*"
}

require_root() {
  if [[ "${EUID}" -ne 0 ]]; then
    echo "This script must run as root" >&2
    exit 1
  fi
}

ensure_app_user() {
  if ! id -u "${APP_USER}" >/dev/null 2>&1; then
    useradd --system --create-home --shell /bin/bash "${APP_USER}"
  fi
}

install_base_packages() {
  apt-get update
  apt-get install -y \
    build-essential \
    ca-certificates \
    curl \
    git \
    jq \
    netcat-openbsd \
    python3 \
    python3-pip \
    python3-venv
}

install_nodejs() {
  if command -v node >/dev/null 2>&1; then
    return
  fi
  curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
  apt-get install -y nodejs
}

install_iii_engine() {
  if [[ -x /usr/local/bin/iii ]]; then
    return
  fi
  # Set HOME to /root for the installer to prevent sh errors
  export HOME=/root
  BIN_DIR=/usr/local/bin curl -fsSL https://install.iii.dev/iii/main/install.sh | sh -s -- v0.11.3
  # Installer may place binaries under ~/.local/bin when run as root.
  for candidate in /usr/local/bin/iii /root/.local/bin/iii /root/bin/iii; do
    if [[ -x "${candidate}" ]]; then
      log "Installing iii from ${candidate}"
      install -m 0755 "${candidate}" /usr/local/bin/iii
      break
    fi
  done
  if [[ ! -x /usr/local/bin/iii ]]; then
    echo "iii binary not found after install" >&2
    exit 1
  fi
}

ensure_repo_present() {
  if [[ ! -d "${PROJECT_ROOT}" ]]; then
    echo "Expected project root ${PROJECT_ROOT} to exist after cloud-init clone" >&2
    exit 1
  fi
  chown -R "${APP_USER}:${APP_GROUP}" "${REPO_DIR}"
}

ensure_runtime_dirs() {
  mkdir -p /etc/alchemyst /etc/iii /var/log/alchemyst "${VENV_ROOT}" /var/cache/huggingface
  chown -R "${APP_USER}:${APP_GROUP}" /var/log/alchemyst /var/cache/huggingface "${VENV_ROOT}"
}

create_python_venv() {
  local venv_path="$1"
  local requirements_file="$2"
  python3 -m venv "${venv_path}"
  "${venv_path}/bin/pip" install --upgrade pip setuptools wheel
  "${venv_path}/bin/pip" install -r "${requirements_file}"
  chown -R "${APP_USER}:${APP_GROUP}" "${venv_path}"
}

install_systemd_unit() {
  install -D -m 0644 "$1" "/etc/systemd/system/$2"
}

install_executable() {
  install -D -m 0755 "$1" "$2"
}

harden_ssh() {
  log "Hardening SSH configuration..."
  # Disable root password login, but allow key-based root for now (as Terraform needs it)
  # In a real senior setup, we'd transition to a deploy user entirely.
  sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin prohibit-password/g' /etc/ssh/sshd_config
  sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/g' /etc/ssh/sshd_config
  systemctl restart ssh
}
