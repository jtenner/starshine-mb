---
kind: research-note
status: completed
created: 2026-05-25
sources:
  - ../../../../src/passes/simplify_globals_optimizing_test.mbt
  - ../../binaryen/passes/simplify-globals-optimizing/parity-matrix.md
  - ../../binaryen/passes/simplify-globals-optimizing/starshine-port-readiness-and-validation.md
  - ../../../../.tmp/sgo003d-probes/memory-grow-independent.wat
  - ../../../../.tmp/sgo003d-probes/table-grow-independent.wat
  - ../../../../.tmp/pass-fuzz-sgo-grow-independence-10k/result.json
---

# SGO independent grow guardrails (`[SGO]003D`)

## Scope

This source-alignment slice pins a narrow side-effect independence boundary for `memory.grow` and `table.grow` in read-only-to-write conditions. It does not broaden the implementation: current Starshine behavior already matches the probed Binaryen positives while preserving existing global-derived grow negatives.

## Binaryen probes

Two focused probes were written under `.tmp/sgo003d-probes/` and run with `wasm-opt --all-features --simplify-globals-optimizing -S`:

- `memory-grow-independent.wat`: a clean `i32.const 0; memory.grow; drop` prefix occurs before the candidate `global.get $guard` and final same-global write guard. Binaryen removes the fake mutable global traffic while preserving the `memory.grow` side effect.
- `table-grow-independent.wat`: a clean `ref.null func; i32.const 0; table.grow; drop` prefix occurs before the candidate read and final same-global write guard. Binaryen removes the fake mutable global traffic while preserving the `table.grow` side effect.

Existing local guardrails already preserve the inverse boundary where the candidate global feeds the `memory.grow` or `table.grow` operand.

## Local tests

Added focused tests in `src/passes/simplify_globals_optimizing_test.mbt`:

- `simplify-globals-optimizing removes guard after independent memory grow`
- `simplify-globals-optimizing removes guard after independent table grow`

Both tests passed immediately, confirming current behavior rather than requiring implementation changes.

## Behavior and boundaries

The pinned subset is deliberately narrow:

- grow operands are clean and independent of the candidate global;
- the grow result is dropped before the single candidate `global.get` reaches the final same-global guard;
- the grow side effect is preserved;
- candidate-derived grow operands remain conservative;
- broader atomics, SIMD memory operations, relaxed SIMD, broad unprobed bulk operations, calls with candidate-derived operands, trapping casts/truncations/loads fed by the candidate, and memory/table growth fed by the candidate remain out of scope.

## Validation

- `moon test src/passes`: `1600/1600` passed after adding the guardrails.
- `moon info`, `moon fmt`, `moon test`: completed; full test count was `3676/3676` passed, with only existing DAE unused warnings from `moon info`.
- Direct SGO fuzz at `.tmp/pass-fuzz-sgo-grow-independence-10k`: `9975/10000` compared, `9975` normalized matches, `0` mismatches, `0` validation failures, `0` generator failures, and `25` Binaryen/tool command failures.
- Command-failure classes: `22` `binaryen-rec-group-zero`, `1` `binaryen-bad-section-size`, `1` `binaryen-table-index-out-of-range`, and `1` `binaryen-invalid-tag-index`.

## Remaining risks

This completes a small `[SGO]003D` grow-independence guardrail slice, not the full side-effect independence backlog. Future `[SGO]003D` work should still admit each additional side-effecting instruction family only with exact Binaryen probes and paired candidate-derived negatives.
