# OI-J exact-result descriptor-cast mismatch validation slice

Date: 2026-07-04

## Scope

This finite OI-J descriptor/exactness slice covers the exact-result spelling of the descriptor-cast mismatch from note `1461`:

```wat
(module
  (rec
    (type $base (sub (descriptor $base_desc) (struct (field i32))))
    (type $base_desc (sub (describes $base) (struct)))
    (type $sub (sub $base (descriptor $sub_desc) (struct (field i32) (field i64))))
    (type $sub_desc (sub $base_desc (describes $sub) (struct)))
  )
  (func $cast (param $x (ref $sub)) (result (ref (exact $base)))
    (ref.cast_desc_eq (ref (exact $base))
      (local.get $x)
      (struct.new_default $base_desc)))
)
```

A non-null `$sub` value cannot pass equality with an exact `$base` descriptor. Binaryen `version_130` folds the cast to `unreachable`. Starshine's HOT lift rejects this exact-result input before the ordinary `optimize-instructions` helper can run, because final validation rejects the surviving exact descriptor cast. This slice adds a narrow raw pre-lift fold so the public pipeline rewrites the known-miss cast before final module validation.

Out of scope: nullable descriptor null-only casts, effectful reference operands, effectful or control descriptor operands, TNH/IIT breadth, `ref.test_desc`, descriptor BrOn forms, generalized descriptor effect/control localization, and broader exact-result descriptor-cast shapes beyond direct non-null local plus fresh exact same-target descriptor allocation.

## Binaryen evidence

Probe: `.tmp/oi-j-next-probes/desc-exact-base-on-subtype.wat`.

Command:

```text
wasm-opt --all-features .tmp/oi-j-next-probes/desc-exact-base-on-subtype.wat --optimize-instructions -S -o .tmp/oi-j-next-probes/desc-exact-base-on-subtype.binaryen-rerun.wat
```

Observed output contains `unreachable` and no residual `ref.cast_desc_eq`.

## Implementation

`src/passes/pass_manager.mbt` now recognizes this exact-result descriptor miss in the `optimize-instructions` lift-error path. The raw rewrite requires:

- `optimize-instructions` only;
- a direct stack sequence `local.get`, `struct.new_default`, `ref.cast_desc_eq`;
- a non-null exact descriptor-cast result;
- the fresh descriptor allocation's type metadata `describes` exactly the cast target;
- the local's declared type is a non-null reference to a strict subtype of the target; and
- no operand effects or control to preserve.

When all preconditions hold, the three-instruction sequence becomes `unreachable`. This is intentionally narrower than the ordinary HOT helper because it exists only to repair the validation-sensitive exact-result spelling before lift/final validation can reject it.

The existing HOT helper from note `1461` remains responsible for already-liftable inexact-result pure/erasable descriptor-miss cases.

## Tests

Added red-first focused test:

- `src/passes/optimize_instructions_test.mbt::optimize-instructions rewrites exact-result descriptor cast misses before final validation`

Red result before implementation:

```text
moon test --package jtenner/starshine/passes --file optimize_instructions_test.mbt --target native --filter 'optimize-instructions rewrites exact-result descriptor cast misses before final validation'
=> failed with `func[(Func 0)]: lift: TypecheckFailure((ref.cast_desc_eq ...), ref.cast_desc_eq target does not match operand type)`
```

Green result after implementation:

```text
moon test --package jtenner/starshine/passes --file optimize_instructions_test.mbt --target native --filter 'optimize-instructions rewrites exact-result descriptor cast misses before final validation'
=> Total tests: 1, passed: 1, failed: 0.
```

## Validation

Completed during the slice:

- Binaryen probe command above passed and emitted `unreachable`.
- Red-first focused test above failed before implementation with the lift/typecheck error.
- Green focused test above passed `1/1` after implementation.
- `python3 -m json.tool docs/wiki/binaryen/passes/optimize-instructions/parity-matrix.json >/dev/null` passed.
- `moon fmt` passed.
- `moon test --package jtenner/starshine/passes --file optimize_instructions_test.mbt --target native --filter '*descriptor*'` passed `41/41` with pre-existing warnings.
- `moon info` passed with pre-existing warnings.
- Full `moon test` passed `7436/7436`.
- `moon build --target native --release src/cmd` passed with pre-existing warnings.
- Native probe replay for `.tmp/oi-j-next-probes/desc-exact-base-on-subtype.wasm` using `target/native/release/build/cmd/cmd.exe --optimize-instructions`, `wasm-tools validate --features all`, and `wasm-tools print` emitted a validating Starshine module with `unreachable` and no residual `ref.cast_desc_eq`.
- Regular GenValid compare-pass: `bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass optimize-instructions --out-dir .tmp/oi-j-exact-result-descriptor-miss-genvalid-10000-20260704 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe` compared `10000/10000`, normalized `10000`, mismatches `0`, validation/generator/property/command failures `0`, Binaryen cache hits/misses `10000/0`.

## Remaining OI-J work

OI-J remains `blocked-surface`. This slice removes the exact-result validation boundary for the direct pure descriptor-miss case, but nullable descriptor null-only casts, effectful reference or descriptor operands, broader TNH/IIT behavior, arbitrary exact-result descriptor-cast shapes, escaping labels, payload prefixes, EH/control descriptor surfaces, multivalue children, and generalized descriptor effect/control localization remain open. The `ref.test_desc` and descriptor BrOn forms remain the unsupported/tooling/representation boundaries documented in note `1456`.
