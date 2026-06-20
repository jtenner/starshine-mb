# Optimize-instructions OI-I ref.as_non_null ref.func proof

## Question

Can Starshine reuse its local known-non-null constructor proof for `ref.as_non_null(ref.func f)` without entering broader cast/test, descriptor, exactness, TNH, or IIT-sensitive reference work?

## Classification

Completed fourth positive `[O4Z-AUDIT-OI-I]` sub-slice.

This slice broadens the previously landed `ref.as_non_null` local-constructor cleanup from exact `ref.i31` to the shared known-non-null proof helper:

- `ref.as_non_null(ref.func f)` now rewrites to `ref.func f`; and
- the existing `ref.as_non_null(ref.i31(x))` rewrite remains covered through the same helper.

The implementation still deliberately limits the proof to pure local constructors already modeled as known non-null (`HotOp::RefFunc` and exact `Instruction::RefI31`). It does not treat `ref.cast`, `ref.test`, descriptor casts, subtype exactness, or arbitrary non-null types as safe `ref.as_non_null` elision proofs; those remain trap/type/mode-sensitive OI-I/OI-J work.

## Source anchors

- `docs/wiki/raw/binaryen/2026-06-19-optimize-instructions-version-130-source-refresh.md` maps Binaryen `visitRefAs(...)`, `skipNonNullCast(...)`, `skipCast(...)`, `visitRefTest(...)`, `visitRefCast(...)`, and the broader cast-check lattice to `[O4Z-AUDIT-OI-I]` / `[O4Z-AUDIT-OI-J]`.
- Local Binaryen `version_130` oracle probe with `wasm-opt --enable-reference-types --enable-gc -S -O --optimize-instructions` showed `(ref.as_non_null (ref.func $callee))` becoming plain `ref.func $callee`.
- `src/passes/optimize_instructions.mbt` now makes `optimize_instructions_try_fold_ref_as_non_null(...)` use `optimize_instructions_ref_is_known_non_null(...)` after the null case, so `ref.i31` and `ref.func` share one local proof boundary.

## Tests

Updated `src/passes/optimize_instructions_test.mbt`:

- `optimize-instructions folds ref.as_non_null on known null and non-null refs`
  - now includes a `ref.func $callee; ref.as_non_null` WAT fixture alongside the existing null and `ref.i31` cases;
  - asserts the optimized function keeps `ref.func` and removes `ref.as_non_null`.

Red-first evidence:

```sh
moon test --target native src/passes/optimize_instructions_test.mbt --filter '*ref.as_non_null*'
# Before implementation: failed the widened existing test. The new func case still contained `ref.func; ref.as_non_null`.
```

Focused final evidence:

```sh
moon test --target native src/passes/optimize_instructions_test.mbt --filter '*ref.as_non_null*'
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

moon build --target native --release src/cmd
# Finished with existing unused-function warnings in src/passes/pass_manager.mbt.

moon info
# Finished with existing warnings in src/validate/gen_valid.mbt and src/validate/gen_valid_ssa.mbt.

git diff --check
# Passed.
```

## Direct compare evidence

Command:

```sh
rm -rf .tmp/pass-fuzz-optimize-instructions-oi-i-ref-as-func-10000 && bun scripts/pass-fuzz-compare.ts --pass optimize-instructions --count 10000 --seed 0x5eed --out-dir .tmp/pass-fuzz-optimize-instructions-oi-i-ref-as-func-10000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe
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

Agent mismatch classification: the `27` raw mismatches are the known **Starshine-win** constant-if and redundant-sign-extension output-shape families from earlier OI slices, not new `ref.as_non_null` semantic failures. Grepping final failure artifacts for `ref.as_non_null`, `ref.func`, `ref.i31`, `ref.is_null`, `ref.eq`, `ref.test`, and `ref.cast` found no occurrences.

## Remaining OI-I work

`[O4Z-AUDIT-OI-I]` remains open. This slice only broadens `ref.as_non_null` elision to the already-supported local `ref.func` known-non-null constructor proof. Remaining useful sub-slices include impossible equality beyond the covered null-vs-`ref.i31` subset, broader known `ref.is_null` constants/proofs beyond exact `ref.i31` and `ref.func`, locally representable `ref.test` / `ref.cast` success and failure cases, broader `ref.as_non_null` cases beyond pure local constructors, broader unreachable/drop-child preservation, and default-mode trap/effect negatives. Descriptor, exactness, TNH, and IIT behavior should stay in `[O4Z-AUDIT-OI-J]` unless a future slice explicitly widens the local mode/metadata surface.
