---
kind: research
status: supported
last_reviewed: 2026-04-22
sources:
  - ../binaryen/2026-04-22-duplicate-function-elimination-primary-sources.md
  - ../../binaryen/passes/duplicate-function-elimination/index.md
  - ../../binaryen/passes/duplicate-function-elimination/binaryen-strategy.md
  - ../../binaryen/passes/duplicate-function-elimination/wat-shapes.md
  - ../../binaryen/passes/duplicate-function-elimination/type-compaction-and-metadata.md
  - ../../../../src/passes/duplicate_function_elimination.mbt
  - ../../../../src/passes/pass_manager.mbt
  - ../../../../src/passes/optimize.mbt
  - ../../../../src/passes/duplicate_function_elimination_test.mbt
  - ../../../../src/cmd/cmd_wbtest.mbt
---

# `duplicate-function-elimination` primary-source and Starshine code-map follow-up

## Why this follow-up exists

The living `duplicate-function-elimination` dossier was already good on the upstream side after the 2026-04-20 refresh, but two practical gaps remained:

- the folder still lacked an immutable raw primary-source manifest like the newer dossiers now carry
- the local Starshine strategy page still explained the module-pass split only at a high level, without a clear exact code-location map for the current MoonBit implementation

This follow-up closes that narrower documentation gap without claiming the folder lacked a real dossier.

## Sources re-checked in this run

### Upstream Binaryen primary sources

Captured immutably in:

- `docs/wiki/raw/binaryen/2026-04-22-duplicate-function-elimination-primary-sources.md`

The key reviewed surfaces were:

- official Binaryen GitHub release pages for `version_129`
- `DuplicateFunctionElimination.cpp` on both `version_129` and `main`
- `pass.cpp`, `function-utils.h`, `hashed.h`, and `opt-utils.h`
- the dedicated all-features / annotations / branch-hints / optimize-level lit files already used by the living dossier

### Local Starshine code surfaces re-checked

- `src/passes/duplicate_function_elimination.mbt`
- `src/passes/pass_manager.mbt`
- `src/passes/optimize.mbt`
- `src/passes/duplicate_function_elimination_test.mbt`
- `src/cmd/cmd_wbtest.mbt`

## Durable findings

### 1. The release anchoring is now explicit instead of implied

The earlier dossier already used `version_129` as the Binaryen oracle, but it did not yet preserve the exact release-page provenance in the raw-source system.
The 2026-04-22 capture now records that the reviewed official release page for `version_129` showed publish date **2026-04-01**, and that the releases index was re-checked on the same day.

That gives the folder a stable provenance anchor instead of relying only on interpreted living pages.

### 2. The most important local teaching gap was the exact module-pass code map

The existing local strategy page correctly said that Starshine keeps `duplicate-function-elimination` module-scoped, but it still hid the concrete ownership split future maintainers are most likely to need:

- the actual one-round duplicate-detection and rebuild loop
- the separate function-index rewrite helpers
- the separate type-compaction and type-index rewrite engine
- the extra element-canonicalization, name-strip, and annotation-map rewrite surfaces
- the registry/dispatcher/tests that prove the current public contract

This follow-up makes that map explicit.

### 3. Current Starshine remains narrower and broader than Binaryen in different directions

Re-checking the local code confirmed that the same two-way split from the earlier dossier still holds:

- **narrower than upstream Binaryen** on iteration and scheduling: the local implementation still performs one duplicate-elimination iteration and the public `optimize` / `shrink` presets still do not schedule DFE
- **broader than upstream Binaryen** on bundled cleanup: the local pass still canonicalizes compactable element-expression segments, strips the name section, compacts duplicate simple function types after a successful merge, rewrites many type-index-bearing surfaces, and rewrites the function-annotation section

The useful local-doc improvement here was not to discover a new algorithmic gap.
It was to attach those conclusions to exact MoonBit source locations.

### 4. The focused local test map is strong once the code map is visible

The local tests already covered the most important current behaviors, but the folder was not yet surfacing that clearly enough:

- `src/passes/duplicate_function_elimination_test.mbt` locks core function-reference rewrites, the single-pass transitive-unlock limit, typed block/select rewrites during type compaction, element canonicalization, and annotation/name cleanup
- `src/cmd/cmd_wbtest.mbt` locks the explicit CLI pass surface for `--duplicate-function-elimination`
- `src/passes/optimize.mbt` proves the current public registry boundary: DFE is an active module pass but not part of the public optimize/shrink presets today

That combination makes the current Starshine contract easier to teach from beginner through advanced readers.

## Files changed because of this follow-up

### New raw-source manifest

- `docs/wiki/raw/binaryen/2026-04-22-duplicate-function-elimination-primary-sources.md`

### Refreshed living pages and catalogs

- `docs/wiki/binaryen/passes/duplicate-function-elimination/index.md`
- `docs/wiki/binaryen/passes/duplicate-function-elimination/starshine-hot-ir-strategy.md`
- `docs/wiki/binaryen/passes/duplicate-function-elimination/type-compaction-and-metadata.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/index.md`
- `docs/wiki/log.md`

## Maintenance rule going forward

If future `duplicate-function-elimination` work needs a quick provenance anchor plus a practical Starshine read-along path, start with:

1. `docs/wiki/raw/binaryen/2026-04-22-duplicate-function-elimination-primary-sources.md`
2. `docs/wiki/binaryen/passes/duplicate-function-elimination/index.md`
3. `docs/wiki/binaryen/passes/duplicate-function-elimination/starshine-hot-ir-strategy.md`
4. `docs/wiki/binaryen/passes/duplicate-function-elimination/type-compaction-and-metadata.md`
5. `src/passes/duplicate_function_elimination.mbt`

That path now gives a clean bridge from official Binaryen release/source/test surfaces to the exact current MoonBit module-pass implementation and its local extra-cleanup boundaries.
