#!/usr/bin/env bash
set -euo pipefail
cd "${PROJECT_ROOT}/workers/caller-worker"
exec /usr/bin/node dist/worker.js
