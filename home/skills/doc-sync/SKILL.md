---
name: doc-sync
description: Sync the triple (help, man page, completions) after a bash script changes. Also syncs README.md when feature or CLI changes warrant it. Use after any script modification.
argument-hint: [script-file]
---

Invoke the `doc-sync` agent on the script at `{project_dir}` (or `$ARGUMENTS` if a specific script file was provided).

Use the Agent tool with `subagent_type: "doc-sync"` and instruct it to sync the triple for the target. Report all findings and changes back to the user exactly as the agent returns them — do not summarise or filter.
