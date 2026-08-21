#!/usr/bin/env bash

set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"
load_versions
require_x86_64
require_commands cp grep kill seq sleep tail

readonly OUTPUT_DIR="${1:-${REPOSITORY_ROOT}/dist}"
readonly WORK_DIR="${REPOSITORY_ROOT}/work/smoke"
readonly FIRECRACKER_BIN="${OUTPUT_DIR}/firecracker"
readonly FIRECTL_BIN="${OUTPUT_DIR}/firectl"
readonly VM_LOG="${WORK_DIR}/vm.log"
readonly SMOKE_ROOTFS="${WORK_DIR}/rootfs.ext4"

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
if [[ ! -x "${FIRECRACKER_BIN}" || ! -x "${FIRECTL_BIN}" ]]; then
  echo "bundle does not contain executable Firecracker and firectl binaries" >&2
  exit 1
fi
cp --reflink=auto --sparse=always "${OUTPUT_DIR}/rootfs.ext4" "${SMOKE_ROOTFS}"

"${FIRECTL_BIN}" \
  --firecracker-binary="${FIRECRACKER_BIN}" \
  --kernel="${OUTPUT_DIR}/vmlinux" \
  --root-drive="${SMOKE_ROOTFS}:rw" \
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
