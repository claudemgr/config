# Claude Rules

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
- Scope includes implicit plumbing needed to make a feature work; it does not include unasked-for features
- Targeted edits only; full rewrites only when asked
- Required deps: just add them. Real choice between alternatives: ask first

## Verification & Safety
- Confirm before: `rm -rf`, force pushes, dropping tables/branches, anything irreversible
- **Never run unrequested destructive ops, even to "fix"** — troubleshooting a broken state does NOT justify deleting volumes, dropping DBs, wiping dirs, force-pushing, or terminating cloud resources. Stop and ask. (Ref: April 2026 PocketOS incident — agent wiped prod DB + 3 months of backups in 9s "fixing" a staging credential issue)
- Verify APIs/flags exist before using them; cite file:line for any code reference
- Fix what's in scope; stop only on external blockers (outages, missing creds, network failures)
- Run code before calling it done; iterate until verification actually passes
- Define "done" criteria before starting non-trivial work; add a test for new behavior
- Plan (use plan mode) for changes touching 3+ files or ambiguous requirements

## Build & Execution
- Dev images: rolling tags (`golang:alpine`, `node:alpine`, etc.) — current toolchain, not pinned
- Run built binaries in containers (prefer Incus); never execute on host
- Target `linux/amd64` + `linux/arm64` by default
- Builds are reproducible in containers; nothing depends on host-installed toolchain

## Project Defaults
- License: MIT · Deployment: single self-contained binary · First-run works with zero config
- No feature gating; all functionality available
- Telemetry opt-in only; never hardcode tracking IDs, site keys, or credentials
- Web UIs: mobile-responsive from day one
- Security in code, not user friction: parameterized queries, constant-time comparison, CSRF/XSS/SSRF/IDOR/path-traversal guards — the standard threat model
- Every repo is public: no passwords, API keys, tokens, or internal hostnames in source ever

## Output
- No preamble ("Great question!"), no reflexive agreement, no closing recap
- Show diffs, not prose retellings of changes
- No emojis unless asked (exception: commit messages follow project convention — see Commit Workflow)
- **No AI attribution** — never add `Co-Authored-By:`, AI-tool trailers, "Generated with X" footers, or any AI attribution to commits, PRs, or code comments. AI acts on behalf of the user, not as a contributor. Editing AI-config files does not count as attribution.
- Next step is clear → do it. Pause only for genuine blockers or destructive-op confirmation

## Agent Usage
- **Haiku for trivial tasks** — renames, format conversions, single-line edits, simple lookups, mechanical refactors: spawn via `Agent` with `model: "haiku"`. Reserve Sonnet for judgment, multi-file coordination, or design decisions.

## Spec Protocol
- `IDEA.md` is the project idea — THE WHAT, never THE HOW; do not derive implementation details from it
- `AI.md` is the spec — THE HOW; source of truth for design, architecture, and implementation decisions
- `TODO.AI.md` is the task list — source of truth for what's pending
- `CLAUDE.md` holds base rules and directs to the relevant section of `AI.md` for project context; search and read `AI.md` before acting on a project
- `.agent/` holds `rules.md`, `state.json`, `changelog.md`; keep `state.json` current
- Check spec alignment before acting; never build unspec'd features without updating `AI.md` first
- Log substantive changes in `.agent/changelog.md`

## Autonomy
- Action commands ("fix all issues", "run the tests", "deploy") → execute fully without step-by-step confirmation
- "Run X" pre-authorizes X and its entire workflow (subcommands, loops, retries, pipes) for this session
- File sensitivity is defined by `protect-host.sh` (system paths, raw disk ops) — `.git/COMMIT_*`, `CLAUDE.md`, lock files, and build artifacts are safe to write without asking

## Commit Workflow
`git commit` and `git push` are denied. `gitcommit` (resolved from PATH) is the only commit path — it signs, stages, commits, and pushes in one invocation. Workflow is pre-approved; commit without asking, but verify the message first.

**Only valid invocation:** `gitcommit --dir {dir} all`
- `{dir}` = absolute path to the project root
- `all` is the only command to use — semantic types (`new`, `improved`, `fixes`, etc.) and status types (`modified`, `deleted`, `renamed`) loop per-file and produce one commit per file, which is never what we want
- Never use `-m` / `--message` — they bypass the message file

**Pre-commit sequence:**
1. `git status --porcelain` + `git diff --stat` — see actual changes
2. Write `{dir}/.git/COMMIT_MESS` — every changed file listed by path, each change described, nothing missing, no leftover content from a prior commit
3. Re-read `COMMIT_MESS` to verify it matches reality
4. Run `gitcommit --dir {dir} all` — wrapper deletes `COMMIT_MESS` on success; every commit starts fresh

**Message format:** `{emoji} Title (≤64 chars) {emoji}` + blank line + body + `- path: change` bullets per file

Emoji map: ✨ feat · 🐛 fix · 📝 docs · 🎨 style · ♻️ refactor · ⚡ perf · ✅ test · 🔧 chore · 🔒 security · 🗑️ remove · 🚀 deploy · 📦 deps

**Cadence:** one logical change per commit. Unrelated subsystems → split. Mid-task inconsistent state → do NOT commit.

**Push is immediate and irreversible.** Wrong message = wrong public history. To skip push: `touch .no_push` at repo root before running (confirm with user first). If push fails (offline/no remote): run `gitcommit push` later — do NOT recreate `COMMIT_MESS`.
