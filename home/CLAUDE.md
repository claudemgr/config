# Claude Rules

## Global Memory
Read `~/.claude/memory/MEMORY.md` at session start and load referenced files as needed.

## Compaction
Preserve: task goal · files changed · commands run · failing tests/errors · decisions · next actions.
Drop: old exploration paths · repeated logs · irrelevant discussion.

## Communication
- Truthful over agreeable — push back, correct, disagree when warranted; useful beats pleasant
- Ask if unsure; never guess or assume
- `?` ends a message → it's a question, not a command — answer it
- Multiple questions → numbered list; user replies "1: … 2: …"
- Match user's terminology exactly; never rename their domain language
- `{x}` = placeholder to substitute; `x` = literal text

## Spelling & Grammar
- Always fix clear spelling and grammar errors encountered in any file being edited — typos, missing letters, doubled letters, wrong verb forms (e.g. "not install" → "not installed", "successssful" → "successful"). Only correct when certain it is an error; never alter technical terms, intentional abbreviations, or domain-specific names.

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
- Match surrounding style: naming, indentation, patterns
- Use ecosystem idioms; run the community linter/formatter
- Use existing standards (POSIX exit codes, HTTP status codes, RFCs, semver, ISO 8601) — never invent wire protocols or error schemes
- Targeted edits only; full rewrites only when asked
- Required deps: just add them. Real choice between alternatives: ask first
- **No comments in JSON** — JSON has no comment syntax; they break parsers
- **Singular directory names** — `handler/`, `model/`, `middleware/` not `handlers/`/`models/`; exception: tooling dirs follow community convention (`scripts/`, `tests/`, `completions/`)

## Sensitive Data
**Never add tokens, API keys, passwords, private keys, internal hostnames, or any credentials to a git repo** unless the user explicitly instructs it or has already committed them manually.

All git repos are treated as public by default — even private ones. The only exception is a personal dotfiles repo that is explicitly designated private and intended to hold credentials (env files, SSH keys, etc.). Context determines this — do not assume; if unclear, ask.

When credentials are needed at runtime: use environment variables, mounted secrets, or a secrets manager. Never hardcode. Never store in source.

**Paste services** (pastebin, GitHub Gist, paste.rs, etc.) are treated identically to public git repos — "private" pastes are still public. Never paste credentials, keys, internal config, or PII. Apply the same pre-flight check as a `git push` before posting anything.

- **Never store tokens in plaintext** — hash with SHA-256 before storing; never log raw tokens
- **Never hardcode machine-specific values** — hostname, IP, CPU count, memory size — always detect at runtime on the target machine

## Project Files & Naming
- See `~/.claude/memory/project_conventions.md` for `{project_dir}/AI.md` / `{project_dir}/IDEA.md` / `{project_dir}/CLAUDE.md` roles, placeholder system, first-time setup flow, and directory layout
- See `~/.claude/memory/project_forbidden_files.md` for file/directory rules including README.md, LICENSE.md naming, and what must never be created

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
- Plan (use plan mode) for changes touching 3+ files or ambiguous requirements

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

## UI/UX
- Any UI work — web, desktop, mobile, TUI — must be approached with designer-level intent. "It works" is not enough; aim for clarity, consistency, and delight.
- Dark mode is the default. Every UI must support dark / light / auto (follows OS preference). Never hardcode colors — use CSS custom properties (web) or a shared theme struct (desktop/TUI).
- For non-trivial UI tasks, invoke the `designer` agent. See `~/.claude/memory/ui_ux_conventions.md` for the full design system.

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
- Use `python3` only when no purpose-built tool can handle the task cleanly
- **curl default:** `curl -q -LSsf {url}` — `-q` suppresses config file, `-L` follows redirects, `-S` shows errors, `-s` suppresses progress meter. Only add `-#` (or drop `-s`) when a progress bar is explicitly needed.
- **wget default:** `wget -q {url}` — `-q` suppresses all output except errors. Only omit `-q` or add `--show-progress` when a progress bar is explicitly needed.
- **grep default:** always `grep {flags} -- {query}` — `--` prevents a query starting with `-` being treated as a flag. Never use `egrep`, `fgrep`, or `rgrep` — use `grep -E`, `grep -F`, `grep -r` instead. This applies to every grep invocation, including in Bash tool calls.
- **Images:** always convert before reading — max 1280px longest side, WebP target, fallback chain `convert` → `ffmpeg` → `vips` → original. URL images: curl to tempdir first, then convert, then read. See `~/.claude/memory/image_conventions.md`.

## Token & Context Discipline
- **Use the explorer subagent for broad codebase searches** — searches spanning 3+ files, unknown locations, or multiple naming conventions: dispatch via explorer. Don't grep-walk in main context — search results bloat conversation history forever. Direct grep/find is fine for one specific known target
- **Read files narrowly** — for files >500 lines: use `offset`/`limit`, or grep first to find the slice. Don't load 2000 lines when you need 50
- **Don't re-read after editing** — Edit/Write errors if the change fails; no verification re-read needed
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
2. Write `{dir}/.git/COMMIT_MESS` — every changed file, each change described, nothing missing
3. Re-read `COMMIT_MESS` to verify it matches reality
4. Run `gitcommit --dir {dir} all` — wrapper deletes `COMMIT_MESS` on success

**Message format:** `{emoji} Title (≤64 chars) {emoji}` + blank line + body + `- path: change` bullets per file

Emoji map: ✨ feat · 🐛 fix · 📝 docs · 🎨 style · ♻️ refactor · ⚡ perf · ✅ test · 🔧 chore · 🔒 security · 🗑️ remove · 🚀 deploy · 📦 deps

**Cadence:** one logical change per commit. Unrelated subsystems → split. Mid-task inconsistent state → do NOT commit.

**Push is immediate and irreversible.** To skip: `touch .no_push` at repo root (confirm with user first). If push fails offline: run `gitcommit push` later — do NOT recreate `COMMIT_MESS`.
