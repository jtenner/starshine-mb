# Optimize-instructions OI-I non-null local ref.test/ref.cast basics

## Question

Can Starshine reuse declared non-null local reference types to fold definitely-successful `ref.test` and `ref.cast` when the cast/test target is exactly the local's heap type?

## Classification

Completed eleventh positive `[O4Z-AUDIT-OI-I]` sub-slice.

This slice broadens the successful `ref.test` / `ref.cast` proof from immediate local constructors to `local.get` operands whose declared local type is a non-null reference with the same heap type as the target. It now covers:

- `ref.test (ref T) (local.get $x)` to `i32.const 1` when `$x : (ref T)`; and
- `ref.cast (ref T) (local.get $x)` to the original `local.get` when `$x : (ref T)`.

The proof remains deliberately narrow. It only trusts declared local type metadata and exact heap-type equality. It does not infer through nullable locals, `local.set` value flow, arbitrary subtype lattice facts, indexed/recursive type relationships, descriptor/exactness/TNH/IIT modes, failed cast/test behavior, or GC aggregate identity.

## Source anchors

- `docs/wiki/raw/binaryen/2026-06-19-optimize-instructions-version-130-source-refresh.md` maps Binaryen reference equality/null/test/cast work under `[O4Z-AUDIT-OI-I]` and descriptor/exactness/TNH/IIT behavior under `[O4Z-AUDIT-OI-J]`.
- Local Binaryen `version_130` oracle probe:

```sh
cat > .tmp/oi-nonnull-local-ref-test-cast.wat <<'WAT'
(module
  (func $test_eq (export "test_eq") (param $x (ref eq)) (result i32)
    (ref.test (ref eq) (local.get $x))
  )
  (func $cast_eq (export "cast_eq") (param $x (ref eq)) (result (ref eq))
    (ref.cast (ref eq) (local.get $x))
  )
)
WAT
wasm-opt .tmp/oi-nonnull-local-ref-test-cast.wat --enable-reference-types --enable-gc -S -O --optimize-instructions -o -
```

The oracle folded the non-null local `ref.test` to `i32.const 1` and removed the exact `ref.cast`, returning the local directly.

- `src/passes/optimize_instructions.mbt` now has `optimize_instructions_ref_is_known_match_for_target(...)` inspect `LocalGet` operands via `@ir.hot_local_type(...)`; it accepts only non-null `RefType` locals whose heap type equals the cast/test target.

## Tests

Added focused direct-core coverage in `src/passes/optimize_instructions_test.mbt`:

- `optimize-instructions folds successful ref.test and ref.cast on non-null local refs`
  - asserts exact non-null local `ref.test` becomes `I32(1)`; and
  - asserts exact non-null local `ref.cast` is removed while preserving `local.get`.

The fixture uses direct core builders because the current Starshine WAT parser rejected the attempted text `ref.test (ref eq)` form before optimizer execution.

Red-first evidence:

```sh
moon test --target native src/passes/optimize_instructions_test.mbt --filter '*non-null local refs*'
# Before implementation: failed because the new exact non-null local ref.test still remained as `ref.test`.
```

Focused final evidence:

```sh
moon test --target native src/passes/optimize_instructions_test.mbt --filter '*non-null local refs*'
# Total tests: 2, passed: 2, failed: 0.

moon test --target native src/passes/optimize_instructions_test.mbt --filter '*ref*'
# Total tests: 21, passed: 21, failed: 0.

moon test --target native src/passes/optimize_instructions_test.mbt --filter '*optimize-instructions*'
# Total tests: 149, passed: 149, failed: 0.
```

## Broader validation

```sh
moon fmt
# Finished.

moon test src/passes
# Total tests: 2661, passed: 2661, failed: 0.

moon build --target native --release src/cmd
# Finished with existing unused-function warnings in src/passes/pass_manager.mbt.

moon info
# Finished with existing warnings in src/validate/gen_valid.mbt and src/validate/gen_valid_ssa.mbt.

git diff --check
# Passed.
```

## Direct compare evidence

The first direct compare attempt with the same command timed out at the harness timeout before writing `result.json`; no final result was recorded from that attempt. The rerun completed:

```sh
rm -rf .tmp/pass-fuzz-optimize-instructions-oi-i-nonnull-local-test-cast-10000-rerun && bun scripts/pass-fuzz-compare.ts --pass optimize-instructions --count 10000 --seed 0x5eed --out-dir .tmp/pass-fuzz-optimize-instructions-oi-i-nonnull-local-test-cast-10000-rerun --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe
```

Result:

- requested: `10000`
- compared: `55/10000`
- normalized matches: `27`
- cleanup-normalized matches: `0`
- compare-normalized matches: `0`
- raw mismatches: `28`
- validation failures: `0`
- property failures: `0`
- generator failures: `0`
- command failures: `1`
- command failure class: `binaryen-rec-group-zero`
- jobs: `16`
- cache: wasm-smith `28` hits / `0` misses; Binaryen `55` hits / `0` misses; Binaryen failures `1` hit / `0` misses

Command failure classification: known **tool/Binaryen failure** (`binaryen-rec-group-zero`) from the cached failure lane.

Agent mismatch classification: the `28` raw mismatches are known **Starshine-win** constant-if and redundant-sign-extension output-shape families from earlier OI slices, not new reference semantic failures. Grepping final failure artifacts for `ref.eq`, `ref.i31`, `ref.test`, `ref.cast`, `ref.is_null`, `ref.as_non_null`, and `ref.func` found no occurrences.

## Remaining OI-I work

`[O4Z-AUDIT-OI-I]` remains open. This slice only adds exact declared non-null `local.get` proofs for successful `ref.test` / `ref.cast` when the local heap type equals the target heap type. Remaining useful sub-slices include impossible equality beyond the covered null-vs-known-non-null and literal-i31 subsets, public non-null `ref.test` / `ref.cast` null-operand validation/type-surface coverage, additional definitely-successful `ref.test` / `ref.cast` cases, broader failed cast/test cases, broader unreachable/drop-child preservation, and default-mode trap/effect negatives. Descriptor, exactness, TNH, and IIT behavior should stay in `[O4Z-AUDIT-OI-J]` unless a future slice explicitly widens the local mode/metadata surface.
