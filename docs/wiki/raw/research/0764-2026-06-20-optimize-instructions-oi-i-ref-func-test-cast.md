# Optimize-instructions OI-I ref.func ref.test/ref.cast

## Question

Can Starshine safely reuse the local `ref.func` constructor proof for definitely successful `ref.test` / `ref.cast` cleanup when the target is the absolute `func` heap type?

## Classification

Completed eighth positive `[O4Z-AUDIT-OI-I]` sub-slice.

This slice adds a narrow successful cast/test proof for local function references:

- `ref.test (ref func)` fed by a local `ref.func` constructor folds to `i32.const 1`; and
- `ref.cast (ref func)` fed by a local `ref.func` constructor rewrites to the constructor child.

The proof remains intentionally local. It only recognizes immediate `ref.func` constructors and exact absolute `func` targets. It does not claim `func` target supertypes, arbitrary subtype-lattice facts, indexed function heap types, descriptors, exact heap types, TNH/IIT mode behavior, or non-local facts. A local Binaryen probe rejected `ref.func` operands tested/cast to `(ref any)` and `(ref eq)`, so this slice does not widen beyond exact `func`.

## Source anchors

- `docs/wiki/raw/binaryen/2026-06-19-optimize-instructions-version-130-source-refresh.md` maps Binaryen `visitRefTest(...)`, `visitRefCast(...)`, `visitRefAs(...)`, `skipCast(...)`, and the cast-check lattice to `[O4Z-AUDIT-OI-I]` / `[O4Z-AUDIT-OI-J]`.
- Local Binaryen `version_130` oracle probe with `wasm-opt --enable-reference-types --enable-gc -S -O --optimize-instructions -o -` showed:
  - `ref.func $callee; ref.test (ref func)` becoming `i32.const 1`; and
  - `ref.func $callee; ref.cast (ref func)` becoming just `ref.func $callee`.
- The same local probe rejected attempted `ref.func` operands with `(ref any)` / `(ref eq)` targets, so exact `func` is the only claimed target for this sub-slice.
- `src/passes/optimize_instructions.mbt` now recognizes local `RefFunc` operands as definitely matching absolute `func` targets for `RefTest` and `RefCast`.

## Tests

Added focused direct-core coverage in `src/passes/optimize_instructions_test.mbt`:

- `optimize-instructions folds successful ref.test and ref.cast on local ref.func refs`
  - builds a declarative element segment so `ref.func` is valid;
  - asserts exact `ref.test (ref func)` becomes `I32(1)` with no `ref.test`; and
  - asserts exact `ref.cast (ref func)` keeps `ref.func` while removing `ref.cast`.

Red-first evidence:

```sh
moon test --target native src/passes/optimize_instructions_test.mbt --filter '*local ref.func refs*'
# Before implementation: failed because the new direct-core ref.func function still contained `ref.test`.
```

Focused final evidence:

```sh
moon test --target native src/passes/optimize_instructions_test.mbt --filter '*local ref.func refs*'
# Total tests: 1, passed: 1, failed: 0.

moon test --target native src/passes/optimize_instructions_test.mbt --filter '*ref*'
# Total tests: 18, passed: 18, failed: 0.

moon test --target native src/passes/optimize_instructions_test.mbt --filter '*optimize-instructions*'
# Total tests: 146, passed: 146, failed: 0.
```

## Broader validation

```sh
moon fmt
# Finished.

moon test src/passes
# Total tests: 2658, passed: 2658, failed: 0.

moon build --target native --release src/cmd
# Finished with existing unused-function warnings in src/passes/pass_manager.mbt.

moon info
# Finished with existing warnings in src/validate/gen_valid.mbt and src/validate/gen_valid_ssa.mbt.

git diff --check
# Passed.
```

## Direct compare evidence

The first direct compare attempt timed out before producing `result.json`. The successful rerun used:

```sh
rm -rf .tmp/pass-fuzz-optimize-instructions-oi-i-ref-func-test-cast-10000 && bun scripts/pass-fuzz-compare.ts --pass optimize-instructions --count 10000 --seed 0x5eed --out-dir .tmp/pass-fuzz-optimize-instructions-oi-i-ref-func-test-cast-10000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe
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

`[O4Z-AUDIT-OI-I]` remains open. This slice only adds successful exact `func`-target `ref.test` / `ref.cast` folds for local `ref.func` constructors. Remaining useful sub-slices include impossible equality beyond the covered null-vs-`ref.i31` subset, broader known `ref.is_null` constants/proofs beyond exact `ref.i31` and `ref.func`, public non-null `ref.test` / `ref.cast` null-operand validation/type-surface coverage, other definitely successful `ref.test` / `ref.cast` cases, broader failed cast/test cases, broader `ref.as_non_null` cases, broader unreachable/drop-child preservation, and default-mode trap/effect negatives. Descriptor, exactness, TNH, and IIT behavior should stay in `[O4Z-AUDIT-OI-J]` unless a future slice explicitly widens the local mode/metadata surface.
