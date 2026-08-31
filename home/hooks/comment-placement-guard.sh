#!/usr/bin/env bash
# shellcheck shell=bash
# - - - - - - - - - - - - - - - - - - - - - - - - -
##@Version           :  202608302430-git
# @@Author           :  Jason Hempstead
# @@Contact          :  git-admin@casjaysdev.pro
# @@License          :  WTFPL
# @@ReadME           :  comment-placement-guard.sh --help
# @@Copyright        :  Copyright: (c) 2026 Jason Hempstead, Casjays Developments
# @@Created          :  Sunday, August 30, 2026 23:00 EDT
# @@File             :  comment-placement-guard.sh
# @@Description      :  PreToolUse Write+Edit hook: blocks comment syntax in .json files and inline trailing comments in common source files, a previously prose-only rule.
# @@Changelog        :  Extended the SHA-pin exemption to .gitea/workflows/ and .forgejo/workflows/, not just .github/workflows/.
# @@TODO             :  None
# @@Other            :  String-aware JSON check; narrow extension-list inline check; exempts `# noqa`/`# type: ignore`/`// nolint` and CI SHA-pin annotations.
# @@Resource         :  CLAUDE.md - Code & Files, comment_conventions.md
# @@Terminal App     :  no
# @@sudo/root        :  no
# @@Template         :  shell/bash
# - - - - - - - - - - - - - - - - - - - - - - - - -
# shellcheck disable=SC1001,SC1003,SC2001,SC2003,SC2016,SC2031,SC2090,SC2115,SC2120,SC2155,SC2199,SC2229,SC2317,SC2329
# - - - - - - - - - - - - - - - - - - - - - - - - -
VERSION="202608302430-git"
# - - - - - - - - - - - - - - - - - - - - - - - - -
set -euo pipefail

if ! command -v python3 >/dev/null 2>&1; then
  printf 'comment-placement-guard.sh: required command not found: python3 (hook disabled, failing open)\n' >&2
  exit 0
fi

COMMENT_PLACEMENT_GUARD_INPUT="$(cat)"

COMMENT_PLACEMENT_GUARD_HOOK_INPUT="$COMMENT_PLACEMENT_GUARD_INPUT" python3 - <<'PYEOF'
import json
import os
import re
import sys

raw = os.environ.get("COMMENT_PLACEMENT_GUARD_HOOK_INPUT", "")
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

basename = os.path.basename(file_path)
if basename == "COMMIT_MESS":
    sys.exit(0)

_, ext = os.path.splitext(basename)
findings = []


def line_of(index, text):
    return text.count("\n", 0, index) + 1


if ext == ".json":
    in_string = False
    escape = False
    i = 0
    n = len(content)
    while i < n:
        c = content[i]
        if in_string:
            if escape:
                escape = False
            elif c == "\\":
                escape = True
            elif c == '"':
                in_string = False
            i += 1
            continue
        if c == '"':
            in_string = True
            i += 1
            continue
        if c == "/" and i + 1 < n and content[i + 1] in ("/", "*"):
            snippet = content[i:i + 40].split("\n", 1)[0]
            findings.append(f"line {line_of(i, content)}: comment in JSON: {snippet[:80]}")
            i += 2
            continue
        i += 1

    if findings:
        lines = ["BLOCKED: comment syntax found in a .json file.\n"]
        for f in findings[:20]:
            lines.append(f"  - {f}")
        lines.append("")
        lines.append(
            "comment_conventions.md: JSON has no comment syntax - comments break\n"
            "parsers and validators. Use a separate doc file instead."
        )
        msg = "\n".join(lines)
        print(msg)
        sys.stderr.write(msg + "\n")
        sys.exit(2)
    sys.exit(0)

HASH_COMMENT_EXT = {".sh", ".bash", ".py", ".rb", ".yml", ".yaml", ".toml", ".ini"}
SLASH_COMMENT_EXT = {
    ".go", ".rs", ".js", ".jsx", ".ts", ".tsx",
    ".java", ".c", ".cpp", ".cc", ".h", ".hpp",
}

if ext not in HASH_COMMENT_EXT and ext not in SLASH_COMMENT_EXT:
    sys.exit(0)

INLINE_EXEMPT_RE = re.compile(r"#\s*(noqa|type:\s*ignore)\b|//\s*nolint\b", re.IGNORECASE)
# comment_conventions.md's SHA-pin exemption covers "CI workflow" annotations
# generically, not GitHub specifically — Gitea and Forgejo use the same
# `uses: owner/action@{sha}  # vX.Y.Z` Action syntax under their own
# workflow directories, so both need the same exemption GitHub gets.
WORKFLOW_DIRS = (".github/workflows/", ".gitea/workflows/", ".forgejo/workflows/")
NORMALIZED_PATH = file_path.replace(os.sep, "/")
IS_WORKFLOW = any(d in NORMALIZED_PATH for d in WORKFLOW_DIRS) and ext in (".yml", ".yaml")
SHA_PIN_RE = re.compile(r"^\s*(-\s*)?uses:\s*\S+@[0-9a-f]{40}\s*#\s*v\S+\s*$")

HASH_INLINE_RE = re.compile(r"\S.*\s#(?!!)")
SLASH_INLINE_RE = re.compile(r"\S.*\s//")

for lineno, line in enumerate(content.split("\n"), start=1):
    stripped = line.lstrip()
    if not stripped or stripped.startswith("#") or stripped.startswith("//"):
        continue
    if INLINE_EXEMPT_RE.search(line):
        continue
    if IS_WORKFLOW and SHA_PIN_RE.match(line):
        continue

    if ext in HASH_COMMENT_EXT and HASH_INLINE_RE.search(line):
        findings.append(f"line {lineno}: inline comment (must be on its own line above): {line.strip()[:80]}")
        continue
    if ext in SLASH_COMMENT_EXT and SLASH_INLINE_RE.search(line):
        findings.append(f"line {lineno}: inline comment (must be on its own line above): {line.strip()[:80]}")

if not findings:
    sys.exit(0)

lines = ["BLOCKED: inline trailing comment detected.\n"]
for f in findings[:20]:
    lines.append(f"  - {f}")
lines.append("")
lines.append(
    "comment_conventions.md: comments always go ABOVE the code they describe,\n"
    "never appended to the end of a code line. Move the comment to its own\n"
    "line above, or use one of the documented inline exceptions (# noqa,\n"
    "# type: ignore, // nolint, or a CI workflow SHA-pin annotation)."
)
msg = "\n".join(lines)
print(msg)
sys.stderr.write(msg + "\n")
sys.exit(2)
PYEOF
