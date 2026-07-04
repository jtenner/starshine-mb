# OI-J nullable exact-target ref.cast nullref slice

Date: 2026-07-04

## Scope

This finite OI-J exactness/useful-type-info slice covers nullable exact-target `ref.cast` operations where a nullable operand can satisfy the target only when it is null:

```wat
(module
  (type $base (sub (struct (field i32))))
  (type $sub (sub $base (struct (field i32) (field i64))))
  (func $cast (param $x (ref null $sub)) (result (ref null (exact $base)))
    (ref.cast (ref null (exact $base)) (local.get $x)))
)
```

For non-null `$sub` values, exact runtime type `$base` is impossible; for null, the nullable exact target matches. Binaryen `version_130` narrows the cast to `ref.cast nullref`, preserving the original operand as the cast child so non-null values still trap and effects still execute in place. Starshine now does the same for nullable exact `$sub` operands and nullable inexact strict-subtype `$sub` operands proven by the module subtype table.

Out of scope: descriptor casts, `ref.test_desc`, same-heap inexact exact-target casts, arbitrary nullable useful-type-info beyond exact different concrete heaps and strict-subtype chains, TNH/IIT behavior, control/effect descriptor localization, and descriptor BrOn variants.

## Binaryen evidence

Probe directory: `.tmp/oi-j-next-probes/`.

Commands:

```text
wasm-tools validate --features all .tmp/oi-j-next-probes/nullable-exact-target-cast-nullref-20260704.wat
wasm-opt --all-features .tmp/oi-j-next-probes/nullable-exact-target-cast-nullref-20260704.wat --optimize-instructions -S -o .tmp/oi-j-next-probes/nullable-exact-target-cast-nullref-20260704.binaryen.wat
grep -n "ref.cast" .tmp/oi-j-next-probes/nullable-exact-target-cast-nullref-20260704.binaryen.wat
```

Binaryen rewrites exact nullable `$sub`, inexact nullable `$sub`, and effectful inexact nullable `$sub` casts against `(ref null (exact $base))` to `ref.cast nullref`. The effectful case keeps the call/global-set producer as the cast operand, preserving effects and the non-null trap.

This is the paired cast behavior left open by note `1458`, which covered only nullable exact-target `ref.test` rewriting to `ref.is_null`.

## Implementation

`src/passes/optimize_instructions.mbt` reuses the `optimize_instructions_ref_operand_matches_nullable_exact_target_only_as_null(...)` proof added by note `1458` and routes matching ordinary exact `ref.cast` nodes to `optimize_instructions_replace_ref_cast_with_nullref_cast(...)`.

The replacement builds `ref.cast nullref` with result type `nullref` and the original operand as its only child. That preserves operand effects and preserves the original trap behavior for non-null values while producing a subtype of the original nullable exact concrete result.

## Tests

Added red-first focused test:

- `src/passes/optimize_instructions_test.mbt::optimize-instructions narrows nullable exact ref.cast subtype misses to nullref`

Red result before implementation:

```text
moon test --package jtenner/starshine/passes --file optimize_instructions_test.mbt --target native --filter 'optimize-instructions narrows nullable exact ref.cast subtype misses to nullref'
=> failed with no `ref.cast nullref` in the exact nullable-subtype cast body
```

Green result after implementation:

```text
moon test --package jtenner/starshine/passes --file optimize_instructions_test.mbt --target native --filter 'optimize-instructions narrows nullable exact ref.cast subtype misses to nullref'
=> Total tests: 1, passed: 1, failed: 0.
```

The focused test covers nullable exact `$sub`, nullable inexact strict-subtype `$sub`, and an effectful nullable inexact strict-subtype producer. It asserts the exact `$base` cast target is removed and `RefCast(true, false, none)` remains in all three optimized functions.

## Validation

Completed in this slice:

- Binaryen probe commands above passed; Binaryen output contains three `ref.cast nullref` instructions.
- Red-first focused command above failed before implementation.
- Green focused command above passed `1/1` after implementation.
- `moon fmt` passed.
- `moon info` passed with pre-existing warnings.
- `moon test --package jtenner/starshine/passes --file optimize_instructions_test.mbt --target native --filter '*nullable exact ref*'` passed `2/2`.
- Full `moon test` passed `7432/7432`.
- `moon build --target native --release src/cmd` passed with pre-existing warnings.
- Probe replay using `wasm-tools parse`, native `cmd.exe --optimize-instructions`, `wasm-tools validate --features all`, and `wasm-tools print` emitted validating Starshine output with three `ref.cast nullref` instructions.
- Regular GenValid compare-pass: `bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass optimize-instructions --out-dir .tmp/oi-j-nullable-exact-target-cast-nullref-genvalid-10000-20260704 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe` compared `10000/10000`, normalized `10000`, mismatches `0`, validation/generator/property/command failures `0`, Binaryen cache hits/misses `10000/0`.
- `python3 -m json.tool docs/wiki/binaryen/passes/optimize-instructions/parity-matrix.json >/dev/null` passed.
- `git diff --check` passed.

## Remaining OI-J work

OI-J remains `blocked-surface`. This slice removes the nullable exact-target `ref.cast` gap paired with note `1458`'s nullable exact-target `ref.test` gap. Remaining work includes descriptor-cast behavior, useful-type-info and exactness breadth beyond the covered exact/inexact subtype proofs, broader TNH/IIT escaping/control descriptor surfaces, arbitrary ordinary cast targets, escaping labels, payload prefixes, effectful/control operands, EH/control descriptor surfaces, multivalue children, and generalized descriptor effect/control localization. The `ref.test_desc` and descriptor BrOn forms remain the unsupported/tooling/representation boundaries documented in note `1456`.
