# claudemgr/config — Implementation Spec (THE HOW)

This file is read-only during routine work. Placeholders like `{deploy_target}` resolve from `IDEA.md → ## Project variables`.

---

## Part 1: Repository Layout

```
config/
├── home/                        # mirrors ~/.claude/ exactly
│   ├── CLAUDE.md                # global AI instructions (deployed to ~/.claude/CLAUDE.md)
│   ├── settings.json            # permissions, hooks, Claude Code flags
│   ├── agents/                  # subagent definition files
│   │   └── {name}.md
│   ├── hooks/                   # PreToolUse/PostToolUse hook scripts
│   │   └── {name}.sh
│   └── memory/                  # convention and standards memory files
│       ├── MEMORY.md            # index — always kept in sync
│       └── {topic}.md
├── AI.md                        # this file — THE HOW
├── IDEA.md                      # THE WHAT
├── CLAUDE.md                    # short loader only
├── install.sh                   # deploys home/ → ~/.claude/
├── README.md
└── LICENSE.md
```

---

## Part 2: install.sh

`install.sh` copies the contents of `home/` to `{deploy_target}` (`~/.claude/`).

- Always `chmod +x` hook scripts after copy
- Never delete files from `{deploy_target}` that are not in `home/` — additive sync only, unless `--clean` is passed
- Must be idempotent — safe to run multiple times
- Tested on host (no container needed — this configures the host's Claude Code installation)
- Always commit all changes before running `install.sh` — deployed state must match the repo

---

## Part 3: home/CLAUDE.md

The global AI instruction file. Loaded by Claude Code at the start of every session in every project.

**Structure** (sections in this order):

1. `## Global Memory` — instructs AI to read `~/.claude/memory/MEMORY.md` at session start
2. `## Compaction` — what to preserve/drop when context compacts
3. `## Communication` — tone, truthfulness, question handling, terminology rules
4. `## Spelling & Grammar` — fix errors in files being edited
5. `## Code & Files` — working-set discipline, scope, style matching
6. `## Sensitive Data` — never commit credentials; all repos public by default
7. `## Project Files & Naming` — reference to `project_forbidden_files.md`
8. `## Cleanup` — project-scoped cleanup only, never broad ops
9. `## Verification & Safety` — confirm before destructive ops, never auto-bypass hooks
10. `## Self-Validation` — verify against ground truth, iterate until passing
11. `## Build & Execution` — rolling tags, execution hierarchy, multi-arch
12. `## Project Defaults` — MIT license, no feature gating, telemetry opt-in only
13. `## Output` — no preamble, tight budget, no emojis in code, no AI attribution
14. `## Tool Preference` — right tool for the job; curl/wget/grep defaults
15. `## Token & Context Discipline` — explorer for broad searches, read narrowly
16. `## Agent Usage` — Haiku for trivial tasks
17. `## Autonomy` — pre-authorized workflows, allowlists
18. `## Commit Workflow` — gitcommit only, pre-commit sequence, message format

**Rules:**
- This file governs all sessions globally — changes are high-impact
- Keep each section tight — no redundancy between sections
- Never add project-specific content here — that belongs in per-project `CLAUDE.md` files
- `{x}` = placeholder; `x` = literal — maintain this convention throughout

---

## Part 4: Memory Files (home/memory/)

Each memory file is a markdown file with YAML frontmatter:

```markdown
---
name: Short display name
description: One sentence describing what this file covers
type: user
---

## Content...
```

`MEMORY.md` is the index — every memory file must have an entry. Format:

```markdown
- [Display name](filename.md) — one-line summary of what it covers
```

**Current memory files and their scope:**

| File | Covers |
|------|--------|
| `MEMORY.md` | Index of all memory files |
| `script_conventions.md` | Shell script standards for all shells |
| `go_conventions.md` | Go project layout, Makefile, build rules |
| `rust_conventions.md` | Rust project layout, Cargo, build rules |
| `logging_conventions.md` | Log file format, pure text, log types |
| `dockerfile_conventions.md` | Two-stage builds, OCI labels, tini |
| `gitignore_conventions.md` | gitignore header format, standard entries |
| `standards_reference.md` | RFCs, HTTP codes, ISO 8601, semver, security headers |
| `never_always_rules.md` | Cross-project NEVER/ALWAYS rules |
| `user_project_conventions.md` | AI.md/IDEA.md/TODO.AI.md roles |
| `project_forbidden_files.md` | Files/dirs that must never be created |
| `sensitive_data.md` | Credential handling rules |
| `user_execution_hierarchy.md` | VM>Incus>Docker>host |
| `feedback_gitcommit.md` | gitcommit path resolution |

**Adding a new memory file:**
1. Create `home/memory/{topic}.md` with frontmatter
2. Add an entry to `home/memory/MEMORY.md`
3. Commit both in the same commit

---

## Part 5: Agent Files (home/agents/)

Each agent is a markdown file with YAML frontmatter followed by the agent's instructions:

```markdown
---
name: agent-name
description: When to invoke this agent — used by Claude to decide routing
model: haiku   # or sonnet or opus; omit to inherit from parent
---

Instructions for the agent...
```

**Rules:**
- `description` must be precise — Claude routes to agents based on it; vague descriptions cause mis-routing
- `model: haiku` for mechanical tasks (linting, renaming, lookups); omit for judgment tasks
- Agent instructions follow the same conventions as `home/CLAUDE.md` — no preamble, no AI attribution
- Agent name in the filename must match the `name:` frontmatter field

**Current agents:**

| Agent | Model | Purpose |
|-------|-------|---------|
| `script-lint.md` | haiku | Lint bash/sh/zsh/fish scripts |
| `go-lint.md` | haiku | Lint Go projects |
| `rust-lint.md` | haiku | Lint Rust projects |

---

## Part 6: Hook Scripts (home/hooks/)

Hooks are bash scripts executed by Claude Code before or after tool use. They communicate back via stdout and exit code.

**Shebang:** `#!/usr/bin/env bash` — always bash, full header per script conventions.

**Exit code protocol:**

| Exit | Meaning |
|------|---------|
| `0` | Allow — tool use proceeds |
| `2` | Block — tool use is cancelled; stdout is shown to the user |

**Blocking output format:**

```bash
echo "BLOCKED: {reason why it was blocked}"
exit 2
```

**Input:** Hook receives tool input as JSON on stdin. Parse with `jq`.

**Rules:**
- Hooks must be fast — they run synchronously before/after every matching tool call
- Never do network I/O in a hook
- Never write to files from a hook (except append-only logs)
- Always handle `jq` parse failures gracefully — malformed input must not crash the hook
- Test hooks by piping sample JSON to them directly: `echo '{...}' | ./hooks/myhook.sh`

**Current hooks:**

| Hook | Trigger | Purpose |
|------|---------|---------|
| `protect-host.sh` | PreToolUse Bash | Blocks destructive host commands |
| `no-ai-attribution.sh` | PreToolUse Write+Edit | Blocks AI attribution phrases in file content |

**Wiring hooks in settings.json:**

```json
"hooks": {
  "PreToolUse": [
    {
      "matcher": "Bash",
      "hooks": [{ "type": "command", "command": "~/.claude/hooks/protect-host.sh" }]
    }
  ]
}
```

---

## Part 7: settings.json

Controls Claude Code permissions and hook wiring. Structure:

```json
{
  "permissions": {
    "allow": [...],
    "deny": [...],
    "ask": [...]
  },
  "hooks": {
    "PreToolUse": [...],
    "PostToolUse": [...]
  }
}
```

**Permission entry format:** `"{ToolName}({glob})"` — e.g. `"Edit(**/.git/COMMIT_MESS)"`.

**Rules:**
- Explicit `allow` entries are required for sensitive paths — Claude Code has built-in sensitivity overrides that `allow` globs alone may not bypass (e.g. `.git/**` paths need explicit entries)
- Sensitive files with explicit allows: `.git/COMMIT_MESS`, `.git/COMMIT_EDITMSG`, `CLAUDE.md`, `settings.json`, `settings.local.json`, `.env`, `app.env`, `default.env`
- `deny` takes precedence over `allow`
- Hook commands use `~/.claude/hooks/` paths — never relative paths

---

## Part 8: Working on This Repo

- The active working set is `home/` and its subdirectories
- No build or compilation step — all files are deployed as-is
- Test hooks manually before committing: `echo '{"tool":"Write","input":{"file_path":"test","content":"foo"}}' | bash home/hooks/no-ai-attribution.sh`
- Validate `settings.json` with `jq . home/settings.json` before committing
- Validate memory file frontmatter: must have `name`, `description`, `type` fields
- Run `install.sh` after committing to deploy — never deploy uncommitted changes
- Changes here affect every Claude Code session on the machine — test carefully

---

## Part 9: Commit Conventions

Follow the global gitcommit workflow from `home/CLAUDE.md`. One logical change per commit.

When adding a memory file: commit both the new file and the updated `MEMORY.md` together.
When adding an agent: commit the agent file; update `AI.md` Part 5 table in the same commit.
When adding a hook: commit the script and the updated `settings.json` wiring together.
