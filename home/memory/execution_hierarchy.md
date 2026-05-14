---
name: Execution hierarchy
description: VM > Incus > Docker > host; applies to everything including scripts and system installers
type: user
---

Never run anything directly on the host unless no lower option works. Always use the lowest viable level:

1. **VM** — best isolation; required for system-level scripts (service installs, OS config, package management)
2. **Incus** — preferred container runtime if installed
3. **Docker** — fallback
4. **Host** — last resort only (e.g. USB device access with no passthrough, host socket that cannot be forwarded)

**This applies to everything:** build toolchains (cargo, gradle, go build), project binaries, ./scripts/, ./tests/, and system install scripts.

**Why:** `scriptmgr/*/install.sh` scripts install system services and modify OS config — they'd trash the developer's host. Test them in a VM or Incus container running the target distro instead.

**Scripts that seem to require host access** (install-to-device.sh, dev-shell.sh, some ./tests/*): still check whether VM/container can satisfy the requirement (USB passthrough, socket forwarding, Docker-in-Docker) before falling back to host.
