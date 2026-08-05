#!/usr/bin/env bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VENV_DIR="$PROJECT_ROOT/.venv"
ENV_FILE="$PROJECT_ROOT/.env.local"
REPO_DIR="$PROJECT_ROOT/my-git-repo"

usage() {
  cat <<'EOF'
Usage:
  scripts/setup_workshop.sh [--api-key KEY] [--git-name NAME] [--git-email EMAIL] [--run]

Options:
  --api-key KEY       Gemini or Google API key. If omitted, the script prompts once and saves it.
  --git-name NAME     Git user.name for my-git-repo. If omitted, the script prompts once and saves it.
  --git-email EMAIL   Git user.email for my-git-repo. If omitted, the script prompts once and saves it.
  --run               Launch Streamlit after setup completes.
  -h, --help          Show this help message.

Examples:
  scripts/setup_workshop.sh
  scripts/setup_workshop.sh --run
EOF
}

log() {
  printf '[setup] %s\n' "$1"
}

fail() {
  printf '[setup] %s\n' "$1" >&2
  exit 1
}

is_placeholder_value() {
  local value="$1"

  case "$value" in
    ''|YOUR_*|your-*|your_*|'Your Name'|'you@example.com'|'you@thoughtworks.com')
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

version_ge() {
  local left="$1"
  local right="$2"
  [[ "$(printf '%s\n%s\n' "$right" "$left" | sort -V | tail -n1)" == "$left" ]]
}

