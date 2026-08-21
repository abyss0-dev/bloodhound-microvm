# Bloodhound microVM

This repository builds reusable Firecracker microVM artifacts for abyss0 E2E
tests that require Bloodhound. It owns the compatibility boundary between the
guest kernel, Bloodhound, and the base root filesystem.

Consumers receive one immutable bundle:

- `vmlinux`: the Firecracker guest kernel with the eBPF features required by
  Bloodhound;
- `rootfs.ext4`: an Ubuntu 24.04 root filesystem with Bloodhound installed and
  enabled;
- `kernel.config`: the resolved kernel configuration;
- `System.map`: the matching kernel symbol map;
- `manifest.json` and `SHA256SUMS`: source provenance and artifact digests.

Sanjaya, Anubis, story fixtures, and exercise-specific configuration do not
belong in the base image. A consumer adds those as a run-specific payload and
replaces or extends the base systemd units.

## Pinned compatibility set

The initial x86_64 bundle uses:

- Firecracker `v1.16.1`;
- Amazon Linux kernel tag `kernel6.18-6.18.39-79.141.amzn2023`;
- the Firecracker 6.18 guest config at commit
  `ca0b24d0c6cd4592dc541ff48cb94107869f9692`;
- Bloodhound commit `46ff1dba3bf85b824bd57eb62aeb6afd04d65b14`.

The Firecracker config is extended by
[`config/bloodhound.fragment`](config/bloodhound.fragment). The resolved config
is checked before compilation; missing BTF, BPF LSM, audit, kprobe, tracepoint,
or traffic-control support fails the build.

## Build and verify

On Ubuntu 24.04 with Docker and KVM:

```console
$ mise install
$ mise run build
$ mise run smoke
```

`mise run build` creates `dist/`. `mise run smoke` boots the generated rootfs
with firectl and succeeds only after Bloodhound reports that its BPF programs
are attached and emits a heartbeat through its NDJSON output.

The GitHub Actions workflow runs the same path on an `ubuntu-24.04`
GitHub-hosted runner. Kernel and source inputs are selected by immutable tag,
commit, and checksum; Actions are pinned by commit SHA.

## Consumer contract

The base image proves collector readiness, not application readiness. Consumer
E2E tests must additionally verify the downstream component and the intended
pipeline, such as `Bloodhound stdout -> Sanjaya stdin`. A successful boot or an
active systemd unit alone is not sufficient readiness evidence.
