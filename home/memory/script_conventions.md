---
name: Bash script conventions
description: Code standards, performance rules, and documentation requirements for CasjaysDev bash scripts
type: user
---

## Script Header Template

The separator line is exactly: `# - - - - - - - - - - - - - - - - - - - - - - - -` (24 dashes, space-separated). Used between every logical block including after the shellcheck line.

### Header block (same fields for all shells)

```
#!/usr/bin/env {shell}
# shellcheck shell={shell}
# - - - - - - - - - - - - - - - - - - - - - - - - -
##@Version           :  %Y%m%d%H%M-git
# @@Author           :  Jason Hempstead
# @@Contact          :  git-admin@casjaysdev.pro
# @@License          :  {LICENSE_NAME} or LICENSE.md
# @@ReadME           :  {scriptname --help | README.md}
# @@Copyright        :  Copyright: (c) {year} Jason Hempstead, Casjays Developments
# @@Created          :  {Weekday, Month DD, YYYY HH:MM TZ}
# @@File             :  {file_name}
# @@Description      :  {short one-sentence description}
# @@Changelog        :  {short one-sentence changelog message}
# @@TODO             :  {short list of TODOs}
# @@Other            :  {anything that doesn't fit another field}
# @@Resource         :  {short list of resources, e.g. Stack Overflow links}
# @@Terminal App     :  {yes|no}
# @@sudo/root        :  {yes|no}
# @@Template         :  {template name, or shell/{shell} if no template}
# - - - - - - - - - - - - - - - - - - - - - - - - -
# shellcheck disable=SC1001,SC1003,SC2001,SC2003,SC2016,SC2031,SC2090,SC2115,SC2120,SC2155,SC2199,SC2229,SC2317,SC2329
# - - - - - - - - - - - - - - - - - - - - - - - - -
VERSION="YYYYMMDDHHMM-git"
```

- `##@Version` uses double `#` — all other `@@` fields use single `#`
- `@@Created` — full weekday + date + time + timezone: `Wednesday, May 13, 2026 10:58 EDT`
- `@@Template` — template name if used; otherwise `shell/bash`, `shell/sh`, `shell/zsh`, `shell/fish`
- There IS a separator line after the shellcheck disable line
- `VERSION="YYYYMMDDHHMM-git"` is the **literal placeholder string** — AI must write it exactly as `YYYYMMDDHHMM-git` in new scripts, never substitute an actual date/time. The script itself replaces it at runtime via git hook or build step. When `--version` is called, this string is printed as-is unless replaced.
- **Never revert a real timestamp to the placeholder** — if a script already contains a real 12-digit timestamp like `VERSION="202605172147-git"`, that is a valid runtime-stamped value. Never replace it with `YYYYMMDDHHMM-git`. The placeholder is only for newly created scripts that have not yet been stamped.
- **Update the timestamp on every edit** — whenever AI edits an existing script, update exactly two things: (1) the `##@Version` line in the header, and (2) the first `VERSION=` assignment that appears after the header block. Set both to the current timestamp, e.g. `202605172147-git` (run `date +'%Y%m%d%H%M-git'` to get the value). Write the resolved value, not the shell expression. Do not touch any other `VERSION=` occurrences elsewhere in the script.
- The `shellcheck disable` line only appears in shells shellcheck supports — see table below

### Shell-specific differences

| Item | bash | sh | zsh | fish |
|------|------|----|-----|------|
| shellcheck shell line | `# shellcheck shell=bash` | `# shellcheck shell=sh` | *(omit)* | *(omit)* |
| shellcheck disable | `# shellcheck disable=SC1001,SC1003,SC2001,SC2003,SC2016,SC2031,SC2090,SC2115,SC2120,SC2155,SC2199,SC2229,SC2317,SC2329` | same as bash | `# shellcheck disable=all` | *(omit entire line)* |
| `APPNAME` | `"${0##*/}"` | `"${0##*/}"` | `"${0:t}"` | `(path basename (status filename))` |
| `SCRIPT_SRC_DIR` | `"${BASH_SOURCE%/*}"` | `"$(dirname -- "$0")"` | `"${0:A:h}"` | `(path dirname (status filename))` |
| `SET_UID` | `"${UID}"` | `"$(id -u)"` | `"${UID}"` | `(id -u)` |
| `__cmd_exists` | `command -v "$1" &>/dev/null` | `command -v "$1" >/dev/null 2>&1` | `(( $+commands[$1] ))` | `command -q $argv[1]` |
| `__function_exists` | `declare -F "$1" &>/dev/null` | `case "$(type "$1" 2>/dev/null)" in *function*)` | `(( $+functions[$1] ))` | `functions -q $argv[1]` |
| color escapes | `\e[` | `\033[` | `\e[` | `\e[` |
| variables | `VAR=value` | `VAR=value` | `VAR=value` | `set -g VAR value` |
| vim modeline filetype | `filetype=sh` | `filetype=sh` | `filetype=zsh` | `filetype=fish` |

For `.ps1` and `.cmd`/`.bat` scripts: omit shellcheck lines entirely; use platform-native idioms (PowerShell cmdlets / CMD variables) per the Interpreter Detection section below.

### Standard boilerplate variables (after header)

```bash
APPNAME="${0##*/}"          # or shell-specific equivalent above
VERSION="YYYYMMDDHHMM-git"
RUN_USER="${USER}"
SET_UID="${UID}"            # or shell-specific equivalent above
SCRIPT_SRC_DIR="..."       # shell-specific — see table
```

