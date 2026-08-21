#!/usr/bin/env bash

set -euo pipefail

readonly REPOSITORY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

load_versions() {
  set -a
  # shellcheck source=../versions.env
  source "${REPOSITORY_ROOT}/versions.env"
  set +a
}

require_x86_64() {
  if [[ "$(uname -m)" != "x86_64" ]]; then
    echo "bloodhound-microVM currently supports only x86_64" >&2
    exit 1
  fi
}

require_commands() {
  local command
  for command in "$@"; do
    if ! command -v "${command}" >/dev/null; then
      echo "required command is not installed: ${command}" >&2
      exit 1
    fi
  done
}
