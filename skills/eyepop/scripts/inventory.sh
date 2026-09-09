#!/usr/bin/env bash
# List what this account can run: models, your abilities, Pops, deployments, instances, datasets.
# Usage: inventory.sh [text|json]   (default text)
set -u

fmt=${1:-text}

section() {
  printf '\n## %s\n' "$1"
}

show() {
  local out
  if out=$(eyepop "$@" --format "$fmt" 2>&1); then
    if [ -n "$out" ]; then printf '%s\n' "$out"; else echo "(none)"; fi
  else
    echo "(error) $(printf '%s\n' "$out" | head -1)"
  fi
}

section "models: eyepop get models";              show get models
section "your abilities: eyepop get abilities --mine"; show get abilities --mine
section "pops: eyepop get pops";                  show get pops
section "deployments: eyepop get deployments";    show get deployments
section "instances: eyepop get instances";        show get instances
section "datasets: eyepop get datasets";          show get datasets
