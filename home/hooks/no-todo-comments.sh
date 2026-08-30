#!/usr/bin/env bash
# shellcheck shell=bash
# - - - - - - - - - - - - - - - - - - - - - - - - -
##@Version           :  202608301800-git
# @@Author           :  Jason Hempstead
# @@Contact          :  git-admin@casjaysdev.pro
# @@License          :  WTFPL
# @@ReadME           :  no-todo-comments.sh --help
# @@Copyright        :  Copyright: (c) 2026 Jason Hempstead, Casjays Developments
# @@Created          :  Sunday, August 30, 2026 21:00 EDT
# @@File             :  no-todo-comments.sh
# @@Description        :  PreToolUse Write+Edit hook: blocks TODO/FIXME/HACK markers and a narrow commented-out-code heuristic, enforcing previously prose-only CLAUDE.md rules.
# @@Changelog        :  Initial version enforcing TODO/commented-code rules; removed the invented XXX marker not in the source rule.
# @@TODO             :  None
# @@Other            :  Never matches `# @@TODO : None` or mid-sentence mentions; TODO.AI.md/TODO.md/PLAN.AI.md/PLAN.md are exempt; commented-code detection is conservative.
# @@Resource         :  CLAUDE.md - Code & Files
# @@Terminal App     :  no
# @@sudo/root        :  no
# @@Template         :  shell/bash
# - - - - - - - - - - - - - - - - - - - - - - - - -
# shellcheck disable=SC1001,SC1003,SC2001,SC2003,SC2016,SC2031,SC2090,SC2115,SC2120,SC2155,SC2199,SC2229,SC2317,SC2329
# - - - - - - - - - - - - - - - - - - - - - - - - -
VERSION="202608301800-git"
# - - - - - - - - - - - - - - - - - - - - - - - - -
set -euo pipefail

if ! command -v python3 >/dev/null 2>&1; then
  printf 'no-todo-comments.sh: required command not found: python3 (hook disabled, failing open)\n' >&2
  exit 0
fi

NO_TODO_COMMENTS_INPUT="$(cat)"

NO_TODO_COMMENTS_HOOK_INPUT="$NO_TODO_COMMENTS_INPUT" python3 - <<'PYEOF'
import json
import os
import re
import sys

raw = os.environ.get("NO_TODO_COMMENTS_HOOK_INPUT", "")
try:
    payload = json.loads(raw, strict=False)
except json.JSONDecodeError:
    sys.exit(0)

tool_name = payload.get("tool_name", "")
if tool_name not in ("Write", "Edit"):
    sys.exit(0)

tool_input = payload.get("tool_input", {})
file_path = tool_input.get("file_path", "") or ""
content = tool_input.get("content", "") if tool_name == "Write" else tool_input.get("new_string", "")
if not content:
    sys.exit(0)

EXEMPT_BASENAMES = {"TODO.AI.md", "TODO.md", "PLAN.AI.md", "PLAN.md", "COMMIT_MESS"}
if os.path.basename(file_path) in EXEMPT_BASENAMES:
    sys.exit(0)

COMMENT_PREFIX = r"^\s*(?:#|//|/\*|\*|--|;|<!--)\s*"

MARKER_RE = re.compile(
    COMMENT_PREFIX + r"(TODO|FIXME|HACK)\b",
)

CODE_KEYWORDS = (
    r"(?:import|from|def|class|return|elif|else:|for|while|try:|except"
    r"|print\(|console\.log\(|function|var|let|const|public|private"
    r"|static|require\(|module\.exports|self\.\w+\s*=)"
)
CODE_SHAPE_RE = re.compile(
    COMMENT_PREFIX + r"(?:" + CODE_KEYWORDS + r"\b"
    r"|[A-Za-z_][A-Za-z0-9_.]*\s*=\s*[^=].*;?\s*$"
    r"|[A-Za-z_][A-Za-z0-9_.]*\([^)]*\)\s*[;{]?\s*$"
    r")"
)

findings = []
for lineno, line in enumerate(content.split("\n"), start=1):
    m = MARKER_RE.match(line)
    if m:
        findings.append(f"line {lineno}: {m.group(1)} marker: {line.strip()[:80]}")
        continue
    if CODE_SHAPE_RE.match(line):
        findings.append(f"line {lineno}: looks like commented-out code: {line.strip()[:80]}")

if not findings:
    sys.exit(0)

lines = ["BLOCKED: TODO/FIXME/HACK marker or commented-out code detected.\n"]
for f in findings[:20]:
    lines.append(f"  - {f}")
lines.append("")
lines.append(
    "CLAUDE.md: \"No TODO/FIXME/HACK in committed code\" and \"No commented-out\n"
    "code\". Finish the work now, or track it in TODO.AI.md instead."
)
msg = "\n".join(lines)
print(msg)
sys.stderr.write(msg + "\n")
sys.exit(2)
PYEOF
