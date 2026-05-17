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
| `*.example.*`, `*.sample.*` | No example files — defaults are embedded in the binary. **Exception:** `.env.example`, `.env.sample`, `app.env.example`, `app.env.sample`, `default.env.example`, `default.env.sample` are allowed — they are safe templates for users to copy |
| `server.yml`, `cli.yml` | Config files are runtime-generated, never in repo |
| `.env`, `app.env`, `default.env` | Never committed — must always be in `.gitignore`. Use `.env.example` / `.env.sample` variants for committed templates |
| `.claude/settings.local.json` | Personal Claude Code overrides — gitignored, never committed |
| `.cursor/settings.json` | Personal Cursor settings — gitignored, never committed |
| `.windsurf/settings.json` | Personal Windsurf settings — gitignored, never committed |
| `.aider.chat.history.md`, `.aider.input.history`, `.aider.llm.history` | Aider personal history — gitignored, never committed |
| `.aider.tags.cache.v3/` | Aider symbol cache — gitignored, never committed |
| `.continue/dev_data/`, `.continue/session.json`, `.continue/index/` | Continue personal data and indexes — gitignored, never committed |
| `.codeium/` | Codeium auth/cache — gitignored, never committed |

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

## `docker/rootfs/` Contents

`docker/rootfs/` mirrors the Linux FHS — it is `COPY`'d into the image at `/`. Acceptable paths inside it:

| Path | Purpose |
|------|---------|
| `etc/logrotate.d/{project_name}` | logrotate config |
| `etc/systemd/system/{project_name}.service` | systemd unit (Incus/VM builds only) |
| `etc/cron.d/{project_name}` | cron job (if needed) |
| `usr/local/bin/entrypoint.sh` | Required — container startup script |
| `usr/local/bin/{additional_scripts}` | Helper scripts bundled with the image |
| `usr/local/share/{project_name}/` | Static data files |

**Never place in `docker/rootfs/`:**
- Source code (belongs in `src/`)
- Credentials or `.env` files
- Files that belong in the OS package manager (`/usr/bin/`, `/bin/`) — use `/usr/local/bin/` instead
- Large binary blobs — embed them in the binary at build time instead

## Allowed Root Files

These are the only files that belong at the project root:

| File | Required | Purpose |
|------|:--------:|---------|
| `AI.md` | ✓ | Project specification (THE HOW) — readonly template copy |
| `SPEC.md` | Optional | Project-specific rule overrides — may be empty; only add content when a rule must contradict the template or global |
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
| `.editorconfig` | Optional | Editor formatting rules — permitted, but settings must match the project's existing style conventions |

---

## README.md Requirements

`README.md` is public documentation — written for users, not developers. Apply designer-level intent: clear, scannable, and complete.

### Mandatory sections (binary projects)

Every project that produces a binary must have all four of these sections:

1. **What it does** — one-paragraph description; no jargon
2. **Install** — platform-complete download instructions (see below)
3. **Usage** — the most common invocation(s); flags table if the binary has a CLI
4. **Build from source** — `make build` is always the canonical command; note any prerequisites

### Install section — platform coverage rule

**The install section MUST cover every platform the project builds for.** Covering one platform when the Makefile builds eight is a documentation bug.

**How to determine the build matrix:**

- **Go projects** — inspect the Makefile for GOOS/GOARCH loops or explicit platform targets. Default is 8 platforms (see `go_conventions.md`): linux/darwin/windows/freebsd × amd64/arm64.
- **Rust projects** — inspect the Makefile for target triples. Default platforms are in `rust_conventions.md`.
- If in doubt, run `grep -E 'GOOS|GOARCH|target.*triple|linux|darwin|windows|freebsd' Makefile` and document what you find.

**Required install section structure:**

```markdown
## Install

Download the latest release from [GitHub Releases](https://github.com/{org}/{project}/releases/latest).

### Linux
| Arch | Binary |
|------|--------|
| amd64 | `{project_name}-linux-amd64` |
| arm64 | `{project_name}-linux-arm64` |

```bash
curl -LSsf https://github.com/{org}/{project}/releases/latest/download/{project_name}-linux-amd64 \
  -o /usr/local/bin/{project_name} && chmod +x /usr/local/bin/{project_name}
```

### macOS
| Arch | Binary |
|------|--------|
| Intel (x86_64) | `{project_name}-darwin-amd64` |
| Apple Silicon (arm64) | `{project_name}-darwin-arm64` |

```bash
# Detect arch automatically
ARCH=$(uname -m | sed 's/x86_64/amd64/;s/aarch64/arm64/')
curl -LSsf "https://github.com/{org}/{project}/releases/latest/download/{project_name}-darwin-${ARCH}" \
  -o /usr/local/bin/{project_name} && chmod +x /usr/local/bin/{project_name}
# Remove macOS quarantine flag
xattr -d com.apple.quarantine /usr/local/bin/{project_name} 2>/dev/null || true
```

### Windows
| Arch | Binary |
|------|--------|
| amd64 | `{project_name}-windows-amd64.exe` |
| arm64 | `{project_name}-windows-arm64.exe` |

Download and add to `%PATH%`.

### FreeBSD
| Arch | Binary |
|------|--------|
| amd64 | `{project_name}-freebsd-amd64` |
| arm64 | `{project_name}-freebsd-arm64` |
```

**Rules:**

- Never document only one platform when the build matrix is wider — omission is a bug
- Never hardcode a version number in download URLs — always use `/releases/latest/download/`
- Always include the `xattr` quarantine removal step for macOS
- Always include `chmod +x` for every Unix binary
- Windows binaries get `.exe`; no other platforms do
- Rust binary naming uses OS names `linux/macos/windows/freebsd` (not `darwin`) and arch names `x86_64/aarch64` (not `amd64/arm64`) — match what the Makefile actually produces
- Go binary naming uses `darwin` (never `macos`) and `amd64`/`arm64` — match what the Makefile actually produces
- If a platform is conditionally built (e.g. macOS cross-compile requires a macOS host), note the constraint; do not silently omit the platform

### README.md sync rule

When any of the following change, README.md must be updated in the same commit:

- New binary added or renamed
- New platform or architecture added to the build matrix
- New CLI flag or subcommand added
- Build prerequisites change
- Project name, org, or repo path changes

Use the `doc-sync` agent when CLI or feature changes require README updates.
