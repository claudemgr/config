#!/usr/bin/env bash
# shellcheck shell=bash
# - - - - - - - - - - - - - - - - - - - - - - - - -
##@Version           :  202608301555-git
# @@Author           :  Jason Hempstead
# @@Contact          :  git-admin@casjaysdev.pro
# @@License          :  MIT or LICENSE.md
# @@ReadME           :  no-history-rewrite.sh --help
# @@Copyright        :  Copyright: (c) 2026 Jason Hempstead, Casjays Developments
# @@Created          :  Sunday, August 30, 2026 16:00 EDT
# @@File             :  no-history-rewrite.sh
# @@Description      :  PreToolUse hook: block git clean -f*, rebase, branch -D, tag -d, filter-repo/filter-branch
# @@Description      :  everywhere, including the Local System Management Zone - these discard commits/work or
# @@Description      :  rewrite history, so CLAUDE.md requires user confirmation before ever running them, even
# @@Description      :  where the zone otherwise pre-authorizes raw git. A hook can only allow or block, not
# @@Description      :  interactively confirm, so - same pattern as no-force-push.sh - this hard-blocks and tells
# @@Description      :  the user to run the command manually once they have actually confirmed it.
# @@Changelog        :  Initial version - audit found these history-rewriting ops had zero technical enforcement,
# @@Changelog        :  only prose in CLAUDE.md's zone exclusion list
# @@Changelog        :  Fixed git -C/-c/--git-dir/etc. global-flag-value bypass in the subcommand
# @@Changelog        :  scan (same fix as zone-git-commit-push.sh)
# @@TODO             :  None
# @@Other            :  git rebase --abort/--continue/--skip are exempt - they resolve an already-started rebase
# @@Other            :  rather than starting a new history rewrite, and blocking them would trap the user with
# @@Other            :  no way out except manual intervention
# @@Resource         :  CLAUDE.md - Local System Management Zone - "Still hard - no exception, ever"
# @@Terminal App     :  no
# @@sudo/root        :  no
# @@Template         :  shell/bash
# - - - - - - - - - - - - - - - - - - - - - - - - -
# shellcheck disable=SC1001,SC1003,SC2001,SC2003,SC2016,SC2031,SC2090,SC2115,SC2120,SC2155,SC2199,SC2229,SC2317,SC2329
# - - - - - - - - - - - - - - - - - - - - - - - - -
VERSION="202608301555-git"
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


def has_delete_flag(tokens):
    for tok in tokens:
        if tok in ("-d", "-D", "--delete"):
            return True
        if re.match(r"^-[a-zA-Z]*[dD][a-zA-Z]*$", tok):
            return True
    return False


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
        if has_delete_flag(args):
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
            if tok in ("command", "env", "exec", "nohup", "time"):
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
