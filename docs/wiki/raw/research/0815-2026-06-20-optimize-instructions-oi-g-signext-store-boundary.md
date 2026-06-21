# Optimize-instructions OI-G sign-extension narrow-store boundary

Date: 2026-06-20

## Summary

Nineteenth `[O4Z-AUDIT-OI-G]` memory/load-store sub-slice.

This boundary slice checks whether sign-extension-before-narrow-store spellings are an OI-owned stored-value cleanup gap. The probed forms are:

```wat
local.get $ptr
local.get $value
i32.extend8_s
i32.store8

local.get $ptr
local.get $value
i32.extend16_s
i32.store16

local.get $ptr
local.get $value64
i64.extend16_s
i64.store16
```

Binaryen `version_130` `optimize-instructions` keeps those explicit sign-extension opcodes before the narrow stores. For shift-pair spellings, Binaryen first canonicalizes the shifts to `i32.extend8_s` / `i32.extend16_s`, then still keeps the extension before the store. Starshine already keeps the same explicit extension spellings, so this is not a current OI parity gap and no optimizer implementation change is needed.

Red-first positive implementation does not apply because the oracle-backed decision is fail-closed/boundary coverage: the desired behavior for Starshine is to keep the sign extension just as Binaryen does for these `version_130` shapes.

## Binaryen oracle

Probe files:

- `.tmp/oi-g-store-signext-probe.wat`
- `.tmp/oi-g-store-shift-signext-probe.wat`

Command:

```sh
wasm-opt .tmp/oi-g-store-signext-probe.wat --enable-gc --enable-reference-types -S -O --optimize-instructions -o -
wasm-opt .tmp/oi-g-store-shift-signext-probe.wat --enable-gc --enable-reference-types -S -O --optimize-instructions -o -
```

Observed output:

- explicit `i32.extend8_s` before `i32.store8` stayed as `i32.extend8_s`;
- explicit `i32.extend16_s` before `i32.store16` stayed as `i32.extend16_s`;
- explicit `i64.extend16_s` before `i64.store16` stayed as `i64.extend16_s`;
- shift-pair forms became explicit sign-extension opcodes but were not dropped before the stores;
- the `i32.extend8_s` before `i32.store16` boundary also stayed, as expected because it can change the low 16 stored bits.

## Starshine change

No optimizer implementation change was required. Added the focused public-pipeline boundary test:

- `optimize-instructions intentionally keeps sign extensions before narrow stores`

The test asserts that Starshine keeps `i32.extend8s`, `i32.extend16s`, and `i64.extend16s` before matching narrow stores, matching the Binaryen-observed keep-spelling behavior and preventing future audit slices from counting these exact shapes as an unimplemented OI stored-value cleanup.

## Evidence

- Binaryen oracle:
  - `wasm-opt .tmp/oi-g-store-signext-probe.wat --enable-gc --enable-reference-types -S -O --optimize-instructions -o -`
  - `wasm-opt .tmp/oi-g-store-shift-signext-probe.wat --enable-gc --enable-reference-types -S -O --optimize-instructions -o -`
  - Kept explicit sign-extension opcodes before narrow stores; canonicalized shift-pair sign extensions to extension opcodes but did not drop the resulting extension before the stores.
- Focused boundary coverage:
  - `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*sign extensions before narrow stores*'` passed immediately: `Total tests: 1, passed: 1, failed: 0.`
  - Immediate pass is expected for this boundary-only slice.
- Broader validation:
  - `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*narrow stores*'` passed: `Total tests: 6, passed: 6, failed: 0.`
  - `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*memory*'` passed: `Total tests: 23, passed: 23, failed: 0.`
  - `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*optimize-instructions*'` passed: `Total tests: 197, passed: 197, failed: 0.`
  - `moon fmt` passed.
  - `moon test src/passes` passed: `Total tests: 2727, passed: 2727, failed: 0.`
  - `moon build --target native --release src/cmd` passed (`moon: no work to do`).
  - `moon info` passed with existing warnings in `src/validate/gen_valid.mbt` and `src/validate/gen_valid_ssa.mbt`.
  - `git diff --check && git diff --cached --check` passed.
- Direct compare smoke:
  - Completed command:
    - `rm -rf .tmp/pass-fuzz-optimize-instructions-oi-g-signext-store-boundary-1 && bun scripts/pass-fuzz-compare.ts --pass optimize-instructions --count 1 --seed 0x5eed --out-dir .tmp/pass-fuzz-optimize-instructions-oi-g-signext-store-boundary-1 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe`
  - Requested `1`, compared `1/1`.
  - Normalized matches: `0`.
  - Cleanup/compare-normalized matches: `0`.
  - Raw mismatches: `1`.
  - Validation failures: `0`.
  - Property failures: `0`.
  - Generator failures: `0`.
  - Command failures: `0`.
  - Cache: wasm-smith `0` hits / `0` misses; Binaryen `1` hit / `0` misses; Binaryen failures `0` hits / `0` misses.
  - Agent classification: the single raw mismatch is the known scalar/default output-shape family from earlier OI slices, including Starshine-win constant-if cleanup and redundant constant sign-extension removal in dropped expression positions. Grepping the final compare failure artifacts found no `store8`, `store16`, `store32`, `memory.fill`, or `memory.copy` occurrences, so it did not exercise the narrow-store boundary covered by this slice.

## Boundaries

This slice does not add:

- a new stored-value removal transform for sign-extension opcodes before stores;
- broad `optimizeStoredValue(...)` parity beyond the existing redundant-mask and constant-truncation subsets;
- any zero-size bulk-memory cleanup under trap-relaxed modes;
- any escape from the `load-call-optimize-instructions-noop` raw gate;
- nonconstant pointer-add offset folding, which remains classified by `0749` as not an OI-owned gap unless future Binaryen source/oracle evidence reopens it.

## Remaining work

`[O4Z-AUDIT-OI-G]` remains active for any further source-backed `optimizeStoredValue` shapes, useful effect/trap negatives, and broader source-backed decisions on whether any class of memory/load/store shapes should escape `load-call-optimize-instructions-noop`. `[O4Z-AUDIT-OI-H]`, `[O4Z-AUDIT-OI-I]`, `[O4Z-AUDIT-OI-J]`, and later OI slices remain open.
