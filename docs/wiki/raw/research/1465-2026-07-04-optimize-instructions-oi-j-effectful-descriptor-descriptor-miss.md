# OI-J effectful-descriptor descriptor-cast mismatch slice

Date: 2026-07-04

## Scope

This finite OI-J descriptor/effect slice covers `ref.cast_desc_eq` operations where a non-null strict-subtype reference operand is pure, but the descriptor operand is a branch-free effectful block that produces an exact descriptor for the target supertype:

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
      (local.get $x)
      (block (result (ref (exact $base_desc)))
        (i32.const 1)
        (global.set $g)
        (struct.new_default $base_desc))))
)
```

The explicit `$base_desc` descriptor can only match exact `$base` instances, so the non-null `$sub` reference cannot pass the descriptor equality check. The descriptor operand still must be evaluated after the pure reference operand and before the cast trap. Starshine now preserves this branch-free descriptor operand as a dropped prefix before `unreachable`.

Out of scope: both operands effectful (requires preserving reference-before-descriptor order, likely scratch localization), descriptor operands with escaping branch/control/EH/multivalue children, nullable descriptor null-only casts, arbitrary exact-result descriptor-cast shapes, TNH/IIT behavior, `ref.test_desc`, descriptor BrOn forms, and generalized descriptor effect/control localization.

## Binaryen evidence

Probe: `.tmp/oi-j-next-probes/desc-effectful-desc-base-on-subtype.wat`.

Commands:

```text
wasm-tools validate --features all .tmp/oi-j-next-probes/desc-effectful-desc-base-on-subtype.wat
wasm-opt --all-features .tmp/oi-j-next-probes/desc-effectful-desc-base-on-subtype.wat --optimize-instructions -S -o .tmp/oi-j-next-probes/desc-effectful-desc-base-on-subtype.binaryen.wat
grep -n "global.set\|unreachable\|ref.cast_desc_eq\|drop\|struct.new" .tmp/oi-j-next-probes/desc-effectful-desc-base-on-subtype.binaryen.wat
```

Binaryen `version_130` emits a dropped block containing `global.set` and `struct.new_default`, followed by `unreachable`, with no residual `ref.cast_desc_eq`.

Before implementation, native Starshine replay with `_build/native/release/build/cmd/cmd.exe --optimize-instructions` preserved the effectful descriptor block but left a residual exactified `ref.cast_desc_eq`.

## Implementation

`src/passes/optimize_instructions.mbt` widens `optimize_instructions_try_fold_ref_cast_desc_eq_exact_descriptor_miss(...)` after the existing exact-descriptor miss proof:

- when both reference and descriptor operands are erasable, the cast still folds directly to `unreachable`;
- when the descriptor is erasable and the reference operand is a branch-free effectful block, the existing drop-reference-before-`unreachable` path still applies;
- when the reference operand is erasable and the descriptor operand is a branch-free effectful block, the descriptor operand is dropped before `unreachable`;
- all other combinations remain fail-closed.

The branch-free proof was renamed to a generic operand helper but remains intentionally narrow: it accepts only a `Block` whose roots and children contain no nested block/loop/if/try/try_table/branch/return/throw control.

## Tests

Added red-first focused public-pipeline test:

- `src/passes/optimize_instructions_test.mbt::optimize-instructions folds descriptor casts with effectful descriptor exact descriptor misses`

Red result before implementation:

```text
moon test --package jtenner/starshine/passes --file optimize_instructions_test.mbt --target native --filter 'optimize-instructions folds descriptor casts with effectful descriptor exact descriptor misses'
=> failed with residual ref.cast_desc_eq in the optimized function body
```

Green result after implementation:

```text
moon test --package jtenner/starshine/passes --file optimize_instructions_test.mbt --target native --filter 'optimize-instructions folds descriptor casts with effectful descriptor exact descriptor misses'
=> Total tests: 1, passed: 1, failed: 0.
```

The test asserts that `global.set` is still present, `unreachable` is present, and `ref.cast_desc_eq` is removed.

## Validation

Completed in this slice:

- `wasm-tools validate --features all .tmp/oi-j-next-probes/desc-effectful-desc-base-on-subtype.wat` passed.
- Binaryen probe command above passed and emitted `drop(block ... global.set ... struct.new_default); unreachable` with no residual descriptor cast.
- Red-first focused test above failed before implementation with residual `ref.cast_desc_eq`.
- Green focused test above passed `1/1` after implementation.
- `moon test --package jtenner/starshine/passes --file optimize_instructions_test.mbt --target native --filter '*descriptor*'` passed `44/44`.
- `moon fmt` passed.
- `moon info` passed with pre-existing warnings.
- Full `moon test` passed `7623/7623`.
- `moon build --target native --release src/cmd` passed with pre-existing warnings.
- Native probe replay using `_build/native/release/build/cmd/cmd.exe --optimize-instructions` on `.tmp/oi-j-next-probes/desc-effectful-desc-base-on-subtype.wasm`, followed by `wasm-tools validate --features all` and `wasm-tools print`, emitted a validating Starshine module with `global.set`, `struct.new_default`, `drop`, and `unreachable`, and no residual `ref.cast_desc_eq`.
- Regular GenValid compare-pass: `bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass optimize-instructions --out-dir .tmp/oi-j-effectful-desc-descriptor-miss-genvalid-10000-20260704 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe` compared `10000/10000`, normalized `10000`, mismatches `0`, validation/generator/property/command failures `0`, command failures `0`, Binaryen cache hits/misses `10000/0`.

## Remaining OI-J work

OI-J remains `blocked-surface`. This slice removes one pure-reference/effectful-descriptor operand variant of the exact descriptor miss, but both-effectful operand-order localization, escaping labels/control, EH, multivalue children, nullable descriptor null-only casts, arbitrary exact-result descriptor-cast shapes, broader TNH/IIT descriptor breadth, and generalized descriptor effect/control localization remain open. The `ref.test_desc` and descriptor BrOn forms remain unsupported/tooling/representation boundaries as documented in note `1456`.
