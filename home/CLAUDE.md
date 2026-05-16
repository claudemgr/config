# Claude Rules

## Global Memory
Read `~/.claude/memory/MEMORY.md` at session start and load referenced files as needed.

Provider-specific convention files (`github_conventions.md`, `gitlab_conventions.md`, `gitea_conventions.md`, `forgejo_conventions.md`) are loaded **on demand only** — detect the provider from `git remote get-url origin` and load only the matching file. Never pre-load all provider files.

## Compaction
Preserve: task goal · files changed · commands run · failing tests/errors · decisions · next actions.
Drop: old exploration paths · repeated logs · irrelevant discussion.

## Communication
- Truthful over agreeable — push back, correct, disagree when warranted; useful beats pleasant
- Ask if unsure; never guess or assume
- `?` ends a message → it's a question, not a command — answer it
- A message ending in `?` that contains an action verb ("Can you add X?", "Should we fix Y?", "Would it make sense to refactor Z?") is still a question — answer it, do not silently treat it as a command. Only act if the user re-sends without the `?` or explicitly says "yes" / "do it" / "go ahead"
- Multiple questions → numbered list; user replies "1: … 2: …"
- Match user's terminology exactly; never rename their domain language
- `{x}` = placeholder to substitute; `x` = literal text

## Spelling & Grammar
- Always fix clear spelling and grammar errors encountered in any file being edited — typos, missing letters, doubled letters, wrong verb forms (e.g. "not install" → "not installed", "successssful" → "successful"). Only correct when certain it is an error; never alter technical terms, intentional abbreviations, or domain-specific names.

## Drift Prevention

Drift = ignoring project-specific rules and reverting to global defaults or prior-session assumptions. It is the primary failure mode of long or compacted sessions.

**What drift looks like:**
- Reading `~/.claude/` files when inside a project that has source equivalents
- Writing outside `{project_dir}` without the user naming an external path
- Applying CI/CD syntax from a different provider than the one detected
- Using global fallback behavior because the project-specific rule was compacted away
- Expanding scope beyond what was asked ("while I'm here" changes)

**Self-check before any read or write:**
1. Is this path inside `{project_dir}`?
2. Does this project have its own version of this file (AI.md, CLAUDE.md, memory files)?
3. Am I applying a rule from THIS project's files, not a global assumption?
4. Is the working set still what the user defined — or have I quietly expanded it?

**When context has been compacted:** treat all rules as needing re-verification from the project's CLAUDE.md and AI.md. Do not assume the compacted summary preserved every constraint.

**If a SessionStart or PostCompact system message references a project_dir:** that path IS `{project_dir}` for this session — use it.

---

## Working Directory & Path Resolution

- **CWD is `$PWD`** — all relative paths (`AI.md`, `./src`, `./`) resolve from there
- **Absolute paths** (`/…`, `~…`) are taken as-is; never prepend CWD to them
- **`{project_dir}`** = `git rev-parse --show-toplevel` if inside a git repo; otherwise = the directory Claude was launched from (`$PWD` at session start)
- **Project files override global**: if `{project_dir}/CLAUDE.md` or `{project_dir}/AI.md` exists, it is the source of truth and supersedes the global `~/.claude/CLAUDE.md` equivalent for that session
- **Stay inside `{project_dir}`** — all writes and edits must target paths within `{project_dir}` unless the user explicitly names an external path. Never reach outside the project tree (e.g. `~/.claude/`, `/etc/`, another repo) on your own initiative, even when a file there "should" be updated as a side effect of the task

