#!/usr/bin/env bash
# shellcheck shell=bash
# - - - - - - - - - - - - - - - - - - - - - - - - -
##@Version           :  202608301800-git
# @@Author           :  Jason Hempstead
# @@Contact          :  git-admin@casjaysdev.pro
# @@License          :  WTFPL
# @@ReadME           :  validate-workflows.sh --help
# @@Copyright        :  Copyright: (c) 2026 Jason Hempstead, Casjays Developments
# @@Created          :  Sunday, May 17, 2026 00:00 EDT
# @@File             :  validate-workflows.sh
# @@Description      :  PreToolUse hook: validate staged .github/workflows files with act --list before gitcommit
# @@Changelog        :  Added the header block, timeout wrapping, setupmgr guard, --dir= parsing, and dual-stream BLOCKED output; fixed the license header field to WTFPL.
# @@TODO             :
# @@Other            :  Exit 0 = allow, exit 2 = block (message sent to Claude as context)
# @@Resource         :
# - - - - - - - - - - - - - - - - - - - - - - - - -
# shellcheck disable=SC1001,SC1003,SC2001,SC2003,SC2016,SC2031,SC2090,SC2115,SC2120,SC2155,SC2199,SC2229,SC2317,SC2329
# - - - - - - - - - - - - - - - - - - - - - - - - -
VERSION="202608301800-git"
# - - - - - - - - - - - - - - - - - - - - - - - - -
set -euo pipefail

# __blocked <msg> — emit the block reason to BOTH stdout and stderr, then exit 2.
# On exit 2 Claude Code relays stderr to the model; stdout is shown to the user.
__blocked() {
    printf '%s\n' "$1"
    printf '%s\n' "$1" >&2
    exit 2
}

INPUT="$(cat)"

CMD="$(printf '%s' "$INPUT" | python3 -c "
import sys, json
data = json.load(sys.stdin)
inp = data.get('tool_input', data.get('input', {}))
print(inp.get('command', ''))
" 2>/dev/null || true)"

[ -z "$CMD" ] && exit 0

# Only fire on gitcommit invocations
printf '%s' "$CMD" | grep -qE -- '\bgitcommit\b' || exit 0

# Extract --dir argument value (accepts both "--dir /path" and "--dir=/path")
PROJECT_DIR="$(printf '%s' "$CMD" | grep -oE -- '--dir(=|[[:space:]]+)[^[:space:]]+' | head -n1 | sed -E 's/^--dir(=|[[:space:]]+)//' || true)"
[ -z "$PROJECT_DIR" ] && exit 0
[ -d "$PROJECT_DIR" ] || exit 0

# Check if any .github/workflows/ YAML files are staged
STAGED_WORKFLOWS="$(git -C "$PROJECT_DIR" diff --cached --name-only 2>/dev/null \
    | grep -E -- '^\.github/workflows/.*\.ya?ml$' || true)"
[ -z "$STAGED_WORKFLOWS" ] && exit 0

# Ensure act is available; install via setupmgr if missing
if ! command -v act >/dev/null 2>&1; then
    if ! command -v setupmgr >/dev/null 2>&1; then
        __blocked 'BLOCKED: act is required to validate workflow files before committing.
Neither act nor setupmgr is installed, so automatic install is not possible.
Install act manually (https://github.com/nektos/act), then retry.'
    fi
    printf 'act not found — installing via setupmgr act...\n' >&2
    # timeout guards against a network stall freezing gitcommit forever
    timeout 60 setupmgr act >/dev/null 2>&1 && STATUS=0 || STATUS=$?
    if [ "$STATUS" -eq 124 ]; then
        __blocked 'BLOCKED: `setupmgr act` timed out after 60 seconds (failing closed).
Install act manually (https://github.com/nektos/act), then retry.'
    fi
    if [ "$STATUS" -ne 0 ]; then
        __blocked 'BLOCKED: act is required to validate workflow files before committing.
Automatic install via `setupmgr act` failed.
Install act manually (https://github.com/nektos/act), then retry.'
    fi
    # Verify install succeeded
    if ! command -v act >/dev/null 2>&1; then
        __blocked 'BLOCKED: act still not found after `setupmgr act`.
Install act manually (https://github.com/nektos/act), then retry.'
    fi
fi

# Validate each staged workflow file
FAILED_FILES=()
FAILED_OUTPUT=()

while IFS= read -r wf; do
    FULL_PATH="$PROJECT_DIR/$wf"
    [ -f "$FULL_PATH" ] || continue

    # timeout guards against an act hang freezing gitcommit forever
    OUTPUT="$(timeout 60 act --list -W "$FULL_PATH" 2>&1)" && STATUS=0 || STATUS=$?
    if [ "$STATUS" -eq 124 ]; then
        OUTPUT='act --list timed out after 60 seconds (failing closed)'
    fi
    if [ "$STATUS" -ne 0 ]; then
        FAILED_FILES+=("$wf")
        FAILED_OUTPUT+=("$OUTPUT")
    fi
done <<< "$STAGED_WORKFLOWS"

[ "${#FAILED_FILES[@]}" -eq 0 ] && exit 0

MSG='BLOCKED: GitHub Actions workflow validation failed.

The following staged workflow files did not pass `act --list`:
'
for i in "${!FAILED_FILES[@]}"; do
    MSG="${MSG}
  ${FAILED_FILES[$i]}
$(printf '%s\n' "${FAILED_OUTPUT[$i]}" | sed 's/^/    /')
"
done

MSG="${MSG}
Fix the errors above, then re-run gitcommit."
__blocked "$MSG"
