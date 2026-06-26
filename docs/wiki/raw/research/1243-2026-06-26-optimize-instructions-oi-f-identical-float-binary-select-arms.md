# Optimize-instructions OI-F identical float binary select arms

Date: 2026-06-26

## Question

Does Binaryen `version_130` fold a `select` whose true and false arms are the same direct f32/f64 binary local/constant expression, and can Starshine cover the same narrow source-backed shape safely?

## Binaryen oracle

Probe: `.tmp/oi-select-identical-float-binary-arms-probe.wat`

Command:

```sh
wasm-opt --all-features -S --optimize-instructions .tmp/oi-select-identical-float-binary-arms-probe.wat -o .tmp/oi-select-identical-float-binary-arms-probe.out.wat
```

Result: passed. Binaryen removed the `select` for identical direct f32/f64 local/constant binary arms. The probe covered `f32.add`, `f32.div`, `f32.copysign`, `f64.mul`, `f64.div`, and `f64.copysign`. Binaryen also rewrote the probed divide-by-two cases to multiply-by-0.5 after the select arm fold.

## Starshine implementation

Starshine now recognizes direct same-instruction, same-local, same-float-constant f32/f64 binary shells as identical pure select arms:

- f32: `add`, `sub`, `mul`, `div`, `copysign`
- f64: `add`, `sub`, `mul`, `div`, `copysign`

The matcher remains intentionally narrow. It requires the two arms to be direct binary nodes with the same instruction, a same-local left child, and an exactly equal direct float constant right child. It does not claim arbitrary structural equality, commuted operands, value-equivalent constants, broad NaN-payload equality, float binary algebraic identities, or effectful/trapping condition folding.

## Tests and validation

- Red-first focused test: `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*numeric expression arms*'` failed before implementation on the new `f32.add` case (`0/1`) and passed after implementation (`1/1`).
- `moon fmt` passed.
- `moon test src/passes` passed.
- Diff whitespace checks passed before commit.

## Files

- `src/passes/optimize_instructions.mbt` adds the f32/f64 local/constant binary identical-arm matchers and wires them into select arm equality.
- `src/passes/optimize_instructions_test.mbt` extends the existing identical numeric expression arm test with f32/f64 binary coverage.
- `agent-todo.md`, `docs/wiki/binaryen/passes/optimize-instructions/index.md`, `docs/wiki/binaryen/passes/optimize-instructions/starshine-strategy.md`, and `docs/wiki/log.md` record the narrower OI-F coverage.

## Remaining boundaries

OI-F identical select-arm folding is still a narrow direct-shell subset. Remaining unsupported or unclaimed families include arbitrary expression equality, commuted binary operands, global value equivalence, float binary arithmetic equality beyond exact direct shells, broad NaN-payload equality, broad reference equality, and effectful/trapping condition folding.
