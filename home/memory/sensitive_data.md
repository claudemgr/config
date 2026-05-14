---
name: Sensitive data rule
description: Never add credentials or secrets to any git repo; all repos treated as public by default
type: user
---

**Never add tokens, API keys, passwords, private keys, internal hostnames, or any credentials to a git repo** unless the user explicitly instructs it or has already committed them manually.

**Why:** All git repos are treated as public by default — even private ones. A leaked credential in git history is a permanent exposure risk.

**The only exception:** a personal dotfiles repo explicitly designated as private and intended to hold credentials (env files, SSH keys, global env vars, etc.). Context determines this — do not assume; if unclear, do not add and ask instead.

**How to apply:**
- When credentials are needed at runtime: use environment variables, mounted secrets, or a secrets manager — never hardcode
- If a config file needs a credential placeholder, use `${VAR_NAME}` or a clear placeholder, never a real value
- If a user asks you to add something that looks like a real credential, stop and confirm intent before proceeding
- Scanning generated code for accidental credential leakage is part of every review
