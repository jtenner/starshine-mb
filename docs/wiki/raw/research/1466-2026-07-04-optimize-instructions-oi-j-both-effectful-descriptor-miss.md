# OI-J both-effectful descriptor-cast mismatch slice

Date: 2026-07-04

## Scope

This finite OI-J descriptor/effect slice covers `ref.cast_desc_eq` operations where both operands are branch-free and effectful, while the reference operand is a non-null strict subtype and the descriptor operand produces an exact descriptor for the target supertype:

```wat
(module
  (rec
    (type $base (sub (descriptor $base_desc) (struct (field i32))))
    (type $base_desc (sub (describes $base) (struct)))
    (type $sub (sub $base (descriptor $sub_desc) (struct (field i32) (field i64))))
    (type $sub_desc (sub $base_desc (describes $sub) (struct)))
  )
  (global $g0 (mut i32) (i32.const 0))
  (global $g1 (mut i32) (i32.const 0))
  (func $cast (param $x (ref $sub)) (result (ref $base))
    (ref.cast_desc_eq (ref $base)
      (block (result (ref $sub))
        (i32.const 1)
        (global.set $g0)
        (local.get $x))
      (block (result (ref (exact $base_desc)))
        (i32.const 2)
        (global.set $g1)
        (struct.new_default $base_desc))))
)
```

The explicit `$base_desc` descriptor can only match exact `$base` instances, so the non-null `$sub` reference cannot pass the descriptor equality check. Both operands still must be evaluated in source order before the cast trap. Starshine now preserves the reference operand as the first dropped prefix and the descriptor operand as the second dropped prefix before `unreachable`.

Out of scope: escaping labels/control, nested control, EH, multivalue operands, nullable descriptor null-only casts, arbitrary exact-result descriptor-cast shapes, TNH/IIT behavior, `ref.test_desc`, descriptor BrOn forms, and generalized descriptor effect/control localization.

## Binaryen evidence

Probe: `.tmp/oi-j-next-probes/desc-both-effectful-base-on-subtype.wat`.

Commands:

```text
wasm-tools validate --features all .tmp/oi-j-next-probes/desc-both-effectful-base-on-subtype.wat
wasm-opt --all-features .tmp/oi-j-next-probes/desc-both-effectful-base-on-subtype.wat --optimize-instructions -S -o .tmp/oi-j-next-probes/desc-both-effectful-base-on-subtype.binaryen.wat
grep -n "global.set\|unreachable\|ref.cast_desc_eq\|drop\|struct.new" .tmp/oi-j-next-probes/desc-both-effectful-base-on-subtype.binaryen.wat
```

Binaryen `version_130` emits two dropped blocks in operand order, then `unreachable`, with both `global.set` operations and the descriptor allocation preserved and no residual `ref.cast_desc_eq`.

## Implementation

`src/passes/optimize_instructions.mbt` adds a two-drop unreachable replacement helper and widens `optimize_instructions_try_fold_ref_cast_desc_eq_exact_descriptor_miss(...)` only after the exact-descriptor miss proof succeeds:

- erasable reference plus erasable descriptor operands still fold directly to `unreachable`;
- effectful reference plus erasable descriptor and erasable reference plus effectful descriptor retain their existing one-drop paths;
- branch-free effectful reference plus branch-free effectful descriptor now rewrites to `drop(reference); drop(descriptor); unreachable`, preserving the reference-before-descriptor evaluation order;
- all other combinations remain fail-closed.

The branch-free predicate is unchanged from the prior descriptor miss slices: it accepts only a `Block` whose roots and children contain no nested block/loop/if/try/try_table/branch/return/throw control.

## Tests

Added red-first focused public-pipeline test:

- `src/passes/optimize_instructions_test.mbt::optimize-instructions folds descriptor casts with both effectful exact descriptor miss operands`

Red result before implementation:

```text
moon test --package jtenner/starshine/passes --file optimize_instructions_test.mbt --target native --filter 'optimize-instructions folds descriptor casts with both effectful exact descriptor miss operands'
=> failed with residual ref.cast_desc_eq in the optimized function body
```

Green result after implementation:

```text
moon test --package jtenner/starshine/passes --file optimize_instructions_test.mbt --target native --filter 'optimize-instructions folds descriptor casts with both effectful exact descriptor miss operands'
=> Total tests: 1, passed: 1, failed: 0.
```

The test asserts both global writes remain, `unreachable` remains, and `ref.cast_desc_eq` is removed.

## Validation

Completed in this slice:

- `wasm-tools validate --features all .tmp/oi-j-next-probes/desc-both-effectful-base-on-subtype.wat` passed.
- Binaryen probe command above passed and emitted two dropped effectful operands before `unreachable` with no residual descriptor cast.
- Red-first focused test above failed before implementation with residual `ref.cast_desc_eq`.
- Green focused test above passed `1/1` after implementation.
- `moon test --package jtenner/starshine/passes --file optimize_instructions_test.mbt --target native --filter '*descriptor*'` passed `45/45`.
- `moon fmt` passed.
- `moon info` passed with pre-existing warnings.
- Full `moon test` passed `7626/7626`.
- `moon build --target native --release src/cmd` passed with pre-existing warnings.
- Native Starshine probe replay using `_build/native/release/build/cmd/cmd.exe --optimize-instructions` on `.tmp/oi-j-next-probes/desc-both-effectful-base-on-subtype.wasm`, followed by `wasm-tools validate --features all` and `wasm-tools print`, emitted a validating Starshine module with both `global.set` operations, `struct.new_default`, two drops, `unreachable`, and no residual `ref.cast_desc_eq`.
- Regular GenValid compare-pass: `bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass optimize-instructions --out-dir .tmp/oi-j-both-effectful-descriptor-miss-genvalid-10000-20260704 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe` compared `10000/10000`, normalized `10000`, mismatches `0`, validation/generator/property/command failures `0`, command failures `0`, Binaryen cache hits/misses `10000/0`.
- `python3 -m json.tool docs/wiki/binaryen/passes/optimize-instructions/parity-matrix.json >/dev/null` passed.
- `git diff --check` passed.

## Remaining OI-J work

OI-J remains `blocked-surface`. This slice removes one both-effectful branch-free exact descriptor miss operand-order variant, but escaping labels/control, nested control, EH, multivalue operands, nullable descriptor null-only casts, arbitrary exact-result descriptor-cast shapes, broader TNH/IIT descriptor breadth, and generalized descriptor effect/control localization remain open. The `ref.test_desc` and descriptor BrOn forms remain unsupported/tooling/representation boundaries as documented in note `1456`.
