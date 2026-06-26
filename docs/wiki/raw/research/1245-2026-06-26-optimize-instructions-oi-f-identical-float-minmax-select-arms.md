# Optimize-instructions OI-F identical float min/max select arms

Date: 2026-06-26

## Question

Does Binaryen `version_130` fold a `select` whose true and false arms are the same direct f32/f64 `min` or `max` local/constant expression, and can Starshine cover the same narrow source-backed shape safely?

## Binaryen oracle

Probe: `.tmp/oi-select-identical-float-minmax-arms-probe.wat`

Command:

```sh
wasm-opt --all-features -S --optimize-instructions .tmp/oi-select-identical-float-minmax-arms-probe.wat -o .tmp/oi-select-identical-float-minmax-arms-probe.out.wat
```

Result: passed. Binaryen removed the `select` for identical direct `f32.min`, `f32.max`, `f64.min`, and `f64.max` local/constant arms.

## Starshine implementation

Starshine now includes `f32.min`, `f32.max`, `f64.min`, and `f64.max` in the existing direct float binary local/constant identical-arm matcher.

The matcher remains intentionally narrow. It requires direct same-instruction binary nodes, the same direct local on the left child, and an exactly equal direct float constant on the right child. It does not claim arbitrary structural equality, commuted operands, value-equivalent constants, broad NaN-payload equality, float algebraic equality, or effectful/trapping condition folding.

## Tests and validation

- Red-first focused test: `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*numeric expression arms*'` failed before implementation on the new `f32.min` case (`0/1`) and passed after implementation (`1/1`).
- Binaryen oracle command above passed.
- `moon fmt` passed.
- `moon test src/passes` passed.
- `git diff --check` and `git diff --cached --check` passed before commit.

## Files

- `src/passes/optimize_instructions.mbt` adds float min/max instructions to the direct f32/f64 local/constant binary identical-arm matchers.
- `src/passes/optimize_instructions_test.mbt` extends the existing identical numeric expression arm test with f32.min and f64.max coverage.
- `agent-todo.md`, `docs/wiki/binaryen/passes/optimize-instructions/index.md`, `docs/wiki/binaryen/passes/optimize-instructions/starshine-strategy.md`, and `docs/wiki/log.md` record the narrowed OI-F coverage.

## Remaining boundaries

OI-F identical select-arm folding remains a direct-shell subset. Unsupported or unclaimed families include arbitrary expression equality, commuted operands, value-equivalent float constants, broad NaN-payload equality, broad reference equality, and effectful/trapping condition folding.
