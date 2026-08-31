#!/usr/bin/env bash
# shellcheck shell=bash
# - - - - - - - - - - - - - - - - - - - - - - - - -
##@Version           :  202608302400-git
# @@Author           :  Jason Hempstead
# @@Contact          :  git-admin@casjaysdev.pro
# @@License          :  WTFPL
# @@ReadME           :  test-lint-mark.sh --help
# @@Copyright        :  Copyright: (c) 2026 Jason Hempstead, Casjays Developments
# @@Created          :  Sunday, August 30, 2026 22:00 EDT
# @@File             :  test-lint-mark.sh
# @@Description      :  PostToolUse Bash hook: records per session/project that a test-gate or lint-gate command exited 0, pairing with enforce-test-lint-gate.sh.
# @@Changelog        :  Marker dir moved to claudemgr/config/test-lint-guard per tempdir_conventions.md's namespacing rule.
# @@TODO             :  None
# @@Other              :  Only marks on exit_code == 0 and interrupted == false — a failed or timed-out run must never count as passing.
# @@Resource         :  CLAUDE.md - Commit Workflow (Test gate, Lint gate), home/hooks/spec-guard-mark.sh
# @@Terminal App     :  no
# @@sudo/root        :  no
# @@Template         :  shell/bash
# - - - - - - - - - - - - - - - - - - - - - - - - -
# shellcheck disable=SC1001,SC1003,SC2001,SC2003,SC2016,SC2031,SC2090,SC2115,SC2120,SC2155,SC2199,SC2229,SC2317,SC2329
# - - - - - - - - - - - - - - - - - - - - - - - - -
VERSION="202608302400-git"
# - - - - - - - - - - - - - - - - - - - - - - - - -
set -euo pipefail

# Fail open when jq is missing — a broken hook must never crash the tool run
if ! command -v jq >/dev/null 2>&1; then
  printf 'test-lint-mark.sh: jq not found — test/lint mark disabled\n' >&2
  exit 0
fi

# $(cat) is required here — hook stdin is a socket; $(</dev/stdin) re-opens it and fails with ENXIO
TEST_LINT_MARK_INPUT="$(cat)"

TEST_LINT_MARK_TOOL=$(printf '%s' "$TEST_LINT_MARK_INPUT" | jq -r '.tool_name // ""')
[ "$TEST_LINT_MARK_TOOL" = "Bash" ] || exit 0

TEST_LINT_MARK_EXIT=$(printf '%s' "$TEST_LINT_MARK_INPUT" | jq -r '.tool_response.exit_code // 1')
TEST_LINT_MARK_INTERRUPTED=$(printf '%s' "$TEST_LINT_MARK_INPUT" | jq -r '.tool_response.interrupted // false')
[ "$TEST_LINT_MARK_EXIT" = "0" ] || exit 0
[ "$TEST_LINT_MARK_INTERRUPTED" = "false" ] || exit 0

TEST_LINT_MARK_CMD=$(printf '%s' "$TEST_LINT_MARK_INPUT" | jq -r '.tool_input.command // ""')
TEST_LINT_MARK_CWD=$(printf '%s' "$TEST_LINT_MARK_INPUT" | jq -r '.cwd // ""')
TEST_LINT_MARK_SESSION_ID=$(printf '%s' "$TEST_LINT_MARK_INPUT" | jq -r '.session_id // ""')
[ -z "$TEST_LINT_MARK_CMD" ] && exit 0
[ -z "$TEST_LINT_MARK_SESSION_ID" ] && exit 0

TEST_LINT_MARK_IS_TEST=0
TEST_LINT_MARK_IS_LINT=0
TEST_LINT_MARK_IS_BASHN=0
printf '%s' "$TEST_LINT_MARK_CMD" | grep -qE -- '\bmake[[:space:]]+test\b|\bgo[[:space:]]+test\b|\bcargo[[:space:]]+test\b|\bpytest\b|\bnpm[[:space:]]+(run[[:space:]]+)?test\b' \
  && TEST_LINT_MARK_IS_TEST=1
printf '%s' "$TEST_LINT_MARK_CMD" | grep -qE -- '\bbash[[:space:]]+-n\b' \
  && TEST_LINT_MARK_IS_BASHN=1
printf '%s' "$TEST_LINT_MARK_CMD" | grep -qE -- '\bscript-lint\b|\bgo-lint\b|\brust-lint\b' \
  && TEST_LINT_MARK_IS_LINT=1

