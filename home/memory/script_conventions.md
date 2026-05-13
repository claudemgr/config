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
- `VERSION="YYYYMMDDHHMM-git"` is the literal format string — used for `--version` output
- The `shellcheck disable` line only appears in shells shellcheck supports — see table below

### Shell-specific differences

| Item | bash | sh | zsh | fish | ps1 | cmd/bat |
|------|------|----|-----|------|-----|---------|
| shellcheck shell line | `# shellcheck shell=bash` | `# shellcheck shell=sh` | *(omit)* | *(omit)* | *(omit)* | *(omit)* |
| shellcheck disable | `# shellcheck disable=SC1001,SC1003,SC2001,SC2003,SC2016,SC2031,SC2090,SC2115,SC2120,SC2155,SC2199,SC2229,SC2317,SC2329` | same as bash | `# shellcheck disable=all` | *(omit entire line)* | *(omit)* | *(omit)* |
| `APPNAME` | `"${0##*/}"` | `"${0##*/}"` | `"${0:t}"` | `(path basename (status filename))` |
| `SCRIPT_SRC_DIR` | `"${BASH_SOURCE%/*}"` | `"$(dirname -- "$0")"` | `"${0:A:h}"` | `(path dirname (status filename))` |
| `SET_UID` | `"${UID}"` | `"$(id -u)"` | `"${UID}"` | `(id -u)` |
| `__cmd_exists` | `command -v "$1" &>/dev/null` | `command -v "$1" >/dev/null 2>&1` | `(( $+commands[$1] ))` | `command -q $argv[1]` |
| `__function_exists` | `declare -F "$1" &>/dev/null` | `case "$(type "$1" 2>/dev/null)" in *function*)` | `(( $+functions[$1] ))` | `functions -q $argv[1]` |
| color escapes | `\e[` | `\033[` | `\e[` | `\e[` |
| variables | `VAR=value` | `VAR=value` | `VAR=value` | `set -g VAR value` |
| vim modeline filetype | `filetype=sh` | `filetype=sh` | `filetype=zsh` | `filetype=fish` |

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

## Code Standards

- **Functions**: ALL functions prefixed with `__` regardless of shell — `__my_function() {}` (bash/sh/zsh), `function __my_function` (fish). No exceptions.
- **Variables**:
  - Global vars: `{SCRIPTNAME}_{VAR}` in uppercase (e.g. `MYSCRIPT_VAR`) — `{SCRIPTNAME}` is the script filename without extension, uppercased
  - Function-scoped vars: declare with `local` in bash/zsh; `set -l` in fish; plain assignment in sh (no `local` in POSIX sh unless targeting bash/zsh)
  - Always use `_` (underscore) — never `-` (hyphen) in variable or function names
  - Exceptions to prefix rule: well-known globals (`VERSION`, `APPNAME`, `RUN_USER`, `SET_UID`, `SCRIPT_SRC_DIR`, `HOME`, `PATH`, `USER`, `PWD`), loop variables, single-letter scratch vars
- **Comments**: always ABOVE the code they describe — NEVER inline at end of line
- **Control flow**: always use `if/elif/else` — never `&&`/`||` chains for logic flow. `&&`/`||` are acceptable only for one-liner guards (`command || return 1`) not as substitutes for `if/elif/else` blocks
- **Newlines**: always add a newline at end of file
- **Headers**: update `@@Version` (`YYYYMMDDHHMM-git`) and `@@Changelog` on every change
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

- `-h` and `-v` are the **only** short flags defined by default. No other short flags unless explicitly specified in `IDEA.md`.
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
case "$0" in
  *"$(basename -- "$0")")
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

- Run `./bin/scriptname --help` to confirm help output renders correctly
- Test inside Incus (preferred) or Docker — never directly on host

## Security

- No `curl -q -LSsf {url} | sh` inside scripts — never pipe a fetched URL into a shell from within a script where the user can't inspect what's being executed
- `curl -q -LSsf {url} | sh` **is acceptable in documentation** (README, install docs) — it is better UX than `curl -o && chmod +x && ./script`. When used in docs, always place immediately above the code block:
  1. A plain-language note explaining what the script does
  2. A direct link to the raw script URL so users can inspect it before running
- **The shell in the pipe must match the script's interpreter** — check the shebang and use the correct shell. `curl -q -LSsf {url} | bash` for bash scripts, `curl -q -LSsf {url} | zsh` for zsh scripts, etc. Never pipe a script into a mismatched shell (e.g. piping a fish script into `bash` will break or silently misbehave)
- Use `sudo tee` instead of redirect for privileged writes
