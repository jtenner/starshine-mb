# Optimize-instructions OI-G signed-load narrow-store boundary

Date: 2026-06-20

## Summary

Twenty-first `[O4Z-AUDIT-OI-G]` memory/load-store boundary sub-slice.

This boundary slice classifies signed loads that feed same-width narrow stores:

```wat
local.get $dst
local.get $src
i32.load8_s
i32.store8
```

Binaryen `version_130` keeps the signed-load spelling before the narrow store for the probed `i32` and `i64` store widths. Starshine already keeps those forms too, so this is not an implementation gap and should not be counted as an `optimizeStoredValue` cleanup miss unless future Binaryen source/oracle evidence changes.

## Binaryen oracle

Probe file: `.tmp/oi-g-load-store-value-probe.wat`

Command:

```sh
wasm-opt .tmp/oi-g-load-store-value-probe.wat --enable-bulk-memory --enable-gc --enable-reference-types -S -O --optimize-instructions -o -
```

Observed output kept all signed loads before their matching narrow stores:

- `i32.load8_s` before `i32.store8`;
- `i32.load16_s` before `i32.store16`;
- `i64.load8_s` before `i64.store8`;
- `i64.load16_s` before `i64.store16`;
- `i64.load32_s` before `i64.store32`.

Binaryen did not rewrite these to unsigned loads and did not remove the load sign-extension spelling in this exact stored-value context.

## Starshine change

No optimizer implementation change was required. Added the focused public-pipeline boundary test:

- `optimize-instructions intentionally keeps signed loads before narrow stores`

The test locks the same spelling boundary in Starshine by asserting that the optimized output still contains the signed-load instructions and the matching narrow stores.

## Evidence

- Binaryen oracle:
  - `wasm-opt .tmp/oi-g-load-store-value-probe.wat --enable-bulk-memory --enable-gc --enable-reference-types -S -O --optimize-instructions -o -`
  - Kept the signed loads listed above before the matching narrow stores.
- Focused boundary coverage:
  - `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*signed loads before narrow stores*'` passed immediately: `Total tests: 1, passed: 1, failed: 0.`
  - Red-first positive implementation evidence does not apply because Binaryen keeps these shapes and Starshine already matched that boundary.
- Broader validation:
  - `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*narrow stores*'` passed: `Total tests: 7, passed: 7, failed: 0.`
  - `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*memory*'` passed: `Total tests: 24, passed: 24, failed: 0.`
  - `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*optimize-instructions*'` passed: `Total tests: 199, passed: 199, failed: 0.`
  - `moon fmt` passed.
  - `moon test src/passes` passed: `Total tests: 2729, passed: 2729, failed: 0.`
  - `moon build --target native --release src/cmd` passed (`moon: no work to do`).
  - `moon info` passed with existing warnings in `src/validate/gen_valid.mbt` and `src/validate/gen_valid_ssa.mbt`.
  - `git diff --check && git diff --cached --check` passed.
- Direct compare smoke:
  - `rm -rf .tmp/pass-fuzz-optimize-instructions-oi-g-signed-load-store-boundary-1 && bun scripts/pass-fuzz-compare.ts --pass optimize-instructions --count 1 --seed 0x5eed --out-dir .tmp/pass-fuzz-optimize-instructions-oi-g-signed-load-store-boundary-1 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe`
  - Requested `1`, compared `1/1`.
  - Normalized matches: `0`.
  - Cleanup/compare-normalized matches: `0`.
  - Raw mismatches: `1`.
  - Validation failures: `0`.
  - Property failures: `0`.
  - Generator failures: `0`.
  - Command failures: `0`.
  - Cache: wasm-smith `0` hits / `0` misses; Binaryen `1` hit / `0` misses; Binaryen failures `0` hits / `0` misses.
  - Agent classification: the single raw mismatch is the known scalar/default output-shape family from earlier OI slices. Grep of final compare failure artifacts found no `load8`, `load16`, `load32`, `store8`, `store16`, `store32`, `memory.copy`, or `memory.fill` occurrences, so it did not exercise this signed-load/store boundary.

## Boundaries

This slice does not add:

- signed-load to unsigned-load canonicalization before narrow stores;
- any new `optimizeStoredValue` recursive `maxBits` proof;
- sign-extension opcode removal before stores, which remains separately classified by `0815`;
- pointer-offset folding or bulk-memory lowering changes;
- any raw-gate escape for stack-carried effects or load/call mixtures.

## Remaining work

`[O4Z-AUDIT-OI-G]` remains active for Binaryen-owned memory/load/store canonicalization beyond the covered memory.fill/copy, mask, constant truncation, constant offset, pointer-add boundary, sign-extension boundary, effectful-memory-copy boundary, and this signed-load boundary. `[O4Z-AUDIT-OI-H]`, `[O4Z-AUDIT-OI-I]`, `[O4Z-AUDIT-OI-J]`, and later remain open.
