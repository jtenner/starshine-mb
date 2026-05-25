---
kind: research-note
status: completed
created: 2026-05-25
sources:
  - ../../../../src/passes/simplify_globals_optimizing_test.mbt
  - ../../binaryen/passes/simplify-globals-optimizing/parity-matrix.md
  - ../../binaryen/passes/simplify-globals-optimizing/starshine-port-readiness-and-validation.md
  - ../../../../.tmp/sgo003c-probes/nested-if-first-arm.wat
  - ../../../../.tmp/sgo003c-probes/nested-if-both-arms.wat
  - ../../../../.tmp/pass-fuzz-sgo-nested-if-arm-placement-10k/result.json
---

# SGO nested-if arm placement guardrails (`[SGO]003C`)

## Scope

This source-alignment slice pins a focused nested `if (result i32)` arm-placement boundary for read-only-to-write detection. It does not broaden the implementation: the current Starshine matcher already handles the Binaryen-positive first-arm placement and preserves the both-arm-read boundary.

## Binaryen probes

Two focused probes were written under `.tmp/sgo003c-probes/` and run with `wasm-opt --all-features --simplify-globals-optimizing -S`:

- `nested-if-first-arm.wat`: the candidate `global.get $guard` is in the `then` arm and the `else` arm yields a clean constant. Binaryen removes the fake mutable global traffic and leaves only the independent `call $foo`.
- `nested-if-both-arms.wat`: both arms read `global.get $guard`. Binaryen preserves the mutable global and guard traffic, so Starshine should not count the two syntactic candidate reads as a single safe read-only-to-write event.

The existing earlier local coverage already pinned the symmetric second-arm positive where the `else` arm reads the candidate and the `then` arm yields a clean constant.

## Local tests

Added focused tests in `src/passes/simplify_globals_optimizing_test.mbt`:

- `simplify-globals-optimizing removes nested-if first-arm value flow with independent call condition`
- `simplify-globals-optimizing keeps nested-if both-arm candidate reads`

Both tests passed immediately, confirming current behavior rather than requiring implementation changes.

## Behavior and boundaries

The covered nested-if arm-placement subset is now explicit:

- one candidate read in either arm, with the opposite arm yielding an independent clean value, is eligible when the surrounding condition and final same-global write guard are otherwise supported;
- both arms reading the candidate global remains conservative;
- existing guardrails still preserve candidate-steered nested conditions, post-if call operands, trapping loads/table gets, arm branches/returns, nested `else` forms outside the source-backed carveout, and candidate-derived `local.set` / `local.tee` escapes.

## Validation

- `moon test src/passes`: `1598/1598` passed after adding the guardrails.
- `moon info`, `moon fmt`, `moon test`: completed; full test count was `3674/3674` passed, with only existing DAE unused warnings from `moon info`.
- Direct SGO fuzz at `.tmp/pass-fuzz-sgo-nested-if-arm-placement-10k`: `9975/10000` compared, `9975` normalized matches, `0` mismatches, `0` validation failures, `0` generator failures, and `25` Binaryen/tool command failures.
- Command-failure classes: `22` `binaryen-rec-group-zero`, `1` `binaryen-bad-section-size`, `1` `binaryen-table-index-out-of-range`, and `1` `binaryen-invalid-tag-index`.

## Remaining risks

This completes the current `[SGO]003C` arm-placement/source-alignment slice, but not full Binaryen `SimplifyGlobals.cpp` parity. Broader nested-if value-flow work should be opened as a new focused slice if new source-backed uncovered shapes appear.
