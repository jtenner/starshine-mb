# Optimize-instructions OI-M tuple-optimization fifty-five-effect boundary

Date: 2026-06-26

## Question

Can the public `optimize-instructions` plus `tuple-optimization` neighbor pipeline parse and preserve the next generated multivalue boundary fixture with fifty-five later non-selected effects, and how does Binaryen shape it?

## Binaryen oracle

Probe: `.tmp/oi-m-tuple-optimization-fifty-five-effects-probe.wat`

Command:

```sh
wasm-opt --all-features -S --optimize-instructions --tuple-optimization .tmp/oi-m-tuple-optimization-fifty-five-effects-probe.wat -o .tmp/oi-m-tuple-optimization-fifty-five-effects-probe.out.wat
```

Result: passed. Binaryen localizes the public multivalue block through `tuple.make 56` plus tuple/scalar scratch locals (`local.set` / `local.get`) while preserving the later effect calls.

## Starshine result

Starshine still keeps the public multivalue block/drop/call/local.get spelling under `optimize-instructions` plus `tuple-optimization` and does not introduce tuple/scalar scratch-local reconstruction for this shape.

This is boundary/status coverage only, not parity implementation. The observed mismatch remains the known OI-M tuple-scratch reconstruction/localization gap.

## Test and validation

- Added focused boundary/status test: `optimize-instructions intentionally keeps public multivalue block with fifty-five later effects through tuple-optimization boundary`.
- Focused command: `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*fifty-five later effects through tuple-optimization*'` passed `1/1`.
- `moon fmt` passed.
- `moon test src/passes` passed.
- Diff whitespace checks passed before commit.

## Files

- `src/passes/optimize_instructions_test.mbt` adds the fifty-five-effect public pipeline boundary test using `optimize_instructions_tuple_optimization_effect_boundary_fixture(55)`.
- `agent-todo.md`, `docs/wiki/binaryen/passes/optimize-instructions/index.md`, `docs/wiki/binaryen/passes/optimize-instructions/starshine-strategy.md`, and `docs/wiki/log.md` record the OI-M boundary evidence and update the tuple/multivalue sub-slice count.

## Remaining work

This does not close OI-M. Remaining work includes tuple-scratch localization/reconstruction for public multivalue block shapes, selected/sibling multi-result tuple cases, broader tee/drop reconstruction, and neighbor interactions with `tuple-optimization` / `simplify-locals`.
