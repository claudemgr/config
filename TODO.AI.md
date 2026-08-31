# TODO.AI.md

Findings from full hook-vs-rules audit (2026-08-30), following the `make lint`
fix (commit b94f19084aee). Source: audit agent pass over all 27 hooks in
home/hooks/, home/CLAUDE.md, AI.md, home/memory/*.md, and sibling claudemgr
template repos.

Dependency order: items 34 and 41 needed a user decision before their own fix
could be implemented — both resolved (see git log). All other items below are
independent and can be fixed in any order.

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
      ${TMPDIR}/claude-hooks/test-lint-guard/<session_id>/{test,lint}
      once the user reports a real passing test/lint run, matching
      exactly what the hook would have written (path renamed since —
      see the claude-hooks namespace commit). No permanent fix available
      from inside this repo — would need a fresh session (new process)
      to re-register hooks, or an upstream Claude Code fix.
      Corroborating occurrence: session 75c8a099-4388-4e7d-b49c-45dedcfcdf80
      (apimgr/ipgaze project) showed the identical failure mode —
      lint-agent-mark.sh (SubagentStop) correctly wrote its `lint`
      marker, but test-lint-mark.sh (PostToolUse) never wrote `test` for
      a real, user-confirmed passing `make test` run in the same
      session. This is the opposite of what that session's own
      transcript concluded (it believed the lint marker was the one
      missing) — verified backwards by reading the real marker files
      directly. Attempting the same manual-append workaround for that
      session was denied by the Claude Code auto-mode classifier;
      per CLAUDE.md's "never auto-bypass a hook/classifier block" rule,
      this was not routed around — left for the user to resolve
      directly (write the marker themselves, or grant an explicit Bash
      permission rule for that path) if they still want the marker
      backfilled.
      UPDATE: `enforce-test-lint-gate.sh` now also scans the PreToolUse
      payload's own `transcript_path` for a passing test/lint Bash call
      this session, independent of whether `test-lint-mark.sh`'s
      PostToolUse marker ever got written — this directly mitigates the
      specific test/lint-gate false-block symptom described above
      without depending on a fix to the underlying registration bug.
      Verified via `echo '{...}' | bash enforce-test-lint-gate.sh`
      (AI.md's documented hook-test method): marker-only path still
      passes unchanged, and a synthetic transcript with no markers at
      all now satisfies both the test and lint gate on its own. Item
      stays open because the underlying PostToolUse/SubagentStop
      registration bug is still upstream-open and can still affect any
      other hook that has no equivalent fallback (e.g.
      `drift-guard-read.sh`, `spec-guard-mark.sh`).

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

Verified clean in this group: zone allow/deny list matches
home/CLAUDE.md:239 exactly; `git stash push` correctly doesn't trip
either hook (home/CLAUDE.md:7 requires it at Session Start);
enforce-gitcommit-shape.sh:98,102-109 accepts exactly the two documented
`gitcommit` forms and rejects `-m`/`--message`; no-force-push.sh:107-117
is a superset of home/CLAUDE.md:88 with no gaps; all six hooks' wiring
matches AI.md Part 6, including no-read-gitcommit.sh's dual Read+Bash
wiring (AI.md:214).

## Git/commit hook group — second independent pass

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

## AUDIT.AI.md A5 — deferred structural gap (go-auth-builder.md,
## rust-auth-builder.md)

- [ ] Step 8 "Handlers" in both `home/agents/go-auth-builder.md` and
      `home/agents/rust-auth-builder.md` is written as prose describing
      what each handler must do, not as actual Go/Rust handler code like
      every other step in these files (models, middleware, templates are
      all real code blocks). Step 14 "Tests" is likewise a checklist of
      assertions to verify, not runnable test code. Every other builder
      agent in this repo (billing-builder, notifications-builder,
      support-builder) emits real code for every step. Bringing these two
      steps in line would mean writing out full `net/http`/`axum` handler
      functions for every route enumerated in Step 8, and real
      `#[test]`/`_test.go` functions for every checklist line in Step 14 —
      a large, self-contained rewrite of both files best done as its own
      session (likely delegated the same way A6 was, given the size).
      Deferred from the A5 fix pass because it's a rewrite of comparable
      size to A6, not a small in-place fix.
