# Optimize-instructions OI-I known-null non-null target prefix

Date: 2026-06-20

## Summary

Fifty-fourth `[O4Z-AUDIT-OI-I]` reference sub-slice.

This coverage slice closes the remaining evidence gap for known-null operands tested or cast against non-null reference targets, including already-evaluated effectful prefixes:

```wat
ref.null struct
ref.test (ref struct)
;; => i32.const 0

ref.null struct
ref.cast (ref struct)
;; => unreachable

call $effect
drop
ref.null struct
ref.test (ref struct)
;; => drop(call $effect); i32.const 0

call $effect
drop
ref.null struct
ref.cast (ref struct)
;; => drop(call $effect); unreachable
```

The proof is narrow and does not require descriptor, exactness, TNH, or IIT facts: null cannot satisfy a non-null target. Starshine already implemented the local transform in `optimize_instructions_try_fold_ref_test_null(...)` and `optimize_instructions_try_fold_ref_cast_null(...)`; this slice adds direct regression coverage and records Binaryen oracle evidence. Red-first does not apply because this is a coverage/type-surface audit slice for behavior that was already present.

## Binaryen oracle

Probe file: `.tmp/oi-known-null-nonnull-target-prefix-probe.wat`

Command:

```sh
wasm-opt .tmp/oi-known-null-nonnull-target-prefix-probe.wat --enable-reference-types --enable-gc -S -O --optimize-instructions -o -
```

Observed output folded pure `ref.test (ref struct)` on `ref.null struct` to `i32.const 0`, rewrote pure `ref.cast (ref struct)` to `unreachable`, and preserved `drop(call $effect)` before the same folded/trapping results for effect-prefix forms.

## Starshine change

No implementation change was required. Added the focused direct-core test:

- `optimize-instructions folds known-null ref.test and ref.cast against non-null target`

The test constructs the typed reference cases directly because nearby typed `ref.test` / `ref.cast` WAT fixtures may hit parser limitations. It asserts that `ref.test` / `ref.cast` are removed, pure `ref.test` becomes `I32(0)`, pure `ref.cast` becomes `unreachable`, and effect-prefix forms preserve `call (Func 0)` plus `drop` before the folded/trapping suffix.

## Evidence

- Binaryen oracle:
  - `wasm-opt .tmp/oi-known-null-nonnull-target-prefix-probe.wat --enable-reference-types --enable-gc -S -O --optimize-instructions -o -`
  - Folded pure and effect-prefix known-null vs non-null `struct` target shapes as expected.
- Focused coverage:
  - `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*known-null ref.test*'` passed immediately: `Total tests: 2, passed: 2, failed: 0.`
  - This immediate pass is expected and documented as coverage-only evidence for already-implemented behavior, not a red-first behavior gap.
- Broader validation:
  - `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*ref.test and ref.cast*'` passed: `Total tests: 25, passed: 25, failed: 0.`
  - `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*ref*'` passed: `Total tests: 62, passed: 62, failed: 0.`
  - `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*optimize-instructions*'` passed: `Total tests: 192, passed: 192, failed: 0.`
  - `moon fmt` passed.
  - `moon test src/passes` passed: `Total tests: 2722, passed: 2722, failed: 0.`
  - `moon build --target native --release src/cmd` passed (`moon: no work to do`).
  - `moon info` passed with existing warnings in `src/validate/gen_valid.mbt` and `src/validate/gen_valid_ssa.mbt`.
  - `git diff --check && git diff --cached --check` passed.
- Direct compare smoke:
  - Completed command:
    - `rm -rf .tmp/pass-fuzz-optimize-instructions-oi-i-known-null-nonnull-target-1 && bun scripts/pass-fuzz-compare.ts --pass optimize-instructions --count 1 --seed 0x5eed --out-dir .tmp/pass-fuzz-optimize-instructions-oi-i-known-null-nonnull-target-1 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe`
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

- new cast/test reasoning for non-null operands;
- nullable-target null casts/tests, where null satisfies the target;
- descriptor, exactness, TNH, or IIT-sensitive behavior;
- arbitrary subtype-lattice reasoning, indexed/defined heap facts, or constructor allocation reasoning;
- default-mode trap/effect negatives beyond the already-evaluated prefix forms covered here.

## Remaining work

`[O4Z-AUDIT-OI-I]` remains active for impossible equality beyond the covered subsets, other definitely successful and failed `ref.test` / `ref.cast` cases beyond the covered constructor/exact-local/local-supertype/nullable-source nullable-target aggregate and i31 subsets, broader failed cast/test cases beyond the known-null and local/immediate subsets, additional unreachable/drop-child and effect preservation outside the covered families, and default-mode trap/effect negatives. `[O4Z-AUDIT-OI-G]`, `[O4Z-AUDIT-OI-H]`, `[O4Z-AUDIT-OI-J]`, and later remain open.
