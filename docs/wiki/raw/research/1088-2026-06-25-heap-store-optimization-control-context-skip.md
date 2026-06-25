---
kind: research
status: current
last_reviewed: 2026-06-25
sources:
  - ./1085-2026-06-25-heap-store-optimization-control-scan-skip.md
  - ./1084-2026-06-25-heap-store-optimization-allocation-heavy-scaling.md
  - ../../../src/passes/heap_store_optimization.mbt
  - ../../../src/passes/heap_store_optimization_test.mbt
  - ../../../agent-todo.md
---

# HSO straight-line external-context skip

## Question

Can HSO reduce allocation-heavy per-candidate overhead further without weakening movement-safety predicates or changing Binaryen behavior?

## Change

`hso_process_region(...)` now checks each current-region root's effect mask before constructing the suffix/external root context used only by nested-region descent. If the root has no `EFFECT_MASK_CONTROL`, HSO skips both the context array construction and the `hso_process_node_regions(...)` call.

This is a narrower companion to `1085`: `1085` made `hso_process_node_regions(...)` return early for straight-line subtrees, while this change avoids preparing per-root context for calls that would immediately return. The current-region root-chain scan still handles all local-set and tee-wrapped struct-set candidates exactly as before.

## Validation

Commands run after the code change:

```sh
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt
moon fmt
moon build --target-dir target --target native --release src/cmd
```

Results:

- Focused HSO tests: `416/416` passed.
- `moon fmt`: passed.
- Native `src/cmd` build: passed with pre-existing unused-function warnings in `src/passes/pass_manager.mbt`.

Direct compare evidence is intentionally left to the next compare slice so the code/performance change and fuzz artifact update stay atomic.

## Allocation-heavy timing after the change

Reused the `1084`/`1085` fixtures and reran three Starshine traced HSO passes for the 1000-function and 2000-function cases. Every emitted wasm validated with `wasm-tools validate --features all`.

| Fixture | Previous Starshine HSO median (`1085`) | New Starshine HSO samples | New median | Prior Binaryen median (`1084`) | New ratio |
|---:|---:|---:|---:|---:|---:|
| 1000 functions | `5.612ms` | `5.524ms`, `5.341ms`, `5.588ms` | `5.524ms` | `0.791ms` | `~7.0x` |
| 2000 functions | `11.199ms` | `11.238ms`, `11.280ms`, `10.876ms` | `11.238ms` | `2.110ms` | `~5.3x` |

## Interpretation

This is a correctness-preserving micro-optimization that removes unnecessary straight-line pre-scan setup. The 1000-function fixture improves slightly compared with `1085`; the 2000-function fixture is statistically flat/slightly worse within the small three-run sample. HSO-I therefore remains open: Starshine still misses the pass-local target (`starshine_time <= 2 * binaryen_time`) on the allocation-heavy candidate fixture.

A discarded local experiment also tried making the predicate cache fully lazy. That did not improve these fixtures, so it was not kept. Next performance work should focus on repeated safety-predicate calls in the simple fold path or a more targeted cache/context reuse strategy, not on weakening correctness guards.
