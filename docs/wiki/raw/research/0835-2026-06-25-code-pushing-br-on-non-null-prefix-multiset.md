---
kind: research
status: supported
last_reviewed: 2026-06-25
sources:
  - ../../binaryen/2026-06-20-code-pushing-version-130-source-lit-refresh.md
  - ../../../binaryen/passes/code-pushing/starshine-port-readiness-and-validation.md
  - ../../../../src/passes/code_pushing.mbt
  - ../../../../src/passes/code_pushing_wbtest.mbt
---

# Code-pushing `br_on_non_null` prefix-payload adjacent multi-set probe

## Question

Does Binaryen v130 move adjacent pure local sets after a two-result block-label `br_on_non_null` when the branch carries an explicit prefix payload plus the implicit non-null reference payload?

## Short answer

Yes for the reduced block-label probe below. Binaryen preserves the source order of the two moved sets. Starshine already had the ordered movement path after the preceding single-set prefix-payload implementation because `code_pushing_try_sink_ordered_sets_after_push_point(...)` uses the same narrowed `BrOnNonNull` block-label gate. This slice adds focused coverage and documents that this exact adjacent multi-set prefix-payload shape is no longer an open behavior gap.

This does **not** widen acceptance for loop-label `br_on_non_null`, `br_on_cast`, `br_on_cast_fail`, reference-carrying variants beyond this reduced shape, or separated/non-adjacent prefix-payload windows.

## Binaryen v130 probe

Local oracle:

```sh
wasm-opt --version
# wasm-opt version 130 (version_130)
```

Probe file: `.tmp/o4z-audit-cp-ii/br-on-non-null-prefix-multiset.wat`.

Input:

```wat
(module
  (func (param $r externref) (local $a i32) (local $b i32)
    (block $exit (result i32 externref)
      (local.set $a (i32.const 7))
      (local.set $b (i32.const 9))
      (i32.const 42)
      (local.get $r)
      (br_on_non_null $exit)
      drop
      (drop (local.get $a))
      (drop (local.get $b))
      (i32.const 13)
      (ref.null extern))
    drop
    drop))
```

Commands:

```sh
wasm-tools parse .tmp/o4z-audit-cp-ii/br-on-non-null-prefix-multiset.wat -o .tmp/o4z-audit-cp-ii/br-on-non-null-prefix-multiset.wasm
wasm-tools validate --features all .tmp/o4z-audit-cp-ii/br-on-non-null-prefix-multiset.wasm
wasm-opt --all-features .tmp/o4z-audit-cp-ii/br-on-non-null-prefix-multiset.wat --code-pushing -S -o .tmp/o4z-audit-cp-ii/br-on-non-null-prefix-multiset.opt.wat
```

Result: the input validates, and Binaryen emits validating optimized WAT. The optimized shape rewrites the multi-value branch through scratch locals/control wrappers, then places `(local.set $a (i32.const 7))` and `(local.set $b (i32.const 9))` after the `br_on_non_null`, before the prefix-payload fallthrough `drop` and later suffix reads.

## Starshine implication

Focused HOT coverage now checks this exact adjacent two-set shape in `src/passes/code_pushing_wbtest.mbt`. The test passed without additional implementation after the preceding single-set prefix-payload gate change, confirming the ordered multi-set helper inherits the narrowed block-label `BrOnNonNull` support.

Keep the generator aggregate unchanged until a dedicated, aggregate-safe prefix-payload leaf is added and direct-compared. The current coverage is focused HOT plus Binaryen probe evidence only.
