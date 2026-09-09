#!/usr/bin/env bash
# Report whether this machine can talk to EyePop: CLI present, credentials, reachability.
# Exit codes: 0 ready, 2 CLI missing, 3 no credentials, 4 unreachable or rejected.
set -u

os=$(uname -s 2>/dev/null || echo unknown)
arch=$(uname -m 2>/dev/null || echo unknown)
echo "platform: $os $arch"

if ! command -v eyepop >/dev/null 2>&1; then
  echo "cli: missing"
  brew_install='brew tap eyepop-ai/eyepop && brew trust eyepop-ai/eyepop && brew install eyepop'
  script_install='curl -fsSL https://raw.githubusercontent.com/eyepop-ai/homebrew-eyepop/main/install.sh | sh'
  case "$os" in
    Darwin) echo "install: $brew_install" ;;
    Linux)
      if command -v brew >/dev/null 2>&1; then echo "install: $brew_install"; else echo "install: $script_install"; fi ;;
    MINGW*|MSYS*|CYGWIN*|Windows_NT)
      echo "install: download eyepop-v<version>-x86_64-pc-windows-msvc.zip from https://github.com/eyepop-ai/homebrew-eyepop/releases/latest, unzip, put eyepop.exe on PATH" ;;
    *) echo "install: see https://docs.eyepop.ai/developer-documentation/cli" ;;
  esac
  if [ -x "$HOME/.local/bin/eyepop" ]; then
    echo "note: $HOME/.local/bin/eyepop exists but is not on PATH. Run: export PATH=\"\$HOME/.local/bin:\$PATH\""
  fi
  exit 2
fi
version=$(eyepop --version 2>&1 | head -1)
if printf '%s\n' "${version#eyepop }" | awk -F. '{ exit !($1 > 0 || ($1 == 0 && $2 >= 18)) }'; then
  echo "cli: $version"
else
  echo "cli: $version (older than 0.18.0; run: eyepop update)"
fi

if [ -n "${EYEPOP_API_KEY:-}" ]; then
  echo "auth: EYEPOP_API_KEY is set"
else
  status=$(eyepop auth status --json 2>&1)
  email=$(printf '%s\n' "$status" | sed -n 's/.*"email": *"\([^"]*\)".*/\1/p' | head -1)
  if [ -n "$email" ]; then
    echo "auth: browser session as $email"
  else
    echo "auth: none"
    echo "next: export EYEPOP_API_KEY=eyp_... for scripts and agents, or run eyepop auth login at a terminal"
    exit 3
  fi
fi

if out=$(eyepop get models --format text 2>&1); then
  echo "reachable: yes"
  echo "status: READY"
else
  echo "reachable: no"
  echo "error: $(printf '%s\n' "$out" | head -1)"
  echo "next: an expired token means eyepop auth login; otherwise check EYEPOP_API_KEY and the network"
  exit 4
fi
