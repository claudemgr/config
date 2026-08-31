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
