---
name: gitcommit path resolution
description: Do not hardcode the gitcommit binary path; resolve from PATH
type: feedback
---

Never hardcode the path to `gitcommit` (e.g., `/usr/local/bin/gitcommit`).

**Why:** The binary may live in `~/.local/bin`, `/usr/bin`, or elsewhere depending on the machine. It's always in PATH, so just reference it as `gitcommit`.

**How to apply:** In CLAUDE.md, documentation, or any instruction that references the gitcommit wrapper, write `gitcommit` without a path prefix.
