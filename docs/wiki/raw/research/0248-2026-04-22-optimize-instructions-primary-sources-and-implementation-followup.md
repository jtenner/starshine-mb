---
kind: research
status: supported
last_reviewed: 2026-04-22
sources:
  - ../binaryen/2026-04-22-optimize-instructions-primary-sources.md
  - ../../binaryen/passes/optimize-instructions/index.md
  - ../../binaryen/passes/optimize-instructions/binaryen-strategy.md
  - ../../binaryen/passes/optimize-instructions/implementation-structure-and-tests.md
  - ../../binaryen/passes/optimize-instructions/gc-casts-call_ref-and-trap-sensitive-rewrites.md
  - ../../binaryen/passes/optimize-instructions/wat-shapes.md
  - ../../binaryen/passes/optimize-instructions/starshine-hot-ir-strategy.md
  - ../../../../src/passes/optimize_instructions.mbt
  - ../../../../src/passes/pass_manager.mbt
  - ../../../../src/passes/optimize.mbt
  - ../../../../src/passes/optimize_instructions_test.mbt
  - ../../../../src/passes/registry_test.mbt
  - ../../../../src/cmd/cmd_wbtest.mbt
---

# `optimize-instructions` primary-source and implementation-map follow-up

## Why this follow-up exists

The living `optimize-instructions` dossier was already strong on the upstream algorithm and on the broad local-vs-upstream gap.
Two practical gaps still remained:

- the folder still lacked an immutable raw primary-source manifest
- the folder still lacked a compact upstream implementation/test map and an exact Starshine code-map page that pointed readers to the specific MoonBit helpers and proof lanes

This follow-up closes that provenance-and-navigation gap without claiming the earlier dossier lacked a real overview, shape catalog, or Binaryen strategy page.

## Sources re-checked in this run

### Upstream Binaryen primary sources

Captured immutably in:

- `docs/wiki/raw/binaryen/2026-04-22-optimize-instructions-primary-sources.md`

The most important reviewed surfaces were:

- the official Binaryen GitHub release pages for `version_129`
- `OptimizeInstructions.cpp` on `version_129` and `main`
- `pass.cpp`, `passes.h`, `opt-utils.h`, and the main IR helper headers it depends on
- representative dedicated lit files for the default, sign-extension, bulk-memory, `call_ref`, GC, TNH-GC, multivalue, and branch-hints surfaces

### Local Starshine code surfaces re-checked

- `src/passes/optimize_instructions.mbt`
- `src/passes/pass_manager.mbt`
- `src/passes/optimize.mbt`
- `src/passes/optimize_instructions_test.mbt`
- `src/passes/registry_test.mbt`
- `src/cmd/cmd_wbtest.mbt`

## Durable findings

### 1. The release anchoring is now explicit instead of implicit

The earlier dossier already treated `version_129` as the source oracle, but it did not preserve the exact release-page provenance in the raw-source system.
The 2026-04-22 capture now records that the reviewed official release page for `version_129` showed publish date **2026-04-01**, and that the releases index was re-checked on the same day.

### 2. The missing upstream page was the owner/test map, not another algorithm page

The existing `binaryen-strategy.md` already taught the real `version_129` mechanics well.
The practical missing page was a compact answer to:

- which files actually own the pass contract?
- which lit files prove which parts?

That gap is now closed by the new `implementation-structure-and-tests.md` page.

### 3. The most useful local upgrade was an exact MoonBit code map

Re-checking the local implementation confirmed that the fastest honest read-along path is:

1. registry descriptor, summary, and preset placement in `src/passes/optimize.mbt`
2. main hot-pass dispatch in `src/passes/pass_manager.mbt`
3. the helper clusters in `src/passes/optimize_instructions.mbt`
4. focused reduced tests in `src/passes/optimize_instructions_test.mbt`
5. registry and CLI-visible proof surfaces in `src/passes/registry_test.mbt` and `src/cmd/cmd_wbtest.mbt`

The older local page described the scope accurately, but it did not yet make those navigation points explicit.

### 4. Current Starshine is still best taught as an exact HOT peephole/code-shape port subset plus local artifact-driven cleanup

The current in-tree MoonBit implementation still centers on:

- exact integer constant and `eqz` folding
- compare-to-zero and relational constant canonicalization
- commutative reordering guarded by HOT use-def and loop-input checks
- arithmetic and shift rewrites
- constant-`if` folding
- nested boolean-`if` normalization and `eqz` wrapping
- duplicate-branch collapse in then-regions
- dead-region-suffix cleanup with explicit zero-sentinel and fallback-branch guards

That exact code map makes the local-vs-upstream boundary easier to teach honestly:

- upstream Binaryen is a much broader AST pass with memory, bulk-memory, `call_ref`, GC casts, tuple extraction, and deferred refinalization/EH repair
- current Starshine is an implemented HOT subset with some additional local control/writeback guards that are driven by this repo's artifact history rather than by a literal upstream phase mirror

## Files changed because of this follow-up

### New raw-source manifest

- `docs/wiki/raw/binaryen/2026-04-22-optimize-instructions-primary-sources.md`

### New living page

- `docs/wiki/binaryen/passes/optimize-instructions/implementation-structure-and-tests.md`

### Refreshed living pages and catalogs

- `docs/wiki/binaryen/passes/optimize-instructions/index.md`
- `docs/wiki/binaryen/passes/optimize-instructions/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/optimize-instructions/starshine-hot-ir-strategy.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/index.md`
- `docs/wiki/log.md`

## Maintenance rule going forward

If future `optimize-instructions` work needs a quick provenance anchor plus a practical Binaryen/Starshine read-along path, start with:

1. `docs/wiki/raw/binaryen/2026-04-22-optimize-instructions-primary-sources.md`
2. `docs/wiki/binaryen/passes/optimize-instructions/index.md`
3. `docs/wiki/binaryen/passes/optimize-instructions/implementation-structure-and-tests.md`
4. `docs/wiki/binaryen/passes/optimize-instructions/starshine-hot-ir-strategy.md`
5. `src/passes/optimize_instructions.mbt`
6. `src/passes/optimize_instructions_test.mbt`
7. `src/cmd/cmd_wbtest.mbt`

That path now gives a clean bridge from official Binaryen release/source/test surfaces to the exact current MoonBit implementation, its focused local evidence surface, and the honest boundary between the current HOT subset and upstream Binaryen's far larger pass contract.
