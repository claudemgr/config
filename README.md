# 🤖 claudemgr/config

Global Claude Code configuration — agents, memory, hooks, and settings deployed to `~/.claude/` on every machine. One installer gets any machine to the same baseline.

## 📦 What's Included

| Path | Purpose |
|------|---------|
| `home/CLAUDE.md` | Global AI rules — always loaded at every session start |
| `home/settings.json` | Claude Code permissions, hook wiring, and behavior flags |
| `home/agents/` | Custom agent definitions |
| `home/hooks/` | Hook scripts — `protect-host.sh` guards destructive ops |
| `home/memory/` | Convention and standards files loaded on demand |
| `install.sh` | Syncs `home/` → `~/.claude/` and registers plugins + MCP servers |

## 🚀 Install

> Clones this repo, copies all config to `~/.claude/`, and installs the plugins and MCP servers listed below. Safe to re-run — fully idempotent.
>
> 📄 [View the raw install script](https://raw.githubusercontent.com/claudemgr/config/main/install.sh) before running.

```sh
curl -fsSL https://raw.githubusercontent.com/claudemgr/config/main/install.sh | sh
```

### Prerequisites

| Tool | Required | Notes |
|------|----------|-------|
| `claude` | ✅ Yes | [Claude Code CLI](https://claude.ai/code) |
| `git` | ✅ Yes | For cloning and updating |
| `npx` | ⚠️ Optional | Required for the fetch MCP server; skipped if absent |

### Environment Variables

| Variable | Purpose |
|----------|---------|
| `GITHUB_TOKEN` | GitHub personal access token for the GitHub MCP server |

---

## 🤖 Agents

Agents are specialized sub-models invoked automatically based on what you ask, or explicitly with `@agent-name`. Each is tuned for a specific kind of task.

### 🏗️ Project Lifecycle

| Agent | When to use |
|-------|-------------|
| `bootstrap` | Start a new project from a spec file (`{project_dir}/AI.md`), or re-bootstrap after a spec change. Reads PART 0–6 of the spec and executes everything — directory layout, build system, config, metadata. Reconciles `TODO.AI.md` if it exists. |
| `spec-migrator` | Migrate a project with `SPEC.md`, a project-spec `CLAUDE.md`, or a sparse `AI.md` to the standard `AI.md` + `IDEA.md` + `CLAUDE.md` loader structure. Also runs a bootstrap wizard for projects with no spec files at all. |
| `go-server-to-api` | Audit a Go project after its AI.md has been replaced with a new spec (SERVER↔API), then generate a complete `TODO.AI.md` covering all migration tasks. |
| `planner` | Design an implementation plan before writing code. Use when a task touches 3+ files, has ambiguous requirements, or needs architectural tradeoffs evaluated. Returns a step-by-step plan and flags risks. Does not write code. |
| `commit-prep` | Prepare a `COMMIT_MESS` file for the current git working tree without polluting the main conversation with raw diff output. |

### 🔍 Code Quality

| Agent | When to use |
|-------|-------------|
| `audit` | Full project health audit — security, code quality, logic correctness, documentation completeness, spec compliance. Fixes issues directly. Triggered by "audit", "check compliance", or "verify project". |
| `code-reviewer` | Review diffs, PRs, specific files, or functions before committing or merging. |
| `security-auditor` | Threat modeling, OWASP audits, secrets scanning, dependency CVEs, auth flows, and hardening reviews. Best run on a PR or feature before it ships. |
| `beta-tester` | Structured beta testing from a user perspective — exploratory testing, edge case discovery, UAT against specs. Use before a release or after a major feature lands. |
| `test-writer` | Write tests for existing code — unit, integration, table-driven, fuzz targets. |
| `designer` | Designer-level UI/UX implementation for web, desktop, mobile, and TUI. Use for new screens, component design, theme systems, layout, and accessibility audits. |

### 🔎 Research & Exploration

| Agent | When to use |
|-------|-------------|
| `architect` | System design, API design, data modeling, architectural tradeoffs. Use when designing a new system or reviewing an existing design for scalability and maintainability. |
| `debugger` | Root cause analysis for bugs, crashes, hangs, and unexpected behavior. Use when you have an error message, stack trace, or reproducible failure. |
| `researcher` | Multi-step research spanning multiple files or locations, or tasks requiring web research combined with code reading. |
| `explorer` | Fast read-only codebase search — find files by pattern, locate symbol definitions, grep for keywords. Specify breadth: "quick", "medium", or "very thorough". |

### 🛠️ Linting

| Agent | When to use |
|-------|-------------|
| `go-lint` | Lint Go projects for convention violations — CGO, binary naming, strip flags, Makefile pattern, CLI flags, NO_COLOR, logging. Run before committing any Go change. |
| `rust-lint` | Lint Rust projects — Cargo.toml release profile, binary naming, CLI flags, NO_COLOR, forbidden patterns. Run before committing any Rust change. |
| `script-lint` | Lint bash/sh scripts — UUOC, naming, version stamps, inline comments, line length, missing triple-sync. Run before committing any script change. |

### ⚙️ Infrastructure & Tooling

| Agent | When to use |
|-------|-------------|
| `devops` | Infrastructure, CI/CD, containers, orchestration — Dockerfile review, Kubernetes manifests, CI pipeline design, secrets management, deployment strategies. |
| `cicd-maintenance` | Handle Renovate dependency update PRs/MRs on GitHub/GitLab/Gitea/Forgejo; audit and fix CI workflow files; run SHA 3-point verification; merge clean PRs; update the SHA table. |
| `rpm-builder` | RPM spec file authoring and build workflow for CasjaysDev packages — own binaries, scripts, services, and third-party repackaging. Generates spec files, Docker build commands, signing steps, and `createrepo_c` invocations. |
| `doc-sync` | Sync the `__help()`, man page, and completions triple after a bash script changes. Also syncs `README.md` when feature or CLI changes warrant it. |
| `statusline-setup` | Configure the Claude Code status line — add, remove, or fix fields. |
| `claude-code-guide` | Answers questions about Claude Code CLI features, hooks, slash commands, MCP servers, settings, and the Claude API. Use when the question is about how Claude Code works, not about a project. |
| `general` | Catch-all for everyday tasks — writing, editing, research, coding — when no specialist agent fits. |

### 🏗️ Scaffolding

| Agent | When to use |
|-------|-------------|
| `billing-builder` | Interactive billing and subscription system scaffolder. Covers subscription plans, payment provider abstraction (47+ providers across 8 categories), usage metering, tax compliance, invoicing, and administrative controls. |
| `notifications-builder` | Interactive notification system scaffolder. Covers 30 channels across 7 categories, SMTP auto-enable behavior, channel plugin architecture, routing rules, user preferences, and administrative controls. |
| `support-builder` | Interactive customer support system scaffolder. Covers ticketing (9-state machine), live chat, knowledge base, deterministic bot automation, SLA management, canned responses, and agent workspace. |
| `go-auth-builder` | Interactive auth scaffolder for Go HTTP server projects. Covers admin auth, API tokens, user accounts, orgs/teams, custom domains, DB schemas, middleware, handlers, HTML templates, routes, and i18n. |

---

## 🧠 Memory System

Files in `home/memory/` are loaded on demand at session start via `MEMORY.md`. They provide persistent convention and standards context without bloating `CLAUDE.md`.

| File | Contents |
|------|---------|
| `MEMORY.md` | Index — entry for every memory file |
| `project_conventions.md` | `{project_dir}/AI.md` / `{project_dir}/IDEA.md` / `{project_dir}/CLAUDE.md` roles, placeholder system, first-time setup flow |
| `project_forbidden_files.md` | Files and directories that must never be created; README/LICENSE naming rules |
| `project_type_conventions.md` | Cross-language rules by project type: server, cli, library, tui, desktop-gui, worker |
| `execution_hierarchy.md` | VM > Incus > Docker > host — where to run commands |
| `sensitive_data.md` | All public destinations are equal; masking format (`key=xxxxx`); pre-flight checklist |
| `image_conventions.md` | Convert before reading (max 1280px, WebP); fallback chain; URL viewing workflow |
| `gitcommit_conventions.md` | `gitcommit` path resolution and usage |
| `script_conventions.md` | Shebang/extension → interpreter; header template; `__` prefix; NO_COLOR; exit codes; doc triple sync |
| `go_conventions.md` | Go project layout, Makefile targets, CGO=0, binary naming, module cache |
| `rust_conventions.md` | Rust project layout, Cargo, release profile, static linking |
| `logging_conventions.md` | Log files are pure raw text; format per type; masking in logs |
| `dockerfile_conventions.md` | Two-stage builds, OCI labels, tini entrypoint, Docker Compose rules, .dockerignore |
| `gitignore_conventions.md` | Header format, standard entries, project-type additions |
| `tempdir_conventions.md` | Required path structure, per-language creation, guarded cleanup |
| `cicd_conventions.md` | SHA pinning, no `pull_request_target`, branch protection, SBOM, release integrity |
| `standards_reference.md` | HTTP status codes, RFC 7807, ISO 8601, semver, MIME, UUID, TLS, JWT, OAuth2, pagination |

---

## 🔒 Source of Truth Order

When rules conflict, the highest level wins:

1. **`{project_dir}/AI.md`** — full project spec; overrides everything when complete
2. **`{project_dir}/CLAUDE.md`** — project-level overrides
3. **`~/.claude/CLAUDE.md`** — global baseline (this repo)

A sparse or minimal `{project_dir}/AI.md` defers to global rules for anything it doesn't cover. A full spec (one that defines the complete implementation for its project type) is authoritative.

---

## 📁 Directory Layout

```
config/
├── install.sh              # Syncs home/ → ~/.claude/
├── home/                   # Mirrors ~/.claude/ exactly
│   ├── CLAUDE.md           # Global AI rules
│   ├── settings.json       # Permissions and hook wiring
│   ├── agents/             # Agent definition files ({name}.md)
│   ├── hooks/              # Hook scripts ({name}.sh)
│   └── memory/             # Convention and standards files
│       ├── MEMORY.md       # Index
│       └── {topic}.md
├── AI.md                   # Project spec (THE HOW)
├── IDEA.md                 # Project plan (THE WHAT)
├── CLAUDE.md               # Short loader
├── README.md
└── LICENSE.md
```

## 🔌 Plugins Installed

| Plugin | Language Server |
|--------|----------------|
| `gopls-lsp` | Go |
| `rust-analyzer-lsp` | Rust |
| `typescript-lsp` | TypeScript / JavaScript |

## 🔗 MCP Servers Configured

| Server | Transport | Purpose |
|--------|-----------|---------|
| `github` | HTTP | GitHub API — PRs, issues, repo search, code review |
| `fetch` | stdio (`npx`) | Fetch web content and documentation |

## 🔄 Updating

```sh
curl -fsSL https://raw.githubusercontent.com/claudemgr/config/main/install.sh | sh
```

## 👤 Author

**Jason Hempstead** · [GitHub](https://github.com/casjay) · [Casjays Developments](https://casjaysdev.pro)

## 📄 License

MIT — see [LICENSE.md](LICENSE.md)
