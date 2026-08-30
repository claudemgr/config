#!/usr/bin/env bash
# shellcheck shell=bash
# - - - - - - - - - - - - - - - - - - - - - - - - -
##@Version           :  202608301800-git
# @@Author           :  Jason Hempstead
# @@Contact          :  git-admin@casjaysdev.pro
# @@License          :  WTFPL
# @@ReadME           :  enforce-test-lint-gate.sh --help
# @@Copyright        :  Copyright: (c) 2026 Jason Hempstead, Casjays Developments
# @@Created          :  Sunday, August 30, 2026 22:00 EDT
# @@File             :  enforce-test-lint-gate.sh
# @@Description      :  PreToolUse Bash hook: blocks the commit wrapper's `--dir <path> all` form unless the test and lint gates ran and passed this session for that project.
# @@Changelog        :  Clarified the template-repo block message and fixed the ENXIO-prone /dev/stdin read to use $(cat).
# @@TODO             :  None
# @@Other            :  Pairs with test-lint-mark.sh's per-session markers; a project-type heuristic picks the test path (manifest, script-collection re-read, or *.md fallback).
# @@Resource         :  CLAUDE.md - Commit Workflow, home/hooks/test-lint-mark.sh, home/hooks/spec-guard.sh
# @@Terminal App     :  no
# @@sudo/root        :  no
# @@Template         :  shell/bash
# - - - - - - - - - - - - - - - - - - - - - - - - -
# shellcheck disable=SC1001,SC1003,SC2001,SC2003,SC2016,SC2031,SC2090,SC2115,SC2120,SC2155,SC2199,SC2229,SC2317,SC2329
# - - - - - - - - - - - - - - - - - - - - - - - - -
VERSION="202608301800-git"
# - - - - - - - - - - - - - - - - - - - - - - - - -
set -euo pipefail

if ! command -v python3 >/dev/null 2>&1; then
  printf 'enforce-test-lint-gate.sh: required command not found: python3 (hook disabled, failing open)\n' >&2
  exit 0
fi

# $(cat) is required here — hook stdin is a socket; $(</dev/stdin) re-opens it and fails with ENXIO
ENFORCE_TEST_LINT_GATE_INPUT="$(cat)"

ENFORCE_TEST_LINT_GATE_HOOK_INPUT="$ENFORCE_TEST_LINT_GATE_INPUT" python3 - <<'PYEOF'
import json
import os
import re
import shlex
import sys

raw = os.environ.get("ENFORCE_TEST_LINT_GATE_HOOK_INPUT", "")
try:
    payload = json.loads(raw, strict=False)
except json.JSONDecodeError:
    sys.exit(0)

if payload.get("tool_name", "") != "Bash":
    sys.exit(0)

cmd = payload.get("tool_input", {}).get("command", "")
session_id = payload.get("session_id", "")
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

marker_dir = os.path.join(os.environ.get("TMPDIR", "/tmp"), "claude-test-lint-guard", session_id)
spec_guard_marker = os.path.join(os.environ.get("TMPDIR", "/tmp"), "claude-spec-guard", session_id, "read")


def marked(marker_file, project):
    try:
        with open(marker_file) as f:
            return any(line.rstrip("\n") == project for line in f)
    except OSError:
        return False


def has_shell_scripts(root):
    skip = {".git", "node_modules", "vendor", ".venv", "target", "dist", "build"}
    depth_limit = root.rstrip(os.sep).count(os.sep) + 4
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = [d for d in dirnames if d not in skip]
        if dirpath.count(os.sep) > depth_limit:
            dirnames[:] = []
            continue
        if any(f.endswith(".sh") for f in filenames):
            return True
    return False


def is_spec_collection(root):
    manifests = ("Makefile", "go.mod", "Cargo.toml", "package.json", "pyproject.toml", "setup.py")
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

    missing = []
    if not marked(os.path.join(marker_dir, "test"), project):
        missing.append("test gate")
    if not marked(os.path.join(marker_dir, "lint"), project):
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
