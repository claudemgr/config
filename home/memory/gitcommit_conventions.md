---
name: gitcommit conventions
description: gitcommit invocation rules, COMMIT_MESS message format, emoji map, cadence, and push behavior
type: user
---

Never hardcode the path to `gitcommit` (e.g., `/usr/local/bin/gitcommit`).

**Why:** The binary may live in `~/.local/bin`, `/usr/bin`, or elsewhere depending on the machine. It's always in PATH, so just reference it as `gitcommit`.

**How to apply:** In `{project_dir}/CLAUDE.md`, documentation, or any instruction that references the gitcommit wrapper, write `gitcommit` without a path prefix.

---

**`gitcommit` creates the remote repo automatically.** If the GitHub remote does not exist, `gitcommit` creates it and sets the upstream — no manual `gh repo create` or `git remote set-url` step is needed before or after.

---

**Never read the `gitcommit` script itself.** It is a pre-approved, trusted command — invoke it as documented; never inspect the script file before use. Reading it is a speculative read violation. The invocation contract is fully specified in the Commit Workflow section of `~/.claude/CLAUDE.md`; the script internals are irrelevant.

---

**Never use bare `@` in a commit message body.** Any `@username` in a commit message body creates a GitHub contributor notification and links the handle — even if the intent is just to reference a name. Only use `@username` when intentionally crediting a real contributor. Otherwise write the name without `@`, or wrap it in backticks to prevent GitHub from parsing it as a mention.

---

## Message Format

`{emoji} Title (≤64 chars) {emoji}` + blank line + body + `- path: change` bullets per file.

Emoji map: ✨ feat · 🐛 fix · 📝 docs · 🎨 style · ♻️ refactor · ⚡ perf · ✅ test · 🔧 chore · 🔒 security · 🗑️ remove · 🚀 deploy · 📦 deps

Write `{dir}/.git/COMMIT_MESS` from `git status --porcelain` + `git diff --stat` output — every changed file described; never write from memory. Re-read `COMMIT_MESS` and compare against the diff before committing — rewrite if anything is missing or wrong.

**Never invent a third-party role label** (`operator decision`, `owner decision`, `admin approved`, etc.) to describe who made a change. Claude Code runs as the user's own agent, not a separate operator/service — there is no third party. State the fact plainly instead: "removed at the user's request," "user-deleted, not a regression," or just describe the change with no attribution clause at all when the reason is self-evident from context.

## Cadence

One logical change per commit. Unrelated subsystems → split. Mid-task inconsistent state → do NOT commit.

**Grouping decision order — evaluate top to bottom; the first rule that matches decides, the rest never get consulted:**

1. **User single-commit override.** If the user's request states or implies a single commit — "one commit", "commit it all together", "single commit for this", or equivalent — every change made to satisfy that request goes into exactly one commit, full stop. This overrides every rule below, including the findings-based one-per-finding default and the coupled/independent split test. It never overrides the test gate, the lint gate, or "never commit a broken/inconsistent state" — those still apply before the single commit is made.
2. **Ad hoc "fix X, and fix anything else you find" requests** (not a numbered findings list, not an audit/review output): fix everything found for that request, then make **one commit** covering the primary fix plus whatever related issues were fixed alongside it. This is not a findings-based fix-list (rule 4) even though multiple issues are involved — it is one user request with one scope.
3. **Bug fixes spanning multiple files/dirs — group by actual coupling, not by request wording or session:**
   - **Independent** (fixing bug A in `file1` does not require touching, does not depend on, and is not blocked by bug B in `dir1`) → **separate commits**, one per independent unit.
   - **Coupled** (bug B blocks bug A from being fixable, fixing A requires changes in `dir1` too, or the bugs share a root cause) → **one commit** covering every file the coupled fix touches, described as one bug-fix group.
   - Judge coupling from actual code/dependency relationships (call graph, shared state, blocking order) — never from "found in the same session" or "same file extension/directory."
4. **Findings-based work** (audits, code reviews, punch lists, numbered user fix-lists) is never "one logical change" by default. Each finding is independently fixable and independently verifiable — batching N findings into one commit because they share a file, subsystem, or session hides which findings actually landed and makes a bad fix silently swallow a good one. Default to **one commit per finding**; only combine findings when they are genuinely inseparable (the same line/block, or fixing one is impossible without the other) — this is the same coupling test as rule 3, applied at finding granularity.
5. **Feature work** — one commit for the whole feature: implement it completely, fix every bug that is part of, blocks, or directly affects that feature, then make one commit. Do not split a single feature into per-part, per-subtask, or per-file commits; the feature is the logical unit, not its internals. Bugs found incidentally that are unrelated to the feature do not go in the feature commit — see below.

**Before writing COMMIT_MESS for findings-based work:** re-list every finding by its original ID/number, then for each one grep/diff-check that its specific fix is actually present in the working tree — not just described in a prior message or agent report. A finding with no matching diff hunk is not fixed; do not include it in COMMIT_MESS as done, and do not commit until it's resolved or explicitly deferred (say so to the user, don't silently drop it).

**Unrelated bugs found while building a feature:** do not fix them inline and do not fold them into the feature commit. Log them to `TODO.AI.md` for a later, separate fix.

**Exception — app-breaking bugs found mid-feature:** if the bug breaks the build, crashes the app, or blocks the feature/app from functioning, fix it immediately, in place, before continuing. Committing a broken project is itself a bug — it violates "no partially implemented code."

## Who Commits

**Only the main session ever runs `gitcommit` or raw `git commit`/`git push`.** Agents and subagents — of any type, including forked agents — never commit and never push, under any circumstance, even inside the Local System Management Zone's raw-git exception. An agent's job ends at editing files and reporting back; the main session is the only place that reviews the full diff, writes `COMMIT_MESS`, and invokes the commit. This is a hard rule, mechanically enforced by `no-subagent-commit.sh` (blocks the attempt) — it is not a preference an agent can reason its way around.

## Push Behavior

Push is immediate and irreversible. To skip: `touch .no_push` (confirm with user first). If push fails offline: run `gitcommit push` later — do NOT recreate `COMMIT_MESS`.
