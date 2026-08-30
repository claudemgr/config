#!/usr/bin/env bash
# shellcheck shell=bash
# - - - - - - - - - - - - - - - - - - - - - - - - -
##@Version           :  202608301200-git
# @@Author           :  Jason Hempstead
# @@Contact          :  git-admin@casjaysdev.pro
# @@License          :  MIT or LICENSE.md
# @@ReadME           :  no-subagent-commit.sh --help
# @@Copyright        :  Copyright: (c) 2026 Jason Hempstead, Casjays Developments
# @@Created          :  Sunday, August 30, 2026 12:00 EDT
# @@File             :  no-subagent-commit.sh
# @@Description      :  PreToolUse hook: block gitcommit/git commit/git push when tool_input.agent_id
# @@Description      :  is present — that field is only set on subagent tool calls, so this closes the
# @@Description      :  gap the "agents never commit" rule left as prose-only with no technical gate.
# @@Changelog        :  Initial version — a fork/subagent committed and pushed unrequested; the rule
# @@Changelog        :  existed in CLAUDE.md/AI.md but nothing actually enforced it
# @@TODO             :  None
# @@Other            :  Applies everywhere, including the Local System Management Zone — the zone's
# @@Other            :  raw-git exception is about bypassing gitcommit for the main session, never
# @@Other            :  about letting a subagent commit on its own authority
# @@Resource         :  CLAUDE.md - Agent Usage - "Agents never commit"
# @@Terminal App     :  no
# @@sudo/root        :  no
# @@Template         :  shell/bash
# - - - - - - - - - - - - - - - - - - - - - - - - -
# shellcheck disable=SC1001,SC1003,SC2001,SC2003,SC2016,SC2031,SC2090,SC2115,SC2120,SC2155,SC2199,SC2229,SC2317,SC2329
# - - - - - - - - - - - - - - - - - - - - - - - - -
VERSION="202608301200-git"
# - - - - - - - - - - - - - - - - - - - - - - - - -
set -uo pipefail
# - - - - - - - - - - - - - - - - - - - - - - - - -

INPUT="$(cat)"
[ -z "$INPUT" ] && exit 0

# Fail-open if python3 is missing — a broken hook exits 0 (no-op) so we never silently block every Bash call.
if ! command -v python3 >/dev/null 2>&1; then
  printf 'no-subagent-commit.sh: required command not found: python3\n' >&2
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

# agent_id is present only on tool calls made from inside a subagent —
# absent for the main session. No agent_id -> not our concern.
if not d.get("agent_id", ""):
    sys.exit(0)

cmd = d.get("tool_input", {}).get("command", "") or ""
if not cmd:
    sys.exit(0)

# Cheap pre-filter: nothing resembling git/gitcommit anywhere -> allow.
if not re.search(r"\bgit\b|\bgitcommit\b", cmd):
    sys.exit(0)


def is_commit_or_push(tokens):
    # tokens = argv of one sub-command, wrapper/env prefixes already stripped
    if not tokens:
        return False
    if tokens[0] == "gitcommit":
        return True
    if tokens[0] != "git":
        return False
    for tok in tokens[1:]:
        if tok in ("commit", "push"):
            return True
        # first non-flag token after `git` that isn't commit/push -> different subcommand
        if not tok.startswith("-"):
            return tok in ("commit", "push")
    return False


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

agent_type = d.get("agent_type", "") or "unknown"
msg = (
    f"BLOCKED: subagents never commit or push (agent_type: {agent_type}).\n\n"
    "Edit and report back — the main session reviews the diff, writes\n"
    "COMMIT_MESS, and runs `gitcommit --dir {project_dir} all` itself.\n\n"
    "See CLAUDE.md's Agent Usage section: \"Agents never commit\"."
)
print(msg)
sys.stderr.write(msg + "\n")
sys.exit(2)
PYEOF
