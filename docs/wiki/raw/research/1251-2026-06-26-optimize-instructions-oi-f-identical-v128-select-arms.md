---
kind: research
status: supported
created: 2026-06-26
sources:
  - ../../binaryen/2026-06-19-optimize-instructions-version-130-source-refresh.md
  - ../../../passes/optimize-instructions/index.md
  - ../../../../../src/passes/optimize_instructions.mbt
  - ../../../../../src/passes/optimize_instructions_test.mbt
---

# Optimize Instructions OI-F Identical V128 Select Arms

## Question

Does Binaryen `version_130` fold `select` when both value arms are the same direct `v128.const`, and can Starshine safely cover that exact local shape?

## Binaryen oracle

Probe: `.tmp/oi-select-identical-v128-arms-probe.wat`.

Command:

```sh
wasm-opt --all-features -S --optimize-instructions .tmp/oi-select-identical-v128-arms-probe.wat -o .tmp/oi-select-identical-v128-arms-probe.out.wat
```

Result: passed. Binaryen removed the `select` for direct identical `v128.const i32x4 1 2 3 4` arms and also removed the already-covered identical `local.get` vector arms.

## Starshine change

Added red-first focused coverage in `src/passes/optimize_instructions_test.mbt`:

- `optimize-instructions folds select with identical pure v128 constant arms`

Before implementation, the focused test failed because Starshine kept the `select`. After implementation, it passes and the root is the direct `V128Const` instruction.

Implementation in `src/passes/optimize_instructions.mbt` is intentionally narrow:

- mark direct `V128Const` leaves as side-effect-free for OI's local expression matcher;
- fold identical select arms only when both direct `V128Const` instructions are byte-identical and the condition is side-effect-free.

## Boundaries

This does not claim SIMD algebraic equality, lane-equivalent spelling equality, arbitrary structural equality, commuted operands, vector splat/equivalence reasoning, or effectful/trapping condition folding. It only covers direct byte-identical `v128.const` select arms.

## Validation

- Binaryen oracle command above: passed.
- Red-first focused Moon command before implementation: `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*v128 constant arms*'` failed `0/1` on the new test.
- Focused command after implementation: same command passed `1/1`.
