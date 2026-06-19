# Optimize-instructions OI-D default scalar audit

Date: 2026-06-19

## Question

`[O4Z-AUDIT-OI-D]` asked whether the smallest recurring `optimize-instructions` scalar/default compare gaps from the OI-B/OI-C direct lanes could be closed before moving into local bit-width facts, memory, `call_ref`, and GC/reference work.

The targeted recurring mismatch families were:

- exact integer constant subtraction folding (`i32.sub` / `i64.sub` of constants)
- default floating spelling canonicalization (`f32.sub` / `f64.sub` by constants to add-negative, and divide-by-two to multiply-by-half)
- `i32.wrap_i64` of a constant
- safe relational operand canonicalization after the earlier disabled canonicalizer
- safety boundaries for trapping integer operations and local/effect/control-sensitive relational reordering

## Findings

Starshine now covers the OI-B/OI-C default scalar mismatch family that made every generated GenValid case diverge before this slice. The direct compare lane still hits the default failure ceiling, but the remaining raw mismatches are no longer the scalar/default arithmetic spelling family. They are the pre-existing Starshine constant-if folding difference: Starshine folds `if (i32.const 0/1)` forms into the selected body or an empty result, while the Binaryen `optimize-instructions` oracle leaves those generated shapes in `if` form. Agent classification for that remaining family is **Starshine-win** for this slice: the condition is a constant, the selected branch is behavior-preserving, no side-effecting condition is removed, both outputs validate, and sampled canonical wasm outputs are smaller for Starshine.

The relational operand canonicalizer was re-enabled rather than replaced. Focused tests cover the safe positive case where a local-get can cross a call subtree because the crossed operation is the pure local read and the compare opcode is reversed, while existing negative coverage still keeps same-local writes, shared tee payloads, control-bearing tees, and loop-carried tees from being reordered.

A trapping integer division test keeps constant division by zero in binary form. The pass may still canonicalize signed non-negative integer division to unsigned spelling, but it does not fold the trap away.

## Evidence

Commands run during this slice:

1. Red-first focused integer subtraction check before implementation:
   - `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*folds exact integer constant subtraction*'`
   - Failed as intended: expected `i32.const` subtraction to fold to one const.

2. Focused checks after implementation:
   - `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*folds exact integer constant subtraction*'`
   - Passed: `Total tests: 1, passed: 1, failed: 0.`
   - `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*keeps trapping integer divisions*'`
   - Passed: `Total tests: 1, passed: 1, failed: 0.`
   - `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*relational*'`
   - Passed: `Total tests: 6, passed: 6, failed: 0.`
   - `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*default scalar float*'`
   - Passed: `Total tests: 1, passed: 1, failed: 0.`
   - `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*wrap_i64 constants*'`
   - Passed: `Total tests: 1, passed: 1, failed: 0.`
   - `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*optimize-instructions*'`
   - Passed: `Total tests: 92, passed: 92, failed: 0.`

3. Formatting and focused package signoff:
   - `moon fmt`
   - Passed.
   - `moon test src/passes`
   - Passed: `Total tests: 2604, passed: 2604, failed: 0.`

4. Native command build:
   - `moon build --target native --release src/cmd`
   - Passed with existing unused-function warnings in `pass_manager.mbt`.

5. Direct compare lane:
   - `bun scripts/pass-fuzz-compare.ts --pass optimize-instructions --count 10000 --seed 0x5eed --out-dir .tmp/pass-fuzz-optimize-instructions-oi-d-default-scalar-10000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe`
   - Completed to the default failure ceiling: requested `10000`, compared `56/10000`, normalized matches `28`, raw mismatches `28`, validation failures `0`, property failures `0`, generator failures `0`, command failures `1`, jobs `16`.
   - Cache: wasm-smith `29` hits / `0` misses; Binaryen `56` hits / `0` misses; Binaryen failures `1` hit / `0` misses.
   - Command failure classification: `case-000029-wasm-smith` remains the known **tool/Binaryen failure** (`binaryen-rec-group-zero`).
   - Agent mismatch classification: the `28` remaining raw mismatches are **Starshine-win** constant-if folding differences, not the OI-B scalar/default arithmetic spelling gaps. Sampled size checks show smaller Starshine canonical wasm, e.g. `case-000002-gen-valid` Binaryen `4161` bytes vs Starshine `4135` bytes, `case-000004-gen-valid` `5539` vs `5501`, and `case-000006-gen-valid` `5559` vs `5516`.

An earlier direct lane before the float/wrap follow-up (`.tmp/pass-fuzz-optimize-instructions-oi-d-10000`) still showed the old floating sub/div and `i32.wrap_i64` gaps; it is superseded by the `oi-d-default-scalar-10000` lane above.

## Files

- `src/passes/optimize_instructions.mbt`: adds exact wrapping integer subtraction folds, scalar float spelling rewrites, `i32.wrap_i64` constant folding, and re-enables the guarded relational operand canonicalizer.
- `src/passes/optimize_instructions_test.mbt`: adds default scalar fixtures for integer subtraction, float spelling, wrap constants, trapping division preservation, and updates the relational call/local-get fixture to the now-enabled safe canonicalization.
- `agent-todo.md`: marks `[O4Z-AUDIT-OI-D]` complete and advances the active OI slice to `[O4Z-AUDIT-OI-E]`.
- `docs/wiki/binaryen/passes/optimize-instructions/index.md`: records the OI-D outcome and links this note.

## Remaining work

`[O4Z-AUDIT-OI-E]` is next: add a `LocalScanner`-style local bit/sign fact model and the first sign-extension slice. Later OI work remains open for boolean/select shell breadth, memory/bulk-memory, `call_ref`, reference/cast/descriptor/null-trap, GC, tuple/multivalue, repair boundaries, and final direct/O4z closeout.
