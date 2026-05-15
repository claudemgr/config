#!/usr/bin/env bash
# no-force-push.sh — PreToolUse hook (Bash)
# Blocks any `git push --force` or `git push -f` invocation.
# Only `gitcommit` is the sanctioned push path; force-pushing rewrites
# remote history and bypasses the signed-commit workflow.
#
# Exit codes:
#   0 = allow
#   2 = block (message sent to Claude as context)

set -euo pipefail

INPUT="$(cat)"

# Extract the command string from the JSON input
CMD="$(printf '%s' "$INPUT" | python3 -c "
import sys, json
data = json.load(sys.stdin)
inp = data.get('tool_input', data.get('input', {}))
print(inp.get('command', ''))
" 2>/dev/null || true)"

[ -z "$CMD" ] && exit 0

# Split on pipe, semicolon, &&, || to check each sub-command
IFS='|;&' read -ra PARTS <<< "$CMD"

for part in "${PARTS[@]}"; do
    # Trim leading whitespace and env var assignments (KEY=VAL ...)
    clean="$(printf '%s' "$part" | sed 's/^[[:space:]]*//' | sed 's/^[A-Z_][A-Z0-9_]*=[^ ]* *//')"

    # Only inspect commands starting with 'git'
    first_word="$(printf '%s' "$clean" | awk '{print $1}')"
    [ "$first_word" != "git" ] && continue

    # Check for force-push flags in this git invocation
    if printf '%s' "$clean" | grep -qE '\bgit\b.*\bpush\b.*(\s--force\b|\s-f\b)'; then
        printf 'BLOCKED: `git push --force` (and `git push -f`) are forbidden.\n'
        printf 'Force-pushing rewrites remote history, bypasses signed commits, and may\n'
        printf 'destroy collaborators'\''s history.\n\n'
        printf 'The only sanctioned commit+push path is:\n'
        printf '  gitcommit --dir {project_dir} all\n\n'
        printf 'If a force-push is genuinely required (e.g. to fix a bad merge on a\n'
        printf 'personal branch), ask the user to run it manually.\n'
        exit 2
    fi
done

exit 0
