#!/usr/bin/env bash
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
##@Version           :  202605240000-git
# @@Author           :  Jason Hempstead
# @@Contact          :  git-admin@casjaysdev.pro
# @@ReadME           :  protect-host.sh --help
# @@Copyright        :  Copyright: (c) 2026 Jason Hempstead, Casjays Developments
# @@Created          :  Friday, May 01, 2026 10:22 EDT
# @@File             :  protect-host.sh
# @@Description      :  Claude Code PreToolUse hook - block truly destructive Bash ops on host
# @@Changelog        :  Surgical protection: only auth-critical files and core OS binary dirs
# @@TODO             :  See project issues
# @@Other            :  Container-mediated commands (docker/incus/podman/kubectl exec) are exempted
# @@Resource         :  github.com/casapps/claude-code-hooks
# @@Terminal App     :  no
# @@sudo/root        :  no
# @@Template         :  bash/simple
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# shellcheck disable=SC1001,SC1003,SC2001,SC2003,SC2016,SC2031,SC2090,SC2115,SC2120,SC2155,SC2199,SC2229,SC2317,SC2329
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
VERSION="202605240000-git"
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
#   • systemctl host-service mutation (restart/stop/start/etc. without --user)
#
# ALLOWED (legitimate sysadmin — not blocked):
#   • chmod/chown/chgrp on any path (e.g. chmod 700 /etc/wireguard)
#   • mkdir/cp/mv/install/ln to /etc/*, /var/*, /opt/*, /run/*, /usr/local/*, etc.
#   • Shell redirects to config files (e.g. > /etc/wireguard/wg0.conf)
#   • tee, wg genkey, and similar pipe-based generators writing to system config paths
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Core OS binary dirs — arbitrary writes here = code execution risk.
CORE_BINARY='(/bin|/sbin|/usr/bin|/usr/sbin)'
# Auth-critical files — deleting or overwriting breaks authentication/identity.
AUTH_CRITICAL='(/etc/(passwd|shadow|gshadow|group|sudoers|master\.passwd))'
# Home-directory root only — the home dir ITSELF, not subpaths.
# e.g. /root and /home/jason are protected; /root/Projects is not.
HOME_LITERAL='(/root|/home/[^/[:space:]&|;()`<>]+|~)'
# Truly destructive verbs: delete and wipe only. chmod/chown are NOT here — they configure, not destroy.
DESTRUCTIVE_VERBS='rm|rmd|rmdir|shred|truncate|wipefs'
# Write verbs that install/overwrite files.
WRITE_VERBS='mv|cp|install|ln'
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
# __is_container_mediated <command> - 0 if the command runs inside a container/sandbox.
__is_container_mediated() {
  case "$1" in
  "docker exec "* | "docker run "*) return 0 ;;
  "docker compose exec "* | "docker compose run "*) return 0 ;;
  "docker-compose exec "* | "docker-compose run "*) return 0 ;;
  "incus exec "* | "incus shell "*) return 0 ;;
  "lxc exec "*) return 0 ;;
  "podman exec "* | "podman run "*) return 0 ;;
  "kubectl exec "*) return 0 ;;
  "nsenter "* | "chroot "*) return 0 ;;
  esac
  return 1
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# __block <reason> - emit a structured BLOCKED message and exit 2.
__block() {
  printf 'BLOCKED: %s\n' "$1" >&2
  exit 2
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# __match <regex> - return 0 if "$CMD" matches the extended regex.
__match() {
  printf '%s' "$CMD" | \grep -qE -- "$1"
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
__require_cmd python3
__require_cmd grep
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
INPUT="$(cat)"
CMD="$(printf '%s' "$INPUT" | __extract_command)"
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Empty / non-Bash payload - nothing to inspect.
[ -z "$CMD" ] && exit 0
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Container-mediated commands are explicitly trusted at this layer.
if __is_container_mediated "$CMD"; then
  exit 0
fi
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Word-boundary fragment reused across rules.
WORD_START='(^|[[:space:];|&`(])'
# Up to 8 non-flag, non-operator tokens between a verb and its target path.
TOKEN_GAP='([[:space:]]+[^[:space:]&|;()`<>]+){0,8}'
# Path tails — match the root itself OR any subpath beneath it.
CORE_BINARY_TAIL="${CORE_BINARY}([[:space:]/]|\$)"
AUTH_CRITICAL_TAIL="${AUTH_CRITICAL}([[:space:]]|\$)"
HOME_TAIL="${HOME_LITERAL}/?([[:space:]]|\$)"
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Rule 1: destructive verb on auth-critical files.
if __match "${WORD_START}(${DESTRUCTIVE_VERBS})${TOKEN_GAP}[[:space:]]+${AUTH_CRITICAL_TAIL}"; then
  __block "destructive op on auth-critical file (/etc/passwd, /etc/shadow, /etc/group, etc.)"
fi
# Rule 2: destructive verb on core OS binary dirs.
if __match "${WORD_START}(${DESTRUCTIVE_VERBS})${TOKEN_GAP}[[:space:]]+${CORE_BINARY_TAIL}"; then
  __block "destructive op on core OS binary path (/bin, /sbin, /usr/bin, /usr/sbin) — use a package manager"
fi
# Rule 3: destructive verb on the home directory root itself (not subpaths).
if __match "${WORD_START}(${DESTRUCTIVE_VERBS})${TOKEN_GAP}[[:space:]]+${HOME_TAIL}"; then
  __block "destructive command targeting the home directory itself"
fi
# Rule 4: destructive verb on the filesystem root /.
if __match "${WORD_START}(${DESTRUCTIVE_VERBS})${TOKEN_GAP}[[:space:]]+/([[:space:]]|\$)"; then
  __block "destructive op targeting the filesystem root /"
fi
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Rule 5: shell redirect (> or >>) to auth-critical files or core binary paths.
# /dev/null, /dev/std{in,out,err}, /dev/tty, /dev/fd/N, /dev/pts/N are always safe.
__check_redirects() {
  python3 - "$1" <<'PYSCRIPT'
import re, sys
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
if BAD_REDIRECT="$(__check_redirects "$CMD")"; then
  :
else
  __block "shell redirect to protected path: $BAD_REDIRECT"
fi
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Rule 6: find -delete or -exec rm in core OS binary paths or on home dir root.
if __match "${WORD_START}find[[:space:]]+${CORE_BINARY}([[:space:]/].*-delete|.*-exec[[:space:]]+rm)"; then
  __block "'find -delete' / '-exec rm' in core OS binary path"
fi
if __match "${WORD_START}find[[:space:]]+${HOME_LITERAL}/?[[:space:]]+([^&;|]*-delete|[^&;|]*-exec[[:space:]]+rm)"; then
  __block "'find -delete' / '-exec rm' targeting the home directory itself"
fi
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Rule 7: write-verb (mv/cp/install/ln) to auth-critical files or core OS binary dirs.
# Writes to /etc/*, /var/*, /opt/*, /run/*, /usr/local/*, etc. are allowed.
if __match "${WORD_START}(${WRITE_VERBS})${TOKEN_GAP}[[:space:]]+${AUTH_CRITICAL_TAIL}"; then
  __block "mv/cp/install/ln to auth-critical file (/etc/passwd, /etc/shadow, /etc/group, etc.)"
fi
if __match "${WORD_START}(${WRITE_VERBS})${TOKEN_GAP}[[:space:]]+${CORE_BINARY_TAIL}"; then
  __block "mv/cp/install/ln to core OS binary path — install to /usr/local/bin instead"
fi
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Rule 8: raw block-device writers targeting host disks.
if __match "${WORD_START}(dd|mkfs[^[:space:]]*)[[:space:]].*((of|of=)/dev/|[[:space:]]/dev/[sh]d|[[:space:]]/dev/nvme)"; then
  __block "raw disk writer targeting host device"
fi
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Rule 9: pkill/killall/kill-by-pgrep — process termination must use tracked PIDs.
if __match "${WORD_START}(pkill|killall)[[:space:]]"; then
  __block "pkill/killall targets processes by name — use kill \$TRACKED_PID (a PID captured at launch) instead"
fi
if __match "${WORD_START}kill[[:space:]]+.*\$\(pgrep"; then
  __block "kill \$(pgrep ...) targets processes by pattern — use kill \$TRACKED_PID (a PID captured at launch) instead"
fi
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Rule 10: systemctl host-service mutation requires user confirmation.
# status/is-active/is-enabled/cat/show and --user variants are always safe.
if __match "${WORD_START}systemctl[[:space:]]"; then
  if __match "${WORD_START}systemctl[[:space:]]+--user[[:space:]]"; then
    : # user-scoped — always OK
  elif __match "${WORD_START}systemctl[[:space:]]+(status|is-active|is-enabled|cat|show|list-units|list-unit-files|list-sockets|list-timers|help)[[:space:]]"; then
    : # read-only — always OK
  elif __match "${WORD_START}systemctl[[:space:]]+(restart|stop|start|reload|disable|enable|mask|unmask|isolate|kill|reset-failed)[[:space:]]"; then
    __block "systemctl host-service mutation requires user confirmation — run manually after approval"
  fi
fi
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
exit 0
