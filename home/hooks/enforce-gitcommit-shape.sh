#!/usr/bin/env bash
# shellcheck shell=bash
# - - - - - - - - - - - - - - - - - - - - - - - - -
##@Version           :  202608301800-git
# @@Author           :  Jason Hempstead
# @@Contact          :  git-admin@casjaysdev.pro
# @@License          :  WTFPL
# @@ReadME           :  enforce-gitcommit-shape.sh --help
# @@Copyright        :  Copyright: (c) 2026 Jason Hempstead, Casjays Developments
# @@Created          :  Sunday, August 30, 2026 19:00 EDT
# @@File             :  enforce-gitcommit-shape.sh
# @@Description      :  PreToolUse Bash hook: blocks any commit-wrapper invocation not exactly `--dir <path> all` or the documented push-retry form (CLAUDE.md's Commit Workflow).
# @@Changelog        :  Initial version validating gitcommit's own invocation shape; fixed the license header field to WTFPL.
# @@TODO             :  None
# @@Other              :  Does not apply to raw git commit/push (governed by zone-git-commit-push.sh instead); the commit wrapper has no zone exception anywhere.
# @@Resource         :  CLAUDE.md - Commit Workflow
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
  printf 'enforce-gitcommit-shape.sh: required command not found: python3 (hook disabled, failing open)\n' >&2
  exit 0
fi

ENFORCE_GITCOMMIT_SHAPE_INPUT="$(cat)"

ENFORCE_GITCOMMIT_SHAPE_HOOK_INPUT="$ENFORCE_GITCOMMIT_SHAPE_INPUT" python3 - <<'PYEOF'
import json
import os
import re
import shlex
import sys

raw = os.environ.get("ENFORCE_GITCOMMIT_SHAPE_HOOK_INPUT", "")
try:
    payload = json.loads(raw, strict=False)
except json.JSONDecodeError:
    sys.exit(0)

if payload.get("tool_name", "") != "Bash":
    sys.exit(0)

cmd = payload.get("tool_input", {}).get("command", "")
if not cmd:
    sys.exit(0)

if not re.search(r"\bgitcommit\b", cmd):
    sys.exit(0)

violations = []

for sub_cmd in re.split(r"[\n;]|&&|\|\||[|&]", cmd):
    sub_cmd = sub_cmd.strip()
    if not sub_cmd:
        continue
    try:
        tokens = shlex.split(sub_cmd)
    except ValueError:
        tokens = sub_cmd.split()

    # Strip wrapper/alias-bypass prefixes and env assignments (any case):
    # \gitcommit, command gitcommit, env [KEY=VAL...] gitcommit, KEY=VAL gitcommit
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

    if not clean or clean[0] != "gitcommit":
        continue

    args = clean[1:]

    # Documented push-retry form: `gitcommit push` (CLAUDE.md Commit Workflow,
    # "If push fails offline: run `gitcommit push` later").
    if args == ["push"]:
        continue

    # Only valid invocation: gitcommit --dir <path> all
    if (
        len(args) == 3
        and args[0] == "--dir"
        and args[2] == "all"
        and args[1]
        and not args[1].startswith("-")
    ):
        continue

    violations.append(sub_cmd)

if not violations:
    sys.exit(0)

msg = (
    "BLOCKED: gitcommit invoked with a disallowed argument shape.\n\n"
    "The only valid invocations (CLAUDE.md's Commit Workflow) are:\n"
    "  gitcommit --dir {project_dir} all\n"
    "  gitcommit push   (push-retry form, after an offline push failure)\n\n"
    "Never use -m/--message or any other flag - gitcommit reads the commit\n"
    "message from .git/COMMIT_MESS, which must be written and re-read first.\n\n"
    "Violating command(s):\n"
)
for sub in violations:
    msg += f"  {sub}\n"

print(msg)
sys.stderr.write(msg + "\n")
sys.exit(2)
PYEOF
