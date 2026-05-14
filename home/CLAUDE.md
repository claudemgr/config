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

## Code & Files
- Read current file state before any edit
- Stay in scope — no unrequested refactors, reformats, or extras
- **Working-set discipline** — the active working set is established when the user says "we are working on X" or names a directory/file group. It stays in force until the user explicitly redirects. Never expand scope on your own initiative — not for related fixes, not for consistency, not for "while we're here" improvements. If a related issue is spotted outside the working set, note it but don't act on it. Exception: spelling/grammar fixes in files already being edited are always permitted
- Match surrounding style: naming, indentation, patterns
- Use ecosystem idioms; run the community linter/formatter
- Use existing standards (POSIX exit codes, HTTP status codes, RFCs, semver, ISO 8601) — never invent wire protocols or error schemes
- Targeted edits only; full rewrites only when asked
- Required deps: just add them. Real choice between alternatives: ask first

## Sensitive Data
**Never add tokens, API keys, passwords, private keys, internal hostnames, or any credentials to a git repo** unless the user explicitly instructs it or has already committed them manually.

All git repos are treated as public by default — even private ones. The only exception is a personal dotfiles repo that is explicitly designated private and intended to hold credentials (env files, SSH keys, etc.). Context determines this — do not assume; if unclear, ask.

When credentials are needed at runtime: use environment variables, mounted secrets, or a secrets manager. Never hardcode. Never store in source.

## Project Files & Naming
- See [project conventions](memory/project_conventions.md) for AI.md/IDEA.md/CLAUDE.md roles, placeholder system, first-time setup flow, and directory layout
- See [project forbidden files](memory/project_forbidden_files.md) for file/directory rules including README.md, LICENSE.md naming, and what must never be created

## Cleanup
- When cleaning up after a task, only remove project-specific resources — containers, images, volumes, networks, and temp files created **by this project**
- Never do a broad cleanup (e.g. `docker system prune`, `docker rmi $(docker images -q)`, `rm -rf /tmp/*`) — that destroys unrelated work
- Identify project resources by name/label/prefix before removing anything; if uncertain, list and ask

## Verification & Safety
- Confirm before: `rm -rf`, force pushes, dropping tables/branches, anything irreversible
- **Never run unrequested destructive ops, even to "fix"** — stop and ask. (Ref: April 2026 PocketOS incident — agent wiped prod DB + 3 months of backups in 9s "fixing" a staging credential issue)
- **Never auto-bypass a hook block** — if a PreToolUse hook returns `BLOCKED:`, do NOT retry the same command. Tell the user what was blocked and what it would destroy; only the user decides whether to proceed
- Verify APIs/flags exist before using them; cite file:line for any code reference
- Run code before calling it done; iterate until verification actually passes
- Plan (use plan mode) for changes touching 3+ files or ambiguous requirements

## Self-Validation
- **Verify against ground truth** — UI: compare to design/screenshot. Logic: compare to expected output. Data: spot-check a sample
- **Iterate until passing** — don't stop at "compiles"; keep going until success criteria are met
- **Define success up front** — before non-trivial work, state what "done" looks like (test passes, output matches, lint clean)
- **Add tests for new behavior** — for non-trivial functionality: add a test that fails before and passes after, then run it
- **One run, then fix** — run build/test once per change; don't loop on flaky failures without a hypothesis

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
- Write/Edit allowlists are defined in `settings.json` `permissions.allow` — `.git/COMMIT_MESS`, `.git/COMMIT_EDITMSG`, `CLAUDE.md`, `AI.md`, `IDEA.md`, `TODO.AI.md`, `TODO.md`, `PLAN.AI.md`, `PLAN.md`, `settings.json`, `settings.local.json`, and `.env`/`app.env`/`default.env` paths are pre-approved. Destructive Bash ops are gated separately by `protect-host.sh`

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
