# Optimize-instructions OI-I nullable ref.test/ref.cast null basics

## Question

Which first locally representable `ref.test` / `ref.cast` null-operand rewrites can Starshine add without entering broader descriptor, exactness, TNH, IIT, or arbitrary subtype-lattice work?

## Classification

Completed fifth positive `[O4Z-AUDIT-OI-I]` sub-slice.

This slice adds the Binaryen-observed nullable null-operand basics that only depend on the tested/cast target's nullable bit and a local `ref.null` operand:

- `ref.test (ref null T)` fed by `ref.null` folds to `i32.const 1`; and
- nullable `ref.cast (ref null T)` fed by `ref.null` rewrites to the null child.

The implementation also handles the local non-null `ref.test` / `ref.cast` null-operand cases internally (`i32.const 0` and `unreachable`, respectively), but this slice does not claim broad non-null cast/test parity. Starshine's current validation/type-matching surface rejects the simple direct-core non-null-null fixtures that Binaryen accepts, so non-null `ref.test` / `ref.cast` public coverage remains an OI-I validation/type-surface follow-up rather than a closed behavior family.

This remains deliberately narrower than Binaryen's full cast-check lattice. It does not use arbitrary subtype information, exactness, descriptor casts, TNH/IIT mode controls, or `ref.as_non_null` / successful `ref.cast` as general facts.

## Source anchors

- `docs/wiki/raw/binaryen/2026-06-19-optimize-instructions-version-130-source-refresh.md` maps Binaryen `visitRefTest(...)`, `visitRefCast(...)`, `visitRefAs(...)`, `skipCast(...)`, and the cast-check lattice to `[O4Z-AUDIT-OI-I]` / `[O4Z-AUDIT-OI-J]`.
- Local Binaryen `version_130` oracle probe with `wasm-opt --enable-reference-types --enable-gc -S -O --optimize-instructions` showed:
  - `ref.test (ref eq)` fed by `ref.null eq` becoming `i32.const 0`;
  - `ref.test (ref null eq)` fed by `ref.null eq` becoming `i32.const 1`;
  - non-null `ref.cast (ref eq)` fed by `ref.null eq` becoming `unreachable`; and
  - nullable `ref.cast (ref null eq)` fed by `ref.null eq` becoming `ref.null none`.
- `src/passes/optimize_instructions.mbt` now dispatches exact `HotOp::RefTest` nodes through `optimize_instructions_try_fold_ref_test_null(...)` and exact `HotOp::RefCast` nodes through `optimize_instructions_try_fold_ref_cast_null(...)` before the existing `ref.cast(unreachable)` validity repair.

## Tests

Added focused direct-core coverage in `src/passes/optimize_instructions_test.mbt`:

- `optimize-instructions folds nullable ref.test and ref.cast on known null refs`
  - builds direct-core nullable `ref.test` and nullable `ref.cast` functions because high-level WAST lacks ordinary `ref.test` / `ref.cast` text support;
  - asserts nullable `ref.test` of a known null becomes `I32(1)` and no longer contains `ref.test`;
  - asserts nullable `ref.cast` of a known null keeps `ref.null` and removes `ref.cast`.

Red-first evidence:

```sh
moon test --target native src/passes/optimize_instructions_test.mbt --filter '*nullable ref.test*'
# Before implementation: failed the new direct-core test. The nullable test/cast functions still contained `ref.test` / `ref.cast`.
```

Focused final evidence:

```sh
moon test --target native src/passes/optimize_instructions_test.mbt --filter '*nullable ref.test*'
# Total tests: 1, passed: 1, failed: 0.

moon test --target native src/passes/optimize_instructions_test.mbt --filter '*ref*'
# Total tests: 16, passed: 16, failed: 0.

moon test --target native src/passes/optimize_instructions_test.mbt --filter '*optimize-instructions*'
# Total tests: 144, passed: 144, failed: 0.
```

## Broader validation

```sh
moon fmt
# Finished.

moon test src/passes
# Total tests: 2656, passed: 2656, failed: 0.

moon build --target native --release src/cmd
# Finished with existing unused-function warnings in src/passes/pass_manager.mbt.

moon info
# Finished with existing warnings in src/validate/gen_valid.mbt and src/validate/gen_valid_ssa.mbt.

git diff --check
# Passed.
```

## Direct compare evidence

The first direct compare attempt with the same parameters and out dir `.tmp/pass-fuzz-optimize-instructions-oi-i-null-ref-test-cast-10000` timed out before writing `result.json`. The rerun completed with cached inputs/oracles:

```sh
rm -rf .tmp/pass-fuzz-optimize-instructions-oi-i-null-ref-test-cast-10000-rerun && bun scripts/pass-fuzz-compare.ts --pass optimize-instructions --count 10000 --seed 0x5eed --out-dir .tmp/pass-fuzz-optimize-instructions-oi-i-null-ref-test-cast-10000-rerun --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe
```

Result:

- requested: `10000`
- compared: `53/10000`
- normalized matches: `26`
- cleanup-normalized matches: `0`
- raw mismatches: `27`
- validation failures: `0`
- property failures: `0`
- generator failures: `0`
- command failures: `1`
- command failure class: `binaryen-rec-group-zero`
- jobs: `16`
- cache: wasm-smith `27` hits / `0` misses; Binaryen `53` hits / `0` misses; Binaryen failures `1` hit / `0` misses

Command failure classification: known **tool/Binaryen failure** (`binaryen-rec-group-zero`) from the cached failure lane.

Agent mismatch classification: the `27` raw mismatches are the known **Starshine-win** constant-if and redundant-sign-extension output-shape families from earlier OI slices, not new nullable `ref.test` / `ref.cast` semantic failures. Grepping final failure artifacts for `ref.test`, `ref.cast`, `ref.eq`, `ref.is_null`, `ref.as_non_null`, `ref.func`, and `ref.i31` found no occurrences.

## Remaining OI-I work

`[O4Z-AUDIT-OI-I]` remains open. This slice only adds nullable null-operand `ref.test` / `ref.cast` basics and an internal local null/non-null target branch. Remaining useful sub-slices include impossible equality beyond the covered null-vs-`ref.i31` subset, broader known `ref.is_null` constants/proofs beyond exact `ref.i31` and `ref.func`, public non-null `ref.test` / `ref.cast` null-operand validation/type-surface coverage, definitely successful `ref.test` / `ref.cast` cases, broader failed cast/test cases, broader `ref.as_non_null` cases beyond pure local constructors, broader unreachable/drop-child preservation, and default-mode trap/effect negatives. Descriptor, exactness, TNH, and IIT behavior should stay in `[O4Z-AUDIT-OI-J]` unless a future slice explicitly widens the local mode/metadata surface.
