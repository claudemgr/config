---
name: Bash script conventions
description: Code standards, performance rules, and documentation requirements for CasjaysDev bash scripts
type: user
---

## Interpreter Detection

The shebang line or file extension determines which interpreter's conventions apply. Always check before editing.

| Shebang / Extension | Interpreter | Apply bash rules? |
|---|---|---|
| `#!/usr/bin/env bash` / `#!/bin/bash` | Bash | Yes — full bash rules, builtins, `[[ ]]`, etc. |
| `#!/usr/bin/env sh` / `#!/bin/sh` | POSIX sh | No — POSIX only; no bashisms, use `[ ]` not `[[ ]]` |
| `#!/usr/bin/env zsh` | Zsh | No — zsh idioms |
| `#!/usr/bin/env fish` | Fish | No — fish idioms (`if`/`end`, `set`, etc.) |
| `#!/usr/bin/env python3` etc. | Python/Ruby/etc. | No — use that language's conventions |
| `.ps1` | PowerShell | No — PowerShell cmdlets, `$variables`, `Verb-Noun` style |
| `.cmd` / `.bat` | Windows CMD | No — `@echo off`, `%variables%`, `GOTO` patterns |

**When there is no shebang** (e.g. a sourced library), infer from the calling context or ask.

## Code Standards

- **Functions**: prefix with `__` (e.g. `__my_function`)
- **Variables**: prefix with `{SCRIPTNAME}_` in uppercase (e.g. `MYSCRIPT_VAR`)
- **Comments**: always ABOVE the code they describe — NEVER inline at end of line
- **Control flow**: prefer `if/else` over `&&`/`||` chains for readability
- **Newlines**: always add a newline at end of file
- **Headers**: update `@@Version` (`YYYYMMDDHHMM-git`) and `@@Changelog` on every change
- **Line length**: if a complete command is ≤180 characters, write it on a single line — including pipelines. Only split when the line exceeds 180 characters, or when the command contains an embedded program that inherently spans lines (e.g. a multi-line `awk` or `sed` script)

## Bash Performance — No UUOC, Minimize Forks

Every `$(...)`, pipe, and external command spawns a subprocess. Prefer bash built-ins.

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

## Documentation Triple Sync

Every script change requires updating all three in the same commit:
1. `__help()` inside the script itself
2. `man/{script}.1`
3. `completions/_{script}_completions.bash`

## Testing

- Syntax-check every script: `bash -n bin/scriptname`
- Run `./bin/scriptname --help` to confirm help output renders correctly
- Test inside Incus (preferred) or Docker — never directly on host

## Security

- No `curl | sh` inside scripts — never pipe a fetched URL into a shell from within a script where the user can't inspect what's being executed
- `curl | sh` **is acceptable in documentation** (README, install docs) — it is better UX than `curl -o && chmod +x && ./script`. When used in docs, always place immediately above the code block:
  1. A plain-language note explaining what the script does
  2. A direct link to the raw script URL so users can inspect it before running
- **The shell in the pipe must match the script's interpreter** — check the shebang and use the correct shell. `curl ... | bash` for bash scripts, `curl ... | zsh` for zsh scripts, etc. Never pipe a script into a mismatched shell (e.g. piping a fish script into `bash` will break or silently misbehave)
- Use `sudo tee` instead of redirect for privileged writes
