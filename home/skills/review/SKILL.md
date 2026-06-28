---
name: review
description: Review code changes for correctness, security, reliability, and style. Reviews the current diff (staged + unstaged) or a specific file/function. Use before committing or merging.
argument-hint: [file|function|PR]
---

Invoke the `code-reviewer` agent on the current working tree at `{project_dir}` (or scoped to `$ARGUMENTS` if a specific file, function, or PR was provided).

Use the Agent tool with `subagent_type: "code-reviewer"` and instruct it to review the target. Report all findings back to the user exactly as the agent returns them — do not summarise or filter.
