---
name: Project forbidden files and directories
description: Files and directories that must never be created in a project repo, sourced from the Go and Rust AI.md templates
type: user
---

## Enforcement Rule

**Forbidden = flag and report, not auto-delete.**

When a forbidden file or directory is found:
1. Tell the user: what it is, why it's forbidden, and where it belongs instead (if anywhere)
2. Wait for explicit confirmation before removing or moving anything
3. Never silently delete — a forbidden file might contain unreplicated work

The only exception: report-only files created by AI itself during the current session (`AUDIT.AI.md` when all issues are resolved, `PLAN.AI.md` scratch files, etc.) may be deleted without confirmation because AI created them and knows their contents.

---

## File Naming Rules

- Documentation is **always** `README.md` — no other casing or name
- License is **always** `LICENSE.md` — project license first, third-party attributions at the bottom

## Forbidden Files

| File | Reason |
|------|--------|
| `SUMMARY.md` | Unnecessary — `AI.md` is the spec |
| `COMPLIANCE.md` | Unnecessary — compliance is in `AI.md` |
| `NOTES.md` | Use `PLAN.md`, `PLAN.AI.md`, `TODO.md`, or `TODO.AI.md` as appropriate |
| `CHANGELOG.md` | Use GitHub/Gitea releases instead |
| `AUDIT.md`, `REPORT.md`, `ANALYSIS.md` | Don't create report-only docs — fix issues directly. Temporary `AUDIT.AI.md` is the explicit-audit exception |
| `CONTRIBUTING.md` in root | Belongs in `.github/` |
| `CODE_OF_CONDUCT.md` in root | Belongs in `.github/` |
| `SECURITY.md` in root | Belongs in `.github/` |
| `PULL_REQUEST_TEMPLATE.md` in root | Belongs in `.github/` |
| `Dockerfile` in root | Belongs in `docker/Dockerfile` |
| `docker-compose.yml` in root | Belongs in `docker/docker-compose.yml` |
| `*.example.*`, `*.sample.*` | No example files — defaults are embedded in the binary |
| `server.yml`, `cli.yml` | Config files are runtime-generated, never in repo |
| `.env*` | No `.env` files in repo |

## Forbidden Directories

| Directory | Reason |
|-----------|--------|
| `config/` in root | Config is embedded, runtime-generated in OS dirs |
| `data/` in root | Data goes to OS data directory at runtime |
| `logs/` in root | Logs go to OS log directory at runtime |
| `tmp/`, `temp/` in root | Use `/tmp/{project_org}/{internal_name}-XXXXXX/` |
| `test-data/` in root | Test data goes to temp directories |
| `build/`, `dist/`, `out/` | Use `binaries/` (gitignored) |
| `vendor/` | Use language module system (Go modules, Cargo.lock) |
| `node_modules/` | Never committed |
| `lib/`, `libs/` at repo root | Use proper language package structure; `lib/` nested under `src/` or similar is acceptable |
| `utils/`, `common/` | Use specific, descriptive package names |

**Note:** `src/data/` is allowed for static files embedded in the binary. Only root-level `data/` is forbidden.

## Allowed Root Files

These are the only files that belong at the project root:

| File | Required | Purpose |
|------|:--------:|---------|
| `AI.md` | ✓ | Project specification (THE HOW) |
| `IDEA.md` | ✓ | Project description, variables, business logic (THE WHAT) |
| `CLAUDE.md` | ✓ | Short loader — points at `AI.md` and `IDEA.md` |
| `README.md` | ✓ | Public documentation |
| `LICENSE.md` | ✓ | Project license + third-party attributions |
| `Makefile` | ✓ | Build entrypoint |
| `PLAN.md` | Optional | Human-owned project plan |
| `PLAN.AI.md` | Optional | AI-owned implementation plan |
| `TODO.md` | Optional | Human-owned task list |
| `TODO.AI.md` | Optional | AI-owned task list (required for 3+ tasks) |
| `release.txt` | Optional | Canonical version string |
| `version.txt` | Optional | Canonical version string (alias for `release.txt` — some projects use this name) |
| `site.txt` | Optional | Official site/homepage URL |
| `.gitignore` | ✓ | Git ignore rules |
| `.github/` | Optional | GitHub-specific files (workflows, templates, etc.) |