**Section separators** between logical blocks:
```
# - - - - - - - - - - - - - - - - - - - - - - - - -
```

**Vim modeline** — always the last line of the file (filetype varies by shell — see table):
```
# ex: ts=2 sw=2 et filetype=sh
```

## Shell Selection by Target Platform

Choose the shell based on where the script will run:

| Target | Correct shell | Reason |
|--------|--------------|--------|
| macOS + Linux + BSD (cross-platform) | `#!/usr/bin/env sh` (POSIX sh) | Lowest common denominator; runs everywhere |
| Linux-only or bash explicitly required | `#!/usr/bin/env bash` | Full bashisms available |
| Zsh environment / oh-my-zsh context | `#!/usr/bin/env zsh` | Full zshisms available |
| Fish shell environment | `#!/usr/bin/env fish` | Fish idioms |
| Windows | `.ps1` (PowerShell) or `.cmd`/`.bat` | Platform native |

**Use the shell's native idioms fully** — bash scripts use bashisms, zsh scripts use zshisms, sh scripts use POSIX only. Never write POSIX-compatible bash "just in case" — pick the right shell for the target and use it properly.

## Interpreter Detection

The shebang line or file extension determines which conventions apply. Always check before editing.

| Shebang / Extension | Interpreter | Idioms to use | Comment char |
|---|---|---|---|
| `#!/usr/bin/env bash` / `#!/bin/bash` | Bash | Bashisms: `[[ ]]`, `(( ))`, arrays, `${var@Q}`, `&>>`, etc. | `#` |
| `#!/usr/bin/env sh` / `#!/bin/sh` | POSIX sh | POSIX only: `[ ]`, `$(...)`, no arrays, no `local`, no `&>>` | `#` |
| `#!/usr/bin/env zsh` | Zsh | Zshisms: `${0:t}`, `(( $+commands ))`, `${0:A:h}`, etc. | `#` |
| `#!/usr/bin/env fish` | Fish | Fish: `set`, `if`/`end`, `function`/`end`, `command -q`, etc. | `#` |
| `#!/usr/bin/env python3` etc. | Python/Ruby/etc. | Language-native conventions and linter | `#` |
| `.ps1` | PowerShell | Cmdlets, `$variables`, `Verb-Noun`, `#Requires` | `#` |
| `.cmd` / `.bat` | Windows CMD | `@echo off`, `%variables%`, `GOTO`, `::` comments | `::` or `REM` |

**When there is no shebang** (e.g. a sourced library), infer from the calling context or ask.

**Header is always added** to every script regardless of shell, using the correct comment character. For `.cmd`/`.bat`, replace `#` with `::` throughout the header block.

## Error Handling — `set -e` and `pipefail`

These modes are powerful but have subtle gotchas. Use them as follows:

| Shell | Recommended | Reason |
|-------|-------------|--------|
| bash | `set -euo pipefail` at top of every script | `-e` exits on error, `-u` catches unset vars, `-o pipefail` catches pipe failures |
| sh (POSIX) | `set -eu` — omit `pipefail` (not POSIX) | `pipefail` is a bashism; plain sh does not support it |
| zsh | `set -euo pipefail` | Same as bash; zsh supports all three |
| fish | Not needed — fish exits on errors by default | Fish error handling is built-in |

Place `set -euo pipefail` (or `set -eu` for sh) immediately after the header block, before any other code.

**`trap ERR` for cleanup:** always pair `set -e` with a trap for cleanup on unexpected exit:

```bash
set -euo pipefail

__cleanup() {
  # remove temp dirs, restore state, etc.
  [ -n "${TEMP_DIR:-}" ] && rm -rf "${TEMP_DIR}"
}
trap '__cleanup' EXIT ERR
```

Use `EXIT` (fires on any exit including clean) for resource cleanup. Use `ERR` only for error-specific actions (e.g. printing a failure message). `EXIT` alone is sufficient for most cases.

**Exceptions to `set -e`:** commands that are expected to fail must be guarded:
```bash
# BAD — exits script if grep finds no match (exit 1)
grep -- "pattern" file

# GOOD — guard with || true when non-zero is expected
grep -- "pattern" file || true

# GOOD — or check in an if block (set -e does not trigger inside conditions)
if grep -q -- "pattern" file; then ...
```

## IFS Safety

When splitting strings by a custom delimiter, always save and restore `IFS`:

```bash
# BAD — permanently changes IFS for the rest of the script
IFS=':'
read -ra parts <<< "${value}"

# GOOD — IFS change is scoped to the read command only
IFS=':' read -ra parts <<< "${value}"  # read is a builtin; IFS here is a command prefix, not global

# GOOD — when IFS must be changed for a block, save/restore
old_IFS="${IFS}"
IFS=','
# ... work with comma-split data ...
IFS="${old_IFS}"
```

Never leave `IFS` modified globally — it causes silent splitting bugs in subsequent code that expects word-splitting behavior.

## Idempotent Config Writes

When a script sets a config value in a file that participates in a **drop-in override pattern**, always search all candidate locations before writing:

1. **Search all locations** — grep for the key/setting across every file in the pattern
2. **If found anywhere** — replace/update in place; never add a duplicate
3. **Only if not found anywhere** — append to or create the appropriate drop-in file

This prevents duplicate entries scattered across multiple files, which causes unpredictable precedence and hard-to-debug behaviour.

