---
title: Code-pushing br_on_cast loop boundary
status: boundary
date: 2026-06-25
tags:
  - binaryen
  - code-pushing
  - o4z-audit
  - br_on_cast
sources:
  - ../../../../src/passes/code_pushing_test.mbt
  - ../../../binaryen/2026-06-20-code-pushing-version-130-source-lit-refresh.md
---

# Code-pushing `br_on_cast` loop boundary

## Slice

`[O4Z-AUDIT-CP-AA]` narrows one open `br_on_*` loop-label question for `code-pushing` without widening mutation. The probed shape is a one-result loop-label `br_on_cast` reduced against local Binaryen `wasm-opt version 130 (version_130)`.

## Binaryen v130 probe

Probe file:

```sh
.tmp/o4z-audit-cp-aa/br-on-cast-loop.wat
```

Command:

```sh
wasm-opt --all-features .tmp/o4z-audit-cp-aa/br-on-cast-loop.wat --code-pushing -S -o .tmp/o4z-audit-cp-aa/br-on-cast-loop.opt.wat
```

Reduced input:

```wat
(module
  (func $f)
  (func (result i32)
    (local $x i32)
    (ref.func $f)
    (loop $loop (param (ref func))
      (drop)
      (local.set $x (i32.const 7))
      (drop
        (br_on_cast $loop funcref (ref func)
          (ref.null nofunc)))
      (i32.const 0)
      (return)
    )
    (local.get $x)
  )
)
```

Binaryen accepted the input and emitted valid optimized text. As with the earlier `br_on_non_null` loop-label probe, Binaryen rewrote the loop-carried reference through a scratch local and loop/block wrapper, but kept the pure `local.set $x` before the `br_on_cast` inside the rewritten loop body. The relevant optimized order remains:

1. consume the loop-carried scratch reference;
2. `local.set $x (i32.const 7)`;
3. dropped `br_on_cast` to the loop label;
4. later return/fallback control.

## Starshine boundary coverage

`src/passes/code_pushing_test.mbt` now has the focused HOT test:

```text
code-pushing keeps loop-label br_on_cast window stationary
```

The test builds a loop-label `BrOnCast` HOT fixture directly because the repo-local WAT parser surface is unreliable for these GC branch forms. It asserts that the pure `local.set` remains before the dropped `br_on_cast`, with the suffix `drop(local.get)` still after the branch.

Validation:

```sh
moon test --target native src/passes/code_pushing_test.mbt --filter '*loop-label br_on_cast*'
# Total tests: 1, passed: 1, failed: 0.
```

## Accepted boundary

This is a narrow source-backed stationary boundary for the reduced one-result loop-label `br_on_cast` shape only. It does not close:

- loop-label `br_on_cast_fail`;
- broader loop-label `br_on_non_null` variants beyond the previous single probe;
- prefix-payload/reference-carrying `br_on_*` variants;
- `br_on_*` forms whose Binaryen behavior differs after a more reliable WAT/HOT reduction;
- value-`br_if` lowering normalization or switch/`br_table` mutation.

Reopen this boundary if a current Binaryen probe moves the same one-result loop-label `br_on_cast` window, or if Starshine gains a broader source-backed loop-label `br_on_*` lowering that can safely match Binaryen's scratch/control rewrite.
