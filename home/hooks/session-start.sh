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

# Only fire when the project has a CLAUDE.md or AI.md (a managed project)
[ -f "$project/CLAUDE.md" ] || [ -f "$project/AI.md" ] || exit 0

MSG="SESSION CONTEXT
project_dir: ${project}
Project CLAUDE.md and AI.md are the source of truth for this session — they override the global ~/.claude/CLAUDE.md.
All writes must stay within ${project} unless the user explicitly names an external path.
Read AI.md and IDEA.md before acting on this project."

python3 -c "
import json, sys
print(json.dumps({'systemMessage': sys.argv[1]}))
" "$MSG"
