---
name: Execution hierarchy
description: QEMU/KVM > Incus > Docker > host; tier purpose, image selection, cleanup rules
type: user
---

Never run anything directly on the host unless no lower option works. Always use the lowest viable level:

1. **QEMU/KVM** — full OS isolation; required when the test needs a real kernel, firmware, or hardware emulation
2. **Incus** — distro-level tests that require systemd or a full init system; preferred for service installs and OS config testing
3. **Docker** — build, unit test, and integration work that does not need systemd; always use the official alpine variant for the stack
4. **Host** — last resort only (e.g. USB device access with no passthrough, host socket that cannot be forwarded)

## Image selection by tier

| Tier | Image to use | When |
|------|-------------|------|
| Docker | Official alpine variant: `golang:alpine`, `rust:alpine`, `node:alpine`, etc. | Build, test, debug — never debian/ubuntu based |
| Incus | Distro image matching the target OS | systemd, service installs, OS config, distro compatibility |
| QEMU/KVM | Full OS image matching the target OS | Kernel-level, firmware, hardware emulation, full install testing |

## Cleanup rules

- **Stop and remove immediately** — every container, VM, volume, network, and temp file must be torn down as soon as it is no longer needed. Never leave them running until session end.
- **Track what you start** — note the name/ID of every container or VM before starting it; guarantee it appears in the cleanup step of the same task.
- Only remove resources created by the current project — never `docker system prune` or broad sweeps.
- Identify resources by name/label/prefix before removing; if uncertain, list and ask.

## Scope

**This applies to everything:** build toolchains (`cargo`, `gradle`, `go build`), project binaries, `./scripts/`, `./tests/`, and system install scripts.

**Why:** install scripts modify OS config and install system services — running them on the host trashes the developer's machine.

**Scripts that seem to require host access** (`install-to-device.sh`, `dev-shell.sh`, some `./tests/*`): still check whether a VM or container can satisfy the requirement (USB passthrough, socket forwarding, Docker-in-Docker) before falling back to host.
