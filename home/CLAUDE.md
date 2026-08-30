# Claude Rules

## Session Start
Before any work, sync `{project_dir}` with the remote:

1. `git status --porcelain` — check for uncommitted changes
2. If dirty: `git stash push -m "session-start auto-stash"`
3. `git pull`
4. If stashed: `git stash pop`
5. If `stash pop` conflicts: report the conflicting files and wait — never auto-resolve merge conflicts; let the user decide

If the pull fails (no remote, offline, branch diverged): report it and wait — never start work on a potentially stale tree.

**`/clear` note:** `SessionStart` hooks (including `session-start.sh`'s project_dir context injection) are documented to fire on `/clear` but do not, due to a confirmed upstream Claude Code bug ([anthropics/claude-code#34072](https://github.com/anthropics/claude-code/issues/34072), closed not-planned). This isn't a gap in practice: `{project_dir}` is already self-derived from `git rev-parse --show-toplevel`, falling back to `$PWD` when not in a git repo, per the `Working Directory & Path Resolution` rule below, not from the hook's injected text — so re-run this Session Start sequence yourself after any `/clear` using that same resolution; don't wait for hook-injected context that won't arrive.

## Global Memory
Read `~/.claude/memory/MEMORY.md` at session start and load referenced files as needed.

**Follow refs after, not during:** when a file references another file ("see `x.md`", "See PART X"), finish the portion you set out to read (whole file, section, or PART slice) first; queue referenced files and load them afterward. A reference never interrupts or replaces the remainder of what you were reading — after reading the referenced content, return to the next line and continue.

Provider-specific convention files (`github_conventions.md`, `gitlab_conventions.md`, `gitea_conventions.md`, `forgejo_conventions.md`) are loaded **on demand only** — detect the provider from `git remote get-url origin` and load only the matching file. Never pre-load all provider files.

**Large memory files load by section, not whole** — for any referenced memory file over ~400 lines, `grep -n "^## "` it first to find the relevant section, then read only that slice (same technique as the `TODO.AI.md` PART-loading rule in Project Files & Naming). Never `Read` the full file for a single-topic question.

## Compaction
Preserve: task goal · files changed · commands run · failing tests/errors · decisions · next actions.
Drop: old exploration paths · repeated logs · irrelevant discussion.

## Communication
- **AI always runs on the user's behalf, never as a separate party** — Claude Code is an extension of the user, not an independent operator/owner/admin/service making its own decisions. Never attribute an action to an invented third-party role (`operator decision`, `owner approved`, etc.) in commit messages, code comments, or chat replies — say "at the user's request," "user-initiated," or state the fact plainly with no role label at all
- Truthful over agreeable — push back, correct, disagree when warranted; useful beats pleasant
- Never agree just to be agreeable — if the user's approach is flawed, say so directly with reasoning
- Say "no" or "I disagree" when warranted — it's more useful than silent compliance
- **Check the project's own spec before asking** — in any project with `AI.md`/`IDEA.md`/`SPEC.md`, grep/read the relevant section of those files before asking the user anything the spec already answers (project name, variables, build tooling, feature scope, rule overrides, etc.). Asking a question already answered in the spec is a research failure, not genuine ambiguity — it wastes the user's time and signals the file wasn't actually consulted. Only ask once the spec has been checked and is genuinely silent, contradictory, or missing the needed value.
- Ask if unsure; never guess or assume — **exceptions apply when asking is physically impossible or meaningless given the environment:**
  - **Inaccessible hardware** — adb/USB, serial ports, Bluetooth pairing, physical buttons: assume the emulator/simulator path or CI-safe alternative
  - **Environment-determined constraints** — no display server (headless), no audio device, no GPU: detect and adapt silently
  - **Known-safe build defaults** — target arch, min SDK, debug vs release when no flag is set: use the documented community default (e.g. Android `minSdk=24`); always reversible
  - **Toolchain unavailability** — if a required tool (`adb`, `xcrun`, etc.) is absent on the remote host: assume the user wants a build artifact, not a deploy
  - These exceptions apply only when **the environment makes asking pointless** (Claude cannot perform the action regardless of the answer) or **the assumption maps to a documented, reversible community default**. They never apply to business logic, data schema, or feature behavior — those still require asking
- `?` ends a message → it's a question, not a command — answer it
- A message ending in `?` that contains an action verb is still a question — answer it; only act if the user re-sends without `?` or says "yes" / "do it" / "go ahead"
- A message starting with an interrogative word (why/what/how/when/where/who/which/should/could/would/can/is/are/do/does/did — case-insensitive, leading whitespace ignored) is a question even with no trailing `?` — answer it; only act if the user re-sends as a plain statement/imperative or says "yes" / "do it" / "go ahead"
- Multiple questions → numbered list; user replies "1: … 2: …"
- Match user's terminology exactly; never rename their domain language
- `{x}` = placeholder to substitute; `x` = literal text

## Spelling & Grammar
Always fix clear spelling and grammar errors in any file being edited. Never alter technical terms, intentional abbreviations, or domain-specific names.

## Drift Prevention

Drift = ignoring project-specific rules and reverting to global defaults or prior-session assumptions.

**Self-check before any read or write:**
1. Is this path inside `{project_dir}`?
2. Does this project have its own version of this file (AI.md, CLAUDE.md, memory files)?
3. Am I applying a rule from THIS project's files, not a global assumption?
4. Is the working set still what the user defined — or have I quietly expanded it?

**This self-check must be answered explicitly (in output or reasoning), not silently assumed** — skipping it is how stale global-default behavior sneaks back in after a compaction.

When context has been compacted: do not bulk re-read CLAUDE.md/AI.md/SPEC.md — that refills context immediately and can trigger another compaction (`post-compact.sh` deliberately does not inject the full files for this reason). Instead, treat every rule as needing re-verification lazily: before each edit, search for and read only the specific section of CLAUDE.md/AI.md/SPEC.md relevant to that edit (`grep -n "^## "` or the file's own heading style to find it), the same technique the `TODO.AI.md` PART-loading rule uses. Never assume a rule from before the compaction still holds without checking its source section first.

If a SessionStart or PostCompact system message references a project_dir: that path IS `{project_dir}` for this session.

---

## Working Directory & Path Resolution

- **CWD is `$PWD`** — all relative paths resolve from there
- **`{project_dir}`** = `git rev-parse --show-toplevel` if inside a git repo; otherwise = `$PWD` at session start
- **`{project_name}`** = `basename {project_dir}` · **`{project_org}`** = `basename $(dirname {project_dir})` · **`{provider_name}`** = `basename $(dirname $(dirname {project_dir}))`
- Projects live at `~/Projects/{provider_name}/{project_org}/{project_name}`. Known providers: `github` (use `gh`) · `gitlab` (use `glab`) · `gitea` / `private` (use `tea`) · `local` (no remote)
- **Git gate** — if `{project_dir}/.git` does not exist, never run any git operation. Check for `.git` first.
- **Project files override global** — if `{project_dir}/CLAUDE.md` or `{project_dir}/AI.md` exists, it supersedes this file
- **Stay inside `{project_dir}`** — all writes and edits must target paths within `{project_dir}` unless the user explicitly names an external path. **A problem inside the project is never sufficient justification on its own** — never edit host system files, shell rc files, systemd units, other repos, or global tool configs to work around a build/test/tool issue; fix the project's own code/config instead. **Exception:** under `~/Projects/local/system/**` (see "Local System Management Zone" below), an explicitly-authorized external path/repo can be recorded as a durable, repeatable grant instead of needing to be re-named every session

### Local System Management Zone (`~/Projects/local/system/**`)

Repos under this exact path are personal project/infra/fleet-management tooling (managing other repos, servers, systems) — not shippable products. **Only the five exceptions below relax; every other rule in this file and its referenced memory files stays in full force**, including git safety, `security_conventions.md`, and all CI/CD, Makefile, language, and framework tooling conventions (test gates, lint gates, build rules).

**Relaxed here — nothing else:**
- **Plaintext credentials allowed** — tokens/passwords/API keys may be stored in plaintext (inventories, `.env`-style credential stores) without the SHA-256 hashing/masking `sensitive_data.md` normally requires. Full condition: `~/.claude/memory/sensitive_data.md` → "The Only Exception".
- **`LICENSE.md` not required** — every other `project_files.md` root-file requirement (`AI.md`, `IDEA.md`, `CLAUDE.md`, `README.md`, `Makefile`, `.gitignore`, etc.) still applies.
- **systemctl lifecycle commands pre-authorized** — `start`/`stop`/`restart`/`reload`/`reload-or-restart`/`try-restart`/`enable`/`disable`/`reset-failed`/`daemon-reload` run without per-call confirmation (see "Code & Files" → "systemctl gate" above for the exact list and rationale).
- **Cross-repo / host-config access with recorded consent** — this is the point of the zone: a project here may write outside `{project_dir}` (other repos, host config files including `/etc/**`) once the user has explicitly authorized that specific path/repo for that project. A verbal "yes" in conversation is not durable and does not survive compaction — before acting, write the grant into `{project_dir}/.claude/settings.local.json` as a real permission entry (gitignored, machine-local). The recorded entry, not the conversation, is what pre-authorizes future access to that path without re-asking each session. Each external path/repo needs its own explicit grant — authorizing one never implies another, and nothing is inferred. Every other safety rule still applies to what's reached this way: destructive-op confirmation (`rm -rf`, force-push, etc.), git safety, and the systemctl gate (including its zone exception above) all apply identically whether the target is inside or outside `{project_dir}`. **This per-path grant requirement does not apply to raw `git commit`/`git push` themselves** — see the next bullet: the zone's whole point is managing many repos' git state from one cwd, so `git -C /other/repo commit`/`push` from a cwd already inside the zone is covered by that bullet's pre-authorization, not this one. Always target commit/push with an explicit `-C <path>` (or an equivalent explicit full path) rather than relying on an ambient cwd inside some other repo — the explicit path is what makes the operation's target unambiguous.
- **Raw standard git commands pre-authorized, `gitcommit`-only path lifted** — inside the zone, ordinary git commands (`status`/`diff`/`log`/`add`/`commit`/`push`/`pull`/`fetch`/`checkout`/`branch`/`merge`/`stash`/`remote`/etc.) run directly, without going through `gitcommit` and without per-call confirmation — the point of the zone is managing many repos' git state directly. **Excluded from this pre-authorization — always confirm first, per the global destructive-op rule, and never pre-run even here:** `git reset` (any form — `--hard`/`--mixed`/`--soft`), `git clean -f*`, `git push --force*`/`--force-with-lease`, `git branch -D`, `git rebase`, `git filter-repo`/`filter-branch`, `git tag -d`, and any other command that discards commits, discards uncommitted work, or rewrites history.
  - **Repo privacy gate** (uses the raw-git exception above, replacing `gitcommit`'s auto-create/auto-push): a repo here may have a remote and be pushed (overriding the general `local` provider's "no remote" default, for this named path only), only under this sequence — never auto-create a remote:
    1. If no remote exists yet, create it explicitly with `gh repo create --private` (or provider equivalent) — never let anything auto-create it, since auto-create does not guarantee private visibility.
    2. `git commit` locally first; do not push in the same step.
    3. Review the local diff for secrets/PII before pushing — the zone's plaintext-credential exception means a diff can legitimately contain real tokens/passwords; confirm nothing that should stay local, or still needs masking outside the credential-store files it's meant for, is about to leave the machine.
    4. Re-verify visibility immediately before push — `gh repo view {org}/{repo} --json visibility` (or provider equivalent); only if `private`, run `git push`.
    5. Re-verify visibility after every push; if a repo is ever found public, switch it to private immediately (`gh repo edit --visibility private` or provider equivalent) before continuing any other work.

**Still hard — no exception, ever, even with a recorded grant:**
- Destructive-op confirmation and no unrequested force-push, everywhere, always — see the excluded-commands list above for what stays gated even in the zone
- Outside the zone, `gitcommit` remains the only commit path — the raw-git exception above applies only under `~/Projects/local/system/**`
- `systemctl mask`/`unmask`/`edit`/`set-property` and all other `security_conventions.md` rules
- **Core OS paths are never a valid grant target, regardless of consent** — `/`, `/boot/**`, `/sys/**`, `/proc/**`, `/dev/**`, partition tables, and bootloader config. This is the "system dir" floor — infra config (`/etc/**`, service configs, other repos) is in scope; the kernel/boot/device layer is not.
- All CI/CD, Makefile, language, and framework tooling conventions

## Code & Files
- **`cd` always uses absolute paths** in scripts, Makefiles, CI steps, and Claude's own Bash tool calls
- **`\command` prefix only for alias-prone external binaries** (`ls`, `grep`, `rm`, `cp`, `mv`, `cat`, `sed`, `diff`, `curl`, …; `command cmd` in fish) — never on shell keywords (`time`, `if`, `while`, `[[` — breaks semantics), never on builtins (no-op), and never on the first word of an allowlisted/pre-authorized or hook-governed command (`gitcommit`, `git`, `make`, `docker`, `incus`, `podman`, `qemu-*`, `virsh`, `systemctl` — breaks permission prefix-matching and PreToolUse hook pattern-matching; container/VM aliases like `docker`→`podman` are deliberate environment config, not noise)
- Read current file state before any edit
- **Edit fails on old_string mismatch → re-read the target slice once, then re-edit** — a mismatch means the in-context copy is stale; never retry an identical failed Edit (guaranteed to fail again and wastes tokens)
- **Working-set discipline** — scope is set when the user names files/dirs; never expand on your own initiative. Exception: spelling/grammar fixes in files already being edited. **Before editing any file the user didn't name, state the specific reason it's in scope** (e.g. "same rule referenced from X") — silent expansion is a violation even when the edit itself is correct
- **Fix completeness** — when a pattern changes, find and fix ALL instances across the working set with `grep -rn` before committing. **Verification required:** re-run the same `grep -rn` after editing — zero remaining matches (or every remaining match named as an intentional exception) before writing COMMIT_MESS; a nonzero, unexplained result means the fix isn't done
- Match surrounding style: naming, indentation, patterns; use ecosystem idioms and community linter/formatter
- Use existing standards (POSIX exit codes, HTTP status codes, RFCs, semver, ISO 8601) — never invent wire protocols
- Targeted edits only; full rewrites only when asked; required deps just add them; real choice between alternatives: ask first
- **No partially implemented code** — every committed line must work as written; no stubs, no `TODO` placeholders inside logic
- **No TODO/FIXME/HACK in committed code** · **No commented-out code**
- **Comments always ABOVE, never inline** (single line, ≤180 chars) · **never in JSON / `.env` KEY=VALUE / CSV/TSV / any pure data format** · JS/CSS comments must use valid syntax for the language. Full rules (inline-directive and SHA-pin exceptions, per-format details): `~/.claude/memory/comment_conventions.md`
- **Directory naming is language-specific** — Go: singular (`handler/`, `model/`, `middleware/`) to match package names; all other languages: plural (`handlers/`, `models/`, `routes/`). Tooling dirs are always plural regardless of language (`scripts/`, `tests/`, `completions/`)
- **Reuse before creating** — before writing a new function, variable/constant, or UI component, search for an existing one that already covers the need and reuse or extend it; only create something new when nothing existing fits
  - **Variables/constants ("search before write")** — before adding a value, enumerate every place it could already live (e.g. config files, env files, code constants, docs — not just the one you thought of first) and grep each one; only after all are checked and come up empty is create/append allowed; replace in place if found in any of them
  - **Functions** — grep for an existing function with the same or similar behavior (same package/module, existing helpers/handlers/validators) before writing a new one; two near-identical functions differing only by a hardcoded value should be one function taking that value as a parameter
  - **UI components/styling** — full rules, including the "everything must be styled, reuse existing classes/tokens before writing new CSS" convention: `~/.claude/memory/ui_ux_conventions.md`
- **Create parent directories before writing** — `mkdir -p "$(dirname -- "$f")"` (shell) · `os.MkdirAll` (Go) · `fs::create_dir_all` (Rust) · `path.parent.mkdir(parents=True)` (Python) · `fs.mkdirSync(path.dirname(f), {recursive:true})` (Node)
- **Every text file ends with a single trailing newline** — exceptions (raw-value secret/token files, verbatim-interpolated files, mid-line fragments, binary/generated artifacts): `~/.claude/memory/file_ending_conventions.md`
- **Indentation: spaces over tabs (2 default, 4 where the ecosystem standard — Python, Rust)** — tabs ONLY where the filetype requires them (Makefile recipes, Go via `gofmt`); the filetype requirement always wins over preference — never let indentation choice break a file

## Sensitive Data
See `~/.claude/memory/sensitive_data.md` for the full credential policy, repo privacy gate, paste-service rules, and env-var overwrite categories.

Key rules always in effect:
- Never commit tokens, API keys, passwords, or private keys — all repos treated as public by default
- Never store tokens in plaintext — hash with SHA-256; never log raw tokens
- Credential masking — preserve the key name, replace value with `xxxxx`

## Project Files & Naming
- See `~/.claude/memory/project_conventions.md` for AI.md / IDEA.md / CLAUDE.md roles, placeholder system, and directory layout
- See `~/.claude/memory/project_files.md` for README.md requirements, LICENSE.md naming, allowed root files, and what must never be created
- **`TODO.AI.md` hygiene** — complete each item fully before removing; never clear while in progress. **`PLAN.AI.md` hygiene** — delete once work is fully committed
- **No issue left only in conversation** — any flagged-but-not-fixed issue (found during an audit, a review, or incidentally while doing something else) must, before moving on to other work, either be fixed immediately or logged as a line item in `TODO.AI.md` (create it if missing). A commit message, a chat reply, or a summary is not a durable record — conversation context can be compacted or lost. This applies regardless of severity or how small the issue seems; the `audit` agent's >5-issues-to-`AUDIT.AI.md` threshold is a separate, additional rule for large batches, not an exemption from logging smaller ones here
- **`TODO.AI.md` PART loading** — `grep -n "^# PART N" AI.md` to find the slice; read only that slice; never load the full spec file; cross-refs inside the slice: finish the slice first, then follow

## Cleanup
- Stop/remove every container, VM, volume, network, and temp file as soon as it is no longer needed
- Track what you start — note name/ID before spinning anything up
- Only remove project-specific resources; never broad sweeps (`docker system prune`, `rm -rf /tmp/*`)
- Full rules: `~/.claude/memory/execution_hierarchy.md`

## Shell Lifetime & Timeouts
Every shell command must be bounded — enforced by `bound-shell-lifetime.sh`. Full rules: `~/.claude/memory/shell_lifetime_conventions.md`
- **The Bash tool `timeout` parameter is in MILLISECONDS** — 60s = `60000`, 300s = `300000`, 600s = `600000`; a raw seconds value (e.g. `30`) means 30 ms and kills the command instantly
- **Timeout tiers** — lookups/status ≤60s · network/package ops ≤300s · builds/tests ≤600s (tool hard max); explicit `timeout` on every Bash call
- **Expected to exceed 600s → run_in_background** from the start; **after a timeout kill, never retry with the same value** — jump a tier or go background
- Never poll harness-tracked work (task-notifications resume it) · bounded polling only · no open-ended sleeps · no `nohup`/`setsid`/`disown` (use run_in_background) · `&` requires `PID=$!` ownership · `tail -f`/`watch` only inside `timeout {n}`

## Verification & Safety
- Confirm before: `rm -rf`, force pushes, dropping tables/branches, anything irreversible
- **Never run unrequested destructive ops, even to "fix"** — stop and ask
- **A `git status` deletion is not automatically an error to fix** — `git restore`, `git checkout -- <path>`, and any additive-restore/deploy step (e.g. `install.sh` copying `home/` → `~/.claude/`) undo the user's own uncommitted change. Never run one of these on a file the user didn't ask to have restored just because it shows as deleted/modified — that deletion is more likely deliberate (e.g. manual cleanup pending regeneration via `bootstrap`) than damage. Ask first before reverting anything the user didn't report as broken. (This does not apply to the Session Start stash/pull/pop sequence — that flow's own `git stash pop` is separately pre-authorized.)
- **Never auto-bypass a hook block** — if a PreToolUse hook returns `BLOCKED:`, tell the user; only they decide whether to proceed
- Verify APIs/flags exist before using them; run code before calling it done; iterate until verification passes
- **kill scoping** — `kill $PID` only when `$PID` was captured at launch in the current task (`PID=$!`)
- **systemctl gate** — `status`/`is-active`/`is-enabled`/`cat`/`show` and `--user` variants are always OK; `restart`/`stop`/`start`/`reload`/`disable`/`enable`/`mask` on host services require user confirmation. **Exception:** under `~/Projects/local/system/**` (see "Local System Management Zone" below), `start`/`stop`/`restart`/`reload`/`reload-or-restart`/`try-restart`/`enable`/`disable`/`reset-failed`/`daemon-reload` are pre-authorized without per-call confirmation; `mask`/`unmask`/`edit`/`set-property` still require confirmation everywhere, including in the zone — they change persistent boot-time behavior other tooling relies on, a different risk class than a lifecycle toggle
- Memory safety and security-by-design rules: `~/.claude/memory/security_conventions.md`

## Self-Validation
- **Define success up front**, then **verify against ground truth** (UI → design; logic → expected output; data → spot-check a sample) and **iterate until passing** — don't stop at "compiles"
- **Add tests for new behavior** — a test that fails before and passes after, then run it
- **One run, then fix** — don't loop on flaky failures without a hypothesis
- **Verification statement required** — before declaring a task done, state the specific ground-truth check performed and its actual result (e.g. "ran `go test ./...`, all pass" or "diffed output against expected.json, matches"); "looks right" or "should work" is not a check and does not count as done

## Build & Execution
- Full rules: `~/.claude/memory/execution_hierarchy.md` · Hierarchy: QEMU/KVM > Incus > Docker > host
- **Never build on the host** — always Docker. Toolchain image selection (first match): **(1)** image declared by the project in IDEA.md/SPEC.md/AI.md; **(2)** project `docker/Dockerfile.build` if it exists; **(3)** standard maintained image for the language: Go → `casjaysdev/go:latest` · Rust → `casjaysdev/rust:latest` · Android → `casjaysdev/android:latest` · Node → `node:alpine` · Python → `python:alpine` · other → official image. This tree picks the TOOLCHAIN image only — the runtime image (final stage of `docker/Dockerfile`) is the project's choice. Full decision tree: `~/.claude/memory/dockerfile_conventions.md` → Toolchain Image — Decision Tree
- **Go, Rust, and Android projects default to NO `docker/Dockerfile.build` or `build-toolchain.yml`** — the casjaysdev images cover virtually every need; a `Dockerfile.build` is allowed only for a genuine custom need the casjaysdev image cannot satisfy, and then it MUST be `FROM casjaysdev/go:latest` / `FROM casjaysdev/rust:latest` / `FROM casjaysdev/android:latest` (extend, never replace)
- **`$PWD` not `$(pwd)` in shell docker `-v` flags** — `$(pwd)` triggers a permission prompt; in Makefiles `$(PWD)` is correct
- **Go Docker builds require `-e GOFLAGS=-buildvcs=false`** — mounted `.git` UID mismatch fails `go build` with "exit status 128"; full pattern: `~/.claude/memory/go_conventions.md § Docker Build Pattern`
- **Coverage and test output never go to the project tree** — full `{project_org}/{internal_name}-XXXXXX/` tempdir structure: `~/.claude/memory/tempdir_conventions.md`
- Target `linux/amd64` + `linux/arm64` by default; builds reproducible in containers
- **Script-collection and spec-collection projects are exempt from this section** — no Makefile, no Docker toolchain build, no CI/CD workflow by default; detection criteria and replacement gates: `~/.claude/memory/project_type_conventions.md § Type: script-collection` / `§ Type: spec-collection`

## UI/UX
- Designer-level intent · dark mode default (support dark/light/auto) · never hardcode colors — CSS custom properties (web) or shared theme struct (desktop/TUI)
- Non-trivial UI tasks → `designer` agent. Full rules: `~/.claude/memory/ui_ux_conventions.md`

## Security & Project Defaults
- Security-by-design rules and memory safety: `~/.claude/memory/security_conventions.md`
- License: MIT · Single self-contained binary · First-run works with zero config
- No feature gating · Telemetry opt-in only · Web UIs mobile-responsive from day one
- Security in code: parameterized queries, constant-time comparison, CSRF/XSS/SSRF/IDOR/path-traversal guards

## Language Constraints
Load the matching file on demand — only when actively working in that language:
- **Go:** `~/.claude/memory/go_conventions.md`
- **Node / TypeScript:** `~/.claude/memory/node_typescript_conventions.md`
- **Python:** `~/.claude/memory/python_conventions.md`
- **Rust:** `~/.claude/memory/rust_conventions.md`

## Output
- No preamble, no reflexive agreement, no closing recap
- Concise but complete — give enough context to understand, but no filler; one clear explanation beats three hedged ones
- **Tight output budget** — status updates: 1–3 sentences max; no headers/bullets unless the task requires structured output
- Show diffs, not prose retellings of changes
- No emojis in code or inline tool output unless asked; emojis are appropriate in READMEs, docs, and commit messages
- **Assume a narrow terminal (~70 columns)** — short lines, no wide tables, compact bullets; prefer stacked prose over side-by-side layouts
- **No AI attribution** — no `Co-Authored-By:`, AI-tool trailers, or "Generated with X" footers anywhere
- Next step is clear → do it; pause only for genuine blockers or destructive-op confirmation

## Tool Preference
See `~/.claude/memory/tool_conventions.md` for internet access rules, curl/wget/grep defaults, provider CLI auto-install rules, `act` usage, and image handling.

Key rules always in effect:
- **Internet access is available and must be used** — fetch docs, versions, READMEs, and any fact that changes over time; never say "I don't have internet access"
- Use the right tool if installed: `jq` (JSON), `yq` (YAML), `bc` (math), `grep`/`sed`/`awk` (text)
- Provider CLIs (`gh`, `glab`, `tea`) over raw `curl` for provider API ops
- `grep` always with `--` before the query; never `egrep`/`fgrep`/`rgrep`

## Token & Context Discipline
- **Explorer subagent for broad searches** — 3+ files, unknown locations, or multiple naming conventions
- **Read files narrowly** — files >500 lines: use `offset`/`limit` or grep first; don't load 2000 lines for 50
- **No speculative reads** — only read files the current task directly requires
- **Don't re-read after editing** — exception: re-read `COMMIT_MESS` once before `gitcommit` to verify it matches the diff
- **Don't spawn agents for small tasks** — 2–3 direct tool calls: do it inline
- **Plan mode for genuine ambiguity only** — not for file count; mechanical changes across many files don't need a plan
- **Parallelize independent research** — spawn agents in parallel (single message, multiple Agent calls)

## Agent Usage
- **Model routing** — route each task to the cheapest capable model; full tier table in `~/.claude/memory/model_routing.md`. Largest single lever on weekly-cap consumption
- **Haiku for trivial tasks** — renames, format conversions, single-line edits, simple lookups, mechanical refactors
- **Agents never commit** — agents edit and report back; main instance reviews the diff, writes `COMMIT_MESS`, runs `gitcommit`

## Autonomy
- Action commands ("fix all issues", "run the tests", "deploy") → execute fully without step-by-step confirmation
- "Run X" pre-authorizes X and its entire workflow (subcommands, loops, retries, pipes) for this session — but not a *different* command, and not a destructive/irreversible action X doesn't plainly imply (e.g. "run the tests" does not pre-authorize a force-push, a schema migration, or deleting a branch); if a step falls outside what X plainly means, stop and ask
- Write/Edit allowlists are in `{project_dir}/.claude/settings.json` — pre-approved paths: `.git/COMMIT_MESS`, `CLAUDE.md`, `AI.md`, `SPEC.md`, `IDEA.md`, `TODO.AI.md`, `TODO.md`, `PLAN.AI.md`, `PLAN.md`, `.claude/settings.json`, `.claude/settings.local.json`, `.env`/`app.env`/`default.env`, `.no_push`

## Task Dependency Ordering
- Dependency graph beats label order (numbered sequence is a tiebreaker only); topological-sort stated dependencies before starting; a task is "ready" only when all prerequisites are complete
- 3+ dependencies → document the resolved order at the top of TODO.AI.md or PLAN.AI.md

## Commit Workflow
`git commit` and `git push` are denied. `gitcommit` (resolved from PATH) is the only commit path. **Never read the `gitcommit` script file** — it is pre-approved and trusted. **Exception:** under `~/Projects/local/system/**`, see "Local System Management Zone" above — raw git commands are pre-authorized there instead.

**Only valid invocation:** `gitcommit --dir {dir} all`
- `{dir}` = absolute path to the project root · `all` is the only command · never use `-m`/`--message`
- If the GitHub remote does not exist, `gitcommit` creates it automatically — no manual `gh repo create` needed

**Pre-commit sequence:**
1. `git status --porcelain` + `git diff --stat` — see actual changes
2. **Run `make test`** (or language equivalent; for `script-collection` projects — see `~/.claude/memory/project_type_conventions.md` — run `bash -n` + `script-lint` instead, no Makefile required; for `spec-collection` projects, re-read the edited file(s) instead — there is no test runner) — every test must pass; never commit with a failing test
3. Run the lint gate (see below) — never commit with violations
4. Write `{dir}/.git/COMMIT_MESS` from that output — every changed file described; never write from memory
5. Re-read `COMMIT_MESS` and compare against the diff — rewrite if anything is missing or wrong
6. Run `gitcommit --dir {dir} all`

**Message format, emoji map, no-bare-`@` rule, and cadence:** `~/.claude/memory/gitcommit_conventions.md` — `{emoji} Title (≤64 chars) {emoji}` + body + `- path: change` bullets; one logical change per commit. **Findings-based work (audits, reviews, numbered fix-lists) defaults to one commit per finding — never batch distinct findings into one commit just because they share a file or session.** Exception: when multiple findings from the same audit pass are pure doc/template-alignment fixes (no logic or behavior change) in the same repo, they may be batched into one commit, each described as its own bullet — this exception never applies to security findings, logic bugs, or anything that might independently need reverting; those always get their own commit. **Feature work is the opposite — one commit for the whole feature, never split per part. Unrelated bugs found mid-feature go to `TODO.AI.md`, except app-breaking bugs, which must be fixed immediately.**

**Test gate:** `make test` (or language equivalent: `go test ./...`, `cargo test`, `pytest`, `npm test`; `script-collection` projects use `bash -n` + `script-lint` instead; `spec-collection` projects have no runnable test — verify by re-reading the changed content) must pass before every commit — no exceptions; never skip tests to "save time".

**Lint gate:** `script-lint` (shell) · `go-lint` (Go) · `rust-lint` (Rust) — never commit with violations.

**Workflow gate and creation order:** `~/.claude/memory/cicd_conventions.md` — staged `.github/workflows/` files need `act --list -W {file}` passing; third-party Actions pinned to a full commit SHA, never a tag; create security-only workflows first, `ci.yml`/`release.yml` last.

**Push is immediate and irreversible.** To skip: `touch .no_push` (confirm with user first). If push fails offline: run `gitcommit push` later — do NOT recreate `COMMIT_MESS`.

**Post-push CI check:** if the project has CI config, check the triggered run's status after every push (`~/.claude/memory/cicd_conventions.md` § Post-Push CI Verification) — a failing build is a bug to fix immediately, not a note for later; never report the task done while the pushed build is red or still running.
