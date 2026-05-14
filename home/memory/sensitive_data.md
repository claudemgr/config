---
name: Sensitive data rule
description: Never expose credentials anywhere; masking format; all public destinations (git, pastes, bug reports, chat) treated identically
type: user
---

## Universal Rule

**All public destinations are equally dangerous.** Treat these identically — a credential leaked to any of them is a permanent exposure risk:

| Destination | Examples |
|-------------|---------|
| Git repos | GitHub, GitLab, Gitea (public OR private) |
| Paste services | pastebin.com, GitHub Gist, paste.rs, dpaste, ix.io, termbin |
| Bug trackers | GitHub Issues, Jira, Linear, Sentry |
| Code review | PRs, diffs, review comments |
| Chat / email | Slack, Discord, Teams, email threads |
| Screenshots / recordings | Any image or video that shows a terminal or config |

**"Private" is not a defense** — private repos get breached, private pastes get indexed, private channels get screenshotted. Treat all of them as fully public.

## What Is Sensitive

- Tokens, API keys, personal access tokens, OAuth secrets
- Passwords, passphrases, PINs
- Private keys, certificates, `.pem` / `.key` files
- Session cookies, JWTs, refresh tokens
- Internal hostnames, IP addresses, VPN endpoints
- Database credentials, connection strings with passwords
- PII: names, emails, phone numbers, addresses, SSNs, card numbers

## The Only Exception

A **personal dotfiles repo explicitly designated as private and intended to hold credentials** (env files, SSH keys, global env vars) may contain credentials. Context determines this — do not assume; if unclear, do not add and ask instead.

## Masking Format

When you must share something that contains or may contain sensitive values — logs, error output, config snippets, bug reports, paste content, screenshots — **mask values but preserve keys**:

```
# Key=value — replace value, keep key
api-token=xxxxx
password=xxxxx
STRIPE_SECRET_KEY=xxxxx

# HTTP headers — keep scheme/prefix, replace credential
Authorization: Bearer xxxxx
Proxy-Authorization: Basic xxxxx

# Connection strings — mask credential, keep host/db for debugging context
db_url=postgres://user:xxxxx@db.internal:5432/myapp

# JSON / YAML / TOML — replace value in-place, keep key
{ "api_key": "xxxxx", "endpoint": "https://api.example.com" }
```

Masking rules:
- Use `xxxxx` (five x's minimum); do not preserve the original length — length is information
- Never show partial values — `sk-abc...xyz` is still a leak
- Last-4 is acceptable only for payment card numbers where the last 4 are intentionally non-secret by PCI design
- A hash (`sha256:abc123…`) is acceptable when the hash itself is non-sensitive and needed for correlation
- Apply before sharing anywhere — paste services, issue trackers, chat, email, screenshots

## How to Handle Credentials at Runtime

- Use environment variables, mounted secrets, or a secrets manager — never hardcode
- Config files that need a credential: use `${VAR_NAME}` as a placeholder, never a real value
- Scanning generated code for accidental credential leakage is part of every review

## Pre-flight Before Sharing

Before posting to any destination above:

1. Scan for anything in the "What Is Sensitive" list
2. Mask every sensitive value using the format above
3. If you are unsure whether something is sensitive — mask it anyway
4. If the user asks you to post something containing real credentials: stop, flag it, mask first, then post only after confirmation

Paste services additionally: no history audit trail, so a leaked secret is harder to identify and rotate than in a git repo. Apply stricter scrutiny.
