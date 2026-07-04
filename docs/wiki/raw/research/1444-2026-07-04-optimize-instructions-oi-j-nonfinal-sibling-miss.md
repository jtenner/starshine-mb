# OptimizeInstructions OI-J non-final sibling ref.test/ref.cast miss

Date: 2026-07-04

## Scope

This note records one finite OI-J parity slice after `dbfb13870 fix: fold final sibling ref cast misses`: concrete **non-final no-overlap** sibling heap miss proofs for ordinary `ref.test` / `ref.cast` on declared non-null locals.

The implemented slice is intentionally narrow:

- source operand: direct `local.get` whose declared reference heap is a concrete module type;
- source heap: concrete module type, including non-final `sub ...`, when no known module subtype overlaps both source and target;
- target heap: a different heap that neither the source heap nor any known source subtype can also match;
- overlap guard: if a module type can subtype the source heap and also match the target heap, Starshine keeps the `ref.test`/`ref.cast` fail-closed;
- result: `ref.test` folds to false, erasing trivially pure operands and preserving effectful operands through the existing drop-before-constant path; `ref.cast` folds to `unreachable` for definitely failing casts.

This does not claim descriptor casts, `ref.test_desc`, exactness beyond the ordinary cast/test immediate, TNH/IIT behavior, effect/control descriptor localization, or broad useful-type-info parity.

## Probe

The focused no-overlap probe uses distinct non-final struct shapes so Binaryen cannot treat the two heaps as identical:

```wat
(module
  (type $a (sub (struct (field i32))))
  (type $b (sub (struct (field i64))))
  (func (param $x (ref $a)) (result i32)
    (ref.test (ref $b) (local.get $x)))
  (func (param $x (ref $a)) (result (ref $b))
    (ref.cast (ref $b) (local.get $x)))
)
```

Artifacts live under `.tmp/oi-j-nonfinal-sibling-20260704/`. Binaryen `version_130` with `--all-features -S --optimize-instructions` folds the test to `local.get; drop; i32.const 0` and the cast to `unreachable`.

## Implementation

`src/ir/hot_module_context.mbt` now exposes `hot_module_subtype_count` so pass-local subtype reasoning can scan the closed module type table without exposing mutable internals.

`src/passes/optimize_instructions.mbt` replaces the previous final/no-sub-only source miss proof with `optimize_instructions_concrete_source_has_no_target_overlap`. The helper:

1. requires a concrete source heap and a module context;
2. refuses to fold when the source heap itself matches the target;
3. scans every concrete module heap and refuses to fold if any heap can match both the source and target through the existing subtype/abstract-heap matcher;
4. otherwise proves the ordinary `ref.test`/`ref.cast` must miss and reuses the existing false/unreachable replacement paths.

The scan is deliberately conservative. It preserves possible overlap from existing subtype declarations, including multi-supertype IR shapes, instead of inferring from finality alone.

## Tests

`src/passes/optimize_instructions_test.mbt::optimize-instructions folds impossible ref.test and ref.cast between non-final no-overlap sibling heap locals` was added red-first. It initially failed with a residual `ref.test` on the no-overlap function, then passed after the module subtype-overlap scan was implemented.

The same test includes an overlap guard: a source heap with a known child that also subtypes the target heap keeps `ref.test`, proving this slice does not over-fold possible runtime overlap.

Focused red/green command:

```sh
moon test src/passes/optimize_instructions_test.mbt --target native --filter 'optimize-instructions folds impossible ref.test and ref.cast between non-final no-overlap sibling heap locals'
```

Final validation for this slice passed:

- `python3 -m json.tool docs/wiki/binaryen/passes/optimize-instructions/parity-matrix.json >/dev/null`
- `moon fmt`
- `moon info` (passed with pre-existing warnings)
- `moon test src/passes/optimize_instructions_test.mbt --target native --filter '*ref.test*ref.cast*'` (`27/27`)
- `moon test` (`7421/7421`)
- `moon build --target native --release src/cmd` (passed with pre-existing warnings)
- focused probe replay on `.tmp/oi-j-nonfinal-sibling-20260704/nonfinal-input.wasm` emitted validating Starshine output with `i32.const 0` and `unreachable`
- `.tmp/oi-j-nonfinal-sibling-miss-genvalid-10000-20260704` regular `optimize-instructions` compare-pass: `10000/10000` compared, `10000` normalized matches, zero validation/generator/property/command failures, zero mismatches

## Remaining OI-J work

OI-J remains `blocked-surface` for broad descriptor/exactness/TNH/IIT parity. This slice removes the ordinary non-final no-overlap concrete sibling `ref.test` / `ref.cast` miss gap only. Remaining open work includes descriptor/exactness/TNH/IIT breadth, `ref.test_desc` representation/tooling, broader useful-type-info, and generalized descriptor effect/control localization.
