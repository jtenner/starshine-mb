---
kind: research
status: supported
last_reviewed: 2026-04-24
sources:
  - ../binaryen/2026-04-24-type-un-finalizing-primary-sources.md
  - ../../binaryen/passes/type-un-finalizing/index.md
  - ../../binaryen/passes/type-un-finalizing/starshine-strategy.md
  - ../../../../src/passes/optimize.mbt
  - ../../../../src/lib/types.mbt
  - 0063-2026-03-24-pass-port-batches-and-registry-map.md
  - ../../../../agent-todo.md
related:
  - ../../binaryen/passes/type-un-finalizing/binaryen-strategy.md
  - ../../binaryen/passes/type-un-finalizing/implementation-structure-and-tests.md
  - ../../binaryen/passes/type-un-finalizing/private-boundaries-sibling-split-and-no-leaf-rule.md
  - ../../binaryen/passes/type-un-finalizing/wat-shapes.md
  - ../../binaryen/passes/type-finalizing/index.md
---

# `type-un-finalizing` primary sources and Starshine follow-up

## Question

The `type-un-finalizing` folder already explained the upstream sibling from the older 0193 research note, but it still lacked:

- an immutable raw primary-source capture,
- a dedicated Starshine status / port-strategy page,
- updated living-page citations to the 2026-04-24 source review,
- and an explicit local code map for the boundary-only registry truth.

## Sources reviewed

Primary online sources are captured in [`../binaryen/2026-04-24-type-un-finalizing-primary-sources.md`](../binaryen/2026-04-24-type-un-finalizing-primary-sources.md).
The important upstream surfaces are:

- Binaryen release `version_129`, observed on 2026-04-24 as latest and published **2026-04-01 14:31**.
- `src/passes/TypeFinalizing.cpp`, shared owner of `type-finalizing` and `type-unfinalizing`.
- `src/passes/pass.cpp`, public registration and default scheduler surface.
- `test/lit/passes/type-finalizing.wast`, the dedicated public proof file for both siblings.
- `type-updating.*`, `module-utils.*`, and `subtypes.h`, the helper surfaces behind private-type selection, coherent global rewrite, and the finalizing-only leaf proof.

Local Starshine surfaces reviewed:

- `src/passes/optimize.mbt`
- `src/lib/types.mbt`
- `src/wast/parser.mbt`
- `src/wast/lower_to_lib.mbt`
- `src/validate/env.mbt`
- `src/validate/typecheck.mbt`
- `src/binary/encode.mbt`
- `src/binary/decode.mbt`
- `docs/0063-2026-03-24-pass-port-batches-and-registry-map.md`
- `agent-todo.md`

## Findings

- Upstream Binaryen spelling is `type-unfinalizing`; Starshine's local registry alias is `type-un-finalizing`.
- Binaryen implements both siblings in the same `TypeFinalizing(bool finalize)` pass class.
- In unfinalizing mode, the pass checks GC, collects private heap types, skips subtype construction, and makes every private candidate open through `GlobalTypeRewriter` plus `setOpen(true)`.
- The sibling intentionally lacks the finalizing mode's leaf-only filter. Reopening a private parent with children is valid because reopening does not claim there are no children.
- The dedicated lit file proves public types stay untouched, private types change according to the selected mode, function heap types participate, and global/local uses remain coherent after the helper rewrite.
- Starshine currently has no owner file, no module dispatcher case, no preset role, and no active backlog slice for this pass. It is a boundary-only name in `src/passes/optimize.mbt`, and direct requests reject through `run_hot_pipeline_expand_passes(...)`.

## Wiki changes made from this research

- Added the raw source capture at [`../binaryen/2026-04-24-type-un-finalizing-primary-sources.md`](../binaryen/2026-04-24-type-un-finalizing-primary-sources.md).
- Added [`../../binaryen/passes/type-un-finalizing/starshine-strategy.md`](../../binaryen/passes/type-un-finalizing/starshine-strategy.md).
- Refreshed the existing living dossier pages to cite the raw manifest and this follow-up instead of relying only on 0193:
  - [`../../binaryen/passes/type-un-finalizing/index.md`](../../binaryen/passes/type-un-finalizing/index.md)
  - [`../../binaryen/passes/type-un-finalizing/binaryen-strategy.md`](../../binaryen/passes/type-un-finalizing/binaryen-strategy.md)
  - [`../../binaryen/passes/type-un-finalizing/implementation-structure-and-tests.md`](../../binaryen/passes/type-un-finalizing/implementation-structure-and-tests.md)
  - [`../../binaryen/passes/type-un-finalizing/private-boundaries-sibling-split-and-no-leaf-rule.md`](../../binaryen/passes/type-un-finalizing/private-boundaries-sibling-split-and-no-leaf-rule.md)
  - [`../../binaryen/passes/type-un-finalizing/wat-shapes.md`](../../binaryen/passes/type-un-finalizing/wat-shapes.md)
- Updated pass catalogs and the general wiki index/log so the folder no longer looks like a pre-manifest working dossier.

## Uncertainties and caveats

- The current Starshine type-section rewrite infrastructure does not yet expose a named equivalent of Binaryen's `GlobalTypeRewriter`; future port work must design or reuse one before flipping the registry entry out of boundary-only status.
- The exact local representation of Binaryen's `ModuleUtils::getPrivateHeapTypes(...)` boundary is not yet defined as a pass helper. A future port must decide how Starshine proves private-vs-public heap-type visibility.
- The current-main check was narrow: owner file and dedicated lit file only. It did not prove absence of drift in every helper transitively used by `GlobalTypeRewriter`.

## Follow-up

- If a future implementation starts, keep `type-finalizing` and `type-un-finalizing` on one shared design path. Binaryen's real split is one mode bit plus the finalizing-only leaf proof.
- Add direct registry tests for `type-un-finalizing` rejection if the broader registry test suite starts asserting every boundary-only GC/type name individually.
