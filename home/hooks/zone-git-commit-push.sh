#!/usr/bin/env bash
# shellcheck shell=bash
# - - - - - - - - - - - - - - - - - - - - - - - - -
##@Version           :  202608301555-git
# @@Author           :  Jason Hempstead
# @@Contact          :  git-admin@casjaysdev.pro
# @@License          :  MIT or LICENSE.md
# @@ReadME           :  zone-git-commit-push.sh --help
# @@Copyright        :  Copyright: (c) 2026 Jason Hempstead, Casjays Developments
# @@Created          :  Saturday, August 29, 2026 00:00 EDT
# @@File             :  zone-git-commit-push.sh
# @@Description      :  PreToolUse hook: allow raw `git commit`/`git push` only under ~/Projects/local/system/**, block elsewhere
# @@Description      :  Outside the zone, gitcommit remains the only sanctioned commit+push path
# @@Changelog        :  Initial version — permissions.deny cannot be directory-scoped, so the zone exception is enforced here
# @@Changelog        :  Fixed git -C/-c/--git-dir/etc. global-flag-value bypass — the subcommand
# @@Changelog        :  scan mistook a flag's value for the subcommand and stopped early
# @@TODO             :  None
# @@Other            :  git reset stays hard-denied everywhere via settings.json (excluded from the zone pre-authorization)
# @@Other            :  force-push stays blocked everywhere via no-force-push.sh, including inside the zone
# @@Resource         :  CLAUDE.md - Local System Management Zone
# @@Terminal App     :  no
# @@sudo/root        :  no
# @@Template         :  shell/bash
# - - - - - - - - - - - - - - - - - - - - - - - - -
# shellcheck disable=SC1001,SC1003,SC2001,SC2003,SC2016,SC2031,SC2090,SC2115,SC2120,SC2155,SC2199,SC2229,SC2317,SC2329
# - - - - - - - - - - - - - - - - - - - - - - - - -
VERSION="202608301555-git"
# - - - - - - - - - - - - - - - - - - - - - - - - -
set -uo pipefail
# - - - - - - - - - - - - - - - - - - - - - - - - -

INPUT="$(cat)"
[ -z "$INPUT" ] && exit 0

# Fail-open if python3 is missing — a broken hook exits 0 (no-op) so we never silently block every Bash call.
if ! command -v python3 >/dev/null 2>&1; then
  printf 'zone-git-commit-push.sh: required command not found: python3\n' >&2
  exit 0
fi

HOOK_INPUT="$INPUT" python3 - <<'PYEOF'
import json
import os
import re
import shlex
import sys

try:
    d = json.loads(os.environ.get("HOOK_INPUT", "{}"), strict=False)
except json.JSONDecodeError:
    sys.exit(0)

if d.get("tool_name", "") != "Bash":
    sys.exit(0)

cmd = d.get("tool_input", {}).get("command", "") or ""
if not cmd:
    sys.exit(0)

# Cheap pre-filter: nothing resembling git anywhere -> allow.
if not re.search(r"\bgit\b", cmd):
    sys.exit(0)


GIT_GLOBAL_OPTS_WITH_VALUE = {"-C", "-c", "--git-dir", "--work-tree", "--namespace", "--exec-path"}


def find_git_subcommand(tokens):
    # First non-flag token after "git", skipping the VALUE of any global
    # option that takes one (-C <path>, -c <k>=<v>, --git-dir <path>, etc.)
    # so `git -C /repo commit` cannot hide its subcommand from the scan.
    i = 1
    while i < len(tokens):
        tok = tokens[i]
        if tok in GIT_GLOBAL_OPTS_WITH_VALUE:
            i += 2
            continue
        if tok.startswith("-"):
            i += 1
            continue
        return tok
    return None


def is_commit_or_push(clean_tokens):
    # Expects argv of one sub-command with wrapper/env prefixes already stripped.
    if not clean_tokens or clean_tokens[0] != "git":
        return False
    return find_git_subcommand(clean_tokens) in ("commit", "push")


found = False
for sub in re.split(r"[\n;]|&&|\|\||[|&]", cmd):
    sub = sub.strip()
    if not sub:
        continue
    try:
        tokens = shlex.split(sub)
    except ValueError:
        tokens = sub.split()

    # Strip wrapper/alias-bypass prefixes and env assignments (any case):
    # \git, command git, env [KEY=VAL...] git, KEY=VAL git
    clean = []
    skipping_prefix = True
    for tok in tokens:
        if skipping_prefix:
            if tok in ("command", "env", "exec", "nohup", "time"):
                continue
            if re.match(r"^[A-Za-z_][A-Za-z0-9_]*=", tok):
                continue
            if tok.startswith("-"):
                continue
            skipping_prefix = False
        clean.append(tok.lstrip("\\"))

    if is_commit_or_push(clean):
        found = True
        break

if not found:
    sys.exit(0)

# Local System Management Zone (~/Projects/local/system/**, see CLAUDE.md) pre-authorizes
# raw `git commit`/`git push` — derived from $HOME at runtime, never hardcoded.
cwd = d.get("cwd", "") or ""
zone_root = os.path.join(os.environ.get("HOME", "/root"), "Projects", "local", "system")
if cwd == zone_root or cwd.startswith(zone_root + os.sep):
    sys.exit(0)

msg = (
    "BLOCKED: raw `git commit`/`git push` is forbidden outside the Local System "
    "Management Zone (~/Projects/local/system/**).\n\n"
    "The only sanctioned commit+push path here is:\n"
    "  gitcommit --dir {project_dir} all\n\n"
    "See CLAUDE.md's Local System Management Zone section for the zone exception."
)
print(msg)
sys.stderr.write(msg + "\n")
sys.exit(2)
PYEOF
