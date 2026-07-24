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

## Cadence

One logical change per commit. Unrelated subsystems → split. Mid-task inconsistent state → do NOT commit.

**Findings-based work (audits, code reviews, punch lists, numbered user fix-lists) is never "one logical change" by default.** Each finding is independently fixable and independently verifiable — batching N findings into one commit because they share a file, subsystem, or session hides which findings actually landed and makes a bad fix silently swallow a good one. Default to **one commit per finding**; only combine findings when they are genuinely inseparable (the same line/block, or fixing one is impossible without the other).

**Before writing COMMIT_MESS for findings-based work:** re-list every finding by its original ID/number, then for each one grep/diff-check that its specific fix is actually present in the working tree — not just described in a prior message or agent report. A finding with no matching diff hunk is not fixed; do not include it in COMMIT_MESS as done, and do not commit until it's resolved or explicitly deferred (say so to the user, don't silently drop it).

## Push Behavior

Push is immediate and irreversible. To skip: `touch .no_push` (confirm with user first). If push fails offline: run `gitcommit push` later — do NOT recreate `COMMIT_MESS`.
