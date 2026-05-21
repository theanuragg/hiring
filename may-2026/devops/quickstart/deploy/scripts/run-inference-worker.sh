#!/usr/bin/env bash
set -euo pipefail
cd "${PROJECT_ROOT}/workers/inference-worker"
exec /opt/alchemyst-venvs/inference-worker/bin/python inference_worker.py
