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

## Tier table

| Task class | Model | Examples |
|---|---|---|
| Trivial / mechanical | **Haiku** | renames, format conversions, single-line edits, simple lookups, mechanical refactors, moving text, grep-and-report |
| Standard coding / editing | **Sonnet** (default) | feature work, multi-file edits, debugging, refactors with logic, writing tests, reviews |
| Deep reasoning | **Opus** | genuine architecture tradeoffs, subtle concurrency/security reasoning, a hard root-cause Sonnet already failed on |
| Visual / design | **Fable** | UI/UX layout, visual polish, design comps — never for logic or text-only work |

## Rules

- **Default is Sonnet.** Do not reach for Opus or Fable unless the task clearly
  falls in its row above.
- **Never** spawn Opus or Fable for a rename, a format conversion, a grep, or
  any edit whose correctness a smaller model can verify.
- **Delegate trivial subtasks to a Haiku subagent** rather than doing them on
  the coordinating (Sonnet/Opus) model — the subagent's own model is what is
  billed for its work.
- **Escalate, don't start high.** Try Sonnet first; move a specific stuck
  sub-problem to Opus only after Sonnet has actually failed on it — never
  preemptively.
- **Fable is for pixels, not prose.** A task is Fable-eligible only when the
  output is visual. Reviewing design code, writing CSS logic, or editing copy
  is Sonnet work.
- **One expensive pass, then down-shift.** After an Opus/Fable step produces the
  hard artifact, return mechanical follow-up (applying edits, wiring, tests) to
  Sonnet or Haiku.
