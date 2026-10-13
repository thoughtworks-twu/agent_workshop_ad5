#!/usr/bin/env bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$PROJECT_ROOT/.env.local"
REPO_DIR="$PROJECT_ROOT/my-git-repo"
HOMEBREW_INSTALL_URL='https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh'

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

find_homebrew() {
  local brew_path=''
  local platform=''

  brew_path="$(command -v brew 2>/dev/null || true)"
  if [[ -n "$brew_path" ]]; then
    printf '%s\n' "$brew_path"
    return 0
  fi

  platform="$(uname -s)"
  case "$platform" in
    Darwin)
      for brew_path in /opt/homebrew/bin/brew /usr/local/bin/brew; do
        if [[ -x "$brew_path" ]]; then
          printf '%s\n' "$brew_path"
          return 0
        fi
      done
      ;;
    Linux)
      brew_path='/home/linuxbrew/.linuxbrew/bin/brew'
      if [[ -x "$brew_path" ]]; then
        printf '%s\n' "$brew_path"
        return 0
      fi
      ;;
  esac

}

bootstrap_homebrew() {
  local installer_path=''
  local platform=''

  platform="$(uname -s)"
  case "$platform" in
    Darwin|Linux) ;;
    *) fail "Unsupported operating system: $platform. Homebrew bootstrap supports macOS and Linux." ;;
  esac

  BREW_BIN="$(find_homebrew)"
  if [[ -n "$BREW_BIN" ]]; then
    return
  fi

  command -v curl >/dev/null 2>&1 || fail 'curl is required to download the official Homebrew installer.'
  log 'Homebrew was not found. Downloading its official installer; follow its confirmation and permission prompts.'
  installer_path="$(mktemp "${TMPDIR:-/tmp}/homebrew-install.XXXXXX")" || fail 'Could not create a temporary file for the Homebrew installer.'
  if ! curl -fsSL "$HOMEBREW_INSTALL_URL" -o "$installer_path"; then
    rm -f "$installer_path"
    fail 'Could not download the official Homebrew installer. Check network access and rerun setup.'
  fi
  if ! /bin/bash "$installer_path"; then
    rm -f "$installer_path"
    fail "The Homebrew installer failed. On Linux, install Homebrew's documented build prerequisites and rerun setup."
  fi
  rm -f "$installer_path"

  BREW_BIN="$(find_homebrew)"
  [[ -n "$BREW_BIN" ]] || fail 'Homebrew installer completed, but the brew executable was not found in PATH or a standard installation prefix.'
}

initialize_homebrew_environment() {
  local shellenv_output=''

  if ! shellenv_output="$("$BREW_BIN" shellenv)"; then
    fail 'Could not initialize the Homebrew environment with brew shellenv.'
  fi
  [[ -n "$shellenv_output" ]] || fail 'Homebrew returned an empty environment from brew shellenv.'
  eval "$shellenv_output" || fail 'Could not apply the Homebrew environment returned by brew shellenv.'
}

ensure_uv() {
  bootstrap_homebrew
  initialize_homebrew_environment

  if ! command -v uv >/dev/null 2>&1; then
    log 'UV was not found. Installing it through Homebrew.'
    if ! "$BREW_BIN" install uv; then
      fail 'Homebrew could not install UV. Check the Homebrew output and rerun setup.'
    fi
  fi

  command -v uv >/dev/null 2>&1 || fail 'UV is still unavailable after Homebrew setup. Check PATH and the Homebrew installation.'
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

sync_project_environment() {
  [[ -f "$PROJECT_ROOT/.python-version" ]] || fail 'Missing .python-version in the project root.'
  [[ -f "$PROJECT_ROOT/uv.lock" ]] || fail 'Missing uv.lock. Run uv lock to generate the project lockfile.'

  cd "$PROJECT_ROOT"
  log 'Installing the pinned Python version and synchronizing the locked project environment with UV.'
  uv python install "$(cat "$PROJECT_ROOT/.python-version")"
  uv sync --locked
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
  exec uv run --locked streamlit run streamlit_app.py
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
ensure_uv

prompt_for_value API_KEY 'Google AI Studio API key' true
prompt_for_value GIT_NAME 'Git user name'
prompt_for_value GIT_EMAIL 'Git user email (user@thoughtworks.com)'

sync_project_environment
write_env_file "$API_KEY" "$GIT_NAME" "$GIT_EMAIL"
ensure_git_repo "$GIT_NAME" "$GIT_EMAIL"

cat <<EOF

Setup complete.

Next steps:
  scripts/run_workshop.sh

EOF

if [[ "$RUN_AFTER_SETUP" == 'true' ]]; then
  start_streamlit
fi
