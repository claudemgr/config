#!/usr/bin/env bash
# shellcheck shell=bash
# - - - - - - - - - - - - - - - - - - - - - - - - -
##@Version           :  202608301800-git
# @@Author           :  Jason Hempstead
# @@Contact          :  git-admin@casjaysdev.pro
# @@License          :  WTFPL
# @@ReadME           :  trailing-newline-guard.sh --help
# @@Copyright        :  Copyright: (c) 2026 Jason Hempstead, Casjays Developments
# @@Created          :  Sunday, August 30, 2026 22:00 EDT
# @@File             :  trailing-newline-guard.sh
# @@Description      :  PostToolUse Write+Edit hook: enforces the trailing-newline rule read-only, blocking with a remediation message instead of rewriting the file.
# @@Changelog        :  Initial version enforcing the previously unenforced trailing-newline rule; fixed the license header field to WTFPL.
# @@TODO             :  None
# @@Other            :  Skips secret/token files, VERSION, lockfiles, binary content, empty files, nonexistent paths; applies everywhere.
# @@Resource         :  file_ending_conventions.md, CLAUDE.md - Code & Files
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
  printf 'trailing-newline-guard.sh: required command not found: python3 (hook disabled, failing open)\n' >&2
  exit 0
fi

TRAILING_NEWLINE_GUARD_INPUT="$(cat)"

TRAILING_NEWLINE_GUARD_HOOK_INPUT="$TRAILING_NEWLINE_GUARD_INPUT" python3 - <<'PYEOF'
import json
import os
import sys

raw = os.environ.get("TRAILING_NEWLINE_GUARD_HOOK_INPUT", "")
try:
    payload = json.loads(raw, strict=False)
except json.JSONDecodeError:
    sys.exit(0)

if payload.get("tool_name", "") not in ("Write", "Edit"):
    sys.exit(0)

path = payload.get("tool_input", {}).get("file_path", "")
if not path:
    sys.exit(0)
path = os.path.expanduser(path)
if not os.path.isfile(path) or os.path.islink(path):
    sys.exit(0)

EXEMPT_BASENAMES = {"VERSION", ".password", "htpasswd", ".htpasswd"}
EXEMPT_LOCKFILES = {
    "package-lock.json", "yarn.lock", "Cargo.lock", "go.sum",
    "pnpm-lock.yaml", "composer.lock",
}
EXEMPT_EXT = {
    ".token", ".pem", ".key", ".crt", ".der", ".p12", ".pfx",
    ".png", ".jpg", ".jpeg", ".gif", ".ico", ".webp", ".bmp",
    ".zip", ".tar", ".gz", ".tgz", ".bz2", ".xz", ".7z", ".pdf",
    ".woff", ".woff2", ".ttf", ".eot", ".otf",
    ".so", ".dylib", ".dll", ".exe", ".bin", ".wasm", ".jar", ".class",
    ".mp3", ".mp4", ".mov", ".avi", ".sqlite", ".db", ".lock",
}

basename = os.path.basename(path)
_, ext = os.path.splitext(basename)
if basename in EXEMPT_BASENAMES or basename in EXEMPT_LOCKFILES or ext in EXEMPT_EXT:
    sys.exit(0)

try:
    with open(path, "rb") as f:
        data = f.read()
except OSError:
    sys.exit(0)

if not data:
    sys.exit(0)
if b"\x00" in data[:8000]:
    sys.exit(0)

if data.endswith(b"\n\n"):
    reason = "has blank line(s) at EOF — must end with exactly ONE trailing newline"
elif not data.endswith(b"\n"):
    reason = "is missing its trailing newline"
else:
    sys.exit(0)

msg = (
    f"BLOCKED: trailing-newline-guard — {path} {reason}.\n"
    "file_ending_conventions.md: every text file ends with a single trailing\n"
    "newline. Fix with a small Edit/Write to this file before continuing."
)
print(msg)
sys.stderr.write(msg + "\n")
sys.exit(2)
PYEOF
