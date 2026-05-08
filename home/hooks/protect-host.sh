#!/usr/bin/env bash
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
##@Version           :  202605080001-git
# @@Author           :  Jason Hempstead
# @@Contact          :  git-admin@casjaysdev.pro
# @@ReadME           :  protect-host.sh --help
# @@Copyright        :  Copyright: (c) 2026 Jason Hempstead, Casjays Developments
# @@Created          :  Friday, May 01, 2026 10:22 EDT
# @@File             :  protect-host.sh
# @@Description      :  AI-agent PreToolUse hook - tiered guardrails for destructive Bash ops
# @@Changelog        :  Tiered design - hard-deny system+home blasts, confirm-required for stateful data
# @@TODO             :  See project issues
# @@Other            :  Container-mediated commands (docker/incus/podman exec) skip Tier 1
# @@Resource         :  github.com/casapps/agent-hooks
# @@Terminal App     :  no
# @@sudo/root        :  no
# @@Template         :  bash/simple
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# shellcheck disable=SC1001,SC1003,SC2001,SC2003,SC2016,SC2031,SC2090,SC2115,SC2120,SC2155,SC2199,SC2229,SC2317,SC2329
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
VERSION="202605080001-git"
# - - - - - - - - - - - - - - - - - - - - - - - - -
set -uo pipefail
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Tier model
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Tier 1 (HARD DENY, no override):
#   - System roots: full subtree blocked
#   - /var, /opt: dir itself + wildcard expansion (e.g. /var/*, /opt/**)
#   - Home literal: ~, /root, /home/<user>, $HOME -- and ~/*, ~/**, ~/.* blasts
#   - Raw block-device writers (dd of=/dev/sd*, mkfs, wipefs)
# Tier 2 (CONFIRM REQUIRED -- bypass with `# CONFIRM_DESTRUCTIVE` marker):
#   - Stateful data dirs: /var/lib/*, /var/spool/*, /var/mail/*, /var/local/*
#   - Cloud-CLI destructive verbs (aws/gcloud/kubectl/helm/terraform/railway/...)
#   - Paths matching a docker/podman/compose bind-mount source in cwd or any parent
# Tier 3 (FREE):
#   - Everything else: /tmp, /var/log, /var/cache, /var/www, /var/tmp, /opt/<app>,
#     home subpaths, project paths, etc.
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Globals
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# System roots -- full subtree blocked.
SYSTEM_ROOTS='(/|/bin|/sbin|/usr|/etc|/lib|/lib32|/lib64|/boot|/dev|/proc|/sys|/srv|/run)'
# Top-level system dirs whose dir-itself + wildcard expansion is blocked, but specific subpaths (e.g. /var/www, /opt/myapp) are allowed.
TIER1_DIR_ONLY='(/var|/opt)'
# Home literals -- dir itself + wildcard expansion blocked; subpaths like ~/Projects are allowed.
HOME_LITERAL='(/root|/home/[^/[:space:]&|;()`<>]+|~|\$HOME)'
# Tier 2 stateful-data subtrees -- destructive ops require explicit confirmation marker.
TIER2_DATA='(/var/lib|/var/spool|/var/mail|/var/local)'
# Raw block devices -- writes to these wipe disks. Tier 2 (USB flashing is legit; system disk wipe is not, so the marker is the user-explicit consent).
RAW_BLOCK_DEVS='/dev/(sd[a-z]+[0-9]*|hd[a-z]+[0-9]*|nvme[0-9]+(n[0-9]+(p[0-9]+)?)?|mmcblk[0-9]+(p[0-9]+)?|loop[0-9]+|sr[0-9]+|dm-[0-9]+|mapper/[^[:space:]]+|disk/[^[:space:]]+)'
# Tier 1 exemptions -- subpaths under SYSTEM_ROOTS that are user-owned spaces (auto-mounted USB drives, user runtime dirs). Matched paths fall through to Tier 2/3 instead of being hard-blocked.
SYSTEM_TIER1_EXEMPT='(/run/media/[^/[:space:]&|;()`<>]+/[^[:space:]&|;()`<>]+|/run/user/[0-9]+/[^[:space:]&|;()`<>]+|/run/mount/[^/[:space:]&|;()`<>]+/[^[:space:]&|;()`<>]+)'
# Cloud CLIs whose destructive subcommands wipe remote state (cannot be undone).
CLOUD_TOOLS='(railway|fly|flyctl|gcloud|aws|kubectl|helm|doctl|linode-cli|vultr-cli|hcloud|az|oci|terraform|tofu|pulumi|heroku|vercel|netlify)'
# Cloud destructive verbs -- matches verb tokens, including hyphenated forms like delete-instance.
CLOUD_DESTRUCTIVE_VERBS='(delete[-_a-zA-Z0-9]*|destroy[-_a-zA-Z0-9]*|terminate[-_a-zA-Z0-9]*|remove[-_a-zA-Z0-9]*|rm|rb|drop|nuke|uninstall|purge)'
# Local destructive verbs.
DESTRUCTIVE_VERBS='rm|rmd|rmdir|chmod|chown|chgrp|shred|truncate|wipefs'
# Move/copy/link verbs that, when writing INTO a protected path, get blocked.
WRITE_VERBS='mv|cp|install|ln'
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Helpers
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# __require_cmd <name> -- bail if a required tool is missing. A broken hook exits 0 (no-op) so we never silently block every Bash call.
__require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    printf 'protect-host.sh: required command not found: %s\n' "$1" >&2
    exit 0
  fi
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# __extract_command -- read JSON payload on stdin, print tool_input.command from the PreToolUse event.
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
# __is_container_mediated <command> -- 0 if mediated through a container/sandbox runtime.
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
# __has_confirm_marker <command> -- 0 if command carries explicit confirmation marker (Tier 2 bypass).
__has_confirm_marker() {
  case "$1" in
  *'# CONFIRM_DESTRUCTIVE'* | *'#CONFIRM_DESTRUCTIVE'*) return 0 ;;
  *'# I_REALLY_MEAN_IT'* | *'#I_REALLY_MEAN_IT'*) return 0 ;;
  esac
  return 1
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# __block_tier1 <reason> -- hard deny, no override possible.
__block_tier1() {
  printf 'BLOCKED (TIER 1, hard deny): %s\n' "$1" >&2
  printf "Use 'docker exec', 'incus exec', or work inside a VM for destructive ops.\n" >&2
  exit 2
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# __block_tier2 <reason> [<target>] -- confirm-required deny, bypassable with `# CONFIRM_DESTRUCTIVE`.
__block_tier2() {
  printf 'BLOCKED (TIER 2, confirmation required): %s\n' "$1" >&2
  if [ -n "${2:-}" ]; then
    printf 'Target: %s\n' "$2" >&2
  fi
  printf 'This destroys persistent state. To proceed, USER must re-issue the command with:\n' >&2
  printf '  <your-command> # CONFIRM_DESTRUCTIVE\n' >&2
  printf 'AI agents must NOT auto-add this marker -- only the user can.\n' >&2
  exit 2
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# __match <regex> -- return 0 if "$CMD" matches the extended regex.
__match() {
  printf '%s' "$CMD" | grep -qE "$1"
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# __check_redirects <command> -- print the first protected redirect target found (and return 1), or return 0 if none.
__check_redirects() {
  python3 - "$1" <<'PYSCRIPT'
import re, sys
cmd = sys.argv[1]
protected = re.compile(r"^(/|/bin|/sbin|/usr|/etc|/lib|/lib32|/lib64|/boot|/dev|/proc|/sys|/srv|/run)(/|$)")
safe = re.compile(r"^/dev/(null|stdin|stdout|stderr|tty|fd/\d+|pts/\d+)$")
for m in re.finditer(r"(?:^|[\s;|&`(])(?:\d+|&)?>>?\s*([^\s;|&`()<>]+)", cmd):
    target = m.group(1).strip("\"'")
    if protected.match(target) and not safe.match(target):
        print(target)
        sys.exit(1)
sys.exit(0)
PYSCRIPT
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# __check_compose_mount <command> <cwd> -- best-effort check whether any path in the command matches a docker/podman bind-mount source defined in a compose file in cwd or any parent (up to git root). Prints "<cmd_path>|<bind_source>" and exits 1 on match; exits 0 otherwise. Works without PyYAML (regex fallback).
__check_compose_mount() {
  python3 - "$1" "$2" <<'PYSCRIPT'
import os, re, sys

cmd = sys.argv[1]
cwd = sys.argv[2] or os.getcwd()
COMPOSE_NAMES = (
    'compose.yml', 'compose.yaml',
    'docker-compose.yml', 'docker-compose.yaml',
    'podman-compose.yml', 'podman-compose.yaml',
)

def find_compose_files(start):
    paths = []
    cur = os.path.abspath(start)
    for _ in range(30):
        for name in COMPOSE_NAMES:
            p = os.path.join(cur, name)
            if os.path.isfile(p):
                paths.append(p)
        if os.path.isdir(os.path.join(cur, '.git')):
            break
        parent = os.path.dirname(cur)
        if parent == cur:
            break
        cur = parent
    return paths

def _scrape(path):
    out = set()
    base = os.path.dirname(os.path.abspath(path))
    try:
        text = open(path).read()
    except Exception:
        return out
    # Short form: `- "./path:..."` or `- /abs:/...`
    for m in re.finditer(r'-\s+["\']?([./~][^\s:"\']+):', text):
        src = m.group(1)
        if src.startswith('~'):
            src = os.path.expanduser(src)
        if not os.path.isabs(src):
            src = os.path.normpath(os.path.join(base, src))
        out.add(src)
    # Long form: `source: ./path` or `source: /abs/path`
    for m in re.finditer(r'(?m)^\s*source:\s*["\']?([./~][^\s"\']+)', text):
        src = m.group(1)
        if src.startswith('~'):
            src = os.path.expanduser(src)
        if not os.path.isabs(src):
            src = os.path.normpath(os.path.join(base, src))
        out.add(src)
    return out

def extract_bind_sources(compose_path):
    try:
        import yaml
    except ImportError:
        return _scrape(compose_path)
    try:
        with open(compose_path) as f:
            data = yaml.safe_load(f) or {}
    except Exception:
        return set()
    out = set()
    base = os.path.dirname(os.path.abspath(compose_path))
    for svc, info in (data.get('services') or {}).items():
        if not isinstance(info, dict):
            continue
        for vol in info.get('volumes', []) or []:
            src = None
            if isinstance(vol, str):
                parts = vol.split(':')
                if len(parts) >= 2 and parts[0].startswith(('.', '/', '~')):
                    src = parts[0]
            elif isinstance(vol, dict):
                if vol.get('type') == 'bind' and 'source' in vol:
                    src = vol['source']
            if src:
                if src.startswith('~'):
                    src = os.path.expanduser(src)
                if not os.path.isabs(src):
                    src = os.path.normpath(os.path.join(base, src))
                out.add(src)
    return out

compose_files = find_compose_files(cwd)
if not compose_files:
    sys.exit(0)

sources = set()
for cf in compose_files:
    sources.update(extract_bind_sources(cf))
if not sources:
    sys.exit(0)

cmd_paths = []
for m in re.finditer(r'(?:^|[\s=])(["\']?)([./~][^\s&|;()`<>"\']+)\1', cmd):
    cmd_paths.append(m.group(2))

for p in cmd_paths:
    if p.startswith('~'):
        p = os.path.expanduser(p)
    if not os.path.isabs(p):
        p = os.path.normpath(os.path.join(cwd, p))
    else:
        p = os.path.normpath(p)
    for src in sources:
        if p == src or p.startswith(src.rstrip('/') + os.sep) or src.startswith(p.rstrip('/') + os.sep):
            print(f"{p}|{src}")
            sys.exit(1)
sys.exit(0)
PYSCRIPT
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
__require_cmd python3
__require_cmd grep
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
INPUT="$(cat)"
CMD="$(printf '%s' "$INPUT" | __extract_command)"
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Empty / non-Bash payload -- nothing to inspect.
[ -z "$CMD" ] && exit 0
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Container-mediated commands skip Tier 1 -- the host paths in the command refer to the container filesystem. They still go through Tier 2: DB paths and cloud verbs inside containers are still dangerous (volume mounts, in-container kubectl, etc.).
CONTAINER_MEDIATED=0
if __is_container_mediated "$CMD"; then
  CONTAINER_MEDIATED=1
fi
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Word-boundary fragment: matches start of a logical command position (line start, whitespace, shell separator).
WORD_START='(^|[[:space:];|&`(])'
# Up to 8 non-flag, non-operator tokens between a verb and its target path. Each iteration is `<space>+<token>`, so after the gap we still need a final `[[:space:]]+` before the target.
TOKEN_GAP='([[:space:]]+[^[:space:]&|;()`<>]+){0,8}'
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Tail patterns
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# System root subtree (also matches /* and /etc* -- wildcards in tail set).
SYSTEM_TAIL="${SYSTEM_ROOTS}([[:space:]/*?]|\$)"
# Tier1 dir-only literal: the dir itself with optional trailing slash, then space/end.
TIER1_DIR_TAIL="${TIER1_DIR_ONLY}/?([[:space:]]|\$)"
# Tier1 dir-only wildcard: /var/*, /var/**, /var/.*, /opt/*, etc.
TIER1_DIR_WILDCARD_TAIL="${TIER1_DIR_ONLY}/+\\.?\\*"
# Home literal: ~, /root, /home/<user>, $HOME -- with optional trailing slash, then space/end.
HOME_TAIL="${HOME_LITERAL}/?([[:space:]]|\$)"
# Home wildcard: ~/*, ~/**, ~/.*, /root/*, $HOME/*.
HOME_WILDCARD_TAIL="${HOME_LITERAL}/+\\.?\\*"
# Tier 2 data subtree: /var/lib/<anything>, /var/spool/<anything>, etc.
TIER2_TAIL="${TIER2_DATA}([[:space:]/*?]|\$)"
# Raw block device tail.
RAW_BLOCK_TAIL="${RAW_BLOCK_DEVS}([[:space:]/*?]|\$)"
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Tier 1 -- hard deny (skipped when container-mediated)
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
if [ "$CONTAINER_MEDIATED" -eq 0 ]; then

  # Rule 1a: destructive verb on a system root or any subpath. EXCEPT raw block devices (USB flashing -> Tier 2) and user-owned subpaths under /run (auto-mounted USB at /run/media, user runtime at /run/user).
  if __match "${WORD_START}(${DESTRUCTIVE_VERBS})${TOKEN_GAP}[[:space:]]+${SYSTEM_TAIL}"; then
    if ! __match "${WORD_START}(${DESTRUCTIVE_VERBS})${TOKEN_GAP}[[:space:]]+(${RAW_BLOCK_DEVS}|${SYSTEM_TIER1_EXEMPT})"; then
      __block_tier1 "destructive command targeting host system path"
    fi
  fi

  # Rule 1b: destructive verb targeting /var or /opt itself (subpaths allowed).
  if __match "${WORD_START}(${DESTRUCTIVE_VERBS})${TOKEN_GAP}[[:space:]]+${TIER1_DIR_TAIL}"; then
    __block_tier1 "destructive command targeting top-level system dir (/var or /opt itself)"
  fi

  # Rule 1c: destructive wildcard expansion at /var or /opt top level (e.g. rm -rf /var/*).
  if __match "${WORD_START}(${DESTRUCTIVE_VERBS})${TOKEN_GAP}[[:space:]]+${TIER1_DIR_WILDCARD_TAIL}"; then
    __block_tier1 "destructive wildcard expansion at /var or /opt top level"
  fi

  # Rule 1d: destructive verb targeting the home directory itself (subpaths allowed).
  if __match "${WORD_START}(${DESTRUCTIVE_VERBS})${TOKEN_GAP}[[:space:]]+${HOME_TAIL}"; then
    __block_tier1 "destructive command targeting the home directory itself"
  fi

  # Rule 1e: destructive wildcard expansion at home top level (e.g. rm -rf ~/*).
  if __match "${WORD_START}(${DESTRUCTIVE_VERBS})${TOKEN_GAP}[[:space:]]+${HOME_WILDCARD_TAIL}"; then
    __block_tier1 "destructive wildcard expansion at home directory top level"
  fi

  # Rule 2: shell redirect (> or >>) into a protected file. Pseudo-devices (/dev/null, /dev/std{in,out,err}, /dev/tty, /dev/fd/N, /dev/pts/N) are exempt.
  if BAD_REDIRECT="$(__check_redirects "$CMD")"; then
    : # all redirects safe
  else
    __block_tier1 "shell redirect to host system path: $BAD_REDIRECT"
  fi

  # Rule 3a: 'find <syspath> ... -delete' or '-exec rm' on system roots.
  if __match "${WORD_START}find[[:space:]]+${SYSTEM_ROOTS}([[:space:]/].*-delete|.*-exec[[:space:]]+rm)"; then
    __block_tier1 "'find -delete' / '-exec rm' targeting host system path"
  fi

  # Rule 3b: same, on home literal (subpaths allowed).
  if __match "${WORD_START}find[[:space:]]+${HOME_LITERAL}/?[[:space:]]+([^&;|]*-delete|[^&;|]*-exec[[:space:]]+rm)"; then
    __block_tier1 "'find -delete' / '-exec rm' targeting the home directory itself"
  fi

  # Rule 3c: same, on /var or /opt top level (subpaths allowed).
  if __match "${WORD_START}find[[:space:]]+${TIER1_DIR_ONLY}/?[[:space:]]+([^&;|]*-delete|[^&;|]*-exec[[:space:]]+rm)"; then
    __block_tier1 "'find -delete' / '-exec rm' targeting top-level system dir"
  fi

  # Rule 4: write-verb (mv/cp/install/ln) with a host system path destination. EXCEPT raw block devices (Tier 2) and Tier 1 exempt subpaths (USB mounts under /run/media, user runtime under /run/user).
  if __match "${WORD_START}(${WRITE_VERBS})([[:space:]]+[^[:space:]&|;()\`<>]+){1,8}[[:space:]]+${SYSTEM_TAIL}"; then
    if ! __match "${WORD_START}(${WRITE_VERBS})([[:space:]]+[^[:space:]&|;()\`<>]+){1,8}[[:space:]]+(${RAW_BLOCK_DEVS}|${SYSTEM_TIER1_EXEMPT})"; then
      __block_tier1 "mv/cp/install/ln with host system path destination"
    fi
  fi

  # (Rule 5 removed: raw block-device writers were Tier 1 hard-deny but legit ISO-to-USB needs Tier 2 confirm. See Rule 2d below.)

  # Rule 6: 'cd /<syspath> && rm ...' style cwd-shift attempts.
  if __match "${WORD_START}cd[[:space:]]+${SYSTEM_ROOTS}([[:space:]/][^&;|]*)?[[:space:]]*(&&|;|\|\|)[[:space:]]*(${DESTRUCTIVE_VERBS}|>|>>)"; then
    __block_tier1 "'cd' into host system path followed by destructive op"
  fi

fi # end Tier 1
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Confirmation marker -- bypass Tier 2 if user explicitly confirmed.
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
if __has_confirm_marker "$CMD"; then
  exit 0
fi
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Tier 2 -- confirm required (bypassable with `# CONFIRM_DESTRUCTIVE`)
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Rule 2a: destructive verb on a Tier 2 stateful-data subtree.
if __match "${WORD_START}(${DESTRUCTIVE_VERBS})${TOKEN_GAP}[[:space:]]+${TIER2_TAIL}"; then
  __block_tier2 "destructive op on stateful data path (DB / spool / mail / local)"
fi

# Rule 2b: cloud CLI followed (eventually) by a destructive verb. Catches `aws s3 rb`, `kubectl delete`, `gcloud sql instances delete`, `terraform destroy`, `helm uninstall`, `railway volume delete`, etc.
if __match "${WORD_START}${CLOUD_TOOLS}${TOKEN_GAP}[[:space:]]+${CLOUD_DESTRUCTIVE_VERBS}([[:space:]]|\$)"; then
  __block_tier2 "cloud CLI destructive verb (volume/resource/instance delete)"
fi

# Rule 2c: compose bind-mount detection -- only run if there is a destructive verb in the command (skip otherwise to keep fast).
if __match "${WORD_START}(${DESTRUCTIVE_VERBS})[[:space:]]+"; then
  if ! MATCH_LINE="$(__check_compose_mount "$CMD" "${PWD:-$(pwd)}" 2>/dev/null)"; then
    __block_tier2 "destructive op on docker/podman bind-mount source" "$MATCH_LINE"
  fi
fi

# Rule 2d: raw disk writers -- dd of=/dev/sd*, mkfs /dev/sd*, wipefs /dev/sd*, cp/mv to /dev/sd*, shred /dev/sd*. Covers ISO-to-USB, disk formatting, and secure wipe; user must explicitly confirm with marker since picking the wrong device wipes the system.
if __match "${WORD_START}(dd|mkfs[^[:space:]]*|wipefs[^[:space:]]*)[[:space:]]+.*((of|of=)${RAW_BLOCK_DEVS}|${RAW_BLOCK_DEVS})"; then
  __block_tier2 "raw disk writer targeting block device (USB / disk)"
fi
if __match "${WORD_START}(${WRITE_VERBS})([[:space:]]+[^[:space:]&|;()\`<>]+){1,8}[[:space:]]+${RAW_BLOCK_TAIL}"; then
  __block_tier2 "cp/mv/install/ln writing to raw block device (USB / disk)"
fi
if __match "${WORD_START}(${DESTRUCTIVE_VERBS})${TOKEN_GAP}[[:space:]]+${RAW_BLOCK_TAIL}"; then
  __block_tier2 "destructive verb targeting raw block device (USB / disk)"
fi
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
exit 0
