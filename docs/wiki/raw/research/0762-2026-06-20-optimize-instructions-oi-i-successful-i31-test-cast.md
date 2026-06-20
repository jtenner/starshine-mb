# Optimize-instructions OI-I successful ref.test/ref.cast on local i31

## Question

Which first definitely-successful `ref.test` / `ref.cast` cases can Starshine fold without entering descriptor, exactness, TNH, IIT, or arbitrary subtype-lattice work?

## Classification

Completed sixth positive `[O4Z-AUDIT-OI-I]` sub-slice.

This slice adds a narrow local constructor proof for exact i31 targets:

- `ref.test (ref i31)` fed by a local `ref.i31` constructor folds to `i32.const 1`; and
- `ref.cast (ref i31)` fed by a local `ref.i31` constructor rewrites to the constructor child.

The proof is intentionally exact and local. It does not claim broader successful cast/test parity for target supertypes, `ref.func`, arbitrary subtype information, descriptors, exact heap types, TNH/IIT mode behavior, or non-local facts.

## Source anchors

- `docs/wiki/raw/binaryen/2026-06-19-optimize-instructions-version-130-source-refresh.md` maps Binaryen `visitRefTest(...)`, `visitRefCast(...)`, `visitRefAs(...)`, `skipCast(...)`, and the cast-check lattice to `[O4Z-AUDIT-OI-I]` / `[O4Z-AUDIT-OI-J]`.
- Local Binaryen `version_130` oracle probe with `wasm-opt --enable-reference-types --enable-gc -S -O --optimize-instructions` showed:
  - `i32.const 7; ref.i31; ref.test (ref i31)` becoming `i32.const 1`; and
  - `i32.const 7; ref.i31; ref.cast (ref i31)` becoming just `ref.i31 (i32.const 7)`.
- `src/passes/optimize_instructions.mbt` now recognizes local `RefI31` constructor operands as definitely matching exact absolute `i31` targets for `RefTest` and `RefCast`.

## Tests

Added focused direct-core coverage in `src/passes/optimize_instructions_test.mbt`:

- `optimize-instructions folds successful ref.test and ref.cast on local i31 refs`
  - builds direct-core functions because high-level WAST lacks ordinary `ref.test` / `ref.cast` text support;
  - asserts `ref.test (ref i31)` of a local `ref.i31` becomes `I32(1)` and no longer contains `ref.test`; and
  - asserts `ref.cast (ref i31)` of a local `ref.i31` keeps `ref.i31` and removes `ref.cast`.

Red-first evidence:

```sh
moon test --target native src/passes/optimize_instructions_test.mbt --filter '*successful ref.test*'
# Before implementation: failed the new direct-core test. The successful i31 test/cast functions still contained `ref.test` / `ref.cast`.
```

Focused final evidence:

```sh
moon test --target native src/passes/optimize_instructions_test.mbt --filter '*successful ref.test*'
# Total tests: 1, passed: 1, failed: 0.

moon test --target native src/passes/optimize_instructions_test.mbt --filter '*ref*'
# Total tests: 17, passed: 17, failed: 0.

moon test --target native src/passes/optimize_instructions_test.mbt --filter '*optimize-instructions*'
# Total tests: 145, passed: 145, failed: 0.
```

## Broader validation

```sh
moon fmt
# Finished.

moon test src/passes
# Total tests: 2657, passed: 2657, failed: 0.

moon build --target native --release src/cmd
# Finished with existing unused-function warnings in src/passes/pass_manager.mbt.

moon info
# Finished with existing warnings in src/validate/gen_valid.mbt and src/validate/gen_valid_ssa.mbt.
```

## Direct compare evidence

The first direct compare attempt with out dir `.tmp/pass-fuzz-optimize-instructions-oi-i-successful-i31-test-cast-10000` timed out before writing final results. The rerun completed with cached inputs/oracles:

```sh
rm -rf .tmp/pass-fuzz-optimize-instructions-oi-i-successful-i31-test-cast-10000-rerun && bun scripts/pass-fuzz-compare.ts --pass optimize-instructions --count 10000 --seed 0x5eed --out-dir .tmp/pass-fuzz-optimize-instructions-oi-i-successful-i31-test-cast-10000-rerun --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe
```

Result:

- requested: `10000`
- compared: `55/10000`
- normalized matches: `27`
- cleanup-normalized matches: `0`
- raw mismatches: `28`
- validation failures: `0`
- property failures: `0`
- generator failures: `0`
- command failures: `1`
- command failure class: `binaryen-rec-group-zero`
- jobs: `16`
- cache: wasm-smith `28` hits / `0` misses; Binaryen `55` hits / `0` misses; Binaryen failures `1` hit / `0` misses

Command failure classification: known **tool/Binaryen failure** (`binaryen-rec-group-zero`) from the cached failure lane.

Agent mismatch classification: the `28` raw mismatches are known **Starshine-win** constant-if and redundant-sign-extension output-shape families from earlier OI slices, not new reference semantic failures. Grepping final failure artifacts for `ref.test`, `ref.cast`, `ref.eq`, `ref.is_null`, `ref.as_non_null`, `ref.func`, and `ref.i31` found no occurrences.

## Remaining OI-I work

`[O4Z-AUDIT-OI-I]` remains open. This slice only adds exact successful `ref.test` / `ref.cast` folds for local `ref.i31` constructors with exact absolute `i31` targets. Remaining useful sub-slices include impossible equality beyond the covered null-vs-`ref.i31` subset, broader known `ref.is_null` constants/proofs beyond exact `ref.i31` and `ref.func`, public non-null `ref.test` / `ref.cast` null-operand validation/type-surface coverage, target-supertypes and other definitely successful `ref.test` / `ref.cast` cases, broader failed cast/test cases, broader `ref.as_non_null` cases, broader unreachable/drop-child preservation, and default-mode trap/effect negatives. Descriptor, exactness, TNH, and IIT behavior should stay in `[O4Z-AUDIT-OI-J]` unless a future slice explicitly widens the local mode/metadata surface.
