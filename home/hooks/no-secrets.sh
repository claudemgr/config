#!/usr/bin/env bash
# shellcheck shell=bash
# - - - - - - - - - - - - - - - - - - - - - - - - -
##@Version           :  YYYYMMDDHHMM-git
# @@Author           :  Jason Hempstead
# @@Contact          :  git-admin@casjaysdev.pro
# @@License          :  MIT or LICENSE.md
# @@ReadME           :  no-secrets.sh --help
# @@Copyright        :  Copyright: (c) 2026 Jason Hempstead, Casjays Developments
# @@Created          :  Thursday, May 15, 2026 00:00 EDT
# @@File             :  no-secrets.sh
# @@Description      :  Claude Code PreToolUse hook — scan Write/Edit content for high-confidence secret patterns and block if found
# @@Changelog        :  Initial version
# @@TODO             :  None
# @@Other            :  Applies to Write (new_content) and Edit (new_string) tool calls.
# @@Other            :  Template/example env files (.env.example, .env.sample, etc.) are exempted.
# @@Other            :  Placeholder-surrounded matches (changeme, your_key_here, <TOKEN>, {SECRET}, etc.) are skipped.
# @@Resource         :  ~/.claude/memory/sensitive_data.md
# @@Terminal App     :  no
# @@sudo/root        :  no
# @@Template         :  shell/bash
# - - - - - - - - - - - - - - - - - - - - - - - - -
# shellcheck disable=SC1001,SC1003,SC2001,SC2003,SC2016,SC2031,SC2090,SC2115,SC2120,SC2155,SC2199,SC2229,SC2317,SC2329
# - - - - - - - - - - - - - - - - - - - - - - - - -
VERSION="YYYYMMDDHHMM-git"
# - - - - - - - - - - - - - - - - - - - - - - - - -
set -uo pipefail
# - - - - - - - - - - - - - - - - - - - - - - - - -

INPUT="$(cat)"
[ -z "$INPUT" ] && exit 0

HOOK_INPUT="$INPUT" python3 - <<'PYEOF'
import json
import os
import re
import sys

d = json.loads(os.environ.get("HOOK_INPUT", "{}"))

tool_name  = d.get("tool_name", "")
tool_input = d.get("tool_input", {})

filepath = tool_input.get("file_path", "") or ""
basename = os.path.basename(filepath)

# Exempted template/example env files — these are expected to contain placeholder values.
ALLOWED_TEMPLATES = {
    ".env.example",
    ".env.sample",
    "app.env.example",
    "app.env.sample",
    "default.env.example",
    "default.env.sample",
}
if basename in ALLOWED_TEMPLATES:
    sys.exit(0)

# Select content to scan based on tool.
if tool_name == "Write":
    content = tool_input.get("new_content", "") or ""
elif tool_name == "Edit":
    content = tool_input.get("new_string", "") or ""
else:
    sys.exit(0)

if not content:
    sys.exit(0)

# High-confidence secret patterns.
PATTERNS = [
    ("AWS Access Key ID",        r"AKIA[0-9A-Z]{16}"),
    ("GitHub Token",             r"gh[pso]_[A-Za-z0-9]{36,}"),
    ("GitHub PAT (new format)",  r"github_pat_[A-Za-z0-9_]{82,}"),
    ("Slack Token",              r"xox[baprs]-[0-9A-Za-z\-]{10,}"),
    ("Stripe Live Secret Key",   r"sk_live_[A-Za-z0-9]{24,}"),
    ("Google API Key",           r"AIza[0-9A-Za-z\-_]{35}"),
    ("SendGrid API Key",         r"SG\.[A-Za-z0-9._\-]{22}\.[A-Za-z0-9._\-]{43}"),
    ("PEM Private Key",          r"-----BEGIN (?:RSA |EC |DSA |OPENSSH )?PRIVATE KEY-----"),
    ("Anthropic API Key",        r"sk-ant-[A-Za-z0-9\-_]{40,}"),
    ("OpenAI API Key",           r"sk-proj-[A-Za-z0-9]{40,}"),
    ("npm Access Token",         r"npm_[A-Za-z0-9]{36,}"),
    ("JWT (3-part)",             r"eyJ[A-Za-z0-9_\-]{10,}\.eyJ[A-Za-z0-9_\-]{10,}\.[A-Za-z0-9_\-]{10,}"),
    ("HuggingFace Token",        r"hf_[A-Za-z0-9]{34,}"),
    ("GitLab Token",             r"glpat-[A-Za-z0-9\-_]{20,}"),
    ("PyPI API Token",           r"pypi-[A-Za-z0-9_\-]{40,}"),
]

# Placeholder indicators — if any appear in a 60-char window around the match,
# treat the match as an example/template value and skip it.
PLACEHOLDER_RE = re.compile(
    r"changeme"
    r"|placeholder"
    r"|your[_-]?(?:api[_-]?)?(?:key|token|secret|password)[_-]?here"
    r"|example"
    r"|dummy"
    r"|fake"
    r"|test[_-]?(?:key|token|secret)"
    r"|xxx+"
    r"|<[A-Za-z_][^>]*>"
    r"|\{[A-Za-z_][^}]*\}"
    r"|TO_BE"
    r"|FILL_IN"
    r"|REPLACE_ME"
    r"|INSERT_HERE"
    r"|YOUR_",
    re.IGNORECASE,
)

def redact(value):
    """Return first 4 chars + asterisks + last 2 chars."""
    if len(value) <= 6:
        return "*" * len(value)
    return value[:4] + "*" * (len(value) - 6) + value[-2:]

findings = []

for label, pattern in PATTERNS:
    for m in re.finditer(pattern, content):
        start = m.start()
        end   = m.end()
        # 60-char context window around the match.
        ctx_start = max(0, start - 60)
        ctx_end   = min(len(content), end + 60)
        context   = content[ctx_start:ctx_start] + content[ctx_start:ctx_end]
        # Exclude the matched value itself from the placeholder check so the
        # placeholder regex only fires on surrounding text.
        surrounding = content[ctx_start:start] + content[end:ctx_end]
        if PLACEHOLDER_RE.search(surrounding):
            continue
        findings.append((label, redact(m.group())))

if not findings:
    sys.exit(0)

lines = ["BLOCKED: potential secret(s) detected in content being written to disk.\n"]
for label, redacted in findings:
    lines.append(f"  - {label}: {redacted}")
lines.append("")
lines.append(
    "Never write real credentials to source files. "
    "Use environment variables, mounted secrets, or a secrets manager. "
    "See ~/.claude/memory/sensitive_data.md"
)
msg = "\n".join(lines)

# stdout → Claude Code (block reason returned to Claude as context)
print(msg)
# stderr → user terminal
print(msg, file=sys.stderr)

sys.exit(2)
PYEOF