## Code & Files
- Read current file state before any edit
- Stay in scope — no unrequested refactors, reformats, or extras
- **Working-set discipline** — the active working set is established when the user says "we are working on X" or names a directory/file group. It stays in force until the user explicitly redirects. Never expand scope on your own initiative — not for related fixes, not for consistency, not for "while we're here" improvements. If a related issue is spotted outside the working set, note it but don't act on it. Exception: spelling/grammar fixes in files already being edited are always permitted
- **Fix completeness — propagate every fix** — when a pattern, convention, tool, or value is changed anywhere in the working set, find and fix ALL instances of it across the working set before committing. Use `grep -rn` to locate every occurrence. A fix that leaves surviving instances of the old pattern is a new bug, not a completed fix. This is NOT scope expansion — it is required completeness. The distinction: working-set discipline prevents adding new features or touching unrelated code; fix propagation requires that a change is applied everywhere it applies within scope. Partial fixes are worse than no fix because they create inconsistency.
- Match surrounding style: naming, indentation, patterns
- Use ecosystem idioms; run the community linter/formatter
- Use existing standards (POSIX exit codes, HTTP status codes, RFCs, semver, ISO 8601) — never invent wire protocols or error schemes
- Targeted edits only; full rewrites only when asked
- Required deps: just add them. Real choice between alternatives: ask first
- **No partially implemented code** — never commit a stub, a `TODO` placeholder inside logic, an unimplemented interface method, or code that calls a function that does not exist yet. Every line of committed code must work as written. If full implementation requires more scope than the current task allows, stop and discuss — do not commit partial work and move on.
- **No TODO/FIXME/HACK in committed code** — resolve before committing or open a tracked issue and reference it; never commit a reminder to future-you
- **No commented-out code** — delete it; git history is the undo mechanism
- **No comments in JSON** — JSON has no comment syntax; they break parsers
- **Singular directory names** — `handler/`, `model/`, `middleware/` not `handlers/`/`models/`; exception: tooling dirs follow community convention (`scripts/`, `tests/`, `completions/`)

## Sensitive Data
**Never add tokens, API keys, passwords, private keys, internal hostnames, or any credentials to a git repo** unless the user explicitly instructs it or has already committed them manually.

All git repos are treated as public by default — even private ones. The only exception is a personal dotfiles repo that is explicitly designated private and intended to hold credentials (env files, SSH keys, etc.). Context determines this — do not assume; if unclear, ask.

When credentials are needed at runtime: use environment variables, mounted secrets, or a secrets manager. Never hardcode. Never store in source.

**Paste services** (pastebin, GitHub Gist, paste.rs, etc.) are treated identically to public git repos — "private" pastes are still public. Never paste credentials, keys, internal config, or PII. Apply the same pre-flight check as a `git push` before posting anything.

- **Never store tokens in plaintext** — hash with SHA-256 before storing; never log raw tokens
- **Never hardcode machine-specific values** — hostname, IP, CPU count, memory size — always detect at runtime on the target machine
- **Credential masking** — when displaying or logging a credential, preserve the key name and replace the value with `xxxxx`; never log partial values

## Project Files & Naming
- See `~/.claude/memory/project_conventions.md` for `{project_dir}/AI.md` / `{project_dir}/IDEA.md` / `{project_dir}/CLAUDE.md` roles, placeholder system, first-time setup flow, and directory layout
- See `~/.claude/memory/project_forbidden_files.md` for file/directory rules including README.md, LICENSE.md naming, and what must never be created
- **`TODO.AI.md` hygiene** — complete each item fully — code working, tests passing, committed — before removing it and starting the next. Never clear an item while its work is still in progress, and never start a new item while the current one is incomplete. Remove items only when done; never leave them marked done and accumulating. **`PLAN.AI.md` hygiene** — delete the file once the work it describes is fully committed

## Cleanup
- **Clean up immediately** — stop/remove every container, VM, volume, network, and temp file as soon as it is no longer needed; never leave them running until session end
- **Track what you start** — note name/ID before spinning anything up; cleanup is part of the same task
- Only remove project-specific resources; never broad sweeps (`docker system prune`, `rm -rf /tmp/*`)
- Full rules: `~/.claude/memory/execution_hierarchy.md`

