---
name: rust-lint
description: Lint the current Rust project for CasjaysDev convention violations. Invokes the rust-lint agent on the project in the current working directory.
argument-hint: [path]
---

Invoke the `rust-lint` agent on the Rust project at `{project_dir}` (or `$ARGUMENTS` if a path was provided).

Use the Agent tool with `subagent_type: "rust-lint"` and instruct it to lint the project at that path. Report all findings back to the user exactly as the agent returns them — do not summarise or filter.
