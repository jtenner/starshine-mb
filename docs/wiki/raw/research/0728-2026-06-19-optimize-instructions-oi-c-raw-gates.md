# Optimize-instructions OI-C raw gate audit

Date: 2026-06-19

## Question

`[O4Z-AUDIT-OI-C]` asked whether the `optimize-instructions` raw no-op gates in `src/passes/pass_manager.mbt` were hiding required behavior or losing trace accountability. The specific gate families were:

- `large-local-optimize-instructions`
- `large-lowered-optimize-instructions-noop`
- `stack-carried-effect-optimize-instructions-noop`
- `load-call-optimize-instructions-noop`
- `call-local-write-optimize-instructions-noop`
- `structured-call-branch-optimize-instructions-noop`
- `block-return-call-branch-optimize-instructions-noop`
- `loop-branch-local-write-optimize-instructions-noop`

## Findings

All OI raw skip families now have explicit public-pipeline boundary coverage with trace reason assertions in `src/passes/optimize_instructions_test.mbt`.

The audit found one real accountability bug: the three structured performance gates were placed after the broad `calls > 0 && local_writes > 0` gate, while each structured gate also requires calls and local writes. As a result, structured fixtures could only report `call-local-write-optimize-instructions-noop`, making the more precise structured reasons unreachable through the public pipeline. The fix moved the structured and loop-specific guards before the broad load/call and call/local-write guards.

A public-pipeline positive fixture now proves that ordinary `optimize-instructions` cleanup still runs when none of the raw no-op gates applies: a simple neutral `i32.add` by zero is optimized away and no `pass[optimize-instructions]:skip-raw` trace line is emitted.

## Timing / performance note

These OI-C gates remain performance/representation boundaries, not semantic claims of Binaryen parity. They protect Starshine's current HOT lift/lower and effect-ordering implementation from large local-heavy functions, lowered instruction-count blowups, stack-carried values across effect barriers, mixed load/call surfaces, call/local-write effects, and dense structured call/branch meshes. OI-C did not remove those boundaries; it made their public trace reasons precise and test-covered. Future behavior slices should narrow the boundaries only when the underlying transform family is implemented and validated.

No pass-local timing fields were added in this slice. The gates are still documented as release boundaries, and the direct compare smoke is expected to keep reporting the existing OI-B scalar/default parity gaps until `[O4Z-AUDIT-OI-D]` and later behavior slices reduce them.

## Evidence

Commands run during this slice:

1. Red-first focused check before implementation:
   - `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*optimize-instructions skips structured*'`
   - Failed as intended: expected `structured-call-branch-optimize-instructions-noop`, got `call-local-write-optimize-instructions-noop`.

2. Focused skip-family coverage after implementation:
   - `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*optimize-instructions skips*'`
   - Passed: `Total tests: 9, passed: 9, failed: 0.`

3. Focused public positive cleanup:
   - `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*public pipeline still cleans*'`
   - Passed: `Total tests: 1, passed: 1, failed: 0.`

4. Formatting and focused package signoff:
   - `moon fmt`
   - Passed.
   - `moon test src/passes`
   - Passed: `Total tests: 2600, passed: 2600, failed: 0.`

5. Native command build:
   - `moon build --target native --release src/cmd`
   - Passed with existing unused-function warnings.

6. Direct compare smoke:
   - `bun scripts/pass-fuzz-compare.ts --pass optimize-instructions --count 100 --seed 0x5eed --out-dir .tmp/pass-fuzz-optimize-instructions-oi-c-smoke-100 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe`
   - Timed out after 600 seconds before writing `result.json`; artifacts are partial.
   - Follow-up smaller smoke: `bun scripts/pass-fuzz-compare.ts --pass optimize-instructions --count 10 --seed 0x5eed --out-dir .tmp/pass-fuzz-optimize-instructions-oi-c-smoke-10 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe`
   - Completed: compared `10/10`, normalized matches `5`, raw mismatches `5`, validation failures `0`, property failures `0`, generator failures `0`, command failures `0`, jobs `10`, cache wasm-smith `5` hits / `0` misses, Binaryen `10` hits / `0` misses, Binaryen failures `0` hits / `0` misses.
   - Agent classification: the 5 raw mismatches are the same known OI-B `gen_valid` scalar/default canonicalization parity-gap family and are intentionally assigned to `[O4Z-AUDIT-OI-D]`, not OI-C.

## Files

- `src/passes/pass_manager.mbt`: reordered the OI raw skip guards so the structured and loop-specific performance blockers can report their exact trace reasons before the broad call/local-write gate.
- `src/passes/optimize_instructions_test.mbt`: added generated fixtures and public-pipeline tests for the missing OI raw gate families plus the outside-gate neutral-add cleanup fixture.
- `agent-todo.md`: marks `[O4Z-AUDIT-OI-C]` complete and keeps `[O4Z-AUDIT-OI-D]` as the next active OI behavior slice.
- `docs/wiki/binaryen/passes/optimize-instructions/index.md`: records the OI-C outcome and links this note.

## Remaining work

`[O4Z-AUDIT-OI-D]` is next. The OI-B direct lane classified the recurring raw mismatches as scalar/default canonicalization parity gaps, especially integer constant subtraction folding, float sub-to-add-negative spelling, `i32.wrap_i64` constant folding, and divide-by-two spelling. Those gaps are intentionally not closed by OI-C.
