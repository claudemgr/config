#!/usr/bin/env bash
# shellcheck shell=bash
# - - - - - - - - - - - - - - - - - - - - - - - - -
##@Version           :  202608301700-git
# @@Author           :  Jason Hempstead
# @@Contact          :  git-admin@casjaysdev.pro
# @@License          :  MIT or LICENSE.md
# @@ReadME           :  no-destructive-bypass.sh --help
# @@Copyright        :  Copyright: (c) 2026 Jason Hempstead, Casjays Developments
# @@Created          :  Sunday, August 30, 2026 17:00 EDT
# @@File             :  no-destructive-bypass.sh
# @@Description      :  PreToolUse hook: hard-blocks git reset (any form), dd, shred, mkfs*, wipefs
# @@Description      :  everywhere, with alias/wrapper-bypass hardening. settings.json's permissions.deny
# @@Description      :  already lists these five as denied, but permissions.deny does raw glob matching on
# @@Description      :  the literal command string, so \dd, command dd, env FOO=1 dd, or a wrapped/nested
# @@Description      :  invocation slips past it untouched. This hook re-enforces the same policy with the
# @@Description      :  shlex/wrapper-stripping approach already used by no-force-push.sh and
# @@Description      :  no-history-rewrite.sh, closing the bypass gap without changing the underlying policy.
# @@Changelog        :  Initial version - audit found permissions.deny's raw glob matching has no
# @@Changelog        :  wrapper-bypass hardening for git reset/dd/shred/mkfs/wipefs
# @@TODO             :  None
# @@Other            :  Container/VM-mediated invocations (docker exec, incus exec, etc.) are NOT exempted
# @@Other            :  here - unlike protect-host.sh's path-scoped rules, these five ops are denied
# @@Other            :  unconditionally by settings.json regardless of target, so the guest-container
# @@Other            :  exemption used elsewhere does not apply
# @@Resource         :  home/settings.json permissions.deny
# @@Terminal App     :  no
# @@sudo/root        :  no
# @@Template         :  shell/bash
# - - - - - - - - - - - - - - - - - - - - - - - - -
# shellcheck disable=SC1001,SC1003,SC2001,SC2003,SC2016,SC2031,SC2090,SC2115,SC2120,SC2155,SC2199,SC2229,SC2317,SC2329
# - - - - - - - - - - - - - - - - - - - - - - - - -
VERSION="202608301700-git"
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
    # \dd, command dd, env [KEY=VAL...] dd, KEY=VAL dd
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
        for i, tok in enumerate(rest):
            if tok.startswith("-"):
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
