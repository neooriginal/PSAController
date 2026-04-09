#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

cleanup() {
  if [[ -n "${BACKEND_PID:-}" ]]; then
    kill "$BACKEND_PID" >/dev/null 2>&1 || true
  fi
}

trap cleanup EXIT INT TERM

cd "$ROOT_DIR/backend"
npm install >/dev/null
python3 -m venv .venv
.venv/bin/pip install --quiet -r psa_bridge/requirements.txt
PSA_BRIDGE_PYTHON="$ROOT_DIR/backend/.venv/bin/python3" HOST=127.0.0.1 PORT=8787 npm start &
BACKEND_PID=$!

cd "$ROOT_DIR/frontend"
flutter pub get >/dev/null
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8787
