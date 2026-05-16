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
# @@Other            :  Compaction drops old context — this hook re-anchors Claude to the project
# @@Resource         :
# - - - - - - - - - - - - - - - - - - - - - - - - -

set -euo pipefail

# Drain stdin (compaction summary) — must consume it
INPUT="$(cat)"

project=$(git -C "$PWD" rev-parse --show-toplevel 2>/dev/null) || exit 0
[ -f "$project/CLAUDE.md" ] || [ -f "$project/AI.md" ] || exit 0

MSG="POST-COMPACT CONTEXT
project_dir: ${project}
Context was compacted. Project CLAUDE.md and AI.md still take precedence over the global ~/.claude/CLAUDE.md.
All writes must stay within ${project}. Re-read project files as needed — do not rely on pre-compaction assumptions."

python3 -c "
import json, sys
print(json.dumps({'systemMessage': sys.argv[1]}))
" "$MSG"
