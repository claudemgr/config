#!/usr/bin/env bash
# shellcheck shell=bash
# - - - - - - - - - - - - - - - - - - - - - - - - -
##@Version           :  202609020139-git
# @@Author           :  Jason Hempstead
# @@Contact          :  git-admin@casjaysdev.pro
# @@License          :  WTFPL
# @@ReadME           :  enforce-test-lint-gate.sh --help
# @@Copyright        :  Copyright: (c) 2026 Jason Hempstead, Casjays Developments
# @@Created          :  Sunday, August 30, 2026 22:00 EDT
# @@File             :  enforce-test-lint-gate.sh
# @@Description      :  PreToolUse Bash hook: blocks the commit wrapper's `--dir <path> all` form unless the test and lint gates ran and passed this session for that project.
# @@Changelog        :  Normalizes every documented-string payload field, so a list/numeric command, cwd or file_path fails open instead of raising TypeError.
# @@TODO             :  None
# @@Other            :  Pairs with test-lint-mark.sh's per-session markers; a project-type heuristic picks the test path (manifest, script-collection re-read, or *.md fallback).
# @@Resource         :  CLAUDE.md - Commit Workflow, home/hooks/test-lint-mark.sh, home/hooks/spec-guard.sh
# @@Terminal App     :  no
# @@sudo/root        :  no
# @@Template         :  shell/bash
# - - - - - - - - - - - - - - - - - - - - - - - - -
# shellcheck disable=SC1001,SC1003,SC2001,SC2003,SC2016,SC2031,SC2090,SC2115,SC2120,SC2155,SC2199,SC2229,SC2317,SC2329
# - - - - - - - - - - - - - - - - - - - - - - - - -
VERSION="202609020139-git"
# - - - - - - - - - - - - - - - - - - - - - - - - -
set -euo pipefail

if ! command -v python3 >/dev/null 2>&1; then
  printf 'enforce-test-lint-gate.sh: required command not found: python3 (hook disabled, failing open)\n' >&2
  exit 0
fi

# $(cat) is required here — hook stdin is a socket; $(</dev/stdin) re-opens it and fails with ENXIO
ENFORCE_TEST_LINT_GATE_INPUT="$(cat)"

ENFORCE_TEST_LINT_GATE_INPUT_TMPFILE="$(mktemp)"
trap 'rm -f "$ENFORCE_TEST_LINT_GATE_INPUT_TMPFILE"' EXIT
printf '%s' "$ENFORCE_TEST_LINT_GATE_INPUT" > "$ENFORCE_TEST_LINT_GATE_INPUT_TMPFILE"

python3 - "$ENFORCE_TEST_LINT_GATE_INPUT_TMPFILE" <<'PYEOF'
import json
import os
import re
import shlex
import sys

with open(sys.argv[1], "r") as _f:
    raw = _f.read()
try:
    payload = json.loads(raw, strict=False)
except json.JSONDecodeError:
    sys.exit(0)

# A JSON scalar or array parses cleanly but has no .get(), so the block
# below would raise AttributeError and exit non-zero. Part 6 requires a
# hook to fail open on any unusable payload, never to surface an error.
if not isinstance(payload, dict):
    sys.exit(0)

# Same reasoning one level down: normalise a non-object tool_input /
# tool_response to an empty dict so every downstream .get() chain below
# stays safe without each call site needing its own type check.
for _field in ("tool_input", "tool_response"):
    if _field in payload and not isinstance(payload[_field], dict):
        payload[_field] = {}

# Every field below is documented as a string but arrives as arbitrary JSON.
# A list `command` or a numeric `cwd` reaches a str-only call (.split(),
# .startswith(), os.path.*) and raises TypeError -> exit 1, which Claude Code
# reports as a hook error on an ordinary tool call. Drop any non-string value
# so the hook no-ops on it instead, per Part 6's "Fail open, always".
for _obj in (payload, payload.get("tool_input") or {}, payload.get("tool_response") or {}):
    for _key in ("command", "file_path", "cwd", "session_id", "transcript_path",
                 "content", "new_string", "old_string", "pattern", "path",
                 "agent_type", "last_assistant_message"):
        if _key in _obj and not isinstance(_obj[_key], str):
            _obj[_key] = ""

if payload.get("tool_name", "") != "Bash":
    sys.exit(0)

cmd = payload.get("tool_input", {}).get("command", "")
session_id = payload.get("session_id", "")
transcript_path = payload.get("transcript_path", "")
if not cmd or not session_id or not re.search(r"\bgitcommit\b", cmd):
    sys.exit(0)