**Common drop-in patterns:**

| Base file | Drop-in directory |
|-----------|------------------|
| `/etc/sysctl.conf` | `/etc/sysctl.d/*.conf` |
| `/etc/security/limits.conf` | `/etc/security/limits.d/*.conf` |
| `/etc/profile` | `/etc/profile.d/*.sh` |
| `/etc/environment` | `/etc/environment.d/*.conf` (systemd only) |
| `/etc/sudoers` | `/etc/sudoers.d/*` |
| `/etc/ssh/sshd_config` | `/etc/ssh/sshd_config.d/*.conf` |
| `/etc/hosts` | No drop-in — edit directly |
| `/etc/pam.d/{service}` | No drop-in — edit directly |

**Example — setting a sysctl value:**

```bash
_key="net.ipv4.ip_forward"
_val="1"
_setting="${_key} = ${_val}"
_found_in=""

for _f in /etc/sysctl.conf /etc/sysctl.d/*.conf; do
  [ -f "${_f}" ] || continue
  if grep -qF -- "${_key}" "${_f}"; then
    _found_in="${_f}"
    break
  fi
done

if [ -n "${_found_in}" ]; then
  # Found — replace in place
  sed -i "s|^[# ]*${_key}.*|${_setting}|" "${_found_in}"
else
  # Not found anywhere — write a new drop-in
  printf '%s\n' "${_setting}" > /etc/sysctl.d/99-projectname.conf
fi

sysctl -p /etc/sysctl.d/99-projectname.conf 2>/dev/null || true
```

**Rules:**
- Prefer a drop-in file over editing the base file — keeps changes isolated and easy to remove
- Use a consistent drop-in filename (`99-{project_name}.conf`) so the script's changes are identifiable
- Replace with `sed -i` anchored to the key — never line-number-based replacement
- Apply the change immediately after writing when the subsystem supports it (`sysctl -p`, `source`, etc.)
- The same search-before-write logic applies to any structured config: `/etc/hosts` entries, `sudoers` rules, PAM lines, `authorized_keys`, etc.

## Code Standards

- **Functions**: ALL functions prefixed with `__` regardless of shell — `__my_function() {}` (bash/sh/zsh), `function __my_function` (fish). No exceptions.
- **Variables**:
  - Global vars: `{SCRIPTNAME}_{VAR}` in uppercase (e.g. `MYSCRIPT_VAR`) — `{SCRIPTNAME}` is the script filename without extension, uppercased. Never use generic prefixes like `APP_`, `MY_`, `SCRIPT_` — always the actual script/project name.
  - Function-scoped vars: declare with `local` in bash/zsh; `set -l` in fish; plain assignment in sh (no `local` in POSIX sh unless targeting bash/zsh)
  - Always use `_` (underscore) — never `-` (hyphen) in variable or function names
  - Exceptions to prefix rule: well-known globals (`VERSION`, `APPNAME`, `RUN_USER`, `SET_UID`, `SCRIPT_SRC_DIR`, `HOME`, `PATH`, `USER`, `PWD`), loop variables, single-letter scratch vars
  - **System environment variables — read freely, overwrite by category** — reading is always fine; use system vars as fallbacks anywhere (`RUN_USER="${SUDO_USER:-$USER}"`, `MYSCRIPT_FQDN="${MYSCRIPT_FQDN:-$HOSTNAME}"`). Use `{SCRIPTNAME}_{VAR}` for project-specific values. Overwriting rules:
    - **Shell mechanics — never overwrite:** `PS1`–`PS4`, `OPTIND`, `OPTARG`, `SHLVL`, all `BASH_*`/`ZSH_*`/`FISH_*` vars. Exception: `IFS` may be temporarily changed — save and restore, or scope to a subshell: `old_IFS="$IFS"; IFS=:; …; IFS="$old_IFS"` or `( IFS=:; … )`.
    - **Process identity — never overwrite:** `HOME`, `USER`, `LOGNAME`, `SHELL`, `UID`, `EUID`, `GID`, `PATH`, `PWD`, `OLDPWD`.
    - **Environment preferences — overwrite only when intentional:** `LANG`, `TZ`, `TERM`, `EDITOR`, `VISUAL`, `PAGER`, `HOSTNAME`, `HOST`. Store the value in a project-prefixed var first, then assign the system var from it when downstream processes must inherit it: `MYSCRIPT_LANG="${MYSCRIPT_LANG:-en_US.UTF-8}"; export LANG="${MYSCRIPT_LANG}"`. Never hardcode directly into the system var.
  - **Exporting vars for external tools** — when an external app, library, or tool expects a specific variable name (e.g. `DATABASE_URL`, `PGPASSWORD`), bridge from the project var and export only if required: `export DATABASE_URL="${MYAPP_DATABASE_URL}"`. Set the adapter immediately before the call that needs it — never at top-level unless the entire script is a thin wrapper.
- **Comments**: always ABOVE the code they describe — NEVER inline at end of line
- **Control flow**: always use `if/elif/else` — never `&&`/`||` chains for logic flow. `&&`/`||` are acceptable only for one-liner guards (`command || return 1`) not as substitutes for `if/elif/else` blocks
- **Newlines**: always add a newline at end of file
- **Headers**: update `##@Version` to the current timestamp (`date +'%Y%m%d%H%M-git'`) and the first `VERSION=` assignment after the header on every change — only those two, nothing else
- **Line length**: if a complete command is ≤180 characters, write it on a single line — including pipelines. Only split when the line exceeds 180 characters, or when the command contains an embedded program that inherently spans lines (e.g. a multi-line `awk` or `sed` script)

