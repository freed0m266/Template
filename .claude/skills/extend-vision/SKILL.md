---
name: extend-vision
description: Companion to make-vision that grows an EXISTING project vision. Runs the same interview + feasibility gate for one new increment, appends new numbered task specs to tasks/ (continuing the numbering — never renumbering or deleting existing tasks), and reconciles VISION.md plus every other place the vision is mentioned. Use for a larger update or next milestone after the MVP — when the user runs /extend-vision, wants to expand the vision, add a new capability or goal, or plan the next slice of work on a project that already has a VISION.md. For a brand-new project with no vision yet, use make-vision instead.
---

# extend-vision

Grows an existing vision. This is the "second act" to `make-vision`: `make-vision` bootstraps the MVP
vision on a greenfield project; `extend-vision` plans each larger increment on top of what already ships.

**Precondition:** `VISION.md` exists and `tasks/` holds real tasks. If `VISION.md` is missing (or
`tasks/` still only has the placeholder example), stop and point the user to `/make-vision` — there is
no vision to extend yet.

**Input:** a freeform description of the new capability/direction the user pastes after
`/extend-vision`. If none was given, ask what they want to add, then start.

**Reuses `make-vision`'s machinery.** Read `.claude/skills/make-vision/SKILL.md` and apply its
**How to interview** rules and its **Phase 3 feasibility gate** verbatim, plus the task skeleton in
`tasks/README.md`. This skill only describes what is *different* when growing rather than bootstrapping.

Claude-only. Does **not** touch git history or run `setup.sh`, and **never deletes or renumbers**
existing tasks.

## Workflow

1. **Load current state.** Read `VISION.md` (name, existing mandatory/optional goals, non-goals, open
   questions) and the existing `tasks/` roadmap (highest task number, what is Done vs Todo). This is
   the ground truth the increment builds on.
2. **Interview for the increment** (make-vision's interview rules — one question at a time, always
   `AskUserQuestion`, recommended answer first). Clarify the new capability, classify each new goal
   **Mandatory** / **Optional**, and surface any new non-goals. **Reconcile against what exists:** if a
   new goal duplicates or conflicts with an existing goal or non-goal, flag it (`AskUserQuestion`:
   extend it / replace it / drop it) — don't silently add a duplicate or leave a contradiction.
3. **Feasibility gate** (make-vision Phase 3) on the **new** goals only: ✅ / 🔬 / ⛔, spikes first for
   uncertain new work. Ground verdicts in reality; propose a spike rather than assuming an API exists.
4. **Write the artifacts:**
   - **Update `VISION.md` in place.** Add the new goals to `## Mandatory goals` / `## Optional goals`,
     add any new `## Non-goals`, and fold the new 🔬/⛔ items into `## Open questions & risks`. Keep
     already-shipped goals. If the increment genuinely changes or retires an existing goal, edit it and
     note that — never leave stale contradictions.
   - **Reconcile every other mention of the vision.** Grep the repo for references (at minimum the
     `## Vision` section in `README.md`); update the one-paragraph pitch only if the increment changes
     what the project fundamentally *is*.
   - **Append the next roadmap slice to `tasks/`** (same skeleton as `tasks/README.md`). Generate
     **only** this increment's feasibility **spikes** + the **foundation** for its mandatory goals — not
     a full backlog; the roadmap keeps growing. **Continue numbering from the current highest task
     number**; never renumber or delete existing tasks. Use `## Reference` to link new tasks to the
     shipped ones they depend on.
   - Update `tasks/README.md`'s "Current tasks" list, then regenerate the board:
     `python3 scripts/generate_dashboard.py --no-open`.

## Done when

- `VISION.md` reflects the new goals with **no stale contradictions**, and every place that referenced
  the vision is consistent with it.
- New tasks are **appended** (continued numbering); existing tasks are untouched.
- This increment's roadmap = its spikes + mandatory foundation, not the full backlog.
- Hand off: the user implements each new task with `/task <number>` (cross-model review runs by default).
