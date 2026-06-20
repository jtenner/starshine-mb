# Optimize-instructions OI-I i31 supertype ref.test/ref.cast

## Question

Can Starshine safely widen the previous local `ref.i31` successful `ref.test` / `ref.cast` proof from exact `i31` targets to the abstract supertypes that every `i31ref` definitely inhabits?

## Classification

Completed seventh positive `[O4Z-AUDIT-OI-I]` sub-slice.

This slice widens the intentionally local `ref.i31` constructor proof for successful cast/test folding:

- `ref.test (ref eq)` and `ref.test (ref any)` fed by a local `ref.i31` constructor fold to `i32.const 1`; and
- `ref.cast (ref eq)` and `ref.cast (ref any)` fed by a local `ref.i31` constructor rewrite to the constructor child.

The proof remains narrow. It only relies on the abstract heap-type chain `i31 <: eq <: any` and the immediate local `ref.i31` constructor. It does not claim arbitrary subtype-lattice reasoning, indexed heap types, descriptors, exact heap types, `ref.func`, TNH/IIT mode behavior, or non-local facts.

## Source anchors

- `docs/wiki/raw/binaryen/2026-06-19-optimize-instructions-version-130-source-refresh.md` maps Binaryen `visitRefTest(...)`, `visitRefCast(...)`, `visitRefAs(...)`, `skipCast(...)`, and the cast-check lattice to `[O4Z-AUDIT-OI-I]` / `[O4Z-AUDIT-OI-J]`.
- Local Binaryen `version_130` oracle probe with `wasm-opt --enable-reference-types --enable-gc -S -O --optimize-instructions -o -` showed:
  - `i32.const 7; ref.i31; ref.test (ref eq)` becoming `i32.const 1`;
  - `i32.const 7; ref.i31; ref.cast (ref eq)` becoming just `ref.i31 (i32.const 7)`;
  - `i32.const 7; ref.i31; ref.test (ref any)` becoming `i32.const 1`; and
  - `i32.const 7; ref.i31; ref.cast (ref any)` becoming just `ref.i31 (i32.const 7)`.
- `src/validate/match.mbt` records the abstract heap-type subtype facts `i31 <: eq` and `i31 <: any`.
- `src/passes/optimize_instructions.mbt` now recognizes local `RefI31` constructor operands as definitely matching absolute `i31`, `eq`, and `any` targets for `RefTest` and `RefCast`.

## Tests

Expanded focused direct-core coverage in `src/passes/optimize_instructions_test.mbt`:

- `optimize-instructions folds successful ref.test and ref.cast on local i31 refs`
  - still covers exact `i31` targets from the previous sub-slice;
  - adds `eq` and `any` target-supertype `ref.test` functions and asserts they become `I32(1)` with no `ref.test`; and
  - adds `eq` and `any` target-supertype `ref.cast` functions and asserts they keep `ref.i31` while removing `ref.cast`.

Red-first evidence:

```sh
moon test --target native src/passes/optimize_instructions_test.mbt --filter '*successful ref.test*'
# Before implementation: failed the expanded direct-core test. The new `eq` supertype function still contained `ref.test`.
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

git diff --check
# Passed.
```

## Direct compare evidence

```sh
rm -rf .tmp/pass-fuzz-optimize-instructions-oi-i-i31-supertype-test-cast-10000 && bun scripts/pass-fuzz-compare.ts --pass optimize-instructions --count 10000 --seed 0x5eed --out-dir .tmp/pass-fuzz-optimize-instructions-oi-i-i31-supertype-test-cast-10000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe
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

Agent mismatch classification: the `27` raw mismatches are known **Starshine-win** constant-if and redundant-sign-extension output-shape families from earlier OI slices, not new reference semantic failures. Grepping final failure artifacts for `ref.test`, `ref.cast`, `ref.eq`, `ref.is_null`, `ref.as_non_null`, `ref.func`, and `ref.i31` found no occurrences.

## Remaining OI-I work

`[O4Z-AUDIT-OI-I]` remains open. This slice only widens successful `ref.test` / `ref.cast` folds for local `ref.i31` constructors to absolute target supertypes `eq` and `any`. Remaining useful sub-slices include impossible equality beyond the covered null-vs-`ref.i31` subset, broader known `ref.is_null` constants/proofs beyond exact `ref.i31` and `ref.func`, public non-null `ref.test` / `ref.cast` null-operand validation/type-surface coverage, other definitely successful `ref.test` / `ref.cast` cases, broader failed cast/test cases, broader `ref.as_non_null` cases, broader unreachable/drop-child preservation, and default-mode trap/effect negatives. Descriptor, exactness, TNH, and IIT behavior should stay in `[O4Z-AUDIT-OI-J]` unless a future slice explicitly widens the local mode/metadata surface.
