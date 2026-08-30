#!/usr/bin/env bash
# shellcheck shell=bash
# - - - - - - - - - - - - - - - - - - - - - - - - -
##@Version           :  202608301800-git
# @@Author           :  Jason Hempstead
# @@Contact          :  git-admin@casjaysdev.pro
# @@License          :  WTFPL
# @@ReadME           :  session-start.sh --help
# @@Copyright        :  Copyright: (c) 2026 Jason Hempstead, Casjays Developments
# @@Created          :  Friday, May 16, 2026 00:00 EDT
# @@File             :  session-start.sh
# @@Description      :  SessionStart hook: inject project-dir context to anchor every session
# @@Changelog        :  Noted project CLAUDE.md as loader and SPEC.md as override tier; fixed the license header field to WTFPL.
# @@TODO             :
# @@Other            :  Silently exits if not inside a git repo with a project CLAUDE.md or AI.md
# @@Resource         :
# - - - - - - - - - - - - - - - - - - - - - - - - -
VERSION="202608301800-git"
# - - - - - - - - - - - - - - - - - - - - - - - - -

set -euo pipefail

project=$(git -C "$PWD" rev-parse --show-toplevel 2>/dev/null) || exit 0

has_claude=0
has_ai=0
has_spec=0
[ -f "$project/CLAUDE.md" ] && has_claude=1
[ -f "$project/AI.md" ] && has_ai=1
[ -f "$project/SPEC.md" ] && has_spec=1

# Only fire when the project has a CLAUDE.md or AI.md (a managed project)
[ "$has_claude" -eq 1 ] || [ "$has_ai" -eq 1 ] || exit 0

LINES=("SESSION CONTEXT" "project_dir: ${project}")
if [ "$has_claude" -eq 1 ]; then
  LINES+=("Read ${project}/CLAUDE.md first — it is a short loader; this project's real spec lives in AI.md (THE HOW) and IDEA.md (THE WHAT).")
fi
LINES+=("Project CLAUDE.md and AI.md are the source of truth for this session — they override the global ~/.claude/CLAUDE.md.")
if [ "$has_spec" -eq 1 ]; then
  LINES+=("SPEC.md exists — it overrides AI.md for any rule it addresses. Precedence: SPEC.md > AI.md > global CLAUDE.md.")
fi
LINES+=("All writes must stay within ${project} unless the user explicitly names an external path.")
if [ "$has_ai" -eq 1 ]; then
  LINES+=("Read AI.md and IDEA.md before acting on this project.")
fi

MSG=$(printf '%s\n' "${LINES[@]}")

python3 -c "
import json, sys
print(json.dumps({'hookSpecificOutput': {'hookEventName': 'SessionStart', 'additionalContext': sys.argv[1]}}))
" "$MSG"
