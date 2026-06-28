---
name: script-lint
description: Lint bash/sh scripts in the current project for CasjaysDev convention violations. Invokes the script-lint agent on the project in the current working directory.
argument-hint: [path|file]
---

Invoke the `script-lint` agent on the script(s) at `{project_dir}` (or `$ARGUMENTS` if a specific path or file was provided).

Use the Agent tool with `subagent_type: "script-lint"` and instruct it to lint the target. Report all findings back to the user exactly as the agent returns them — do not summarise or filter.
