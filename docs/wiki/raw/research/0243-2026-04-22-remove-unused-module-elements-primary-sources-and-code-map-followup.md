---
kind: research
status: supported
last_reviewed: 2026-04-22
sources:
  - ../binaryen/2026-04-22-remove-unused-module-elements-primary-sources.md
  - ../../binaryen/passes/remove-unused-module-elements/index.md
  - ../../binaryen/passes/remove-unused-module-elements/binaryen-strategy.md
  - ../../binaryen/passes/remove-unused-module-elements/wat-shapes.md
  - ../../binaryen/passes/remove-unused-module-elements/roots-reference-only-and-nullification.md
  - ../../../../src/passes/remove_unused_module_elements.mbt
  - ../../../../src/passes/pass_manager.mbt
  - ../../../../src/passes/optimize.mbt
  - ../../../../src/passes/remove_unused_module_elements_test.mbt
  - ../../../../src/cmd/cmd_wbtest.mbt
---

# `remove-unused-module-elements` primary-source and Starshine code-map follow-up

## Why this follow-up exists

The living `remove-unused-module-elements` dossier was already strong on the upstream side after the 2026-04-20 refresh, but two practical gaps remained:

- the folder still lacked an immutable raw primary-source manifest like the newer implemented-pass dossiers now carry
- the local Starshine strategy page still stopped at high-level module-pass framing instead of giving readers an exact MoonBit registry / dispatcher / liveness / rewrite / test map

This follow-up closes that narrower provenance-and-navigation gap without claiming the folder lacked a real dossier.

## Sources re-checked in this run

### Upstream Binaryen primary sources

Captured immutably in:

- `docs/wiki/raw/binaryen/2026-04-22-remove-unused-module-elements-primary-sources.md`

The key reviewed surfaces were:

- official Binaryen GitHub release pages for `version_129`
- `RemoveUnusedModuleElements.cpp` on both `version_129` and `main`
- `pass.cpp`, `module-utils.h`, `element-utils.h`, `gc-type-utils.h`, `table-utils.h`, `type-updating.h`, and `FunctionTypeUtils.cpp`
- the dedicated all-features / refs / EH-old / sibling-mode lit files already used by the living dossier

### Local Starshine code surfaces re-checked

- `src/passes/remove_unused_module_elements.mbt`
- `src/passes/pass_manager.mbt`
- `src/passes/optimize.mbt`
- `src/passes/remove_unused_module_elements_test.mbt`
- `src/cmd/cmd_wbtest.mbt`

## Durable findings

### 1. The release anchoring is now explicit instead of implied

The earlier dossier already treated `version_129` as the Binaryen oracle, but it did not yet preserve the exact release-page provenance in the raw-source system.
The 2026-04-22 capture now records that the reviewed official release page for `version_129` showed publish date **2026-04-01**, and that the releases index was re-checked on the same day.

That gives the folder a stable provenance anchor instead of relying only on interpreted living pages.

### 2. The main remaining local teaching gap was the exact module-pass code map

The existing local strategy page correctly said that Starshine keeps `remove-unused-module-elements` module-scoped, but it still hid the ownership split future maintainers are most likely to need:

- the registry and dispatcher surface
- the imported-parent retention policy
- the queue-driven whole-module liveness collector
- the broad surviving-index rewrite machinery
- the post-prune dead-type cleanup path
- the focused test and CLI lanes that prove the current public contract

This follow-up makes that map explicit.

### 3. Current Starshine RUME is best taught as one coherent module rewrite pipeline

Re-checking the local code confirmed that the cleanest local read-along is:

1. register the pass as a module pass
2. seed liveness with start / exports / imported-parent active segments
3. run a queue-driven reachability walk over code and module sections
4. build remaps for surviving module elements
5. rewrite all surviving section and instruction carriers
6. compact now-dead type entries

That is the durable local explanation readers need; the older page was correct about the module-pass split, but too vague about the actual implementation structure.

### 4. The focused local test map is stronger than the old strategy page made obvious

The local tests already covered the most important current behaviors, but the folder was not surfacing that clearly enough:

- `src/passes/remove_unused_module_elements_test.mbt` locks broad survivor remapping, explicit memarg rewrites, imported-parent retention, imported-element drop, imported-function drop plus dead-type cleanup, start-section no-op handling, and active-segment keep/drop distinctions
- `src/cmd/cmd_wbtest.mbt` locks the explicit CLI pass surface for `--remove-unused-module-elements` plus the unchanged-bytes fast path
- `src/passes/optimize.mbt` proves the current public registry boundary: RUME is an active module pass but not a HOT pass

That combination makes the current Starshine contract easier to teach from beginner through advanced readers.

## Files changed because of this follow-up

### New raw-source manifest

- `docs/wiki/raw/binaryen/2026-04-22-remove-unused-module-elements-primary-sources.md`

### Refreshed living pages and catalogs

- `docs/wiki/binaryen/passes/remove-unused-module-elements/index.md`
- `docs/wiki/binaryen/passes/remove-unused-module-elements/starshine-hot-ir-strategy.md`
- `docs/wiki/binaryen/passes/remove-unused-module-elements/retention-and-index-rewrites.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/index.md`
- `docs/wiki/log.md`

## Maintenance rule going forward

If future `remove-unused-module-elements` work needs a quick provenance anchor plus a practical Starshine read-along path, start with:

1. `docs/wiki/raw/binaryen/2026-04-22-remove-unused-module-elements-primary-sources.md`
2. `docs/wiki/binaryen/passes/remove-unused-module-elements/index.md`
3. `docs/wiki/binaryen/passes/remove-unused-module-elements/starshine-hot-ir-strategy.md`
4. `docs/wiki/binaryen/passes/remove-unused-module-elements/retention-and-index-rewrites.md`
5. `src/passes/remove_unused_module_elements.mbt`

That path now gives a clean bridge from official Binaryen release/source/test surfaces to the exact current MoonBit module-pass implementation and its local rewrite/test boundaries.
