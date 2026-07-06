---
name: make-vision
description: Inception interview that turns a raw project brain-dump into a clear VISION.md (project name, mandatory + optional goals, non-goals) and, after a feasibility gate, a dependency-ordered series of numbered task specs in tasks/. Use at the very start of a project — when the user runs /make-vision, wants to define a project's vision or goals, or bootstrap the task roadmap from an idea. Not for refining an existing design (use a grill/design skill for that).
---

# make-vision

Run at project inception. Input is a freeform brain-dump the user pastes after `/make-vision`
(available as the command argument). Output, in order: a shared understanding of scope, a feasibility
verdict on every goal, a root `VISION.md`, a README link to it, and a dependency-ordered set of task
specs in `tasks/`.

If no brain-dump was given, ask the user to describe the idea in a sentence or two first, then start.

Claude-only (it leans on `AskUserQuestion`). It does **not** touch git history or run `setup.sh`.

## How to interview

The engine is a relentless, one-question-at-a-time interview — the same technique as a grill skill,
inlined here so it works in any clone of the template with no external dependency:

- Ask **one** question at a time and wait for the answer before the next.
- **Every** question goes through `AskUserQuestion` (clickable), never plain text.
- 2–4 mutually exclusive options. Put your recommended answer **first** and append `(Doporučeno)`.
- Each option's description states the concrete trade-off. Don't add a manual "Other" (the tool adds one).
- If a question can be answered by reading the repo or the brain-dump, do that instead of asking.
- Match the user's language (the brain-dump's language). Keep going until each phase is resolved.

## Phase 1 — Name & one-liner

1. Extract a first-pass structure from the brain-dump: what it is, capabilities, constraints, any
   mandatory/optional split the user already stated, and how it differs from existing things.
2. Resolve the **project name**. If the user didn't give one, offer 2–3 candidates.
3. Confirm a single-paragraph "what this is" (the elevator pitch), free of implementation detail.

## Phase 2 — Goals & non-goals

- Classify every capability as **Mandatory** (the project fails without it) or **Optional** (nice to
  have). Surface anything the user mentioned in prose but never classified, and ask.
- Capture **Non-goals** — what this deliberately is NOT, including how it differs from adjacent tools
  the user named. Explicit no's are as valuable as the yes's.

## Phase 3 — Feasibility gate (before writing ANY task)

For each mandatory and optional goal, give an honest feasibility verdict. This is the whole point of
the gate: **no task may be written that is very hard or impossible to fulfil.** Categorize each goal:

- ✅ **Feasible** — a clear, known path exists.
- 🔬 **Needs a research spike** — plausible but unproven (unknown API, uncertain platform support).
  The roadmap's first task(s) become timeboxed spikes that de-risk it before the dependent work.
- ⛔ **Likely infeasible / no known path** — flag it, explain why, and resolve with the user via
  `AskUserQuestion`: reframe the goal, drop it, or accept it as an explicit research risk.

Ground every verdict in reality. If you don't know whether an API or capability exists, say so and
propose a spike — never assume it works. Walk the uncertain goals one at a time.

## Phase 4 — Write the artifacts

1. Write **`VISION.md`** at the repo root:
   - `# <Name>` + the one-paragraph vision.
   - `## Mandatory goals` / `## Optional goals` — bulleted, outcome-focused, no implementation detail.
   - `## Non-goals`.
   - `## Open questions & risks` — the 🔬 spikes and ⛔ items from Phase 3.
2. Add a short **`## Vision`** section near the top of `README.md` linking to `VISION.md`.
3. Generate the **opening slice of the roadmap** as numbered task specs in `tasks/`, following the
   exact skeleton defined in `tasks/README.md` (`# NN — Title`, `**Status:** Todo`,
   `**Priorita:** · **Úsilí:** · **Dopad:**`, `## Cíl`, `## Kontext`, `## Scope`, `## Mimo scope`,
   `## Hotovo když`, `## Rizika`, `## Reference`). Generate **only**:
   - the feasibility **spikes** (🔬 items) — these come first, and
   - the **mandatory foundation**: the minimal, dependency-ordered tasks that de-risk and stand up a
     first working slice toward the mandatory goals.

   Do **not** pre-plan optional goals or any work whose shape depends on an unresolved spike — the
   roadmap is a living document that grows once the spikes resolve and the foundation lands. Say that
   explicitly to the user. Every task needs a concrete, verifiable `## Hotovo když`.
   - Delete the placeholder `tasks/01-example-task.md` and number the roadmap from `01`.
   - Update `tasks/README.md`'s "Current tasks" list, then regenerate the board:
     `python3 scripts/generate_dashboard.py --no-open`.
4. If the repo is still named `Template`, suggest running `./setup.sh <Name>` — don't run it (it
   deletes git history and itself).

## Done when

- `VISION.md` exists and `README.md` links it.
- The roadmap holds the feasibility spikes plus the mandatory foundation — **not** the full backlog;
  it is expected to grow after the spikes have answered their questions.
- No task depends on an unresolved ⛔ item; uncertain goals are spikes, not blind implementation tasks.
- Hand off: the user implements each task with `/task <number>` (cross-model review runs by default),
  then re-plans the next slice once the spikes resolve.
