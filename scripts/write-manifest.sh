#!/usr/bin/env bash

set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"
load_versions
require_commands jq sha256sum

readonly OUTPUT_DIR="${1:-${REPOSITORY_ROOT}/dist}"

jq -n \
  --arg architecture x86_64 \
  --arg firecracker_version "${FIRECRACKER_VERSION}" \
  --arg firectl_commit "${FIRECTL_COMMIT}" \
  --arg kernel_tag "${KERNEL_TAG}" \
  --arg kernel_commit "${KERNEL_COMMIT}" \
  --arg firecracker_config_commit "${FIRECRACKER_CONFIG_COMMIT}" \
  --arg bloodhound_commit "${BLOODHOUND_COMMIT}" \
  '{
    schema_version: 1,
    architecture: $architecture,
    firecracker: {version: $firecracker_version},
    firectl: {commit: $firectl_commit},
    kernel: {tag: $kernel_tag, commit: $kernel_commit, firecracker_config_commit: $firecracker_config_commit},
    bloodhound: {commit: $bloodhound_commit}
  }' >"${OUTPUT_DIR}/manifest.json"

(
  cd "${OUTPUT_DIR}"
  sha256sum System.map bloodhound firecracker firectl kernel.config kernel.release manifest.json rootfs.ext4 vmlinux >SHA256SUMS
)
