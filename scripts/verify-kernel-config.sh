#!/usr/bin/env bash

set -euo pipefail

readonly CONFIG_PATH="${1:?usage: verify-kernel-config.sh <kernel.config>}"

readonly REQUIRED_OPTIONS=(
  CONFIG_AUDIT
  CONFIG_AUDITSYSCALL
  CONFIG_BPF
  CONFIG_BPF_EVENTS
  CONFIG_BPF_JIT
  CONFIG_BPF_LSM
  CONFIG_BPF_SYSCALL
  CONFIG_CGROUP_BPF
  CONFIG_DEBUG_INFO_BTF
  CONFIG_FTRACE
  CONFIG_FTRACE_SYSCALLS
  CONFIG_KPROBES
  CONFIG_KPROBE_EVENTS
  CONFIG_NET_CLS_ACT
  CONFIG_NET_SCH_INGRESS
  CONFIG_PERF_EVENTS
  CONFIG_SECURITY
  CONFIG_SECURITYFS
  CONFIG_SERIAL_8250_CONSOLE
  CONFIG_VIRTIO_BLK
)

for option in "${REQUIRED_OPTIONS[@]}"; do
  if ! grep -Fxq "${option}=y" "${CONFIG_PATH}"; then
    echo "required kernel option is not built in: ${option}" >&2
    exit 1
  fi
done

if ! grep -E '^CONFIG_LSM=.*(^|,)bpf(,|"$)' "${CONFIG_PATH}" >/dev/null; then
  echo "CONFIG_LSM must contain bpf" >&2
  exit 1
fi
