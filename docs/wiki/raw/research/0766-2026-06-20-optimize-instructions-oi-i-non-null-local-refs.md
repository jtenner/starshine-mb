# Optimize-instructions OI-I non-null local reference basics

## Question

Can Starshine reuse function-local type metadata to fold reference null checks when a `local.get` is statically non-null?

## Classification

Completed tenth positive `[O4Z-AUDIT-OI-I]` sub-slice.

This slice broadens the existing local known-non-null proof from immediate constructors to `local.get` operands whose declared local type is a non-null reference. It now covers:

- `ref.is_null(local.get $x)` to `i32.const 0` when `$x : (ref T)`;
- `ref.as_non_null(local.get $x)` to the original `local.get` when `$x : (ref T)`; and
- `ref.eq(local.get $x, ref.null T)` to `i32.const 0` through the existing null-equality path when `$x : (ref T)`.

The proof is intentionally narrow. It only trusts the local's declared non-null `RefType`; it does not infer non-nullness through nullable locals, SSA definitions, `local.set` value flow, descriptor/exactness/TNH/IIT-sensitive casts, arbitrary successful `ref.test` / `ref.cast`, or GC aggregate identity reasoning.

## Source anchors

- `docs/wiki/raw/binaryen/2026-06-19-optimize-instructions-version-130-source-refresh.md` maps Binaryen reference equality/null/test/cast work under `[O4Z-AUDIT-OI-I]` and descriptor/exactness/TNH/IIT behavior under `[O4Z-AUDIT-OI-J]`.
- Local Binaryen `version_130` oracle probe:

```sh
cat > .tmp/oi-nonnull-local-ref-basics.wat <<'WAT'
(module
  (func (export "is-null-eq") (param (ref eq)) (result i32)
    local.get 0
    ref.is_null)
  (func (export "as-non-null-eq") (param (ref eq)) (result (ref eq))
    local.get 0
    ref.as_non_null)
  (func (export "eq-null") (param (ref eq)) (result i32)
    local.get 0
    ref.null eq
    ref.eq)
)
WAT
wasm-opt .tmp/oi-nonnull-local-ref-basics.wat --enable-reference-types --enable-gc -S -O --optimize-instructions -o -
```

The oracle folded the non-null local `ref.is_null` to `i32.const 0`, removed `ref.as_non_null`, and made the null equality path equivalent to the same `i32.const 0` result.

- `src/passes/optimize_instructions.mbt` now has `optimize_instructions_ref_is_known_non_null(...)` inspect `LocalGet` operands via `@ir.hot_local_type(...)` and `RefType::is_non_nullable()`.

## Tests

Added focused WAT coverage in `src/passes/optimize_instructions_test.mbt`:

- `optimize-instructions folds reference checks on non-null local refs`
  - asserts non-null local `ref.is_null` becomes `I32(0)`;
  - asserts non-null local `ref.as_non_null` is removed while preserving `local.get`; and
  - asserts non-null local equality against `ref.null eq` removes `ref.eq` and becomes `I32(0)`.

Red-first evidence:

```sh
moon test --target native src/passes/optimize_instructions_test.mbt --filter '*non-null local ref*'
# Before implementation: failed because the new `is-null` function still contained the unfurled reference-null check.
```

Focused final evidence:

```sh
moon test --target native src/passes/optimize_instructions_test.mbt --filter '*non-null local ref*'
# Total tests: 1, passed: 1, failed: 0.

moon test --target native src/passes/optimize_instructions_test.mbt --filter '*ref*'
# Total tests: 20, passed: 20, failed: 0.

moon test --target native src/passes/optimize_instructions_test.mbt --filter '*optimize-instructions*'
# Total tests: 148, passed: 148, failed: 0.
```

## Broader validation

```sh
moon fmt
# Finished.

moon test src/passes
# Total tests: 2660, passed: 2660, failed: 0.

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
rm -rf .tmp/pass-fuzz-optimize-instructions-oi-i-nonnull-local-10000 && bun scripts/pass-fuzz-compare.ts --pass optimize-instructions --count 10000 --seed 0x5eed --out-dir .tmp/pass-fuzz-optimize-instructions-oi-i-nonnull-local-10000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe
```

Result:

- requested: `10000`
- compared: `52/10000`
- normalized matches: `26`
- cleanup-normalized matches: `0`
- compare-normalized matches: `0`
- raw mismatches: `26`
- validation failures: `0`
- property failures: `0`
- generator failures: `0`
- command failures: `1`
- command failure class: `binaryen-rec-group-zero`
- jobs: `16`
- cache: wasm-smith `27` hits / `0` misses; Binaryen `52` hits / `0` misses; Binaryen failures `1` hit / `0` misses

Command failure classification: known **tool/Binaryen failure** (`binaryen-rec-group-zero`) from the cached failure lane.

Agent mismatch classification: the `26` raw mismatches are known **Starshine-win** constant-if and redundant-sign-extension output-shape families from earlier OI slices, not new reference semantic failures. Grepping final failure artifacts for `ref.eq`, `ref.i31`, `ref.test`, `ref.cast`, `ref.is_null`, `ref.as_non_null`, and `ref.func` found no occurrences.

## Remaining OI-I work

`[O4Z-AUDIT-OI-I]` remains open. This slice only adds declared non-null `local.get` proofs for `ref.is_null`, `ref.as_non_null`, and null equality. Remaining useful sub-slices include impossible equality beyond the covered null-vs-known-non-null and literal-i31 subsets, public non-null `ref.test` / `ref.cast` null-operand validation/type-surface coverage, other definitely successful `ref.test` / `ref.cast` cases, broader failed cast/test cases, broader unreachable/drop-child preservation, and default-mode trap/effect negatives. Descriptor, exactness, TNH, and IIT behavior should stay in `[O4Z-AUDIT-OI-J]` unless a future slice explicitly widens the local mode/metadata surface.