[ "$TEST_LINT_MARK_IS_TEST" = "1" ] || [ "$TEST_LINT_MARK_IS_BASHN" = "1" ] || [ "$TEST_LINT_MARK_IS_LINT" = "1" ] || exit 0

TEST_LINT_MARK_PROJECT=$(git -C "${TEST_LINT_MARK_CWD:-.}" rev-parse --show-toplevel 2>/dev/null) \
  || TEST_LINT_MARK_PROJECT="$TEST_LINT_MARK_CWD"
[ -z "$TEST_LINT_MARK_PROJECT" ] && exit 0
# Normalize the same way enforce-test-lint-gate.sh's reader normalizes its
# --dir lookup key (Python os.path.realpath) — without this, a marker
# written under a symlinked/un-normalized path never matches the reader's
# realpath'd key and the gate falsely reports the test/lint gate as unrun.
TEST_LINT_MARK_PROJECT=$(realpath -- "$TEST_LINT_MARK_PROJECT" 2>/dev/null) || :

# `bash -n` only satisfies the test gate for script-collection projects
# (home/CLAUDE.md's Test gate line) — a project with a real test runner
# (go.mod/Cargo.toml/package.json/pyproject.toml, project_type_conventions.md's
# authoritative manifest set) must not have its test gate satisfied by
# syntax-checking an unrelated script.
if [ "$TEST_LINT_MARK_IS_BASHN" = "1" ] && [ "$TEST_LINT_MARK_IS_TEST" != "1" ]; then
  TEST_LINT_MARK_IS_SCRIPT_COLLECTION=1
  for TEST_LINT_MARK_MANIFEST in go.mod Cargo.toml package.json pyproject.toml; do
    [ -f "$TEST_LINT_MARK_PROJECT/$TEST_LINT_MARK_MANIFEST" ] && TEST_LINT_MARK_IS_SCRIPT_COLLECTION=0 && break
  done
  if [ "$TEST_LINT_MARK_IS_SCRIPT_COLLECTION" = "1" ]; then
    TEST_LINT_MARK_IS_TEST=1
  fi
fi
[ "$TEST_LINT_MARK_IS_TEST" = "1" ] || [ "$TEST_LINT_MARK_IS_LINT" = "1" ] || exit 0

# tempdir_conventions.md's mandated shape is {project_org}/{internal_name}-XXXXXX,
# but the -XXXXXX random mktemp suffix is for one-shot unique dirs; this marker
# must be a deterministic, reconstructable path so enforce-test-lint-gate.sh's
# reader can look it up again by session_id alone. session_id already serves
# the uniqueness role -XXXXXX would, so it replaces that suffix here while
# still satisfying the org/internal_name namespacing the rule requires
# (IDEA.md: internal_org=claudemgr, internal_name=config).
TEST_LINT_MARK_DIR="${TMPDIR:-/tmp}/claudemgr/config/test-lint-guard/${TEST_LINT_MARK_SESSION_ID}"
mkdir -p "$TEST_LINT_MARK_DIR"
chmod 700 "${TMPDIR:-/tmp}/claudemgr/config/test-lint-guard" "$TEST_LINT_MARK_DIR" 2>/dev/null || true

# Prune marker dirs older than 1 day — scoped only to this tool's own temp namespace
find "${TMPDIR:-/tmp}/claudemgr/config/test-lint-guard" -maxdepth 1 -type d -mtime +1 -exec rm -rf -- {} + 2>/dev/null || true

if [ "$TEST_LINT_MARK_IS_TEST" = "1" ]; then
  TEST_LINT_MARK_TEST_MARKER="$TEST_LINT_MARK_DIR/test"
  grep -qxF -- "$TEST_LINT_MARK_PROJECT" "$TEST_LINT_MARK_TEST_MARKER" 2>/dev/null \
    || printf '%s\n' "$TEST_LINT_MARK_PROJECT" >>"$TEST_LINT_MARK_TEST_MARKER"
fi

if [ "$TEST_LINT_MARK_IS_LINT" = "1" ]; then
  TEST_LINT_MARK_LINT_MARKER="$TEST_LINT_MARK_DIR/lint"
  grep -qxF -- "$TEST_LINT_MARK_PROJECT" "$TEST_LINT_MARK_LINT_MARKER" 2>/dev/null \
    || printf '%s\n' "$TEST_LINT_MARK_PROJECT" >>"$TEST_LINT_MARK_LINT_MARKER"
fi

exit 0