## Verification & Safety
- Confirm before: `rm -rf`, force pushes, dropping tables/branches, anything irreversible
- **Never run unrequested destructive ops, even to "fix"** — stop and ask. (Ref: April 2026 PocketOS incident — agent wiped prod DB + 3 months of backups in 9s "fixing" a staging credential issue)
- **Never auto-bypass a hook block** — if a PreToolUse hook returns `BLOCKED:`, do NOT retry the same command. Tell the user what was blocked and what it would destroy; only the user decides whether to proceed
- Verify APIs/flags exist before using them; cite file:line for any code reference
- Run code before calling it done; iterate until verification actually passes
- Plan (use plan mode) for genuinely ambiguous requirements or architectural decisions with real tradeoffs — not simply because a task touches many files

**Memory Safety — these apply to every line of code in every language:**
- `unsafe` (Rust) / `import "unsafe"` (Go) requires a justification comment at the call site and a note in `{project_dir}/IDEA.md`
- Never spawn unbounded goroutines/threads — always cap with a semaphore, worker pool, or context cancellation
- Never spawn processes inside an unthrottled loop — every subprocess spawn must have a concurrency limit
- Never call `ulimit -u unlimited`, `setrlimit(RLIM_INFINITY)`, or equivalent — raise limits to a specific documented ceiling only
- Every network call, DB query, subprocess wait, channel receive, and lock acquisition must have a timeout or deadline — infinite block = eventual hang
- Every opened file, socket, or pipe must be closed — `defer f.Close()` (Go), RAII/`Drop` (Rust), `trap`/explicit close (shell)
- Never `rm -rf "$VAR/"` without a `[ -n "$VAR" ]` guard; never `DROP TABLE` or `DELETE FROM` without a `WHERE`
- Size-cap all untrusted input before buffering — no `ReadAll`/`read_to_string` on an unbounded network stream without a `LimitedReader`/`take()` guard

## Self-Validation
- **Verify against ground truth** — UI: compare to design/screenshot. Logic: compare to expected output. Data: spot-check a sample
- **Iterate until passing** — don't stop at "compiles"; keep going until success criteria are met
- **Define success up front** — before non-trivial work, state what "done" looks like (test passes, output matches, lint clean)
- **Add tests for new behavior** — for non-trivial functionality: add a test that fails before and passes after, then run it
- **One run, then fix** — run build/test once per change; don't loop on flaky failures without a hypothesis

## Build & Execution
- Execution hierarchy: QEMU/KVM > Incus > Docker > host — Docker uses official alpine variants (`golang:alpine`, `rust:alpine`); Incus for systemd/distro tests; QEMU/KVM for full OS. See `~/.claude/memory/execution_hierarchy.md`
- Dev images: rolling tags — never pinned
- Target `linux/amd64` + `linux/arm64` by default
- Builds are reproducible in containers; nothing depends on host-installed toolchain
- **Container startup chain: `tini → entrypoint.sh → app`** — never override or bypass; all startup customization goes in `entrypoint.sh`
- `docker-compose.yml` must have hardcoded sane defaults and work with zero `.env` — users override by editing the file, not by creating `.env`
- Cleanup: never remove base images (`golang`, `alpine`, `ubuntu`, etc.) — only `{project_org}/{internal_name}:*` images
- Temp dirs: never hardcode `/tmp`; use `$TMPDIR`/`os.TempDir()`/`std::env::temp_dir()`; always org-prefixed — see `~/.claude/memory/tempdir_conventions.md`
- **`docker run` must use `--rm`** — every build/test container must self-remove on exit; no orphaned containers
- **Test container network isolation** — always create a named bridge network for tests; never use the default bridge or `--network host`

## UI/UX
- Any UI work — web, desktop, mobile, TUI — must be approached with designer-level intent. "It works" is not enough; aim for clarity, consistency, and delight.
- Dark mode is the default. Every UI must support dark / light / auto (follows OS preference). Never hardcode colors — use CSS custom properties (web) or a shared theme struct (desktop/TUI).
- For non-trivial UI tasks, invoke the `designer` agent. See `~/.claude/memory/ui_ux_conventions.md` for the full design system.

## Security by Design

Security is first-class from day one — never bolted on after. It must also be user-friendly: friction-free for honest users, hard for attackers.

