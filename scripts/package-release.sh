#!/usr/bin/env bash

set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"
require_x86_64
require_commands cp install sha256sum tar zstd

readonly VERSION="${1:?usage: package-release.sh <version> [bundle-dir] [release-dir]}"
readonly BUNDLE_DIR="${2:-${REPOSITORY_ROOT}/dist}"
readonly RELEASE_DIR="${3:-${REPOSITORY_ROOT}/release}"
readonly STAGING_ROOT="${REPOSITORY_ROOT}/work/release/${VERSION}"
readonly STAGING_DIR="${STAGING_ROOT}/bloodhound-microvm-x86_64"
readonly ARCHIVE_NAME="bloodhound-microvm-${VERSION}-x86_64.tar.zst"
readonly ARCHIVE_PATH="${RELEASE_DIR}/${ARCHIVE_NAME}"

if [[ ! "${VERSION}" =~ ^v[0-9]+\.[0-9]+\.[0-9]+([.-][0-9A-Za-z.-]+)?$ ]]; then
  echo "version must be a v-prefixed semantic version: ${VERSION}" >&2
  exit 1
fi

readonly BUNDLE_FILES=(
  SHA256SUMS
  System.map
  bloodhound
  firecracker
  firectl
  kernel.config
  kernel.release
  manifest.json
  rootfs.ext4
  vmlinux
)

for file in "${BUNDLE_FILES[@]}"; do
  if [[ ! -f "${BUNDLE_DIR}/${file}" ]]; then
    echo "bundle file is missing: ${BUNDLE_DIR}/${file}" >&2
    exit 1
  fi
done

rm -rf "${STAGING_ROOT}"
mkdir -p "${STAGING_DIR}" "${RELEASE_DIR}"
for file in "${BUNDLE_FILES[@]}"; do
  cp --reflink=auto --sparse=always "${BUNDLE_DIR}/${file}" "${STAGING_DIR}/${file}"
done
install -m 0644 "${REPOSITORY_ROOT}/LICENSE" "${STAGING_DIR}/LICENSE"
install -m 0644 "${REPOSITORY_ROOT}/THIRD_PARTY_NOTICES.md" "${STAGING_DIR}/THIRD_PARTY_NOTICES.md"

tar \
  --create \
  --file "${ARCHIVE_PATH}" \
  --sparse \
  --sort=name \
  --mtime='UTC 1970-01-01' \
  --owner=0 \
  --group=0 \
  --numeric-owner \
  --zstd \
  --directory "${STAGING_ROOT}" \
  bloodhound-microvm-x86_64

(
  cd "${RELEASE_DIR}"
  sha256sum "${ARCHIVE_NAME}" >"${ARCHIVE_NAME}.sha256"
)

echo "${ARCHIVE_PATH}"
echo "${ARCHIVE_PATH}.sha256"
