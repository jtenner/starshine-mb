---
kind: research
status: current
last_reviewed: 2026-06-25
sources:
  - ./1088-2026-06-25-heap-store-optimization-control-context-skip.md
  - ./1084-2026-06-25-heap-store-optimization-allocation-heavy-scaling.md
  - ../../../src/passes/heap_store_optimization.mbt
  - ../../../src/passes/heap_store_optimization_test.mbt
  - ../../../agent-todo.md
---

# HSO simple-value skip fast path

## Question

Can HSO avoid repeated skip-local-set predicate walks for simple moved values without weakening Binaryen movement safety?

## Change

`hso_reorder_effect_mask(...)` now returns the node's effect mask immediately when it has no `EFFECT_MASK_CONTROL`. The only reason this helper previously consulted `hso_subtree_may_skip_local_set(...)` was to decide whether to keep or strip control effects from the reordering mask. A value whose effect summary has no control cannot branch, become unreachable, or otherwise skip the local assignment that anchors a fresh constructor chain, so the skip-local-set walk is unnecessary.

`hso_try_fold_into_struct_new(...)` now uses the same guard before its explicit skip-local-set safety check. If the moved value's effect mask has no control, HSO cannot need the branch-only/external-root exception path.

This is intended as a pure fast path. It does not change movement legality for any control-carrying, catchable, tail-call, branch, or unreachable value: those still use the existing `hso_subtree_may_skip_local_set(...)`, `hso_subtree_skip_is_branch_only(...)`, and active-catch checks.

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

Reused the `1084`/`1085`/`1088` fixtures and reran three Starshine traced HSO passes for the 1000-function and 2000-function cases. Every emitted wasm validated with `wasm-tools validate --features all`.

| Fixture | Previous Starshine HSO median (`1088`) | New Starshine HSO samples | New median | Prior Binaryen median (`1084`) | New ratio |
|---:|---:|---:|---:|---:|---:|
| 1000 functions | `5.524ms` | `5.436ms`, `5.199ms`, `5.919ms` | `5.436ms` | `0.791ms` | `~6.9x` |
| 2000 functions | `11.238ms` | `11.201ms`, `12.621ms`, `11.033ms` | `11.201ms` | `2.110ms` | `~5.3x` |

## Interpretation

The fast path is correctness-preserving and gives another tiny 1000-function improvement, but the allocation-heavy 2000-function fixture remains effectively flat and still misses the pass-local target (`starshine_time <= 2 * binaryen_time`). HSO-I remains open. Further performance work likely needs a more structural reduction in candidate-chain work or context/cache reuse, not additional tiny simple-value guards alone.
