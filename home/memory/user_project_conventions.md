---
name: Project file conventions
description: Full spec for AI.md, IDEA.md, CLAUDE.md, and related files; template system in claudemgr
type: user
---

## File roles

| File | Role | Mutable during work? |
|------|------|----------------------|
| **AI.md** | THE HOW — implementation spec, source of truth. READ-ONLY. | No (except policy-level changes) |
| **IDEA.md** | THE WHAT — project plan. Three required sections (see below). | Yes |
| **TODO.AI.md** | AI-owned task list. Required when working on more than 2 items. Completed items are REMOVED (not marked done and left). | Yes |
| **TODO.md** | Human-owned task list; AI **must** mark done when completed (leaving unmarked is misleading), never delete/empty entries | Limited |
| **PLAN.AI.md** | AI-owned implementation plan | Yes |
| **PLAN.md** | Human-owned plan; AI **must** mark done when completed, never delete entries or rewrite wholesale | Limited |
| **CLAUDE.md** | Short loader pointing at AI.md and IDEA.md. No project-specific spec content. | No |

**If AI.md and IDEA.md conflict, AI.md wins. Fix IDEA.md.**

**New project detection:** if AI.md or IDEA.md is missing → new project. Plan first: create IDEA.md, copy TEMPLATE.md as AI.md, write PLAN.AI.md and TODO.AI.md before touching code.

## IDEA.md required layout (exactly three top-level sections, in this order)

```
## Project description
(Elevator pitch — who, what, why. Free-form prose.)

## Project variables
(key: value pairs, lower_snake_case keys. Minimum required: project_name, project_org,
internal_name, internal_org. Add extras as needed: app_name, official_site, etc.)

## Business logic
(THE WHAT — features, flows, roles, permissions, data models, trust boundaries,
abuse cases, security decisions. NOT the HOW.)
```

## Placeholder system

Placeholders in AI.md (e.g., `{project_name}`, `{PROJECT_ORG}`) are **reference tokens resolved at runtime from IDEA.md `## Project variables`**. AI.md itself stays read-only — placeholders are NOT substituted into the file at copy time.

| Placeholder | Mutability | On-disk use? |
|-------------|------------|--------------|
| `{project_name}` / `{PROJECT_NAME}` | Mutable (project may rename) | No |
| `{project_org}` / `{PROJECT_ORG}` | Mutable | No |
| `{internal_name}` / `{INTERNAL_NAME}` | **Frozen forever** at first-time setup | Yes — config/data/cache dirs, systemd units |
| `{internal_org}` / `{INTERNAL_ORG}` | **Frozen forever** at first-time setup | Yes — Bundle IDs, package IDs |
| `{plist_name}` | Derived, not stored: `io.github.{internal_org}.{internal_name}` | Yes |

**internal_name and internal_org are set ONCE (initial value = project_name/project_org) and never edited after the project ships. On-disk identifiers never change even if the project renames.**

## Template system (claudemgr repo)

- `claudemgr/go/TEMPLATE.md` — master Go project template
- `claudemgr/rust/TEMPLATE.md` — master Rust project template
- `claudemgr/config/CLAUDE.md` — project CLAUDE.md loader template
- When starting a new project: COPY the appropriate TEMPLATE.md into the project as `AI.md`
- The copied AI.md is immediately read-only; project-specific values go in IDEA.md

## First-time setup flow

1. Check if IDEA.md exists with all required `## Project variables` entries
2. If not: detect values from directory structure (`basename "$PWD"`, `basename "$(dirname "$PWD")"`) — never guess
3. Confirm with user before writing
4. Create/update IDEA.md; set internal_name = project_name and internal_org = project_org (frozen immediately)
5. If an existing CLAUDE.md has real project details, migrate them into IDEA.md; keep CLAUDE.md as a short loader only

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

Temp, debug, and test output: `/tmp/{project_org}/{internal_name}-XXXXXX` — never committed. (`{internal_name}` is the frozen on-disk identifier, never `{project_name}` which may change.)

## Compliance schedule (per AI.md)

- Session start: read AI.md completely
- Before each task: re-read relevant parts
- Every 3–5 changes: verify against spec
- Before task completion: full compliance check
- When uncertain: re-read spec, never guess

## Go template specifics (claudemgr/go/TEMPLATE.md)

- CGO_ENABLED=0 always; pure Go, single static binary, Go embed for assets
- 8 platforms: linux/darwin/windows/freebsd × amd64/arm64
- Binary naming: `{project_name}-{os}-{arch}` (windows adds .exe)
- Build only via Makefile (`make dev/local/build/test`); never `go build` directly on host

## Rust template specifics (claudemgr/rust/TEMPLATE.md)

- Rust-only source; no C/C++ in the binary (ring is pre-approved exception)
- Single static binary: musl on Linux, static CRT on Windows, system frameworks on macOS
- Build only inside Docker; never `cargo` directly on host
- GUI surfaces must support BOTH X11 and Wayland as first-class backends
- Assets embedded at build time; binary must work air-gapped
