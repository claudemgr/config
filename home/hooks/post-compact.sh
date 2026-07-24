#!/usr/bin/env bash
# shellcheck shell=bash
# - - - - - - - - - - - - - - - - - - - - - - - - -
##@Version           :  202607241700-git
# @@Author           :  Jason Hempstead
# @@Contact          :  git-admin@casjaysdev.pro
# @@License          :  MIT or LICENSE.md
# @@ReadME           :  post-compact.sh --help
# @@Copyright        :  Copyright: (c) 2026 Jason Hempstead, Casjays Developments
# @@Created          :  Friday, May 16, 2026 00:00 EDT
# @@File             :  post-compact.sh
# @@Description      :  SessionStart(compact) hook: re-inject project-dir and global context after compaction
# @@Changelog        :  Registered as SessionStart matcher=compact; emit additionalContext so the model sees it
# @@Changelog        :  Clear spec-guard marker on compaction so AI.md/SPEC.md must be re-read (spec-guard.sh)
# @@Changelog        :  Message no longer mandates bulk file re-reads (was causing autocompact thrashing); now on-demand only
# @@TODO             :
# @@Other            :  Compaction drops old context — this hook re-anchors Claude to the project
# @@Other            :  Message intentionally avoids ordering a full re-read of AI.md/CLAUDE.md/MEMORY.md — that refilled context fast enough to re-trigger compaction in a loop
# @@Resource         :
# - - - - - - - - - - - - - - - - - - - - - - - - -
VERSION="202607241700-git"
# - - - - - - - - - - - - - - - - - - - - - - - - -

set -euo pipefail

# Drain stdin (session-start payload) — must consume it
POST_COMPACT_INPUT="$(cat)"

# Clear this session's spec-guard marker so AI.md/SPEC.md must be re-read after compaction
if command -v jq >/dev/null 2>&1; then
  POST_COMPACT_SESSION_ID=$(printf '%s' "$POST_COMPACT_INPUT" | jq -r '.session_id // ""')
  [ -n "$POST_COMPACT_SESSION_ID" ] && rm -rf -- "${TMPDIR:-/tmp}/claude-spec-guard/${POST_COMPACT_SESSION_ID}"
fi

POST_COMPACT_PROJECT=$(git -C "$PWD" rev-parse --show-toplevel 2>/dev/null) || exit 0
[ -f "$POST_COMPACT_PROJECT/CLAUDE.md" ] || [ -f "$POST_COMPACT_PROJECT/AI.md" ] || exit 0

POST_COMPACT_MSG="POST-COMPACT CONTEXT
project_dir: ${POST_COMPACT_PROJECT}
Context was compacted. The summary above is your state — resume from its task goal and next actions.
Do NOT bulk re-read files now; that refills context immediately and can trigger another compaction.
1. Project CLAUDE.md/AI.md/SPEC.md still override the global CLAUDE.md, but consult them on demand —
   read only the specific section your next action needs, not the whole file
2. Before editing a file, re-read only that file (or the relevant section) — don't proactively re-read files you are not about to touch
3. All writes must stay within ${POST_COMPACT_PROJECT} unless the user explicitly names an external path
4. spec-guard.sh will block Edit/Write until AI.md/SPEC.md is Read again this session — it fires on its own when you attempt an edit; no need to pre-emptively satisfy it"

python3 -c "
import json, sys
print(json.dumps({'hookSpecificOutput': {'hookEventName': 'SessionStart', 'additionalContext': sys.argv[1]}}))
" "$POST_COMPACT_MSG"