- **Secure default** — the safe path is the easy path. Insecure options require explicit opt-in; never make the user work harder to be secure
- **Fail closed** — when in doubt, deny and explain clearly; never silently allow
- **Least privilege** — request only the permissions actually needed; drop them as soon as they are no longer needed
- **Explicit trust boundaries** — document what is trusted (authenticated session, signed payload, internal network) and what is not; never assume
- **No security through obscurity** — assume the attacker knows your code, your schema, and your algorithm choices; security must hold even so
- **Defense in depth** — no single control is the last line; layer authentication, authorization, input validation, output encoding, and rate limiting independently
- **Rate-limit all auth endpoints** — login, password reset, OTP, token refresh — with exponential backoff and lockout; brute force is always in scope
- **Audit log security-relevant events** — auth success/failure, permission changes, admin actions, data exports; logs are append-only and never contain raw credentials
- **No security theater** — do not impose friction that punishes honest users without meaningfully stopping attackers (e.g. forced password rotation on a schedule unrelated to breach, CAPTCHA on low-risk flows, MFA on non-sensitive pages)
- **Clear security errors** — when a request is blocked or fails a security check, tell the user what happened and what to do next; never return a bare 403 or "access denied" with no context
- **Enumeration mitigation** — identical message and timing for "wrong password" vs "no such user"; opaque IDs over sequential integers; never confirm account existence on password reset; see `~/.claude/memory/security_conventions.md`
- **GeoIP is a signal, not a gate** — country blocks are risk signals only; never use GeoIP as the sole access control; VPNs bypass it trivially; see `~/.claude/memory/security_conventions.md`
- **CVE pre-flight** — run `govulncheck` (Go) / `cargo audit` (Rust) / `npm audit` (Node) before adding any dependency and before committing; never ship a critical/high CVE in direct deps; see `~/.claude/memory/security_conventions.md`

## Project Defaults
- License: MIT · Single self-contained binary · First-run works with zero config
- No feature gating; all functionality available to all users
- Telemetry opt-in only; never hardcode tracking IDs or site keys
- Web UIs: mobile-responsive from day one
- Security in code: parameterized queries, constant-time comparison, CSRF/XSS/SSRF/IDOR/path-traversal guards
- **Password hashing: Argon2id only** — never bcrypt, never scrypt, never MD5/SHA for passwords

## Language Constraints

**Go:**
- `CGO_ENABLED=0` always — pure Go, no C, no exceptions
- No `-musl` suffix on Alpine/musl builds — omit it
- Use project `config.ParseBool()` not `strconv.ParseBool()` (handles 40+ variations)
- Never run `go` directly on host — always via `make dev` / `make test` / `make build` (Docker internally)
- Never depend on host cron or systemd timers — use a built-in scheduler (`robfig/cron`, `go-co-op/gocron`, or a ticker loop)
- Server projects: Go templates rendered server-side only — no client-side rendering

**Node / TypeScript:**
- `strict: true` in `tsconfig.json` — no `any` without a comment explaining why
- ESLint + Prettier required; `eslint --max-warnings 0` in CI — zero tolerance
- Never `require()` in TypeScript — `import` only; enable `"moduleResolution": "bundler"` or `"node16"`
- Never `process.exit()` in library code — only in CLI entry points
- `package.json` scripts must work without global installs — use `npx` or `./node_modules/.bin/`
- `npm ci` in CI (reproducible); `npm install` only for local dev
- No CDN scripts in HTML — bundle all assets at build time (no `<script src="https://..."`)
- Never log `req`, `res`, or `ctx` objects — they contain credentials; log only safe fields

**Python:**
- `python3 -m venv` or `uv` for isolation — never install project deps into the system Python
- Type hints required on all function signatures; run `mypy --strict` or `pyright` in CI — type errors are build failures
- `ruff` for both linting and formatting — replaces flake8, isort, black; zero warnings in CI
- No `import *` — explicit imports only
- `pathlib.Path` over `os.path` for all filesystem operations
- No `eval()`, `exec()`, or `__import__()` with untrusted input — these are arbitrary code execution

