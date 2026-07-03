#!/usr/bin/env bash
# shellcheck shell=bash
# - - - - - - - - - - - - - - - - - - - - - - - - -
##@Version           :  202607031823-git
# @@Author           :  Jason Hempstead
# @@Contact          :  git-admin@casjaysdev.pro
# @@License          :  MIT or LICENSE.md
# @@ReadME           :  enforce-docker-rm.sh --help
# @@Copyright        :  Copyright: (c) 2026 Jason Hempstead, Casjays Developments
# @@Created          :  Thursday, May 15, 2026 00:00 EDT
# @@File             :  enforce-docker-rm.sh
# @@Description      :  PreToolUse hook: block docker run without --rm/--name and incus launch/init without an instance name (prevents orphaned/untargetable containers)
# @@Changelog        :  Require explicit instance name on incus/lxc launch and init (project-scoped naming, same policy as docker --name)
# @@TODO             :  Better docs
# @@Other            :
# @@Resource         :
# - - - - - - - - - - - - - - - - - - - - - - - - -
# shellcheck disable=SC1001,SC1003,SC2001,SC2003,SC2016,SC2031,SC2090,SC2115,SC2120,SC2155,SC2199,SC2229,SC2317,SC2329
# - - - - - - - - - - - - - - - - - - - - - - - - -
VERSION="202607031823-git"
# - - - - - - - - - - - - - - - - - - - - - - - - -
set -euo pipefail

# __require_cmd <name> - bail with a clear error if a required tool is missing.
# A broken hook exits 0 (no-op) so we never silently block every Bash call.
__require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    printf 'enforce-docker-rm.sh: required command not found: %s\n' "$1" >&2
    exit 0
  fi
}

__require_cmd python3

# $(cat) is required here — hook stdin is a socket; $(</dev/stdin) re-opens it and fails with ENXIO
ENFORCE_DOCKER_RM_INPUT="$(cat)"

ENFORCE_DOCKER_RM_HOOK_INPUT="$ENFORCE_DOCKER_RM_INPUT" python3 - <<'PYEOF'
import json
import os
import re
import shlex
import sys

raw = os.environ.get("ENFORCE_DOCKER_RM_HOOK_INPUT", "")
# strict=False accepts raw control characters (tabs/newlines) inside strings
# so a payload with an embedded tab cannot bypass the hook via a parse failure
try:
    payload = json.loads(raw, strict=False)
except json.JSONDecodeError:
    sys.exit(0)

tool = payload.get("tool_name", "")
if tool != "Bash":
    sys.exit(0)

cmd = payload.get("tool_input", {}).get("command", "")
if not cmd:
    sys.exit(0)

# Only inspect commands that contain docker run or incus/lxc launch|init
# (any whitespace: spaces, tabs, or backslash-newline continuations)
if not re.search(r"docker\s+run|(incus|lxc)\s+(launch|init)", cmd):
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
    if clean[0] not in ("docker", "incus", "lxc"):
        continue

    # incus/lxc launch|init: an omitted instance name makes incus assign a
    # random one — unscoped and untargetable. Require an explicit name so
    # every instance is project-scoped, same policy as docker --name.
    if clean[0] in ("incus", "lxc"):
        if len(clean) < 2 or clean[1] not in ("launch", "init"):
            continue
        if any(t in ("--help", "-h") for t in clean[2:]):
            continue
        # Positional tokens after the verb: first is the image, second is the
        # instance name. Skip flags, values of known value-taking flags, and
        # key=value tokens; unknown value-taking flags fail open — acceptable.
        value_flags = {
            "-p", "--profile", "-n", "--network", "-s", "--storage",
            "-t", "--type", "-d", "--device", "-c", "--config",
            "--target", "--project",
        }
        positionals = []
        skip_next = False
        for t in clean[2:]:
            if skip_next:
                skip_next = False
                continue
            if t.startswith("-"):
                if t in value_flags:
                    skip_next = True
                continue
            if "=" in t:
                continue
            positionals.append(t)
        if len(positionals) < 2:
            short = " ".join(clean[:6]) + (" ..." if len(clean) > 6 else "")
            violations.append((short, ["instance name"]))
        continue

    if len(clean) < 2 or clean[1] != "run":
        continue

    # Check for --rm in the argument list
    # Also accept --rm=true
    has_rm = any(t in ("--rm", "--rm=true") for t in clean[2:])

    # Check for --name in the argument list
    # Accept both "--name value" and "--name=value" forms
    has_name = any(t == "--name" or t.startswith("--name=") for t in clean[2:])

    # docker run --help and dry-run forms are fine
    is_help = any(t in ("--help", "-h") for t in clean[2:])

    if is_help:
        continue

    missing = []
    if not has_rm:
        missing.append("--rm")
    if not has_name:
        missing.append("--name")

    if missing:
        # Reconstruct a short form for the message
        short = " ".join(clean[:6]) + (" ..." if len(clean) > 6 else "")
        violations.append((short, missing))

if not violations:
    sys.exit(0)

msg = (
    "BLOCKED: container/instance launch missing required naming.\n\n"
    "Every docker container must use --rm (self-remove on exit, no orphans) and\n"
    "--name {project_name}-XXXX; every incus/lxc instance must be launched with\n"
    "an explicit {project_name}-XXXX instance name (targeted cleanup by name).\n"
    "XXXX = random 8-char lowercase alphanumeric suffix.\n\n"
    "Violating command(s):\n"
)
for short, missing in violations:
    msg += f"  {short}  (missing: {', '.join(missing)})\n"

msg += (
    "\nFix patterns:\n"
    "  docker run --rm --name \"{project_name}-$(tr -dc 'a-z0-9' </dev/urandom | head -c8)\" [OPTIONS] IMAGE [COMMAND]\n"
    "  incus launch [OPTIONS] IMAGE \"$(basename \"$PWD\")-$(tr -dc 'a-z0-9' </dev/urandom | head -c8)\"\n\n"
    "If this container must persist after the session (e.g. a user-requested dev environment),\n"
    "confirm with the user first and document the container name/ID."
)

print(msg)
sys.stderr.write(msg + "\n")
sys.exit(2)
PYEOF
