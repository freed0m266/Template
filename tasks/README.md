# Roadmap

Numbered task specs for the project. Each task is a self-contained markdown document with a
fixed structure (goal, context, scope, out-of-scope, done criteria, risks, references).

## How to use

Pick up a task with the `/task <number>` Claude command (defined in
[`.claude/commands/task.md`](../.claude/commands/task.md)). It will:

1. Read the task file and any referenced files for context.
2. Branch off `main` (naming `feature/<NN>-<short-slug>`).
3. Implement the scope, writing tests alongside the code.
4. Run `codex review --uncommitted` on the staged diff and apply legitimate findings.
5. Mark the task done with `**Status:** Done — YYYY-MM-DD` at the top.

Pass `--skip-review` to skip step 4 — useful for purely mechanical scaffolding tasks.

`/task` never commits — staging is intentional, you decide when to write the commit message.

## Conventions

Each task file follows this skeleton:

```markdown
# NN — Title

**Status:** Todo

**Priorita:** v1.0 · **Úsilí:** S/M/L · **Dopad:** Low/Medium/High

## Cíl

One paragraph: what success looks like.

## Kontext

What the implementer needs to know before writing code — relevant existing files,
prior decisions, constraints, gotchas.

## Scope

### 1. Sub-task name

Concrete steps with file paths.

### 2. Another sub-task

…

## Mimo scope

- Explicit non-goals. Kills "scope creep" debates.

## Hotovo když

- Checklist of objective done criteria.
- Build passes, tests green, manual verify done.

## Rizika

- Edge cases, things to watch for, fragile interactions.

## Reference

- File paths, external documentation links.
```

## Current tasks

1. [01 — Example task](01-example-task.md)