**Rust:**
- Never run `cargo` directly on host — all cargo invocations run inside Docker
- No `*-sys` dynamic linkage — vendored C deps must be statically linked; no `.so`/`.dylib`/`.dll` at runtime
- No GPL/AGPL/LGPL dependencies without an explicit `{project_dir}/IDEA.md` exception — static linking relicenses the binary
- No `dlopen` or runtime extension loading unless `{project_dir}/IDEA.md` defines a hardened plugin contract
- No CDN or network fetch on first run — all assets embedded at build time

## Output
- No preamble, no reflexive agreement, no closing recap
- **Tight output budget** — status updates and requested summaries: 1–3 sentences max. No headers/bullets/sections unless the task requires structured output
- Show diffs, not prose retellings of changes
- No emojis in code or inline tool output unless asked
- Emojis **are appropriate** in READMEs, documentation, and commit messages where they aid readability or navigation
- **No AI attribution** — no `Co-Authored-By:`, AI-tool trailers, or "Generated with X" footers anywhere
- Next step is clear → do it. Pause only for genuine blockers or destructive-op confirmation

## Tool Preference
- Always use the right tool for the job if installed: `jq` for JSON, `yq` for YAML, `bc` for math, `grep`/`sed`/`awk` for text, `git` for version control, etc.
- **Provider CLIs** — prefer over raw `curl` for provider API operations when installed:
  - `gh` (GitHub CLI, Apache-2.0) — issues, PRs, releases, repo ops on GitHub
  - `tea` (Gitea CLI, MIT) — same operations on Gitea; also works against Forgejo (compatible API)
  - `glab` (GitLab CLI, MIT) — same operations on GitLab
  - Fall back to `curl -q -LSsf` only when the provider CLI is not installed or the operation has no CLI equivalent
- **`act`** (nektos/act, MIT) — run GitHub Actions workflows locally before pushing; use `act -j {job}` to test a specific job. Never use `act` to bypass CI gates — it is a pre-push verification tool only.
- Use `python3` only when no purpose-built tool can handle the task cleanly
- **curl default:** `curl -q -LSsf {url}` — `-q` suppresses config file, `-L` follows redirects, `-S` shows errors, `-s` suppresses progress meter. Only add `-#` (or drop `-s`) when a progress bar is explicitly needed.
- **wget default:** `wget -q {url}` — `-q` suppresses all output except errors. Only omit `-q` or add `--show-progress` when a progress bar is explicitly needed.
- **grep default:** always `grep {flags} -- {query}` — `--` prevents a query starting with `-` being treated as a flag. Never use `egrep`, `fgrep`, or `rgrep` — use `grep -E`, `grep -F`, `grep -r` instead. This applies to every grep invocation, including in Bash tool calls.
- **Images:** always convert before reading — max 1280px longest side, WebP target, fallback chain `convert` → `ffmpeg` → `vips` → original. URL images: curl to tempdir first, then convert, then read. See `~/.claude/memory/image_conventions.md`.

## Token & Context Discipline
- **Use the explorer subagent for broad codebase searches** — searches spanning 3+ files, unknown locations, or multiple naming conventions: dispatch via explorer. Don't grep-walk in main context — search results bloat conversation history forever. Direct grep/find is fine for one specific known target
- **Read files narrowly** — for files >500 lines: use `offset`/`limit`, or grep first to find the slice. Don't load 2000 lines when you need 50
- **No speculative reads** — only read files the current task directly requires. Do not open adjacent files because they "might be relevant." If a file turns out to be needed, read it then.
- **Don't re-read after editing** — Edit/Write errors if the change fails; no verification re-read needed. The one explicit exception: `COMMIT_MESS` must be written from the actual `git status`/`git diff` output (never from memory), then re-read once to verify it matches the diff before running `gitcommit` — a push is irreversible and COMMIT_MESS must reflect actual state, not assumptions.
- **Don't spawn agents for small tasks** — if the work fits in 2–3 direct tool calls, do it inline. Agent overhead (launch, context transfer, result relay) costs more tokens than the task itself for simple lookups, single-file edits, or short shell commands.
- **Plan mode is for genuine ambiguity, not file count** — invoke plan mode when requirements are unclear or the approach has real tradeoffs, not simply because a task touches 3+ files. Mechanical changes across many files (rename, find-replace, bulk fix) do not need a plan.
- **Parallelize independent research** — multiple independent questions: spawn agents in parallel (single message, multiple Agent calls)

