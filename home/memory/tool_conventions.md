---
name: Tool conventions
description: Default flags and usage rules for curl, wget, grep, provider CLIs (gh/glab/tea), act, images, and python3
type: user
---

## General

Always use the right tool for the job if installed: `jq` for JSON, `yq` for YAML, `bc` for math, `grep`/`sed`/`awk` for text, `git` for version control.

Use `python3` only when no purpose-built tool can handle the task cleanly.

## curl

Default: `curl -q -LSs {url}`
- `-q` suppresses config file · `-L` follows redirects · `-S` shows errors · `-s` suppresses progress meter
- Never add `-f`/`--fail` by default — it suppresses the response body on HTTP errors, hiding diagnostic information
- Only add `-f` in scripts or Makefiles where silent failure and a non-zero exit code are explicitly the right behaviour
- Only add `-#` (or drop `-s`) when a progress bar is explicitly needed

## wget

Default: `wget -q {url}` — suppresses all output except errors. Only omit `-q` or add `--show-progress` when a progress bar is explicitly needed.

## grep

Default: always `grep {flags} -- {query}` — `--` prevents a query starting with `-` being treated as a flag.

Never use `egrep`, `fgrep`, or `rgrep` — use `grep -E`, `grep -F`, `grep -r` instead. This applies to every grep invocation, including in Bash tool calls.

## Provider CLIs

Prefer over raw `curl` for provider API operations. If not installed, download and install the binary before use — never fall back to raw `curl` for provider operations when a CLI exists for that provider:

| CLI | License | Purpose | Latest release |
|-----|---------|---------|----------------|
| `gh` | Apache-2.0 | GitHub — issues, PRs, releases, repo ops | `https://github.com/cli/cli/releases/latest` |
| `glab` | MIT | GitLab — same operations | `https://gitlab.com/gitlab-org/cli/-/releases` |
| `tea` | MIT | Gitea and Forgejo (compatible API) | `https://gitea.com/gitea/tea/releases` |

**Auto-install when missing** — detect arch (`uname -m`: `x86_64`→`amd64`, `aarch64`→`arm64`), download the latest Linux binary from the provider's release page, install to `/usr/local/bin` if running as root or `sudo -n true 2>/dev/null` succeeds, otherwise `~/.local/bin`. Always `mkdir -p` the target dir and `chmod +x` after download. Confirm with the user before installing to `/usr/local/bin` via sudo.

`curl` is acceptable when there is a reason: CLI not authenticated/configured, operation is simpler or faster without the CLI, public endpoint that needs no auth, or operation has no CLI equivalent.

## act

`act` (nektos/act, MIT) — validate and run GitHub Actions workflows locally before pushing. Install: `setupmgr act`.

Key uses:
- `act --list -W {file}` — validate a workflow file (parses YAML + resolves job graph, exits non-zero on errors)
- `act -j {job}` — run a specific job locally

**Required pre-commit:** if `.github/workflows/` files are staged, `act --list` must pass on each before `gitcommit` runs — the `validate-workflows.sh` hook enforces this automatically. Never use `act` to bypass CI gates — it is a pre-push verification tool only.

## Images

Always convert before reading — max 1280px longest side, WebP target, fallback chain `convert` → `ffmpeg` → `vips` → original. URL images: curl to tempdir first, then convert, then read. See `image_conventions.md`.
