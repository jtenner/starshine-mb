# Optimize-instructions OI-I indexed i31/aggregate ref.eq miss

Date: 2026-06-20

## Summary

Fifty-seventh `[O4Z-AUDIT-OI-I]` reference sub-slice.

This coverage slice locks the indexed/defined heap surface for a narrow disjoint local equality proof:

```wat
(type $s (struct))
(type $a (array i32))

local.get $i31 ;; (ref i31)
local.get $s   ;; (ref $s)
ref.eq
;; => i32.const 0

local.get $a   ;; (ref null $a)
local.get $i31 ;; (ref i31)
ref.eq
;; => i32.const 0

call $effect
local.get $i31
local.get $a ;; (ref $a)
ref.eq
;; => call $effect; i32.const 0
```

Binaryen folds the equality because a definitely non-null `i31` reference cannot equal a struct or array reference, including indexed/defined aggregate heaps. Starshine already had the local proof through `optimize_instructions_ref_cannot_be_i31(...)` and the existing `ref.eq` rewrite path; this slice adds explicit indexed heap coverage and records the oracle evidence. Red-first does not apply because this is a coverage-only audit of already-implemented behavior, not a new behavior gap.

## Binaryen oracle

Probe file: `.tmp/oi-i-indexed-i31-eq-probe.wat`

Command:

```sh
wasm-opt .tmp/oi-i-indexed-i31-eq-probe.wat --enable-gc --enable-reference-types -S -O --optimize-instructions -o -
```

Observed output folded:

- `(ref i31)` vs `(ref $s)` equality to `i32.const 0`;
- nullable `(ref null $a)` vs `(ref i31)` equality to `i32.const 0`;
- effect-prefix `(call $effect; (ref i31) vs (ref $a))` equality to `call $effect; i32.const 0`.

## Starshine change

No optimizer implementation change was required. Added the focused WAT pipeline test:

- `optimize-instructions locks indexed i31 aggregate local ref.eq miss coverage`

The test asserts that each indexed/defined heap equality removes `ref.eq`, yields `I32(0)`, and preserves the imported call plus `drop` in the effect-prefix form.

## Evidence

- Binaryen oracle:
  - `wasm-opt .tmp/oi-i-indexed-i31-eq-probe.wat --enable-gc --enable-reference-types -S -O --optimize-instructions -o -`
  - Folded the pure indexed struct/array equality misses and preserved the effect call before the folded effect-prefix result.
- Focused coverage:
  - `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*indexed i31 aggregate*'` passed immediately: `Total tests: 1, passed: 1, failed: 0.`
  - This immediate pass is expected for a coverage-only audit slice.
- Broader validation:
  - `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*ref.eq*'` passed: `Total tests: 8, passed: 8, failed: 0.`
  - `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*ref*'` passed: `Total tests: 66, passed: 66, failed: 0.`
  - `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*optimize-instructions*'` passed: `Total tests: 196, passed: 196, failed: 0.`
  - `moon fmt` passed.
  - `moon test src/passes` passed: `Total tests: 2726, passed: 2726, failed: 0.`
  - `moon build --target native --release src/cmd` passed (`moon: no work to do`).
  - `moon info` passed with existing warnings in `src/validate/gen_valid.mbt` and `src/validate/gen_valid_ssa.mbt`.
- Direct compare smoke:
  - Completed command:
    - `rm -rf .tmp/pass-fuzz-optimize-instructions-oi-i-indexed-i31-eq-1 && bun scripts/pass-fuzz-compare.ts --pass optimize-instructions --count 1 --seed 0x5eed --out-dir .tmp/pass-fuzz-optimize-instructions-oi-i-indexed-i31-eq-1 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe`
  - Requested `1`, compared `1/1`.
  - Normalized matches: `0`.
  - Cleanup/compare-normalized matches: `0`.
  - Raw mismatches: `1`.
  - Validation failures: `0`.
  - Property failures: `0`.
  - Generator failures: `0`.
  - Command failures: `0`.
  - Cache: wasm-smith `0` hits / `0` misses; Binaryen `1` hit / `0` misses; Binaryen failures `0` hits / `0` misses.
  - Agent classification: the single raw mismatch is a known scalar/default output-shape family from earlier OI slices, not a new reference semantic failure. Grep of final compare failure artifacts found no `ref.*`, `call_ref`, or `return_call_ref` occurrences.

## Boundaries

This slice does not add:

- arbitrary indexed heap-type disjointness beyond the existing narrow `i31` vs non-`i31` local proof;
- constructor allocation identity or allocation-dropping equality folds;
- descriptor, exactness, TNH, or IIT reasoning;
- new `ref.test` / `ref.cast` behavior;
- broader default-mode trap/effect behavior beyond preserving the already-evaluated effect prefix.

## Remaining work

`[O4Z-AUDIT-OI-I]` remains active for impossible equality beyond the covered null-vs-known-non-null, literal-`ref.i31`, same-local identity, same-local `ref.i31(local.get)`, same-local cast/as_non_null, aggregate sibling, i31/struct, i31/array, and this indexed i31/aggregate local subset; additional successful and failed `ref.test` / `ref.cast` cases; broader unreachable/drop-child and effect preservation; and default-mode trap/effect negatives. `[O4Z-AUDIT-OI-G]`, `[O4Z-AUDIT-OI-H]`, `[O4Z-AUDIT-OI-J]`, and later remain open.
