#!/usr/bin/env bash
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
##@Version           :  202604281009-git
# @@Author           :  Jason Hempstead
# @@Contact          :  git-admin@casjaysdev.pro
# @@ReadME           :  protect-host.sh --help
# @@Copyright        :  Copyright: (c) 2026 Jason Hempstead, Casjays Developments
# @@Created          :  Friday, May 01, 2026 10:22 EDT
# @@File             :  protect-host.sh
# @@Description      :  Claude Code PreToolUse hook - block destructive Bash ops on host system paths
# @@Changelog        :  Initial version
# @@TODO             :  See project issues
# @@Other            :  Container-mediated commands (docker/incus/podman/kubectl exec) are exempted
# @@Resource         :  github.com/casapps/claude-code-hooks
# @@Terminal App     :  no
# @@sudo/root        :  no
# @@Template         :  bash/simple
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# shellcheck disable=SC1001,SC1003,SC2001,SC2003,SC2016,SC2031,SC2090,SC2115,SC2120,SC2155,SC2199,SC2229,SC2317,SC2329
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
VERSION="202604281009-git"
# - - - - - - - - - - - - - - - - - - - - - - - - -
set -uo pipefail
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Globals
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Strict host-path prefixes. Anything under these roots is off limits on the host (full subtree blocked). Inside containers, anything goes.
STRICT_PATHS='(/|/bin|/sbin|/usr|/etc|/lib|/lib32|/lib64|/boot|/var|/opt|/dev|/proc|/sys|/srv|/run)'
# Home-directory literals. Only the home dir ITSELF is protected (e.g. `rm -rf ~`, `rm -rf /root`),
# subpaths like /root/Projects, /home/jason/code, ~/dev are normal work and stay allowed.
HOME_LITERAL='(/root|/home/[^/[:space:]&|;()`<>]+|~)'
# Destructive verbs that, paired with a protected path argument, get blocked.
DESTRUCTIVE_VERBS='rm|rmd|rmdir|chmod|chown|chgrp|shred|truncate|wipefs'
# Move/copy/link verbs that, when writing INTO a protected path, get blocked.
WRITE_VERBS='mv|cp|install|ln'
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Helpers
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# __require_cmd <name> - bail with a clear error if a required tool
# is missing. A broken hook exits 0 (no-op) so we never silently
# block every Bash call.
__require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    printf 'protect-host.sh: required command not found: %s\n' "$1" >&2
    exit 0
  fi
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# __extract_command - read the JSON payload on stdin, print tool_input.command from the Claude Code PreToolUse event.
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
# __is_container_mediated <command> - 0 if the command is mediated through a container/sandbox runtime (docker/incus/etc.).
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
  printf "Use 'docker exec', 'incus exec', or work inside a VM for destructive ops.\n" >&2
  exit 2
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# __match <regex> - return 0 if "$CMD" matches the extended regex.
__match() {
  printf '%s' "$CMD" | grep -qE "$1"
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
# Word-boundary fragment reused across rules. Matches the start of a logical command position: line start, whitespace, or a shell separator.
WORD_START='(^|[[:space:];|&`(])'
# Up to 8 non-flag, non-operator tokens between a verb and its target path, so things like 'chmod -R 777 /etc' or 'find -L /etc -delete' match.
TOKEN_GAP='([[:space:]]+[^[:space:]&|;()`<>]+){0,8}'
# Strict tail: matches the path itself OR any subpath beneath it (system roots).
STRICT_TAIL="${STRICT_PATHS}([[:space:]/]|\$)"
# Home tail: matches ONLY the home dir itself (with optional trailing slash). Subpaths are NOT matched.
HOME_TAIL="${HOME_LITERAL}/?([[:space:]]|\$)"
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Rule 1a: destructive verb followed (eventually) by a host system path.
if __match "${WORD_START}(${DESTRUCTIVE_VERBS})${TOKEN_GAP}[[:space:]]+${STRICT_TAIL}"; then
  __block "destructive command targeting host system path"
fi
# Rule 1b: destructive verb targeting the home directory itself (subpaths allowed).
if __match "${WORD_START}(${DESTRUCTIVE_VERBS})${TOKEN_GAP}[[:space:]]+${HOME_TAIL}"; then
  __block "destructive command targeting the home directory itself"
fi
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Rule 2: shell redirect (> or >>) that truncates / appends a protected file.
# Exempts /dev/null, /dev/std{in,out,err}, /dev/tty, /dev/fd/N, /dev/pts/N — these are
# I/O pseudo-devices, not real files. Walks every redirect target via python and blocks
# only if a target is under a protected root AND not a safe pseudo-device.
__check_redirects() {
  python3 - "$1" <<'PYSCRIPT'
import re, sys
cmd = sys.argv[1]
protected = re.compile(r"^(/|/bin|/sbin|/usr|/etc|/lib|/lib32|/lib64|/boot|/var|/opt|/dev|/proc|/sys|/srv|/run)(/|$)")
safe = re.compile(r"^/dev/(null|stdin|stdout|stderr|tty|fd/\d+|pts/\d+)$")
for m in re.finditer(r"(?:^|[\s;|&`(])(?:\d+|&)?>>?\s*([^\s;|&`()<>]+)", cmd):
    target = m.group(1).strip("\"'")
    if protected.match(target) and not safe.match(target):
        print(target)
        sys.exit(1)
sys.exit(0)
PYSCRIPT
}
# all redirects safe if __check_redirects exits 0
if BAD_REDIRECT="$(__check_redirects "$CMD")"; then
  :
else
  __block "shell redirect to host system path: $BAD_REDIRECT"
fi
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Rule 3a: 'find <syspath> ... -delete' or '... -exec rm ...' on system roots.
if __match "${WORD_START}find[[:space:]]+${STRICT_PATHS}([[:space:]/].*-delete|.*-exec[[:space:]]+rm)"; then
  __block "'find -delete' / '-exec rm' targeting host system path"
fi
# Rule 3b: same, but on the home dir itself (subpaths allowed).
if __match "${WORD_START}find[[:space:]]+${HOME_LITERAL}/?[[:space:]]+([^&;|]*-delete|[^&;|]*-exec[[:space:]]+rm)"; then
  __block "'find -delete' / '-exec rm' targeting the home directory itself"
fi
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Rule 4: write-verb (mv/cp/install/ln) with a host system path destination.
# Note: writes INTO the home dir (e.g. cp foo /root/Projects/bar) are allowed — only system roots are blocked here.
if __match "${WORD_START}(${WRITE_VERBS})([[:space:]]+[^[:space:]&|;()\`<>]+){1,8}[[:space:]]+${STRICT_TAIL}"; then
  __block "mv/cp/install/ln with host system path destination"
fi
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Rule 5: raw block-device writers targeting host disks (sda/hda/nvme/of=).
if __match "${WORD_START}(dd|mkfs[^[:space:]]*)[[:space:]].*((of|of=)/dev/|[[:space:]]/dev/[sh]d|[[:space:]]/dev/nvme)"; then
  __block "raw disk writer targeting host device"
fi
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Rule 6: 'cd /<syspath> && rm ...' style cwd-shift attempts (system roots only — cd into home is normal).
if __match "${WORD_START}cd[[:space:]]+${STRICT_PATHS}([[:space:]/][^&;|]*)?[[:space:]]*(&&|;|\|\|)[[:space:]]*(${DESTRUCTIVE_VERBS}|>|>>)"; then
  __block "'cd' into host system path followed by destructive op"
fi
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
exit 0
