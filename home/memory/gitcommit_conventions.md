---
name: gitcommit conventions
description: Do not hardcode the gitcommit binary path; resolve from PATH
type: user
---

Never hardcode the path to `gitcommit` (e.g., `/usr/local/bin/gitcommit`).

**Why:** The binary may live in `~/.local/bin`, `/usr/bin`, or elsewhere depending on the machine. It's always in PATH, so just reference it as `gitcommit`.

**How to apply:** In `{project_dir}/CLAUDE.md`, documentation, or any instruction that references the gitcommit wrapper, write `gitcommit` without a path prefix.

---

**Never read the `gitcommit` script itself.** It is a pre-approved, trusted command — invoke it as documented; never inspect the script file before use. Reading it is a speculative read violation. The invocation contract is fully specified in the Commit Workflow section of `~/.claude/CLAUDE.md`; the script internals are irrelevant.
