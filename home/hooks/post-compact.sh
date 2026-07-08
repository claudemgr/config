#!/usr/bin/env bash
# shellcheck shell=bash
# - - - - - - - - - - - - - - - - - - - - - - - - -
##@Version           :  202607031500-git
# @@Author           :  Jason Hempstead
# @@Contact          :  git-admin@casjaysdev.pro
# @@License          :  MIT or LICENSE.md
# @@ReadME           :  post-compact.sh --help
# @@Copyright        :  Copyright: (c) 2026 Jason Hempstead, Casjays Developments
# @@Created          :  Friday, May 16, 2026 00:00 EDT
# @@File             :  post-compact.sh
# @@Description      :  SessionStart(compact) hook: re-inject project-dir and global context after compaction
# @@Changelog        :  Registered as SessionStart matcher=compact; emit additionalContext so the model sees it
# @@TODO             :
# @@Other            :  Compaction drops old context — this hook re-anchors Claude to the project
# @@Resource         :
# - - - - - - - - - - - - - - - - - - - - - - - - -
VERSION="202607031500-git"
# - - - - - - - - - - - - - - - - - - - - - - - - -

set -euo pipefail

# Drain stdin (session-start payload) — must consume it
POST_COMPACT_INPUT="$(cat)"

POST_COMPACT_PROJECT=$(git -C "$PWD" rev-parse --show-toplevel 2>/dev/null) || exit 0
[ -f "$POST_COMPACT_PROJECT/CLAUDE.md" ] || [ -f "$POST_COMPACT_PROJECT/AI.md" ] || exit 0

POST_COMPACT_MSG="POST-COMPACT CONTEXT
project_dir: ${POST_COMPACT_PROJECT}
Context was compacted. Re-establish full state before continuing:
1. Project CLAUDE.md and AI.md are the source of truth — they override ~/.claude/CLAUDE.md; re-read them now
2. Re-read ~/.claude/memory/MEMORY.md and any convention files it references that are relevant to the current task
3. All writes must stay within ${POST_COMPACT_PROJECT} unless the user explicitly names an external path
4. Do not rely on pre-compaction memory of file contents — re-read files before editing them
5. Resume from the task goal and next actions captured in the compaction summary
6. Read AI.md and IDEA.md before acting on this project"

python3 -c "
import json, sys
print(json.dumps({'hookSpecificOutput': {'hookEventName': 'SessionStart', 'additionalContext': sys.argv[1]}}))
" "$POST_COMPACT_MSG"
