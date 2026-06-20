# Optimize-instructions OI-I double no-op cast ref.eq coverage

Date: 2026-06-20

## Slice

Twenty-third `[O4Z-AUDIT-OI-I]` reference sub-slice.

This is a coverage/source-backed audit sub-slice for the existing same-local nullable no-op `ref.cast` equality helper from `0777`. It locks the both-operands variant:

```wat
local.get 0
ref.cast (ref null eq)
local.get 0
ref.cast (ref null eq)
ref.eq
```

Starshine already had the implementation needed to fold this to `i32.const 1`; this slice adds the missing direct-core test surface so future refactoring cannot accidentally keep only the asymmetric one-cast forms.

## Binaryen oracle

Probe file: `.tmp/oi-noop-cast-both-eq-probe.wat`

Command:

```sh
wasm-opt .tmp/oi-noop-cast-both-eq-probe.wat --enable-reference-types --enable-gc -S -O --optimize-instructions -o -
```

Observed output for the exported function was just `i32.const 1`.

## Starshine coverage

Updated `src/passes/optimize_instructions_test.mbt` test `optimize-instructions folds same-local equality through nullable no-op ref.cast` to include a third direct-core function where both operands are immediate nullable no-op `ref.cast(local.get 0)` nodes.

The test requires the optimized third function to contain no `ref.eq` and to contain `I32(1)`.

## TDD note

Red-first does not apply here because this was an evidence/coverage-only sub-slice for behavior already implemented by `optimize_instructions_ref_eq_same_local_operand(...)` in `0777`. The focused test passed immediately after adding the both-cast fixture.

## Boundaries

This slice does not widen the optimizer contract beyond `0777`:

- no non-null cast elision for nullable locals,
- no arbitrary cast skipping,
- no subtype-lattice cast removal,
- no flow-sensitive nullable-local facts,
- no descriptor/exactness/TNH/IIT behavior,
- no arbitrary SSA identity.

The proof remains limited to immediate nullable `ref.cast` nodes whose target heap exactly matches the direct `local.get` local declaration.

## Evidence captured

- `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*nullable no-op ref.cast*'`
  - Passed: `Total tests: 1, passed: 1, failed: 0.`

- `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*ref*'`
  - Passed: `Total tests: 30, passed: 30, failed: 0.`
- `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*optimize-instructions*'`
  - Passed: `Total tests: 160, passed: 160, failed: 0.`
- `moon fmt`
  - Passed.
- `moon test src/passes`
  - Passed: `Total tests: 2672, passed: 2672, failed: 0.`
- `moon build --target native --release src/cmd`
  - Passed with existing pass-manager unused-function warnings.
- `moon info`
  - Passed with existing warnings in `src/validate/gen_valid.mbt` and `src/validate/gen_valid_ssa.mbt`.
- `git diff --check`
  - Passed.
- Direct compare first attempt timed out before final artifacts:
  - `rm -rf .tmp/pass-fuzz-optimize-instructions-oi-i-double-noop-cast-ref-eq-10000 && bun scripts/pass-fuzz-compare.ts --pass optimize-instructions --count 10000 --seed 0x5eed --out-dir .tmp/pass-fuzz-optimize-instructions-oi-i-double-noop-cast-ref-eq-10000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe`
- Direct compare rerun:
  - `rm -rf .tmp/pass-fuzz-optimize-instructions-oi-i-double-noop-cast-ref-eq-10000-rerun && bun scripts/pass-fuzz-compare.ts --pass optimize-instructions --count 10000 --seed 0x5eed --out-dir .tmp/pass-fuzz-optimize-instructions-oi-i-double-noop-cast-ref-eq-10000-rerun --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe`
  - Requested `10000`, compared `54/10000`.
  - Normalized matches: `27`.
  - Cleanup-normalized matches: `0`.
  - Compare-normalized matches: CLI `0`, `result.json` key `null`.
  - Raw mismatches: `27`.
  - Validation/property/generator failures: `0`.
  - Command failures: `1`, classified as the known cached Binaryen/tool `binaryen-rec-group-zero` failure.
  - Cache: wasm-smith `28` hits / `0` misses; Binaryen `54` hits / `0` misses; Binaryen failures `1` hit / `0` misses.
  - Agent classification: the `27` raw mismatches are the known Starshine-win constant-if and redundant-sign-extension output-shape families from earlier OI slices, not new reference semantic failures.
  - Grep of final failure artifacts found no `ref.eq`, `ref.i31`, `ref.test`, `ref.cast`, `ref.is_null`, `ref.as_non_null`, or `ref.func` occurrences.

## Remaining work

`[O4Z-AUDIT-OI-I]` remains active for impossible equality beyond the covered subsets, broader definitely-successful and definitely-failed `ref.test` / `ref.cast` proofs, broader unreachable/drop-child preservation, and default-mode trap/effect negatives. `[O4Z-AUDIT-OI-J]` and later remain open.
