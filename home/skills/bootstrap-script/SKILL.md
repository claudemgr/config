---
name: bootstrap-script
description: Bootstrap a new or existing script-only project. Creates the main script, .editorconfig, .shellcheckrc (not fish), and standard project files (AI.md, IDEA.md, CLAUDE.md, .gitignore, README.md, LICENSE.md). No workflows, no toolchain, no Makefile. Auto-invoke when user asks to create/init a script project, install script, or setup script.
argument-hint: [sh|bash|zsh|fish] [script-name]
---

# Bootstrap a Script Project

Bootstrap a script-type project in `{project_dir}`. Script projects contain one or more shell scripts — no compiled binaries, no CI workflows, no toolchain images.

## Step 1 — Resolve arguments

Parse `$ARGUMENTS` as: `[shell] [script-name]`

**Shell** (first arg, optional):
- Accepted values: `sh`, `bash`, `zsh`, `fish`
- Default: `sh` (POSIX)
- If omitted but a script file already exists, detect from its shebang (`#!/usr/bin/env bash` → bash, etc.) or extension (`.sh` → sh, `.bash` → bash, `.zsh` → zsh, `.fish` → fish). No extension → sh.

**Script name** (second arg, optional):
- Default: `install.sh` for sh/bash, `install.zsh` for zsh, `install.fish` for fish
- Extension rules: bash/sh → `.sh`; zsh → `.zsh`; fish → `.fish`
- If a name is given without extension, append the correct extension for the shell.

## Step 2 — Create the script file

If the script file does not already exist, create it. If it exists, leave it untouched.

Use the header template from `script_conventions.md`. Fill in:
- `{shell}` — resolved shell name
- `##@Version` and `VERSION=` — run `date +'%Y%m%d%H%M-git'` and use the result
- `@@Created` — current date/time in full weekday format: e.g. `Monday, May 19, 2026 14:30 EDT`
- `@@File` — the script filename
- `@@Description` — one sentence describing what the script does (infer from name; ask if unclear)
- `@@Template` — `shell/{shell}`
- All other `@@` fields — leave empty (just the field label, no value)

After the header, add the standard boilerplate variables for the resolved shell (see `script_conventions.md` Shell-specific differences table). Then add `set -euo pipefail` (bash/zsh) or `set -eu` (sh). Fish gets neither.

**ENV var shadowing rule — enforced always:**
Never assign directly to a name that is an existing system environment variable. Always use the env var as a fallback:
```sh
# WRONG — shadows system env
HOSTNAME="$(hostname -f)"
USER="admin"

# CORRECT — preserves existing env, falls back to runtime value
APP_FQDN="${APP_FQDN:-$(hostname -f)}"
RUN_USER="${SUDO_USER:-${USER}}"
```
Known system env vars never to shadow: `HOME`, `USER`, `LOGNAME`, `SHELL`, `PATH`, `PWD`, `OLDPWD`, `HOSTNAME`, `HOST`, `TERM`, `LANG`, `TZ`, `EDITOR`, `VISUAL`, `PAGER`, `UID`, `EUID`, `GID`, `SHLVL`, `IFS`, `PS1`–`PS4`, `OPTIND`, `OPTARG`, and all `BASH_*`, `ZSH_*`, `FISH_*` vars. Use project-prefixed names (`APP_*`, `INSTALL_*`, etc.) for script-specific values.

End the script with the vim modeline (`# ex: ts=2 sw=2 et filetype={vim-filetype}`) — see `script_conventions.md` for the filetype per shell.

## Step 3 — Create .editorconfig

If `.editorconfig` does not already exist, create it using the template below (verbatim — do not alter content):

```
!`cat "${CLAUDE_SKILL_DIR}/editorconfig.template"`
```

## Step 4 — Create .shellcheckrc

Skip entirely if shell is `fish`.

If `.shellcheckrc` does not already exist, create it using the template below, then change the `shell=` line to match the target shell:
- `sh` → `shell=sh`
- `bash` → `shell=bash`
- `zsh` → `shell=bash` (shellcheck has no native zsh support; bash is the closest valid value)

Template:
```
!`cat "${CLAUDE_SKILL_DIR}/shellcheckrc.template"`
```

## Step 5 — Create standard project files

Create only the files that do not already exist. Never overwrite.

**.gitignore** — standard ignores for a shell script project:
```
.no_push
.no_git
.installed
.env
app.env
default.env
*.local
.claude/settings.local.json
.claude/backups/
.claude/cache/
.claude/file-history/
.claude/history.jsonl
.claude/projects/
.claude/statsFile
.claude/*.lock
```

**CLAUDE.md** — minimal loader:
```markdown
# {project_name}

Read `AI.md` and `IDEA.md` before acting on this project.
```

**AI.md** — minimal spec stub (fill `{project_name}` from the directory name):
```markdown
# {project_name} — AI Spec

## PART 0 — Project Identity

- **Name:** {project_name}
- **Type:** shell script
- **Shell:** {shell}
- **Primary script:** {script_name}
- **Description:** {one-sentence description}
```

**IDEA.md** — stub:
```markdown
# {project_name} — Project Description

{One paragraph: what this script does, for whom, and why it exists.}
```

**README.md** — minimal stub following canonical section order from `project_files.md`:
```markdown
# {project_name}

{One-paragraph description.}

---

## 📦 Install

\`\`\`sh
curl -LSs https://raw.githubusercontent.com/{org}/{project_name}/main/{script_name} \
  -o /usr/local/bin/{script_name_no_ext} && chmod +x /usr/local/bin/{script_name_no_ext}
\`\`\`

---

## 🛠️ Development

\`\`\`sh
# Clone and run directly
git clone https://github.com/{org}/{project_name}
./{script_name} --help
\`\`\`

---

## 📄 License

MIT — see [LICENSE.md](LICENSE.md)
```

**LICENSE.md** — MIT license with current year and author `Jason Hempstead, Casjays Developments`.

## Step 6 — Initialize git

If `.git` does not exist, run `git init && git add -A` to stage everything. Do not commit — let the user run `gitcommit` when ready.

If `.git` already exists, run `git add -A` to stage new files.

## Step 7 — Report

List every file created (or "already existed — skipped") in a compact table. Note any fields in AI.md/IDEA.md/README.md that need the user's input.
