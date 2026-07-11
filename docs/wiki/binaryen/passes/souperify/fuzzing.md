---
kind: workflow
status: planned
last_reviewed: 2026-07-11
sources:
  - ../../../raw/fuzzing/2026-07-11-pass-fuzz-admission-boundary-audit.md
  - ../../../tooling/pass-fuzz-compare.md
  - ../../../../../scripts/lib/pass-fuzz-compare-task.ts
  - ../../../../../src/passes/optimize.mbt
related:
  - ./index.md
  - ./starshine-strategy.md
  - ./flat-dataflow-traces-and-single-use-boundaries.md
  - ../../../tooling/pass-fuzz-compare.md
---

# `souperify` fuzzing status

## Current status: planned only—and not an ordinary compare-pass target

Do **not** run or advertise `bun fuzz compare-pass --pass souperify ...` as a current smoke lane.

- [`scripts/lib/pass-fuzz-compare-task.ts`](../../../../../scripts/lib/pass-fuzz-compare-task.ts) does not admit `souperify` or `souperify-single-use` in `SUPPORTED_PASS_FLAGS`; parsing stops before input generation or either optimizer runs.
- [`src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt) does not even track the names as boundary-only: current Starshine requests are unknown-pass failures.
- Binaryen's public pass emits bounded Souper text from flat/DataFlow analysis rather than primarily rewriting a wasm module. The normal compare-pass oracle compares normalized wasm outputs, so merely adding an allowlist entry would not establish the correct product oracle.
- Parser rejection, unknown-pass output, and zero comparisons are status checks only; see [`../../../raw/fuzzing/2026-07-11-pass-fuzz-admission-boundary-audit.md`](../../../raw/fuzzing/2026-07-11-pass-fuzz-admission-boundary-audit.md).

Use `bun fuzz compare-pass --list-passes` only to inspect the current ordinary wasm-transform roster.

## Future validation design

Before any fuzz lane, Starshine needs a deliberate user-visible trace-output contract: registry pass, analysis/export command, or debugger subcommand. The oracle should compare stable Souper text/artifacts against Binaryen, while separately proving the input wasm is unchanged unless a local API intentionally says otherwise.

Fixture and fuzz coverage should include:

- flat straight-line integer expressions and non-flat rejection;
- bounded trace depth/node fallback to fresh `var`s;
- local use, external use, and the `souperify-single-use` truncation rule;
- `if`-derived `pc` / `blockpc`, phi/block joins, and conservative loop behavior; and
- unsupported operators and invalid merges.

A future command must therefore name the eventual trace-oracle runner rather than copying the ordinary wasm compare template. If a Starshine implementation also exposes an explicit non-mutating pass flag, `compare-pass` may test its no-mutation property, but it must not replace text-oracle coverage.
