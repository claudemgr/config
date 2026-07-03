#!/usr/bin/env bash
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
##@Version           :  202607031823-git
# @@Author           :  Jason Hempstead
# @@Contact          :  git-admin@casjaysdev.pro
# @@ReadME           :  protect-host.sh --help
# @@Copyright        :  Copyright: (c) 2026 Jason Hempstead, Casjays Developments
# @@Created          :  Friday, May 01, 2026 10:22 EDT
# @@File             :  protect-host.sh
# @@Description      :  Claude Code PreToolUse hook - block truly destructive Bash ops on host
# @@Changelog        :  Rule 11 — block unscoped container/instance sweeps (docker/podman ps, incus/lxc list feeding kill/stop/rm/delete; prune)
# @@TODO             :  See project issues
# @@Other            :  Container-mediated commands (docker/incus/podman/kubectl exec) are exempted
# @@Resource         :  github.com/casapps/claude-code-hooks
# @@Terminal App     :  no
# @@sudo/root        :  no
# @@Template         :  bash/simple
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# shellcheck disable=SC1001,SC1003,SC2001,SC2003,SC2016,SC2031,SC2090,SC2115,SC2120,SC2155,SC2199,SC2229,SC2317,SC2329
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
VERSION="202607031823-git"
# - - - - - - - - - - - - - - - - - - - - - - - - -
set -uo pipefail
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Protection philosophy: surgical, not broad.
#
# ALWAYS blocked (true non-exemptables):
#   • Delete/corrupt auth-critical files: /etc/passwd, /etc/shadow, /etc/group,
#     /etc/gshadow, /etc/sudoers, /etc/master.passwd
#   • Write arbitrary files into core OS binary dirs: /bin/, /sbin/, /usr/bin/, /usr/sbin/
#   • Wipe filesystem root (/) or home directory itself (rm -rf ~)
#   • Raw block-device writes (dd/mkfs to /dev/sd*, /dev/nvme*)
#   • pkill/killall (name-based process kill — hits unrelated host processes)
#   • Unscoped container/instance sweeps (unfiltered docker ps or incus list feeding kill/stop/rm/delete; docker prune)
#   • systemctl host-service mutation (restart/stop/start/etc. without --user)
#
# ALLOWED (legitimate sysadmin — not blocked):
#   • chmod/chown/chgrp on any path (e.g. chmod 700 /etc/wireguard)
#   • mkdir/cp/mv/install/ln to /etc/*, /var/*, /opt/*, /run/*, /usr/local/*, etc.
#   • Shell redirects to config files (e.g. > /etc/wireguard/wg0.conf)
#   • tee, wg genkey, and similar pipe-based generators writing to system config paths
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Core OS binary dirs — arbitrary writes here = code execution risk.
PROTECT_HOST_CORE_BINARY='(/bin|/sbin|/usr/bin|/usr/sbin)'
# Auth-critical files — deleting or overwriting breaks authentication/identity.
PROTECT_HOST_AUTH_CRITICAL='(/etc/(passwd|shadow|gshadow|group|sudoers|master\.passwd))'
# Home-directory root only — the home dir ITSELF, not subpaths.
# e.g. /root and /home/jason are protected; /root/Projects is not.
# $HOME (unexpanded) and ~ are equivalent spellings of the same target.
PROTECT_HOST_HOME_LITERAL='(/root|/home/[^/[:space:]&|;()`<>]+|~|\$HOME)'
# Truly destructive verbs: delete and wipe only. chmod/chown are NOT here — they configure, not destroy.
PROTECT_HOST_DESTRUCTIVE_VERBS='rm|rmd|rmdir|shred|truncate|wipefs'
# Write verbs that install/overwrite files.
PROTECT_HOST_WRITE_VERBS='mv|cp|install|ln'
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Helpers
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# __require_cmd <name> - bail with a clear error if a required tool is missing.
# A broken hook exits 0 (no-op) so we never silently block every Bash call.
__require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    printf 'protect-host.sh: required command not found: %s\n' "$1" >&2
    exit 0
  fi
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# __extract_command - read the JSON payload on stdin, print tool_input.command.
__extract_command() {
  python3 -c '
import json, sys
try:
    d = json.load(sys.stdin)
    print(d.get("tool_input", {}).get("command", ""))
except Exception:
    print("")
'
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# __strip_container_subcmds - split the command on newlines and shell separators,
# drop sub-commands that run inside a container/sandbox, print the rest one per line.
# Splitting is intentionally naive (quoted separators over-split) — over-splitting
# only makes the check stricter, never looser. Exempting per sub-command closes the
# old whole-command-prefix bypass: "docker run --rm img true; rm -rf ~" no longer
# gets a free pass just because the string STARTS with "docker run ".
__strip_container_subcmds() {
  python3 -c '
import re, sys
cmd = sys.stdin.read()
prefixes = (
    "docker exec ", "docker run ",
    "docker compose exec ", "docker compose run ",
    "docker-compose exec ", "docker-compose run ",
    "incus exec ", "incus shell ", "incus file push ", "incus file pull ",
    "lxc exec ", "lxc file push ", "lxc file pull ",
    "podman exec ", "podman run ",
    "kubectl exec ",
    "nsenter ", "chroot ",
)
kept = []
for part in re.split(r"[\n;]|&&|\|\||[|&]", cmd):
    sub = part.strip()
    if not sub:
        continue
    if sub.startswith(prefixes):
        continue
    kept.append(sub)
print("\n".join(kept))
'
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# __block <reason> - emit a structured BLOCKED message and exit 2.
__block() {
  printf 'BLOCKED: %s\n' "$1" >&2
  exit 2
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# __match <regex> - return 0 if "$PROTECT_HOST_CMD" matches the extended regex.
__match() {
  printf '%s' "$PROTECT_HOST_CMD" | \grep -qE -- "$1"
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
__require_cmd python3
__require_cmd grep
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# $(cat) is required here — hook stdin is a socket; $(</dev/stdin) re-opens it and fails with ENXIO
PROTECT_HOST_INPUT="$(cat)"
PROTECT_HOST_CMD="$(printf '%s' "$PROTECT_HOST_INPUT" | __extract_command)"
# Raw command kept for pipeline-shaped rules — sub-command splitting severs
# pipes, so "docker ps -q | xargs docker kill" is only visible here.
PROTECT_HOST_RAW_CMD="$PROTECT_HOST_CMD"
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Empty / non-Bash payload - nothing to inspect.
[ -z "$PROTECT_HOST_CMD" ] && exit 0
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Container-mediated sub-commands are explicitly trusted at this layer;
# everything else in a compound/multi-line command is still inspected.
PROTECT_HOST_CMD="$(printf '%s' "$PROTECT_HOST_CMD" | __strip_container_subcmds)"
[ -z "$PROTECT_HOST_CMD" ] && exit 0
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Word-boundary fragment reused across rules.
# Includes backslash so the house-style alias bypass "\rm" is still caught.
PROTECT_HOST_WORD_START='(^|[[:space:];|&`(\])'
# Up to 32 non-flag, non-operator tokens between a verb and its target path.
PROTECT_HOST_TOKEN_GAP='([[:space:]]+[^[:space:]&|;()`<>]+){0,32}'
# Path tails — match the root itself OR any subpath beneath it.
PROTECT_HOST_CORE_BINARY_TAIL="${PROTECT_HOST_CORE_BINARY}([[:space:]/]|\$)"
PROTECT_HOST_AUTH_CRITICAL_TAIL="${PROTECT_HOST_AUTH_CRITICAL}([[:space:]]|\$)"
# Trailing /* (wipe-the-contents form) is as destructive as the dir itself.
PROTECT_HOST_HOME_TAIL="${PROTECT_HOST_HOME_LITERAL}(/\*?)?([[:space:]]|\$)"
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Rule 1: destructive verb on auth-critical files.
if __match "${PROTECT_HOST_WORD_START}(${PROTECT_HOST_DESTRUCTIVE_VERBS})${PROTECT_HOST_TOKEN_GAP}[[:space:]]+${PROTECT_HOST_AUTH_CRITICAL_TAIL}"; then
  __block "destructive op on auth-critical file (/etc/passwd, /etc/shadow, /etc/group, etc.)"
fi
# Rule 2: destructive verb on core OS binary dirs.
if __match "${PROTECT_HOST_WORD_START}(${PROTECT_HOST_DESTRUCTIVE_VERBS})${PROTECT_HOST_TOKEN_GAP}[[:space:]]+${PROTECT_HOST_CORE_BINARY_TAIL}"; then
  __block "destructive op on core OS binary path (/bin, /sbin, /usr/bin, /usr/sbin) — use a package manager"
fi
# Rule 3: destructive verb on the home directory root itself (not subpaths).
if __match "${PROTECT_HOST_WORD_START}(${PROTECT_HOST_DESTRUCTIVE_VERBS})${PROTECT_HOST_TOKEN_GAP}[[:space:]]+${PROTECT_HOST_HOME_TAIL}"; then
  __block "destructive command targeting the home directory itself"
fi
# Rule 4: destructive verb on the filesystem root / (including the /* contents form).
if __match "${PROTECT_HOST_WORD_START}(${PROTECT_HOST_DESTRUCTIVE_VERBS})${PROTECT_HOST_TOKEN_GAP}[[:space:]]+/\*?([[:space:]]|\$)"; then
  __block "destructive op targeting the filesystem root /"
fi
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Rule 5: shell redirect (> or >>) to auth-critical files or core binary paths.
# /dev/null, /dev/std{in,out,err}, /dev/tty, /dev/fd/N, /dev/pts/N are always safe.
__check_redirects() {
  python3 - "$1" <<'PYSCRIPT'
import re, sys
# Any unexpected exception must fail OPEN (exit 0) — the documented design is
# that a broken hook never blocks every Bash call; only a real match exits 1.
sys.excepthook = lambda *a: sys.exit(0)
cmd = sys.argv[1]
auth_critical = re.compile(
    r"^/etc/(passwd|shadow|gshadow|group|sudoers|master\.passwd)$"
)
core_binary = re.compile(
    r"^/(bin|sbin|usr/bin|usr/sbin)(/|$)"
)
safe_pseudo = re.compile(
    r"^/dev/(null|stdin|stdout|stderr|tty|fd/\d+|pts/\d+)$"
)
for m in re.finditer(r"(?:^|[\s;|&`(])(?:\d+|&)?>>?\s*([^\s;|&`()<>]+)", cmd):
    target = m.group(1).strip("\"'")
    if safe_pseudo.match(target):
        continue
    if auth_critical.match(target) or core_binary.match(target):
        print(target)
        sys.exit(1)
sys.exit(0)
PYSCRIPT
}
if PROTECT_HOST_BAD_REDIRECT="$(__check_redirects "$PROTECT_HOST_CMD")"; then
  :
else
  __block "shell redirect to protected path: $PROTECT_HOST_BAD_REDIRECT"
fi
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Rule 6: find -delete or -exec rm in core OS binary paths or on home dir root.
if __match "${PROTECT_HOST_WORD_START}find[[:space:]]+${PROTECT_HOST_CORE_BINARY}([[:space:]/].*-delete|.*-exec[[:space:]]+rm)"; then
  __block "'find -delete' / '-exec rm' in core OS binary path"
fi
if __match "${PROTECT_HOST_WORD_START}find[[:space:]]+${PROTECT_HOST_HOME_LITERAL}/?[[:space:]]+([^&;|]*-delete|[^&;|]*-exec[[:space:]]+rm)"; then
  __block "'find -delete' / '-exec rm' targeting the home directory itself"
fi
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Rule 7: write-verb (mv/cp/install/ln) to auth-critical files or core OS binary dirs.
# Writes to /etc/*, /var/*, /opt/*, /run/*, /usr/local/*, etc. are allowed.
if __match "${PROTECT_HOST_WORD_START}(${PROTECT_HOST_WRITE_VERBS})${PROTECT_HOST_TOKEN_GAP}[[:space:]]+${PROTECT_HOST_AUTH_CRITICAL_TAIL}"; then
  __block "mv/cp/install/ln to auth-critical file (/etc/passwd, /etc/shadow, /etc/group, etc.)"
fi
if __match "${PROTECT_HOST_WORD_START}(${PROTECT_HOST_WRITE_VERBS})${PROTECT_HOST_TOKEN_GAP}[[:space:]]+${PROTECT_HOST_CORE_BINARY_TAIL}"; then
  __block "mv/cp/install/ln to core OS binary path — install to /usr/local/bin instead"
fi
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Rule 8: raw block-device writers targeting host disks.
if __match "${PROTECT_HOST_WORD_START}(dd|mkfs[^[:space:]]*)[[:space:]].*((of|of=)/dev/|[[:space:]]/dev/[sh]d|[[:space:]]/dev/nvme)"; then
  __block "raw disk writer targeting host device"
fi
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Rule 9: pkill/killall/kill-by-pgrep — process termination must use tracked PIDs.
if __match "${PROTECT_HOST_WORD_START}(pkill|killall)[[:space:]]"; then
  __block "pkill/killall targets processes by name — use kill \$TRACKED_PID (a PID captured at launch) instead"
fi
if __match "${PROTECT_HOST_WORD_START}kill[[:space:]]+.*\$\(pgrep"; then
  __block "kill \$(pgrep ...) targets processes by pattern — use kill \$TRACKED_PID (a PID captured at launch) instead"
fi
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Rule 10: systemctl host-service mutation requires user confirmation.
# status/is-active/is-enabled/cat/show and --user variants are always safe.
if __match "${PROTECT_HOST_WORD_START}systemctl[[:space:]]"; then
  if __match "${PROTECT_HOST_WORD_START}systemctl[[:space:]]+--user[[:space:]]"; then
    # user-scoped — always OK
    :
  elif __match "${PROTECT_HOST_WORD_START}systemctl[[:space:]]+(status|is-active|is-enabled|cat|show|list-units|list-unit-files|list-sockets|list-timers|help)[[:space:]]"; then
    # read-only — always OK
    :
  elif __match "${PROTECT_HOST_WORD_START}systemctl[[:space:]]+(restart|stop|start|reload|disable|enable|mask|unmask|isolate|kill|reset-failed)[[:space:]]"; then
    __block "systemctl host-service mutation requires user confirmation — run manually after approval"
  fi
fi
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Rule 11: unscoped container sweeps — the container analog of pkill.
# Feeding an unfiltered `docker ps` list into kill/stop/rm/restart hits EVERY
# container on the host, not just this project's. A name=/label=/--filter scope
# makes the sweep targeted and is allowed. Matched against PROTECT_HOST_RAW_CMD because the
# sub-command split severs pipes.
PROTECT_HOST_CONTAINER_SWEEP_VERBS='(kill|stop|rm|restart)'
PROTECT_HOST_CONTAINER_LIST='(docker|podman)[[:space:]]+(container[[:space:]]+)?(ps|ls)'
# __match_raw <regex> - return 0 if "$PROTECT_HOST_RAW_CMD" matches the extended regex.
__match_raw() {
  printf '%s' "$PROTECT_HOST_RAW_CMD" | \grep -qE -- "$1"
}
if __match_raw "${PROTECT_HOST_WORD_START}(docker|podman)[[:space:]]+${PROTECT_HOST_CONTAINER_SWEEP_VERBS}[^;&]*[\$\`]\(?${PROTECT_HOST_CONTAINER_LIST}" ||
  __match_raw "${PROTECT_HOST_CONTAINER_LIST}[^|]*\|.*(docker|podman)[[:space:]]+${PROTECT_HOST_CONTAINER_SWEEP_VERBS}"; then
  if ! __match_raw '(--filter|name=|label=)'; then
    __block "unscoped container sweep — an unfiltered 'docker ps' feeding kill/stop/rm hits EVERY container on the host; target project containers by name or add --filter name={project_name}-"
  fi
fi
# Incus/LXC analog: an unfiltered `incus list` feeding stop/delete/restart hits
# EVERY instance on the host. A name= filter, positional name=… key filter, or
# --project scope makes it targeted and is allowed.
PROTECT_HOST_INCUS_SWEEP_VERBS='(stop|delete|rm|restart|pause)'
PROTECT_HOST_INCUS_LIST='(incus|lxc)[[:space:]]+(list|ls)'
if __match_raw "${PROTECT_HOST_WORD_START}(incus|lxc)[[:space:]]+${PROTECT_HOST_INCUS_SWEEP_VERBS}[^;&]*[\$\`]\(?${PROTECT_HOST_INCUS_LIST}" ||
  __match_raw "${PROTECT_HOST_INCUS_LIST}[^|]*\|.*(incus|lxc)[[:space:]]+${PROTECT_HOST_INCUS_SWEEP_VERBS}"; then
  if ! __match_raw '(--filter|name=|label=|--project)'; then
    __block "unscoped instance sweep — an unfiltered 'incus list' feeding stop/delete hits EVERY instance on the host; target project instances by name or add a name={project_name}- filter"
  fi
fi
# prune subcommands are always a broad sweep — cleanup must target project resources by name.
if __match_raw "${PROTECT_HOST_WORD_START}(docker|podman)[[:space:]]+(system|builder|buildx|container|image|volume|network)[[:space:]]+prune"; then
  __block "docker prune is a broad sweep — remove only project-scoped resources by name (docker stop/rm {project_name}-XXXX)"
fi
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
exit 0
