# 0448-2026-05-05-heap-store-optimization-current-main-recheck

## Question

Did Binaryen `heap-store-optimization` drift on current `main`, and did the exact Starshine code anchors in the living dossier need a refresh?

## Answer

No teaching-relevant current-`main` drift was found. The reviewed upstream contract is still the same narrow constructor/store fold:

- fold `struct.set` into a fresh `struct.new` family when the moved value stays safe to reorder;
- leave the generic dead-store / load-forwarding TODO visible;
- keep the `StructSet` / `Block` visitor surface;
- rely on effect-order checks and `LazyLocalGraph` for the hard control-flow case.

The local Starshine code map did need a refresh, mainly because the `optimize.mbt` and `pass_manager.mbt` line anchors had moved since the earlier 2026-04-25 capture.

## Files involved

- `docs/wiki/raw/binaryen/2026-05-05-heap-store-optimization-current-main-recheck.md`
- `docs/wiki/binaryen/passes/heap-store-optimization/index.md`
- `docs/wiki/binaryen/passes/heap-store-optimization/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/heap-store-optimization/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/heap-store-optimization/swap-safety-and-control-flow.md`
- `docs/wiki/binaryen/passes/heap-store-optimization/wat-shapes.md`
- `docs/wiki/binaryen/passes/heap-store-optimization/starshine-hot-ir-strategy.md`

## Follow-up

The living dossier was updated to point at the new 2026-05-05 raw capture and to use the refreshed local line anchors for the active Starshine implementation.
