---
kind: research
status: supported
last_reviewed: 2026-04-24
sources:
  - ../binaryen/2026-04-24-dealign-primary-sources.md
  - ../../binaryen/passes/dealign/index.md
  - ../../binaryen/passes/dealign/binaryen-strategy.md
  - ../../binaryen/passes/dealign/implementation-structure-and-tests.md
  - ../../binaryen/passes/dealign/align-one-rewrite-surface-and-alignment-lowering-split.md
  - ../../binaryen/passes/dealign/wat-shapes.md
  - ../../binaryen/passes/dealign/starshine-strategy.md
  - ../../binaryen/passes/alignment-lowering/index.md
  - ../../../../src/passes/optimize.mbt
  - ../../../../docs/0063-2026-03-24-pass-port-batches-and-registry-map.md
  - ../../../../agent-todo.md
  - ../../binaryen/no-dwarf-default-optimize-path.md
supersedes:
  - 0221-2026-04-21-dealign-binaryen-research.md
---

# `dealign` primary-source and Starshine follow-up

## Why this follow-up exists

The `dealign` dossier was already useful as the canonical sibling page for `alignment-lowering`, but it still had two problems:

1. it lacked an immutable raw primary-source manifest and a dedicated Starshine status page; and
2. fresh source review showed that several details in the 2026-04-21 dossier were stale overreads.

This follow-up closes the provenance gap and corrects the mechanics while keeping the broader teaching purpose intact: `dealign` is still the tiny opposite-direction alignment-metadata sibling of `alignment-lowering`, not a chunk-lowering legality pass.

## Primary sources rechecked in this run

Captured immutably in:

- `docs/wiki/raw/binaryen/2026-04-24-dealign-primary-sources.md`

The most important reviewed surfaces were:

- the official Binaryen GitHub release page for `version_129`
- `src/passes/DeAlign.cpp` on `version_129` and current `main`
- `src/passes/pass.cpp` on `version_129` and current `main`
- `test/lit/passes/dealign.wast` on `version_129` and current `main`

## Local Starshine code and planning surfaces rechecked

- `src/passes/optimize.mbt`
- `docs/0063-2026-03-24-pass-port-batches-and-registry-map.md`
- `agent-todo.md`
- `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
- neighboring `alignment-lowering` dossier pages

## Corrections from the older 0221 research note

The older research note remains useful historically, but the following mechanics are superseded:

- no source-backed early `module->memory.exists()` bailout exists in reviewed `DeAlign.cpp`
- no explicit module-pass wrapper using `ModuleUtils::iterDefinedFunctions(...)` exists in reviewed `DeAlign.cpp`
- no `visitSIMDStore` method exists in the reviewed file
- the implementation does not branch on `align > 1`; it directly assigns `align = 1`
- the dedicated lit file visibly proves only small scalar `i32` load/store families, not broad `i64` / `f32` / `f64` / SIMD proof coverage

The corrected durable contract is smaller:

- Binaryen registers public pass `dealign`
- the pass is a function-parallel `WalkerPass<PostWalker<DeAlign>>`
- it visits `Load`, `Store`, and `SIMDLoad`
- it assigns each visited node's `align` field to `1`
- it preserves everything else about those nodes

## Starshine status found in this run

Starshine currently has no `dealign` registry entry at all.
That differs from neighboring `alignment-lowering`, which is tracked as boundary-only.

The exact current local status is:

- `src/passes/optimize.mbt#L127-L153` lists the current boundary-only and removed registry names, and neither list contains `dealign`
- `src/passes/optimize.mbt#L446-L466` therefore rejects an explicit `dealign` request through the generic `unknown pass flag {name}` path
- `docs/0063-2026-03-24-pass-port-batches-and-registry-map.md#L57-L61` names `alignment-lowering` but not `dealign`
- `agent-todo.md` has no dedicated `dealign` backlog slice
- the canonical no-DWARF path page does not schedule `dealign`

The new `starshine-strategy.md` page records this as an upstream-only status bridge rather than pretending Starshine has a local pass plan.

## Files changed because of this follow-up

### New files

- `docs/wiki/raw/binaryen/2026-04-24-dealign-primary-sources.md`
- `docs/wiki/raw/research/0317-2026-04-24-dealign-primary-sources-and-starshine-followup.md`
- `docs/wiki/binaryen/passes/dealign/starshine-strategy.md`

### Refreshed living pages and catalogs

- `docs/wiki/binaryen/passes/dealign/index.md`
- `docs/wiki/binaryen/passes/dealign/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/dealign/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/dealign/align-one-rewrite-surface-and-alignment-lowering-split.md`
- `docs/wiki/binaryen/passes/dealign/wat-shapes.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/index.md`
- `docs/wiki/log.md`
- `CHANGELOG.md`

## Maintenance rule going forward

If future `dealign` work needs a clean read path, start with:

1. `docs/wiki/raw/binaryen/2026-04-24-dealign-primary-sources.md`
2. `docs/wiki/binaryen/passes/dealign/index.md`
3. `docs/wiki/binaryen/passes/dealign/binaryen-strategy.md`
4. `docs/wiki/binaryen/passes/dealign/implementation-structure-and-tests.md`
5. `docs/wiki/binaryen/passes/dealign/align-one-rewrite-surface-and-alignment-lowering-split.md`
6. `docs/wiki/binaryen/passes/dealign/wat-shapes.md`
7. `docs/wiki/binaryen/passes/dealign/starshine-strategy.md`
8. `src/passes/optimize.mbt`
9. `docs/0063-2026-03-24-pass-port-batches-and-registry-map.md`
10. `agent-todo.md`
11. `docs/wiki/binaryen/passes/alignment-lowering/index.md`

## Bottom line

`dealign` remains a justified upstream-only dossier, but its corrected source-backed contract is narrower than the old page said: public Binaryen `dealign` is a function-parallel walker that sets `Load`, `Store`, and `SIMDLoad` alignments to `1`. Current Starshine does not even track the name in the registry, so the local strategy page is a status bridge and future-port warning, not an implementation map.
