---
name: go-lint
description: Lint the current Go project for CasjaysDev convention violations. Invokes the go-lint agent on the project in the current working directory.
argument-hint: [path]
---

Invoke the `go-lint` agent on the Go project at `{project_dir}` (or `$ARGUMENTS` if a path was provided).

Use the Agent tool with `subagent_type: "go-lint"` and instruct it to lint the project at that path. Report all findings back to the user exactly as the agent returns them — do not summarise or filter.
