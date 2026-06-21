# Optimize-instructions OI-G superset narrow-store masks

Date: 2026-06-20

## Summary

Twenty-second `[O4Z-AUDIT-OI-G]` memory/load-store sub-slice.

This coverage/classification slice locks Starshine's existing narrow-store mask cleanup for masks that preserve at least all bits observed by the store, even when the mask also preserves additional higher bits:

```wat
local.get $ptr
local.get $value
i32.const 511
i32.and
i32.store8
```

For a narrow store, the extra preserved high bits cannot affect the bytes written by the store. Starshine therefore drops these superset masks as a size/output-shape win, extending the already documented exact i32 mask cleanup and the earlier i64 Starshine-win cleanup.

## Binaryen oracle

Probe file: `.tmp/oi-g-wide-mask-narrow-store-probe.wat`

Command:

```sh
wasm-opt .tmp/oi-g-wide-mask-narrow-store-probe.wat -S -O --optimize-instructions -o -
```

Observed Binaryen `version_130` behavior:

- kept `i32.and 511` before `i32.store8`;
- kept `i32.and 131071` before `i32.store16`;
- kept `i64.and 511` before `i64.store8`;
- kept `i64.and 131071` before `i64.store16`;
- kept `i64.and 8589934591` before `i64.store32`.

Control probe file: `.tmp/oi-g-exact-mask-narrow-store-probe.wat`

Command:

```sh
wasm-opt .tmp/oi-g-exact-mask-narrow-store-probe.wat -S -O --optimize-instructions -o -
```

The control probe confirmed Binaryen still drops the exact i32 low-bit masks (`255` before `i32.store8`, `65535` before `i32.store16`) but keeps the exact i64 masks (`255`, `65535`, `4294967295`) before `i64.store8` / `i64.store16` / `i64.store32`, consistent with the earlier `0741` and `0742` notes.

## Starshine change

No optimizer implementation change was required. Added the focused public-pipeline coverage test:

- `optimize-instructions drops superset low-bit masks before narrow stores`

The test covers non-commuted superset masks for:

- `i32.store8` with `i32.and 511`;
- `i32.store16` with `i32.and 131071`;
- `i64.store8` with `i64.and 511`;
- `i64.store16` with `i64.and 131071`;
- `i64.store32` with `i64.and 8589934591`.

It asserts that Starshine removes the `and` operators and preserves the original address/value operands before the narrow stores.

## Why this is intentionally not a parity gap

Binaryen's output is larger for the probed superset masks, but the store semantics observe only the low 8/16/32 bits selected by the store opcode. A mask that preserves all of those low bits cannot change the memory write even if it also preserves additional high bits that the store discards. Starshine's existing helper checks exactly that low-bit preservation condition, and the value-changing mask negatives continue to protect masks that clear any written low bit.

This is therefore recorded as a narrow Starshine-win output-shape divergence rather than an implementation gap to align away. It remains limited to direct `and` operands of narrow stores; it does not add recursive `maxBits` scanning or any new effectful/localizing rewrite.

## Evidence

- Binaryen oracle:
  - `wasm-opt .tmp/oi-g-wide-mask-narrow-store-probe.wat -S -O --optimize-instructions -o -`
  - Kept all probed superset masks listed above.
  - `wasm-opt .tmp/oi-g-exact-mask-narrow-store-probe.wat -S -O --optimize-instructions -o -`
  - Dropped the exact i32 masks but kept the exact i64 masks, matching the older OI-G classifications.
- Focused coverage:
  - `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*superset low-bit masks*'` passed immediately: `Total tests: 1, passed: 1, failed: 0.`
  - Red-first positive implementation evidence does not apply because this slice covers an already-implemented Starshine-win generalization and documents the Binaryen output-shape divergence.
- Broader validation:
  - `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*narrow stores*'` passed: `Total tests: 8, passed: 8, failed: 0.`
  - `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*optimize-instructions*'` passed: `Total tests: 204, passed: 204, failed: 0.`
  - `moon fmt` passed.
  - `moon test src/passes` passed: `Total tests: 2734, passed: 2734, failed: 0.`
  - `moon build --target native --release src/cmd` passed (`moon: no work to do`).
  - `moon info` passed with existing warnings in `src/validate/gen_valid.mbt` and `src/validate/gen_valid_ssa.mbt`.
  - `git diff --check && git diff --cached --check` passed.
- Direct compare smoke:
  - `rm -rf .tmp/pass-fuzz-optimize-instructions-oi-g-superset-store-mask-1 && bun scripts/pass-fuzz-compare.ts --pass optimize-instructions --count 1 --seed 0x5eed --out-dir .tmp/pass-fuzz-optimize-instructions-oi-g-superset-store-mask-1 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe`
  - Requested `1`, compared `1/1`.
  - Normalized matches: `0`.
  - Cleanup/compare-normalized matches: `0`.
  - Raw mismatches: `1`.
  - Validation failures: `0`.
  - Property failures: `0`.
  - Generator failures: `0`.
  - Command failures: `0`.
  - Cache: wasm-smith `0` hits / `0` misses; Binaryen `1` hit / `0` misses; Binaryen failures `0` hits / `0` misses.
  - Agent classification: the single raw mismatch is not this slice. Grep of final compare failure artifacts found no `store8`, `store16`, `store32`, `memory.copy`, or `memory.fill` occurrences; it only found unrelated scalar `and` operators in the input and both outputs.

## Boundaries

This slice does not add:

- recursive `maxBits` scanner behavior beyond direct `and` masks;
- sign-extension removal before narrow stores;
- signed-load to unsigned-load canonicalization before narrow stores;
- pointer-offset folding changes;
- any stack-carried effect or load/call raw-gate escape.

## Remaining work

`[O4Z-AUDIT-OI-G]` remains active for source-backed memory/load/store canonicalization beyond the covered bulk-memory, memory64, constant offset, direct stored-value mask/truncation, and documented boundary subsets. `[O4Z-AUDIT-OI-H]`, `[O4Z-AUDIT-OI-I]`, `[O4Z-AUDIT-OI-J]`, `[O4Z-AUDIT-OI-K]`, and later remain open.
