#!/usr/bin/env bash

set -euo pipefail

readonly VERSION="${BUNDLE_VERSION:?BUNDLE_VERSION is required}"
readonly EXPECTED_SHA256="${BUNDLE_SHA256:?BUNDLE_SHA256 is required}"
readonly ARCHIVE_NAME="bloodhound-microvm-${VERSION}-x86_64.tar.zst"
readonly DOWNLOAD_URL="${BUNDLE_URL:-https://github.com/abyss0-dev/bloodhound-microvm/releases/download/${VERSION}/${ARCHIVE_NAME}}"
readonly DESTINATION="${BUNDLE_DESTINATION:-${RUNNER_TEMP:?RUNNER_TEMP is required}/bloodhound-microvm-${VERSION}}"
readonly TEMP_DIR="$(mktemp -d)"
readonly ARCHIVE_PATH="${TEMP_DIR}/${ARCHIVE_NAME}"
trap 'rm -rf "${TEMP_DIR}"' EXIT

if [[ ! "${VERSION}" =~ ^v[0-9]+\.[0-9]+\.[0-9]+([.-][0-9A-Za-z.-]+)?$ ]]; then
  echo "version must be a v-prefixed semantic version: ${VERSION}" >&2
  exit 1
fi
if [[ ! "${EXPECTED_SHA256}" =~ ^[0-9a-f]{64}$ ]]; then
  echo "sha256 must be exactly 64 lowercase hexadecimal characters" >&2
  exit 1
fi
if [[ "$(uname -m)" != "x86_64" ]]; then
  echo "Bloodhound microVM release bundles currently support only x86_64" >&2
  exit 1
fi
for command in curl sha256sum tar zstd; do
  if ! command -v "${command}" >/dev/null; then
    echo "required command is not installed: ${command}" >&2
    exit 1
  fi
done
if [[ -e "${DESTINATION}" ]] && find "${DESTINATION}" -mindepth 1 -print -quit | grep -q .; then
  echo "destination must be absent or empty: ${DESTINATION}" >&2
  exit 1
fi

mkdir -p "${DESTINATION}"
curl --fail --location --retry 3 --silent --show-error \
  --output "${ARCHIVE_PATH}" \
  "${DOWNLOAD_URL}"
echo "${EXPECTED_SHA256}  ${ARCHIVE_PATH}" | sha256sum --check
tar --extract --file "${ARCHIVE_PATH}" --zstd --strip-components=1 --directory "${DESTINATION}"

(
  cd "${DESTINATION}"
  sha256sum --check SHA256SUMS
)

for file in vmlinux rootfs.ext4 firecracker firectl manifest.json; do
  if [[ ! -f "${DESTINATION}/${file}" ]]; then
    echo "verified bundle is missing required file: ${file}" >&2
    exit 1
  fi
done
if [[ ! -x "${DESTINATION}/firecracker" || ! -x "${DESTINATION}/firectl" ]]; then
  echo "runtime tool binaries are not executable" >&2
  exit 1
fi

{
  echo "bundle-path=${DESTINATION}"
  echo "kernel-path=${DESTINATION}/vmlinux"
  echo "rootfs-path=${DESTINATION}/rootfs.ext4"
  echo "firecracker-path=${DESTINATION}/firecracker"
  echo "firectl-path=${DESTINATION}/firectl"
  echo "manifest-path=${DESTINATION}/manifest.json"
} >>"${GITHUB_OUTPUT:?GITHUB_OUTPUT is required}"
