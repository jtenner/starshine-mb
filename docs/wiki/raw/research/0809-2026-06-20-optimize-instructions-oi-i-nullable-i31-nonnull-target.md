# Optimize-instructions OI-I nullable i31 non-null target miss

Date: 2026-06-20

## Summary

Fifty-third `[O4Z-AUDIT-OI-I]` reference sub-slice.

This implementation slice closes a narrow failed `ref.test` / `ref.cast` gap for nullable absolute `i31` locals tested or cast against non-null aggregate targets. The guarded shapes are:

```wat
local.get 0 ;; (ref null i31)
ref.test (ref struct)
;; => i32.const 0

local.get 0 ;; (ref null i31)
ref.cast (ref struct)
;; => unreachable

call $effect
drop
local.get 0 ;; (ref null i31)
ref.test (ref struct)
;; => drop(call $effect); i32.const 0

call $effect
drop
local.get 0 ;; (ref null i31)
ref.cast (ref struct)
;; => drop(call $effect); unreachable
```

The proof is intentionally narrow: null cannot satisfy a non-null target, and any non-null `i31` value cannot be a `struct` or `array`. Starshine already had the effect-preserving replacement machinery for non-null target misses, but its nullable-source helper only recognized absolute `struct` / `array` disjointness. This slice extends that helper to include nullable local `i31` sources against locally-modeled impossible non-null targets.

## Binaryen oracle

Probe file: `.tmp/oi-nullable-i31-nonnull-target-probe.wat`

Command:

```sh
wasm-opt .tmp/oi-nullable-i31-nonnull-target-probe.wat --enable-reference-types --enable-gc -S -O --optimize-instructions -o -
```

Observed output folded pure `ref.test (ref struct)` on `(ref null i31)` to `i32.const 0`, rewrote pure `ref.cast (ref struct)` to `unreachable`, and preserved `drop(call $effect)` before the same folded/trapping results for already-evaluated prefix forms.

## Starshine change

Updated `src/passes/optimize_instructions.mbt`:

- `optimize_instructions_ref_is_null_or_known_miss_for_non_null_target(...)` now treats a local whose declared heap is absolute `i31` as a known miss for targets accepted by the existing `optimize_instructions_ref_i31_cannot_match_target(...)` helper. This preserves the existing non-null-target null rule: nullable source is safe here only because a null source also misses a non-null target.

Added focused direct-core tests in `src/passes/optimize_instructions_test.mbt`:

- `optimize-instructions folds nullable i31 local against non-null aggregate ref.test and ref.cast miss`
- `optimize-instructions preserves effectful prefix for nullable i31 local non-null aggregate ref.test and ref.cast miss`

The tests construct direct modules because nearby typed `ref.test` / `ref.cast` surfaces have used direct-core fixtures when WAT parsing support is uneven. They assert that `ref.test` / `ref.cast` disappear, pure test folds produce `I32(0)`, pure casts become `unreachable`, and effectful-prefix forms keep `call (Func 0)` and `drop` before the folded/trapping suffix.

## TDD evidence

Red-first was captured with:

```sh
moon test --target native src/passes/optimize_instructions_test.mbt --filter '*nullable i31 local*'
```

Before the helper change, both new tests failed because the `ref.test` suffix remained in the optimized bodies. After the helper change, the same focused filter passed `2/2`.

## Focused and broader evidence

- Binaryen oracle:
  - `wasm-opt .tmp/oi-nullable-i31-nonnull-target-probe.wat --enable-reference-types --enable-gc -S -O --optimize-instructions -o -`
  - Folded pure and effect-prefix `(ref null i31)` vs non-null `struct` target miss shapes as expected.
- Focused tests:
  - red-first `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*nullable i31 local*'` failed `0/2` before implementation because `ref.test` remained.
  - final `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*nullable i31 local*'` passed: `Total tests: 2, passed: 2, failed: 0.`
- Broader validation:
  - `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*ref.test and ref.cast*'` passed: `Total tests: 24, passed: 24, failed: 0.`
  - `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*ref*'` passed: `Total tests: 61, passed: 61, failed: 0.`
  - `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*optimize-instructions*'` passed: `Total tests: 191, passed: 191, failed: 0.`
  - `moon fmt` passed.
  - `moon test src/passes` passed: `Total tests: 2721, passed: 2721, failed: 0.`
  - `moon build --target native --release src/cmd` passed with existing unused-function warnings in `src/passes/pass_manager.mbt`.
  - `moon info` passed with existing warnings in `src/validate/gen_valid.mbt` and `src/validate/gen_valid_ssa.mbt`.
- Direct compare smoke:
  - Completed command:
    - `rm -rf .tmp/pass-fuzz-optimize-instructions-oi-i-nullable-i31-nonnull-target-1 && bun scripts/pass-fuzz-compare.ts --pass optimize-instructions --count 1 --seed 0x5eed --out-dir .tmp/pass-fuzz-optimize-instructions-oi-i-nullable-i31-nonnull-target-1 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe`
  - Requested `1`, compared `1/1`.
  - Normalized matches: `0`.
  - Cleanup-normalized matches: `0`.
  - Raw mismatches: `1`.
  - Validation failures: `0`.
  - Property failures: `0`.
  - Generator failures: `0`.
  - Command failures: `0`.
  - Cache: wasm-smith `0` hits / `0` misses; Binaryen `1` hit / `0` misses; Binaryen failures `0` hits / `0` misses.
  - Agent classification: the single raw mismatch is a known scalar/default output-shape family from earlier OI slices, not a new reference semantic failure. Grep of final compare failure artifacts found no `ref.*`, `call_ref`, or `return_call_ref` occurrences.

## Boundaries

This slice does not add:

- nullable-source non-null-target miss reasoning beyond absolute `i31` locals against targets already accepted by `optimize_instructions_ref_i31_cannot_match_target(...)`;
- nullable-source nullable-target failed `i31` reasoning, because null may satisfy nullable targets;
- new `ref.eq` behavior;
- indexed/defined heap subtype or arbitrary subtype-lattice reasoning beyond the existing helper;
- descriptor/exactness/TNH/IIT-sensitive behavior;
- constructor allocation/effect reasoning, local.set-derived flow facts, or non-local SSA;
- default-mode trap/effect negatives.

## Remaining work

`[O4Z-AUDIT-OI-I]` remains active for impossible equality beyond the covered subsets, other definitely successful and failed `ref.test` / `ref.cast` cases beyond the covered constructor/exact-local/local-supertype/nullable-source nullable-target aggregate and i31 subsets, broader failed cast/test cases beyond the now-covered nullable-source non-null-target `i31` miss and aggregate sibling miss subsets, additional unreachable/drop-child and effect preservation outside the covered families, and default-mode trap/effect negatives. `[O4Z-AUDIT-OI-G]`, `[O4Z-AUDIT-OI-H]`, `[O4Z-AUDIT-OI-J]`, and later remain open.
