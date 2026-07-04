# OI-J exact descriptor-cast mismatch slice

Date: 2026-07-04

## Scope

This finite OI-J descriptor/exactness slice covers `ref.cast_desc_eq` operations where a non-null strict-subtype reference operand is paired with an exact descriptor for the target supertype:

```wat
(module
  (rec
    (type $base (sub (descriptor $base_desc) (struct (field i32))))
    (type $base_desc (sub (describes $base) (struct)))
    (type $sub (sub $base (descriptor $sub_desc) (struct (field i32) (field i64))))
    (type $sub_desc (sub $base_desc (describes $sub) (struct)))
  )
  (func $cast (param $x (ref $sub)) (result (ref $base))
    (ref.cast_desc_eq (ref $base)
      (local.get $x)
      (struct.new_default $base_desc)))
)
```

The explicit `$base_desc` descriptor can only match exact `$base` instances. A non-null `$sub` value therefore cannot pass the descriptor equality cast, even though `$sub` is an ordinary subtype of `$base`. Binaryen `version_130` folds the cast to `unreachable`; Starshine now does the same for the pure/erasable operand subset.

Out of scope: exact-result descriptor-cast inputs that Starshine's final validator still rejects before this fold can repair them, nullable source/nullable target null-only descriptor casts, effectful reference or descriptor operands that must be preserved before `unreachable`, TNH/IIT mode behavior, `ref.test_desc`, descriptor BrOn variants, EH/control operands, multivalue children, and generalized descriptor effect/control localization.

## Binaryen evidence

Probe directory: `.tmp/oi-j-next-probes/`.

Commands:

```text
wasm-tools validate --features all .tmp/oi-j-next-probes/desc-inexact-base-on-subtype.wat
wasm-opt --all-features .tmp/oi-j-next-probes/desc-inexact-base-on-subtype.wat --optimize-instructions -S -o .tmp/oi-j-next-probes/desc-inexact-base-on-subtype.binaryen.wat
```

Binaryen output rewrites the function body to `unreachable`.

A companion exact-result probe, `.tmp/oi-j-next-probes/desc-exact-base-on-subtype.wat`, also folds to `unreachable` in Binaryen, but Starshine still fails that exact descriptor-cast input during final validation if the optimizer does not rewrite it first. This slice deliberately implements the validating inexact-result subset and records the exact-result path as a remaining representation/validation boundary.

## Implementation

`src/passes/optimize_instructions.mbt` adds `optimize_instructions_try_fold_ref_cast_desc_eq_exact_descriptor_miss(...)` before descriptor-cast result narrowing. The helper requires:

- default mode, not `--traps-never-happen`;
- a two-operand `RefCastDescEq`;
- an exact descriptor operand that describes the cast target;
- a reference operand proven to miss the descriptor-exact target, either by exact different heap or strict-subtype proof;
- an erasable descriptor operand; and
- a pure/trivially-pure reference operand.

When all preconditions hold, the cast is replaced with `unreachable`. Broader effectful cases are left fail-closed so operand order/effects are not dropped.

## Tests

Added red-first focused test:

- `src/passes/optimize_instructions_test.mbt::optimize-instructions folds descriptor casts with exact mismatching descriptors`

Red result before implementation:

```text
moon test --package jtenner/starshine/passes --file optimize_instructions_test.mbt --target native --filter 'optimize-instructions folds descriptor casts with exact mismatching descriptors'
=> failed with residual descriptor cast instead of `unreachable`
```

Green result after implementation:

```text
moon test --package jtenner/starshine/passes --file optimize_instructions_test.mbt --target native --filter 'optimize-instructions folds descriptor casts with exact mismatching descriptors'
=> Total tests: 1, passed: 1, failed: 0.
```

## Validation

Completed in this slice:

- Binaryen probe commands above passed; Binaryen output contains `unreachable`.
- Red-first focused command above failed before implementation.
- Green focused command above passed `1/1` after implementation.
- `moon test --package jtenner/starshine/passes --file optimize_instructions_test.mbt --target native --filter '*descriptor*'` passed `40/40`.
- `moon build --target native --release src/cmd` passed with pre-existing warnings.
- Starshine probe replay for `.tmp/oi-j-next-probes/desc-inexact-base-on-subtype.wat` using `wasm-tools parse`, native `cmd.exe --optimize-instructions`, `wasm-tools validate --features all`, and `wasm-tools print` emitted a validating module with `unreachable` in the cast function.
- Regular GenValid compare-pass: `bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass optimize-instructions --out-dir .tmp/oi-j-exact-descriptor-miss-genvalid-10000-20260704-rerun --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe` compared `10000/10000`, normalized `10000`, mismatches `0`, validation/generator/property/command failures `0`, Binaryen cache hits/misses `10000/0`.

## Remaining OI-J work

OI-J remains `blocked-surface`. This slice removes one pure descriptor-cast exact-mismatch gap but keeps the exact-result descriptor-cast validation boundary, nullable descriptor null-only casts, effectful/control descriptor operands, broader TNH/IIT behavior, arbitrary ordinary cast targets, escaping labels, payload prefixes, EH/control descriptor surfaces, multivalue children, and generalized descriptor effect/control localization open. The `ref.test_desc` and descriptor BrOn forms remain the unsupported/tooling/representation boundaries documented in note `1456`.
