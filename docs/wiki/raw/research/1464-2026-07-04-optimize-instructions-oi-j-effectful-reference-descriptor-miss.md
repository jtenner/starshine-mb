# OI-J effectful-reference descriptor-cast mismatch slice

Date: 2026-07-04

## Scope

This finite OI-J descriptor/effect slice covers `ref.cast_desc_eq` operations where a non-null strict-subtype reference operand is effectful but branch-free, and the descriptor operand is a fresh exact descriptor allocation for the target supertype:

```wat
(module
  (rec
    (type $base (sub (descriptor $base_desc) (struct (field i32))))
    (type $base_desc (sub (describes $base) (struct)))
    (type $sub (sub $base (descriptor $sub_desc) (struct (field i32) (field i64))))
    (type $sub_desc (sub $base_desc (describes $sub) (struct)))
  )
  (global $g (mut i32) (i32.const 0))
  (func $cast (param $x (ref $sub)) (result (ref $base))
    (ref.cast_desc_eq (ref $base)
      (block (result (ref $sub))
        (i32.const 1)
        (global.set $g)
        (local.get $x))
      (struct.new_default $base_desc)))
)
```

The reference operand must be evaluated before the descriptor equality cast traps, so Starshine now preserves it as a dropped prefix before `unreachable`. The slice is intentionally narrow: descriptor operands must remain erasable, reference operands with escaping branch/control stay fail-closed, and effectful descriptor operands, EH/control, multivalue children, TNH/IIT, nullable null-only descriptor casts, `ref.test_desc`, and descriptor BrOn forms remain open.

## Binaryen evidence

Probe: `.tmp/oi-j-next-probes/desc-effectful-ref-base-on-subtype.wat`.

Commands:

```text
wasm-tools validate --features all .tmp/oi-j-next-probes/desc-effectful-ref-base-on-subtype.wat
wasm-opt --all-features .tmp/oi-j-next-probes/desc-effectful-ref-base-on-subtype.wat --optimize-instructions -S -o .tmp/oi-j-next-probes/desc-effectful-ref-base-on-subtype.binaryen.wat
grep -n "global.set\|unreachable\|ref.cast_desc_eq\|drop" .tmp/oi-j-next-probes/desc-effectful-ref-base-on-subtype.binaryen.wat
```

Binaryen `version_130` emits a dropped block containing the `global.set` and local reference, followed by `unreachable`, with no residual `ref.cast_desc_eq`.

## Implementation

`src/passes/optimize_instructions.mbt` widens `optimize_instructions_try_fold_ref_cast_desc_eq_exact_descriptor_miss(...)` after the existing exact-descriptor miss proof:

- pure/trivially pure reference operands still fold directly to `unreachable`;
- branch-free non-pure reference operands now use `optimize_instructions_replace_with_drop_then_unreachable(...)`;
- operands with escaping branch/control still return `false` and preserve the descriptor cast.

The descriptor operand precondition did not widen: it must still exactly describe the target and be erasable. That keeps effectful descriptor operand order and generalized control localization out of this slice.

## Tests

Added red-first focused public-pipeline test:

- `src/passes/optimize_instructions_test.mbt::optimize-instructions folds descriptor casts with effectful reference exact descriptor misses`

Red result before implementation:

```text
moon test --package jtenner/starshine/passes --file optimize_instructions_test.mbt --target native --filter 'optimize-instructions folds descriptor casts with effectful reference exact descriptor misses'
=> failed with residual ref.cast_desc_eq in the optimized function body
```

Green result after implementation:

```text
moon test --package jtenner/starshine/passes --file optimize_instructions_test.mbt --target native --filter 'optimize-instructions folds descriptor casts with effectful reference exact descriptor misses'
=> Total tests: 1, passed: 1, failed: 0.
```

The test asserts that `global.set` is still present, `unreachable` is present, and `ref.cast_desc_eq` is removed.

## Validation

Completed in this slice:

- `wasm-tools validate --features all .tmp/oi-j-next-probes/desc-effectful-ref-base-on-subtype.wat` passed.
- Binaryen probe command above passed and emitted `drop(block ... global.set ... local.get); unreachable` with no residual descriptor cast.
- Red-first focused test above failed before implementation with residual `ref.cast_desc_eq`.
- Green focused test above passed `1/1` after implementation.
- `moon test --package jtenner/starshine/passes --file optimize_instructions_test.mbt --target native --filter '*descriptor*'` passed `43/43`.
- `moon fmt` passed.
- `moon info` passed with pre-existing warnings.
- Full `moon test` passed `7622/7622`.
- `moon build --target native --release src/cmd` passed with pre-existing warnings.
- Native probe replay using `_build/native/release/build/cmd/cmd.exe --optimize-instructions` on `.tmp/oi-j-next-probes/desc-effectful-ref-base-on-subtype.wasm`, followed by `wasm-tools validate --features all` and `wasm-tools print`, emitted a validating Starshine module with `global.set`, `drop`, and `unreachable`, and no residual `ref.cast_desc_eq`.
- Regular GenValid compare-pass: `bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass optimize-instructions --out-dir .tmp/oi-j-effectful-ref-descriptor-miss-genvalid-10000-20260704-rerun --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe` compared `10000/10000`, normalized `10000`, mismatches `0`, validation/generator/property/command failures `0`, command failures `0`, Binaryen cache hits/misses `10000/0`.

## Remaining OI-J work

OI-J remains `blocked-surface`. This slice removes one effectful-reference operand variant of the exact descriptor miss, but effectful descriptor operands, escaping labels/control, EH, multivalue children, nullable descriptor null-only casts, arbitrary exact-result descriptor-cast shapes, broader TNH/IIT descriptor breadth, and generalized descriptor effect/control localization remain open. The `ref.test_desc` and descriptor BrOn forms remain unsupported/tooling/representation boundaries as documented in note `1456`.
