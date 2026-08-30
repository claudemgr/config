#!/usr/bin/env bash
# shellcheck shell=bash
# - - - - - - - - - - - - - - - - - - - - - - - - -
##@Version           :  202608301800-git
# @@Author           :  Jason Hempstead
# @@Contact          :  git-admin@casjaysdev.pro
# @@License          :  WTFPL
# @@ReadME           :  no-read-gitcommit.sh --help
# @@Copyright        :  Copyright: (c) 2026 Jason Hempstead, Casjays Developments
# @@Created          :  Sunday, August 30, 2026 20:00 EDT
# @@File             :  no-read-gitcommit.sh
# @@Description      :  PreToolUse Read+Bash hook: blocks reading the commit wrapper's script file (Read tool and cat/less/head/etc via Bash), a previously prose-only rule.
# @@Changelog        :  Initial version enforcing the previously prose-only never-read-gitcommit rule; fixed the license header field to WTFPL.
# @@TODO             :  None
# @@Other            :  Resolves the symlink target so both paths are blocked; the zone's raw-git pre-authorization never covers the commit wrapper itself.
# @@Resource         :  CLAUDE.md - Commit Workflow, home/hooks/drift-guard-read.sh
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
  printf 'no-read-gitcommit.sh: required command not found: python3 (hook disabled, failing open)\n' >&2
  exit 0
fi

NO_READ_GITCOMMIT_INPUT="$(cat)"

NO_READ_GITCOMMIT_HOOK_INPUT="$NO_READ_GITCOMMIT_INPUT" python3 - <<'PYEOF'
import json
import os
import re
import shlex
import sys

raw = os.environ.get("NO_READ_GITCOMMIT_HOOK_INPUT", "")
try:
    payload = json.loads(raw, strict=False)
except json.JSONDecodeError:
    sys.exit(0)

tool_name = payload.get("tool_name", "")

GITCOMMIT_PATHS = {
    "/usr/local/bin/gitcommit",
    "/usr/local/share/CasjaysDev/scripts/bin/gitcommit",
}


def is_gitcommit_path(path):
    if not path:
        return False
    resolved = os.path.realpath(path)
    return path in GITCOMMIT_PATHS or resolved in GITCOMMIT_PATHS or os.path.basename(path) == "gitcommit" and resolved in GITCOMMIT_PATHS


msg = (
    "BLOCKED: reading the gitcommit script file is forbidden.\n\n"
    "CLAUDE.md's Commit Workflow: \"Never read the gitcommit script file -\n"
    "it is pre-approved and trusted.\" It is invoked, never inspected."
)

if tool_name == "Read":
    file_path = payload.get("tool_input", {}).get("file_path", "") or ""
    if is_gitcommit_path(file_path):
        print(msg)
        sys.stderr.write(msg + "\n")
        sys.exit(2)
    sys.exit(0)

if tool_name != "Bash":
    sys.exit(0)

cmd = payload.get("tool_input", {}).get("command", "")
if not cmd or not re.search(r"gitcommit", cmd):
    sys.exit(0)

READ_VERBS = {"cat", "less", "more", "head", "tail", "vim", "vi", "nano",
              "view", "bat", "sed", "awk", "grep", "xxd", "od", "strings",
              "cp", "diff"}

for sub_cmd in re.split(r"[\n;]|&&|\|\||[|&]", cmd):
    sub_cmd = sub_cmd.strip()
    if not sub_cmd:
        continue
    try:
        tokens = shlex.split(sub_cmd)
    except ValueError:
        tokens = sub_cmd.split()

    clean = []
    skipping_prefix = True
    for tok in tokens:
        if skipping_prefix:
            if tok in ("command", "env", "exec", "nohup", "time", "sudo", "doas"):
                continue
            if re.match(r"^[A-Za-z_][A-Za-z0-9_]*=", tok):
                continue
            if tok.startswith("-"):
                continue
            skipping_prefix = False
        clean.append(tok.lstrip("\\"))

    if not clean:
        continue

    head = clean[0]
    if head not in READ_VERBS:
        continue

    for arg in clean[1:]:
        if arg.startswith("-"):
            continue
        if is_gitcommit_path(arg):
            print(msg)
            sys.stderr.write(msg + "\n")
            sys.exit(2)

sys.exit(0)
PYEOF
