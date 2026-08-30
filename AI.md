# claudemgr/config — Implementation Spec (THE HOW)

This file is read-only during routine work. Placeholders like `{deploy_target}` resolve from `IDEA.md → ## Project variables`.

---

## Part 1: Repository Layout

```
config/
├── home/                        # mirrors ~/.claude/ exactly
│   ├── CLAUDE.md                # global AI instructions (deployed to ~/.claude/CLAUDE.md)
│   ├── settings.json            # permissions, hooks, Claude Code flags
│   ├── agents/                  # subagent definition files
│   │   └── {name}.md
│   ├── hooks/                   # PreToolUse/PostToolUse hook scripts
│   │   └── {name}.sh
│   └── memory/                  # convention and standards memory files
│       ├── MEMORY.md            # index — always kept in sync
│       └── {topic}.md
├── AI.md                        # this file — THE HOW
├── IDEA.md                      # THE WHAT
├── CLAUDE.md                    # short loader only
├── install.sh                   # deploys home/ → ~/.claude/
├── README.md
└── LICENSE.md
```

---

## Part 2: install.sh

`install.sh` copies the contents of `home/` to `{deploy_target}` (`~/.claude/`).

- Always `chmod +x` hook scripts after copy
- Never delete files from `{deploy_target}` that are not in `home/` — additive sync only, unless `--clean` is passed
- Must be idempotent — safe to run multiple times
- Tested on host (no container needed — this configures the host's Claude Code installation)
- Always commit all changes before running `install.sh` — deployed state must match the repo

---

## Part 3: home/CLAUDE.md

The global AI instruction file. Loaded by Claude Code at the start of every session in every project.

**Structure** (sections in this order):

1. `## Global Memory` — instructs AI to read `~/.claude/memory/MEMORY.md` at session start
2. `## Compaction` — what to preserve/drop when context compacts
3. `## Communication` — tone, truthfulness, question handling, terminology rules
4. `## Spelling & Grammar` — fix errors in files being edited
5. `## Working Directory & Path Resolution` — `{project_dir}` resolution, path namespace rules
6. `## Code & Files` — working-set discipline, scope, style matching, no JSON comments, singular dirs
7. `## Sensitive Data` — never commit credentials; all repos public by default; masking format
8. `## Project Files & Naming` — reference to `~/.claude/memory/project_conventions.md`
9. `## Cleanup` — project-scoped cleanup only, never broad ops
10. `## Verification & Safety` — confirm before destructive ops, never auto-bypass hooks; Memory Safety block (8 rules)
11. `## Self-Validation` — verify against ground truth, iterate until passing
12. `## Build & Execution` — rolling tags, execution hierarchy, tini chain, docker-compose zero-.env
13. `## Project Defaults` — MIT license, no feature gating, telemetry opt-in, Argon2id only
14. `## Language Constraints` — absolute Go rules (CGO=0, Docker-only) and Rust rules (Docker-only, no *-sys dynamic)
15. `## Output` — no preamble, tight budget, no emojis in code, no AI attribution
16. `## Tool Preference` — right tool for the job; curl/wget/grep defaults
17. `## Token & Context Discipline` — explorer for broad searches, read narrowly
18. `## Agent Usage` — Haiku for trivial tasks
19. `## Autonomy` — pre-authorized workflows, allowlists
20. `## Commit Workflow` — gitcommit only, pre-commit sequence, message format

**Rules:**
- This file governs all sessions globally — changes are high-impact
- Keep each section tight — no redundancy between sections
- Never add project-specific content here — that belongs in per-project `CLAUDE.md` files
- `{x}` = placeholder; `x` = literal — maintain this convention throughout

---

## Part 4: Memory Files (home/memory/)

Each memory file is a markdown file with YAML frontmatter:

```markdown
---
name: Short display name
description: One sentence describing what this file covers
type: user
---

## Content...
```

`MEMORY.md` is the index — every memory file must have an entry. Format:

```markdown
- [Display name](filename.md) — one-line summary of what it covers
```

**Current memory files and their scope:**

| File | Covers |
|------|--------|
| `MEMORY.md` | Index of all memory files |
| `project_conventions.md` | `{project_dir}/AI.md` / `IDEA.md` / `CLAUDE.md` roles, placeholder system, template system, first-time setup |
| `execution_hierarchy.md` | VM > Incus > Docker > host; execution scope rules |
| `sensitive_data.md` | All public destinations equal; masking format (`key=xxxxx`); pre-flight checklist |
| `image_conventions.md` | Convert before reading (max 1280px, WebP); fallback chain; URL image workflow |
| `gitcommit_conventions.md` | `gitcommit` path resolution; never hardcode path |
| `script_conventions.md` | Shebang/extension → interpreter; header template; `__` prefix; NO_COLOR; exit codes; doc triple sync |
| `project_files.md` | Files/dirs that must never be created; README.md/LICENSE.md naming rules |
| `standards_reference.md` | HTTP status codes, RFC 7807, ISO 8601, semver, MIME, UUID, TLS, JWT, OAuth2, pagination |
| `gitignore_conventions.md` | Header format, standard entries, project-type additions |
| `dockerfile_conventions.md` | Two-stage builds, OCI labels, tini entrypoint, Docker Compose rules, .dockerignore |
| `logging_conventions.md` | Log files are pure raw text; format per type; masking in logs |
| `tempdir_conventions.md` | Required path structure, per-language creation, guarded cleanup |
| `cicd_conventions.md` | SHA pinning, no `pull_request_target`, branch protection, SBOM, release integrity |
| `go_conventions.md` | Go project layout, Makefile targets, CGO=0, binary naming, module cache |
| `rust_conventions.md` | Rust project layout, Cargo, release profile, static linking |
| `project_type_conventions.md` | Rules by project type: server, cli, script-collection, spec-collection, library, tui, desktop-gui, worker |

**Adding a new memory file:**
1. Create `home/memory/{topic}.md` with frontmatter
2. Add an entry to `home/memory/MEMORY.md`
3. Commit both in the same commit

---

## Part 5: Agent Files (home/agents/)

Each agent is a markdown file with YAML frontmatter followed by the agent's instructions:

```markdown
---
name: agent-name
description: When to invoke this agent — used by Claude to decide routing
model: haiku   # or sonnet or opus; omit to inherit from parent
---

Instructions for the agent...
```

**Rules:**
- `description` must be precise — Claude routes to agents based on it; vague descriptions cause mis-routing
- `model: haiku` for mechanical tasks (linting, renaming, lookups); omit for judgment tasks
- Agent instructions follow the same conventions as `home/CLAUDE.md` — no preamble, no AI attribution
- Agent name in the filename must match the `name:` frontmatter field

**Current agents:**

| Agent | Model | Purpose |
|-------|-------|---------|
| `architect.md` | opus | System design, API design, data modeling, architectural tradeoffs |
| `audit.md` | opus | Full project health audit — security, quality, logic, docs, line-by-line AI.md compliance |
| `beta-tester.md` | sonnet | Structured beta testing — exploratory testing, edge cases, UAT against specs |
| `bootstrap.md` | sonnet | Bootstrap a project from a spec (`{project_dir}/AI.md`); builds PART 0–6 scaffolding incl. loaders + `.claude/rules/`, enumerates feature PARTs into a complete `TODO.AI.md`, ensures IDEA.md without fabricating it |
| `cicd-maintenance.md` | sonnet | Dependabot PR review (SHA 3-point verification, merge, SHA table update) and `security.yml` audit/fix |
| `claude-code-guide.md` | sonnet | Answers questions about Claude Code CLI, hooks, MCP servers, Claude API |
| `code-reviewer.md` | sonnet | Review diffs, PRs, or files before committing or merging |
| `commit-prep.md` | haiku | Prepare `COMMIT_MESS` without polluting main conversation with diff output |
| `debugger.md` | sonnet | Root cause analysis for bugs, crashes, hangs, unexpected behavior |
| `devops.md` | sonnet | Infrastructure, CI/CD, containers, orchestration, deployment strategies |
| `doc-sync.md` | haiku | Sync `__help()`, man page, and completions triple after a script changes |
| `dockersrc-bootstrap.md` | sonnet | Bootstrap or update a CasjaysDev Docker image repo against the current gen-dockerfile templates |
| `explorer.md` | haiku | Fast read-only codebase search — files by pattern, symbol definitions, keywords |
| `general.md` | sonnet | Catch-all for everyday tasks when no specialist agent fits |
| `go-lint.md` | haiku | Lint Go projects for CasjaysDev convention violations |
| `implement.md` | opus | Read a spec from its first word and implement everything in order (following refs); orchestrates scaffold-then-build-all, delegates to scoped builders, never commits or runs the gate |
| `planner.md` | sonnet | Design an implementation plan before writing code; flags risks |
| `researcher.md` | sonnet | Multi-step research spanning multiple files or requiring web + code reading |
| `rust-lint.md` | haiku | Lint Rust projects for CasjaysDev convention violations |
| `script-lint.md` | haiku | Lint bash/sh scripts for CasjaysDev convention violations |
| `security-auditor.md` | opus | Threat modeling, OWASP audits, secrets scanning, auth flows, hardening |
| `spec-migrator.md` | sonnet | Migrate SPEC.md/CLAUDE.md/AI.md to standard structure; bootstrap wizard |
| `statusline-setup.md` | haiku | Configure Claude Code status line fields |
| `test-writer.md` | sonnet | Write unit, integration, table-driven, and fuzz tests for existing code |

---

## Part 6: Hook Scripts (home/hooks/)

Hooks are bash scripts executed by Claude Code before or after tool use. They communicate back via stdout and exit code.

**Shebang:** `#!/usr/bin/env bash` — always bash, full header per script conventions.

**Exit code protocol:**

| Exit | Meaning |
|------|---------|
| `0` | Allow — tool use proceeds |
| `2` | Block — tool use is cancelled; stdout is shown to the user |

**Blocking output format:**

```bash
echo "BLOCKED: {reason why it was blocked}"
exit 2
```

**Input:** Hook receives tool input as JSON on stdin. Parse with `jq`.

**Rules:**
- Hooks must be fast — they run synchronously before/after every matching tool call
- Never do network I/O in a hook
- Never write to files from a hook (except append-only logs)
- Always handle `jq` parse failures gracefully — malformed input must not crash the hook
- Test hooks by piping sample JSON to them directly: `echo '{...}' | ./hooks/myhook.sh`

**Current hooks:**

| Hook | Trigger | Purpose |
|------|---------|---------|
| `session-start.sh` | SessionStart | Injects project_dir + CLAUDE.md/AI.md/SPEC.md precedence context on session start. Documented to also fire on `/clear` (`matcher: "clear"`), but a confirmed upstream bug ([anthropics/claude-code#34072](https://github.com/anthropics/claude-code/issues/34072), closed not-planned) means `SessionStart` hooks do not actually fire on `/clear` as of Claude Code 2.1.231 — CLAUDE.md's own "Session Start" section is the reliable fallback since CLAUDE.md is always reloaded on `/clear` regardless of hooks |
| `post-compact.sh` | SessionStart(compact) | Re-injects project-dir and global context after compaction |
| `drift-guard-read.sh` | PreToolUse Read | Blocks reading `~/.claude/` deployed copies when a `home/` source exists |
| `no-read-gitcommit.sh` | PreToolUse Read+Bash | Blocks reading the `gitcommit` script file (Read tool, and `cat`/`less`/`head`/etc. via Bash) — CLAUDE.md's Commit Workflow says it is "pre-approved and trusted" and must never be inspected, only invoked; no zone exception |
| `protect-host.sh` | PreToolUse Bash | Blocks destructive host commands; systemctl lifecycle mutation is exempt under `~/Projects/local/system/**` (cwd-scoped, see CLAUDE.md's Local System Management Zone) |
| `block-host-toolchain.sh` | PreToolUse Bash | Blocks direct host toolchain invocations and suggests the Docker equivalent |
| `enforce-docker-rm.sh` | PreToolUse Bash | Blocks `docker run` without `--rm`/`--name` and `incus launch`/`init` without an instance name (prevents orphaned/untargetable containers). `--rm` is exempt on detached (`-d`/`--detach`) containers, for multi-container integration testing (e.g. server/client) that needs to inspect a crashed container's logs before teardown — `--name` stays mandatory |
| `bound-shell-lifetime.sh` | PreToolUse Bash | Blocks unbounded shell lifetimes (infinite poll loops, open-ended sleeps/follows, untracked daemonization) |
| `zone-git-commit-push.sh` | PreToolUse Bash | Blocks raw `git commit`/`git push` outside `~/Projects/local/system/**`; allows them inside the zone (cwd-scoped, see CLAUDE.md's Local System Management Zone). `settings.json`'s `permissions.deny` cannot be directory-scoped, so this hook is the actual enforcement point — `git reset` stays hard-denied everywhere via `permissions.deny` |
| `no-subagent-commit.sh` | PreToolUse Bash | Blocks `gitcommit`/`git commit`/`git push` when the tool call's `agent_id` field is set (i.e. it came from a subagent, not the main session) — everywhere, including inside the zone. "Agents never commit" (CLAUDE.md's Agent Usage section) was prose-only with no technical gate until this hook |
| `no-force-push.sh` | PreToolUse Bash | Blocks `git push --force`/`-f`/`+refspec` everywhere, including inside the zone (`gitcommit` is the only sanctioned push path outside the zone; force-push is excluded from the zone's raw-git pre-authorization) |
| `no-history-rewrite.sh` | PreToolUse Bash | Blocks `git clean -f*`, `git rebase` (not `--abort`/`--continue`/`--skip`), `git branch -D`, `git tag -d`, `git filter-repo`, `git filter-branch` everywhere, including inside the zone (all excluded from the zone's raw-git pre-authorization — CLAUDE.md's Local System Management Zone, "Still hard" list) |
| `no-destructive-bypass.sh` | PreToolUse Bash | Re-enforces `settings.json`'s `permissions.deny` for `git reset`, `dd`, `shred`, `mkfs*`, `wipefs` with wrapper-bypass hardening (`\cmd`, `command cmd`, `env KEY=VAL cmd`) — `permissions.deny` only does raw glob matching on the literal command string, so a wrapped invocation slips past it |
| `bash-content-scan.sh` | PreToolUse Bash | Runs `no-secrets.sh`'s secret patterns and `no-ai-attribution.sh`'s attribution patterns against content written by a Bash heredoc or `echo`/`printf` redirect — those two hooks only ever see Write/Edit `tool_input`, so `cat <<EOF > file` bypassed both entirely. Same zone exemption for secrets, no zone exemption for AI attribution, container-mediated heredocs exempt |
| `enforce-gitcommit-shape.sh` | PreToolUse Bash | Blocks any `gitcommit` invocation that isn't exactly `gitcommit --dir <path> all` or the documented push-retry form `gitcommit push` — catches `-m`/`--message` and any other flag/argument shape, everywhere including inside the zone (`gitcommit` itself has no zone exception) |
| `validate-workflows.sh` | PreToolUse Bash | Validates staged `.github/workflows` files with `act --list` before `gitcommit` |
| `no-ai-attribution.sh` | PreToolUse Write+Edit | Blocks AI attribution phrases in file content |
| `no-secrets.sh` | PreToolUse Write+Edit | Scans Write/Edit content for high-confidence secret patterns and blocks if found; exempt under `~/Projects/local/system/**` (cwd-scoped, see CLAUDE.md's Local System Management Zone) |
| `no-forbidden-files.sh` | PreToolUse Write+Edit | Confirms before writing normally-forbidden files |
| `spec-guard.sh` | PreToolUse Write+Edit | Blocks Edit/Write on project files until AI.md/SPEC.md was read this session |
| `spec-guard-mark.sh` | PostToolUse Read | Records that AI.md/SPEC.md was read this session, per project |

**Wiring hooks in settings.json:**

```json
"hooks": {
  "PreToolUse": [
    {
      "matcher": "Bash",
      "hooks": [{ "type": "command", "command": "~/.claude/hooks/protect-host.sh" }]
    }
  ]
}
```

---

## Part 7: settings.json

Controls Claude Code permissions and hook wiring. Structure:

```json
{
  "permissions": {
    "allow": [...],
    "deny": [...],
    "ask": [...]
  },
  "hooks": {
    "PreToolUse": [...],
    "PostToolUse": [...]
  }
}
```

**Permission entry format:** `"{ToolName}({glob})"` — e.g. `"Edit(**/.git/COMMIT_MESS)"`.

**Rules:**
- Explicit `allow` entries are required for sensitive paths — Claude Code has built-in sensitivity overrides that `allow` globs alone may not bypass (e.g. `.git/**` paths need explicit entries)
- Sensitive files with explicit allows: `.git/COMMIT_MESS`, `.git/COMMIT_EDITMSG`, `CLAUDE.md`, `settings.json`, `settings.local.json`, `.env`, `app.env`, `default.env`
- `deny` takes precedence over `allow`
- Hook commands use `~/.claude/hooks/` paths — never relative paths

---

## Part 8: Working on This Repo

- The active working set is `home/` and its subdirectories
- No build or compilation step — all files are deployed as-is
- Test hooks manually before committing: `echo '{"tool":"Write","input":{"file_path":"test","content":"foo"}}' | bash home/hooks/no-ai-attribution.sh`
- Validate `settings.json` with `jq . home/settings.json` before committing
- Validate memory file frontmatter: must have `name`, `description`, `type` fields
- Run `install.sh` after committing to deploy — never deploy uncommitted changes
- Changes here affect every Claude Code session on the machine — test carefully

---

## Part 9: Template Repositories (../{lang|type}/{TYPE}.md)

"Templates" refers to the sibling repos next to this one — `~/Projects/github/claudemgr/{lang|type}/{TYPE}.md` — each a master `AI.md`-style spec copied verbatim into a generated project as that project's `AI.md`. The repo-name segment is not always a programming language — `go`/`rust` are languages, `android` is a device/platform target — so read `{lang|type}` as "whatever the repo is named," never assume it parses as a language.

**Default referent:** an unqualified "the templates" (e.g. "why do the templates say/have/miss X") always means these template repos — `go/`, `rust/`, `android/`, `docker/`, and `home/TEMPLATES/*.md` — and the search/fix scope is all of them. It never means `home/**`/`./home/*`/`./home` (this repo's deployed dotfiles/memory tree) unless the user names one of those paths explicitly.

**Filename convention per app category** (fixed, applies across every `{lang|type}` repo):

| Category | Filename |
|----------|----------|
| Full server (server-rendered HTML + optional REST) | `SERVER.md` |
| API-only (REST/JSON, no frontend) | `API.md` |
| Desktop/GUI/TUI/CLI app, no server component | `APPLICATION.md` (singular — not `APPLICATIONS.md`) |
| Hybrid — application surfaces (GUI/TUI/CLI) plus an embedded full server (frontend + backend) in one binary | `HYBRID.md` |

Not every repo ships every category — `android` is app-only (`APPLICATION.md` only, no `API.md`/`SERVER.md`/`HYBRID.md`), since there's no server-side Android target.

```
~/Projects/github/claudemgr/
├── config/                      # this repo — source of ~/.claude/
├── go/                           # github.com/claudemgr/go — language
│   ├── API.md                    # REST/JSON API server template
│   ├── APPLICATION.md            # GUI/TUI/CLI, no server, template
│   ├── HYBRID.md                 # application + embedded full server template
│   └── SERVER.md                 # full-stack web server template
├── rust/                         # github.com/claudemgr/rust — language
│   ├── API.md
│   ├── APPLICATION.md
│   ├── HYBRID.md
│   └── SERVER.md
├── android/                      # github.com/claudemgr/android — device/platform, app-only
│   └── APPLICATION.md            # no API.md/SERVER.md — app-only ecosystem
└── docker/                       # github.com/claudemgr/docker — Docker repo templates
    ├── DOCKERSRC.md              # master spec for dockersrc/* base-image repos
    ├── CASJAYSDEVDOCKER.md       # master spec for casjaysdevdocker/* app-image repos
    └── COMPOSEMGR.md             # master spec for composemgr/* compose-stack repos
```

More `{lang|type}` repos will be added over time (languages and device/platform targets alike) using this same filename convention — do not invent new filenames per repo.

**Exception — `docker/`:** it holds master specs for Docker *repositories* (`dockersrc/*` and `casjaysdevdocker/*` image repos, `composemgr/*` compose-stack repos), not app projects, so the app-category filenames don't apply. Its files are named per repo family (`DOCKERSRC.md`, `CASJAYSDEVDOCKER.md`, `COMPOSEMGR.md`; more may follow the same `{FAMILY}.md` pattern). Everything else about template repos applies unchanged: copied verbatim into a repo as its `AI.md`, WTFPL-licensed, own remote, own commits, swept by the alignment rule where content overlaps. The image-repo maintenance runbook lives in the `dockersrc-bootstrap` agent, not in the specs; compose repos need no runbook (no generator tooling).

**If a template dir doesn't exist locally**, clone it before reading/editing — never treat a missing dir as "no templates to update":

```bash
git clone https://github.com/claudemgr/{lang|type}.git ~/Projects/github/claudemgr/{lang|type}
```

**Alignment rule:** template repos are separate git repos, each with its own remote, its own `gitcommit --dir {repo} all`, and no dependency on this repo's git history — but their CI/CD, security, and build content MUST stay aligned with `home/**` (especially `home/memory/cicd_conventions.md`, `go_conventions.md`, `rust_conventions.md`). When a rule in `home/**` changes in a way that affects generated projects (e.g. a new CI gate, a new verification step), check the matching template file(s) in every existing `{lang|type}` repo for the same gap and fix them in the same session, as separate commits in their own repos — and sweep `home/TEMPLATES/` for the same gap in the same session (see below).

### Global Templates (home/TEMPLATES/, installed to ~/.claude/TEMPLATES/)

`home/TEMPLATES/` holds two species of template; both are templates in the full sense — every template-authoring rule (no inline comments, no hardcoded versions, placeholder system, templates follow their own rules) applies to them exactly as it does to the repo templates:

| File | Species | Role |
|------|---------|------|
| `BASE.md` | **Project template** | Generic fallback member of the project-template family — copied into a project as its `AI.md` when language/shape is unknown; replaced by a `{lang|type}/{TYPE}.md` once known |
| `BILLING.md`, `NOTIFICATIONS.md`, `SUPPORT.md` | **Feature template** | Authoritative feature-module spec applied INTO an existing project by its builder agent (`billing-builder`, `notifications-builder`, `support-builder`) — never a whole-project spec |

**Terminology:** "project templates" = the `{lang|type}/{TYPE}.md` repo specs plus `BASE.md`; "feature templates" = the builder-agent specs. Unqualified "templates" continues to mean the repo templates.

**Alignment, two tiers:**

- `BASE.md` aligns with the template repos on ALL shared canon (release-flow skeleton, version/build-metadata rules, checksum format, commit workflow, verification gates). It stays language-agnostic — it states the canon generically and defers language-specific mechanics to the `{lang|type}` templates that replace it.
- Feature templates align where they OVERLAP shared canon (CI additions, security rules, DB/config conventions) but defer to the host project's template on build/release matters — a feature template never redefines the release flow.

**Sweep rule:** any canon change that triggers a template-repo sweep also triggers a `home/TEMPLATES/` sweep in the same session (BASE.md always; feature templates when the change touches content they overlap).

Templates are licensed WTFPL (the templates themselves); generated projects ship MIT.

---

## Part 10: Commit Conventions

Follow the global gitcommit workflow from `home/CLAUDE.md`. One logical change per commit.

When adding a memory file: commit both the new file and the updated `MEMORY.md` together.
When adding an agent: commit the agent file; update `AI.md` Part 5 table in the same commit.
When adding a hook: commit the script and the updated `settings.json` wiring together.
