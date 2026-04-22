---
kind: research
status: supported
last_reviewed: 2026-04-22
sources:
  - ../binaryen/2026-04-22-heap2local-primary-sources.md
  - ../../binaryen/passes/heap2local/index.md
  - ../../binaryen/passes/heap2local/binaryen-strategy.md
  - ../../binaryen/passes/heap2local/validation-fixups-and-special-cases.md
  - ../../binaryen/passes/heap2local/wat-shapes.md
  - ../../binaryen/passes/heap2local/starshine-hot-ir-strategy.md
  - ../../../../src/passes/heap2local.mbt
  - ../../../../src/passes/pass_manager.mbt
  - ../../../../src/passes/optimize.mbt
  - ../../../../src/passes/heap2local_test.mbt
  - ../../../../src/passes/heap2local_primary_test.mbt
  - ../../../../src/passes/optimize_test.mbt
  - ../../../../src/passes/registry_test.mbt
---

# `heap2local` primary-source and Starshine code-map follow-up

## Why this follow-up exists

The living `heap2local` dossier was already strong after the 2026-04-20 Binaryen research pass, but two practical gaps remained:

- the folder still lacked an immutable raw primary-source manifest like the newer implemented-pass dossiers now carry
- the local Starshine strategy page still described the implementation accurately at a high level, but it did not yet give readers the exact MoonBit registry / dispatcher / candidate-analysis / rewrite / test map needed for quick code navigation

This follow-up closes that narrower provenance-and-navigation gap without claiming the folder previously lacked a real Binaryen or Starshine dossier.

## Sources re-checked in this run

### Upstream Binaryen primary sources

Captured immutably in:

- `docs/wiki/raw/binaryen/2026-04-22-heap2local-primary-sources.md`

The key reviewed surfaces were:

- official Binaryen GitHub release pages for `version_129`
- `Heap2Local.cpp` on both `version_129` and `main`
- `pass.cpp`, `opt-utils.h`, `pass.h`, and `type-updating.h`
- the dedicated `heap2local.wast` lit file on both `version_129` and `main`

### Local Starshine code surfaces re-checked

- `src/passes/heap2local.mbt`
- `src/passes/pass_manager.mbt`
- `src/passes/optimize.mbt`
- `src/passes/heap2local_test.mbt`
- `src/passes/heap2local_primary_test.mbt`
- `src/passes/optimize_test.mbt`
- `src/passes/registry_test.mbt`

## Durable findings

### 1. The release anchoring is now explicit instead of implied

The earlier dossier already treated `version_129` as the Binaryen oracle, but it did not yet preserve the exact release-page provenance in the raw-source system.
The 2026-04-22 capture now records that the reviewed official release page for `version_129` showed publish date **2026-04-01**, and that the releases index was re-checked on the same day.

That gives the folder a stable provenance anchor instead of relying only on interpreted living pages.

### 2. The most useful local teaching upgrade was an exact code map

Re-checking the local MoonBit implementation confirmed that the cleanest read-along path is:

1. registry entry and summary in `src/passes/optimize.mbt`
2. dispatcher handoff in `src/passes/pass_manager.mbt`
3. candidate discovery, array discovery, direct-ref fold helpers, rewrite helpers, and detached-node cleanup in `src/passes/heap2local.mbt`
4. focused pass, primary-parity, preset-order, and registry coverage across the local test files

The older Starshine strategy page was directionally right, but it was too vague about where each part actually lives.

### 3. Current Starshine is best taught as a narrower direct local-pattern engine, not as a hidden Binaryen `EscapeAnalyzer` port

The local file still clearly centers on:

- `@ir.HotAnalysis::use_def()` as the only required analysis
- one-write local-owner candidate discovery
- direct struct and array shape checks
- explicit local-family traversal for copy chains
- direct helper folds for `ref.eq`, `ref.get_desc`, and array `ref.test`

That code map makes the main local-vs-upstream difference easier to teach honestly:

- upstream Binaryen uses broader escape/exclusivity reasoning with `LazyLocalGraph`, parent walking, branch-target flow, array-to-synthetic-struct lowering, and mandatory post-rewrite fixups
- current Starshine is a narrower HOT/use-def pattern matcher with direct array-element localization and no equivalent automatic nondefaultable-local fixup layer documented in this path

### 4. The local evidence surface is broader than one test file, but still narrower than a full CLI dossier

The re-check showed a useful touched-area hygiene clarification:

- the real local proof surface is not only `heap2local_test.mbt`; it also includes `heap2local_primary_test.mbt`, `optimize_test.mbt`, and `registry_test.mbt`
- there is **no** dedicated `heap2local` CLI replay lane in `src/cmd/cmd_wbtest.mbt` today, so the dossier should not imply that one exists

That clarification is small, but it keeps the touched folder from overstating local regression coverage.

## Files changed because of this follow-up

### New raw-source manifest

- `docs/wiki/raw/binaryen/2026-04-22-heap2local-primary-sources.md`

### Refreshed living pages and catalogs

- `docs/wiki/binaryen/passes/heap2local/index.md`
- `docs/wiki/binaryen/passes/heap2local/starshine-hot-ir-strategy.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/index.md`
- `docs/wiki/log.md`

## Maintenance rule going forward

If future `heap2local` work needs a quick provenance anchor plus a practical Starshine read-along path, start with:

1. `docs/wiki/raw/binaryen/2026-04-22-heap2local-primary-sources.md`
2. `docs/wiki/binaryen/passes/heap2local/index.md`
3. `docs/wiki/binaryen/passes/heap2local/starshine-hot-ir-strategy.md`
4. `docs/wiki/binaryen/passes/heap2local/parity.md`
5. `src/passes/heap2local.mbt`

That path now gives a clean bridge from official Binaryen release/source/test surfaces to the exact current MoonBit implementation, its focused local evidence surface, and the honest boundary between current HOT/use-def coverage and the larger upstream `EscapeAnalyzer` contract.
