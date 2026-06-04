---
kind: research
status: current
last_reviewed: 2026-06-04
sources:
  - ../../binaryen/passes/reorder-locals/index.md
  - ../../binaryen/passes/reorder-locals/starshine-hot-ir-strategy.md
  - ../../binaryen/passes/reorder-locals/starshine-port-readiness-and-validation.md
  - ../../ir2/registry-map.md
  - ../../ir2/execution-plan.md
  - ./0552-2026-05-08-simplify-locals-nostructure-ordered-slot-replay.md
  - ./0063-2026-03-24-pass-port-batches-and-registry-map.md
  - ../../../../src/passes/optimize.mbt
  - ../../../../src/passes/optimize_test.mbt
  - ../../../../src/passes/registry_test.mbt
  - https://github.com/WebAssembly/binaryen/blob/main/src/passes/ReorderLocals.cpp
  - https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp
  - https://github.com/WebAssembly/binaryen/blob/main/test/passes/reorder-locals.wast
related:
  - ../../binaryen/no-dwarf-default-optimize-path.md
  - ../../binaryen/passes/simplify-locals-nostructure/index.md
  - ../../binaryen/passes/tuple-optimization/index.md
  - ../../binaryen/passes/coalesce-locals/index.md
---

# `reorder-locals` preset-scheduling reconciliation

## Question

The living IR2 registry pages say Starshine public `optimize` / `shrink` presets schedule `reorder-locals` once inside the tuple/no-structure cleanup lane, but older `reorder-locals` dossier pages still said the pass stayed entirely out of public presets. Which statement is current?

## Current source check

Local source of truth on 2026-06-04:

- `src/passes/optimize.mbt` registers `reorder-locals` as a `ModulePass` and both `optimize_preset_passes(...)` and `shrink_preset_passes(...)` contain exactly one `reorder-locals` slot:

```text
code-pushing -> tuple-optimization -> simplify-locals-nostructure -> vacuum -> reorder-locals -> remove-unused-brs
```

- `src/passes/optimize_test.mbt` locks that slot in two ways:
  - `tuple-optimization exact preset prereqs place code-pushing before the tuple slot` asserts the local-neighborhood order around positions 15 through 20.
  - `optimize and shrink presets schedule reorder-locals only inside the tuple no-structure slot` asserts the only `reorder-locals` slot is index `19`, preceded by `vacuum` and followed by `remove-unused-brs`.
- `src/passes/registry_test.mbt` keeps `reorder-locals` classified as `HotPassRegistryCategory::module_pass()` and asserts every expanded preset item is an active hot or module pass.
- The archived March registry note `0063` already records the corrected rule: `reorder-locals` is scheduled once inside the tuple/no-structure cleanup lane, not kept entirely out of presets.

Upstream orientation on 2026-06-04:

- Binaryen `main` still keeps the dedicated pass source at `src/passes/ReorderLocals.cpp`, with the same small frequency-sort / unused-body-local trim contract taught by the existing dossier.
- Binaryen `pass.cpp` still represents `reorder-locals` as a public pass and the no-DWARF strategy still treats it as a repeated local-cleanup glue pass in the broader optimizer path.
- No new upstream behavior source was needed for the Starshine scheduling correction: the change is about local preset state, and the already-ingested Binaryen source manifests remain sufficient for the upstream semantics.

## Reconciliation

Current durable Starshine split:

1. **Explicit pass:** active module pass.
2. **Public presets:** scheduled exactly once in both `optimize` and `shrink`, in the proven early tuple/no-structure cleanup lane.
3. **Not yet claimed:** full Binaryen slot-for-slot parity for every upstream `reorder-locals` occurrence. Binaryen uses multiple reorder-locals placements; Starshine currently documents and tests one public slot.
4. **Future expansion gate:** any second or third public preset slot still needs ordered-neighborhood replay evidence, local-name / raw-name-payload safety, and the same registry/preset tests updated in the landing change.

The stale sentence family to remove from living pages is therefore:

- “`reorder-locals` stays out of `optimize` / `shrink` presets until neighboring local passes land.”
- “`src/passes/optimize_test.mbt` asserts `optimize` / `shrink` do not contain `reorder-locals`.”

Replace it with:

- “Starshine schedules `reorder-locals` exactly once in the `code-pushing -> tuple-optimization -> simplify-locals-nostructure -> vacuum -> reorder-locals -> remove-unused-brs` lane; extra upstream-style slots remain future work.”

## Follow-up health rule

When a local preset changes, update all of these together:

- `docs/wiki/ir2/registry-map.md`
- `docs/wiki/ir2/execution-plan.md`
- the affected pass folder's local strategy / validation / parity pages
- `docs/wiki/binaryen/passes/tracker.md` if the pass status or scheduled surface changes materially
- `docs/wiki/index.md` and `docs/wiki/log.md`

Do not rely on old line-number prose such as `src/passes/optimize_test.mbt:390`; prefer test names or current function names unless a fresh line-anchor audit is part of the same change.
