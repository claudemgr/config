#!/usr/bin/env bash
# shellcheck shell=bash
# - - - - - - - - - - - - - - - - - - - - - - - - -
##@Version           :  202605160000-git
# @@Author           :  Jason Hempstead
# @@Contact          :  git-admin@casjaysdev.pro
# @@License          :  MIT or LICENSE.md
# @@ReadME           :  post-compact.sh --help
# @@Copyright        :  Copyright: (c) 2026 Jason Hempstead, Casjays Developments
# @@Created          :  Friday, May 16, 2026 00:00 EDT
# @@File             :  post-compact.sh
# @@Description      :  PostCompact hook: re-inject project-dir context after compaction truncates it
# @@Changelog        :  New File
# @@TODO             :
# @@Other            :  Compaction drops old context; this hook re-anchors Claude to the project
# @@Resource         :
# - - - - - - - - - - - - - - - - - - - - - - - - -

set -euo pipefail

# Drain stdin (compaction summary) — we do not use it but must consume it
INPUT="$(cat)"

project=$(git -C "$PWD" rev-parse --show-toplevel 2>/dev/null) || exit 0
[ -f "$project/CLAUDE.md" ] || [ -f "$project/AI.md" ] || exit 0

if [ -f "$project/home/CLAUDE.md" ]; then
  MSG="POST-COMPACT DRIFT GUARD [claudemgr/config]
project_dir: ${project}
Context was compacted — re-anchoring now.
Source: ${project}/home/ | Deployed: ~/.claude/ (never read directly from this project)
When global CLAUDE.md says read ~/.claude/memory/MEMORY.md, read home/memory/MEMORY.md instead.
Writes stay within ${project}."
else
  MSG="POST-COMPACT CONTEXT
project_dir: ${project}
Context was compacted. Project CLAUDE.md/AI.md still take precedence over global ~/.claude/CLAUDE.md.
Writes stay within ${project}."
fi

python3 -c "
import json, sys
msg = sys.argv[1]
print(json.dumps({'systemMessage': msg}))
" "$MSG"
