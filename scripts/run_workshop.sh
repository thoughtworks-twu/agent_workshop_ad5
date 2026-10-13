#!/usr/bin/env bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$PROJECT_ROOT/.env.local"

read_env_file_value() {
  local variable_name="$1"

  [[ -f "$ENV_FILE" ]] || return 0

  sed -n "s/^export ${variable_name}=\"\(.*\)\"$/\1/p" "$ENV_FILE" | tail -n 1
}

initialize_homebrew_environment() {
  local brew_bin=''
  local shellenv_output=''
  local platform=''

  brew_bin="$(command -v brew 2>/dev/null || true)"
  if [[ -z "$brew_bin" ]]; then
    platform="$(uname -s)"
    case "$platform" in
      Darwin)
        for brew_bin in /opt/homebrew/bin/brew /usr/local/bin/brew; do
          [[ -x "$brew_bin" ]] && break
          brew_bin=''
        done
        ;;
      Linux)
        brew_bin='/home/linuxbrew/.linuxbrew/bin/brew'
        [[ -x "$brew_bin" ]] || brew_bin=''
        ;;
    esac
  fi

  [[ -n "$brew_bin" ]] || return 0
  if ! shellenv_output="$("$brew_bin" shellenv)"; then
    printf '[run] Could not initialize the Homebrew environment. Run scripts/setup_workshop.sh to repair the workshop setup.\n' >&2
    return 1
  fi
  [[ -n "$shellenv_output" ]] || {
    printf '[run] Homebrew returned an empty shell environment. Run scripts/setup_workshop.sh to repair the workshop setup.\n' >&2
    return 1
  }
  if ! eval "$shellenv_output"; then
    printf '[run] Could not apply the Homebrew environment. Run scripts/setup_workshop.sh to repair the workshop setup.\n' >&2
    return 1
  fi
}

if ! command -v uv >/dev/null 2>&1; then
  initialize_homebrew_environment || exit 1
fi

command -v uv >/dev/null 2>&1 || {
  printf '[run] UV is unavailable. Run scripts/setup_workshop.sh to install Homebrew and UV and prepare the workshop.\n' >&2
  exit 1
}

[[ -f "$ENV_FILE" ]] || {
  printf '[run] Missing %s. Run scripts/setup_workshop.sh first.\n' "$ENV_FILE" >&2
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
exec uv run --locked streamlit run streamlit_app.py
