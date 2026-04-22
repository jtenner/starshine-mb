---
kind: research
status: supported
last_reviewed: 2026-04-22
sources:
  - ../binaryen/2026-04-22-tuple-optimization-primary-sources.md
  - ../../binaryen/passes/tuple-optimization/index.md
  - ../../binaryen/passes/tuple-optimization/binaryen-strategy.md
  - ../../binaryen/passes/tuple-optimization/implementation-structure-and-tests.md
  - ../../binaryen/passes/tuple-optimization/wat-shapes.md
  - ../../binaryen/passes/tuple-optimization/starshine-hot-ir-strategy.md
  - ../../binaryen/passes/tuple-optimization/implementation-map.md
  - ../../binaryen/passes/tuple-optimization/scheduler-and-gates.md
  - ../../binaryen/passes/tuple-optimization/parity.md
  - ../../../../src/passes/tuple_optimization.mbt
  - ../../../../src/passes/pass_manager.mbt
  - ../../../../src/passes/optimize.mbt
  - ../../../../src/passes/tuple_optimization_wbtest.mbt
  - ../../../../src/passes/registry_test.mbt
  - ../../../../src/cmd/cmd_wbtest.mbt
  - ../../../../src/cmd/cmd_native_wbtest.mbt
---

# `tuple-optimization` primary-source and code-map follow-up

## Why this follow-up exists

The living `tuple-optimization` dossier was already strong on upstream mechanics, transformed shapes, and the local HOT strategy.
Two practical gaps still remained:

- the folder still lacked an immutable raw primary-source manifest
- several living pages still relied on 2026-04-20 / 2026-04-21 source-check wording without one compact 2026-04-22 provenance anchor that tied the official Binaryen release surface directly to the current Starshine code map

This follow-up closes that provenance-and-navigation gap without claiming the earlier dossier lacked a real overview page, Binaryen strategy page, transformed-shape page, or Starshine strategy page.

## Sources re-checked in this run

### Upstream Binaryen primary sources

Captured immutably in:

- `docs/wiki/raw/binaryen/2026-04-22-tuple-optimization-primary-sources.md`

The most important reviewed surfaces were:

- the official Binaryen GitHub release pages for `version_129`
- `TupleOptimization.cpp` on `version_129` and `main`
- the relevant `pass.cpp` scheduler / registration lines on `version_129` and `main`
- the tuple-specific `OptimizeInstructions.cpp` peephole boundary on `version_129` and `main`
- tuple semantic neighbors in `wasm.cpp` and `wasm-validator.cpp`
- the dedicated `tuple-optimization.wast` lit file on `version_129` and `main`

### Local Starshine code surfaces re-checked

- `src/passes/tuple_optimization.mbt`
- `src/passes/pass_manager.mbt`
- `src/passes/optimize.mbt`
- `src/passes/tuple_optimization_wbtest.mbt`
- `src/passes/registry_test.mbt`
- `src/cmd/cmd_wbtest.mbt`
- `src/cmd/cmd_native_wbtest.mbt`

## Durable findings

### 1. The release anchoring is now explicit instead of implicit

The earlier dossier already treated `version_129` as the upstream oracle, but it did not preserve the exact release-page provenance in the raw-source system.
The 2026-04-22 capture now records that the reviewed official release page for `version_129` showed publish date **2026-04-01**, and that the releases index was re-checked on the same day.

### 2. The missing practical gap was provenance plus read-along navigation

The folder already had the required living pass pages:

- overview / landing page
- Binaryen strategy page
- transformed-shapes page
- Starshine strategy page
- upstream implementation/test-map page
- local implementation-map page

What was still missing was an immutable source manifest plus one compact note explaining that the remaining improvement was provenance and exact navigation, not a missing conceptual page.

### 3. The core Binaryen contract remains stable on the reviewed surfaces

Re-checking the official sources confirmed that the current teaching rule still holds:

