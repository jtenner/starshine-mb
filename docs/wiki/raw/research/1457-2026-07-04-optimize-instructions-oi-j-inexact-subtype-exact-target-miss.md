# OI-J inexact strict-subtype exact-target miss slice

Date: 2026-07-04

## Scope

This finite OI-J exactness/useful-type-info slice covers ordinary `ref.test` / `ref.cast` misses where the operand has a non-null inexact concrete subtype and the target immediate is an exact concrete supertype:

```wat
(module
  (type $base (sub (struct (field i32))))
  (type $sub (sub $base (struct (field i32) (field i64))))
  (func $test (param $x (ref $sub)) (result i32)
    (ref.test (ref (exact $base)) (local.get $x)))
  (func $cast (param $x (ref $sub)) (result (ref (exact $base)))
    (ref.cast (ref (exact $base)) (local.get $x)))
)
```

Even though `$sub` values match the inexact `$base` heap, they cannot have exact runtime type `$base`. Binaryen `version_130` folds the exact test to false and the exact cast to `unreachable`; Starshine now does the same for the strict-subtype proof.

Out of scope: descriptor casts, `ref.test_desc`, same-heap inexact exact-target casts, nullable-source/null-matching exact-target cases, arbitrary useful-type-info beyond concrete strict subtype chains represented in the module context, TNH/IIT behavior, control/effect descriptor localization, and descriptor BrOn variants.

## Binaryen evidence

Probe directory: `.tmp/oi-j-next-probes/`.

Commands:

```text
wasm-opt --all-features .tmp/oi-j-next-probes/exact-target-inexact-subtype-miss.wat --optimize-instructions -S -o .tmp/oi-j-next-probes/exact-target-inexact-subtype-miss.binaryen.wat
wasm-tools validate --features all .tmp/oi-j-next-probes/exact-target-inexact-subtype-miss.wat
```

Binaryen output drops the tested local before `i32.const 0` and rewrites the cast function to `unreachable`. The input validates with `wasm-tools`.

## Implementation

`src/passes/optimize_instructions.mbt` adds `optimize_instructions_ref_operand_misses_exact_target_by_strict_subtype(...)`. The helper requires:

- a module context;
- a single reference result operand;
- concrete source and concrete exact target heaps;
- `source != target`;
- non-null source, or a non-null exact target so null cannot match; and
- the existing module subtype matcher proving the source heap matches the target heap.

The existing `ref.test` false and `ref.cast` unreachable paths now include this exact-target strict-subtype proof. Existing replacement helpers preserve effectful operands as dropped prefixes; pure local operands may be removed entirely, yielding a smaller validating Starshine spelling than Binaryen's dropped-local form.

## Tests

Added red-first focused test:

- `src/passes/optimize_instructions_test.mbt::optimize-instructions folds exact ref.test and ref.cast misses on inexact strict subtype operands`

Red result before implementation:

```text
moon test --package jtenner/starshine/passes --file optimize_instructions_test.mbt --target native --filter 'optimize-instructions folds exact ref.test and ref.cast misses on inexact strict subtype operands'
=> failed with residual `ref.test (ref (exact $base))` on the `(ref $sub)` local
```

Green result after implementation:

```text
moon test --package jtenner/starshine/passes --file optimize_instructions_test.mbt --target native --filter 'optimize-instructions folds exact ref.test and ref.cast misses on inexact strict subtype operands'
=> Total tests: 1, passed: 1, failed: 0.
```

The focused test covers pure and effectful exact `ref.test` misses plus pure and effectful exact `ref.cast` misses.

## Validation

Completed in this slice:

- `moon fmt` passed.
- `moon test --package jtenner/starshine/passes --file optimize_instructions_test.mbt --target native --filter '*exact ref.test*ref.cast*'` passed `2/2`.
- `moon info` passed with pre-existing warnings.
- Full `moon test` passed `7430/7430`.
- `moon build --target native --release src/cmd` passed with pre-existing warnings.
- Probe replay using `wasm-tools parse`, native `cmd.exe --optimize-instructions`, `wasm-tools validate --features all`, and `wasm-tools print` emitted validating Starshine output with no residual `ref.test` / `ref.cast`, containing `i32.const 0` and `unreachable`.
- Regular GenValid compare-pass: `bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass optimize-instructions --out-dir .tmp/oi-j-exact-inexact-subtype-genvalid-10000-20260704 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe` compared `10000/10000`, normalized `10000`, mismatches `0`, validation/generator/property/command failures `0`, Binaryen cache hits/misses `10000/0`.

## Remaining OI-J work

OI-J remains `blocked-surface`. This slice removes one exact-target useful-type-info gap for non-null concrete strict-subtype operands. Remaining work includes descriptor-cast behavior, useful-type-info and exactness breadth beyond the covered exact/inexact subtype proofs, broader TNH/IIT escaping/control descriptor surfaces, arbitrary ordinary cast targets, escaping labels, payload prefixes, effectful/control operands, EH/control descriptor surfaces, multivalue children, and generalized descriptor effect/control localization. The `ref.test_desc` and descriptor BrOn forms remain the unsupported/tooling/representation boundaries documented in note `1456`.
