# OptimizeInstructions OI-J final sibling ref.test/ref.cast miss

Date: 2026-07-04

## Scope

This note records one finite OI-J parity slice after `4d69a6151 fix: fold exact ref.test success predicates`: concrete **final/no-sub** sibling heap miss proofs for ordinary `ref.test` / `ref.cast` on declared non-null locals.

The implemented slice is intentionally narrow:

- source operand: direct `local.get` whose declared reference heap is a concrete module type;
- source heap: `sub final ...` or the no-sub shorthand decoded as `CompTypeSubType`, so all runtime values with that source type are exactly the source heap or one of its declared supertypes;
- target heap: a different heap not matched by the final source heap or its declared supertypes;
- result: `ref.test` folds to false, erasing trivially pure operands and preserving effectful operands as existing helpers do; `ref.cast` folds to `unreachable` for the definitely failing cast.

This does not claim broader non-final sibling overlap reasoning, multiple-supertype overlap closure, descriptor casts, `ref.test_desc`, TNH/IIT behavior, or generalized useful-type-info parity.

## Probe

The prior roadmap probe 11 used two empty structs. That is not valid evidence for sibling-miss behavior because `wasm-opt --all-features` can canonicalize/merge identical empty struct heap types before `--optimize-instructions`, turning the apparent sibling miss into a same-type success.

A replacement focused probe uses distinct final struct shapes:

```wat
(module
  (type $a (sub final (struct (field i32))))
  (type $b (sub final (struct (field i64))))
  (func (param $x (ref $a)) (result i32)
    (ref.test (ref $b) (local.get $x)))
  (func (param $x (ref $a)) (result (ref $b))
    (ref.cast (ref $b) (local.get $x)))
)
```

Artifacts live under `.tmp/oi-j-sibling-miss-20260704/`.

Binaryen `version_130` with `--optimize-instructions` folds the test to `local.get; drop; i32.const 0` and the cast to `unreachable`. Starshine before this slice left residual `ref.test (ref none)` / `ref.cast (ref none)` in the printed output while still validating. After this slice, Starshine emits `i32.const 0` and `unreachable`; this is a measured Starshine-win output-shape difference for the pure-local test operand (`49` raw wasm bytes versus Binaryen's `52`, and `336` printed WAT bytes versus `361`) rather than a remaining parity gap.

## Implementation

`src/passes/optimize_instructions.mbt` now passes `HotPassContext` into the known-miss helpers so they can consult the module context. The new concrete helper resolves the source heap subtype through `@ir.hot_module_resolve_subtype` and proves a miss only when the source concrete heap is final/no-sub and does not match the target heap through its own heap identity, abstract heap family, or declared supertypes.

The existing replacement paths then reuse the prior behavior:

- trivially pure `ref.test` operand: replace with `i32.const 0`;
- effectful `ref.test` operand: drop the operand before `i32.const 0`;
- trivially pure failed `ref.cast`: replace with `unreachable`;
- effectful failed `ref.cast`: drop the operand before `unreachable`.

## Tests

`src/passes/optimize_instructions_test.mbt::optimize-instructions folds impossible ref.test and ref.cast between final sibling heap locals` was added red-first. It initially failed with residual `ref.test` on the first function, then passed after the final-source miss proof was implemented.

Focused command:

```sh
moon test src/passes/optimize_instructions_test.mbt --target native --filter 'optimize-instructions folds impossible ref.test and ref.cast between final sibling heap locals'
```

Final validation for this slice passed:

- `python3 -m json.tool docs/wiki/binaryen/passes/optimize-instructions/parity-matrix.json >/dev/null`
- `moon fmt`
- `moon test src/passes/optimize_instructions_test.mbt --target native --filter '*ref.test*ref.cast*'` (`26/26`)
- `moon test` (`7420/7420`)
- `moon info` (passed with pre-existing warnings)
- `moon build --target native --release src/cmd` (passed with pre-existing warnings)
- focused probe replay on `.tmp/oi-j-sibling-miss-20260704/final-input.wasm` emitted validating Starshine output with `i32.const 0` and `unreachable`
- `.tmp/oi-j-final-sibling-miss-genvalid-10000-20260704` regular `optimize-instructions` compare-pass: `10000/10000` compared, `10000` normalized matches, zero validation/generator/property/command failures, zero mismatches

A native full `moon test --target native` attempt timed out after 1200s while running unrelated long native tests; the regular full `moon test` passed.

## Remaining OI-J work

OI-J remains `blocked-surface` for broad descriptor/exactness/TNH/IIT parity. This slice only removes the final concrete sibling ordinary `ref.test` / `ref.cast` miss gap and should not be used as evidence for descriptor equality casts, `ref.test_desc`, non-final sibling overlap, generalized label-aware descriptor localization, or broad useful-type-info inference.