install_homebrew_if_needed() {
  if command -v brew >/dev/null 2>&1; then
    return
  fi

  [[ "$(uname -s)" == "Darwin" ]] || fail 'Homebrew is required automatically only on macOS. Install Python 3.11+ manually on this OS.'
  log 'Homebrew not found. Installing Homebrew.'
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

  if [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [[ -x /usr/local/bin/brew ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
  fi

  command -v brew >/dev/null 2>&1 || fail 'Homebrew installation finished, but brew is still not on PATH.'
}

ensure_python_311() {
  local candidate

  for candidate in python3.11 python3 python; do
    if command -v "$candidate" >/dev/null 2>&1; then
      local version
      version="$($candidate -c 'import sys; print(".".join(map(str, sys.version_info[:3])))')"
      if version_ge "$version" '3.11.0'; then
        printf '%s' "$candidate"
        return
      fi
    fi
  done

  install_homebrew_if_needed
  log 'Installing python@3.11 via Homebrew.'
  brew install python@3.11

  command -v python3.11 >/dev/null 2>&1 || fail 'python3.11 is not available after installation.'
  printf '%s' 'python3.11'
}

create_or_refresh_venv() {
  local python_bin="$1"

  if [[ ! -d "$VENV_DIR" ]]; then
    log "Creating virtual environment with $python_bin."
    "$python_bin" -m venv "$VENV_DIR"
  else
    log 'Virtual environment already exists. Reusing it.'
  fi

  # shellcheck disable=SC1091
  source "$VENV_DIR/bin/activate"
  python -m pip install --upgrade pip
  python -m pip install "pydantic-ai==2.17.0" streamlit nest_asyncio mcp-server-git
}

read_env_file_value() {
  local variable_name="$1"

  [[ -f "$ENV_FILE" ]] || return 0

  sed -n "s/^export ${variable_name}=\"\(.*\)\"$/\1/p" "$ENV_FILE" | tail -n 1
}

load_saved_values() {
  if [[ ! -f "$ENV_FILE" ]]; then
    return 0
  fi

  if [[ -z "$API_KEY" ]]; then
    API_KEY="$(read_env_file_value GOOGLE_API_KEY)"
  fi

  if [[ -z "$GIT_NAME" ]]; then
    GIT_NAME="$(read_env_file_value WORKSHOP_GIT_NAME)"
  fi

  if [[ -z "$GIT_EMAIL" ]]; then
    GIT_EMAIL="$(read_env_file_value WORKSHOP_GIT_EMAIL)"
  fi

  if is_placeholder_value "$API_KEY"; then
    API_KEY=''
  fi

  if is_placeholder_value "$GIT_NAME"; then
    GIT_NAME=''
  fi

  if is_placeholder_value "$GIT_EMAIL"; then
    GIT_EMAIL=''
  fi
}

prompt_for_value() {
  local variable_name="$1"
  local prompt_text="$2"
  local is_secret="${3:-false}"
  local current_value="${!variable_name:-}"

  if [[ -n "$current_value" ]] && ! is_placeholder_value "$current_value"; then
    return
  fi

  local entered_value=''
  while [[ -z "$entered_value" ]]; do
    if [[ "$is_secret" == 'true' ]]; then
      read -r -s -p "$prompt_text: " entered_value
      printf '\n'
    else
      read -r -p "$prompt_text: " entered_value
    fi
  done

  printf -v "$variable_name" '%s' "$entered_value"
}

write_env_file() {
  local api_key="$1"
  local git_name="$2"
  local git_email="$3"

  cat > "$ENV_FILE" <<EOF
export GOOGLE_API_KEY="$api_key"
export GEMINI_API_KEY="${api_key}"
export WORKSHOP_GIT_NAME="$git_name"
export WORKSHOP_GIT_EMAIL="$git_email"
EOF

  chmod 600 "$ENV_FILE"
  log "Wrote local environment file to $ENV_FILE."
}

ensure_git_repo() {
  local git_name="$1"
  local git_email="$2"

  mkdir -p "$REPO_DIR"

  if [[ ! -d "$REPO_DIR/.git" ]]; then
    log 'Initializing git repository in my-git-repo.'
    git -C "$REPO_DIR" init
  else
    log 'Git repository already initialized in my-git-repo.'
  fi

  git -C "$REPO_DIR" config user.name "$git_name"
  git -C "$REPO_DIR" config user.email "$git_email"
}

start_streamlit() {
  export GOOGLE_API_KEY="$API_KEY"
  export GEMINI_API_KEY="$API_KEY"
  cd "$PROJECT_ROOT"
  log 'Starting Streamlit on http://localhost:8501.'
  exec "$VENV_DIR/bin/streamlit" run streamlit_app.py
}

API_KEY="${GOOGLE_API_KEY:-}"
GIT_NAME=''
GIT_EMAIL=''
RUN_AFTER_SETUP='false'

load_saved_values

while [[ $# -gt 0 ]]; do
  case "$1" in
    --api-key)
      [[ $# -ge 2 ]] || fail 'Missing value for --api-key.'
      API_KEY="$2"
      shift 2
      ;;
    --git-name)
      [[ $# -ge 2 ]] || fail 'Missing value for --git-name.'
      GIT_NAME="$2"
      shift 2
      ;;
    --git-email)
      [[ $# -ge 2 ]] || fail 'Missing value for --git-email.'
      GIT_EMAIL="$2"
      shift 2
      ;;
    --run)
      RUN_AFTER_SETUP='true'
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      fail "Unknown argument: $1"
      ;;
  esac
done

[[ -f "$PROJECT_ROOT/streamlit_app.py" && -f "$PROJECT_ROOT/agent_1.py" ]] || fail 'Run this script from the workshop repository. Expected streamlit_app.py and agent_1.py in the project root.'
command -v git >/dev/null 2>&1 || fail 'git is required on PATH.'

prompt_for_value API_KEY 'Google AI Studio API key' true
prompt_for_value GIT_NAME 'Git user name'
prompt_for_value GIT_EMAIL 'Git user email (user@thoughtworks.com)'

PYTHON_BIN="$(ensure_python_311)"
log "Using Python interpreter: $PYTHON_BIN"
create_or_refresh_venv "$PYTHON_BIN"
write_env_file "$API_KEY" "$GIT_NAME" "$GIT_EMAIL"
ensure_git_repo "$GIT_NAME" "$GIT_EMAIL"

cat <<EOF

Setup complete.

Next steps:
  1. source "$ENV_FILE"
  2. source "$VENV_DIR/bin/activate"
  3. streamlit run streamlit_app.py

Or use:
  scripts/run_workshop.sh
EOF

if [[ "$RUN_AFTER_SETUP" == 'true' ]]; then
  start_streamlit
fi
