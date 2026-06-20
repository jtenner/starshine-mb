# Optimize-instructions OI-I ref null basics

## Question

Which first locally representable non-GC reference equality/null rewrites should Starshine add before moving into the broader `ref.test` / `ref.cast` lattice and descriptor/exactness boundaries?

## Classification

Completed first positive `[O4Z-AUDIT-OI-I]` sub-slice.

This slice adds the Binaryen-observed null-reference basics that do not need descriptor metadata, exact type information, trap-relaxed mode, or a broader cast-check lattice:

- `ref.is_null(ref.null T)` folds to `i32.const 1`;
- `ref.eq(x, ref.null eq)` rewrites to `ref.is_null(x)`;
- `ref.eq(ref.null eq, x)` rewrites to `ref.is_null(x)`; and
- `ref.eq(ref.null eq, ref.null eq)` folds to `i32.const 1`.

This is intentionally not a full `[O4Z-AUDIT-OI-I]` closeout. Remaining reference work still includes impossible equality/non-null proofs, `ref.test`, `ref.cast`, `ref.as_non_null`, unreachable/drop-child preservation, and trap/effect negatives. Descriptor/exactness/TNH/IIT-sensitive behavior remains reserved for `[O4Z-AUDIT-OI-J]`.

## Source anchors

- `docs/wiki/raw/binaryen/2026-06-19-optimize-instructions-version-130-source-refresh.md` maps Binaryen `visitRefEq(...)`, `visitRefIsNull(...)`, `visitRefTest(...)`, `visitRefCast(...)`, and `visitRefAs(...)` to `[O4Z-AUDIT-OI-I]` / `[O4Z-AUDIT-OI-J]`.
- Local Binaryen `version_130` oracle probe with `wasm-opt --enable-reference-types --enable-gc -S -O --optimize-instructions` folded `ref.is_null(ref.null eq)` to `i32.const 1`, folded `ref.is_null(ref.i31(...))` to `i32.const 0`, rewrote both `ref.eq` null-operand orders to `ref.is_null(local.get 0)`, and folded `ref.eq(null, null)` to `i32.const 1`.
- `src/passes/optimize_instructions.mbt` now handles the local `HotOp::RefIsNull` null-constant fold and `HotOp::Heap` / exact-`RefEq` null-operand rewrites. The `ref.eq` rewrite builds an exact unary `ref.is_null` node rather than attempting broader type reasoning.
- Starshine validation currently rejects some non-null `ref.is_null` text fixtures because the local typechecker requires a nullable reference operand. This slice therefore covers the local text-representable null fold and leaves known-non-null constants for a later validation/type-surface or direct-core slice.

## Tests

Added two focused tests in `src/passes/optimize_instructions_test.mbt`:

- `optimize-instructions folds ref.is_null on known null refs`
  - WAT fixture with `ref.null func; ref.is_null`;
  - asserts the optimized function no longer contains the null check and returns `I32(1)`.
- `optimize-instructions rewrites ref.eq null comparisons through ref.is_null`
  - WAT fixture with right-null, left-null, and null/null `ref.eq` forms over `eqref`;
  - asserts `ref.eq` is gone from the param comparisons, the operand-preserving unary null check remains, and the null/null form folds to `I32(1)`.

Red-first evidence:

```sh
moon test --target native src/passes/optimize_instructions_test.mbt --filter '*ref*'
# Before implementation: the two new tests failed. The ref.is_null fixture still contained the original null check, and the ref.eq fixture still contained ref.eq.
```

Focused final evidence:

```sh
moon test --target native src/passes/optimize_instructions_test.mbt --filter '*ref*'
# Total tests: 11, passed: 11, failed: 0.

moon test --target native src/passes/optimize_instructions_test.mbt --filter '*optimize-instructions*'
# Total tests: 139, passed: 139, failed: 0.
```

Note: `pretty_print_func(...)` currently renders lowered `RefIsNull` as `ref.null` in this path, so the `ref.eq` test proves the rewrite by checking that `ref.eq` disappears while the local operand and unary reference check spelling remain. The behavior is still encoded/lowered as `Instruction::RefIsNull` by the HOT node.

## Broader validation

```sh
moon fmt
# Finished.

moon test src/passes
# Total tests: 2651, passed: 2651, failed: 0.

moon build --target native --release src/cmd
# Finished with existing unused-function warnings in pass_manager.mbt.

moon info
# Finished with existing warnings in src/validate/gen_valid.mbt and src/validate/gen_valid_ssa.mbt.
```

## Direct compare evidence

The first 10000-case compare attempt timed out before writing `result.json`:

```sh
rm -rf .tmp/pass-fuzz-optimize-instructions-oi-i-ref-null-10000 && bun scripts/pass-fuzz-compare.ts --pass optimize-instructions --count 10000 --seed 0x5eed --out-dir .tmp/pass-fuzz-optimize-instructions-oi-i-ref-null-10000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe
# timed out after 300s; no result.json
```

Rerun command:

```sh
rm -rf .tmp/pass-fuzz-optimize-instructions-oi-i-ref-null-10000-rerun && bun scripts/pass-fuzz-compare.ts --pass optimize-instructions --count 10000 --seed 0x5eed --out-dir .tmp/pass-fuzz-optimize-instructions-oi-i-ref-null-10000-rerun --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe
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

Agent mismatch classification: the `28` raw mismatches are known **Starshine-win** constant-if and redundant-sign-extension output-shape families from earlier OI slices, not new reference-null semantic failures. Grepping final failure artifacts for `ref.eq`, `ref.is_null`, `ref.test`, `ref.cast`, and `ref.as_non_null` found no occurrences.

## Remaining OI-I work

`[O4Z-AUDIT-OI-I]` remains open. This slice only starts the non-GC reference surface with null equality and null-test rewrites. Remaining useful sub-slices include source-backed impossible-equality/non-null proofs, locally representable `ref.test` and `ref.cast` success/failure cases, `ref.as_non_null`, unreachable/drop-child preservation, and default-mode trap/effect negatives. Descriptor, exactness, TNH, and IIT behavior should stay in `[O4Z-AUDIT-OI-J]` unless a future slice explicitly widens the local mode/metadata support.
