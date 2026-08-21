#!/usr/bin/env bash

set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"
require_x86_64

readonly OUTPUT_DIR="${1:-${REPOSITORY_ROOT}/dist}"
readonly WORK_DIR="${2:-${REPOSITORY_ROOT}/work/rootfs}"
readonly CONTEXT_DIR="${WORK_DIR}/context"
readonly ROOTFS_TAR="${WORK_DIR}/rootfs.tar"
readonly ROOTFS_TREE="${WORK_DIR}/tree"
readonly IMAGE_TAG="bloodhound-microvm-rootfs"

mkdir -p "${OUTPUT_DIR}" "${CONTEXT_DIR}"
install -m 0755 "${OUTPUT_DIR}/bloodhound" "${CONTEXT_DIR}/bloodhound"
install -m 0644 "${REPOSITORY_ROOT}/rootfs/Dockerfile" "${CONTEXT_DIR}/Dockerfile"
install -m 0644 "${REPOSITORY_ROOT}/rootfs/bloodhound.service" "${CONTEXT_DIR}/bloodhound.service"
install -m 0644 "${REPOSITORY_ROOT}/rootfs/bloodhound-ready.service" "${CONTEXT_DIR}/bloodhound-ready.service"
install -m 0644 "${REPOSITORY_ROOT}/rootfs/journald-console.conf" "${CONTEXT_DIR}/journald-console.conf"

docker build --quiet --tag "${IMAGE_TAG}" "${CONTEXT_DIR}"
container_id="$(docker create "${IMAGE_TAG}")"
trap 'docker rm --force "${container_id}" >/dev/null 2>&1 || true' EXIT
docker export "${container_id}" --output "${ROOTFS_TAR}"
docker rm "${container_id}" >/dev/null
container_id=""

docker run --rm \
  --mount "type=bind,src=${WORK_DIR},dst=/work" \
  ubuntu:24.04 \
  /bin/bash -euc '
    apt-get update >/dev/null
    DEBIAN_FRONTEND=noninteractive apt-get install --yes --no-install-recommends e2fsprogs >/dev/null
    rm -rf /work/tree
    mkdir -p /work/tree
    tar -xf /work/rootfs.tar -C /work/tree
    rm -f /work/tree/.dockerenv
    truncate -s 2G /work/rootfs.ext4
    mkfs.ext4 -F -d /work/tree /work/rootfs.ext4 >/dev/null
  '
install -m 0644 "${WORK_DIR}/rootfs.ext4" "${OUTPUT_DIR}/rootfs.ext4"
