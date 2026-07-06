---
description: Start working on a numbered task from tasks/ (Codex review runs by default)
argument-hint: <number> [--skip-review]
---

Start working on the task numbered `$1` from the `tasks/` folder.

`/task <number>` runs the task and then runs a Codex closing review on the staged changes.
`/task <number> --skip-review` (or `-s`) skips the review — useful for purely mechanical scaffolding
tasks where review wouldn't catch anything substantive.

## Workflow

1. Parse the first argument as the task number. Accept both `2` and `02`.
2. Strip leading zeros and match either `tasks/<n>-*.md` or `tasks/0<n>-*.md`.
3. If no file matches, list available tasks with `ls tasks/` and stop.
4. Read the matched task file fully.
5. Read `AGENTS.md`, `CLAUDE.md`, and any files referenced by the task scope so there is enough
   context to implement safely.
6. Briefly confirm understanding in one or two sentences, including any open questions. If scope
   ambiguity affects implementation, ask before coding.
7. Create or switch to a branch before making task changes.
   - Branch naming: `feature/<zero-padded-number>-<short-kebab-slug>` derived from the task
     filename, e.g. `tasks/02-fiat-currency-selection.md` → `feature/02-fiat-currency-selection`.
   - Branch from `main`. If the branch already exists, switch to it.
   - If the working tree is dirty before switching, stop and ask the user how to proceed.
8. Implement the task.
   - Follow the project conventions in `AGENTS.md` (MVVM, protocol-first, `@Observable`, DI via
     `AppDependency`, mocks under `Testing/`, `#if DEBUG` for previews).
   - Respect the task's Scope, Mimo scope, Hotovo když, Rizika, and Reference sections.
   - Add or update focused tests/snapshots for the touched target.
   - Run relevant verification (`tuist generate` if targets/resources changed, then the target's
     test scheme).
9. Unless `--skip-review` or `-s` was passed, run the Codex closing review (below).
10. After accepted review findings are handled and tests are re-run, mark the task done by appending
    `**Status:** Done — <YYYY-MM-DD>` near the top of the task file. Do not delete the task file.

Do not commit changes unless the user explicitly asks.

## Codex closing review

1. Stage the task changes with `git add ...`.
2. Run `codex review --uncommitted` on the staged diff. Codex defaults to `gpt-5.5` with
   `model_reasoning_effort = "xhigh"` (configured in `~/.codex/config.toml`) — no flags needed.
3. Wait for Codex to finish and triage the findings:
   - Apply findings that identify real bugs, missing edge cases, concurrency/memory issues,
     incorrect API usage, or substantially better designs that fit the task and project conventions.
     Re-run tests after each applied finding.
   - Skip findings that are off-base, context-unaware, outside task scope, contradict an explicit
     decision, or are clearly hallucinated (e.g. claiming code won't compile when tests just passed).
     Note the reason briefly.
   - Pause and ask the user if a finding has security/data-loss implications or if it is genuinely
     unclear whether it should land.
4. Re-run relevant tests after applying any finding.
5. If Codex times out, returns nothing, or repeatedly produces nonsense, log that and continue
   without applying review changes for this task.
6. Report back with: `Codex found N findings — applied P (…), skipped S (…).`
