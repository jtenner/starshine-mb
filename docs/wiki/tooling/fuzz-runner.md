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
- Batch command:
  `--emit-gen-valid-batch --count <n> --seed <uint64> --out-dir <dir>`
- Current active suites are `validate-valid`, `validate-invalid-ast`, `validate-invalid-binary`, `validate-invalid-text`, `validate-invalid-spec-seed`, `binary-roundtrip`, `wast-roundtrip`, `wat-roundtrip`, and `cmd-harness`.
- `--list-suites` still prints an inventory line per suite as `active\t<name>` or `reserved\t<name>`, but there are currently no reserved validator-rejection suite ids left in the tree.
- The Bun wrapper now forwards the same discovery and batch surfaces as the Moon entrypoint, so `bun fuzz run --help`, `--list-suites`, `--list-profiles`, and `--emit-gen-valid-batch ...` stay aligned with `src/fuzz/main.mbt` instead of carrying a narrower wrapper-only contract.

## Practical Rule

- When adding fuzz work, add or extend a named `src/fuzz` suite instead of burying it in `moon test`.
- Keep deterministic reducers and invariants beside implementation tests, and keep long randomized exploration in the fuzz runner.
- Preserve the suite/profile/seed contract in both Moon and Bun entrypoints so failures stay reproducible, and keep persisted invalid-repro metadata compatible with that same contract.

## Sources

- Archived research doc: [`../raw/research/0003-2026-03-12-fuzz-migration.md`](../raw/research/0003-2026-03-12-fuzz-migration.md)
- Runner implementation: [`../../../src/fuzz/main.mbt`](../../../src/fuzz/main.mbt)
