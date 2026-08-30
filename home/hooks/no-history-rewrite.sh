#!/usr/bin/env bash
# shellcheck shell=bash
# - - - - - - - - - - - - - - - - - - - - - - - - -
##@Version           :  202608302319-git
# @@Author           :  Jason Hempstead
# @@Contact          :  git-admin@casjaysdev.pro
# @@License          :  WTFPL
# @@ReadME           :  no-history-rewrite.sh --help
# @@Copyright        :  Copyright: (c) 2026 Jason Hempstead, Casjays Developments
# @@Created          :  Sunday, August 30, 2026 16:00 EDT
# @@File             :  no-history-rewrite.sh
# @@Description      :  PreToolUse hook: blocks git clean -f*/rebase/branch -D/tag -d/filter-repo/filter-branch everywhere — a hook can only block, not interactively confirm.
# @@Changelog        :  Narrowed git tag delete matching to -d/--delete only (was matching -D like branch delete); documented the git clean -fn dry-run carve-out.
# @@TODO             :  None
# @@Other            :  git rebase --abort/--continue/--skip are exempt — they resolve an already-started rebase rather than starting a new history rewrite.
# @@Resource         :  CLAUDE.md - Local System Management Zone - "Still hard - no exception, ever"
# @@Terminal App     :  no
# @@sudo/root        :  no
# @@Template         :  shell/bash
# - - - - - - - - - - - - - - - - - - - - - - - - -
# shellcheck disable=SC1001,SC1003,SC2001,SC2003,SC2016,SC2031,SC2090,SC2115,SC2120,SC2155,SC2199,SC2229,SC2317,SC2329
# - - - - - - - - - - - - - - - - - - - - - - - - -
VERSION="202608302319-git"
# - - - - - - - - - - - - - - - - - - - - - - - - -
set -euo pipefail

# A broken hook must fail OPEN (exit 0) so it never silently blocks every Bash call.
if ! command -v python3 >/dev/null 2>&1; then
  printf 'no-history-rewrite.sh: required command not found: python3 (hook disabled, failing open)\n' >&2
  exit 0
fi

NO_HISTORY_REWRITE_INPUT="$(cat)"

NO_HISTORY_REWRITE_HOOK_INPUT="$NO_HISTORY_REWRITE_INPUT" python3 - <<'PYEOF'
import json
import os
import re
import shlex
import sys

raw = os.environ.get("NO_HISTORY_REWRITE_HOOK_INPUT", "")
try:
    payload = json.loads(raw, strict=False)
except json.JSONDecodeError:
    sys.exit(0)

if payload.get("tool_name", "") != "Bash":
    sys.exit(0)

cmd = payload.get("tool_input", {}).get("command", "")
if not cmd:
    sys.exit(0)

HEREDOC_SHELLS = {"bash", "sh", "zsh", "dash", "ksh", "mksh", "ash"}
HEREDOC_CONTAINER_TOOLS = {"docker", "docker-compose", "podman", "podman-compose",
                           "kubectl", "incus", "lxc", "machinectl", "systemd-nspawn",
                           "vagrant", "multipass", "distrobox", "toolbox", "virsh",
                           "nsenter", "chroot"}


def strip_heredoc_bodies(text):
    # Non-shell heredoc bodies are data, not commands - drop them before scanning
    # so a cat/tee/python3 heredoc that merely MENTIONS a blocked command is not a
    # false positive. Bodies fed to a host shell (bash <<EOF) stay fully scanned;
    # container/VM-mediated shells (docker exec -i c bash <<EOF) are exempt - the
    # body runs inside the disposable guest. Fails open to the original text on
    # any parse error so scanning never silently weakens.
    try:
        out = []
        lines = text.split("\n")
        i = 0
        while i < len(lines):
            line = lines[i]
            out.append(line)
            delims = []
            for m in re.finditer(r"(?<!<)<<(?!<)-?\s*(['\"]?)(\w+)\1", line):
                head = {t.rsplit("/", 1)[-1].lstrip("\\") for t in line[: m.start()].split()}
                if head & HEREDOC_CONTAINER_TOOLS or not (head & HEREDOC_SHELLS):
                    delims.append(m.group(2))
            i += 1
            for delim in delims:
                while i < len(lines):
                    if lines[i].strip() == delim:
                        out.append(lines[i])
                        i += 1
                        break
                    i += 1
        return "\n".join(out)
    except Exception:
        return text


cmd = strip_heredoc_bodies(cmd)

# Cheap pre-filter: nothing resembling git/filter-repo anywhere -> allow.
if not re.search(r"\bgit\b|\bfilter-repo\b|\bfilter-branch\b", cmd):
    sys.exit(0)