## Exit Codes

Use standard POSIX and sysexits codes — never invent custom schemes.

### POSIX core (all shells, Go, Rust)

| Code | Meaning | When to use |
|------|---------|-------------|
| `0` | Success | Command completed successfully |
| `1` | General error | Unspecified runtime failure |
| `2` | Misuse | Bad arguments, unknown flag, wrong usage — also what `getopt`/`getopts` returns on parse error |

### sysexits.h (preferred for scripts and CLI tools)

| Code | Name | When to use |
|------|------|-------------|
| `64` | `EX_USAGE` | Wrong number of arguments or invalid flag |
| `65` | `EX_DATAERR` | Input data malformed or invalid |
| `66` | `EX_NOINPUT` | Input file not found or not readable |
| `67` | `EX_NOUSER` | User not found |
| `68` | `EX_NOHOST` | Host not found |
| `69` | `EX_UNAVAILABLE` | Required service or resource unavailable |
| `70` | `EX_SOFTWARE` | Internal software error |
| `71` | `EX_OSERR` | OS-level error (fork failed, out of memory, etc.) |
| `72` | `EX_OSFILE` | System file missing or unreadable |
| `73` | `EX_CANTCREAT` | Output file cannot be created |
| `74` | `EX_IOERR` | I/O error |
| `75` | `EX_TEMPFAIL` | Temporary failure — caller may retry |
| `76` | `EX_PROTOCOL` | Remote protocol error |
| `77` | `EX_NOPERM` | Insufficient permissions (not root, missing capability) |
| `78` | `EX_CONFIG` | Configuration error |

### Signal-terminated processes

Processes killed by a signal exit with `128 + {signal}`:

| Code | Signal | Common cause |
|------|--------|-------------|
| `130` | `128+2` SIGINT | Ctrl-C |
| `137` | `128+9` SIGKILL | Forced kill |
| `143` | `128+15` SIGTERM | Graceful shutdown request |

### Rules

- `--help` and `--version` always exit `0`
- Unknown flag or bad argument: exit `2` (POSIX misuse) or `64` (EX_USAGE) — be consistent within a project
- Missing required file: exit `66` (EX_NOINPUT)
- Missing permission: exit `77` (EX_NOPERM)
- Config file invalid: exit `78` (EX_CONFIG)
- Never use exit codes outside `0–78` or `128–143` for your own errors — those ranges are reserved
- Scripts: use bare integer `exit N`; Go: `os.Exit(N)`; Rust: `std::process::exit(N)` or `clap` exit handling

## CLI Flags and Argument Parsing

### Standard flags (all interactive scripts, all shells)

| Flag | Short | Behavior |
|------|-------|----------|
| `--help` | `-h` | Print help and exit 0 — never escalate privileges |
| `--version` | `-v` | Print version and exit 0 — never escalate privileges |
| `--debug` | *(none)* | Enable debug output |
| `--no-color` | *(none)* | Disable color output |

- `-h` and `-v` are the **only** short flags defined by default. No other short flags unless explicitly specified in `{project_dir}/IDEA.md`.
- `--debug` and `--no-color` have no short equivalents.
- `--help` and `--version` must **never** require root/sudo — exit immediately with the requested output, regardless of privilege state.

### NO_COLOR support

