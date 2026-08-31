# TODO.AI.md

Findings from full hook-vs-rules audit (2026-08-30), following the `make lint`
fix (commit b94f19084aee). Source: audit agent pass over all 27 hooks in
home/hooks/, home/CLAUDE.md, AI.md, home/memory/*.md, and sibling claudemgr
template repos. Report-only pass — nothing below has been fixed yet.

Dependency order: items 34 and 41 need a user decision before their own fix
(and before anything that depends on the answer) can be implemented. All
other items are independent and can be fixed in any order.

## Environment bug, not fixable in this repo

- [ ] 68 (OPEN, not a claudemgr/config code issue): live long-running
      session (5b02732a-98bc-4e4b-86ff-94fff4d9ca97) has PreToolUse
      hooks firing correctly (enforce-test-lint-gate.sh blocks as
      designed) but PostToolUse hooks (test-lint-mark.sh) silently not
      firing for real Bash tool calls — confirmed not a script bug via
      direct simulation of the deployed hook with the real session_id,
      cwd, and command, which wrote the marker correctly every time; no
      project-local settings.json/settings.local.json override exists
      to explain it. Likely the same class of stale-hook-registration
      bug as the documented SessionStart-on-/clear issue
      (anthropics/claude-code#34072), but for PostToolUse specifically,
      and it does NOT clear on /clear per that same bug. Workaround used
      this session: manually append the project path to
      ${TMPDIR}/claude-test-lint-guard/<session_id>/{test,lint} once the
      user reports a real passing test/lint run, matching exactly what
      the hook would have written. No permanent fix available from
      inside this repo — would need a fresh session (new process) to
      re-register hooks, or an upstream Claude Code fix.

## Needs user decision first

- [x] 34 (FIXED, user decision: "if there are scripts then lint, no
      scripts don't lint"): Is `claudemgr/config` itself spec-collection?
      AI.md:226 already correctly excludes it (it isn't in the
      `claudemgr/{go,rust,android,docker,mgr}` no-AI.md template list,
      and it has AI.md/SPEC.md at root). Fixed
      home/memory/project_type_conventions.md instead — removed
      `config` from the spec-collection example list, added the "if
      there are scripts, lint; if not, don't" simple rule, and
      clarified that any `*.sh` beyond a bare deploy-only root
      `install.sh` disqualifies a repo from spec-collection.
- [x] 41 (FIXED, user decision: keep no-bulk-re-read but tighten the
      CLAUDE.md wording to "search and read the relevant section
      before each edit"): post-compact.sh:41 ("Do NOT bulk re-read
      files now") directly contradicted home/CLAUDE.md:63 ("treat all
      rules as needing re-verification" after compaction). Fixed
      home/CLAUDE.md's Drift Prevention section to explicitly say: do
      not bulk re-read CLAUDE.md/AI.md/SPEC.md after compaction;
      instead, before each edit, search for and read only the specific
      relevant section (matching post-compact.sh and the TODO.AI.md
      PART-loading technique). No hook change needed.

## Same bug class as make lint (hardcoded value doesn't match source rule)

- [x] 1 (FIXED): bound-shell-lifetime.sh:275 block message prints wrong timeout
      tiers (<=30s/<=120s/<=600s) vs actual <=60s/<=300s/<=600s
      (home/CLAUDE.md:149, shell_lifetime_conventions.md:11). Fixed the printed
      tiers to <=60s/<=300s/<=600s.
- [x] 2 (FIXED): test-lint-mark.sh:63 — `bash -n` satisfies the test gate for
      every project type; home/CLAUDE.md:255 scopes it to
      script-collection only. Fixed: `bash -n` now only marks the test gate
      when the project has no Makefile/go.mod/Cargo.toml/package.json/
      pyproject.toml/setup.py (script-collection heuristic).
- [x] 5 (FIXED): no-todo-comments.sh:75 — `XXX` is an invented marker not in
      CLAUDE.md's "No TODO/FIXME/HACK" (home/CLAUDE.md:114). Removed XXX
      from the blocked-marker regex.

## Core-OS / destructive-op gaps (protect-host.sh)

- [x] 3 (FIXED): protect-host.sh:367 — `systemctl edit`/`set-property` not
      blocked at all (home/CLAUDE.md:99,160 require confirmation
      everywhere including the zone). Added to the always-confirm
      alternation, deliberately excluded from the zone-bypass alternation.
- [x] 4 (FIXED): protect-host.sh:361,364,367 — trailing `[[:space:]]` instead of
      `([[:space:]]|$)` lets argument-less `systemctl daemon-reload`
      bypass the block outside the zone. All three alternations now use
      `([[:space:]]|$)`.
- [x] 6 (FIXED): protect-host.sh:284-287 — `/boot`,`/sys`,`/proc`,`/dev` subpaths
      not actually blocked (only the dir itself or its `/*` glob);
      home/CLAUDE.md:100 uses `/boot/**` etc. Added Rule 4c blocking any
      destructive verb on a subpath beneath these four dirs.
- [x] 7 (FIXED): protect-host.sh — partition tables / bootloader config
      unenforced; no match for `sgdisk`/`parted`/`grub-install`/
      `/etc/default/grub` (home/CLAUDE.md:100). Added Rule 8b blocking
      sgdisk/parted/fdisk/cfdisk/gdisk/grub-install/grub2-install and
      writes/redirects to /etc/default/grub.
- [x] 8 (FIXED): no-destructive-bypass.sh:119 — wrapper-strip list missing
      `builtin`/`nice`/`ionice`/`stdbuf`/`timeout`/`setsid` that its
      sibling enforce-docker-rm.sh:135 already strips. Wrapper set now
      matches, including skipping duration/priority arguments (timeout 60).
- [x] 9 (FIXED): bound-shell-lifetime.sh:200,202 — iteration-cap/bounded_before
      escapes evaluate before the sentinel-poll block at :205, laundering
      a forbidden sentinel poll as merely "bounded" (shell_lifetime_
      conventions.md:21 forbids sentinel polling unconditionally). Sentinel
      check now runs first in the loop, and sub_scripts() no longer skips
      recursing into `timeout N shell -c "..."` payloads (marks
      outer_bounded instead, so only ordinary loops are exempted).

## no-forbidden-files.sh badly out of sync

- [x] 10 (FIXED: found already correct on inspection): `LOCATION_RESTRICTED_DOCKER_BASENAMES`
      requires `docker/` in path for Dockerfile/docker-compose.yml —
      consistent with project_files.md's root-placement rule.
- [x] 11 (FIXED): SUMMARY/COMPLIANCE/NOTES/AUDIT/REPORT/ANALYSIS.md and
      CONTRIBUTING/CODE_OF_CONDUCT/SECURITY/PULL_REQUEST_TEMPLATE were
      already implemented (FORBIDDEN_REPORT_BASENAMES,
      LOCATION_RESTRICTED_DOC_BASENAMES) on inspection. Added the
      remaining missing rows: `.env`/`app.env`/`default.env`,
      `server.yml`/`cli.yml` to FORBIDDEN_BASENAMES; `.claude/` detritus
      (settings.local.json, backups/, cache/, file-history/,
      history.jsonl, projects/, statsFile, *.lock) and AI-tool config
      dirs (.cursor/settings.json, .windsurf/settings.json, .aider.*,
      .continue/*, .codeium/) as new FORBIDDEN_PATH_PATTERNS entries.
      .netrc/id_rsa/.pem/.jks are documented in project_files.md:61,64,69
      — the "undocumented" audit finding was already stale. Fixed the
      empty @@Resource field to point at home/memory/project_files.md.
      Verified live: `.env` and `.claude/settings.local.json` both now
      block with exit 2; README.md still passes with exit 0.
- [x] 12 (FIXED): message now starts with `BLOCKED: confirm required
      before writing {file_path}`, matching AI.md:191-196's mandated prefix.
- [x] 13 (FIXED: found already correct on inspection): version stamp is
      `202608302000-git` consistently at both header locations.

## Trailing-newline / comment guards

- [x] 14 (FIXED: found already correct on inspection): `.pem`/`.key`/
      `.crt` were already dropped from EXEMPT_EXT in a prior session
      (see the script's own changelog entry) — not in EXEMPT_EXT.
- [x] 15 (FIXED): mid-line-fragment and project-tooling-wins
      (file_ending_conventions.md:25,28-30) can't be auto-detected from
      a file path/extension alone — they require human judgment about
      how the file is consumed. The BLOCKED message now names both
      exceptions explicitly so a human reviewer knows to check before
      blindly adding a newline, rather than the hook silently omitting
      them from its own guidance.
- [x] 16 (FIXED): added a check for `.env`/`app.env`/`default.env`
      basenames and `.csv`/`.tsv` extensions that blocks any `#`-led
      comment line, matching comment_conventions.md:15-20's forbidden-
      format list. Verified live: `.env` and `.csv` with a leading `#`
      comment both block with exit 2; a bare `.env` with no comment
      still passes with exit 0.
- [x] 17 (FIXED): own-line comments (`#`/`//`-led lines) now blocked
      when they exceed 180 chars. Verified live: a 202-char comment
      blocks with exit 2; a short comment still passes with exit 0.
- [x] 18 (FIXED): added a quote-aware `find_unquoted_marker()` scanner that
      tracks single/double-quote state so a `#`/`//` inside a string literal
      is never mistaken for a comment start; `INLINE_EXEMPT_RE` now searches
      only the actual comment substring instead of the whole line, closing
      the bypass vector. Verified live: a quoted `#` inside a string no
      longer blocks; `"# noqa"` as string content followed by a real
      trailing comment now correctly blocks; genuine `# noqa`, CI SHA-pin
      lines, genuine inline comments, and own-line comments all still
      behave as before.
- [ ] 19: no-todo-comments.sh:72,91-97 — `#`/`*` in COMMENT_PREFIX
      blocks Markdown headings/list items; home/CLAUDE.md:114 scopes
      the rule to committed code, and AUDIT.AI.md isn't exempted
      alongside TODO.AI.md.

## Secrets

- [ ] 20: no-secrets.sh:69-74 — zone exemption applied on path alone;
      sensitive_data.md:35 conditions it on confirmed private
      visibility (network check forbidden in hooks per AI.md:202 —
      note the gap in the hook comment / AI.md:231 if left unfixed).
      Duplicated at bash-content-scan.sh:165-167.
- [ ] 21: bash-content-scan.sh:110-119 doesn't mirror no-secrets.sh's
      ALLOWED_TEMPLATES (:58-65) despite claiming full mirroring at
      :12-16,204-206.
- [ ] 22: no-forbidden-files.sh:156 allowlists `.env.template`, which
      neither no-secrets.sh nor project_files.md:39 recognizes (only
      `.example`/`.sample`).

## block-host-toolchain.sh (worst offender, 846 lines)

- [ ] 23: all ~48 suggested `docker run` commands omit `--memory`/
      `--cpus` (execution_hierarchy.md:126).
- [ ] 24: no Android dispatch; gradle/gradlew maps to `gradle:alpine`
      instead of `casjaysdev/android:latest` (home/CLAUDE.md:171,
      dockerfile_conventions.md:42); adb/sdkmanager/apksigner/zipalign/
      d8/r8/aapt2 not blocked at all.
- [ ] 25: ignores steps 1-2 of toolchain precedence (project-declared
      image, Dockerfile.build) — only ever emits the language-default
      step (dockerfile_conventions.md:29-32).
- [ ] 26: suggests `ubuntu:latest`/`debian:latest` at :645,747,773,797
      (dockerfile_conventions.md:45 forbids).
- [ ] 27: Node/Python arms omit required cache mounts (:299-367) that
      Go/Rust arms have (node_typescript_conventions.md:114,
      python_conventions.md:114). Also note: makefile_conventions.md:150
      says `/app` mount, node/python conventions say `/build` — hook
      can't satisfy both without a resolved convention.
- [ ] 28: Rust arm :284-293 mounts sccache dir but drops
      `-e RUSTC_WRAPPER=sccache` (rust_conventions.md:84), making the
      mount inert.
- [ ] 29: container-runtime exemption list (:236-240) misses virsh/
      vagrant/distrobox/nsenter that the hook's own :147-150 recognizes,
      so a higher-tier runtime gets wrongly redirected to Docker.
- [ ] 30: no script-collection/spec-collection exemption despite
      home/CLAUDE.md:177 exempting both from Build & Execution; blocks
      `prove` at :686 despite it being part of script-collection's gate.
- [ ] 31: :107 tempdir snippet omits the parent `mkdir -p` required by
      tempdir_conventions.md:41-42 — printed command fails first use.
- [ ] 32: :270 etc. — `--name` derived from `$PWD` not `{project_name}`,
      breaking the `docker ps --filter name={project_name}-` cleanup
      convention when run from a subdir.

## Gate/marker hooks

- [ ] 33: enforce-test-lint-gate.sh:156-157 permanently blocks commits
      for any non-spec-collection project with no .sh files — no
      lint-gate tool exists for e.g. a pure Python/Node repo.
- [ ] 35: lint-agent-mark.sh:48-52 marks the gate on subagent
      *completion*, not on a passing result — a lint agent reporting
      unfixed violations still opens the gate (home/CLAUDE.md:257).
- [ ] 36: validate-workflows.sh:57-80 does a network install
      (setupmgr act) inside a hook — violates AI.md:201-202 (hooks
      must be fast, no network I/O).
- [ ] 37: validate-workflows.sh only implements 1 of the Workflow
      gate's 3 clauses — SHA-pinning of third-party Actions
      (home/CLAUDE.md:259) is enforced by no hook at all.
- [ ] 38: spec-guard.sh:58-64 hard-blocks repos with CLAUDE.md but no
      AI.md/SPEC.md, which project_conventions.md:172 puts out of
      scope — unsatisfiable gate.
- [ ] 39: spec-guard.sh:44-49 exempts seven files (incl. README.md,
      LICENSE.md) not listed in its own header :17.
- [ ] 40: project_type_conventions.md:176 omits `mgr` from the
      template-repo list that AI.md:226 and spec-guard-mark.sh:49
      both include.

## Session hooks

- [ ] 42: drift-guard-read.sh never checks a home/ source actually
      exists before redirecting (its own @@Description:12 and
      AI.md:213 say it should).
- [ ] 43: drift-guard-read.sh is Read-only; `cat ~/.claude/memory/...`
      bypasses it entirely (no-read-gitcommit.sh and
      bash-content-scan.sh both close the equivalent gap on their
      own hooks — this one doesn't).
- [ ] 44: AI.md:211 documents `matcher: "clear"` on session-start.sh,
      which home/settings.json does not have.

## Template repos (ship as generated projects' AI.md)

- [ ] 45: go/API.md:1607,3285-3321, rust/API.md:1595,3269-3305,
      rust/SERVER.md:1906,3142, go/HYBRID.md:425,442 all teach
      `gitcommit <command>` — a shape enforce-gitcommit-shape.sh:98-111
      hard-blocks. Other files in the same repos use the correct
      `--dir {dir} all` — internally inconsistent too.
- [ ] 46: go/API.md:1878, rust/API.md:1864 allowlist
      `Bash(go *)`/`Bash(cargo *)`/`Bash(golangci-lint *)`, which
      block-host-toolchain.sh:265-294 and home/CLAUDE.md:171 forbid on
      host; contradicts their own sibling go/APPLICATION.md:164.
- [ ] 47: go/APPLICATION.md:605,658,1420,2049,2213 and
      rust/APPLICATION.md:635,692 teach `golangci-lint run ./...` /
      `cargo clippy` as "the lint gate", but lint-agent-mark.sh:50 only
      recognizes script-lint/go-lint/rust-lint — following the template
      leaves the commit permanently blocked.
- [ ] 48: go/HYBRID.md:37618 README `docker run` example has `--name`
      but no `--rm` and isn't detached — enforce-docker-rm.sh:220 blocks
      it.

## Cross-cutting

- [ ] 49: AI.md:203 "Never write to files from a hook (except
      append-only logs)" is contradicted by test-lint-mark.sh:75,
      spec-guard-mark.sh:67, lint-agent-mark.sh:63, which each mkdir/
      chmod/prune a marker dir. Needs an explicit marker-file carve-out
      in AI.md:203, not hook deletion (AI.md:237 relies on the rule
      elsewhere).
- [ ] 50: AI.md:198 says hooks parse with `jq`; block-host-toolchain.sh
      and several others use python3 instead — a host without python3
      silently no-ops those gates (exit 0).
- [ ] 51: AI.md:278 documents `~/.claude/hooks/` paths; home/
      settings.json uses `$HOME/.claude/hooks/` for all 35 wirings —
      functionally identical, literally mismatched.

## Git/commit hook group (zone-git-commit-push.sh, no-subagent-commit.sh,
## no-history-rewrite.sh, no-destructive-bypass.sh, no-read-gitcommit.sh,
## no-force-push.sh, enforce-gitcommit-shape.sh)

- [x] 52 (HIGH — fix first, FIXED): `git -C <path> <subcmd>` bypasses four hooks
      at once — zone-git-commit-push.sh:63-73, no-subagent-commit.sh:71-85,
      no-history-rewrite.sh:147-155, no-destructive-bypass.sh:151-156 skip
      tokens starting with "-" but never skip the VALUE of a valued global
      flag, so `-C` is skipped and `/path` is mistaken for the subcommand,
      stopping the scan. Verified exit 0 (should be 2) for
      `git -C /p commit -m x` outside the zone, `git -c user.name=z push
      origin main`, `git -C /repo rebase main`, `git -C /repo reset
      --hard`. Bypasses home/CLAUDE.md:239, the zone-excluded command
      list at home/CLAUDE.md:88, and permissions.deny `Bash(git reset *)`.
      no-force-push.sh:103 (uses tokens.index("push")) is immune —
      correct idiom already in-repo, so this is an inconsistency, not a
      tradeoff. Root cause is one parser copy-pasted across all these
      hooks and fixed in only some — extract a shared helper that also
      skips values of -C, -c, --git-dir, --work-tree, --namespace,
      --exec-path, rather than patching each hook separately.
      Fixed: added shared GIT_GLOBAL_OPTS_WITH_VALUE set +
      find_git_subcommand() helper to zone-git-commit-push.sh,
      no-subagent-commit.sh, no-history-rewrite.sh, and
      no-destructive-bypass.sh; verified with bash -n and live
      BLOCKED-exit-2 tests for `-C`, `-c`, rebase, and reset cases.
      Also restored no-subagent-commit.sh's missing executable bit
      (discovered while verifying this fix — the hook could not have
      fired at all until this fix). Items 53/54/56/57 remain open —
      distinct bugs in this same file group, not part of the -C bypass.
- [ ] 53 (fix second — may have never fired): no-subagent-commit.sh:12
      header says `tool_input.agent_id`; code at :59 reads top-level
      `d.get("agent_id")`. AI.md:220 is ambiguous on the schema. If the
      real payload nests agent_id under tool_input, this hook has never
      fired and "Agents never commit" (home/CLAUDE.md's Agent Usage
      section) is currently unenforced. Needs an empirical check against
      a live subagent Bash tool call before fixing — do not guess the
      schema.
- [ ] 54: no-read-gitcommit.sh:56-59 hardcodes the exact paths
      (`/usr/local/bin/gitcommit` + CasjaysDev path) that
      gitcommit_conventions.md:7-9 explicitly forbids hardcoding
      ("It's always in PATH"). `cat $(command -v gitcommit)` → exit 0 on
      a machine using a different PATH location. Fix: resolve via
      shutil.which instead of a fixed allowlist.
- [ ] 55: no-read-gitcommit.sh:90-92 READ_VERBS omits `rg` (and
      nl/tac/cut/wc/file/`.`/source) — `rg pattern
      /usr/local/bin/gitcommit` → exit 0 despite grep/sed/awk being
      covered.
- [ ] 56: zone-git-commit-push.sh, no-subagent-commit.sh, and
      enforce-gitcommit-shape.sh lack heredoc-body stripping, unlike
      no-force-push.sh:59-91 and no-history-rewrite.sh:70-102 which have
      strip_heredoc_bodies(). False positive: `cat <<EOF > doc.md` /
      `git commit -m foo` / `EOF` → exit 2 even though the "commit" text
      is inside a heredoc body, not a real command.
- [ ] 57: enforce-gitcommit-shape.sh:102-109 accepts a relative `--dir`
      value; home/CLAUDE.md:242 requires `{dir}` to be an absolute path.
      `gitcommit --dir . all` → exit 0.
- [ ] 58: no-history-rewrite.sh omits several ops from home/CLAUDE.md:88's
      catch-all ("any other command that discards commits, discards
      uncommitted work, or rewrites history"): `git commit --amend`
      (exit 0, and since `commit` is zone-pre-authorized,
      zone-git-commit-push.sh also waves it through inside the zone),
      `git stash drop`/`clear`, `git push --delete`, `git update-ref -d`,
      `git reflog expire`, `git gc --prune`. Separately, home/CLAUDE.md:156
      requires asking before `git restore`/`git checkout -- <path>` but
      no hook gates either — prose-only today.
- [ ] 59: no-history-rewrite.sh:127-128,158 invents a `--dry-run`
      exemption for `git clean`; home/CLAUDE.md:88 lists `git clean -f*`
      with no carve-out. Documented in the hook's own header, but not
      present in the source rule text — needs the rule updated to match,
      or the exemption removed.
- [ ] 60: no-history-rewrite.sh:118-124 `has_delete_flag` for `git tag`
      uses a regex (`^-[a-zA-Z]*[dD][a-zA-Z]*$`) that matches any
      combined flag containing d/D, broader than intended. Contrast
      :167-171's branch handler, which correctly restricts to `-D` only,
      matching the rule exactly — low impact, but inconsistent within
      the same file.
- [ ] 61: no-force-push.sh:15-17 header is missing `@@Other`,
      `@@Resource`, `@@Terminal App`, `@@sudo/root`, `@@Template` —
      script_conventions.md:29-32,42 and AI.md:182 require the full
      header block; this is the only one of the seven git/commit hooks
      with this defect.
- [x] 62 (FIXED, user decision: keep cwd-scoped — "I prefer -C so it is
      always full path is set, keep in mind raw git commit/push is
      limited to ~/Projects/local/system/** only"): zone-git-commit-
      push.sh:110-113 scopes the zone check to `cwd` only, so a cwd
      inside the zone pre-authorizes commit/push to an arbitrary
      external repo via `git -C /other/repo push`. home/CLAUDE.md:87
      requires a per-path recorded grant; AI.md:219 documents this as
      cwd-scoped. Resolved as intentional — hook behavior unchanged.
      Fixed home/CLAUDE.md's cross-repo grant bullet (:87) to explicitly
      carve out raw git commit/push from the per-path grant requirement
      (it's covered by the very next bullet's zone-wide raw-git
      pre-authorization instead) and to recommend always using an
      explicit `-C <path>` rather than relying on ambient cwd.

Verified clean in this group: zone allow/deny list matches
home/CLAUDE.md:239 exactly; `git stash push` correctly doesn't trip
either hook (home/CLAUDE.md:7 requires it at Session Start);
enforce-gitcommit-shape.sh:98,102-109 accepts exactly the two documented
`gitcommit` forms and rejects `-m`/`--message`; no-force-push.sh:107-117
is a superset of home/CLAUDE.md:88 with no gaps; all six hooks' wiring
matches AI.md Part 6, including no-read-gitcommit.sh's dual Read+Bash
wiring (AI.md:214).

## Git/commit hook group — second independent pass (confirms 52/54/56/57
## above; adds four new items not previously caught)

- [x] 63 (FIXED — same fix as 52): no-force-push.sh:104 uses `tokens.index("push")` and is
      immune to the `-C`/`-c` bypass in item 52 — but
      zone-git-commit-push.sh, no-subagent-commit.sh, and
      no-history-rewrite.sh all use the vulnerable first-non-flag-token
      parser. So `git -C /p push` (no `--force`) sails past the zone
      gate while the identical command *with* `--force` is correctly
      blocked by no-force-push.sh. Confirms item 52 needs the shared
      helper fix, not a per-hook patch.
- [x] 64 (FIXED): wrapper-strip list missing `sudo`/`doas` in four git
      hooks — zone-git-commit-push.sh, no-force-push.sh,
      no-history-rewrite.sh, and no-subagent-commit.sh (a fourth
      instance found by direct grep, beyond the three originally
      flagged) used `("command","env","exec","nohup","time")`, while
      enforce-gitcommit-shape.sh:82 and no-read-gitcommit.sh:107 already
      use the correct superset adding `sudo`/`doas`. `sudo git push
      --force`, `sudo git rebase`, `sudo gitcommit` bypassed these four
      hooks entirely. Fixed: added `sudo`/`doas` to all four tuples to
      match the sibling hooks; verified with bash -n and live
      BLOCKED-exit-2 tests. Item 8 (no-destructive-bypass.sh missing
      builtin/nice/ionice/stdbuf/timeout/setsid) is a related but
      distinct gap in a hook that already has sudo/doas — not touched
      by this fix.
- [ ] 65: no-read-gitcommit.sh:66 has a dead third clause —
      `path in P or resolved in P or (basename==\"gitcommit\" and
      resolved in P)` — the third conjunct requires `resolved in P`,
      which the second clause already covers; it can never fire.
- [ ] 66: no-read-gitcommit.sh is not registered on the `Grep` matcher
      in home/settings.json (only `Read` and `Bash`). `Grep` with
      `path=/usr/local/bin/gitcommit output_mode=content` prints the
      file's contents, defeating "Never read the gitcommit script
      file" (home/CLAUDE.md's Commit Workflow).
- [ ] 67: no-force-push.sh:109 `tok.startswith("--force")` also blocks
      `--force-if-includes`, which is a *safety* flag, not a force
      operation — stricter than home/CLAUDE.md:88's literal
      `git push --force*`/`--force-with-lease`. Worth a deliberate
      decision (keep blanket caution vs. narrow the match) rather than
      an accidental prefix-match side effect.
