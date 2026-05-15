#!/usr/bin/env bash
# shellcheck shell=bash
# - - - - - - - - - - - - - - - - - - - - - - - - -
##@Version           :  YYYYMMDDHHMM-git
# @@Author           :  Jason Hempstead
# @@Contact          :  git-admin@casjaysdev.pro
# @@License          :  MIT or LICENSE.md
# @@ReadME           :  enforce-docker-rm.sh --help
# @@Copyright        :  Copyright: (c) 2026 Jason Hempstead, Casjays Developments
# @@Created          :  Thursday, May 15, 2026 00:00 EDT
# @@File             :  enforce-docker-rm.sh
# @@Description      :  PreToolUse hook: block docker run without --rm (prevents orphaned containers)
# @@Changelog        :  New File
# @@TODO             :  Better docs
# @@Other            :
# @@Resource         :
# - - - - - - - - - - - - - - - - - - - - - - - - -

set -euo pipefail

INPUT="$(cat)"

HOOK_INPUT="$INPUT" python3 - <<'PYEOF'
import json
import os
import re
import shlex
import sys

raw = os.environ.get("HOOK_INPUT", "")
try:
    payload = json.loads(raw)
except json.JSONDecodeError:
    sys.exit(0)

tool = payload.get("tool_name", "")
if tool != "Bash":
    sys.exit(0)

cmd = payload.get("tool_input", {}).get("command", "")
if not cmd:
    sys.exit(0)

# Only inspect commands that contain "docker run"
if "docker run" not in cmd and "docker  run" not in cmd:
    sys.exit(0)

# Tokenise with shlex; split on pipes/semicolons/&& first
# so we examine each sub-command independently
sub_cmds = re.split(r"[|;&]|\&\&|\|\|", cmd)

violations = []
for sub in sub_cmds:
    sub = sub.strip()
    # Does this sub-command invoke docker run?
    try:
        tokens = shlex.split(sub)
    except ValueError:
        tokens = sub.split()

    # Find "docker run" (possibly with env-var prefixes: KEY=VAL docker run)
    # Skip leading KEY=VALUE tokens
    clean = [t for t in tokens if not re.match(r'^[A-Za-z_][A-Za-z0-9_]*=', t)]

    if not clean:
        continue

    # Normalise: handle "docker  run" with extra spaces already split away
    if clean[0] != "docker":
        continue
    if len(clean) < 2 or clean[1] != "run":
        continue

    # Check for --rm in the argument list
    # Also accept --rm=true
    has_rm = any(t in ("--rm", "--rm=true") for t in clean[2:])

    # docker run --help and dry-run forms are fine
    is_help = any(t in ("--help", "-h") for t in clean[2:])

    if not has_rm and not is_help:
        # Reconstruct a short form for the message
        short = " ".join(clean[:6]) + (" ..." if len(clean) > 6 else "")
        violations.append(short)

if not violations:
    sys.exit(0)

msg = (
    "BLOCKED: docker run without --rm detected.\n\n"
    "Every build/test container must self-remove on exit to prevent orphaned containers.\n\n"
    "Violating command(s):\n"
)
for v in violations:
    msg += f"  {v}\n"

msg += (
    "\nFix: add --rm to each docker run invocation:\n"
    "  docker run --rm [OPTIONS] IMAGE [COMMAND]\n\n"
    "If this container must persist after the session (e.g. a user-requested dev environment),\n"
    "confirm with the user first and document the container name/ID."
)

print(msg)
sys.stderr.write(msg + "\n")
sys.exit(2)
PYEOF
