---
name: gitcommit conventions
description: Do not hardcode the gitcommit binary path; resolve from PATH
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
