# Optimize-instructions OI-I known-non-null reference basics

## Question

Which locally representable known-non-null reference shapes can Starshine fold before entering broader `ref.test` / `ref.cast`, descriptor, exactness, TNH, and IIT-sensitive work?

## Classification

Completed third positive `[O4Z-AUDIT-OI-I]` sub-slice.

This slice adds the Binaryen-observed known-non-null basics that only depend on local constructor knowledge:

- `ref.is_null(ref.i31(x))` folds to `i32.const 0`;
- `ref.is_null(ref.func f)` folds to `i32.const 0`; and
- `ref.eq(ref.i31(x), ref.null eq)` / `ref.eq(ref.null eq, ref.i31(x))` fold to `i32.const 0` instead of materializing a redundant null test.

The implementation deliberately limits the known-non-null proof to pure local constructors (`ref.i31` and `ref.func`). It does not treat `ref.as_non_null`, `ref.cast`, `ref.test`, descriptor casts, or exact subtype information as general non-null proofs because those families are trap-, type-, and mode-sensitive and remain open for later OI-I/OI-J slices.

The slice also corrects Starshine validation for `ref.is_null` operands: the typechecker now accepts any reference operand, including non-null references, and still rejects non-reference operands. This was needed to expose the public WAT fixtures for the optimizer behavior.

## Source anchors

- `docs/wiki/raw/binaryen/2026-06-19-optimize-instructions-version-130-source-refresh.md` maps Binaryen `visitRefEq(...)`, `visitRefIsNull(...)`, `visitRefTest(...)`, `visitRefCast(...)`, and the cast-check lattice to `[O4Z-AUDIT-OI-I]` / `[O4Z-AUDIT-OI-J]`.
- Local Binaryen `version_130` oracle probe with `wasm-opt --enable-reference-types --enable-gc -S -O --optimize-instructions` showed `ref.is_null(ref.i31(...))`, both `ref.eq(ref.i31(...), null)` operand orders, and `ref.is_null(ref.func f)` all fold to `i32.const 0`.
- `src/validate/typecheck.mbt` now accepts `ref.is_null` on non-null reference operands, matching the wasm stack-subtyping surface needed by the fixture.
- `src/passes/optimize_instructions.mbt` now uses a local known-non-null helper for exact `ref.i31` and `ref.func` nodes in the `RefIsNull` fold and null-operand `RefEq` rewrite.

## Tests

Added focused tests in `src/passes/optimize_instructions_test.mbt`:

- `optimize-instructions folds ref.is_null on locally known non-null refs`
  - WAT fixture with `ref.i31` and `ref.func` operands;
  - asserts the optimized functions return `I32(0)` and no longer contain the null-check result.
- `optimize-instructions folds null equality against locally known non-null refs`
  - WAT fixture with right-null and left-null `ref.eq` over `ref.i31`;
  - asserts `ref.eq` disappears and each function returns `I32(0)`.

Added validation coverage in `src/validate/typecheck.mbt`:

- `Typecheck RefIsNull accepts non-null references`.

Red-first evidence:

```sh
moon test --target native src/passes/optimize_instructions_test.mbt --filter '*known non-null*'
# First failed before the validation fix because Starshine rejected non-null ref.is_null operands.
# After the typechecker correction and before the optimizer implementation, the two new OI tests failed because the functions still contained the original ref.is_null/ref.eq shapes instead of I32(0).
```

Focused final evidence:

```sh
moon test --target native src/validate/typecheck.mbt --filter '*RefIsNull*'
# Total tests: 2, passed: 2, failed: 0.

moon test --target native src/passes/optimize_instructions_test.mbt --filter '*known non-null*'
# Total tests: 2, passed: 2, failed: 0.

moon test --target native src/passes/optimize_instructions_test.mbt --filter '*ref*'
# Total tests: 15, passed: 15, failed: 0.

moon test --target native src/passes/optimize_instructions_test.mbt --filter '*optimize-instructions*'
# Total tests: 143, passed: 143, failed: 0.
```

## Broader validation

```sh
moon fmt
# Finished.

moon test src/passes
# Total tests: 2655, passed: 2655, failed: 0.

moon test src/validate
# Total tests: 1612, passed: 1612, failed: 0.

moon build --target native --release src/cmd
# Finished with existing unused-function warnings in src/passes/pass_manager.mbt.

moon info
# Finished with existing warnings in src/validate/gen_valid.mbt and src/validate/gen_valid_ssa.mbt.
```

## Direct compare evidence

The first 10000-case compare attempt timed out before writing `result.json`:

```sh
rm -rf .tmp/pass-fuzz-optimize-instructions-oi-i-known-non-null-10000 && bun scripts/pass-fuzz-compare.ts --pass optimize-instructions --count 10000 --seed 0x5eed --out-dir .tmp/pass-fuzz-optimize-instructions-oi-i-known-non-null-10000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe
# timed out after 600s; no result.json
```

Rerun command:

```sh
rm -rf .tmp/pass-fuzz-optimize-instructions-oi-i-known-non-null-10000-rerun && bun scripts/pass-fuzz-compare.ts --pass optimize-instructions --count 10000 --seed 0x5eed --out-dir .tmp/pass-fuzz-optimize-instructions-oi-i-known-non-null-10000-rerun --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe
```

Result:

- requested: `10000`
- compared: `56/10000`
- normalized matches: `28`
- cleanup-normalized matches: `0`
- raw mismatches: `28`
- validation failures: `0`
- property failures: `0`
- generator failures: `0`
- command failures: `1`
- jobs: `16`
- cache: wasm-smith `29` hits / `0` misses; Binaryen `56` hits / `0` misses; Binaryen failures `1` hit / `0` misses

Command failure classification: known **tool/Binaryen failure** (`binaryen-rec-group-zero`) from the cached failure lane.

Agent mismatch classification: the `28` raw mismatches are the known **Starshine-win** constant-if and redundant-sign-extension output-shape families from earlier OI slices, not new reference semantic failures. Grepping final failure artifacts for `ref.is_null`, `ref.eq`, `ref.test`, `ref.cast`, `ref.as_non_null`, `ref.func`, and `ref.i31` found no occurrences.

## Remaining OI-I work

`[O4Z-AUDIT-OI-I]` remains open. This slice only adds locally known-non-null constructor proofs for `ref.i31` / `ref.func` null checks and the `ref.i31` null-equality subset, plus the validation surface needed to author non-null `ref.is_null` WAT fixtures. Remaining useful sub-slices include impossible equality beyond `null` vs `ref.i31`, locally representable `ref.test` / `ref.cast` success and failure cases, broader `ref.as_non_null` operands, broader unreachable/drop-child preservation, and default-mode trap/effect negatives. Descriptor, exactness, TNH, and IIT behavior should stay in `[O4Z-AUDIT-OI-J]` unless a future slice explicitly widens the local mode/metadata surface.
