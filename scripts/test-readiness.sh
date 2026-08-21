#!/usr/bin/env bash

set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

readonly TEST_DIR="$(mktemp -d)"
trap 'rm -rf "${TEST_DIR}"' EXIT

readonly JOURNALCTL_STUB="${TEST_DIR}/journalctl"
readonly TEST_EVENT_LOG="${TEST_DIR}/bloodhound.ndjson"
readonly TEST_CONSOLE="${TEST_DIR}/console"

cat >"${JOURNALCTL_STUB}" <<'EOF'
#!/usr/bin/env bash
echo "BPF programs loaded and attached"
EOF
chmod 0755 "${JOURNALCTL_STUB}"

echo '{"event":{"type":"HEARTBEAT","name":"heartbeat"}}' >"${TEST_EVENT_LOG}"

JOURNALCTL_BIN="${JOURNALCTL_STUB}" \
EVENT_LOG="${TEST_EVENT_LOG}" \
CONSOLE="${TEST_CONSOLE}" \
READINESS_ATTEMPTS=1 \
READINESS_INTERVAL_SECONDS=0 \
  "${REPOSITORY_ROOT}/rootfs/bloodhound-ready"

grep -Fxq "Bloodhound microVM ready" "${TEST_CONSOLE}"

echo '{"event":{"type":"SYSCALL","name":"execve"}}' >"${TEST_EVENT_LOG}"
if JOURNALCTL_BIN="${JOURNALCTL_STUB}" \
    EVENT_LOG="${TEST_EVENT_LOG}" \
    CONSOLE="${TEST_CONSOLE}" \
    READINESS_ATTEMPTS=1 \
    READINESS_INTERVAL_SECONDS=0 \
    "${REPOSITORY_ROOT}/rootfs/bloodhound-ready"; then
  echo "readiness succeeded without a heartbeat" >&2
  exit 1
fi

grep -Fxq "Bloodhound microVM readiness failed" "${TEST_CONSOLE}"