def has_force_flag(tokens):
    for tok in tokens:
        if tok in ("-f", "--force"):
            return True
        if re.match(r"^-[a-zA-Z]*f[a-zA-Z]*$", tok):
            return True
    return False


def has_tag_delete_flag(tokens):
    # git tag has no -D form (only git branch does) — CLAUDE.md's
    # Local System Management Zone names only `git tag -d`. Matching
    # lowercase -d/--delete (and combined flags carrying lowercase d)
    # only, mirroring the branch-delete matcher's exact-flag precision.
    for tok in tokens:
        if tok in ("-d", "--delete"):
            return True
        if re.match(r"^-[a-zA-Z]*d[a-zA-Z]*$", tok):
            return True
    return False


# `git clean -fn`/`-f --dry-run` never deletes anything — it only lists what
# would be removed — so it carries none of the irreversible-data-loss risk
# CLAUDE.md's Verification & Safety section gates on; exempting it here is a
# deliberate carve-out, not a gap in the "git clean -f* blocked everywhere"
# rule (AI.md's no-history-rewrite.sh row, CLAUDE.md's Local System
# Management Zone "Still hard" list).
def is_dry_run(tokens):
    return any(tok in ("-n", "--dry-run") for tok in tokens)


GIT_GLOBAL_OPTS_WITH_VALUE = {"-C", "-c", "--git-dir", "--work-tree", "--namespace", "--exec-path"}


def find_git_subcommand(rest):
    # First non-flag token, skipping the VALUE of any global option that
    # takes one (-C <path>, -c <k>=<v>, --git-dir <path>, etc.) so
    # `git -C /repo rebase` cannot hide its subcommand from the scan.
    i = 0
    while i < len(rest):
        tok = rest[i]
        if tok in GIT_GLOBAL_OPTS_WITH_VALUE:
            i += 2
            continue
        if tok.startswith("-"):
            i += 1
            continue
        return tok, i
    return None, -1


def violation(clean_tokens):
    # Expects argv of one sub-command with wrapper/env prefixes already stripped.
    if not clean_tokens:
        return None

    if clean_tokens[0] in ("filter-repo", "git-filter-repo"):
        return "filter-repo rewrites every commit in history"

    if clean_tokens[0] != "git":
        return None

    rest = clean_tokens[1:]
    sub, sub_idx = find_git_subcommand(rest)
    if sub is None:
        return None
    args = rest[sub_idx + 1:]

    if sub == "clean":
        if has_force_flag(args) and not is_dry_run(args):
            return "git clean -f discards untracked files irreversibly"
        return None

    if sub == "rebase":
        if any(a in ("--abort", "--continue", "--skip") for a in args):
            return None
        return "git rebase rewrites commit history"

    if sub == "branch":
        for a in args:
            if a == "-D" or re.match(r"^-[a-zA-Z]*D[a-zA-Z]*$", a):
                return "git branch -D force-deletes a branch, possibly losing unmerged commits"
        return None

    if sub == "tag":
        if has_tag_delete_flag(args):
            return "git tag -d deletes a tag pointer"
        return None

    if sub == "filter-branch":
        return "filter-branch rewrites every commit in history"

    if sub == "filter-repo":
        return "filter-repo rewrites every commit in history"

    return None


# Examine each sub-command independently; newlines are separators too,
# so multi-line commands cannot hide a violation on line 2+.
for sub_cmd in re.split(r"[\n;]|&&|\|\||[|&]", cmd):
    sub_cmd = sub_cmd.strip()
    if not sub_cmd:
        continue
    try:
        tokens = shlex.split(sub_cmd)
    except ValueError:
        tokens = sub_cmd.split()

    # Strip wrapper/alias-bypass prefixes and env assignments (any case):
    # \git, command git, env [KEY=VAL...] git, KEY=VAL git
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

    reason = violation(clean)
    if reason:
        msg = (
            f"BLOCKED: history-rewriting/destructive git operation ({reason}).\n\n"
            "git clean -f*, git rebase, git branch -D, git tag -d, git filter-repo,\n"
            "and git filter-branch all discard commits/work or rewrite history, so\n"
            "they require explicit user confirmation before ever running - even\n"
            "inside the Local System Management Zone, where raw git is otherwise\n"
            "pre-authorized (see CLAUDE.md's zone section, \"Still hard\" list).\n\n"
            "Ask the user to confirm, then have them run the command manually -\n"
            "this hook cannot grant a one-time exception."
        )
        print(msg)
        sys.stderr.write(msg + "\n")
        sys.exit(2)

sys.exit(0)
PYEOF
