#!/usr/bin/env bash

set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"
load_versions

readonly OUTPUT_DIR="${1:-${REPOSITORY_ROOT}/dist}"
mkdir -p "${OUTPUT_DIR}"

"${REPOSITORY_ROOT}/scripts/build-kernel.sh" "${OUTPUT_DIR}"
"${REPOSITORY_ROOT}/scripts/build-bloodhound.sh" "${OUTPUT_DIR}"
"${REPOSITORY_ROOT}/scripts/build-runtime-tools.sh" "${OUTPUT_DIR}"
"${REPOSITORY_ROOT}/scripts/build-rootfs.sh" "${OUTPUT_DIR}"
"${REPOSITORY_ROOT}/scripts/write-manifest.sh" "${OUTPUT_DIR}"
