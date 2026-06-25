---
kind: research
status: supported
last_reviewed: 2026-06-25
sources:
  - ../../binaryen/2026-06-20-code-pushing-version-130-source-lit-refresh.md
  - ../../binaryen/passes/code-pushing/starshine-port-readiness-and-validation.md
  - ../../../../src/passes/code_pushing.mbt
  - ../../../../src/passes/code_pushing_test.mbt
---

# Code-pushing `br_on_non_null` prefix-payload probe

## Question

Does Binaryen v130 move pure local sets after a block-label `br_on_non_null` when the branch carries an explicit prefix payload in addition to the implicit non-null reference payload?

## Short answer

Yes, for the reduced two-result block-label probe below. This is source-backed evidence for a remaining Starshine behavior gap, not an accepted boundary: Starshine's current bounded `BrOnNonNull` movement gate covers only the one-result block-label shape with a single guard child. The prefix-payload shape should be implemented test-first in a future slice before claiming broader `br_on_non_null` coverage.

## Binaryen v130 probe

Local oracle:

```sh
wasm-opt --version
# wasm-opt version 130 (version_130)
```

Probe file: `.tmp/o4z-audit-cp-ee/br-on-non-null-prefix.wat`.

Input:

```wat
(module
  (func (param $r externref) (local $tmp i32)
    (block $exit (result i32 externref)
      (local.set $tmp (i32.const 7))
      (i32.const 42)
      (local.get $r)
      (br_on_non_null $exit)
      drop
      (drop (local.get $tmp))
      (i32.const 13)
      (ref.null extern))
    drop
    drop))
```

Commands:

```sh
wasm-tools parse .tmp/o4z-audit-cp-ee/br-on-non-null-prefix.wat -o /tmp/br-on-non-null-prefix.wasm
wasm-tools validate --features all /tmp/br-on-non-null-prefix.wasm
wasm-opt --all-features .tmp/o4z-audit-cp-ee/br-on-non-null-prefix.wat --code-pushing -S -o .tmp/o4z-audit-cp-ee/br-on-non-null-prefix.opt.wat
```

Result: the input validates under `wasm-tools`, and Binaryen emits a validating optimized WAT. The optimized shape rewrites the multi-value branch through scratch locals/control wrappers, but it moves `local.set $tmp (i32.const 7)` after the `br_on_non_null`, before the fallthrough prefix-payload `drop` and before the later use/drop of `$tmp`.

Representative optimized excerpt:

```wat
(block $exit0 (result externref)
  (local.set $scratch_3
    (block (result i32)
      (local.set $scratch_4 (i32.const 42))
      (local.set $scratch (local.get $r))
      (local.get $scratch_4)))
  (br_on_non_null $exit0
    (local.get $scratch))
  (local.set $tmp
    (i32.const 7))
  (drop
    (local.get $scratch_3))
  (drop
    (local.get $tmp))
  ...)
```

## Starshine implication

Current Starshine movement support remains narrower than this Binaryen behavior. `code_pushing_single_set_conditional_branch_push_point_supported(...)` currently admits `BrOnNonNull` for a block label only when `branch_arity == 1` and `child_count == 1`. The probed prefix-payload shape has a two-result block label and should require at least:

- HOT-level red tests that build a `BrOnNonNull` with an explicit prefix payload plus the reference operand;
- guard/prefix local-read negatives proving moved locals are not read by either the prefix payload or guard;
- implementation that preserves source order for single-set and, if separately probed, adjacent multi-set windows;
- focused validation and then a dedicated profile decision only after the shape is aggregate-safe.

## Follow-up

Treat this as an open positive behavior gap. Do not generalize from it to loop-label `br_on_non_null` (already covered as a stationary boundary), `br_on_cast`, `br_on_cast_fail`, or arbitrary multi-value/reference-carrying branches without independent probes.
