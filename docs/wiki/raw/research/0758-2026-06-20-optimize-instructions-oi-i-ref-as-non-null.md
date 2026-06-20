# Optimize-instructions OI-I ref.as_non_null basics

## Question

Which first locally representable `ref.as_non_null` rewrites should Starshine add before broader `ref.test` / `ref.cast` lattice, descriptor, exactness, TNH, and IIT work?

## Classification

Completed second positive `[O4Z-AUDIT-OI-I]` sub-slice.

This slice adds the Binaryen-observed `ref.as_non_null` basics that only depend on local constant/null knowledge:

- `ref.as_non_null(ref.null T)` rewrites to `unreachable`; and
- `ref.as_non_null(ref.i31(x))` rewrites to `ref.i31(x)`.

The implementation also collapses a `ref.cast` whose operand has become `unreachable` to `unreachable`. That keeps the HOT tree and lowered output valid for stacked source shapes such as `ref.null; ref.as_non_null; ref.cast`, where the child rewrite otherwise left a parent cast with an unreachable operand that lowered as invalid `unreachable; ref.cast` stack code.

This is intentionally not a full `[O4Z-AUDIT-OI-I]` closeout. Remaining reference work still includes impossible equality/non-null proofs beyond `ref.i31`, `ref.is_null` known-non-null proofs, locally representable `ref.test` and `ref.cast` success/failure cases, broader `ref.as_non_null` operands, unreachable/drop-child preservation beyond the exact cast repair covered here, and default-mode trap/effect negatives. Descriptor/exactness/TNH/IIT behavior remains reserved for `[O4Z-AUDIT-OI-J]` unless a future slice explicitly widens the local mode/metadata surface.

## Source anchors

- `docs/wiki/raw/binaryen/2026-06-19-optimize-instructions-version-130-source-refresh.md` maps Binaryen `visitRefAs(...)`, `skipNonNullCast(...)`, `skipCast(...)`, and the cast-check lattice to `[O4Z-AUDIT-OI-I]` / `[O4Z-AUDIT-OI-J]`.
- Local Binaryen `version_130` oracle probe with `wasm-opt --enable-reference-types --enable-gc -S -O --optimize-instructions` showed:
  - `(ref.as_non_null (ref.null eq))` becomes `unreachable`; and
  - `(ref.as_non_null (ref.i31 (i32.const 3)))` becomes `ref.i31 (i32.const 3)`.
- `src/passes/optimize_instructions.mbt` now handles exact `RefAsNonNull` nodes in the local `HotOp::Heap` dispatch and exact `RefCast` nodes whose operand has become `Unreachable` in the `HotOp::RefCast` dispatch.

## Tests

Added focused tests in `src/passes/optimize_instructions_test.mbt`:

- `optimize-instructions folds ref.as_non_null on known null and non-null refs`
  - WAT fixture with `ref.null eq; ref.as_non_null` and `i32.const 7; ref.i31; ref.as_non_null`;
  - asserts the null case now contains `unreachable` and no `ref.as_non_null`;
  - asserts the known-non-null `ref.i31` case keeps `ref.i31` and removes `ref.as_non_null`.
- `optimize-instructions collapses casts fed by unreachable ref.as_non_null`
  - direct-core fixture for `ref.null func; ref.as_non_null; ref.cast (ref func)`;
  - asserts the optimized function contains `unreachable` and no remaining `ref.as_non_null` or `ref.cast`.

Red-first evidence:

```sh
moon test --target native src/passes/optimize_instructions_test.mbt --filter '*ref.as_non_null*'
# Before implementation: failed the first new test. The null function still contained raw `ref.null; ref.as_non_null`.
```

During implementation, broader pass tests exposed a validity regression in an existing DAE nested optimize-casts fixture: rewriting `ref.as_non_null(ref.null)` under `ref.cast` left invalid lowered `unreachable; ref.cast` output. The `HotOp::RefCast` unreachable-operand collapse plus the new direct-core OI test now cover that case.

Focused final evidence:

```sh
moon test --target native src/passes/optimize_instructions_test.mbt --filter '*ref.as_non_null*'
# Total tests: 2, passed: 2, failed: 0.

moon test --target native src/passes/optimize_instructions_test.mbt --filter '*ref*'
# Total tests: 13, passed: 13, failed: 0.

moon test --target native src/passes/optimize_instructions_test.mbt --filter '*optimize-instructions*'
# Total tests: 141, passed: 141, failed: 0.
```

## Broader validation

```sh
moon fmt
# Finished.

moon test src/passes
# Total tests: 2653, passed: 2653, failed: 0.

moon build --target native --release src/cmd
# Finished with existing unused-function warnings in src/passes/pass_manager.mbt.

moon info
# Finished with existing warnings in src/validate/gen_valid.mbt and src/validate/gen_valid_ssa.mbt.
```

## Direct compare evidence

The first 10000-case compare attempt timed out before writing `result.json`:

```sh
rm -rf .tmp/pass-fuzz-optimize-instructions-oi-i-ref-as-non-null-10000 && bun scripts/pass-fuzz-compare.ts --pass optimize-instructions --count 10000 --seed 0x5eed --out-dir .tmp/pass-fuzz-optimize-instructions-oi-i-ref-as-non-null-10000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe
# timed out after 600s; no result.json
```

Rerun command:

```sh
rm -rf .tmp/pass-fuzz-optimize-instructions-oi-i-ref-as-non-null-10000-rerun && bun scripts/pass-fuzz-compare.ts --pass optimize-instructions --count 10000 --seed 0x5eed --out-dir .tmp/pass-fuzz-optimize-instructions-oi-i-ref-as-non-null-10000-rerun --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe
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
- jobs: `16`
- cache: wasm-smith `28` hits / `0` misses; Binaryen `55` hits / `0` misses; Binaryen failures `1` hit / `0` misses

Command failure classification: known **tool/Binaryen failure** (`binaryen-rec-group-zero`) from the cached failure lane.

Agent mismatch classification: the `28` raw mismatches are the known **Starshine-win** constant-if and redundant-sign-extension output-shape families from earlier OI slices, not new `ref.as_non_null` semantic failures. Grepping final failure artifacts for `ref.as_non_null`, `ref.cast`, `ref.test`, `ref.eq`, and `ref.is_null` found no occurrences.

## Remaining OI-I work

`[O4Z-AUDIT-OI-I]` remains open. This slice only adds first `ref.as_non_null` null/known-`i31` cleanup and the exact `ref.cast(unreachable)` validity repair needed by that rewrite. Remaining useful sub-slices include impossible equality/non-null proofs, broader known-non-null `ref.is_null` and `ref.as_non_null` cases, locally representable `ref.test` / `ref.cast` success and failure cases, broader unreachable/drop-child preservation, and default-mode trap/effect negatives. Descriptor, exactness, TNH, and IIT behavior should stay in `[O4Z-AUDIT-OI-J]` unless a future slice explicitly widens the local mode/metadata support.
