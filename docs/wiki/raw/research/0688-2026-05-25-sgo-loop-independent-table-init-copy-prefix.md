# SGO loop independent table.init/table.copy prefix

## Context

Slice: `[SGO]003C5` loop-specific FlowScanner breadth for `simplify-globals-optimizing`.

Prior loop-prefix slices covered independent constant-operand `global.set`, `local.set`, scalar/table stores, `memory.fill`, `memory.copy`, `memory.init`, and `table.fill` before a yielded candidate `global.get` inside a non-branching value loop. This note extends the same narrow contract to `table.init` and `table.copy`.

## Binaryen probe

Local probes against `wasm-opt --all-features --simplify-globals-optimizing` showed Binaryen turns the candidate global immutable and removes the fake guard traffic for both shapes:

- `const; const; const; table.init <elem>; global.get <candidate>`
- `const; const; const; table.copy <dst> <src>; global.get <candidate>`

The preserved side effect remains in the optimized text, while the `global.get` / `global.set` guard traffic disappears. This matches the already-landed `memory.copy` / `memory.init` / `table.fill` loop-prefix contract.

## Implementation

Changed `src/passes/simplify_globals_optimizing.mbt` so the loop-only independent triple-effect prefix matcher also recognizes:

- `TableInit(_, _)`
- `TableCopy(_, _)`

The matcher still requires all three operands to be exact constants and still only applies when the loop's final yielded value is the single candidate `global.get`. Candidate-derived operands remain conservative because they introduce an extra same-global read / tainted effect operand before the final condition read.

## Tests

Added focused tests in `src/passes/simplify_globals_optimizing_test.mbt`:

- positive `table.init` loop prefix: candidate global becomes immutable, guard traffic is removed, `table.init` is preserved;
- positive `table.copy` loop prefix: candidate global becomes immutable, guard traffic is removed, `table.copy` is preserved;
- negative candidate-derived `table.init` destination operand: candidate global remains mutable and guard traffic remains;
- negative candidate-derived `table.copy` destination operand: candidate global remains mutable and guard traffic remains.

TDD failure was observed before implementation with the two positive tests failing because the candidate global remained mutable. After implementation, `moon test src/passes` passed (`1635/1635`).

## Validation

- `moon test src/passes` passed after implementation: `1635/1635`.
- `moon fmt` passed.
- `moon info` passed with the existing DAE unused-value warnings.
- `moon test` passed: `3711/3711`.
- `bun fuzz compare-pass --count 10000 --seed 0x5eed --pass simplify-globals-optimizing --max-failures 20 --out-dir .tmp/pass-fuzz-sgo-loop-table-init-copy-0688-10000` passed the slice criteria: `6759/10000` compared before the configured 20 command-failure stop, `6759` normalized matches, `0` mismatches, `0` Starshine validation failures, `0` generator failures, and `20` Binaryen/tool command failures. Command failures were the established tool classes: `17` `binaryen-rec-group-zero`, `1` `binaryen-bad-section-size`, `1` `binaryen-table-index-out-of-range`, and `1` `binaryen-invalid-tag-index`.

## Classification

This is a semantic-safe / Binaryen-positive implementation of a narrow source-backed loop prefix family. It preserves table side effects and only removes fake candidate-global guard traffic when all table operands are independent constants. Candidate-derived operands remain guarded by focused negatives.
