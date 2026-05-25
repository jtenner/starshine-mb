---
kind: research-note
status: completed
created: 2026-05-25
sources:
  - ../../../../src/passes/simplify_globals_optimizing.mbt
  - ../../binaryen/passes/simplify-globals-optimizing/parity-matrix.md
  - ../../binaryen/passes/simplify-globals-optimizing/starshine-port-readiness-and-validation.md
  - ../../../../.tmp/pass-fuzz-sgo-if-return-tail-refactor-10k/result.json
---

# SGO exact `if return; set` tail refactor (`[SGO]003O`)

## Scope

This is a refactor-only maintainability slice for `simplify-globals-optimizing`. It centralizes repeated exact-tail dispatch in the direct `if return; set` matcher without changing matcher breadth.

## Change

Added `sgo_if_return_guard_and_tail_match(...)` and reused the existing `sgo_if_return_tail_matches(...)` helper from `sgo_is_exact_if_return_set(...)`.

The refactor preserves the existing condition families while removing repeated block-tail versus inline const-set-tail dispatch:

- direct `global.get; if(return); tail`;
- `global.get; i32.eqz; if(return); tail`;
- `global.get; const; compare; if(return); tail`;
- `const; global.get; compare; if(return); tail`.

## Behavior

No optimizer behavior changed. The refactor preserves:

- the same accepted `return` guard shape;
- the same inline constant `global.set` tail;
- the same void `block` containing a single constant same-global set tail;
- the same direct, `i32.eqz`, and bidirectional compare condition families;
- all existing non-tail, wrong-global, non-constant, extra-instruction, call/control, trapping/effectful, and unsupported wrapper boundaries.

## Validation

- `moon test src/passes`: `1600/1600` passed.
- Direct SGO fuzz at `.tmp/pass-fuzz-sgo-if-return-tail-refactor-10k`: `9975/10000` compared, `9975` normalized matches, `0` mismatches, `0` validation failures, `0` generator failures, and `25` Binaryen/tool command failures.
- Command-failure classes are the established mixed-generator Binaryen/tool failures: `22` `binaryen-rec-group-zero`, `1` `binaryen-bad-section-size`, `1` `binaryen-table-index-out-of-range`, and `1` `binaryen-invalid-tag-index`.
- `moon info`, `moon fmt`, `moon test`: completed; full test count was `3676/3676` passed, with only existing DAE unused warnings from `moon info` / test builds.

## Remaining risks

This does not broaden SGO matcher behavior, close the refactor queue, or claim full Binaryen `SimplifyGlobals.cpp` parity. `[SGO]003` remains active/partial.