def find_gitcommit_dir(text):
    # Only the valid `gitcommit --dir <path> all` shape carries a --dir path -
    # malformed shapes are already blocked by enforce-gitcommit-shape.sh.
    for sub_cmd in re.split(r"[\n;]|&&|\|\||[|&]", text):
        sub_cmd = sub_cmd.strip()
        if not sub_cmd:
            continue
        try:
            tokens = shlex.split(sub_cmd)
        except ValueError:
            tokens = sub_cmd.split()

        clean = []
        skipping_prefix = True
        for tok in tokens:
            if skipping_prefix:
                if tok in ("command", "env", "exec", "nohup", "time", "sudo", "doas"):
                    continue
                if re.match(r"^[A-Za-z_][A-Za-z0-9_]*=", tok):
                    continue
                if tok.startswith("-"):
                    continue
                skipping_prefix = False
            clean.append(tok.lstrip("\\"))

        if len(clean) == 4 and clean[0] == "gitcommit" and clean[1] == "--dir" and clean[3] == "all":
            yield clean[2]


targets = list(find_gitcommit_dir(cmd))
if not targets:
    sys.exit(0)

# Must match the deterministic path test-lint-mark.sh/lint-agent-mark.sh
# write (see those files' comments for why this deviates from
# tempdir_conventions.md's -XXXXXX mktemp-suffix pattern: session_id is
# the lookup key here, so it takes the uniqueness role -XXXXXX would).
#
# `or "/tmp"` rather than a get() default: the writers use bash's
# ${TMPDIR:-/tmp}, which also falls back when TMPDIR is set but EMPTY.
# os.environ.get("TMPDIR", "/tmp") returns "" in that case, making these
# paths relative to the cwd — the reader would then never find markers the
# writers put in /tmp, permanently false-blocking every gitcommit.
tmp_root = os.environ.get("TMPDIR") or "/tmp"
marker_dir = os.path.join(tmp_root, "claude-hooks", "test-lint-guard", session_id)
spec_guard_marker = os.path.join(tmp_root, "claude-hooks", "spec-guard", session_id, "read")


def marked(marker_file, project):
    try:
        with open(marker_file) as f:
            return any(line.rstrip("\n") == project for line in f)
    except OSError:
        return False


# Fallback for the confirmed upstream bug (anthropics/claude-code#36310,
# open): PostToolUse on Bash sometimes never spawns, so test-lint-mark.sh's
# marker is never written even though the command genuinely passed.
# transcript_path (documented in Claude Code's hook payload) is written by
# the CLI itself, independent of PostToolUse firing, so scanning it directly
# gives a reliable second signal that a Bash command ran and passed this
# session. This only runs when the command already matched `gitcommit`
# above, so it never adds cost to ordinary Bash calls.
TEST_CMD_RE = re.compile(
    r"\bmake\s+test\b|\bgo\s+test\b|\bcargo\s+test\b|\bpytest\b|\bnpm\s+(run\s+)?test\b"
)
BASHN_RE = re.compile(r"\bbash\s+-n\b")
LINT_CMD_RE = re.compile(r"\bscript-lint\b|\bgo-lint\b|\brust-lint\b")


def transcript_pass(transcript_path, project, allow_bashn_as_test):
    if not transcript_path or not os.path.isfile(transcript_path):
        return False, False
    tool_use_cmds = {}
    test_ok = False
    lint_ok = False
    try:
        with open(transcript_path, errors="ignore") as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    entry = json.loads(line)
                except json.JSONDecodeError:
                    continue
                if not isinstance(entry, dict):
                    continue
                etype = entry.get("type")
                # "message" (and its "content") can legitimately be null or a
                # non-list in some transcript entries (e.g. summary/system
                # lines) - .get()'s default only covers a MISSING key, not a
                # present null, so each level is defensively re-checked
                # rather than trusting the transcript's shape (reproduced
                # AttributeError: 'NoneType' object has no attribute 'get').
                if etype == "assistant":
                    msg = entry.get("message")
                    content = msg.get("content") if isinstance(msg, dict) else None
                    for c in content or []:
                        if not isinstance(c, dict):
                            continue
                        if c.get("type") == "tool_use" and c.get("name") == "Bash":
                            inp = c.get("input")
                            cmd_ = inp.get("command", "") if isinstance(inp, dict) else ""
                            if cmd_:
                                tool_use_cmds[c.get("id")] = cmd_
                elif etype == "user":
                    entry_cwd = entry.get("cwd", "")
                    try:
                        entry_project = os.path.realpath(entry_cwd) if entry_cwd else ""
                    except OSError:
                        entry_project = ""
                    if entry_project != project:
                        continue
                    tur = entry.get("toolUseResult") or {}
                    if not isinstance(tur, dict):
                        tur = {}
                    if tur.get("interrupted"):
                        continue
                    msg = entry.get("message")
                    content = msg.get("content") if isinstance(msg, dict) else None
                    for c in content or []:
                        if not isinstance(c, dict):
                            continue
                        if c.get("type") != "tool_result" or c.get("is_error"):
                            continue
                        cmd_ = tool_use_cmds.get(c.get("tool_use_id"))
                        if not cmd_:
                            continue
                        if TEST_CMD_RE.search(cmd_):
                            test_ok = True
                        if allow_bashn_as_test and BASHN_RE.search(cmd_):
                            test_ok = True
                        if LINT_CMD_RE.search(cmd_):
                            lint_ok = True
    except OSError:
        return False, False
    return test_ok, lint_ok


