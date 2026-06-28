---
name: rpm-build
description: Author an RPM spec file and run the full build workflow for a CasjaysDev package — own binaries (Go/Rust), own scripts, own services, and third-party repackaging. Generates spec file, Docker build command, signing steps, and createrepo_c invocation.
argument-hint: [package-name|spec-file]
---

Invoke the `rpm-builder` agent on the project at `{project_dir}` (or targeting `$ARGUMENTS` if a specific package name or spec file was provided).

Use the Agent tool with `subagent_type: "rpm-builder"` and instruct it to build the RPM for the target. Report all findings, generated files, and commands back to the user exactly as the agent returns them — do not summarise or filter.
