#!/usr/bin/env bash
# shellcheck shell=bash
# - - - - - - - - - - - - - - - - - - - - - - - - -
##@Version           :  202608302100-git
# @@Author           :  Jason Hempstead
# @@Contact          :  git-admin@casjaysdev.pro
# @@License          :  MIT or LICENSE.md
# @@ReadME           :  no-todo-comments.sh --help
# @@Copyright        :  Copyright: (c) 2026 Jason Hempstead, Casjays Developments
# @@Created          :  Sunday, August 30, 2026 21:00 EDT
# @@File             :  no-todo-comments.sh
# @@Description      :  PreToolUse Write+Edit hook: blocks TODO/FIXME/HACK/XXX markers written at the
# @@Description      :  start of a comment, and a narrow set of high-confidence commented-out-code
# @@Description      :  signatures, enforcing CLAUDE.md's "No TODO/FIXME/HACK in committed code" and
# @@Description      :  "No commented-out code" rules, previously prose-only with no technical gate.
# @@Changelog        :  Initial version - audit found the TODO/commented-code rules were unenforced
# @@TODO             :  None
# @@Other            :  Marker detection requires the word immediately after the comment prefix (e.g.
# @@Other            :  `# TODO: ...`) so it never matches the house header field `# @@TODO : None`
# @@Other            :  (starts with @@, not the bare word) or prose that merely mentions TODO/FIXME/HACK
# @@Other            :  mid-sentence, or filename mentions like `TODO.AI.md`.
# @@Other            :  TODO.AI.md, TODO.md, PLAN.AI.md, PLAN.md are exempt entirely - tracking TODO
# @@Other            :  items is their documented purpose (project_conventions.md).
# @@Other            :  Commented-out-code detection is a narrow, high-confidence heuristic (whole-line
# @@Other            :  match on common statement keywords or an assignment/call shape immediately after
# @@Other            :  the comment prefix) - deliberately conservative to avoid false positives on
# @@Other            :  ordinary descriptive comments.
# @@Resource         :  CLAUDE.md - Code & Files
# @@Terminal App     :  no
# @@sudo/root        :  no
# @@Template         :  shell/bash
# - - - - - - - - - - - - - - - - - - - - - - - - -
# shellcheck disable=SC1001,SC1003,SC2001,SC2003,SC2016,SC2031,SC2090,SC2115,SC2120,SC2155,SC2199,SC2229,SC2317,SC2329
# - - - - - - - - - - - - - - - - - - - - - - - - -
VERSION="202608302100-git"
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
    COMMENT_PREFIX + r"(TODO|FIXME|HACK|XXX)\b",
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
