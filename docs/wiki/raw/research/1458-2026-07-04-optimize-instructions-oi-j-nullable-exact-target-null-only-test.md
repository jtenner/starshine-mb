# OI-J nullable exact-target ref.test null-only subtype slice

Date: 2026-07-04

## Scope

This finite OI-J exactness/useful-type-info slice covers nullable exact-target `ref.test` predicates where the nullable operand can match the target only when it is null:

```wat
(module
  (type $base (sub (struct (field i32))))
  (type $sub (sub $base (struct (field i32) (field i64))))
  (func $test (param $x (ref null $sub)) (result i32)
    (ref.test (ref null (exact $base)) (local.get $x)))
)
```

For non-null `$sub` values, exact runtime type `$base` is impossible; for null, the nullable exact target matches. Binaryen `version_130` rewrites the predicate to `ref.is_null`. Starshine now does the same for exact nullable different-heap concrete operands and inexact nullable strict-subtype operands proven by the module subtype table.

Out of scope: nullable exact-target `ref.cast` narrowing to `ref.cast nullref`, descriptor casts, `ref.test_desc`, same-heap inexact exact-target casts, arbitrary nullable useful-type-info beyond exact different concrete heaps and strict-subtype chains, TNH/IIT behavior, control/effect descriptor localization, and descriptor BrOn variants.

## Binaryen evidence

Probe directory: `.tmp/oi-j-next-probes/`.

Commands:

```text
wasm-tools validate --features all .tmp/oi-j-next-probes/nullable-exact-subtype-nullable-exact-target-test.wat
wasm-opt --all-features .tmp/oi-j-next-probes/nullable-exact-subtype-nullable-exact-target-test.wat --optimize-instructions -S -o .tmp/oi-j-next-probes/nullable-exact-subtype-nullable-exact-target-test.binaryen.wat
wasm-tools validate --features all .tmp/oi-j-next-probes/nullable-subtype-nullable-exact-target.wat
wasm-opt --all-features .tmp/oi-j-next-probes/nullable-subtype-nullable-exact-target.wat --optimize-instructions -S -o .tmp/oi-j-next-probes/nullable-subtype-nullable-exact-target.binaryen.wat
```

Binaryen rewrites exact nullable `$sub` and inexact nullable `$sub` tests against `(ref null (exact $base))` to `ref.is_null`, and preserves effectful operands as the child of that null predicate. The broader probe also shows Binaryen rewrites the paired nullable exact-target `ref.cast` to `ref.cast nullref`; Starshine deliberately leaves that cast behavior for a separate slice because it changes the cast target/result proof rather than just the i32 predicate.

## Implementation

`src/passes/optimize_instructions.mbt` adds `optimize_instructions_ref_operand_matches_nullable_exact_target_only_as_null(...)`. The helper requires:

- an exact nullable target immediate;
- a nullable reference operand;
- concrete source and target heaps;
- distinct source and target heaps; and
- either an exact source heap, or a module-context strict-subtype proof that the inexact source heap matches the target heap.

`optimize_instructions_try_fold_ref_test_null` now routes that proof to `optimize_instructions_replace_with_ref_is_null(...)`, preserving pure and effectful operands as the child of `ref.is_null` instead of folding to a constant.

## Tests

Added red-first focused test:

- `src/passes/optimize_instructions_test.mbt::optimize-instructions folds nullable exact ref.test subtype misses to ref.is_null`

Red result before implementation:

```text
moon test --package jtenner/starshine/passes --file optimize_instructions_test.mbt --target native --filter 'optimize-instructions folds nullable exact ref.test subtype misses to ref.is_null'
=> failed with residual `ref.test (ref null (exact $base))` on a nullable exact `$sub` local
```

Green result after implementation:

```text
moon test --package jtenner/starshine/passes --file optimize_instructions_test.mbt --target native --filter 'optimize-instructions folds nullable exact ref.test subtype misses to ref.is_null'
=> Total tests: 1, passed: 1, failed: 0.
```

The focused test covers nullable exact `$sub`, nullable inexact strict-subtype `$sub`, and an effectful nullable inexact strict-subtype producer. It also records the current pretty-printer quirk where lowered `RefIsNull` is printed as `ref.null`.

## Validation

Completed in this slice:

- Red-first focused command above failed before implementation with residual `ref.test`.
- Green focused command above passed `1/1` after implementation.

Final signoff after docs updates also passed:

- `python3 -m json.tool docs/wiki/binaryen/passes/optimize-instructions/parity-matrix.json >/dev/null`
- `moon fmt`
- `moon test --package jtenner/starshine/passes --file optimize_instructions_test.mbt --target native --filter '*nullable exact ref.test*'` (`1/1`)
- `moon info` (pre-existing warnings only)
- full `moon test` (`7431/7431`)
- `moon build --target native --release src/cmd` (pre-existing warnings only)
- Probe replay using `wasm-tools parse`, native `cmd.exe --optimize-instructions`, `wasm-tools validate --features all`, and `wasm-tools print` emitted validating Starshine output with `ref.is_null` in all three `ref.test` functions and preserved residual `ref.cast (ref null (exact $base))` in the two cast functions.
- Regular GenValid compare-pass: `bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass optimize-instructions --out-dir .tmp/oi-j-nullable-exact-target-null-only-genvalid-10000-20260704 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe` compared `10000/10000`, normalized `10000`, mismatches `0`, validation/generator/property/command failures `0`, Binaryen cache hits/misses `10000/0`.

## Remaining OI-J work

OI-J remains `blocked-surface`. This slice removes one nullable exact-target `ref.test` gap where null is the only possible match. Remaining work includes nullable exact-target `ref.cast` narrowing to `nullref`, descriptor-cast behavior, useful-type-info and exactness breadth beyond the covered exact/inexact subtype proofs, broader TNH/IIT escaping/control descriptor surfaces, arbitrary ordinary cast targets, escaping labels, payload prefixes, effectful/control operands, EH/control descriptor surfaces, multivalue children, and generalized descriptor effect/control localization. The `ref.test_desc` and descriptor BrOn forms remain the unsupported/tooling/representation boundaries documented in note `1456`.
