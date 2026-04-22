---
kind: research
status: supported
last_reviewed: 2026-04-22
sources:
  - ../binaryen/2026-04-22-reorder-locals-primary-sources.md
  - ../../binaryen/passes/reorder-locals/index.md
  - ../../binaryen/passes/reorder-locals/binaryen-strategy.md
  - ../../binaryen/passes/reorder-locals/implementation-structure-and-tests.md
  - ../../binaryen/passes/reorder-locals/names-roundtrip-and-porting.md
  - ../../binaryen/passes/reorder-locals/wat-shapes.md
  - ../../binaryen/passes/reorder-locals/starshine-hot-ir-strategy.md
  - ../../binaryen/passes/reorder-locals/parity.md
  - ../../binaryen/passes/reorder-locals/multivalue-call-scope.md
  - ../../../../src/passes/reorder_locals.mbt
  - ../../../../src/passes/reorder_locals_test.mbt
  - ../../../../src/passes/pass_manager.mbt
  - ../../../../src/passes/optimize.mbt
  - ../../../../src/passes/optimize_test.mbt
  - ../../../../src/passes/registry_test.mbt
  - ../../../../src/cmd/cmd_wbtest.mbt
---

# `reorder-locals` primary-source and code-map follow-up

## Why this follow-up exists

The living `reorder-locals` dossier already had the required overview, shape catalog, Binaryen strategy page, Starshine strategy page, parity page, and multivalue-scope decision.
Two practical gaps still remained:

- the folder still lacked an immutable raw primary-source manifest
- the Binaryen side still lacked a compact implementation/test-map page that future readers could use as a read-along bridge from the tiny upstream source to the dossier's broader parity and porting notes

This follow-up closes that provenance-and-navigation gap without claiming the earlier folder lacked a real pass overview or real Binaryen/Starshine strategy coverage.

## Sources re-checked in this run

### Upstream Binaryen primary sources

Captured immutably in:

- `docs/wiki/raw/binaryen/2026-04-22-reorder-locals-primary-sources.md`

The most important reviewed surfaces were:

- the official Binaryen GitHub release page for `version_129`
- the GitHub releases index
- `ReorderLocals.cpp` on `version_129` and `main`
- `pass.cpp`
- the dedicated `reorder-locals*` and `reorder-locals_print_roundtrip*` test pairs
- `wasm-ir-builder.cpp` and `wasm-stack.cpp` only for the already-known non-pass-local multivalue-call writeback boundary

### Local Starshine code surfaces re-checked

- `src/passes/reorder_locals.mbt`
- `src/passes/reorder_locals_test.mbt`
- `src/passes/pass_manager.mbt`
- `src/passes/optimize.mbt`
- `src/passes/optimize_test.mbt`
- `src/passes/registry_test.mbt`
- `src/cmd/cmd_wbtest.mbt`

## Durable findings

### 1. Release anchoring is now explicit instead of only implicit

The older dossier already treated Binaryen `version_129` as the upstream oracle.
This run adds the missing raw-source provenance and records the reviewed official release-page date explicitly:

- on 2026-04-22, the official GitHub `version_129` release page showed publish date **2026-04-01**

That is now preserved in the raw-source layer instead of only being inferable from living prose.

### 2. The upstream owner surface is even smaller than the pass name suggests

Re-checking `ReorderLocals.cpp` confirmed that the real upstream contract is still concentrated in one tiny owner file:

- a local-user `ReIndexer`
- one function-parallel access-count plus first-use sorter
- one zero-count body-local truncation step
- one local-name-map repair step

That small owner surface is now called out directly in the new implementation/test-map page so future readers do not have to re-derive it from the broader strategy page.

### 3. The dedicated tests prove two different halves of the contract

The re-checked test files reinforce an important split that was previously present in the folder but not summarized compactly enough:

- `reorder-locals.wast` and `.txt` prove parameter stability, hot-local ordering, tee/write counting, and zero-count tail trimming
- `reorder-locals_print_roundtrip.wast` and `.txt` prove that local declaration order and names remain visible and correct after print/write roundtrips

That distinction matters for future ports because it makes clear that `reorder-locals` is not only an in-memory comparator.
It also has an externally visible metadata and roundtrip contract.

### 4. The local Starshine teaching gap was provenance plus navigation, not missing strategy pages

The local dossier already had the essential living pages.
What was still awkward was answering questions like:

- where is the exact public summary and registry entry?
- where is the actual recursive local-user scan?
- where are the ordering and grouped-run rebuild helpers?
- where are local-name repair and raw-name-payload invalidation handled?
- where is module-pass dispatch proven?
- which tests lock down preset exclusion, registry category, CLI entry, and name repair?

This follow-up turns those answers into a compact exact code map instead of leaving them spread across chat history and multiple file reads.

### 5. The remaining parity caveat is still a Binaryen boundary issue, not a sorter drift issue

Re-checking the upstream supporting boundary files kept the old conclusion intact:

- `wasm-ir-builder.cpp` and `wasm-stack.cpp` still own the tuple scratch-local packaging and emitted-local expansion that explain the stubborn multivalue-call drift
- `ReorderLocals.cpp` itself still remains the small local-sorter-plus-name-repair pass already described by the folder

So the new raw-source capture strengthens the existing scope decision rather than changing it.

## Files changed because of this follow-up

### New raw-source manifest

- `docs/wiki/raw/binaryen/2026-04-22-reorder-locals-primary-sources.md`

### New research note

- `docs/wiki/raw/research/0253-2026-04-22-reorder-locals-primary-sources-and-code-map-followup.md`

### New living page

- `docs/wiki/binaryen/passes/reorder-locals/implementation-structure-and-tests.md`

### Refreshed living pages and catalogs

- `docs/wiki/binaryen/passes/reorder-locals/index.md`
- `docs/wiki/binaryen/passes/reorder-locals/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/reorder-locals/names-roundtrip-and-porting.md`
- `docs/wiki/binaryen/passes/reorder-locals/starshine-hot-ir-strategy.md`
- `docs/wiki/binaryen/passes/reorder-locals/parity.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/index.md`
- `docs/wiki/log.md`

## Maintenance rule going forward

If future `reorder-locals` work needs a quick provenance anchor plus a practical Binaryen/Starshine read-along path, start with:

1. `docs/wiki/raw/binaryen/2026-04-22-reorder-locals-primary-sources.md`
2. `docs/wiki/binaryen/passes/reorder-locals/index.md`
3. `docs/wiki/binaryen/passes/reorder-locals/implementation-structure-and-tests.md`
4. `docs/wiki/binaryen/passes/reorder-locals/binaryen-strategy.md`
5. `docs/wiki/binaryen/passes/reorder-locals/names-roundtrip-and-porting.md`
6. `docs/wiki/binaryen/passes/reorder-locals/starshine-hot-ir-strategy.md`
7. `docs/wiki/binaryen/passes/reorder-locals/parity.md`
8. `src/passes/reorder_locals.mbt`
9. `src/passes/reorder_locals_test.mbt`
10. `src/passes/pass_manager.mbt`
11. `src/passes/optimize.mbt`
12. `src/passes/optimize_test.mbt`
13. `src/passes/registry_test.mbt`
14. `src/cmd/cmd_wbtest.mbt`

That path now gives a clean bridge from official Binaryen release/source/test surfaces to the exact current MoonBit implementation, the visible local metadata/writeback boundary work, the explicit module-pass scheduler surface, the focused proof lanes, and the standing rule that multivalue-call writeback drift is outside the current pass-parity scope.
