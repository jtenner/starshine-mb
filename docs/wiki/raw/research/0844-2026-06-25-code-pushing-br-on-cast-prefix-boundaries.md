---
title: Code-pushing br_on_cast prefix-payload boundaries
status: supported
date: 2026-06-25
tags:
  - code-pushing
  - binaryen
  - o4z-audit
  - boundary
sources:
  - ../../../../src/passes/code_pushing_test.mbt
  - ../../../binaryen/2026-06-20-code-pushing-version-130-source-lit-refresh.md
---

# Code-pushing `br_on_cast` / `br_on_cast_fail` prefix-payload boundaries

## Slice

`[O4Z-AUDIT-CP-SS]` probes another remaining `br_on_*` prefix-payload surface after the positive `br_on_non_null` prefix-payload work. The question was whether local Binaryen v130 moves a pure SFA `local.set` after two-result block-label `br_on_cast` or `br_on_cast_fail` branches when the taken edge carries an explicit `i32` prefix payload plus the reference payload.

## Binaryen v130 probes

Local oracle:

```sh
wasm-opt --version
# wasm-opt version 130 (version_130)
```

`br_on_cast` probe file: `.tmp/o4z-audit-cp-ss/br-on-cast-prefix.wat`.

```wat
(module
  (type $sig (func))
  (func $target (type $sig))
  (elem declare func $target)
  (func (local $tmp funcref)
    (block $out (result i32 (ref func))
      (local.set $tmp (ref.func $target))
      (i32.const 42)
      (br_on_cast $out funcref (ref func)
        (ref.null nofunc))
      drop
      drop
      (drop (local.get $tmp))
      (i32.const 13)
      (ref.func $target))
    drop
    drop))
```

Commands:

```sh
wasm-tools parse .tmp/o4z-audit-cp-ss/br-on-cast-prefix.wat -o .tmp/o4z-audit-cp-ss/br-on-cast-prefix.wasm
wasm-tools validate --features all .tmp/o4z-audit-cp-ss/br-on-cast-prefix.wasm
wasm-opt --all-features .tmp/o4z-audit-cp-ss/br-on-cast-prefix.wat --code-pushing -S -o .tmp/o4z-audit-cp-ss/br-on-cast-prefix.opt.wat
```

Result: the input validates, and Binaryen keeps `local.set $tmp` before the `br_on_cast` after rewriting the multivalue branch through scratch/control wrappers.

`br_on_cast_fail` probe file: `.tmp/o4z-audit-cp-tt/br-on-cast-fail-prefix.wat`.

```wat
(module
  (type $sig (func))
  (func $target (type $sig))
  (elem declare func $target)
  (func (local $tmp funcref)
    (block $out (result i32 funcref)
      (local.set $tmp (ref.func $target))
      (i32.const 42)
      (br_on_cast_fail $out funcref (ref func)
        (ref.func $target))
      drop
      drop
      (drop (local.get $tmp))
      (i32.const 13)
      (ref.null nofunc))
    drop
    drop))
```

Commands:

```sh
wasm-tools parse .tmp/o4z-audit-cp-tt/br-on-cast-fail-prefix.wat -o .tmp/o4z-audit-cp-tt/br-on-cast-fail-prefix.wasm
wasm-tools validate --features all .tmp/o4z-audit-cp-tt/br-on-cast-fail-prefix.wasm
wasm-opt --all-features .tmp/o4z-audit-cp-tt/br-on-cast-fail-prefix.wat --code-pushing -S -o .tmp/o4z-audit-cp-tt/br-on-cast-fail-prefix.opt.wat
```

Result: the input validates, and Binaryen keeps `local.set $tmp` before the `br_on_cast_fail` after the same style of scratch/control rewrite.

## Starshine boundary coverage

`src/passes/code_pushing_test.mbt` now has explicit intentionally unsupported/Binaryen-stationary HOT boundary tests for both prefix-payload forms:

- `code-pushing boundary keeps SFA set before br_on_cast prefix payload`
- `code-pushing boundary keeps SFA set before br_on_cast_fail prefix payload`

The focused tests use HOT fixtures because the repo WAT test parser cannot parse these `br_on_cast` forms, while local `wasm-tools` and Binaryen can. The HOT fixtures build two-result block-label branches with an explicit `i32` prefix child and a reference operand child, then assert that the pure SFA `local.set` remains before the branch after `code-pushing`.

Validation:

```sh
moon test --target native src/passes/code_pushing_test.mbt --filter '*prefix payload*'
# Total tests: 2, passed: 2, failed: 0.
```

## Classification

These are narrow accepted stationary boundaries, not positive movement slices. They do not add `code-pushing` mutation support, do not add GenValid leaves, and do not imply a general `br_on_*` prefix-payload non-goal. Reopen if Binaryen starts moving these exact v130-style reduced shapes, if Starshine accidentally moves them without a proof and tests, or if a broader source-backed `br_on_cast` / `br_on_cast_fail` prefix-payload family is shown to be Binaryen-positive.

`[O4Z-AUDIT-CP]` remains active for broader reference-carrying forms, other prefix-payload variants, remaining switch/`br_table` surfaces, precise ordered/effect barriers, and the final closeout matrix.
