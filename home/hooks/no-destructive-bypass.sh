#!/usr/bin/env bash
# shellcheck shell=bash
# - - - - - - - - - - - - - - - - - - - - - - - - -
##@Version           :  202608301745-git
# @@Author           :  Jason Hempstead
# @@Contact          :  git-admin@casjaysdev.pro
# @@License          :  WTFPL
# @@ReadME           :  no-destructive-bypass.sh --help
# @@Copyright        :  Copyright: (c) 2026 Jason Hempstead, Casjays Developments
# @@Created          :  Sunday, August 30, 2026 17:00 EDT
# @@File             :  no-destructive-bypass.sh
# @@Description      :  PreToolUse hook: hard-blocks git reset/dd/shred/mkfs*/wipefs everywhere, re-enforcing permissions.deny against alias/wrapper-bypass invocations.
# @@Changelog        :  Initial version hardening permissions.deny against wrapper bypasses for git reset/dd/shred/mkfs/wipefs.
# @@TODO             :  None
# @@Other              :  Container/VM-mediated invocations are NOT exempted — these five ops are denied unconditionally by settings.json regardless of target.
# @@Resource         :  home/settings.json permissions.deny
# @@Terminal App     :  no
# @@sudo/root        :  no
# @@Template         :  shell/bash
# - - - - - - - - - - - - - - - - - - - - - - - - -
# shellcheck disable=SC1001,SC1003,SC2001,SC2003,SC2016,SC2031,SC2090,SC2115,SC2120,SC2155,SC2199,SC2229,SC2317,SC2329
# - - - - - - - - - - - - - - - - - - - - - - - - -
VERSION="202608301745-git"
# - - - - - - - - - - - - - - - - - - - - - - - - -
set -euo pipefail

# A broken hook must fail OPEN (exit 0) so it never silently blocks every Bash call.
if ! command -v python3 >/dev/null 2>&1; then
  printf 'no-destructive-bypass.sh: required command not found: python3 (hook disabled, failing open)\n' >&2
  exit 0
fi

NO_DESTRUCTIVE_BYPASS_INPUT="$(cat)"

NO_DESTRUCTIVE_BYPASS_HOOK_INPUT="$NO_DESTRUCTIVE_BYPASS_INPUT" python3 - <<'PYEOF'
import json
import os
import re
import shlex
import sys

raw = os.environ.get("NO_DESTRUCTIVE_BYPASS_HOOK_INPUT", "")
try:
    payload = json.loads(raw, strict=False)
except json.JSONDecodeError:
    sys.exit(0)

if payload.get("tool_name", "") != "Bash":
    sys.exit(0)

cmd = payload.get("tool_input", {}).get("command", "")
if not cmd:
    sys.exit(0)

HEREDOC_SHELLS = {"bash", "sh", "zsh", "dash", "ksh", "mksh", "ash"}


def strip_heredoc_bodies(text):
    # Heredoc bodies fed to a host shell stay scanned; everything else is data
    # that merely mentions a command name and must not false-positive. Fails
    # open to the original text on any parse error.
    try:
        out = []
        lines = text.split("\n")
        i = 0
        while i < len(lines):
            line = lines[i]
            out.append(line)
            delims = []
            for m in re.finditer(r"(?<!<)<<(?!<)-?\s*(['\"]?)(\w+)\1", line):
                head = {t.rsplit("/", 1)[-1].lstrip("\\") for t in line[: m.start()].split()}
                if not (head & HEREDOC_SHELLS):
                    delims.append(m.group(2))
            i += 1
            for delim in delims:
                while i < len(lines):
                    if lines[i].strip() == delim:
                        out.append(lines[i])
                        i += 1
                        break
                    i += 1
        return "\n".join(out)
    except Exception:
        return text


cmd = strip_heredoc_bodies(cmd)

if not re.search(r"\bgit\b|\bdd\b|\bshred\b|\bmkfs|\bwipefs\b", cmd):
    sys.exit(0)

GIT_GLOBAL_OPTS_WITH_VALUE = {"-C", "-c", "--git-dir", "--work-tree", "--namespace", "--exec-path"}

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
    # \dd, command dd, env [KEY=VAL...] dd, KEY=VAL dd, timeout 60 dd
    wrappers = {"command", "builtin", "env", "exec", "nohup", "setsid", "nice",
                "ionice", "stdbuf", "time", "timeout", "sudo", "doas"}
    clean = [tok.lstrip("\\") for tok in tokens]
    while clean:
        head = clean[0]
        if head in wrappers:
            clean.pop(0)
            # skip wrapper flags and duration/priority arguments (timeout 600)
            while clean and (clean[0].startswith("-")
                             or re.fullmatch(r"[0-9]+(\.[0-9]+)?[smhd]?", clean[0])):
                clean.pop(0)
            continue
        if re.match(r"^[A-Za-z_][A-Za-z0-9_]*=", head):
            clean.pop(0)
            continue
        break

    if not clean:
        continue

    head = clean[0]

    if head == "dd":
        violations.append((sub_cmd, "dd"))
        continue

    if head == "shred":
        violations.append((sub_cmd, "shred"))
        continue

    if head == "wipefs":
        violations.append((sub_cmd, "wipefs"))
        continue

    if head.startswith("mkfs"):
        violations.append((sub_cmd, "mkfs*"))
        continue

    if head == "git":
        rest = clean[1:]
        i = 0
        while i < len(rest):
            tok = rest[i]
            if tok in GIT_GLOBAL_OPTS_WITH_VALUE:
                i += 2
                continue
            if tok.startswith("-"):
                i += 1
                continue
            if tok == "reset":
                violations.append((sub_cmd, "git reset"))
            break

if not violations:
    sys.exit(0)

msg = (
    "BLOCKED: destructive operation denied everywhere (git reset, dd, shred,\n"
    "mkfs*, wipefs).\n\n"
    "These are unconditionally denied by settings.json's permissions.deny, but\n"
    "a wrapper (\\cmd, command cmd, env KEY=VAL cmd) can slip past its raw glob\n"
    "match. This hook re-enforces the same policy after stripping wrappers.\n\n"
    "Ask the user to confirm, then have them run the command manually -\n"
    "this hook cannot grant a one-time exception.\n\n"
    "Violating command(s):\n"
)
for sub, verb in violations:
    msg += f"  {sub}  (denied: {verb})\n"

print(msg)
sys.stderr.write(msg + "\n")
sys.exit(2)
PYEOF
