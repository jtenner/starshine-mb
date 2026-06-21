# Optimize-instructions OI-I same-heap non-null ref.cast

Date: 2026-06-20

## Summary

Fifty-sixth `[O4Z-AUDIT-OI-I]` reference sub-slice.

This implementation slice adds the narrow Binaryen `ref.cast` spelling rewrite for an unknown nullable operand whose static heap exactly matches a non-null cast target:

```wat
call $maybe ;; result eqref
ref.cast (ref eq)
;; => ref.as_non_null(call $maybe)
```

The rewrite preserves both the imported call effect and the null trap: it does not remove the check, it only uses the more precise `ref.as_non_null` operator for the exact same-heap nullable-to-non-null case. It deliberately does not rewrite sibling or narrowing casts such as `eqref` to `(ref array)`; those remain `ref.cast` because they perform a real heap check in addition to the non-null check.

## Binaryen oracle

Probe file: `.tmp/oi-i-default-trap-negative-probe.wat`

Command:

```sh
wasm-opt .tmp/oi-i-default-trap-negative-probe.wat --enable-gc --enable-reference-types -S -O --optimize-instructions -o -
```

Observed output:

- `call $maybe; ref.cast (ref eq)` was lowered to `ref.as_non_null(call $maybe)`.
- The exported explicit `ref.as_non_null(call $maybe)` and same-heap cast shared the same optimized body.
- `call $maybe; ref.cast (ref $s)` remained a `ref.cast`, preserving the heap-check boundary for a narrower target.

## Starshine change

Added a conservative HOT helper that reads the operand node result type and only matches:

- `ref.cast` with a non-null target;
- exactly one operand;
- operand result type is a nullable reference;
- operand heap type exactly equals the cast target heap.

When all conditions hold, Starshine rebuilds the node as HOT `Heap` / `ref.as_non_null` with the original result type and child. The existing `ref.null` branch stays earlier than this rewrite, so known-null casts still fold to `unreachable` rather than being converted to an explicit `ref.as_non_null(ref.null)` trap spelling.

Added the focused direct-core test:

- `optimize-instructions lowers non-null same-heap ref.cast to ref.as_non_null`

The test covers the positive same-heap `eqref` to `(ref eq)` case and a boundary `eqref` to `(ref array)` case that must remain `ref.cast`.

## Evidence

- Binaryen oracle:
  - `wasm-opt .tmp/oi-i-default-trap-negative-probe.wat --enable-gc --enable-reference-types -S -O --optimize-instructions -o -`
- Red-first:
  - `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*non-null same-heap ref.cast*'` initially failed `0/1` because the same-heap cast still contained `ref.cast`.
  - A first implementation attempt rewrote known-null casts too early; `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*ref.cast*'` exposed three regressions where known-null non-null-target casts became `ref.as_non_null(ref.null)` instead of `unreachable`. The final implementation keeps the known-null branch first.
- Focused validation after the final implementation:
  - `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*non-null same-heap ref.cast*'` passed: `Total tests: 1, passed: 1, failed: 0.`
  - `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*ref.cast*'` passed: `Total tests: 30, passed: 30, failed: 0.`
  - `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*ref*'` passed: `Total tests: 65, passed: 65, failed: 0.`
  - `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*optimize-instructions*'` passed: `Total tests: 195, passed: 195, failed: 0.`
- Broader validation:
  - `moon fmt` passed.
  - `moon test src/passes` passed: `Total tests: 2725, passed: 2725, failed: 0.`
  - `moon build --target native --release src/cmd` passed with existing unused-function warnings in `src/passes/pass_manager.mbt`.
  - `moon info` passed with existing warnings in `src/validate/gen_valid.mbt` and `src/validate/gen_valid_ssa.mbt`.
  - `git diff --check && git diff --cached --check` passed.
- Direct compare smoke:
  - `rm -rf .tmp/pass-fuzz-optimize-instructions-oi-i-same-heap-ref-cast-1 && bun scripts/pass-fuzz-compare.ts --pass optimize-instructions --count 1 --seed 0x5eed --out-dir .tmp/pass-fuzz-optimize-instructions-oi-i-same-heap-ref-cast-1 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe`
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

- subtype or supertype casts beyond exact static heap equality;
- descriptor, exactness, TNH, or IIT reasoning;
- arbitrary flow-sensitive same-heap facts;
- a rewrite for `eqref` to `(ref array)` / `(ref struct)` / indexed heap targets, which still require a heap check;
- any `ref.test` behavior.

## Remaining work

`[O4Z-AUDIT-OI-I]` remains active for impossible equality beyond the covered subsets, other definitely successful and failed `ref.test` / `ref.cast` cases, broader unreachable/drop-child and effect preservation, and remaining default-mode trap/effect negatives. `[O4Z-AUDIT-OI-G]`, `[O4Z-AUDIT-OI-H]`, `[O4Z-AUDIT-OI-J]`, and later remain open.
