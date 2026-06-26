# Optimize-instructions OI-M tuple-optimization fifty-seven-effect boundary

Date: 2026-06-26

## Question

Can the public `optimize-instructions` plus `tuple-optimization` pipeline parse and preserve Starshine's current boundary shape for a multivalue block with fifty-seven later non-selected effectful siblings, while Binaryen `version_130` localizes the same shape through tuple scratch locals?

## Binaryen oracle

Probe: `.tmp/oi-m-tuple-optimization-fifty-seven-effects-probe.wat`

Command:

```sh
wasm-opt --all-features -S --optimize-instructions --tuple-optimization .tmp/oi-m-tuple-optimization-fifty-seven-effects-probe.wat -o .tmp/oi-m-tuple-optimization-fifty-seven-effects-probe.out.wat
```

Result: passed. Binaryen emitted `tuple.make 58` plus tuple/scalar scratch local traffic, including scratch localization for the selected lane and the fifty-seven later effectful siblings.

## Starshine status

Starshine intentionally keeps the public multivalue block/drop/call/local.get spelling for this fixture and does not introduce local scratch traffic. This is boundary/status coverage only, not a parity implementation. The remaining mismatch is the same tuple-scratch reconstruction/localization gap tracked by OI-M.

## Tests and validation

- Focused boundary/status test: `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*fifty-seven later effects through tuple-optimization*'` passed `1/1`.
- Binaryen oracle command above passed and produced `tuple.make 58` plus tuple/scalar scratch locals.
- `moon fmt` passed.
- `moon test src/passes` passed.
- `git diff --check` and `git diff --cached --check` passed before commit.

## Files

- `src/passes/optimize_instructions_test.mbt` adds the fifty-seven-effect public tuple-optimization boundary test using the existing generated fixture helper.
- `agent-todo.md`, `docs/wiki/binaryen/passes/optimize-instructions/index.md`, `docs/wiki/binaryen/passes/optimize-instructions/starshine-strategy.md`, and `docs/wiki/log.md` record that OI-M now has the first ninety-nine tuple/multivalue sub-slices.

## Remaining boundaries

This does not close OI-M. Starshine still lacks broad tuple-scratch reconstruction/localization for selected or sibling multivalue effects, and broader `simplify-locals` / dedicated `tuple-optimization` neighbor parity remains open.
