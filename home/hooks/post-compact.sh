#!/usr/bin/env bash
# shellcheck shell=bash
# - - - - - - - - - - - - - - - - - - - - - - - - -
##@Version           :  202606080000-git
# @@Author           :  Jason Hempstead
# @@Contact          :  git-admin@casjaysdev.pro
# @@License          :  MIT or LICENSE.md
# @@ReadME           :  post-compact.sh --help
# @@Copyright        :  Copyright: (c) 2026 Jason Hempstead, Casjays Developments
# @@Created          :  Friday, May 16, 2026 00:00 EDT
# @@File             :  post-compact.sh
# @@Description      :  PostCompact hook: re-inject project-dir and global context after compaction
# @@Changelog        :  Updated to reload MEMORY.md and convention files post-compaction
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
Context was compacted. Re-establish full state before continuing:
1. Project CLAUDE.md and AI.md are the source of truth — they override ~/.claude/CLAUDE.md; re-read them now
2. Re-read ~/.claude/memory/MEMORY.md and any convention files it references that are relevant to the current task
3. Re-read ~/.claude/memory/MEMORY.md at session start and load referenced files as needed
4. All writes must stay within ${project} unless the user explicitly names an external path
5. Do not rely on pre-compaction memory of file contents — re-read files before editing them
6. Resume from the task goal and next actions captured in the compaction summary
7. Read AI.md and IDEA.md before acting on this project"

python3 -c "
import json, sys
print(json.dumps({'systemMessage': sys.argv[1]}))
" "$MSG"
