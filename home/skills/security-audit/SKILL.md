---
name: security-audit
description: Security-focused review of code, configs, and infrastructure — threat modeling, OWASP audits, secrets scanning, dependency CVEs, auth flows, and hardening. Use before shipping a feature or on demand.
argument-hint: [path|module|feature]
---

Invoke the `security-auditor` agent on the project at `{project_dir}` (or scoped to `$ARGUMENTS` if a specific path, module, or feature was provided).

Use the Agent tool with `subagent_type: "security-auditor"` and instruct it to audit the target. Report all findings back to the user exactly as the agent returns them — do not summarise or filter.