## Agent Usage
- **Haiku for trivial tasks** — renames, format conversions, single-line edits, simple lookups, mechanical refactors: spawn via `Agent` with `model: "haiku"`. Reserve Sonnet for judgment, multi-file coordination, or design decisions.

## Autonomy
- Action commands ("fix all issues", "run the tests", "deploy") → execute fully without step-by-step confirmation
- "Run X" pre-authorizes X and its entire workflow (subcommands, loops, retries, pipes) for this session
- Write/Edit allowlists are defined in `{project_dir}/.claude/settings.json` `permissions.allow` — the following `{project_dir}/`-relative paths are pre-approved: `.git/COMMIT_MESS`, `.git/COMMIT_EDITMSG`, `CLAUDE.md`, `AI.md`, `IDEA.md`, `TODO.AI.md`, `TODO.md`, `PLAN.AI.md`, `PLAN.md`, `.claude/settings.json`, `.claude/settings.local.json`, and `.env`/`app.env`/`default.env`. Destructive Bash ops are gated separately by `protect-host.sh`

## Task Dependency Ordering
When executing a task list, dependency graph takes priority over label order. Numbered/lettered sequence is a tiebreaker only — never an execution mandate.
- Scan any task list for stated dependencies ("X before Y", "requires X", "needs X first") before starting
- Topological-sort the graph; use label order only to break ties among tasks at the same depth
- A task is only "ready" when all its prerequisites are complete
- If a dependency is ambiguous, ask — never assume order
- For non-trivial graphs (3+ dependencies), document the resolved order at the top of TODO.AI.md or PLAN.AI.md

**Example:** tasks 1, 2, 3 and a, b, c where c→2 and a→2: correct order is `1, a, c, 2, b, 3` — not `1, 2, 3, a, b, c`.

## Commit Workflow
`git commit` and `git push` are denied. `gitcommit` (resolved from PATH) is the only commit path — signs, stages, commits, and pushes in one invocation. Workflow is pre-approved; commit without asking, but verify the message first.

**Only valid invocation:** `gitcommit --dir {dir} all`
- `{dir}` = absolute path to the project root
- `all` is the only command — other subcommands commit one file at a time
- Never use `-m` / `--message` — bypasses the message file

**Pre-commit sequence:**
1. `git status --porcelain` + `git diff --stat` — see actual changes
2. Write `{dir}/.git/COMMIT_MESS` directly from that output — every changed file, each change described, nothing missing. Never write from memory of what you think you changed; always derive from the diff you just ran.
3. Re-read `COMMIT_MESS` and compare against the diff — verify every changed file is listed, every description is accurate. If anything is missing or wrong, rewrite the file and re-read again.
4. Run `gitcommit --dir {dir} all` — wrapper deletes `COMMIT_MESS` on success

**Message format:** `{emoji} Title (≤64 chars) {emoji}` + blank line + body + `- path: change` bullets per file

Emoji map: ✨ feat · 🐛 fix · 📝 docs · 🎨 style · ♻️ refactor · ⚡ perf · ✅ test · 🔧 chore · 🔒 security · 🗑️ remove · 🚀 deploy · 📦 deps

**Cadence:** one logical change per commit. Unrelated subsystems → split. Mid-task inconsistent state → do NOT commit.

**Lint gate:** run the appropriate agent before committing — `script-lint` for shell, `go-lint` for Go, `rust-lint` for Rust. Do not commit if the linter reports violations.

**CI/CD:** third-party GitHub Actions must be pinned to a full commit SHA — never a tag (`uses: actions/checkout@v4` is forbidden; `uses: actions/checkout@{sha}` is required).

**Push is immediate and irreversible.** To skip: `touch .no_push` at repo root (confirm with user first). If push fails offline: run `gitcommit push` later — do NOT recreate `COMMIT_MESS`.
