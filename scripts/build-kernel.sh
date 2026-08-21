#!/usr/bin/env bash

set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"
load_versions
require_x86_64
require_commands bison flex gcc make pahole python3

readonly OUTPUT_DIR="${1:-${REPOSITORY_ROOT}/dist}"
readonly WORK_DIR="${2:-${REPOSITORY_ROOT}/work/kernel}"
readonly SOURCE_DIR="${WORK_DIR}/linux"
readonly BASE_CONFIG="${WORK_DIR}/firecracker.config"

mkdir -p "${OUTPUT_DIR}" "${WORK_DIR}"

if [[ ! -d "${SOURCE_DIR}/.git" ]]; then
  git init --quiet "${SOURCE_DIR}"
  git -C "${SOURCE_DIR}" remote add origin https://github.com/amazonlinux/linux.git
fi
git -C "${SOURCE_DIR}" fetch --quiet --depth=1 origin "refs/tags/${KERNEL_TAG}"
git -C "${SOURCE_DIR}" checkout --quiet --detach FETCH_HEAD
if [[ "$(git -C "${SOURCE_DIR}" rev-parse HEAD)" != "${KERNEL_COMMIT}" ]]; then
  echo "Amazon Linux kernel tag resolved to an unexpected commit" >&2
  exit 1
fi

curl -fsSLo "${BASE_CONFIG}" \
  "https://raw.githubusercontent.com/firecracker-microvm/firecracker/${FIRECRACKER_CONFIG_COMMIT}/resources/guest_configs/microvm-kernel-ci-x86_64-6.18.config"
echo "${FIRECRACKER_CONFIG_SHA256}  ${BASE_CONFIG}" | sha256sum --check

cp "${BASE_CONFIG}" "${SOURCE_DIR}/.config"
while IFS='=' read -r option value; do
  [[ -n "${option}" && "${option}" == CONFIG_* ]] || continue
  case "${value}" in
    y) "${SOURCE_DIR}/scripts/config" --file "${SOURCE_DIR}/.config" --enable "${option#CONFIG_}" ;;
    m) "${SOURCE_DIR}/scripts/config" --file "${SOURCE_DIR}/.config" --module "${option#CONFIG_}" ;;
    n) "${SOURCE_DIR}/scripts/config" --file "${SOURCE_DIR}/.config" --disable "${option#CONFIG_}" ;;
    *) echo "unsupported config fragment value: ${option}=${value}" >&2; exit 1 ;;
  esac
done <"${REPOSITORY_ROOT}/config/bloodhound.fragment"

make -C "${SOURCE_DIR}" olddefconfig
"${REPOSITORY_ROOT}/scripts/verify-kernel-config.sh" "${SOURCE_DIR}/.config"
make -C "${SOURCE_DIR}" -j"$(nproc)" vmlinux

install -m 0644 "${SOURCE_DIR}/vmlinux" "${OUTPUT_DIR}/vmlinux"
install -m 0644 "${SOURCE_DIR}/.config" "${OUTPUT_DIR}/kernel.config"
install -m 0644 "${SOURCE_DIR}/System.map" "${OUTPUT_DIR}/System.map"
make -s -C "${SOURCE_DIR}" kernelrelease >"${OUTPUT_DIR}/kernel.release"
