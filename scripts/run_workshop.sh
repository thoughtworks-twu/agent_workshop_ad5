#!/usr/bin/env bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VENV_DIR="$PROJECT_ROOT/.venv"
ENV_FILE="$PROJECT_ROOT/.env.local"

read_env_file_value() {
  local variable_name="$1"

  [[ -f "$ENV_FILE" ]] || return 0

  sed -n "s/^export ${variable_name}=\"\(.*\)\"$/\1/p" "$ENV_FILE" | tail -n 1
}

[[ -f "$ENV_FILE" ]] || {
  printf '[run] Missing %s. Run scripts/setup_workshop.sh first.\n' "$ENV_FILE" >&2
  exit 1
}

[[ -x "$VENV_DIR/bin/streamlit" ]] || {
  printf '[run] Missing virtual environment at %s. Run scripts/setup_workshop.sh first.\n' "$VENV_DIR" >&2
  exit 1
}

GOOGLE_API_KEY="$(read_env_file_value GOOGLE_API_KEY)"
GEMINI_API_KEY="$(read_env_file_value GEMINI_API_KEY)"

[[ -n "$GOOGLE_API_KEY" ]] || {
  printf '[run] Missing GOOGLE_API_KEY in %s. Run scripts/setup_workshop.sh again.\n' "$ENV_FILE" >&2
  exit 1
}

export GOOGLE_API_KEY
export GEMINI_API_KEY="${GEMINI_API_KEY:-$GOOGLE_API_KEY}"

cd "$PROJECT_ROOT"
exec "$VENV_DIR/bin/streamlit" run streamlit_app.py
