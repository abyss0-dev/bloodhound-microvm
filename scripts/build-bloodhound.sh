#!/usr/bin/env bash

set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"
load_versions
require_x86_64

readonly OUTPUT_DIR="${1:-${REPOSITORY_ROOT}/dist}"
readonly WORK_DIR="${2:-${REPOSITORY_ROOT}/work/bloodhound}"
readonly SOURCE_DIR="${WORK_DIR}/source"

mkdir -p "${OUTPUT_DIR}" "${WORK_DIR}"
if [[ ! -d "${SOURCE_DIR}/.git" ]]; then
  git init --quiet "${SOURCE_DIR}"
  git -C "${SOURCE_DIR}" remote add origin https://github.com/abyss0-dev/bloodhound.git
fi
git -C "${SOURCE_DIR}" fetch --quiet --depth=1 origin "${BLOODHOUND_COMMIT}"
git -C "${SOURCE_DIR}" checkout --quiet --detach FETCH_HEAD
make -C "${SOURCE_DIR}" build-docker
install -m 0755 "${SOURCE_DIR}/target/docker/bloodhound" "${OUTPUT_DIR}/bloodhound"
