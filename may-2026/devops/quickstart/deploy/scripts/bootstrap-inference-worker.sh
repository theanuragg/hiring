#!/usr/bin/env bash
set -euo pipefail

source /opt/alchemyst-hiring/may-2026/devops/quickstart/deploy/scripts/bootstrap-common.sh

require_root
install_base_packages
ensure_app_user
ensure_repo_present
ensure_runtime_dirs

create_python_venv \
  "/opt/alchemyst-venvs/inference-worker" \
  "${PROJECT_ROOT}/workers/inference-worker/requirements.txt"

install_executable \
  "${PROJECT_ROOT}/deploy/scripts/run-inference-worker.sh" \
  /usr/local/bin/run-inference-worker.sh
install_systemd_unit \
  "${PROJECT_ROOT}/deploy/systemd/alchemyst-inference-worker.service" \
  alchemyst-inference-worker.service

systemctl daemon-reload
systemctl enable --now alchemyst-inference-worker.service
