# OptimizeInstructions OI-J exact subtype ref.test/ref.cast miss

Date: 2026-07-04

## Scope

This note records one finite OI-J exactness slice after `8fb8620ca fix: fold non-final sibling ref cast misses`: exact-target `ref.test` / `ref.cast` misses where the operand is statically known to have a different exact subtype heap.

The implemented slice is intentionally narrow:

- operand type: a reference value whose HOT result type is exact for some heap `$sub`;
- target immediate: an exact concrete heap `$base` where `$sub != $base`;
- nullability guard: nullable exact targets only fold when the operand is statically non-null, because `null` still matches a nullable target;
- result: `ref.test` folds to `i32.const 0` and `ref.cast` folds to `unreachable`, preserving effectful operands through the existing drop-before-constant/unreachable paths.

This does not claim descriptor casts, `ref.test_desc`, TNH/IIT behavior, non-exact source exact-target reasoning, or broad exactness/useful-type-info closure.

## Probe

Focused probes live under `.tmp/oi-j-exact-subtype-miss-20260704/`.

The pure probe uses a strict subtype pair:

```wat
(module
  (type $base (sub (struct (field i32))))
  (type $sub (sub $base (struct (field i32) (field i64))))
  (func $test (param $x (ref (exact $sub))) (result i32)
    (ref.test (ref (exact $base)) (local.get $x)))
  (func $cast (param $x (ref (exact $sub))) (result (ref (exact $base)))
    (ref.cast (ref (exact $base)) (local.get $x)))
)
```

Binaryen `version_130` with `wasm-opt --all-features -S --optimize-instructions` folds the exact test to dropped operand plus `i32.const 0` and the exact cast to `unreachable`. A companion effectful probe confirms Binaryen preserves `global.set`-carrying operand blocks as dropped prefixes before the same false/unreachable replacements.

## Implementation

`src/passes/optimize_instructions.mbt` adds `optimize_instructions_ref_operand_misses_exact_target`. The helper inspects the operand HOT result type and proves an exact-target miss only when the operand itself is exact for a different heap and either the operand is non-null or the target is non-null.

The ordinary known-miss paths for `RefTest` and `RefCast` now include this exact-target proof. Existing replacement helpers keep behavior consistent with the rest of the reference optimizer:

- pure `ref.test` operand: replace with `i32.const 0`;
- effectful `ref.test` operand: drop the operand before `i32.const 0`;
- pure failed `ref.cast`: replace with `unreachable`;
- effectful failed `ref.cast`: drop the operand before `unreachable`.

## Tests

`src/passes/optimize_instructions_test.mbt::optimize-instructions folds exact ref.test and ref.cast misses on exact subtype operands` was added red-first. It initially failed with a residual `ref.test (ref (exact $base))` on an exact `$sub` local, then passed after the exact-target miss helper was implemented.

The test covers pure and effectful exact `ref.test` misses plus pure and effectful exact `ref.cast` misses. It is deliberately limited to exact-typed operands and does not infer broad exact-target miss behavior from inexact source types.

## Validation

Completed in this slice:

- Red-first focused command: `moon test src/passes/optimize_instructions_test.mbt --target native --filter 'optimize-instructions folds exact ref.test and ref.cast misses on exact subtype operands'` failed before implementation with a residual `ref.test`.
- Green focused command: the same command passed `1/1` after implementation.
- Focused exact ref.test/ref.cast command: `moon test src/passes/optimize_instructions_test.mbt --target native --filter '*exact ref.test*ref.cast*'` passed `1/1`.
- `moon build --target native --release src/cmd` passed with pre-existing warnings.
- Probe replay: native `cmd.exe --optimize-instructions` on `.tmp/oi-j-exact-subtype-miss-20260704/input.wasm` and `effectful.wasm` emitted validating Starshine outputs; printed WAT contains `i32.const 0`, `unreachable`, and preserved `global.set` prefixes with no residual `ref.test` / `ref.cast`.

Final signoff after docs updates also passed:

- `python3 -m json.tool docs/wiki/binaryen/passes/optimize-instructions/parity-matrix.json >/dev/null`
- `moon fmt`
- `moon info` (pre-existing warnings only)
- `moon test src/passes/optimize_instructions_test.mbt --target native --filter '*ref.test*ref.cast*'` (`28/28`)
- full `moon test` (`7422/7422`)
- `moon build --target native --release src/cmd`
- regular GenValid compare-pass `.tmp/oi-j-exact-subtype-miss-genvalid-10000-20260704`: compared `10000/10000`, normalized `10000`, mismatches `0`, validation/generator/property/command failures `0`, Binaryen cache hits/misses `10000/0`
- `git diff --check` passed before commit.

## Remaining OI-J work

OI-J remains `blocked-surface`. This slice removes one exactness/useful-type-info gap where exact-subtype operands cannot match exact-supertype targets. Remaining open work includes descriptor/exactness/TNH/IIT breadth, `ref.test_desc` representation/tooling, broader descriptor casts, generalized descriptor effect/control localization, and exact-target reasoning beyond this exact-typed operand proof.
