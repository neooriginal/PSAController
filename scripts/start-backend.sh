#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

cd "$ROOT_DIR/backend"
npm install
python3 -m venv .venv
.venv/bin/pip install --quiet -r psa_bridge/requirements.txt
export PSA_BRIDGE_PYTHON="$ROOT_DIR/backend/.venv/bin/python3"
npm start
