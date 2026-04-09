#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
API_BASE_URL="${API_BASE_URL:-http://localhost:8787}"

cd "$ROOT_DIR/frontend"
flutter pub get
flutter run -d chrome --dart-define=API_BASE_URL="$API_BASE_URL"
