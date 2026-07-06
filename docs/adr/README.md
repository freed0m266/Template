# Architecture Decision Records

Short, dated notes recording *why* a non-obvious decision was made — so a future reader (or agent)
doesn't have to reverse-engineer the reasoning from the code, or re-litigate a settled trade-off.

## Numbering

Sequential: `0001-slug.md`, `0002-slug.md`, … Scan this directory for the highest number and add one.

## When to write one

Only when **all three** are true:

1. **Hard to reverse** — changing your mind later carries a real cost.
2. **Surprising without context** — a reader will look at the code and wonder "why on earth this way?".
3. **The result of a real trade-off** — there were genuine alternatives and you picked one for reasons.

If a decision is easy to undo, not surprising, or had no real alternative, skip it.

## Format

An ADR can be a single paragraph: what's the context, what did we decide, why. Add
`## Considered alternatives` / `## Consequences` sections only when they carry genuine value.

## Records

- [0001 — Tuist environments (Testing / Production), default `.testing`](0001-tuist-environments-default-testing.md)
