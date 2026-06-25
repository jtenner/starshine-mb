---
kind: research
status: supported
created: 2026-06-25
sources:
  - ../../binaryen/2026-06-20-code-pushing-version-130-source-lit-refresh.md
  - ../../../binaryen/passes/code-pushing/index.md
  - ../../../binaryen/passes/code-pushing/segment-selection-and-barriers.md
  - ../../../../../src/passes/code_pushing.mbt
  - ../../../../../src/passes/code_pushing_test.mbt
---

# Code-pushing global.set segment movement

## Question

Can a pure SFA `local.set` move across an intervening `global.set` before a later `br_if` push point?

This narrows the ordered-effect surface for `[O4Z-AUDIT-CP]` after the call/EH barrier slices: `global.set` mutates global state, but the moved value is a pure constant with no global read dependency.

## Binaryen v130 probe

Probe path: `.tmp/cp-probes/global-set-before-brif.wat`.

Input shape:

```wat
(module
  (global $g (mut i32) (i32.const 0))
  (func (param i32) (local i32)
    (block $exit
      i32.const 7
      local.set 1
      i32.const 1
      global.set $g
      local.get 0
      br_if $exit
      local.get 1
      drop)))
```

Commands:

- `wasm-tools parse .tmp/cp-probes/global-set-before-brif.wat -o .tmp/cp-probes/global-set-before-brif.wasm` — passed.
- `wasm-tools validate --features all .tmp/cp-probes/global-set-before-brif.wasm` — passed.
- `wasm-opt --version` — `wasm-opt version 130 (version_130)`.
- `wasm-opt --all-features .tmp/cp-probes/global-set-before-brif.wat --code-pushing -S -o -` — passed.

Binaryen moved the pure SFA set after the `global.set` and after the later `br_if`, preserving the global mutation before the branch and placing the delayed constant computation next to the suffix use.

## Starshine coverage

Added focused test: `code-pushing moves pure SFA set past global.set before br_if push point` in `src/passes/code_pushing_test.mbt`.

The test confirms the existing Starshine segment path already matches the Binaryen-positive shape: the original `local.set` becomes `nop`, the `global.set` remains before the `br_if`, and the cloned `local.set` is inserted after the `br_if` before the suffix `drop` use.

No pass implementation or GenValid profile changed in this slice.

## Validation

- `moon test --target native src/passes/code_pushing_test.mbt --filter '*global.set before br_if*'` — passed `1/1`.

## Audit impact

This closes one narrow global-state ordered-window question for pure values before a later `br_if`. It does **not** prove that `global.get` values may cross `global.set`; Starshine's current guarded `global.get` movement remains effect-sensitive. Broader global/table/memory state windows and richer ordered-effect combinations remain open for `[O4Z-AUDIT-CP]`.
