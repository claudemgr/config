---
name: Model routing
description: Route each unit of work to the cheapest model that can do it correctly — the largest single lever on consumption for capped plans
type: user
---

# Model Routing

Route each unit of work to the cheapest model that can do it correctly. On
capped plans (Max weekly limit) model choice is the largest single lever on
consumption — Opus and Fable cost multiples of Sonnet, so spending them on
mechanical work burns the weekly budget for no quality gain.

## Mechanism (how routing is even possible)

The main thread's model is fixed for the session — it cannot self-switch
per task. Routing to a cheaper model therefore happens **by delegation**: a
spawned subagent runs on its own model (agent frontmatter `model:`, or the
Agent tool's per-spawn `model` override), independent of the coordinating
thread. So "route to Haiku" means *delegate the subtask to a Haiku subagent*,
not switch the current thread. `fallbackModel` is availability-only, not
task-based.

## Tier table

| Task class | Model | Examples |
|---|---|---|
| Trivial / mechanical | **Haiku** (default) | renames, format conversions, single-line edits, simple lookups, mechanical refactors, moving text, grep-and-report |
| Standard coding / editing | **Sonnet** | feature work, multi-file edits, debugging, refactors with logic, writing tests, reviews |
| Deep reasoning | **Opus** | genuine architecture tradeoffs, subtle concurrency/security reasoning, a hard root-cause Sonnet already failed on |
| Visual / design | **Fable** | only when absolutely needed — UI/UX layout, visual polish, design comps where no cheaper model can produce the output; never for logic or text-only work |

## Rules

- **Default is Haiku.** The main session starts on Haiku (`settings.json`
  `model`). Escalate by delegating to a subagent on a costlier model
  (per Mechanism above), or by switching the main thread with `/model` for a
  task that genuinely needs sustained Sonnet/Opus-level reasoning throughout.
- **Never** spawn Opus or Fable for a rename, a format conversion, a grep, or
  any edit whose correctness a smaller model can verify.
- **Delegate trivial subtasks to a Haiku subagent** rather than doing them on
  a costlier coordinating model — the subagent's own model is what is billed
  for its work.
- **Escalate, don't start high.** Try Haiku first for anything that looks
  mechanical; move to Sonnet only once the task shows real coding/logic
  complexity; move a specific stuck sub-problem to Opus only after Sonnet has
  actually failed on it — never preemptively.
- **Fable only when absolutely needed.** A task is Fable-eligible only when
  the output is visual and no cheaper model can produce it. Reviewing design
  code, writing CSS logic, or editing copy is Sonnet/Haiku work, not Fable.
- **One expensive pass, then down-shift.** After an Opus/Fable step produces the
  hard artifact, return mechanical follow-up (applying edits, wiring, tests) to
  Sonnet or Haiku.
