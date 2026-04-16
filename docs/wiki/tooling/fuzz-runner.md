---
kind: concept
status: supported
last_reviewed: 2026-04-16
sources:
  - ../raw/research/0003-2026-03-12-fuzz-migration.md
related:
  - ../../../src/fuzz/main.mbt
  - ../../../scripts/lib/fuzz-task.ts
  - ../../../scripts/test/task-family-commands.ts
  - ../../../AGENTS.md
---

# Fuzz Runner Workflow

## Durable Conclusions

- Heavy randomized workloads belong in `src/fuzz` and run through `moon run src/fuzz -- ...`.
- `moon test` stays deterministic and fast; large randomized loops should not move back into package tests.
- The shared profile ladder is `smoke`, `ci`, `stress`.
- Every fuzz lane must be rerunnable from logged `suite`, `profile`, and `seed`.
- Moon commands should stay serialized because they contend on `_build/.moon-lock`.

## Current Entry Surface

- Core runner: [`../../../src/fuzz/main.mbt`](../../../src/fuzz/main.mbt)
- Bun wrapper: [`../../../scripts/lib/fuzz-task.ts`](../../../scripts/lib/fuzz-task.ts)
- Discovery commands:
  `--help`, `--list-suites`, `--list-profiles`
- Current active suites are `validate-valid`, `binary-roundtrip`, `wast-roundtrip`, `wat-roundtrip`, and `cmd-harness`.
- `--list-suites` currently prints an inventory line per suite as `active\t<name>` or `reserved\t<name>` so the future invalid-lane ids are visible without being misrepresented as runnable.
- The reserved future invalid-lane ids are `validate-invalid-ast`, `validate-invalid-binary`, `validate-invalid-text`, and `validate-invalid-spec-seed`.

## Practical Rule

- When adding fuzz work, add or extend a named `src/fuzz` suite instead of burying it in `moon test`.
- Keep deterministic reducers and invariants beside implementation tests, and keep long randomized exploration in the fuzz runner.
- Preserve the suite/profile/seed contract in both Moon and Bun entrypoints so failures stay reproducible.

## Sources

- Archived research doc: [`../raw/research/0003-2026-03-12-fuzz-migration.md`](../raw/research/0003-2026-03-12-fuzz-migration.md)
- Runner implementation: [`../../../src/fuzz/main.mbt`](../../../src/fuzz/main.mbt)
