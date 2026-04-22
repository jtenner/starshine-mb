---
kind: research
status: supported
last_reviewed: 2026-04-22
sources:
  - ../binaryen/2026-04-22-precompute-primary-sources.md
  - ../../binaryen/passes/precompute/index.md
  - ../../binaryen/passes/precompute/binaryen-strategy.md
  - ../../binaryen/passes/precompute/implementation-structure-and-tests.md
  - ../../binaryen/passes/precompute/propagation-partial-precompute-and-gc-identity.md
  - ../../binaryen/passes/precompute/wat-shapes.md
  - ../../binaryen/passes/precompute/starshine-hot-ir-strategy.md
  - ../../../../src/passes/precompute.mbt
  - ../../../../src/passes/pass_manager.mbt
  - ../../../../src/passes/optimize.mbt
  - ../../../../src/passes/precompute_test.mbt
  - ../../../../src/passes/optimize_test.mbt
  - ../../../../src/passes/registry_test.mbt
  - ../../../../src/cmd/cmd_wbtest.mbt
---

# `precompute` primary-source and code-map follow-up

## Why this follow-up exists

The living `precompute` dossier was already strong on upstream strategy, transformed shapes, and the plain-vs-propagate family split.
Two practical gaps still remained:

- the folder still lacked an immutable raw primary-source manifest
- the Starshine page still described the local subset honestly, but it did not yet give readers a compact exact code map for the MoonBit owner file, preset placement, writeback guards, and focused proof lanes

This follow-up closes that provenance-and-navigation gap without claiming the earlier dossier lacked a real overview page, Binaryen strategy page, transformed-shape page, or Starshine strategy page.

## Sources re-checked in this run

### Upstream Binaryen primary sources

Captured immutably in:

- `docs/wiki/raw/binaryen/2026-04-22-precompute-primary-sources.md`

The most important reviewed surfaces were:

- the official Binaryen GitHub release pages for `version_129`
- `Precompute.cpp` on `version_129` and `main`
- `pass.cpp`, `passes.h`, `opt-utils.h`, `local-graph.h`, `properties.h`, and `wasm-interpreter.h`
- representative plain and propagate lit files for effects, partial-select, all-features, GC, strings, `ref.func`, and relaxed-SIMD coverage

### Local Starshine code surfaces re-checked

- `src/passes/precompute.mbt`
- `src/passes/pass_manager.mbt`
- `src/passes/optimize.mbt`
- `src/passes/precompute_test.mbt`
- `src/passes/optimize_test.mbt`
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

What was still missing was a compact read-along answer to:

- where is the local descriptor and summary?
- where do the exact-constant helpers and actual fold matchers live?
- where is the constant-`if` and root-cleanup logic implemented?
- where do the invalid-carrier and writeback-validation guards live?
- which tests prove the current local contract, slot placement, and artifact safety story?

That exact navigation layer is what this follow-up adds.

### 3. Current Starshine `precompute` is still a narrow HOT subset plus pipeline hardening

Re-checking the local code confirmed that current Starshine remains much smaller than upstream Binaryen plain `precompute`.
The real local contract is split across a few compact surfaces:

- `src/passes/precompute.mbt`
  - exact constant recognizers
  - scalar/global/`if`/dead-drop rewrites
  - root-region cleanup
  - iterative local fixpoint driver
- `src/passes/pass_manager.mbt`
  - dispatch plus precompute-specific invalid-carrier and writeback-validation guards
- `src/passes/optimize.mbt`
  - registry entry and the two visible top-level preset slots
- test lanes in `precompute_test.mbt`, `optimize_test.mbt`, `registry_test.mbt`, and `cmd_wbtest.mbt`

That code map is more useful for future readers than another high-level restatement of upstream Binaryen.

### 4. The local proof surface is broader than one pass-local test file

The exact code map also made one practical point clearer:
local `precompute` behavior is not proven only by `precompute_test.mbt`.
The real proof surface today spans:

- `precompute_test.mbt` for the main HOT rewrite, cleanup, and validation regressions
- `optimize_test.mbt` for the two-top-level-slot preset claim
- `registry_test.mbt` for the public descriptor and preset-expansion claim
- `cmd_wbtest.mbt` for generated-artifact and debug-artifact CLI replays that retired the old slot-19 corruption witness

That matters because future readers can now follow pass behavior from the core file directly into the exact focused tests.

### 5. The main semantic gap versus Binaryen remains explicit

The new code map does not change the bottom line:

- upstream Binaryen plain `precompute` is a semantic compile-time evaluator with `Flow`, child-retention, partial-select precompute, emitability boundaries, and final refinalization, and the sibling `precompute-propagate` adds local-flow propagation plus one extra rerun
- current Starshine `precompute` is still the intentionally smaller HOT exact-scalar/global/constant-`if` subset, plus region cleanup and artifact-driven writeback hardening

The new docs make that contrast easier to follow directly from code and tests rather than only from prose.

## Files changed because of this follow-up

### New raw-source manifest

- `docs/wiki/raw/binaryen/2026-04-22-precompute-primary-sources.md`

### New research note

- `docs/wiki/raw/research/0251-2026-04-22-precompute-primary-sources-and-code-map-followup.md`

### Refreshed living pages and catalogs

- `docs/wiki/binaryen/passes/precompute/index.md`
- `docs/wiki/binaryen/passes/precompute/starshine-hot-ir-strategy.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/index.md`
- `docs/wiki/log.md`

## Maintenance rule going forward

If future `precompute` work needs a quick provenance anchor plus a practical Binaryen/Starshine read-along path, start with:

1. `docs/wiki/raw/binaryen/2026-04-22-precompute-primary-sources.md`
2. `docs/wiki/binaryen/passes/precompute/index.md`
3. `docs/wiki/binaryen/passes/precompute/implementation-structure-and-tests.md`
4. `docs/wiki/binaryen/passes/precompute/starshine-hot-ir-strategy.md`
5. `src/passes/precompute.mbt`
6. `src/passes/pass_manager.mbt`
7. `src/passes/optimize.mbt`
8. `src/passes/precompute_test.mbt`
9. `src/passes/optimize_test.mbt`
10. `src/passes/registry_test.mbt`
11. `src/cmd/cmd_wbtest.mbt`

That path now gives a clean bridge from official Binaryen release/source/test surfaces to the exact current MoonBit implementation, the local invalid-carrier and writeback-guard behavior, the focused test evidence, and the honest semantic gap between the current HOT subset and upstream Binaryen's much larger semantic evaluator family.