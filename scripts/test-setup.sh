#!/usr/bin/env bash

set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"
require_commands curl sha256sum tar zstd

readonly TEST_DIR="$(mktemp -d)"
trap 'rm -rf "${TEST_DIR}"' EXIT

readonly VERSION="v0.0.0-test"
readonly ARCHIVE_NAME="bloodhound-microvm-${VERSION}-x86_64.tar.zst"
readonly ARCHIVE_PATH="${TEST_DIR}/${ARCHIVE_NAME}"
readonly SOURCE_DIR="${TEST_DIR}/source/bloodhound-microvm-x86_64"
readonly OUTPUT_FILE="${TEST_DIR}/github-output"
readonly DESTINATION="${TEST_DIR}/installed"

mkdir -p "${SOURCE_DIR}"
touch \
  "${SOURCE_DIR}/System.map" \
  "${SOURCE_DIR}/bloodhound" \
  "${SOURCE_DIR}/kernel.config" \
  "${SOURCE_DIR}/kernel.release" \
  "${SOURCE_DIR}/rootfs.ext4" \
  "${SOURCE_DIR}/vmlinux"
printf '#!/usr/bin/env bash\n' >"${SOURCE_DIR}/firecracker"
printf '#!/usr/bin/env bash\n' >"${SOURCE_DIR}/firectl"
chmod 0755 "${SOURCE_DIR}/firecracker" "${SOURCE_DIR}/firectl"
echo '{"schema_version":1}' >"${SOURCE_DIR}/manifest.json"
(
  cd "${SOURCE_DIR}"
  sha256sum System.map bloodhound firecracker firectl kernel.config kernel.release manifest.json rootfs.ext4 vmlinux >SHA256SUMS
)
tar --create --file "${ARCHIVE_PATH}" --zstd --directory "${TEST_DIR}/source" bloodhound-microvm-x86_64
readonly ARCHIVE_SHA256="$(sha256sum "${ARCHIVE_PATH}" | cut -d ' ' -f 1)"

BUNDLE_DESTINATION="${DESTINATION}" \
BUNDLE_SHA256="${ARCHIVE_SHA256}" \
BUNDLE_URL="file://${ARCHIVE_PATH}" \
BUNDLE_VERSION="${VERSION}" \
GITHUB_OUTPUT="${OUTPUT_FILE}" \
RUNNER_TEMP="${TEST_DIR}" \
  "${REPOSITORY_ROOT}/setup/setup.sh"

grep -Fxq "kernel-path=${DESTINATION}/vmlinux" "${OUTPUT_FILE}"
grep -Fxq "rootfs-path=${DESTINATION}/rootfs.ext4" "${OUTPUT_FILE}"
test -x "${DESTINATION}/firecracker"
test -x "${DESTINATION}/firectl"

if BUNDLE_DESTINATION="${TEST_DIR}/bad-digest" \
    BUNDLE_SHA256="$(printf '0%.0s' {1..64})" \
    BUNDLE_URL="file://${ARCHIVE_PATH}" \
    BUNDLE_VERSION="${VERSION}" \
    GITHUB_OUTPUT="${TEST_DIR}/bad-output" \
    RUNNER_TEMP="${TEST_DIR}" \
    "${REPOSITORY_ROOT}/setup/setup.sh" >/dev/null 2>&1; then
  echo "setup accepted an archive with the wrong digest" >&2
  exit 1
fi
