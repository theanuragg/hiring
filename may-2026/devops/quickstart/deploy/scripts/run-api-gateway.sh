#!/usr/bin/env bash
set -euo pipefail
cd "${PROJECT_ROOT}/app/api-gateway"
HOST="${APP_BIND_HOST:-127.0.0.1}"
PORT="${APP_BIND_PORT:-8000}"
exec /opt/alchemyst-venvs/api-gateway/bin/uvicorn main:app --host "${HOST}" --port "${PORT}"