def has_shell_scripts(root):
    # project_type_conventions.md's spec-collection rule scans "anywhere in
    # its tree", unqualified — no depth limit. A bare deploy-only install.sh
    # at the project root does not disqualify spec-collection on its own;
    # any *.sh/*.bash file elsewhere in the tree does.
    skip = {".git", "node_modules", "vendor", ".venv", "target", "dist", "build"}
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = [d for d in dirnames if d not in skip]
        for f in filenames:
            if not f.endswith((".sh", ".bash")):
                continue
            if dirpath == root and f == "install.sh":
                continue
            return True
    return False


def is_spec_collection(root):
    # Authoritative manifest set from project_type_conventions.md's
    # script-collection detection signals: go.mod/Cargo.toml/package.json/
    # pyproject.toml only — Makefile/setup.py are not part of that list.
    manifests = ("go.mod", "Cargo.toml", "package.json", "pyproject.toml")
    if any(os.path.isfile(os.path.join(root, m)) for m in manifests):
        return False
    return not has_shell_scripts(root)


blocked = []
for target in targets:
    project = os.path.realpath(os.path.expanduser(target))
    if not os.path.isdir(project):
        continue

    if is_spec_collection(project):
        if not marked(spec_guard_marker, project):
            blocked.append(
                f"{project}: spec-collection project — AI.md/SPEC.md (or, for a template repo with "
                f"neither, its root-level *.md spec file) has not been re-read this session "
                f"(CLAUDE.md's substitute for a test runner here)."
            )
        continue

    manifests_present = any(
        os.path.isfile(os.path.join(project, m))
        for m in ("go.mod", "Cargo.toml", "package.json", "pyproject.toml")
    )
    transcript_test_ok, transcript_lint_ok = transcript_pass(
        transcript_path, project, allow_bashn_as_test=not manifests_present
    )

    missing = []
    if not marked(os.path.join(marker_dir, "test"), project) and not transcript_test_ok:
        missing.append("test gate")
    # Only Go/Rust/shell have a defined lint agent (go-lint/rust-lint/
    # script-lint) — a Node- or Python-only project (package.json/
    # pyproject.toml, no go.mod/Cargo.toml/*.sh) has no lint gate the spec
    # defines, so requiring one here is an unsatisfiable deadlock.
    has_defined_lint_target = (
        os.path.isfile(os.path.join(project, "go.mod"))
        or os.path.isfile(os.path.join(project, "Cargo.toml"))
        or has_shell_scripts(project)
    )
    if (
        has_defined_lint_target
        and not marked(os.path.join(marker_dir, "lint"), project)
        and not transcript_lint_ok
    ):
        missing.append("lint gate")
    if missing:
        blocked.append(f"{project}: {' and '.join(missing)} has not run (and passed) this session")

if not blocked:
    sys.exit(0)

msg_lines = ["BLOCKED: gitcommit requires the test/lint gate to have run and passed this session.\n"]
for b in blocked:
    msg_lines.append(f"  - {b}")
msg_lines.append("")
msg_lines.append(
    "Run the project's test gate (make test / go test ./... / cargo test / pytest /\n"
    "npm test / bash -n for script-collection) and lint gate (script-lint / go-lint /\n"
    "rust-lint — run via the Agent tool, not `make lint`) first, then retry gitcommit."
)
msg = "\n".join(msg_lines)
print(msg)
sys.stderr.write(msg + "\n")
sys.exit(2)
PYEOF
