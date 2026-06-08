#!/usr/bin/env bash
# shellcheck shell=bash
# - - - - - - - - - - - - - - - - - - - - - - - - -
##@Version           :  202606080000-git
# @@Author           :  Jason Hempstead
# @@Contact          :  git-admin@casjaysdev.pro
# @@License          :  MIT or LICENSE.md
# @@ReadME           :  pre-compact.sh --help
# @@Copyright        :  Copyright: (c) 2026 Jason Hempstead, Casjays Developments
# @@Created          :  Sunday, Jun 08, 2026 00:00 EDT
# @@File             :  pre-compact.sh
# @@Description      :  PreCompact hook: inject custom instructions into the compaction model prompt
# @@Changelog        :  New File
# @@TODO             :
# @@Other            :  newCustomInstructions are injected into the compaction model — guides what survives
# @@Resource         :
# - - - - - - - - - - - - - - - - - - - - - - - - -

set -euo pipefail

# Drain stdin — hook runner sends conversation state; must be consumed
INPUT="$(cat)"

INSTRUCTIONS="Preserve in the summary:
- Current task goal and what specific work was in progress
- All files modified, created, or deleted this session (exact paths)
- Commands run and their significant outcomes
- Errors encountered and how they were resolved
- Decisions made and the reasoning behind them
- Next actions remaining before the task is complete
- Active project constraints: naming conventions, toolchain rules, image selection, commit workflow
- The project_dir path and which repo is being worked on
- Any rule overrides or exceptions the user explicitly granted this session

Drop from the summary:
- Exploratory paths that were abandoned without result
- Verbose tool output that has already been acted on
- Repeated or duplicate log lines
- Discussion that reached no conclusion or actionable decision"

python3 -c "
import json, sys
print(json.dumps({'newCustomInstructions': sys.argv[1]}))
" "$INSTRUCTIONS"
