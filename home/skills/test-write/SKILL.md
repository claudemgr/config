---
name: test-write
description: Write tests for existing code — unit tests, integration tests, table-driven tests, fuzz targets. Provide the code to test and describe what coverage is needed.
argument-hint: [file|function|module]
---

Invoke the `test-writer` agent on the target at `{project_dir}` (or scoped to `$ARGUMENTS` if a specific file, function, or module was provided).

Use the Agent tool with `subagent_type: "test-writer"` and instruct it to write tests for the target. Report all generated tests and explanations back to the user exactly as the agent returns them — do not summarise or filter.
