#!/usr/bin/env bash
# shellcheck shell=bash
# - - - - - - - - - - - - - - - - - - - - - - - - -
##@Version           :  202608311430-git
# @@Author           :  Jason Hempstead
# @@Contact          :  git-admin@casjaysdev.pro
# @@License          :  WTFPL
# @@ReadME           :  no-read-gitcommit.sh --help
# @@Copyright        :  Copyright: (c) 2026 Jason Hempstead, Casjays Developments
# @@Created          :  Sunday, August 30, 2026 20:00 EDT
# @@File             :  no-read-gitcommit.sh
# @@Description      :  PreToolUse Read+Grep+Bash hook: blocks reading the commit wrapper script (Read/Grep tools, cat/less/head/etc via Bash), a previously prose-only rule.
# @@Changelog        :  Fixed ARG_MAX crash by passing payload via tmpfile instead of an env var.
# @@TODO             :  None
# @@Other            :  Resolves the symlink target so both paths are blocked; the zone's raw-git pre-authorization never covers the commit wrapper itself.
# @@Resource         :  CLAUDE.md - Commit Workflow, home/hooks/drift-guard-read.sh
# @@Terminal App     :  no
# @@sudo/root        :  no
# @@Template         :  shell/bash
# - - - - - - - - - - - - - - - - - - - - - - - - -
# shellcheck disable=SC1001,SC1003,SC2001,SC2003,SC2016,SC2031,SC2090,SC2115,SC2120,SC2155,SC2199,SC2229,SC2317,SC2329
# - - - - - - - - - - - - - - - - - - - - - - - - -
VERSION="202608311430-git"
# - - - - - - - - - - - - - - - - - - - - - - - - -
set -euo pipefail

if ! command -v python3 >/dev/null 2>&1; then
  printf 'no-read-gitcommit.sh: required command not found: python3 (hook disabled, failing open)\n' >&2
  exit 0
fi

NO_READ_GITCOMMIT_INPUT="$(cat)"

NO_READ_GITCOMMIT_INPUT_TMPFILE="$(mktemp)"
trap 'rm -f "$NO_READ_GITCOMMIT_INPUT_TMPFILE"' EXIT
printf '%s' "$NO_READ_GITCOMMIT_INPUT" > "$NO_READ_GITCOMMIT_INPUT_TMPFILE"

python3 - "$NO_READ_GITCOMMIT_INPUT_TMPFILE" <<'PYEOF'
import json
import os
import re
import shlex
import shutil
import sys

with open(sys.argv[1], "r") as _f:
    raw = _f.read()
try:
    payload = json.loads(raw, strict=False)
except json.JSONDecodeError:
    sys.exit(0)

tool_name = payload.get("tool_name", "")

# gitcommit_conventions.md:7 forbids hardcoding the gitcommit path (e.g.
# /usr/local/bin/gitcommit) verbatim - it may live in ~/.local/bin,
# /usr/bin, or elsewhere depending on the machine, and "it's always in
# PATH" per that same rule. Resolve it from PATH instead of a fixed list.
GITCOMMIT_RESOLVED = None
_which = shutil.which("gitcommit")
if _which:
    GITCOMMIT_RESOLVED = os.path.realpath(_which)


def is_gitcommit_path(path):
    if not path or not GITCOMMIT_RESOLVED:
        return False
    resolved = os.path.realpath(path)
    return path == GITCOMMIT_RESOLVED or resolved == GITCOMMIT_RESOLVED


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

if tool_name == "Grep":
    grep_path = payload.get("tool_input", {}).get("path", "") or ""
    if is_gitcommit_path(grep_path):
        print(msg)
        sys.stderr.write(msg + "\n")
        sys.exit(2)
    sys.exit(0)

if tool_name != "Bash":
    sys.exit(0)

cmd = payload.get("tool_input", {}).get("command", "")
if not cmd or not re.search(r"gitcommit", cmd):
    sys.exit(0)

# Display/pager/editor verbs only — matches AI.md's "cat/less/head/etc."
# row (Part 6, Hook Scripts table). cp/diff read the file too but they
# are file-manipulation/comparison tools, not display tools, so they are
# out of this rule's scope per the audit's Priority 2 classification.
READ_VERBS = {"cat", "less", "more", "head", "tail", "vim", "vi", "nano",
              "view", "bat", "sed", "awk", "grep", "rg", "xxd", "od",
              "strings", "nl", "tac", "cut", "wc", "file", ".", "source"}

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
