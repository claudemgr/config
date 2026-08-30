#!/usr/bin/env bash
# shellcheck shell=bash
# - - - - - - - - - - - - - - - - - - - - - - - - -
##@Version           :  202608301800-git
# @@Author           :  Jason Hempstead
# @@Contact          :  git-admin@casjaysdev.pro
# @@License          :  WTFPL
# @@ReadME           :  bash-content-scan.sh --help
# @@Copyright        :  Copyright: (c) 2026 Jason Hempstead, Casjays Developments
# @@Created          :  Sunday, August 30, 2026 18:00 EDT
# @@File             :  bash-content-scan.sh
# @@Description      :  PreToolUse Bash hook: scans no-secrets.sh/no-ai-attribution.sh patterns against heredoc or echo/printf redirects, which bypass Write/Edit tool_input.
# @@Changelog        :  Added Bash heredoc/redirect secret-scanning coverage and fixed the license header field to WTFPL.
# @@TODO             :  None
# @@Other            :  Secrets respect the zone's plaintext-credential exemption (cwd-scoped); AI-attribution has no exemption; container/VM-mediated heredocs are exempt.
# @@Resource         :  home/hooks/no-secrets.sh, home/hooks/no-ai-attribution.sh
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
  printf 'bash-content-scan.sh: required command not found: python3 (hook disabled, failing open)\n' >&2
  exit 0
fi

BASH_CONTENT_SCAN_INPUT="$(cat)"

BASH_CONTENT_SCAN_HOOK_INPUT="$BASH_CONTENT_SCAN_INPUT" python3 - <<'PYEOF'
import json
import os
import re
import sys

raw = os.environ.get("BASH_CONTENT_SCAN_HOOK_INPUT", "")
try:
    payload = json.loads(raw, strict=False)
except json.JSONDecodeError:
    sys.exit(0)

if payload.get("tool_name", "") != "Bash":
    sys.exit(0)

cmd = payload.get("tool_input", {}).get("command", "")
if not cmd:
    sys.exit(0)

CONTAINER_PREFIXES = {"docker", "docker-compose", "podman", "podman-compose",
                      "kubectl", "incus", "lxc", "machinectl", "systemd-nspawn",
                      "vagrant", "multipass", "distrobox", "toolbox", "virsh",
                      "nsenter", "chroot"}


def extract_heredoc_bodies(text):
    # Returns a list of (body_text, is_container_mediated) - the body content
    # written on disk-facing heredocs, so it can be scanned like Write/Edit
    # content. Container/VM-mediated heredocs are flagged so the caller can
    # skip them (the body runs inside a disposable guest, not the host).
    bodies = []
    lines = text.split("\n")
    i = 0
    while i < len(lines):
        line = lines[i]
        for m in re.finditer(r"(?<!<)<<(?!<)-?\s*(['\"]?)(\w+)\1", line):
            delim = m.group(2)
            head = {t.rsplit("/", 1)[-1].lstrip("\\") for t in line[: m.start()].split()}
            is_container = bool(head & CONTAINER_PREFIXES)
            body_lines = []
            j = i + 1
            while j < len(lines):
                if lines[j].strip() == delim:
                    break
                body_lines.append(lines[j])
                j += 1
            bodies.append(("\n".join(body_lines), is_container))
        i += 1
    return bodies


def extract_redirected_echo_printf(text):
    # echo/printf content redirected to a real file (> or >>), the other
    # common way a Bash command writes content without going through
    # Write/Edit. Best-effort - only literal-quoted or bare arguments before
    # the first > / >> on the same logical line.
    out = []
    for sub_cmd in re.split(r"[\n;]|&&|\|\|", text):
        sub_cmd = sub_cmd.strip()
        if not re.match(r"^(echo|printf)\b", sub_cmd):
            continue
        if not re.search(r">>?\s*[^&|\s]", sub_cmd):
            continue
        body = re.split(r">>?\s*[^&|\s]", sub_cmd, maxsplit=1)[0]
        out.append(body)
    return out


segments = []
for body, is_container in extract_heredoc_bodies(cmd):
    if is_container:
        continue
    segments.append(body)
segments.extend(extract_redirected_echo_printf(cmd))

content = "\n".join(s for s in segments if s)
if not content:
    sys.exit(0)

