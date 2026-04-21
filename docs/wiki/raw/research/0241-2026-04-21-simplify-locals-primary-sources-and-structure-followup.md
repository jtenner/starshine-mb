---
kind: research
status: supported
last_reviewed: 2026-04-21
sources:
  - ../binaryen/2026-04-21-simplify-locals-primary-sources.md
  - ../../binaryen/passes/simplify-locals/index.md
  - ../../binaryen/passes/simplify-locals/binaryen-strategy.md
  - ../../binaryen/passes/simplify-locals/wat-shapes.md
  - ../../../../src/passes/simplify_locals.mbt
  - ../../../../src/passes/pass_manager.mbt
  - ../../../../src/passes/simplify_locals_test.mbt
  - ../../../../src/passes/pass_manager_wbtest.mbt
  - ../../../../src/passes_perf_long/simplify_locals_multivalue_perf_test.mbt
---

# `simplify-locals` primary-source and structure-result follow-up

## Why this follow-up exists

The living `simplify-locals` dossier was already deep, but one practical teaching gap remained:

- the folder did not yet have an immutable primary-source manifest like the newer `ssa-nomerge` work
- the folder still spread the most important structure-result bridge across multiple pages instead of giving readers one compact Binaryen-to-Starshine map for block/if/loop carrier cleanup
- two of the most Starshine-specific local pages still carried older `last_reviewed` metadata and older source lists even though the upstream dossier around them had been refreshed on 2026-04-21

This follow-up closes that narrower but still worthwhile documentation gap without pretending the pass lacked a dossier.

## Sources re-checked in this run

### Upstream Binaryen primary sources

Captured immutably in:

- `docs/wiki/raw/binaryen/2026-04-21-simplify-locals-primary-sources.md`

The key reviewed surfaces were:

- official Binaryen GitHub release pages for `version_129`
- `SimplifyLocals.cpp` on both `version_129` and `main`
- `pass.cpp`, `opt-utils.h`, `pass.h`, and the core helper headers already referenced by the dossier
- the main effect/GC/EH/string/table/flatness lit files already used by the living folder

### Local Starshine code surfaces re-checked

- `src/passes/simplify_locals.mbt`
- `src/passes/pass_manager.mbt`
- `src/passes/simplify_locals_test.mbt`
- `src/passes/pass_manager_wbtest.mbt`
- `src/passes_perf_long/simplify_locals_multivalue_perf_test.mbt`

## Durable findings

### 1. Release anchoring is cleaner now than the older folder wording implied

Earlier nearby wiki work had to preserve release-order uncertainty for some Binaryen surfaces.
For `simplify-locals`, the 2026-04-21 GitHub release pages reviewed in this run showed `version_129` as the latest release page, with publish date **2026-04-01**.

So the simplify-locals dossier can now say a stronger, simpler thing:

- use `version_129` as the released oracle for this pass family
- use current `main` only for narrow drift checks

### 2. The checked current-`main` drift still stays tiny and bookkeeping-only

The reviewed `main` `SimplifyLocals.cpp` surface still matched the tagged `version_129` algorithm on the teaching-relevant pieces used by the dossier.
The visible drift on the inspected file was the bookkeeping-container cleanup:

- `blockBreaks`: `std::map` -> `std::unordered_map`
- `unoptimizableBlocks`: `std::set` -> `std::unordered_set`

That keeps the existing dossier rule intact:

- treat `version_129` as the semantic contract
- mention current-`main` only when drift is more than tiny container cleanup

### 3. The most useful beginner-to-advanced bridge is still the structure-result family

The most reusable single bridge between the upstream and local implementations is the structure-result carrier family:

- block exits that all write the same local
- if/else arms that compute the same later local value
- one-armed `if` rewrites that are only legal for defaultable locals
- narrow loop-tail lifting
- the local Starshine wrapper-forwarder cleanup that repairs real debug-artifact carriers near the same family of shapes

Those concepts already existed in pieces across the folder, but the dossier was more navigable after collecting them into one compact page that points directly at both the upstream and in-tree helper clusters.

### 4. The local code map already had the right helpers; the missing part was the bridge page

The current in-tree MoonBit helpers already make the structure cluster fairly explicit:

- `simplify_locals_try_rewrite_block_return`
- `simplify_locals_try_rewrite_if_return`
- `simplify_locals_try_rewrite_loop_return`
- `simplify_locals_try_rewrite_nested_one_armed_if_child`
- `simplify_locals_try_rewrite_split_local_set_wrapper_forwarder`
- `simplify_locals_run_structure_rewrites`

The main reduced tests were already present too, especially the block / if / loop / one-armed cases in `src/passes/simplify_locals_test.mbt` and the debug-artifact wrapper/carrier cases in `src/passes/pass_manager_wbtest.mbt`.

So the useful change here was not “invent a new local strategy.”
It was “make the existing strategy easier to follow from shape -> upstream source family -> MoonBit helper -> local tests.”

## Files changed because of this follow-up

### New raw-source manifest

- `docs/wiki/raw/binaryen/2026-04-21-simplify-locals-primary-sources.md`

### New living page

- `docs/wiki/binaryen/passes/simplify-locals/structure-result-lifting-and-carrier-cleanup.md`

### Refreshed living pages and catalogs

- `docs/wiki/binaryen/passes/simplify-locals/index.md`
- `docs/wiki/binaryen/passes/simplify-locals/starshine-hot-ir-strategy.md`
- `docs/wiki/binaryen/passes/simplify-locals/implementation-map.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/index.md`
- `docs/wiki/log.md`

## Maintenance rule going forward

If future `simplify-locals` work needs a quick primary-source anchor or a compact explanation of the structure-result families, start with:

1. `docs/wiki/raw/binaryen/2026-04-21-simplify-locals-primary-sources.md`
2. `docs/wiki/binaryen/passes/simplify-locals/structure-result-lifting-and-carrier-cleanup.md`
3. `docs/wiki/binaryen/passes/simplify-locals/implementation-map.md`
4. `docs/wiki/binaryen/passes/simplify-locals/starshine-hot-ir-strategy.md`

That path now gives a clean beginner-to-advanced bridge from official Binaryen release/source/test surfaces to the exact MoonBit helper clusters and local regression lanes.
