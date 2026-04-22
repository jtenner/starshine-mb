---
kind: research
status: supported
last_reviewed: 2026-04-22
sources:
  - ../binaryen/2026-04-22-memory-packing-primary-sources.md
  - ../../binaryen/passes/memory-packing/index.md
  - ../../binaryen/passes/memory-packing/binaryen-strategy.md
  - ../../binaryen/passes/memory-packing/implementation-structure-and-tests.md
  - ../../binaryen/passes/memory-packing/segment-op-rewrites-and-traps.md
  - ../../binaryen/passes/memory-packing/wat-shapes.md
  - ../../binaryen/passes/memory-packing/starshine-hot-ir-strategy.md
  - ../../binaryen/passes/memory-packing/parity.md
  - ../../../../src/passes/memory_packing.mbt
  - ../../../../src/passes/pass_manager.mbt
  - ../../../../src/passes/optimize.mbt
  - ../../../../src/passes/memory_packing_test.mbt
  - ../../../../src/passes/registry_test.mbt
  - ../../../../src/cmd/cmd_wbtest.mbt
---

# `memory-packing` primary-source and code-map follow-up

## Why this follow-up exists

The living `memory-packing` dossier was already strong on upstream strategy, transformed shapes, and the segment-op/trap corner cases.
Two practical gaps still remained:

- the folder still lacked an immutable raw primary-source manifest
- the Starshine page still described the local subset honestly, but it did not yet give readers a compact exact MoonBit code map for the active-range helpers, legality gate, module-pass dispatch, preset placement, and focused proof lanes

This follow-up closes that provenance-and-navigation gap without claiming the earlier dossier lacked a real overview page, Binaryen strategy page, transformed-shape page, or Starshine strategy page.

## Sources re-checked in this run

### Upstream Binaryen primary sources

Captured immutably in:

- `docs/wiki/raw/binaryen/2026-04-22-memory-packing-primary-sources.md`

The most important reviewed surfaces were:

- the official Binaryen GitHub release pages for `version_129`
- `MemoryPacking.cpp` on `version_129` and `main`
- `pass.cpp`
- the dedicated lit files for all-features, traps, zero-filled imported memory, memory64 high-address handling, and GC data-segment users

### Local Starshine code surfaces re-checked

- `src/passes/memory_packing.mbt`
- `src/passes/pass_manager.mbt`
- `src/passes/optimize.mbt`
- `src/passes/memory_packing_test.mbt`
- `src/passes/registry_test.mbt`
- `src/cmd/cmd_wbtest.mbt`

## Durable findings

### 1. The release anchoring is now explicit instead of implicit

The earlier dossier already treated `version_129` as the upstream oracle, but it did not preserve the exact release-page provenance in the raw-source system.
The 2026-04-22 capture now records that the reviewed official release page for `version_129` showed publish date **2026-04-01**, and that the releases index was re-checked on the same day.

### 2. The local teaching gap was navigation, not missing pass pages

The folder already had the required living pass pages:

- overview / landing page
- Binaryen strategy page
- transformed-shapes page
- Starshine strategy page
- upstream implementation/test-map page
- parity page

What was still missing was a compact read-along answer to:

- where is the local public summary and module-pass entry?
- where do the exact offset, range, merge, and top-byte helpers live?
- where is the whole-module one-memory / overlap gate implemented?
- where is the pass dispatched and scheduled in presets?
- which tests prove the current local contract, and where is the nearest CLI replay evidence?

That exact navigation layer is what this follow-up adds.

### 3. Current Starshine `memory-packing` is still an active-segment-only module pass

Re-checking the local code confirmed that current Starshine remains much smaller than upstream Binaryen `MemoryPacking.cpp`.
The real local contract is concentrated in a few compact surfaces:

- `src/passes/memory_packing.mbt`
  - summary text
  - offset parsing and shifting
  - zero/nonzero range collection and small-zero merging
  - top-byte trap preservation
  - one-memory / overlap legality gating
  - active-segment-only module rewriting plus `data_count` repair
- `src/passes/pass_manager.mbt`
  - explicit module-pass dispatch inside the public pipeline
- `src/passes/optimize.mbt`
  - registry entry plus early preset placement before `once-reduction` and `global-refining`
- proof lanes in `memory_packing_test.mbt`, `registry_test.mbt`, and the debug-artifact optimize-prefix replay in `cmd_wbtest.mbt`

That exact code map is more useful for future readers than another high-level restatement of upstream Binaryen.

### 4. The local proof surface is broader than the three focused pass tests

The direct pass tests still cover only three focused active-shape families:

- profitable active zero trimming
- top-byte trap preservation
- active overlap bailout

But the exact code map made one practical point clearer:
local `memory-packing` behavior is also evidenced by:

- `registry_test.mbt` proving the module-pass category and preset presence
- `optimize.mbt` proving the coarse scheduler slot
- `cmd_wbtest.mbt` proving the debug-artifact optimize-prefix replay that includes `--memory-packing` as part of the early module-pass prefix

That matters because future readers can now follow pass behavior from the core file directly into the exact focused tests and the nearest artifact replay lane instead of treating the pass as if it had only one tiny isolated test file.

### 5. The main semantic gap versus Binaryen remains explicit

The new code map does not change the bottom line:

- upstream Binaryen `memory-packing` is a whole-module segment-and-segment-op rewrite pass with passive-user replacement, drop-state bookkeeping, imported-memory gating, GC conservative boundaries, and segment-count limiting
- current Starshine `memory-packing` is still the intentionally smaller active-segment-only module pass with constant-offset parsing, overlap checks, simple profitability, top-byte trap preservation, and `data_count` repair

The new docs make that contrast easier to follow directly from code and tests rather than only from prose.

## Files changed because of this follow-up

### New raw-source manifest

- `docs/wiki/raw/binaryen/2026-04-22-memory-packing-primary-sources.md`

### New research note

- `docs/wiki/raw/research/0252-2026-04-22-memory-packing-primary-sources-and-code-map-followup.md`

### Refreshed living pages and catalogs

- `docs/wiki/binaryen/passes/memory-packing/index.md`
- `docs/wiki/binaryen/passes/memory-packing/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/memory-packing/starshine-hot-ir-strategy.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/index.md`
- `docs/wiki/log.md`

## Maintenance rule going forward

If future `memory-packing` work needs a quick provenance anchor plus a practical Binaryen/Starshine read-along path, start with:

1. `docs/wiki/raw/binaryen/2026-04-22-memory-packing-primary-sources.md`
2. `docs/wiki/binaryen/passes/memory-packing/index.md`
3. `docs/wiki/binaryen/passes/memory-packing/implementation-structure-and-tests.md`
4. `docs/wiki/binaryen/passes/memory-packing/starshine-hot-ir-strategy.md`
5. `src/passes/memory_packing.mbt`
6. `src/passes/pass_manager.mbt`
7. `src/passes/optimize.mbt`
8. `src/passes/memory_packing_test.mbt`
9. `src/passes/registry_test.mbt`
10. `src/cmd/cmd_wbtest.mbt`

That path now gives a clean bridge from official Binaryen release/source/test surfaces to the exact current MoonBit implementation, the focused active-only legality and rewrite subset, the public module-pass scheduler slot, the local test evidence, and the honest semantic gap between the current Starshine subset and upstream Binaryen's much larger passive-rewrite contract.
