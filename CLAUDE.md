# {PROJECT_NAME}

## New project detection

If `AI.md` or `IDEA.md` is missing, this is a new project. Stop and plan:
1. Ask the user what the project does (if `IDEA.md` is absent).
2. Create `IDEA.md` with the required three sections (`## Project description`, `## Project variables`, `## Business logic`).
3. Copy the appropriate `TEMPLATE.md` from `claudemgr` into this repo as `AI.md`.
4. Create `PLAN.AI.md` with the implementation plan before writing any code.
5. Create `TODO.AI.md` with the task list derived from the plan.

## Session start

Before acting on this project, read in order:

1. `AI.md` — source of truth for all implementation decisions (THE HOW). Read-only; never modify during routine work.
2. `IDEA.md` — project description, variables, and business logic (THE WHAT). Resolve `{placeholders}` from `## Project variables` at runtime; do not substitute them into `AI.md`.
3. `PLAN.AI.md` — current AI implementation plan (if it exists).
4. `TODO.AI.md` — current AI task list (if it exists).
5. `PLAN.md` — human implementation plan (if it exists); AI **must** mark items done when completed, never rewrite wholesale or delete entries.
6. `TODO.md` — human task list (if it exists); AI **must** mark items done when completed, never delete or empty entries.

**AI.md wins on any conflict with IDEA.md. Fix IDEA.md, not AI.md.**

## Execution hierarchy

Never run builds, tests, or scripts directly on the host unless no lower option works. Always use the lowest viable level:

1. **VM** — best isolation; required for system-level scripts (service installs, OS config, package management)
2. **Incus** — preferred container runtime if installed; more system-capable than Docker
3. **Docker** — fallback container
4. **Host** — last resort only when the task genuinely cannot work at a higher level (e.g. USB device access with no passthrough available, host-level socket that cannot be forwarded)

This applies to everything: build toolchains (`cargo`, `gradle`, `go build`), project binaries, `./scripts/`, `./tests/`, and system install scripts (`install.sh`, `setup.sh`). A script being the deliverable (e.g. `scriptmgr/*/install.sh`) does not exempt it from this rule — test it in a VM or Incus container running the target distro.

Scripts that appear to require host access (`install-to-device.sh`, `dev-shell.sh`, some `./tests/*`) should still use the hierarchy where possible — check whether the VM/container can get USB passthrough, socket forwarding, or Docker-in-Docker before falling back to the host.

## Directory layout

```
{project_name}/
├── src/          # source code (Go, Rust, etc.)
├── app/          # source code (Android/Kotlin)
├── scripts/      # dev and install scripts (always committed)
├── tests/        # test runners and helpers (always committed)
├── docker/
│   ├── Dockerfile
│   ├── Dockerfile.dev
│   ├── docker-compose.yml
│   └── rootfs/   # files ADDed into image, mirroring Linux FHS
│       ├── etc/
│       └── usr/local/bin/   # entrypoint.sh, etc.
├── AI.md
├── IDEA.md
├── CLAUDE.md
└── ...
```

Temp, debug, and test output always go in `/tmp/{project_org}/{project_name}-XXXXXX` — never committed, never in the repo tree. The repo must be free of scratch files (`config.yml`, `rootfs/`, `volumes/`, etc. at repo root or anywhere not listed above).

## Task tracking rules

- Use `TODO.AI.md` whenever working on more than 2 items.
- Remove completed items from `TODO.AI.md` as they are finished — do not accumulate done items.
- `TODO.md` and `PLAN.md` are human-owned: AI **must** mark items done when it completes them — leaving them unmarked is misleading. Never delete entries or rewrite wholesale.
- Update `PLAN.AI.md` when the approach changes mid-task.

## Compliance

- Re-read the relevant `AI.md` section before each task.
- Verify against spec every 3–5 changes.
- Full compliance check before marking any task done.
- When uncertain: re-read the spec. Never guess.
