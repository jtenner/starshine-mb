---
kind: research
status: current
last_reviewed: 2026-06-25
sources:
  - ./1126-2026-06-25-heap-store-optimization-post-1125-rebuild-validation.md
  - ./1125-2026-06-25-heap-store-optimization-timer-instrumentation-disposition.md
  - ../../binaryen/passes/heap-store-optimization/index.md
  - ../../../agent-todo.md
---

# HSO local attribution after rejected timers

## Question

Can we get useful HSO-I attribution without committing the per-function detail timers that distorted the traced timing lane in `1125`?

## Answer

Yes, but only as temporary local/non-comparable instrumentation. I rebuilt several local variants, validated each emitted wasm, and then restored the committed source. The measurements indicate that the allocation-heavy fixture is not dominated by pass-manager dispatch or the final region splice alone. The expensive part is the current per-function pure-default chain path: root-array copying/scanning plus per-chain HOT mutation/replacement across every generated function.

This does not close HSO-I. It does narrow the next implementation target: avoid another preflight or extra trace line, and focus on reducing root-copy/chain-bookkeeping/mutation work in `hso_process_region(...)` / `hso_process_local_set_chain(...)`.

## Fixture

Fixture: `.tmp/hso-allocation-heavy-candidates-2000-20260625.wat`.

All Starshine runs used:

```sh
target/native/release/build/cmd/cmd.exe \
  --heap-store-optimization \
  --tracing pass \
  .tmp/hso-allocation-heavy-candidates-2000-20260625.wat \
  -o .tmp/hso-sliceA-<variant>.<n>.wasm
wasm-tools validate --features all .tmp/hso-sliceA-<variant>.<n>.wasm
```

Each temporary variant was built with:

```sh
moon build --target-dir target --target native --release src/cmd
```

## Local variant results

| Variant | Temporary source shape | Samples | Median |
|---|---|---:|---:|
| Effects-only | `heap_store_optimization_run(...)` calls `pass_require_effects(...)` and returns unchanged. | `0.355ms`, `0.385ms`, `0.342ms` | `0.355ms` |
| No chain processing | `hso_process_local_set_chain(...)` immediately returns the original root unchanged. | `2.125ms`, `1.699ms`, `1.683ms` | `1.699ms` |
| Chain scan / consume only | Pure-default fast path scans matching stores and returns `([roots[idx]], next_idx)` before building the replacement. | `9.854ms`, `8.668ms`, `7.939ms` | `8.668ms` |
| No final region splice | Full chain processing still builds replacements, but the final `hot_region_splice(...)` in `hso_process_region(...)` is skipped. | `8.666ms`, `9.252ms`, `9.387ms` | `9.252ms` |
| Restored baseline | Original source restored and rebuilt. | `9.618ms`, `9.568ms`, `9.278ms`, `9.605ms`, `9.717ms` | `9.605ms` |

The restored-baseline median is local to this run and does not supersede the better committed `1122` reference median (`7.710ms`) or the post-rebuild `1126` median (`8.372ms`). It was captured to compare local variants under the same noisy environment.

## Interpretation

- Effects-only and no-chain runs are small relative to the restored baseline, so pass-manager function dispatch and HSO's no-op setup are not the dominant owner on this fixture.
- Skipping only the final root-region splice does not help; the cost has already been paid by chain scanning/replacement and associated HOT mutation bookkeeping.
- The scan/consume-only variant staying near baseline means the current complete-chain path still spends most time walking/copying the root array, recognizing each store chain, and updating per-function HOT state, not in default-field type materialization or the final splice alone.
- The `1125` per-function detail timer result (`detail:hso:process-root-region` `2.951ms` with inflated `pass:heap-store-optimization` total) should remain a distortion warning, not a committed timing source.

## Next target

Try one narrow implementation that reduces root-copy and chain bookkeeping without adding an extra preflight:

- avoid constructing `next_roots` from scratch for regions whose only change is a single consecutive pure-default chain;
- or add a one-splice consecutive-chain rewrite that scans once, builds the replacement once, and mutates the root region at the matched range rather than rebuilding every root array;
- or prove via a smaller patch that `hso_region_roots(...)` / `next_roots` copying is not avoidable before moving on to HOT mutation internals.

Do not revive the `1124` no-control preflight/in-place rewrite, the direct complete-chain return/array-reuse path, or the `1125` per-function timers without a materially different profile-backed design.

## Validation

- `moon build --target-dir target --target native --release src/cmd` passed for every temporary variant and after restoring the original source.
- Every emitted `.wasm` listed above validated with `wasm-tools validate --features all`.
- No source change from these experiments was kept.
