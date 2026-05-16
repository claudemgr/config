#!/usr/bin/env bash
# shellcheck shell=bash
# - - - - - - - - - - - - - - - - - - - - - - - - -
##@Version           :  202605160000-git
# @@Author           :  Jason Hempstead
# @@Contact          :  git-admin@casjaysdev.pro
# @@License          :  MIT or LICENSE.md
# @@ReadME           :  session-start.sh --help
# @@Copyright        :  Copyright: (c) 2026 Jason Hempstead, Casjays Developments
# @@Created          :  Friday, May 16, 2026 00:00 EDT
# @@File             :  session-start.sh
# @@Description      :  SessionStart hook: inject project-dir context to anchor every session
# @@Changelog        :  New File
# @@TODO             :
# @@Other            :  Silently exits if not inside a git repo with a project CLAUDE.md or AI.md
# @@Resource         :
# - - - - - - - - - - - - - - - - - - - - - - - - -

set -euo pipefail

project=$(git -C "$PWD" rev-parse --show-toplevel 2>/dev/null) || exit 0

# Only fire when the project has a CLAUDE.md or AI.md (i.e. a managed project)
[ -f "$project/CLAUDE.md" ] || [ -f "$project/AI.md" ] || exit 0

# Build the context message
if [ -f "$project/home/CLAUDE.md" ]; then
  # claudemgr/config project — source vs deployed distinction matters
  MSG="DRIFT GUARD ACTIVE [claudemgr/config]
project_dir: ${project}
Source files: ${project}/home/ (CLAUDE.md, memory/, agents/, hooks/, settings.json)
Deployed copies: ~/.claude/ — written by deploy script only, never read directly
Rule: when the global CLAUDE.md says read ~/.claude/memory/MEMORY.md, in THIS project read home/memory/MEMORY.md instead.
All reads and writes must stay within ${project}."
else
  # General managed project
  MSG="SESSION CONTEXT
project_dir: ${project}
Project CLAUDE.md and AI.md override the global ~/.claude/CLAUDE.md for this session.
All writes must stay within ${project} unless the user explicitly names an external path.
If this project has AI.md, read it before acting."
fi

python3 -c "
import json, sys
msg = sys.argv[1]
print(json.dumps({'systemMessage': msg}))
" "$MSG"
