# Optimize-instructions OI-I i31 ref.eq constants

## Question

Can Starshine safely fold `ref.eq` when both operands are immediate `ref.i31` constructors fed by local `i32.const` payloads?

## Classification

Completed ninth positive `[O4Z-AUDIT-OI-I]` sub-slice.

This slice adds a narrow impossible/successful equality proof for local `ref.i31` constants:

- `ref.eq(ref.i31(i32.const N), ref.i31(i32.const N))` folds to `i32.const 1`; and
- `ref.eq(ref.i31(i32.const A), ref.i31(i32.const B))` folds to `i32.const 0` when `A != B`.

The proof remains intentionally local and value-literal-only. It does not claim nonconstant `ref.i31` equality, arbitrary reference identity reasoning, descriptor/exactness/TNH/IIT-sensitive cast behavior, non-local facts, or equality for GC aggregate and function references.

## Source anchors

- `docs/wiki/raw/binaryen/2026-06-19-optimize-instructions-version-130-source-refresh.md` maps Binaryen reference equality/null/test/cast work under `[O4Z-AUDIT-OI-I]` and the descriptor/exactness/TNH/IIT boundary under `[O4Z-AUDIT-OI-J]`.
- Local Binaryen `version_130` oracle probe:

```sh
cat > .tmp/oi-ref-i31-eq.wat <<'WAT'
(module
  (func (export "same") (result i32)
    i32.const 7
    ref.i31
    i32.const 7
    ref.i31
    ref.eq)
  (func (export "diff") (result i32)
    i32.const 7
    ref.i31
    i32.const 8
    ref.i31
    ref.eq)
)
WAT
wasm-opt .tmp/oi-ref-i31-eq.wat --enable-reference-types --enable-gc -S -O --optimize-instructions -o -
```

The oracle folded `same` to `i32.const 1` and `diff` to `i32.const 0`.

- `src/passes/optimize_instructions.mbt` now recognizes immediate `RefI31` operands whose child is an `i32.const` and folds `RefEq` based on the payload equality.

## Tests

Added focused WAT coverage in `src/passes/optimize_instructions_test.mbt`:

- `optimize-instructions folds equality on local ref.i31 constants`
  - asserts equal local `ref.i31` constants become `I32(1)` with no `ref.eq`; and
  - asserts unequal local `ref.i31` constants become `I32(0)` with no `ref.eq`.

Red-first evidence:

```sh
moon test --target native src/passes/optimize_instructions_test.mbt --filter '*local ref.i31 constants*'
# Before implementation: failed because the new `same` function still contained `ref.eq`.
```

Focused final evidence:

```sh
moon test --target native src/passes/optimize_instructions_test.mbt --filter '*local ref.i31 constants*'
# Total tests: 1, passed: 1, failed: 0.

moon test --target native src/passes/optimize_instructions_test.mbt --filter '*ref*'
# Total tests: 19, passed: 19, failed: 0.

moon test --target native src/passes/optimize_instructions_test.mbt --filter '*optimize-instructions*'
# Total tests: 147, passed: 147, failed: 0.
```

## Broader validation

```sh
moon fmt
# Finished.

moon test src/passes
# Total tests: 2659, passed: 2659, failed: 0.

moon build --target native --release src/cmd
# Finished with existing unused-function warnings in src/passes/pass_manager.mbt.

moon info
# Finished with existing warnings in src/validate/gen_valid.mbt and src/validate/gen_valid_ssa.mbt.

git diff --check
# Passed.
```

## Direct compare evidence

```sh
rm -rf .tmp/pass-fuzz-optimize-instructions-oi-i-i31-eq-10000 && bun scripts/pass-fuzz-compare.ts --pass optimize-instructions --count 10000 --seed 0x5eed --out-dir .tmp/pass-fuzz-optimize-instructions-oi-i-i31-eq-10000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe
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

Agent mismatch classification: the `27` raw mismatches are known **Starshine-win** constant-if and redundant-sign-extension output-shape families from earlier OI slices, not new reference semantic failures. Grepping final failure artifacts for `ref.eq`, `ref.i31`, `ref.test`, `ref.cast`, `ref.is_null`, `ref.as_non_null`, and `ref.func` found no occurrences.

## Remaining OI-I work

`[O4Z-AUDIT-OI-I]` remains open. This slice only adds immediate `ref.i31(i32.const)` equality folding. Remaining useful sub-slices include impossible equality beyond this literal-i31 and the covered null-vs-`ref.i31` subset, broader known `ref.is_null` constants/proofs beyond exact `ref.i31` and `ref.func`, public non-null `ref.test` / `ref.cast` null-operand validation/type-surface coverage, other definitely successful `ref.test` / `ref.cast` cases, broader failed cast/test cases, broader `ref.as_non_null` cases, broader unreachable/drop-child preservation, and default-mode trap/effect negatives. Descriptor, exactness, TNH, and IIT behavior should stay in `[O4Z-AUDIT-OI-J]` unless a future slice explicitly widens the local mode/metadata surface.