- upstream `tuple-optimization` is a conservative tuple-local scratch-storage splitter
- it is not a generic multivalue optimizer
- its visible behavior is still anchored in the same small owner surface: `TupleOptimization.cpp`, the scheduler lines in `pass.cpp`, the earlier tuple peephole boundary in `OptimizeInstructions.cpp`, and the dedicated `tuple-optimization.wast` file

The narrow 2026-04-22 spot check on those `main` surfaces did not surface a new teaching-relevant drift beyond the living dossier's current claims.

### 4. The local Starshine code-map story is now easier to follow from source provenance

The existing local pages already mapped the main MoonBit implementation, but this follow-up makes the intended read-along path explicit:

- `src/passes/tuple_optimization.mbt`
  - seed-group matching
  - copy-payload recovery and copy-group linking
  - query-summary and forwarded-use classification
  - badness propagation
  - rewrite-mask planning
  - root-slot and carrier placement
  - concrete rewrite and cleanup entry points
- `src/passes/pass_manager.mbt`
  - active dispatch plus the tuple-debug trace hook
- `src/passes/optimize.mbt`
  - registry entry and exact-slot preset exclusion rule
- focused proof lanes in `tuple_optimization_wbtest.mbt`, `registry_test.mbt`, `cmd_wbtest.mbt`, and `cmd_native_wbtest.mbt`

That exact code map is more useful for future readers than another high-level restatement of the already-good HOT strategy prose.

### 5. The main Binaryen-versus-Starshine semantic split remains explicit

The refresh does not change the bottom line:

- upstream Binaryen works from explicit tuple locals, `tuple.make`, `tuple.extract`, and a tiny approved-use plus copy-component poisoning model
- current Starshine works from lifted multivalue producers, scalar spill ladders, forwarded copy groups, host-lane preservation, and HOT-lowering-aware carrier placement

The refreshed living pages now anchor that contrast more cleanly to both the raw official sources and the exact MoonBit owner files.

## Files changed because of this follow-up

### New raw-source manifest

- `docs/wiki/raw/binaryen/2026-04-22-tuple-optimization-primary-sources.md`

### New research note

- `docs/wiki/raw/research/0254-2026-04-22-tuple-optimization-primary-sources-and-code-map-followup.md`

### Refreshed living pages and catalogs

- `docs/wiki/binaryen/passes/tuple-optimization/index.md`
- `docs/wiki/binaryen/passes/tuple-optimization/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/tuple-optimization/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/index.md`
- `docs/wiki/log.md`

## Maintenance rule going forward

If future `tuple-optimization` work needs a quick provenance anchor plus a practical Binaryen/Starshine read-along path, start with:

1. `docs/wiki/raw/binaryen/2026-04-22-tuple-optimization-primary-sources.md`
2. `docs/wiki/binaryen/passes/tuple-optimization/index.md`
3. `docs/wiki/binaryen/passes/tuple-optimization/binaryen-strategy.md`
4. `docs/wiki/binaryen/passes/tuple-optimization/implementation-structure-and-tests.md`
5. `docs/wiki/binaryen/passes/tuple-optimization/starshine-hot-ir-strategy.md`
6. `docs/wiki/binaryen/passes/tuple-optimization/implementation-map.md`
7. `src/passes/tuple_optimization.mbt`
8. `src/passes/pass_manager.mbt`
9. `src/passes/optimize.mbt`
10. `src/passes/tuple_optimization_wbtest.mbt`
11. `src/passes/registry_test.mbt`
12. `src/cmd/cmd_wbtest.mbt`
13. `src/cmd/cmd_native_wbtest.mbt`

That path now gives a clean bridge from official Binaryen release/source/test surfaces to the exact current MoonBit implementation, the local preset-gating and debug-trace behavior, the focused proof lanes, and the honest semantic gap between Starshine's HOT-native bundle recognizer and upstream Binaryen's much smaller tuple-local AST pass.
