# Optimize-instructions OI-I effectful ref.as_non_null coverage

Date: 2026-06-20

## Summary

Thirty-sixth `[O4Z-AUDIT-OI-I]` reference sub-slice.

This coverage slice locks the existing effect-preserving `ref.as_non_null` cleanup for a locally known-non-null immediate `ref.i31(...)` operand whose payload is effectful. The already-implemented rewrite removes the redundant non-null assertion while keeping the original `ref.i31(call $effect)` value, so the imported call remains evaluated exactly once.

The locked shape is:

```wat
call $effect
ref.i31
ref.as_non_null
;; => ref.i31(call $effect)
```

## Binaryen oracle

Probe file: `.tmp/oi-effectful-ref-as-non-null-i31-probe.wat`

Command:

```sh
wasm-opt .tmp/oi-effectful-ref-as-non-null-i31-probe.wat --enable-reference-types --enable-gc -S -O --optimize-instructions -o -
```

Observed output removed `ref.as_non_null` and preserved the imported call as the payload of `ref.i31`.

## Starshine change

No optimizer implementation change was needed. `src/passes/optimize_instructions.mbt` already rewrites `ref.as_non_null` around locally known-non-null operands by replacing the assertion with its operand, which preserves an effectful immediate `ref.i31(call $effect)` child.

The new `src/passes/optimize_instructions_test.mbt` WAT fixture locks that behavior through the public `optimize-instructions` pipeline by asserting:

- `ref.as_non_null` is removed;
- `call (Func 0)` remains;
- `ref.i31` remains.

## TDD / coverage note

Red-first does not apply because this was a coverage/type-surface audit of behavior already implemented by the earlier `ref.as_non_null` known-non-null helper. The slice's purpose is to keep this effect-preservation surface from regressing while narrowing the remaining OI-I effect-preservation backlog.

Focused command:

```sh
moon test --target native src/passes/optimize_instructions_test.mbt --filter '*ref.as_non_null*'
```

Result: `Total tests: 4, passed: 4, failed: 0.`

## Focused and broader evidence

- Focused `*ref*` test:
  - `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*ref*'`
  - Passed: `Total tests: 43, passed: 43, failed: 0.`
- Focused `*optimize-instructions*` test:
  - `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*optimize-instructions*'`
  - Passed: `Total tests: 173, passed: 173, failed: 0.`
- Broader validation:
  - `moon fmt` passed.
  - `moon test src/passes` passed: `Total tests: 2697, passed: 2697, failed: 0.`
  - `moon build --target native --release src/cmd` passed.
  - `moon info` passed with existing warnings in `src/validate/gen_valid.mbt` and `src/validate/gen_valid_ssa.mbt`.
  - `git diff --check` passed.
- Direct compare smoke:
  - Completed command:
    - `rm -rf .tmp/pass-fuzz-optimize-instructions-oi-i-effectful-ref-as-non-null-1 && bun scripts/pass-fuzz-compare.ts --pass optimize-instructions --count 1 --seed 0x5eed --out-dir .tmp/pass-fuzz-optimize-instructions-oi-i-effectful-ref-as-non-null-1 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe`
  - Requested `1`, compared `1/1`.
  - Normalized matches: `0`.
  - Cleanup-normalized matches: `0`.
  - Raw mismatches: `1`.
  - Validation failures: `0`.
  - Property failures: `0`.
  - Generator failures: `0`.
  - Command failures: `0`.
  - Cache: wasm-smith `0` hits / `0` misses; Binaryen `1` hit / `0` misses; Binaryen failures `0` hits / `0` misses.
  - Agent classification: the single raw mismatch is a known scalar/default output-shape family from earlier OI slices, not a new reference semantic failure. Grep of final compare artifacts found no `ref.*`, `call_ref`, or `return_call_ref` occurrences.

## Boundaries

This slice does not add:

- new `ref.as_non_null` proofs beyond locally known-non-null immediate `ref.i31`, direct `ref.func`, declared non-null locals, and already-covered null/trap surfaces;
- arbitrary flow-sensitive nullable-local facts;
- descriptor/exactness/TNH/IIT-sensitive cast behavior;
- constructor allocation or aggregate type reasoning;
- effect preservation for other reference folds outside the now-covered immediate-`ref.i31` `ref.as_non_null` surface.

## Remaining work

`[O4Z-AUDIT-OI-I]` remains active for impossible equality beyond the covered subsets, broader definitely-successful and definitely-failed `ref.test` / `ref.cast` proofs, additional unreachable/drop-child and effect preservation outside the covered immediate-`ref.i31` known-miss, null-equality, `ref.is_null`, successful `ref.test`, represented impossible `ref.eq`, and `ref.as_non_null` paths, and default-mode trap/effect negatives. `[O4Z-AUDIT-OI-J]` and later remain open.
