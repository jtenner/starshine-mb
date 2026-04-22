---
kind: research
status: supported
last_reviewed: 2026-04-22
sources:
  - ../binaryen/2026-04-22-once-reduction-primary-sources.md
  - ../../binaryen/passes/once-reduction/index.md
  - ../../binaryen/passes/once-reduction/binaryen-strategy.md
  - ../../binaryen/passes/once-reduction/implementation-structure-and-tests.md
  - ../../binaryen/passes/once-reduction/dominance-propagation-and-cycle-safety.md
  - ../../binaryen/passes/once-reduction/wat-shapes.md
  - ../../binaryen/passes/once-reduction/starshine-hot-ir-strategy.md
  - ../../binaryen/passes/once-reduction/parity.md
  - ../../../../src/passes/once_reduction.mbt
  - ../../../../src/passes/once_reduction_test.mbt
  - ../../../../src/passes/pass_manager.mbt
  - ../../../../src/passes/optimize.mbt
  - ../../../../src/passes/registry_test.mbt
  - ../../../../src/cmd/cmd_wbtest.mbt
---

# `once-reduction` primary-source and code-map follow-up

## Why this follow-up exists

The existing `once-reduction` dossier was already solid on both the upstream algorithm and the local Starshine subset.
However, it still had two durable gaps:

- it lacked an immutable raw primary-source manifest
- several touched pages still described freshness only through the older 2026-04-20/2026-04-21 local wording instead of anchoring the folder to a single reviewed official release/source/test capture

This follow-up closes the provenance gap, re-anchors the folder to an immutable 2026-04-22 Binaryen source capture, and refreshes the touched living pages so beginners and advanced readers can follow the same source-to-code-map path without reconstructing provenance from scattered links.

## Primary sources rechecked in this run

Captured immutably in:

- `docs/wiki/raw/binaryen/2026-04-22-once-reduction-primary-sources.md`

The most important reviewed surfaces were:

- the official Binaryen GitHub release page for `version_129`
- the GitHub releases index
- `OnceReduction.cpp` on `version_129` and `main`
- `pass.cpp`
- `intrinsics.h`
- the dedicated `once-reduction.wast` file on `version_129` and `main`

## Local Starshine code surfaces rechecked

- `src/passes/once_reduction.mbt`
- `src/passes/once_reduction_test.mbt`
- `src/passes/pass_manager.mbt`
- `src/passes/optimize.mbt`
- `src/passes/registry_test.mbt`
- `src/cmd/cmd_wbtest.mbt`

## Durable findings

### 1. The dossier gap was provenance, not missing pass-coverage structure

The folder already had the required living pieces:

- pass overview
- Binaryen strategy
- implementation/test map
- dedicated transformed-shape catalog
- Starshine strategy/code-map page
- parity page

So this run did not need to invent a new `once-reduction` structure.
It needed to make the existing structure easier to trust and easier to navigate by adding an immutable official-source capture and threading that capture back through the living pages.

### 2. The reviewed upstream `@binaryen.idempotent` path is still real and still easy to miss

The new raw-source manifest keeps one high-value teaching point explicit:

- `OnceReduction.cpp` still checks `Intrinsics::getAnnotations(func.get()).idempotent`
- it still assigns a fake once-global with `Names::getValidGlobalName(...)`
- the dedicated `once-reduction.wast` file still does not foreground that path directly

That means the current dossier should continue teaching the idempotent path as a real upstream feature whose main proof surface is the source itself, not as a speculative or maybe-stale side note.

### 3. The local Starshine code map remains the practical read-along path for the in-tree subset

Rechecking the MoonBit implementation reconfirmed the exact local bridge from docs to code:

- `src/passes/once_reduction.mbt` owns the matcher, scan, recursive summary propagation, rewrite, tiny wrapper cleanup, and end-to-end module pass
- `src/passes/pass_manager.mbt` owns module-pass dispatch
- `src/passes/optimize.mbt` owns registry and preset placement
- `src/passes/registry_test.mbt` locks the module-pass classification
- `src/cmd/cmd_wbtest.mbt` keeps explicit CLI coverage
- `src/passes/once_reduction_test.mbt` holds the focused local proof surface

The important teaching boundary is unchanged:

- Starshine is still a recursive boundary-array once-bit subset
- upstream Binaryen is still the broader CFG/dominator plus idempotent-annotation pass

### 4. The touched folder should now cite 2026-04-22 provenance directly instead of leaving it implicit

Before this run, the folder's claims were good but the freshness story was scattered across older research notes and direct GitHub links.
After this run, the folder can point readers to one immutable provenance source that records:

- the reviewed official release page date for `version_129` (**2026-04-01**)
- the exact source/test URLs reviewed on 2026-04-22
- the narrow no-drift current-`main` spot check for the key `OnceReduction.cpp` idempotent and wrapper-cleanup surfaces plus the dedicated `once-reduction.wast` nonconstant-initializer surface

## Files changed because of this follow-up

### New raw-source manifest

- `docs/wiki/raw/binaryen/2026-04-22-once-reduction-primary-sources.md`

### New research note

- `docs/wiki/raw/research/0256-2026-04-22-once-reduction-primary-sources-and-code-map-followup.md`

### Refreshed living pages and catalogs

- `docs/wiki/binaryen/passes/once-reduction/index.md`
- `docs/wiki/binaryen/passes/once-reduction/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/once-reduction/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/once-reduction/dominance-propagation-and-cycle-safety.md`
- `docs/wiki/binaryen/passes/once-reduction/wat-shapes.md`
- `docs/wiki/binaryen/passes/once-reduction/starshine-hot-ir-strategy.md`
- `docs/wiki/binaryen/passes/once-reduction/parity.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/index.md`
- `docs/wiki/log.md`

## Maintenance rule going forward

If future `once-reduction` work needs a clean provenance-plus-code-map path, start with:

1. `docs/wiki/raw/binaryen/2026-04-22-once-reduction-primary-sources.md`
2. `docs/wiki/binaryen/passes/once-reduction/index.md`
3. `docs/wiki/binaryen/passes/once-reduction/binaryen-strategy.md`
4. `docs/wiki/binaryen/passes/once-reduction/implementation-structure-and-tests.md`
5. `docs/wiki/binaryen/passes/once-reduction/dominance-propagation-and-cycle-safety.md`
6. `docs/wiki/binaryen/passes/once-reduction/wat-shapes.md`
7. `docs/wiki/binaryen/passes/once-reduction/starshine-hot-ir-strategy.md`
8. `docs/wiki/binaryen/passes/once-reduction/parity.md`
9. `src/passes/once_reduction.mbt`
10. `src/passes/once_reduction_test.mbt`
11. `src/passes/pass_manager.mbt`
12. `src/passes/optimize.mbt`
13. `src/passes/registry_test.mbt`
14. `src/cmd/cmd_wbtest.mbt`

That path now gives a clean bridge from official Binaryen release/source/test surfaces to the exact in-tree MoonBit matcher, recursive summary/rewrite engine, wrapper-cleanup subset, preset wiring, registry coverage, and the explicit statement that Starshine remains narrower than upstream Binaryen's full CFG/dominator plus idempotent-annotation contract.