# - - - secrets (mirrors no-secrets.sh) - - -
SECRET_PATTERNS = [
    ("AWS Access Key ID",        r"AKIA[0-9A-Z]{16}"),
    ("GitHub Token",             r"gh[pso]_[A-Za-z0-9]{36,}"),
    ("GitHub PAT (new format)",  r"github_pat_[A-Za-z0-9_]{82,}"),
    ("Slack Token",              r"xox[baprs]-[0-9A-Za-z\-]{10,}"),
    ("Stripe Live Secret Key",   r"sk_live_[A-Za-z0-9]{24,}"),
    ("Google API Key",           r"AIza[0-9A-Za-z\-_]{35}"),
    ("SendGrid API Key",         r"SG\.[A-Za-z0-9._\-]{22}\.[A-Za-z0-9._\-]{43}"),
    ("PEM Private Key",          r"-----BEGIN (?:RSA |EC |DSA |OPENSSH )?PRIVATE KEY-----"),
    ("Anthropic API Key",        r"sk-ant-[A-Za-z0-9\-_]{40,}"),
    ("OpenAI API Key",           r"sk-proj-[A-Za-z0-9]{40,}"),
    ("npm Access Token",         r"npm_[A-Za-z0-9]{36,}"),
    ("JWT (3-part)",             r"eyJ[A-Za-z0-9_\-]{10,}\.eyJ[A-Za-z0-9_\-]{10,}\.[A-Za-z0-9_\-]{10,}"),
    ("HuggingFace Token",        r"hf_[A-Za-z0-9]{34,}"),
    ("GitLab Token",             r"glpat-[A-Za-z0-9\-_]{20,}"),
    ("PyPI API Token",           r"pypi-[A-Za-z0-9_\-]{40,}"),
]
PLACEHOLDER_RE = re.compile(
    r"changeme"
    r"|placeholder"
    r"|your[_-]?(?:api[_-]?)?(?:key|token|secret|password)[_-]?here"
    r"|example"
    r"|dummy"
    r"|fake"
    r"|test[_-]?(?:key|token|secret)"
    r"|xxx+"
    r"|<[A-Za-z_][^>]*>"
    r"|\{[A-Za-z_][^}]*\}"
    r"|TO_BE"
    r"|FILL_IN"
    r"|REPLACE_ME"
    r"|INSERT_HERE"
    r"|YOUR_",
    re.IGNORECASE,
)


def redact(value):
    if len(value) <= 6:
        return "*" * len(value)
    return value[:4] + "*" * (len(value) - 6) + value[-2:]


cwd = payload.get("cwd", "") or ""
zone_root = os.path.join(os.environ.get("HOME", "/root"), "Projects", "local", "system")
in_zone = cwd == zone_root or cwd.startswith(zone_root + os.sep)

findings = []
if not in_zone:
    for label, pattern in SECRET_PATTERNS:
        for m in re.finditer(pattern, content):
            if PLACEHOLDER_RE.search(m.group(0)):
                continue
            findings.append(f"secret: {label}: {redact(m.group())}")

# - - - AI attribution (mirrors no-ai-attribution.sh) - - -
_verbs = r"(generated|written|created|authored|built|made|assisted)"
_conn = r"(by|with|using)"
_ai = r"(claude|anthropic|an? ai\b)"
_hyph = r"(-|‑)"
_ca = r"co" + _hyph + r"authored" + _hyph + r"by"
_gen = r"generated"
ATTRIBUTION_PATTERN = re.compile(
    _verbs + r"\s+" + _conn + r"\s+" + _ai
    + r"|" + _ca + r":\s*(claude|anthropic)"
    + r"|co_authored_by:\s*(claude|anthropic)"
    + r"|\bai[- ]" + _gen + r"\b"
    + "|\U0001F916" + r"\s*" + _verbs
    + r"|(this\s+file\s+(was|is)\s+(" + _gen + r"|written|created)\s+by\s+(claude|anthropic|ai\b))",
    re.IGNORECASE,
)
if ATTRIBUTION_PATTERN.search(content):
    findings.append("AI attribution phrase detected")

if not findings:
    sys.exit(0)

lines = ["BLOCKED: content written via Bash (heredoc/redirect) failed the secret/AI-attribution scan.\n"]
for f in findings:
    lines.append(f"  - {f}")
lines.append("")
lines.append(
    "This mirrors no-secrets.sh and no-ai-attribution.sh, which only ever see\n"
    "Write/Edit tool_input - a heredoc or `echo ... > file` bypasses both.\n"
    "Never write real credentials or AI-attribution lines via Bash either."
)
msg = "\n".join(lines)
print(msg)
sys.stderr.write(msg + "\n")
sys.exit(2)
PYEOF
