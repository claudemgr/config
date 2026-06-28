---
name: audit
description: Comprehensive project health audit — security, code quality, logic correctness, documentation completeness, spec compliance, and code flow trace. Fixes issues directly. Tracks >5 issues in AUDIT.AI.md.
argument-hint: [path|focus]
---

Invoke the `audit` agent on the project at `{project_dir}` (or scoped to `$ARGUMENTS` if a specific path or focus area was provided).

Use the Agent tool with `subagent_type: "audit"` and instruct it to audit the target. Report all findings and actions back to the user exactly as the agent returns them — do not summarise or filter.
