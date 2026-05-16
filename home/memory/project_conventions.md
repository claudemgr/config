---
name: Project file conventions
description: Full spec for AI.md, IDEA.md, CLAUDE.md, and related files; template system in claudemgr
type: user
---

## Project root (`{project_dir}`)

`{project_dir}` is resolved once at session start:
- Inside a git repo → `git rev-parse --show-toplevel` (the git root)
- Not a git repo → the directory Claude was launched from (`$PWD` at session start)

All relative file references (`AI.md`, `./src`, `./`) resolve from `$PWD`. Absolute paths (`/…`, `~…`) are taken as-is.

**Project files override global:** if `{project_dir}/CLAUDE.md` or `{project_dir}/AI.md` exists, it is the source of truth for that session and supersedes any global equivalent.

**Stay inside `{project_dir}`:** all writes and edits must target paths within `{project_dir}` unless the user explicitly names an external path. Never reach outside the project tree (e.g. `~/.claude/`, `/etc/`, another repo) on own initiative, even when a file there "should" be updated as a side effect of the task.

---

## File roles

| File | Role | Mutable during work? |
|------|------|----------------------|
| **AI.md** | THE HOW — implementation spec, source of truth. READ-ONLY. | No (except policy-level changes) |
| **IDEA.md** | THE WHAT — project plan. Three required sections (see below). | Yes |
| **TODO.AI.md** | AI-owned task list. Required when working on more than 2 items. Completed items are REMOVED (not marked done and left). | Yes |
| **TODO.md** | Human-owned task list; AI **must** mark done when completed (leaving unmarked is misleading), never delete/empty entries | Limited |
| **PLAN.AI.md** | AI-owned implementation plan — delete when the work it describes is fully committed | Yes |
| **PLAN.md** | Human-owned plan; AI **must** mark done when completed, never delete entries or rewrite wholesale | Limited |
| **CLAUDE.md** | Short loader pointing at AI.md and IDEA.md. No project-specific spec content. | No |

**If AI.md and IDEA.md conflict, AI.md wins. Fix IDEA.md.**

### AI tool config files (Claude Code, Cursor, Windsurf, Aider, Copilot, Continue, etc.)

All AI tool configs follow the same split: **team config is committed; personal overrides, history, and cache are gitignored.** The canonical example is `.claude/settings.json` (committed) vs `.claude/settings.local.json` (gitignored). The same rule applies to every other tool. The full per-tool table — what to commit and what to ignore — is in `~/.claude/memory/gitignore_conventions.md`.

**New project detection:** if AI.md or IDEA.md is missing → new project. Plan first: create IDEA.md, copy TEMPLATE.md as AI.md, write PLAN.AI.md and TODO.AI.md before touching code.

**Partial IDEA.md:** if IDEA.md exists but is missing one or more of the three required sections, do not proceed with work — add the missing sections first. Ask the user for the missing information rather than guessing. A partial IDEA.md is treated as absent for the section(s) it is missing.

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

## Task dependency ordering

When a task list has dependencies, execution order must respect them before sequence order.

**Rule:** resolve the dependency graph first; numbered/lettered order is a default tiebreaker only, not an execution mandate.

**Example:** tasks 1, 2, 3 and a, b, c where c→2 and a→2 (c and a must complete before 2):

```
Correct order: 1, a, c, 2, b, 3   (a and c unblock 2; 1 has no deps so runs first)
Wrong order:   1, 2, 3, a, b, c   (2 runs before its prerequisites)
```

**Rules:**
- Before starting any task list, scan for stated dependencies ("X before Y", "requires X", "needs X first")
- Build a mental dependency graph; topological-sort it; use label order only to break ties among tasks at the same depth
- If a dependency is ambiguous, ask before executing — never assume order
- Document the resolved order at the top of TODO.AI.md or PLAN.AI.md when the graph is non-trivial (3+ dependencies)
- A task is only "ready" when all its prerequisites are in a completed state

---

## Compliance schedule (per AI.md)

- Session start: read AI.md completely
- Before each task: re-read relevant parts
- Every 3–5 changes: verify against spec
- Before task completion: full compliance check
- When uncertain: re-read spec, never guess

## Language-specific implementation rules

For language-specific build rules, binary naming, Makefile targets, and code conventions see the dedicated files: `~/.claude/memory/go_conventions.md` and `~/.claude/memory/rust_conventions.md`.
