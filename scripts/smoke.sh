#!/usr/bin/env bash

set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"
load_versions
require_x86_64

readonly OUTPUT_DIR="${1:-${REPOSITORY_ROOT}/dist}"
readonly WORK_DIR="${REPOSITORY_ROOT}/work/smoke"
readonly FIRECRACKER_ARCHIVE="firecracker-${FIRECRACKER_VERSION}-x86_64.tgz"
readonly FIRECRACKER_RELEASE_DIR="${WORK_DIR}/release-${FIRECRACKER_VERSION}-x86_64"
readonly FIRECRACKER_BIN="${FIRECRACKER_RELEASE_DIR}/firecracker-${FIRECRACKER_VERSION}-x86_64"
readonly FIRECTL_SOURCE="${WORK_DIR}/firectl"
readonly FIRECTL_BIN="${WORK_DIR}/firectl-bin"
readonly VM_LOG="${WORK_DIR}/vm.log"

vm_pid=""
cleanup() {
  if [[ -n "${vm_pid}" ]] && kill -0 "${vm_pid}" 2>/dev/null; then
    kill -QUIT "${vm_pid}" 2>/dev/null || true
    for _ in $(seq 1 50); do
      kill -0 "${vm_pid}" 2>/dev/null || break
      sleep 0.1
    done
    kill -KILL "${vm_pid}" 2>/dev/null || true
    wait "${vm_pid}" 2>/dev/null || true
  fi
}
trap cleanup EXIT

if [[ ! -r /dev/kvm || ! -w /dev/kvm ]]; then
  echo "smoke test requires readable and writable /dev/kvm" >&2
  exit 1
fi

mkdir -p "${WORK_DIR}"
curl -fsSLo "${WORK_DIR}/${FIRECRACKER_ARCHIVE}" \
  "https://github.com/firecracker-microvm/firecracker/releases/download/${FIRECRACKER_VERSION}/${FIRECRACKER_ARCHIVE}"
echo "${FIRECRACKER_ARCHIVE_SHA256}  ${WORK_DIR}/${FIRECRACKER_ARCHIVE}" | sha256sum --check
tar -xzf "${WORK_DIR}/${FIRECRACKER_ARCHIVE}" -C "${WORK_DIR}"

if [[ ! -d "${FIRECTL_SOURCE}/.git" ]]; then
  git init --quiet "${FIRECTL_SOURCE}"
  git -C "${FIRECTL_SOURCE}" remote add origin https://github.com/firecracker-microvm/firectl.git
fi
git -C "${FIRECTL_SOURCE}" fetch --quiet --depth=1 origin "${FIRECTL_COMMIT}"
git -C "${FIRECTL_SOURCE}" checkout --quiet --detach FETCH_HEAD
(
  cd "${FIRECTL_SOURCE}"
  GOPROXY="https://proxy.golang.org,direct" go build -trimpath -o "${FIRECTL_BIN}" .
)

"${FIRECTL_BIN}" \
  --firecracker-binary="${FIRECRACKER_BIN}" \
  --kernel="${OUTPUT_DIR}/vmlinux" \
  --root-drive="${OUTPUT_DIR}/rootfs.ext4:rw" \
  --ncpus=2 \
  --memory=2048 \
  --kernel-opts="root=/dev/vda rw console=ttyS0 reboot=k panic=1 pci=off lsm=landlock,lockdown,yama,apparmor,bpf" \
  >"${VM_LOG}" 2>&1 &
vm_pid=$!

for _ in $(seq 1 240); do
  if grep -Fq "Bloodhound microVM ready" "${VM_LOG}" && \
      grep -Fq "BPF programs loaded and attached" "${VM_LOG}"; then
    echo "Bloodhound-ready Firecracker microVM booted successfully."
    exit 0
  fi
  if grep -Fq "Bloodhound microVM readiness failed" "${VM_LOG}"; then
    break
  fi
  if ! kill -0 "${vm_pid}" 2>/dev/null; then
    break
  fi
  sleep 0.5
done

echo "Bloodhound microVM did not become ready" >&2
tail -n 360 "${VM_LOG}" >&2
exit 1
