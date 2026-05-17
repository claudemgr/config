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

## Incus Instance Naming

Every Incus instance started by AI must follow the same naming schema as Docker containers:

```
{project_name}-XXXX
```

where `XXXX` is a random 8-character lowercase alphanumeric suffix — identical to the Docker `--name` convention.

```bash
SUFFIX=$(tr -dc 'a-z0-9' </dev/urandom | head -c8)
INSTANCE="{project_name}-${SUFFIX}"

incus launch {image} "${INSTANCE}" --network {project_name}-test-net
incus exec "${INSTANCE}" -- {command}
# ... work ...
incus delete --force "${INSTANCE}"
```

Rules:
- Always generate the suffix before the launch command; store it in a variable
- The instance name is the primary key for cleanup — record it immediately after launch
- Never use generic names (`test`, `temp`, `dev`) that cannot be traced to a project
- In Makefile targets: `SUFFIX=$$(tr -dc 'a-z0-9' </dev/urandom | head -c8)`

## Incus Network Isolation

Test instances must run on an isolated network — never on the default bridge:

```bash
incus network create {project_name}-test-net
incus launch {image} {project_name}-XXXX --network {project_name}-test-net
# ... run tests ...
incus delete --force {project_name}-XXXX
incus network delete {project_name}-test-net
```

Rules:
- Create a dedicated network before the first test instance starts; delete it after the last instance stops
- Never attach test instances to `lxdbr0` or any shared bridge
- Instances in the test network can reach each other by instance name via Incus DNS; no host port forwarding needed for inter-instance traffic
- Track the network name alongside instance names for cleanup

## Container Network Isolation

Test containers must run on an isolated network — never on the default bridge:

```bash
docker network create --driver bridge {project_name}-test-net
# ... run containers with --network {project_name}-test-net ...
docker network rm {project_name}-test-net   # clean up immediately after
```

Rules:
- Create a named network before the first test container starts; tear it down after the last container stops
- Never use `--network host` in tests — it exposes the container to the host network and other services
- Containers in the test network can communicate by service name; no host port mapping required for inter-container traffic
- Track the network name/ID alongside container IDs for cleanup

## Container / Instance Lifetime

Every container or Incus instance started by AI must have an explicit lifetime — never leave one running indefinitely:

- **Test containers / instances:** stop and remove immediately after the test completes (pass or fail)
- **Build containers:** `--rm -it --name {project_name}-XXXX` on all `docker run` invocations; self-remove on exit, interactive-capable, named for traceability (`XXXX` = random 8-char suffix)
- **Incus instances:** `incus launch {image} {project_name}-XXXX`; `incus delete --force {project_name}-XXXX` when done; same 8-char random suffix convention as Docker
- **Long-running service containers (integration tests):** set a `--stop-timeout` and enforce it; if a container has not exited within 60s of `docker stop`, force-kill with `docker kill`
- **No containers or instances survive a session end** — everything started during a session must be stopped before the session ends

If a container must remain running after the session (e.g. a dev environment started at user request), document its name/ID explicitly and tell the user — never leave one silently running.

## Scope

**This applies to everything:** build toolchains (`cargo`, `gradle`, `go build`), project binaries, `./scripts/`, `./tests/`, and system install scripts.

**Why:** install scripts modify OS config and install system services — running them on the host trashes the developer's machine.

**Scripts that seem to require host access** (`install-to-device.sh`, `dev-shell.sh`, some `./tests/*`): still check whether a VM or container can satisfy the requirement (USB passthrough, socket forwarding, Docker-in-Docker) before falling back to host.
