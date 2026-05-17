#!/usr/bin/env bash
# validate-workflows.sh — PreToolUse hook (Bash)
# When gitcommit is invoked, checks whether any .github/workflows/ files
# are staged. If so, validates each one with `act --list` before allowing
# the commit through. A broken workflow is caught here — never on GitHub.
#
# If act is not installed, runs `setupmgr act` to install it first.
#
# Exit codes:
#   0 = allow
#   2 = block (message sent to Claude as context)

set -euo pipefail

INPUT="$(cat)"

CMD="$(printf '%s' "$INPUT" | python3 -c "
import sys, json
data = json.load(sys.stdin)
inp = data.get('tool_input', data.get('input', {}))
print(inp.get('command', ''))
" 2>/dev/null || true)"

[ -z "$CMD" ] && exit 0

# Only fire on gitcommit invocations
printf '%s' "$CMD" | grep -qE '\bgitcommit\b' || exit 0

# Extract --dir argument value
PROJECT_DIR="$(printf '%s' "$CMD" | grep -oE -- '--dir[[:space:]]+[^[:space:]]+' | awk '{print $2}' || true)"
[ -z "$PROJECT_DIR" ] && exit 0
[ -d "$PROJECT_DIR" ] || exit 0

# Check if any .github/workflows/ YAML files are staged
STAGED_WORKFLOWS="$(git -C "$PROJECT_DIR" diff --cached --name-only 2>/dev/null \
    | grep -E '^\.github/workflows/.*\.ya?ml$' || true)"
[ -z "$STAGED_WORKFLOWS" ] && exit 0

# Ensure act is available; install via setupmgr if missing
if ! command -v act >/dev/null 2>&1; then
    printf 'act not found — installing via setupmgr act...\n' >&2
    if ! setupmgr act >&2 2>&1; then
        printf 'BLOCKED: act is required to validate workflow files before committing.\n'
        printf 'Automatic install via `setupmgr act` failed.\n'
        printf 'Install act manually (https://github.com/nektos/act), then retry.\n'
        exit 2
    fi
    # Verify install succeeded
    if ! command -v act >/dev/null 2>&1; then
        printf 'BLOCKED: act still not found after `setupmgr act`.\n'
        printf 'Install act manually (https://github.com/nektos/act), then retry.\n'
        exit 2
    fi
fi

# Validate each staged workflow file
FAILED_FILES=()
FAILED_OUTPUT=()

while IFS= read -r wf; do
    FULL_PATH="$PROJECT_DIR/$wf"
    [ -f "$FULL_PATH" ] || continue

    OUTPUT="$(act --list -W "$FULL_PATH" 2>&1)" && STATUS=0 || STATUS=$?
    if [ "$STATUS" -ne 0 ]; then
        FAILED_FILES+=("$wf")
        FAILED_OUTPUT+=("$OUTPUT")
    fi
done <<< "$STAGED_WORKFLOWS"

[ "${#FAILED_FILES[@]}" -eq 0 ] && exit 0

printf 'BLOCKED: GitHub Actions workflow validation failed.\n\n'
printf 'The following staged workflow files did not pass `act --list`:\n\n'

for i in "${!FAILED_FILES[@]}"; do
    printf '  %s\n' "${FAILED_FILES[$i]}"
    printf '%s\n' "${FAILED_OUTPUT[$i]}" | sed 's/^/    /'
    printf '\n'
done

printf 'Fix the errors above, then re-run gitcommit.\n'
exit 2
