#!/usr/bin/env bash
# shellcheck shell=bash
# - - - - - - - - - - - - - - - - - - - - - - - - -
##@Version           :  202608311430-git
# @@Author           :  Jason Hempstead
# @@Contact          :  git-admin@casjaysdev.pro
# @@License          :  WTFPL
# @@ReadME           :  drift-guard-read.sh --help
# @@Copyright        :  Copyright: (c) 2026 Jason Hempstead, Casjays Developments
# @@Created          :  Friday, May 16, 2026 00:00 EDT
# @@File             :  drift-guard-read.sh
# @@Description      :  PreToolUse Read+Bash hook: block reading ~/.claude/ deployed copies when a home/ source exists
# @@Changelog        :  Fixed ARG_MAX crash by passing payload via tmpfile instead of an env var.
# @@TODO             :
# @@Other            :  Fires only when inside a claudemgr/config project (detected by presence of home/CLAUDE.md); fails open if the home/ source doesn't exist
# @@Resource         :  home/hooks/no-read-gitcommit.sh
# - - - - - - - - - - - - - - - - - - - - - - - - -
VERSION="202608311430-git"
# - - - - - - - - - - - - - - - - - - - - - - - - -

set -euo pipefail

if ! command -v python3 >/dev/null 2>&1; then
  printf 'drift-guard-read.sh: python3 not found — drift guard disabled\n' >&2
  exit 0
fi

DRIFT_GUARD_READ_INPUT="$(cat)"

DRIFT_GUARD_READ_INPUT_TMPFILE="$(mktemp)"
trap 'rm -f "$DRIFT_GUARD_READ_INPUT_TMPFILE"' EXIT
printf '%s' "$DRIFT_GUARD_READ_INPUT" > "$DRIFT_GUARD_READ_INPUT_TMPFILE"

python3 - "$DRIFT_GUARD_READ_INPUT_TMPFILE" <<'PYEOF'
import json
import os
import re
import shlex
import sys

with open(sys.argv[1], "r") as _f:
    raw = _f.read()
try:
    payload = json.loads(raw, strict=False)
except json.JSONDecodeError:
    sys.exit(0)

tool_name = payload.get("tool_name", "")
if tool_name not in ("Read", "Bash"):
    sys.exit(0)

home = os.environ.get("HOME", "")
if not home:
    sys.exit(0)

claude_dir = os.path.join(home, ".claude")

# Only paths under ~/.claude/ that have a home/ source equivalent
WATCHED_PREFIXES = (
    os.path.join(claude_dir, "CLAUDE.md"),
    os.path.join(claude_dir, "settings.json"),
    os.path.join(claude_dir, "memory") + os.sep,
    os.path.join(claude_dir, "agents") + os.sep,
    os.path.join(claude_dir, "hooks") + os.sep,
    os.path.join(claude_dir, "skills") + os.sep,
    os.path.join(claude_dir, "TEMPLATES") + os.sep,
)


def is_watched(path):
    return path in WATCHED_PREFIXES[:2] or path.startswith(WATCHED_PREFIXES[2:])


def resolve_home(path):
    if not path:
        return ""
    if path == "~":
        return home
    if path.startswith("~/"):
        return home + path[1:]
    return path


def project_root(cwd):
    try:
        import subprocess
        out = subprocess.run(
            ["git", "-C", cwd, "rev-parse", "--show-toplevel"],
            capture_output=True, text=True, timeout=5,
        )
        if out.returncode != 0:
            return ""
        return out.stdout.strip()
    except Exception:
        return ""


def check_and_block(path):
    path = resolve_home(path)
    if not is_watched(path):
        return
    cwd = payload.get("cwd", "") or os.getcwd()
    proj = project_root(cwd)
    if not proj or not os.path.isfile(os.path.join(proj, "home", "CLAUDE.md")):
        return
    relative = path[len(claude_dir) + 1:]
    source = os.path.join(proj, "home", relative)
    # Only redirect when a home/ source actually exists — a deployed-only
    # file (nothing to redirect to) must fail open, not block the read
    if not os.path.exists(source):
        return
    msg = (
        f"BLOCKED: Drift guard — read home/{relative} (source) not "
        f"~/.claude/{relative} (deployed copy).\n"
        f"Source files live in {proj}/home/ and are deployed to ~/.claude/ "
        "by the deploy script.\n"
        "Never read deployed copies from within this project."
    )
    print(msg)
    sys.stderr.write(msg + "\n")
    sys.exit(2)


if tool_name == "Read":
    check_and_block(payload.get("tool_input", {}).get("file_path", "") or "")
    sys.exit(0)

# Bash: cat/less/head/etc. reads the same deployed copies but bypasses the
# Read tool entirely, so it needs the same redirect check.
cmd = payload.get("tool_input", {}).get("command", "")
if not cmd:
    sys.exit(0)

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
        check_and_block(arg)

sys.exit(0)
PYEOF
