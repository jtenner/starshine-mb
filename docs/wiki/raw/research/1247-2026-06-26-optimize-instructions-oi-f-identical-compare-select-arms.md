# Optimize-instructions OI-F identical compare select arms

Date: 2026-06-26

## Question

Does Binaryen `version_130` fold a `select` whose true and false arms are the same direct numeric comparison local/constant expression, and can Starshine cover the same narrow source-backed shape safely?

## Binaryen oracle

Probe: `.tmp/oi-select-identical-compare-arms-probe.wat`

Command:

```sh
wasm-opt --all-features -S --optimize-instructions .tmp/oi-select-identical-compare-arms-probe.wat -o .tmp/oi-select-identical-compare-arms-probe.out.wat
```

Result: passed. Binaryen removed the `select` for identical direct `i32.eq`, `i64.lt_u`, `f32.gt`, and `f64.le` local/constant compare arms.

## Starshine implementation

Starshine now includes direct i32/i64 integer compare instructions and direct f32/f64 float compare instructions in the existing local/constant identical-arm matchers.

The matcher remains intentionally narrow. It requires direct same-instruction binary nodes, the same direct local on the left child, and an exactly equal direct constant on the right child. It does not claim arbitrary structural equality, commuted operands, value-equivalent constants, broad NaN-payload equality, float algebraic equality, or effectful/trapping condition folding.

## Tests and validation

- Red-first focused test: `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*numeric expression arms*'` failed before implementation on the new `i32.eq` case (`0/1`) and passed after implementation (`1/1`).
- Binaryen oracle command above passed.
- `moon fmt` passed.
- `moon test src/passes` passed.
- `git diff --check` and `git diff --cached --check` passed before commit.

## Files

- `src/passes/optimize_instructions.mbt` adds integer and float compare instructions to the direct numeric local/constant identical-arm matchers.
- `src/passes/optimize_instructions_test.mbt` extends the existing identical numeric expression arm test with i32/i64/f32/f64 compare coverage.
- `agent-todo.md`, `docs/wiki/binaryen/passes/optimize-instructions/index.md`, `docs/wiki/binaryen/passes/optimize-instructions/starshine-strategy.md`, and `docs/wiki/log.md` record the narrowed OI-F coverage.

## Remaining boundaries

OI-F identical select-arm folding remains a direct-shell subset. Unsupported or unclaimed families include arbitrary expression equality, commuted operands, value-equivalent float constants, broad NaN-payload equality, broad reference equality, and effectful/trapping condition folding.
