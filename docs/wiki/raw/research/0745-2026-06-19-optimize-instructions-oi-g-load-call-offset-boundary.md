# Optimize-instructions OI-G load-call offset gate boundary

Date: 2026-06-19

## Question

After the memory32 and memory64 constant-pointer static-offset sub-slices, `[O4Z-AUDIT-OI-G]` still asked for an explicit decision on whether any memory/load/call shape should escape the `load-call-optimize-instructions-noop` raw gate. This note covers one narrow source-backed decision: scalar load offset folding in a function that also contains a call.

## Decision

Starshine intentionally does **not** relax `load-call-optimize-instructions-noop` for this sub-slice.

The direct HOT pass can fold constant-pointer static memarg offsets for scalar loads/stores through `optimize_instructions_try_fold_const_memory_access_offset(...)`, and Binaryen `version_130` also folds the load/call fixture used here. However, Starshine's public pipeline keeps mixed plain-load plus call functions behind the existing raw skip until a broader gate escape has a source-backed ownership proof, focused public trace coverage, and evidence that running the whole current HOT `optimize-instructions` pass on that class is safe and worthwhile.

This is a fail-closed boundary, not a Binaryen parity claim. The parity gap remains visible under `[O4Z-AUDIT-OI-G]` as broader load/store canonicalization and raw-gate narrowing work.

## Local coverage

`src/passes/optimize_instructions_test.mbt` now has `optimize-instructions intentionally keeps load-call memory offset folds behind raw gate`.

The fixture imports a call, performs `i32.const 8; i32.load offset=4; drop; call $touch`, and runs the public pass pipeline. It asserts:

- the trace contains `pass[optimize-instructions]:skip-raw reason=load-call-optimize-instructions-noop`;
- the pretty-printed function still contains `i32.const I32(8)`;
- the load still has `offset=U64(4)`;
- the folded `i32.const I32(12)` address is absent.

The comment in the test labels this as an intentional fail-closed OI-G boundary.

## Binaryen oracle check

A local oracle probe with `wasm-opt .tmp/oi-g-load-call-offset-boundary.wat --optimize-instructions -S --print | grep -E 'i32\\.const|i32\\.load|call'` showed Binaryen folds the same fixture to `i32.const 12` feeding `i32.load` before the call. That confirms the public-pipeline Starshine behavior is a deliberate raw-gate boundary rather than upstream parity.

## Evidence

Commands run for this slice:

1. Boundary test:
   - `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*load-call*'`
   - Passed: `Total tests: 1, passed: 1, failed: 0.`

2. Binaryen oracle probe:
   - Wrote `.tmp/oi-g-load-call-offset-boundary.wat` with the mixed load/call fixture.
   - `wasm-opt .tmp/oi-g-load-call-offset-boundary.wat --optimize-instructions -S --print | grep -E 'i32\\.const|i32\\.load|call'`
   - Confirmed Binaryen rewrites the static offset into `i32.const 12` and keeps the call.

3. Focused skip-family coverage:
   - `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*skips*'`
   - Passed: `Total tests: 9, passed: 9, failed: 0.`

4. Focused optimize-instructions coverage:
   - `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*optimize-instructions*'`
   - Passed: `Total tests: 126, passed: 126, failed: 0.`

5. Formatting and pass package validation:
   - `moon fmt`
   - Passed.
   - `moon test src/passes`
   - Passed: `Total tests: 2638, passed: 2638, failed: 0.`

6. Native command build and package graph check:
   - `moon build --target native --release src/cmd`
   - Passed with no work needed.
   - `moon info`
   - Passed with existing warnings in `src/validate/gen_valid.mbt` and `src/validate/gen_valid_ssa.mbt`.

7. Direct compare lane:
   - `bun scripts/pass-fuzz-compare.ts --pass optimize-instructions --count 10000 --seed 0x5eed --out-dir .tmp/pass-fuzz-optimize-instructions-oi-g-load-call-offset-boundary-10000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe`
   - Completed to the default failure ceiling: requested `10000`, compared `56/10000`, normalized matches `28`, compare-normalized matches `0`, raw mismatches `28`, validation failures `0`, property failures `0`, generator failures `0`, command failures `1`, jobs `16`.
   - Cache: wasm-smith `29` hits / `0` misses; Binaryen `56` hits / `0` misses; Binaryen failures `1` hit / `0` misses.
   - Command failure classification: known **tool/Binaryen failure** (`binaryen-rec-group-zero`).
   - Agent mismatch classification: the `28` raw mismatches are known **Starshine-win** constant-if and redundant-sign-extension output-shape families from earlier OI slices, not new load-call/offset semantic failures. A grep of failure artifacts found no `load-call`, `i32.load offset`, `i64.load offset`, `i32.store offset`, or `i64.store offset` occurrences.

## Remaining OI-G work

`[O4Z-AUDIT-OI-G]` remains open. This boundary slice only decides that the existing load/call raw gate should not be relaxed for constant-pointer static-offset folding today. Remaining work includes broader load/store canonicalization, any further proof-backed `optimizeStoredValue` shapes, useful additional effect/trap negatives, and zero-size bulk-memory cleanup only if Starshine gains local ignore-traps/TNH/IIT-equivalent support.
