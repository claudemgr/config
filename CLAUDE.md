# {PROJECT_NAME}

## Spec

Before acting on this project:

1. Read `AI.md` in full — it is the source of truth for all implementation decisions (THE HOW). It is read-only; do not modify it during routine work.
2. Read `IDEA.md` — project description, variables (`project_name`, `project_org`, `internal_name`, `internal_org`, etc.), and business logic (THE WHAT).
3. Read `TODO.AI.md` — current task list.

Resolve `{placeholders}` from `IDEA.md ## Project variables` at runtime. Do not substitute them into `AI.md`.

If `IDEA.md` is missing or `## Project variables` is incomplete (missing `project_name`, `project_org`, `internal_name`, or `internal_org`), run the first-time setup flow defined in `AI.md` before doing anything else.

**AI.md wins on any conflict with IDEA.md. Fix IDEA.md, not AI.md.**

## Compliance

- Re-read the relevant `AI.md` section before each task.
- Verify against spec every 3–5 changes.
- Full compliance check before marking any task done.
- When uncertain: re-read the spec. Never guess.
