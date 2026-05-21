#!/usr/bin/env bash
set -euo pipefail
cd "${PROJECT_ROOT}/app/api-gateway"
exec /opt/alchemyst-venvs/api-gateway/bin/uvicorn main:app --host "${APP_BIND_HOST}" --port "${APP_BIND_PORT}"