Every interactive script must honor the `NO_COLOR` environment variable ([no-color.org](https://no-color.org/)):

```bash
# At the top of the script, after variable declarations
if [[ -n "${NO_COLOR}" ]]; then
  # disable all color output
  COLOR_RESET=""
  COLOR_RED=""
  # ... all color vars set to empty string
fi
```

`--no-color` flag sets the same state as `NO_COLOR` being present. Both must be checked; either disables color and emojis in output.

**Note — flag name differs by language by design:** Shell scripts use `--no-color` (a boolean on/off flag). Compiled Go and Rust binaries use `--color auto|yes|no` (a three-value enum that also covers auto-detection). Both conventions honor the `NO_COLOR` env var. Do not apply the Go/Rust `--color` pattern to shell scripts, and do not apply the shell `--no-color` pattern to compiled binaries.

### Argument parsing — use the shell's native parser

**Never write a bare `while`/`case` argument loop unless no parser is available for that shell.** Use the shell-native option parser:

| Shell | Parser | Long option support |
|-------|--------|-------------------|
| bash | `getopt` (external GNU getopt) | Yes — `--long opt` and `--long=opt` both work |
| sh (POSIX) | `getopts` (built-in, short only) or external `getopt` if available | `getopts`: short only; `getopt`: long options |
| zsh | `zparseopts` (built-in) | Yes |
| fish | `argparse` (built-in) | Yes |

**bash — `getopt` pattern:**

```bash
_OPTS="$(getopt -o hv -l help,version,debug,no-color -n "${APPNAME}" -- "$@")" || { __help; exit 1; }
eval set -- "${_OPTS}"
while true; do
  case "$1" in
    -h|--help)     __help; exit 0 ;;
    -v|--version)  __version; exit 0 ;;
    --debug)       SCRIPTNAME_DEBUG=1; shift ;;
    --no-color)    NO_COLOR=1; shift ;;
    --)            shift; break ;;
    *)             break ;;
  esac
done
```

`getopt` normalizes both `--flag value` and `--flag=value` automatically — no manual `=` splitting needed.

**zsh — `zparseopts` pattern:**

```zsh
zparseopts -D -E -- h=opt_help -help=opt_help v=opt_version -version=opt_version -debug=opt_debug -no-color=opt_nocolor
[[ -n "${opt_help}" ]]    && { __help; exit 0 }
[[ -n "${opt_version}" ]] && { __version; exit 0 }
[[ -n "${opt_debug}" ]]   && SCRIPTNAME_DEBUG=1
[[ -n "${opt_nocolor}" ]] && NO_COLOR=1
```

**fish — `argparse` pattern:**

```fish
argparse h/help v/version debug no-color -- $argv
or return 1
if set -q _flag_help;     __help; return 0; end
if set -q _flag_version;  __version; return 0; end
if set -q _flag_debug;    set -g SCRIPTNAME_DEBUG 1; end
if set -q _flag_no_color; set -gx NO_COLOR 1; end
```

**sh (POSIX) — `getopts` for short flags + manual long via `case`:**

```sh
while getopts ":hv-:" opt; do
  case "${opt}" in
    h) __help; exit 0 ;;
    v) __version; exit 0 ;;
    -)
      case "${OPTARG}" in
        help)     __help; exit 0 ;;
        version)  __version; exit 0 ;;
        debug)    SCRIPTNAME_DEBUG=1 ;;
        no-color) NO_COLOR=1 ;;
        *) printf 'Unknown option: --%s\n' "${OPTARG}" >&2; exit 2 ;;
      esac ;;
    *) printf 'Unknown option: -%s\n' "${OPTARG}" >&2; exit 2 ;;
  esac
done
shift $((OPTIND - 1))
```

Note: POSIX `getopts` with `-:` trick handles `--long` but NOT `--long=value`. Use external `getopt` if `=` syntax is required in sh scripts.

## Library Scripts — Sourced vs Direct Execution

Every library/shared script must detect whether it is being sourced or run directly and act accordingly — sourced libraries define functions and variables only; direct execution can show help, run self-tests, or error out.

Per-shell detection pattern:

**bash:**
```bash
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  # running directly
  __main "$@"
fi
```

**sh (POSIX):**
```sh
# $0 is the interpreter name when sourced (e.g. "sh" or "-sh")
# Use parameter expansion (no basename fork) — strip leading path; compare to bare $0
_self="${0##*/}"
case "$0" in
  *"${_self}")
    # running directly — $0 matches the script name
    __main "$@"
    ;;
esac
```

**zsh:**
```zsh
if [[ "${ZSH_EVAL_CONTEXT}" == "toplevel" ]]; then
  # running directly
  __main "$@"
fi
```

**fish:**
```fish
if status is-script
  # running directly (not sourced)
  __main $argv
end
```

When sourced: only define functions and set variables — do not execute side effects, print output, or exit.
When run directly: print help, run self-tests, or call `__main`.

## Performance — No UUOC, Minimize Forks

Every `$(...)`, pipe, and external command spawns a subprocess. Minimize forks in all shells by preferring built-ins and parameter expansion over external commands. These rules apply universally — bash, sh, zsh, fish.

**File reading:**
```bash
# BAD
contents="$(cat file)"
cat file | grep pattern

# GOOD
contents="$(< file)"
grep pattern file
```

**Path manipulation — parameter expansion, NOT basename/dirname:**
```bash
# BAD
name="$(basename -- "$path")"
dir="$(dirname -- "$path")"

# GOOD
name="${path##*/}"      # basename
dir="${path%/*}"        # dirname
stem="${name%.ext}"     # strip extension
```

**String matching — `[[ ]]`, NOT `echo | grep`:**
```bash
# BAD
if echo "$var" | grep -q "pattern"; then

# GOOD
if [[ "$var" == *"pattern"* ]]; then
```

**Regex — `=~` + `BASH_REMATCH`, NOT `echo | grep -E`:**
```bash
if [[ "$url" =~ ^(https?):// ]]; then
  protocol="${BASH_REMATCH[1]}"
fi
```

**Splitting — parameter expansion, NOT `echo | cut`:**
```bash
# BAD:  echo "$ver" | cut -d. -f1
# GOOD: "${ver%%.*}"
```

**Parsing — `read`, NOT `cat | awk` when bash suffices:**
```bash
# BAD:  cat /proc/loadavg | awk '{print $1}'
# GOOD: read -r load1 load5 _ _ _ < /proc/loadavg
```

**Stdin — let tools read directly, do NOT `cat - |` into them:**
```bash
# BAD:  cat - | sed 's/x/y/'
# GOOD: sed 's/x/y/'
```

**grep — always use `--` before the query:**
```bash
# BAD:  grep -r "pattern" file
# BAD:  grep "pattern" file
# GOOD: grep -r -- "pattern" file
```

`--` signals end of options, preventing a query that starts with `-` from being misinterpreted as a flag. Apply to all `grep` invocations.

**Never use grep aliases — they may not exist:**

| Never | Use instead |
|-------|------------|
| `egrep` | `grep -E` |
| `fgrep` | `grep -F` |
| `rgrep` | `grep -r` |

Always `grep {flags} -- {query}` — no exceptions.

## Terminal Display — Alt Buffer and ANSI Escapes

### Alt buffer

Any script that is a TUI or acts as a TUI (interactive menus, full-screen output, progress UIs) **must** use the alternate screen buffer. This preserves the user's scrollback and restores the terminal cleanly on exit.

```bash
# Enter alt buffer + set blinking I-beam cursor
printf '\e[?1049h\e[5 q'

# Always restore on exit — use a trap so it fires even on Ctrl-C
trap 'printf "\e[?1049l\e[0 q"' EXIT
```

- `\e[?1049h` — enter alternate screen buffer
- `\e[?1049l` — leave alternate screen buffer (restore normal screen)
- `\e[5 q` — blinking I-beam cursor (preferred)
- `\e[0 q` — restore terminal default cursor on exit

The `EXIT` trap must be set **before** entering the alt buffer so it fires on all exit paths including signals.

Non-TUI scripts (one-shot output, batch processing, log writers) must NOT enter the alt buffer.

### ANSI escapes — never tput

`tput` forks a subprocess for every call — forbidden under the minimize-forks rule. Use ANSI escape sequences directly via `printf`.

| tput call | ANSI equivalent |
|-----------|----------------|
| `tput smcup` | `printf '\e[?1049h'` |
| `tput rmcup` | `printf '\e[?1049l'` |
| `tput clear` | `printf '\e[2J\e[H'` |
| `tput cup R C` | `printf '\e[%d;%dH' $((R+1)) $((C+1))'` |
| `tput civis` | `printf '\e[?25l'` |
| `tput cnorm` | `printf '\e[?25h'` |
| `tput bold` | `printf '\e[1m'` |
| `tput sgr0` | `printf '\e[0m'` |
| `tput setaf 1` | `printf '\e[31m'` |
| `tput setab 2` | `printf '\e[42m'` |

Use `printf` — never `echo -e` (not portable) or `echo -n` for escape sequences.

Color and cursor sequences must be suppressed when `NO_COLOR` is set or `--no-color` is passed — wrap them in a helper:

```bash
__ansi() {
  # Emit ANSI escape only when color is enabled
  if [[ -z "${NO_COLOR}" ]]; then
    printf '%s' "$1"
  fi
}
```

---

## Documentation Triple Sync

Every script change requires updating all three in the same commit:
1. `__help()` inside the script itself
2. `man/{script}.1`
3. `completions/_{script}_completions.bash`

**Exempt from triple sync:** hook scripts, sourced library files, and non-interactive scripts that are not user-facing commands. These do not have `__help()`, man pages, or completions.

## Self-Contained Scripts

Scripts must bundle all logic they need — no `source` or `.` includes:

```bash
# BAD
source /path/to/lib.sh
. "$SCRIPT_SRC_DIR/helpers.sh"

# GOOD — inline the required logic
```

**Exception:** profile/shell init scripts are explicitly designed to source files: `.bashrc`, `.bash_profile`, `.profile`, `.zshrc`, `.zshenv`, `.zprofile`, `.fishrc`, and analogues. These may use `source`/`.` freely.

## Standard Utility Functions

These functions are defined in scripts when needed — not included by default. Copy verbatim; do not rename or alter signatures. All variables are `local`; functions work as direct calls or in command substitution (`var="$(__determine_domain_name)"`).

### `__determine_domain_name`

Returns the runtime domain name. Tries `hostname -d` first; falls back to stripping the first label from `hostname -f`. Returns 1 if both fail.

```bash
__determine_domain_name() {
  local domain
  domain="$(hostname -d 2>/dev/null)"
  if [[ -n "$domain" ]]; then
    printf '%s\n' "$domain"
    return 0
  fi
  local fqdn
  fqdn="$(hostname -f 2>/dev/null)"
  if [[ -n "$fqdn" ]] && [[ "$fqdn" == *.* ]]; then
    printf '%s\n' "${fqdn#*.}"
    return 0
  fi
  return 1
}
```

### `__determine_hostname_name`

Returns the runtime FQDN via `hostname -f`. Returns 1 if unavailable.

```bash
__determine_hostname_name() {
  local fqdn
  fqdn="$(hostname -f 2>/dev/null)"
  if [[ -n "$fqdn" ]]; then
    printf '%s\n' "$fqdn"
    return 0
  fi
  return 1
}
```

### `__validate__hosts_fqdn`

Returns 0 if `$1` is a valid FQDN (`domain.tld` or `host.domain.tld`, etc.), 1 otherwise. Enforces: at least two labels, each label 1–63 chars, alphanumeric + interior hyphens only, total length ≤ 253.

```bash
__validate__hosts_fqdn() {
  local fqdn="${1:-}"
  [[ -z "$fqdn" ]] && return 1
  [[ ${#fqdn} -gt 253 ]] && return 1
  [[ "$fqdn" != *.* ]] && return 1
  local label labels
  local IFS='.'
  read -ra labels <<< "$fqdn"
  for label in "${labels[@]}"; do
    [[ -z "$label" ]] && return 1
    [[ ${#label} -gt 63 ]] && return 1
    [[ "$label" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?$ ]] || return 1
  done
  return 0
}
```

### `__download_all_scripts_from_github`

Downloads every file from the `scripts/` directory of a GitHub repo via the API (paginated) and saves them to `$1` with `chmod 755`. Requires `curl` and `jq`.

- `GITHUB_RAW_REPO` — `{userORorg}/{repo}` path; defaults to `{project_org}/{project_name}`
- `$1` — destination directory; typically `/usr/local/bin` (system) or `~/.local/bin` (user)

```bash
__download_all_scripts_from_github() {
  local dest="${1:?Usage: __download_all_scripts_from_github <dest_dir>}"
  local GITHUB_RAW_REPO="${GITHUB_RAW_REPO:-{project_org}/{project_name}}"
  local api_base="https://api.github.com/repos/${GITHUB_RAW_REPO}/contents/scripts"
  local raw_base="https://raw.githubusercontent.com/${GITHUB_RAW_REPO}/main/scripts"
  local page=1
  local files file response

  mkdir -p "$dest" || return 1

  while :; do
    response="$(curl -q -LSs "${api_base}?per_page=100&page=${page}")" || return 1
    mapfile -t files < <(printf '%s' "$response" | jq -r '.[] | select(.type=="file") | .name')
    [[ ${#files[@]} -eq 0 ]] && break
    for file in "${files[@]}"; do
      curl -q -LSs "${raw_base}/${file}" -o "${dest}/${file}" || return 1
      chmod 755 "${dest}/${file}"
    done
    (( ${#files[@]} < 100 )) && break
    (( page++ ))
  done
}
```

### `__does_host_have_valid_ip6`

Returns 0 if the host has at least one global-scope IPv6 address, 1 otherwise.

```bash
__does_host_have_valid_ip6() {
  local addr
  addr="$(ip -6 addr show scope global 2>/dev/null | awk '/inet6/ {print $2; exit}')"
  [[ -n "$addr" ]] && return 0
  return 1
}
```

### `__get_network_device`

Returns the name of the network device that holds the global default route. Accepted prefixes: `eth*`, `en*`, `wg*`, `br*`, `vmbr*`. Excluded: `incus*`, `docker*`, `lo`, `veth*`, and all other virtual devices. Returns 1 if no suitable device is found.

```bash
__get_network_device() {
  local dev candidate
  # Prefer the device on the default IPv4 route
  candidate="$(ip route show default 2>/dev/null | awk '/^default/ {for(i=1;i<=NF;i++) if($i=="dev"){print $(i+1); exit}}')"
  case "${candidate:-}" in
    eth*|en*|wg*|br*|vmbr*) printf '%s\n' "$candidate"; return 0 ;;
  esac
  # Fallback: first UP device matching allowed prefixes
  while IFS= read -r dev; do
    case "$dev" in
      eth*|en*|wg*|br*|vmbr*) printf '%s\n' "$dev"; return 0 ;;
    esac
  done < <(ip link show up 2>/dev/null | awk -F': ' '/^[0-9]+:/ {print $2}' | cut -d'@' -f1)
  return 1
}
```

### `__is_ip4_public`

Returns 0 if `$1` is a public (globally routable) IPv4 address, 1 if private, reserved, or invalid. Covers RFC1918, loopback, link-local, CGNAT (100.64/10), and multicast/reserved (224+).

```bash
__is_ip4_public() {
  local ip="${1:-}"
  [[ -z "$ip" ]] && return 1
  [[ "$ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || return 1
  local a b c d
  IFS='.' read -r a b c d <<< "$ip"
  (( a == 0 )) && return 1                              # 0.0.0.0/8
  (( a == 10 )) && return 1                             # 10.0.0.0/8
  (( a == 127 )) && return 1                            # 127.0.0.0/8 loopback
  (( a == 100 && b >= 64 && b <= 127 )) && return 1    # 100.64.0.0/10 CGNAT
  (( a == 169 && b == 254 )) && return 1               # 169.254.0.0/16 link-local
  (( a == 172 && b >= 16 && b <= 31 )) && return 1     # 172.16.0.0/12
  (( a == 192 && b == 0 && c == 0 )) && return 1       # 192.0.0.0/24 IETF protocol
  (( a == 192 && b == 0 && c == 2 )) && return 1       # 192.0.2.0/24 TEST-NET-1
  (( a == 192 && b == 168 )) && return 1               # 192.168.0.0/16
  (( a == 198 && b == 51 && c == 100 )) && return 1    # 198.51.100.0/24 TEST-NET-2
  (( a == 203 && b == 0 && c == 113 )) && return 1     # 203.0.113.0/24 TEST-NET-3
  (( a >= 224 )) && return 1                            # 224.0.0.0+ multicast/reserved
  return 0
}
```

### `__is_ip6_public`

Returns 0 if `$1` is a public (globally routable) IPv6 address, 1 if private, reserved, or invalid. Excludes loopback (`::1`), unspecified (`::`), link-local (`fe80::/10`), unique-local (`fc00::/7`), and IPv4-mapped (`::ffff:`). Accepts only global unicast (`2000::/3`, i.e. addresses starting with `2` or `3`).

```bash
__is_ip6_public() {
  local ip="${1:-}"
  [[ -z "$ip" ]] && return 1
  ip="${ip%%\%*}"          # strip zone ID (e.g. fe80::1%eth0)
  local low="${ip,,}"      # lowercase for pattern matching
  [[ "$low" == "::" || "$low" == "::1" ]] && return 1
  [[ "$low" =~ ^fe[89ab][0-9a-f]?:  ]] && return 1    # fe80::/10 link-local
  [[ "$low" =~ ^f[cd]               ]] && return 1    # fc00::/7  unique-local
  [[ "$low" =~ ^::ffff:             ]] && return 1    # IPv4-mapped
  [[ "$low" =~ ^[23]                ]] || return 1    # must be global unicast
  return 0
}
```

### `__get_hosts_ip4_address`

Returns the host's public IPv4 address. If `IP4_ADDRESS` is already set in the environment, returns it immediately (no curl). Otherwise tries `ifcfg.us` → `ifconfig.co` → `checkip.amazonaws.com` in order, forcing IPv4 with `curl -4`. Returns 1 if all sources fail.

```bash
__get_hosts_ip4_address() {
  if [[ -n "${IP4_ADDRESS:-}" ]]; then
    printf '%s\n' "$IP4_ADDRESS"
    return 0
  fi
  local ip url
  for url in "https://ifcfg.us/ip" "https://ifconfig.co/ip" "https://checkip.amazonaws.com"; do
    ip="$(curl -4 -q -LSs --max-time 5 "$url" 2>/dev/null | tr -d '[:space:]')"
    if [[ -n "$ip" ]] && __is_ip4_public "$ip"; then
      printf '%s\n' "$ip"
      return 0
    fi
  done
  return 1
}
```

### `__get_hosts_ip6_address`

Returns the host's public IPv6 address. Skips entirely (returns 1) if `__does_host_have_valid_ip6` fails. If `IP6_ADDRESS` is already set in the environment, returns it immediately. Otherwise tries `ifcfg.us` → `ifconfig.co` → `api6.ipify.org` in order, forcing IPv6 with `curl -6`. Returns 1 if all sources fail.

```bash
__get_hosts_ip6_address() {
  __does_host_have_valid_ip6 || return 1
  if [[ -n "${IP6_ADDRESS:-}" ]]; then
    printf '%s\n' "$IP6_ADDRESS"
    return 0
  fi
  local ip url
  for url in "https://ifcfg.us/ip" "https://ifconfig.co/ip" "https://api6.ipify.org"; do
    ip="$(curl -6 -q -LSs --max-time 5 "$url" 2>/dev/null | tr -d '[:space:]')"
    if [[ -n "$ip" ]] && __is_ip6_public "$ip"; then
      printf '%s\n' "$ip"
      return 0
    fi
  done
  return 1
}
```

## Testing

Syntax checking is interpreter-aware — use the right tool per shebang:

| Shebang | Syntax check | Linter |
|---------|-------------|--------|
| `#!/usr/bin/env bash` / `#!/bin/bash` | `bash -n scriptname` | `shellcheck -s bash scriptname` |
| `#!/usr/bin/env sh` / `#!/bin/sh` | `sh -n scriptname` | `shellcheck -s sh scriptname` |
| `#!/usr/bin/env zsh` | `zsh -n scriptname` | no shellcheck (unsupported) |
| `#!/usr/bin/env fish` | `fish -n scriptname` | no shellcheck (unsupported) |
| `#!/usr/bin/env python3` etc. | language-specific (`python3 -m py_compile`) | language-specific linter |
| `.ps1` | `pwsh -NonInteractive -File scriptname` | PSScriptAnalyzer |
| `.cmd` / `.bat` | no standard checker | no standard linter |

- Syntax checks (`bash -n`, `sh -n`, `zsh -n`, `fish -n`) and `--help`/`--version` invocations are safe to run directly on the host — they only print and exit 0, with no side effects
- Functional testing (anything that mutates state, installs, calls external services, or runs as root) must run inside Incus (preferred) or Docker — never directly on host

## Security

- No `curl -q -LSsf {url} | sh` inside scripts — never pipe a fetched URL into a shell from within a script where the user can't inspect what's being executed
- `curl -q -LSsf {url} | sh` **is acceptable in documentation** (README, install docs) — it is better UX than `curl -o && chmod +x && ./script`. When used in docs, always place immediately above the code block:
  1. A plain-language note explaining what the script does
  2. A direct link to the raw script URL so users can inspect it before running
- **The shell in the pipe must match the script's interpreter** — check the shebang and use the correct shell. `curl -q -LSsf {url} | bash` for bash scripts, `curl -q -LSsf {url} | zsh` for zsh scripts, etc. Never pipe a script into a mismatched shell (e.g. piping a fish script into `bash` will break or silently misbehave)
- Use `sudo tee` instead of redirect for privileged writes

## Pipe Safety

Scripts **should** be pipe-safe — safe to run via `curl … | sh` or any pipeline without hanging or misbehaving.

**Rules:**
- Never read from stdin unconditionally — always check first
- Never prompt interactively (e.g. `read -p`) without confirming stdin is a terminal
- Side-effect-free by default: no writes, no installs, no destructive ops before the user has had a chance to inspect (satisfied by the doc-link requirement in Security above)

**Stdin detection — use `[ -t 0 ]` (POSIX, works on Linux/macOS/BSD):**

```sh
if [ -t 0 ]; then
  # stdin is a terminal — interactive input is safe
else
  # stdin is a pipe or redirect — skip prompts, use defaults
fi
```

**Cross-platform notes:**

| Platform | Detection | Notes |
|----------|-----------|-------|
| Linux / macOS / BSD | `[ -t 0 ]` | POSIX; works in sh, bash, zsh, dash |
| Windows (pwsh) | `[Console]::IsInputRedirected` | PowerShell only |
| Windows (cmd) | Not reliably detectable | Avoid interactive reads in `.cmd` scripts entirely |

**Scripts that accept piped input** (e.g. `cat file | script`) should auto-detect and switch modes — interactive prompts become no-ops or use flag-supplied defaults; output stays machine-readable (no color, no spinners) when stdout is not a terminal (`[ -t 1 ]`).
