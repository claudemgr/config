# AUDIT.AI.md

Findings from the `audit` agent pass comparing all 27 `home/hooks/*.sh` against
`home/CLAUDE.md`, `AI.md`, and `home/memory/*.md`. Logged per the "No issue
left only in conversation" rule (>5 issues → this file, not TODO.AI.md).
Nothing has been fixed yet — this is the raw record. Status: OPEN.

## Priority 0 — live security bypasses (fix first, no judgment call needed)

- [x] D1 (FIXED): `no-destructive-bypass.sh` now masks quoted strings
      (same technique as `bound-shell-lifetime.sh`'s `mask_quotes`) before
      splitting on separators, then slices the original text by the masked
      match positions — a `|` inside a quoted string (e.g. a `grep`
      pattern) no longer causes a false-positive split/block.
- [x] D2 (FIXED): `no-destructive-bypass.sh` now peels a wrapping
      subshell/command-substitution `(dd …)`/`$(dd …)`/`` `dd …` ``
      before tokenizing, recurses into `xargs`'s trailing command (after
      skipping xargs's own flags), recurses into `bash -c '…'`/`sh -c
      "…"` payloads (re-splitting and re-scanning them), and normalizes
      the command basename (`/bin/dd` → `dd`, `/usr/bin/git` → `git`)
      before comparison — closing all four bypasses.
- [x] D3 (FIXED): `protect-host.sh` removed `chroot`/`nsenter`/`virsh`
      from the container-prefix exemption list — these are
      host-namespace-entering or host-side tools, not guest isolation,
      so `chroot /mnt rm -rf /etc` and `nsenter -t 1 -m rm -rf /etc` are
      now blocked like any other destructive host command.
- [x] D4 (FIXED): `protect-host.sh`'s sweep escape valve now extracts
      just the `ps`/`ls`/`list` segment of the command (up to the next
      `;`/`&`/`|`) and checks `--filter`/`name=`/`label=` only within
      that segment, instead of against the whole raw command string — an
      unrelated `name=` substring elsewhere in the pipeline (e.g. inside
      the kill/stop/rm target list) no longer satisfies the check.

## Priority 1 — needs a decision (delete the rule vs. add the missing spec line)

`protect-host.sh` enforces five entire rule families with no spec backing
anywhere in `home/CLAUDE.md` or `home/memory/*.md`:
- [x] Auth-critical file protection (`/etc/passwd`, `/etc/shadow`,
      `/etc/sudoers`, …) — formalized into `security_conventions.md`'s
      new "Protected Host Paths" section
- [x] 15-entry top-level system-dir list vs. spec's 6-entry floor
      (`/`,`/boot`,`/sys`,`/proc`,`/dev`,partition/bootloader) —
      formalized into the same new section
- [x] Delete-on `/bin`,`/usr/bin`,`/sbin`,`/usr/sbin` (write-half is
      sourced at `project_files.md:86`, delete-half is not) —
      formalized into the same new section
- [x] Shell-redirect rule + pseudo-device allowlist — formalized into
      the same new section
- [x] `find -delete` / `find -exec rm` rule — formalized into the same
      new section
- [x] `systemctl isolate`/`kill` in the confirm-gate (spec lists
      `restart|stop|start|reload|disable|enable|mask|unmask|edit|
      set-property` only) — formalized: added `isolate`/`kill` to
      `home/CLAUDE.md`'s systemctl gate rule and "Still hard" zone list
      (same blast-radius risk class as `mask`/`unmask`/`edit`/
      `set-property`)
- [x] `pkill`/`killall`/`pgrep` blocking — already sourced: matches
      `home/CLAUDE.md`'s "kill scoping" rule ("`kill $PID` only when
      `$PID` was captured at launch") verbatim; no change needed, this
      was a missing-citation false positive, not an actual gap

`no-forbidden-files.sh` — entire forbidden-name set has no source in
`project_files.md`, AND allowlists what the spec actually forbids:
- [x] Unsourced: `FORBIDDEN_BASENAMES` (`.netrc`, `credentials.json`,
      `id_rsa`, `.ds_store`, `thumbs.db`, …) — formalized into
      `project_files.md`'s new "Forbidden Basenames & Extensions" section
- [x] Unsourced: `.p12`/`.pfx`/`.jks`/`.p8`/`.ppk` — formalized in the
      same new `project_files.md` section
- [x] Wrong direction: blocks `id_rsa.pub`/`id_ed25519.pub` (public keys;
      spec names private keys only) — removed from
      `FORBIDDEN_BASENAMES`, `.ssh/id_` path pattern now excludes `*.pub`
- [x] Unsourced: blocks `.aws/config` (holds no credentials) — removed
      from `FORBIDDEN_PATH_PATTERNS`
- [x] Unsourced: `docs/` MkDocs carve-out (zero `mkdocs` hits in spec) —
      formalized into `project_files.md`
- [x] Contradiction: allows `Dockerfile`/`docker-compose.yml` at repo
      root; spec requires `docker/` — removed from always-allow,
      `LOCATION_RESTRICTED_DOCKER_BASENAMES` now requires a `docker/`
      path
- [x] Contradiction: allowlists `/vendor/`, `/node_modules/`; spec
      forbids both dirs — removed from always-allow, added to
      `FORBIDDEN_PATH_PATTERNS`
- [x] Contradiction: allows `.env.template`, not in spec's exception set
      — removed; `app.env.*`/`default.env.*` variants the spec does name
      were added
- [x] Missing: hook enforces none of spec's actual forbidden entries
      (`SUMMARY.md`, `COMPLIANCE.md`, `NOTES.md`, `AUDIT.md`, `REPORT.md`,
      `ANALYSIS.md`, all 11 forbidden directories) — added
      `FORBIDDEN_REPORT_BASENAMES` (exact-match, `AUDIT.AI.md` stays
      exempt) and cwd-scoped `FORBIDDEN_ROOT_DIRNAMES` via the hook
      payload's `cwd` field

- [x] `no-destructive-bypass.sh:140-154` blocks `dd`/`shred`/`mkfs*`/`wipefs`
      unconditionally with no confirm path; `home/CLAUDE.md:88,97` frames
      these as "confirm first", not deny — NOT a hook bug: `settings.json`'s
      `permissions.deny` already hard-denies `git reset`/`dd`/`shred`/
      `mkfs*`/`wipefs` with no confirm path at the permission layer, and the
      hook correctly re-enforces that stricter deny (against wrapper
      bypasses `permissions.deny`'s raw glob match can't catch). Formalized
      by adding a clarifying line to `home/CLAUDE.md`'s Verification &
      Safety section: these five are hard-denied, not confirm-gated,
      overriding the general "confirm before irreversible" default.
- [x] `no-secrets.sh:59-68` and `bash-content-scan.sh:166-171` exempt
      `.env.example`/zone paths without checking repo-visibility-confirmed-
      private, which `sensitive_data.md:35` and `home/CLAUDE.md:89-94`
      require as a precondition — NOT fixable as a live hook check: AI.md
      Part 6's hook rules forbid network I/O (`gh repo view` would be
      network I/O), so a hook can never verify visibility itself.
      Formalized in `sensitive_data.md`: the precondition is enforced
      procedurally by the Repo privacy gate (steps 1-5), not technically by
      these hooks — cwd scoping is necessary but not sufficient; the
      privacy-gate workflow is what makes the exemption actually safe.

## Priority 2 — invented enforcement, narrower scope (no judgment call, just fix)

- [x] `enforce-test-lint-gate.sh:126,129-131` — 4-level depth limit on the
      script scan; spec says "anywhere in its tree", unqualified. Fixed:
      depth limit removed.
- [x] `enforce-test-lint-gate.sh:160-165` — a manifest-only project
      (e.g. only `package.json`) can never satisfy the lint gate, since a
      lint marker only comes from script-lint/go-lint/rust-lint. Verified:
      unsatisfiable deadlock for Node/Python-only projects. Fixed: lint
      gate skipped for projects with no defined lint agent.
- [x] `enforce-test-lint-gate.sh:137-141` / AI.md:226 — no carve-out for
      `install.sh`-only spec-collection repos; `project_type_conventions.md
      :182` says an `install.sh` alone does not disqualify spec-collection.
      Fixed: install.sh-only carve-out added.
- [x] `enforce-test-lint-gate.sh:150-157` — spec-collection substitute
      checks "AI.md/SPEC.md was read", spec requires re-reading the
      edited/changed file(s) instead. Fixed.
- [x] `enforce-test-lint-gate.sh:138` / `test-lint-mark.sh:100` — adds
      `Makefile`/`setup.py` to the manifest list beyond spec's
      go.mod/Cargo.toml/package.json/pyproject.toml. Fixed: manifest list
      narrowed to spec's four.
- [x] `bound-shell-lifetime.sh:209` — sentinel tokens `.output`/`/tasks/`
      unsourced; spec only names `*.done`. Fixed: narrowed to `*.done`.
- [x] `bound-shell-lifetime.sh:206-213` — blocks sentinel polls even when
      wrapped in `timeout {n}`; spec exempts anything under `timeout {n}`
      with no carve-out. Verified live. Fixed: the blanket bounded-check
      now runs before the sentinel-specific check.
- [x] `enforce-docker-rm.sh:107,156,162` — enforces `lxc launch|init`;
      spec (`execution_hierarchy.md:29-37,96`) says Incus only. Fixed:
      lxc dropped from the launch/init naming enforcement.
- [x] `no-history-rewrite.sh:132-133,173-176` — undocumented `git clean
      -fn` dry-run carve-out (behaviorally fine, not written anywhere).
      Fixed: documented, and is_dry_run() now also matches combined
      short flags (-fn/-nf), which the original carve-out missed.
- [x] `no-history-rewrite.sh:123-129,189-192` — tag-delete matching
      extended to `-D`/combined flags; spec names `-d` only. Inconsistent
      with same file's branch-delete matcher (correctly `-D` only). Fixed:
      narrowed to -d/--delete (and combined flags carrying lowercase d).
- [x] `no-ai-attribution.sh:52` — bare regex match on the phrase itself
      with no scope check; spec scopes the rule to trailers/footers, this
      blocks any file merely discussing that phrase as a topic (this file
      had to be reworded once already while being written, to avoid the
      hook self-triggering on a description of its own bug). Fixed:
      matching anchored to line-start after stripping comment/quote
      leaders.
- [x] `no-read-gitcommit.sh:91-93` — `cp`/`diff` added to READ_VERBS
      beyond spec's `cat/less/head/etc`. Fixed: cp/diff dropped.
- [x] `no-read-gitcommit.sh:57-60` — hardcodes `/usr/local/bin/gitcommit`;
      spec (`gitcommit_conventions.md:7`) forbids this exact pattern
      verbatim, using that path as its own counter-example. Fixed:
      resolved dynamically via shutil.which("gitcommit").
- [x] Marker temp paths (`test-lint-mark.sh:109`, `lint-agent-mark.sh:63`,
      `enforce-test-lint-gate.sh:112-113`) use
      `${TMPDIR}/claude-test-lint-guard/…`, not the mandated
      `${TMPDIR}/{project_org}/{internal_name}-XXXXXX/` shape
      (`tempdir_conventions.md:16,30,32` names this exact shape FORBIDDEN).
      Fixed: moved to `${TMPDIR}/claudemgr/config/test-lint-guard/${session_id}`
      — session_id takes the -XXXXXX uniqueness role since the marker must
      stay reconstructable by session_id alone; org/internal_name namespacing
      now matches the mandated shape.
- [x] `trailing-newline-guard.sh:70` — exempts `.pem`/`.key`/`.crt`/`.der`;
      spec requires trailing newline on PEM keys specifically.
      Fixed: dropped `.pem`/`.key`/`.crt` from `EXEMPT_EXT` — they're text
      (base64/PEM-armored), not binary; `.der`/`.p12`/`.pfx` stay exempt as
      genuinely binary encodings, per `file_ending_conventions.md:12`.
- [ ] `no-todo-comments.sh:76-92` — runs on every file type, not just
      code; a Markdown `# TODO` heading or `* key = value` bullet false-
      positives as commented-out code.
- [ ] `comment-placement-guard.sh:137` — SHA-pin exemption limited to
      `.github/workflows/`; spec also covers `.gitea/workflows/` and
      `.forgejo/workflows/`.
- [ ] `lint-agent-mark.sh:50-72` — marks lint gate satisfied on subagent
      completion with no pass/fail signal; spec requires "never commit
      with violations". Also derives project from hook's own cwd, not the
      directory the lint agent actually inspected.
- [ ] `block-host-toolchain.sh` — hardcoded tier-3 images at every
      `__block` call, ignoring spec's project-declared-image-first order;
      no `--memory`/`--cpus` in any suggestion; several suggestions use
      debian/ubuntu images against spec's alpine-only rule (justified only
      by lack of official Alpine image — undocumented exception); exempts
      `python`/`python3` and has no branch for `ruff`/`mypy` at all,
      against `python_conventions.md:93`; Rust suggestion omits
      `-e RUSTC_WRAPPER=sccache`; Node/Python suggestions omit cache
      mounts spec requires.
- [ ] `protect-host.sh:222` — writes BLOCKED message to stderr only;
      AI.md:189,193-196 mandate stdout.
- [ ] `protect-host.sh` / `no-destructive-bypass.sh` — both parse with
      python3, not `jq` as AI.md:198 specifies.
- [ ] `test-lint-mark.sh:110-114` / `lint-agent-mark.sh:64-68` — hooks
      delete files (`find … -exec rm -rf`); AI.md:203 says hooks may only
      append to logs. Scoped to own namespace so not unsafe, but still a
      Part 6 documentation violation.

## Priority 3 — AI.md Part 6 table corrections (doc-only, no logic change)

- [ ] AI.md:215 (`protect-host.sh`) row severely under-describes actual
      behavior (omits container/sweep blocking, prune blocking, pkill,
      partition/bootloader, redirects, find-delete, container exemption).
- [ ] AI.md:213 (`drift-guard-read.sh`) — says it checks for a
      corresponding `home/` source file; it doesn't, it's a fixed path
      prefix list gated only on repo containing `home/CLAUDE.md`.
- [ ] AI.md:218 (`bound-shell-lifetime.sh`) — omits rule E (`&` without
      `PID=$!`) and the sentinel-poll-blocked-even-when-bounded behavior.
- [ ] AI.md:221 (`no-force-push.sh`) row incomplete re: `--force-with-lease`
      (code is correct, row just doesn't mention it).
- [ ] AI.md:221/222 — container-mediated heredoc exemption documented
      only for `bash-content-scan.sh`, but also present in
      `no-force-push.sh`/`no-history-rewrite.sh`.
- [ ] AI.md:226 — repeats the incorrect spec-collection test description
      (see Priority 2 `enforce-test-lint-gate.sh:150-157` item).
- [ ] AI.md:216 (`block-host-toolchain.sh`) — doesn't mention suggestions
      are fixed tier-3 images rather than the project's declared one.
- [ ] `no-destructive-bypass.sh:23-26` header claims container-mediated
      invocations are denied unconditionally; code never looks past the
      head token, so `docker run … alpine dd if=…` is actually allowed.
- [ ] `spec-guard.sh:18` header's exempt-file list omits the seven files
      actually exempted at `:46-47`.
- [ ] `home/settings.json` uses `$HOME/.claude/hooks/`; AI.md:278 and its
      own example (:243-249) mandate `~/.claude/hooks/`.
- [ ] `home/memory/file_ending_conventions.md` has no YAML frontmatter,
      violating AI.md:80-90 / the pre-commit validation step at AI.md:288.
- [ ] Spec self-contradiction: `project_type_conventions.md:23` lists
      `claudemgr/config` as a spec-collection example; `:178` says it is
      not one. Hooks correctly follow `:178` — the `:23` line needs fixing.

## Priority 4 — documented gaps, no hook coverage (informational, no fix required unless requested)

`execution_hierarchy.md` (`--memory`/`--cpus`, `--network host`, `-it`,
`{project_name}-XXXX` naming, `docker compose up -d`) unchecked by
`enforce-docker-rm.sh`; `comment_conventions.md` (`.env`, CSV/TSV, CSS
`//`) unchecked; `sensitive_data.md` (passwords, internal hostnames/IPs,
DB connection strings) has no `no-secrets.sh` pattern; per-call `timeout`
requirement (`shell_lifetime_conventions.md:11-12`) never inspected.

---

Deployment note: all fixes must be `cp`'d from `home/hooks/*.sh` to
`~/.claude/hooks/*.sh` after editing — the deployed copy is what the
harness actually executes; the source-only edit has zero live effect
until deployed (this was the actual cause of the "still blocked" report
resolved earlier this session).
