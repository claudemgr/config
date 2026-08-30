#!/usr/bin/env bash
# shellcheck shell=bash
# - - - - - - - - - - - - - - - - - - - - - - - - -
##@Version           :  202608302000-git
# @@Author           :  Jason Hempstead
# @@Contact          :  git-admin@casjaysdev.pro
# @@License          :  MIT or LICENSE.md
# @@ReadME           :  no-read-gitcommit.sh --help
# @@Copyright        :  Copyright: (c) 2026 Jason Hempstead, Casjays Developments
# @@Created          :  Sunday, August 30, 2026 20:00 EDT
# @@File             :  no-read-gitcommit.sh
# @@Description      :  PreToolUse Read+Bash hook: blocks reading the gitcommit script file, mirroring
# @@Description      :  drift-guard-read.sh's pattern. CLAUDE.md's Commit Workflow says "Never read the
# @@Description      :  gitcommit script file - it is pre-approved and trusted", but nothing previously
# @@Description      :  enforced that technically - both the Read tool and a Bash cat/less/head/etc could
# @@Description      :  read it freely.
# @@Changelog        :  Initial version - audit found the "never read gitcommit" rule was prose-only
# @@TODO             :  None
# @@Other            :  Resolves the gitcommit symlink target (/usr/local/bin/gitcommit ->
# @@Other            :  /usr/local/share/CasjaysDev/scripts/bin/gitcommit) so both paths are blocked
# @@Other            :  No zone exception - the zone's raw-git pre-authorization never applies to
# @@Other            :  gitcommit itself (see enforce-gitcommit-shape.sh's header for the same reasoning)
# @@Resource         :  CLAUDE.md - Commit Workflow, home/hooks/drift-guard-read.sh
# @@Terminal App     :  no
# @@sudo/root        :  no
# @@Template         :  shell/bash
# - - - - - - - - - - - - - - - - - - - - - - - - -
# shellcheck disable=SC1001,SC1003,SC2001,SC2003,SC2016,SC2031,SC2090,SC2115,SC2120,SC2155,SC2199,SC2229,SC2317,SC2329
# - - - - - - - - - - - - - - - - - - - - - - - - -
VERSION="202608302000-git"
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
