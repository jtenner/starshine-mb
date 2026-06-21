# Optimize-instructions OI-G stack-carried effectful memory.copy boundary

Date: 2026-06-20

## Summary

Twentieth `[O4Z-AUDIT-OI-G]` memory/load-store sub-slice.

This boundary slice checks whether tiny `memory.copy` lowering should escape Starshine's raw stack-carried-effect gate when the destination and source operands are calls:

```wat
call $dst
call $src
i32.const 1
memory.copy

call $dst
call $src
i32.const 8
memory.copy
```

Binaryen `version_130` `optimize-instructions` lowers those size-1 and size-8 copies to `i32.store8(i32.load8_u(...))` and `i64.store(i64.load(...))`, preserving the `dst` call as the store address and the `src` call as the load address. A red-first positive Starshine test failed because Starshine returned the original function through `stack-carried-effect-optimize-instructions-noop` before the HOT pass could expand the copies.

The landed change is an explicit fail-closed boundary, not an implementation: Starshine intentionally keeps the stack-carried call-result copies unchanged until a localizing/HOT-lowering slice proves the already-evaluated call results can be represented and rewritten without reordering or losing traps/effects.

## Binaryen oracle

Probe file:

- `.tmp/oi-g-effectful-memory-copy-probe.wat`

Command:

```sh
wasm-opt .tmp/oi-g-effectful-memory-copy-probe.wat --enable-bulk-memory --enable-gc --enable-reference-types -S -O --optimize-instructions -o -
```

Observed output:

- size-1 `memory.copy` with `call $dst` / `call $src` operands became `i32.store8` fed by `i32.load8_u`;
- size-8 `memory.copy` with the same effectful operand shape became `i64.store align=1` fed by `i64.load align=1`;
- Binaryen kept the destination call in the store-address position and the source call in the load-address position.

## Starshine change

No optimizer implementation change was made. Added the focused public-pipeline boundary test:

- `optimize-instructions intentionally keeps stack-carried effectful tiny memory.copy`

The test asserts that Starshine traces `pass[optimize-instructions]:skip-raw reason=stack-carried-effect-optimize-instructions-noop` and keeps both `memory.copy` operations. This prevents the audit from silently treating call-operand tiny copy lowering as covered by the existing local/get tiny-copy implementation.

## Evidence

- Binaryen oracle:
  - `wasm-opt .tmp/oi-g-effectful-memory-copy-probe.wat --enable-bulk-memory --enable-gc --enable-reference-types -S -O --optimize-instructions -o -`
  - Lowered size-1 and size-8 effectful-call copies to load/store forms.
- Red-first positive probe:
  - Initial `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*effectful tiny memory.copy*'` failed `0/1` when the test expected Starshine to expand the copies; the output stayed as two `memory.copy` operations because the raw stack-carried-effect gate returned the original function.
- Focused boundary coverage:
  - After converting the expectation to the intentional fail-closed boundary, `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*stack-carried effectful tiny memory.copy*'` passed: `Total tests: 1, passed: 1, failed: 0.`
- Broader validation:
  - `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*memory.copy*'` passed: `Total tests: 6, passed: 6, failed: 0.`
  - `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*memory*'` passed: `Total tests: 24, passed: 24, failed: 0.`
  - `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*optimize-instructions*'` passed: `Total tests: 198, passed: 198, failed: 0.`
  - `moon fmt` passed.
  - `moon test src/passes` passed: `Total tests: 2728, passed: 2728, failed: 0.`
  - `moon build --target native --release src/cmd` passed (`moon: no work to do`).
  - `moon info` passed with existing warnings in `src/validate/gen_valid.mbt` and `src/validate/gen_valid_ssa.mbt`.
  - `git diff --check && git diff --cached --check` passed.
- Direct compare smoke:
  - Completed command:
    - `rm -rf .tmp/pass-fuzz-optimize-instructions-oi-g-effectful-memory-copy-boundary-1 && bun scripts/pass-fuzz-compare.ts --pass optimize-instructions --count 1 --seed 0x5eed --out-dir .tmp/pass-fuzz-optimize-instructions-oi-g-effectful-memory-copy-boundary-1 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe`
  - Requested `1`, compared `1/1`.
  - Normalized matches: `0`.
  - Cleanup/compare-normalized matches: `0`.
  - Raw mismatches: `1`.
  - Validation failures: `0`.
  - Property failures: `0`.
  - Generator failures: `0`.
  - Command failures: `0`.
  - Cache: wasm-smith `0` hits / `0` misses; Binaryen `1` hit / `0` misses; Binaryen failures `0` hits / `0` misses.
  - Agent classification: the single raw mismatch is the known scalar/default output-shape family from earlier OI slices. Grepping the final compare failure artifacts found no `memory.copy`, `memory.fill`, `store8`, `store16`, `store32`, `i32.load8`, or `i64.load` occurrences, so it did not exercise this effectful-memory-copy boundary.

## Boundaries

This slice does not add:

- a localizing lowering for call-result destination/source operands;
- an escape from `stack-carried-effect-optimize-instructions-noop` for tiny `memory.copy`;
- a broader escape from `load-call-optimize-instructions-noop`;
- new `memory.fill` effectful-value lowering; the probed imported-call `memory.fill` size-2/4/8 forms stayed as `memory.fill` in Binaryen `version_130` and remain covered by the existing Starshine effectful-value boundary.

## Remaining work

`[O4Z-AUDIT-OI-G]` remains active for further source-backed `optimizeStoredValue` shapes, useful effect/trap negatives, and any future safe design for escaping raw stack-carried-effect or load-call gates. `[O4Z-AUDIT-OI-H]`, `[O4Z-AUDIT-OI-I]`, `[O4Z-AUDIT-OI-J]`, and later OI slices remain open.
