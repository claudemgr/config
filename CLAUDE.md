# {PROJECT_NAME}

## New project detection

If `AI.md` or `IDEA.md` is missing, this is a new project. Stop and plan:
1. Ask the user what the project does (if `IDEA.md` is absent).
2. Create `IDEA.md` with the required three sections (`## Project description`, `## Project variables`, `## Business logic`).
3. Copy the appropriate `TEMPLATE.md` from `claudemgr` into this repo as `AI.md`.
4. Create `PLAN.AI.md` with the implementation plan before writing any code.
5. Create `TODO.AI.md` with the task list derived from the plan.

## Session start

Before acting on this project, read in order:

1. `AI.md` — source of truth for all implementation decisions (THE HOW). Read-only; never modify during routine work.
2. `IDEA.md` — project description, variables, and business logic (THE WHAT). Resolve `{placeholders}` from `## Project variables` at runtime; do not substitute them into `AI.md`.
3. `PLAN.AI.md` — current AI implementation plan (if it exists).
4. `TODO.AI.md` — current AI task list (if it exists).
5. `PLAN.md` — human implementation plan (if it exists); AI may mark items done, never rewrite wholesale.
6. `TODO.md` — human task list (if it exists); AI may mark items done, never delete or empty.

**AI.md wins on any conflict with IDEA.md. Fix IDEA.md, not AI.md.**

## Task tracking rules

- Use `TODO.AI.md` whenever working on more than 2 items.
- Remove completed items from `TODO.AI.md` as they are finished — do not accumulate done items.
- `TODO.md` and `PLAN.md` are human-owned: AI marks done but never deletes entries or rewrites wholesale.
- Update `PLAN.AI.md` when the approach changes mid-task.

## Compliance

- Re-read the relevant `AI.md` section before each task.
- Verify against spec every 3–5 changes.
- Full compliance check before marking any task done.
- When uncertain: re-read the spec. Never guess.
