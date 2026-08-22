#!/usr/bin/env bash

set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"
load_versions
require_x86_64
require_commands curl git go install sha256sum tar

readonly OUTPUT_DIR="${1:-${REPOSITORY_ROOT}/dist}"
readonly WORK_DIR="${2:-${REPOSITORY_ROOT}/work/runtime-tools}"
readonly FIRECRACKER_ARCHIVE="firecracker-${FIRECRACKER_VERSION}-x86_64.tgz"
readonly FIRECRACKER_RELEASE_DIR="${WORK_DIR}/release-${FIRECRACKER_VERSION}-x86_64"
readonly FIRECTL_SOURCE="${WORK_DIR}/firectl"

mkdir -p "${OUTPUT_DIR}" "${WORK_DIR}"

curl -fsSLo "${WORK_DIR}/${FIRECRACKER_ARCHIVE}" \
  "https://github.com/firecracker-microvm/firecracker/releases/download/${FIRECRACKER_VERSION}/${FIRECRACKER_ARCHIVE}"
echo "${FIRECRACKER_ARCHIVE_SHA256}  ${WORK_DIR}/${FIRECRACKER_ARCHIVE}" | sha256sum --check
tar -xzf "${WORK_DIR}/${FIRECRACKER_ARCHIVE}" -C "${WORK_DIR}"
install -m 0755 \
  "${FIRECRACKER_RELEASE_DIR}/firecracker-${FIRECRACKER_VERSION}-x86_64" \
  "${OUTPUT_DIR}/firecracker"

if [[ ! -d "${FIRECTL_SOURCE}/.git" ]]; then
  git init --quiet "${FIRECTL_SOURCE}"
  git -C "${FIRECTL_SOURCE}" remote add origin https://github.com/firecracker-microvm/firectl.git
fi
git -C "${FIRECTL_SOURCE}" fetch --quiet --depth=1 origin "${FIRECTL_COMMIT}"
git -C "${FIRECTL_SOURCE}" checkout --quiet --detach FETCH_HEAD
(
  cd "${FIRECTL_SOURCE}"
  GOPROXY="${GOPROXY:-https://proxy.golang.org,direct}" \
    go build -trimpath -o "${OUTPUT_DIR}/firectl" .
)
