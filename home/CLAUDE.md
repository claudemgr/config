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

## Code & Files
- Read current file state before any edit
- Stay in scope — no unrequested refactors, reformats, or extras
- Match surrounding style: naming, indentation, patterns
- Use ecosystem idioms; run the community linter/formatter
- Use existing standards (POSIX exit codes, HTTP status codes, RFCs, semver, ISO 8601) — never invent wire protocols or error schemes
- Targeted edits only; full rewrites only when asked
- Required deps: just add them. Real choice between alternatives: ask first

## Sensitive Data
**Never add tokens, API keys, passwords, private keys, internal hostnames, or any credentials to a git repo** unless the user explicitly instructs it or has already committed them manually.

All git repos are treated as public by default — even private ones. The only exception is a personal dotfiles repo that is explicitly designated private and intended to hold credentials (env files, SSH keys, etc.). Context determines this — do not assume; if unclear, ask.

When credentials are needed at runtime: use environment variables, mounted secrets, or a secrets manager. Never hardcode. Never store in source.

## Verification & Safety
- Confirm before: `rm -rf`, force pushes, dropping tables/branches, anything irreversible
- **Never run unrequested destructive ops, even to "fix"** — stop and ask. (Ref: April 2026 PocketOS incident — agent wiped prod DB + 3 months of backups in 9s "fixing" a staging credential issue)
- Verify APIs/flags exist before using them; cite file:line for any code reference
- Run code before calling it done; iterate until verification actually passes
- Plan (use plan mode) for changes touching 3+ files or ambiguous requirements

## Build & Execution
- Dev images: rolling tags (`golang:alpine`, `node:alpine`, etc.) — never pinned
- Execution hierarchy: VM > Incus > Docker > host (host only when no lower level works)
- Target `linux/amd64` + `linux/arm64` by default
- Builds are reproducible in containers; nothing depends on host-installed toolchain

## Project Defaults
- License: MIT · Single self-contained binary · First-run works with zero config
- No feature gating; all functionality available to all users
- Telemetry opt-in only; never hardcode tracking IDs or site keys
- Web UIs: mobile-responsive from day one
- Security in code: parameterized queries, constant-time comparison, CSRF/XSS/SSRF/IDOR/path-traversal guards

## Output
- No preamble, no reflexive agreement, no closing recap
- Show diffs, not prose retellings of changes
- No emojis unless asked (exception: commit messages follow project convention)
- **No AI attribution** — no `Co-Authored-By:`, AI-tool trailers, or "Generated with X" footers anywhere
- Next step is clear → do it. Pause only for genuine blockers or destructive-op confirmation

## Agent Usage
- **Haiku for trivial tasks** — renames, format conversions, single-line edits, simple lookups, mechanical refactors: spawn via `Agent` with `model: "haiku"`. Reserve Sonnet for judgment, multi-file coordination, or design decisions.

## Autonomy
- Action commands ("fix all issues", "run the tests", "deploy") → execute fully without step-by-step confirmation
- "Run X" pre-authorizes X and its entire workflow (subcommands, loops, retries, pipes) for this session
- File sensitivity is defined by `protect-host.sh` — `.git/COMMIT_*`, `CLAUDE.md`, lock files, and build artifacts are safe to write without asking

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
