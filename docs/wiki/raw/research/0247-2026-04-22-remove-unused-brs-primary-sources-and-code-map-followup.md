---
kind: research
status: supported
last_reviewed: 2026-04-22
sources:
  - ../binaryen/2026-04-22-remove-unused-brs-primary-sources.md
  - ../../binaryen/passes/remove-unused-brs/index.md
  - ../../binaryen/passes/remove-unused-brs/binaryen-strategy.md
  - ../../binaryen/passes/remove-unused-brs/implementation-structure-and-tests.md
  - ../../binaryen/passes/remove-unused-brs/wat-shapes.md
  - ../../binaryen/passes/remove-unused-brs/starshine-hot-ir-strategy.md
  - ../../binaryen/passes/remove-unused-brs/parity.md
  - ../../../../src/passes/remove_unused_brs.mbt
  - ../../../../src/passes/pass_manager.mbt
  - ../../../../src/passes/optimize.mbt
  - ../../../../src/passes/remove_unused_brs_test.mbt
  - ../../../../src/passes/perf_test.mbt
  - ../../../../src/passes/optimize_test.mbt
  - ../../../../src/cmd/cmd_wbtest.mbt
---

# `remove-unused-brs` primary-source and Starshine code-map follow-up

## Why this follow-up exists

The living `remove-unused-brs` dossier was already a strong beginner-to-advanced explanation after the 2026-04-20 research pass, but two practical gaps remained:

- the folder still lacked an immutable raw primary-source manifest like the newer implemented-pass dossiers now carry
- the local Starshine strategy page still explained the two-layer HOT architecture accurately at a high level, but it did not yet give readers the exact MoonBit registry / preset / dispatcher / helper-cluster / test map needed for fast code navigation

This follow-up closes that narrower provenance-and-navigation gap without claiming the folder previously lacked a real Binaryen or Starshine dossier.

## Sources re-checked in this run

### Upstream Binaryen primary sources

Captured immutably in:

- `docs/wiki/raw/binaryen/2026-04-22-remove-unused-brs-primary-sources.md`

The key reviewed surfaces were:

- official Binaryen GitHub release pages for `version_129`
- `RemoveUnusedBrs.cpp` on both `version_129` and `main`
- `pass.cpp`, `branch-utils.h`, `branch-hints.h`, and `effects.h`
- the dedicated `remove-unused-brs.wast`, `remove-unused-brs-gc.wast`, `remove-unused-brs-eh.wast`, and `remove-unused-brs_branch-hints-unconditionalize.wast` lit files

### Local Starshine code surfaces re-checked

- `src/passes/remove_unused_brs.mbt`
- `src/passes/pass_manager.mbt`
- `src/passes/optimize.mbt`
- `src/passes/remove_unused_brs_test.mbt`
- `src/passes/perf_test.mbt`
- `src/passes/optimize_test.mbt`
- `src/cmd/cmd_wbtest.mbt`

## Durable findings

### 1. The release anchoring is now explicit instead of implied

The earlier dossier already treated `version_129` as the Binaryen oracle, but it did not yet preserve the exact release-page provenance in the raw-source system.
The 2026-04-22 capture now records that the reviewed official release page for `version_129` showed publish date **2026-04-01**, and that the releases index was re-checked on the same day.

That gives the folder a stable provenance anchor instead of relying only on interpreted living pages.

### 2. The most useful local teaching upgrade was an exact code map

Re-checking the MoonBit implementation confirmed that the cleanest read-along path is:

1. registry descriptor and summary in `src/passes/remove_unused_brs.mbt`, active hot-pass registration in `src/passes/optimize.mbt`, and repeated preset placement in the local `optimize` / `shrink` pass lists
2. raw pre-lift decision-ladder rewrite and skip-family dispatch in `src/passes/pass_manager.mbt`
3. lifted summary scanning, per-cycle scan recomputation, region visitation, and the main rewrite helpers in `src/passes/remove_unused_brs.mbt`
4. focused pass, perf, preset-slot, and CLI replay coverage in the local test files

The older Starshine strategy page was directionally right, but it was too vague about where each major part actually lives.

### 3. Current Starshine is best taught as a two-stage raw-plus-HOT proof stack, not as a literal `RemoveUnusedBrs.cpp` port

The local files still clearly center on:

- raw no-lift classifiers and one cheap raw decision-ladder normalization in `pass_manager.mbt`
- a lifted HOT summary scan used for multiple no-op classifiers
- a per-cycle `label_refs` + branch-payload-child + `has_br_table` scan
- region-root rewrite ordering in `remove_unused_brs_visit_region(...)`
- a large family of narrowly guarded structural rewrites over HOT labels, holders, result arities, and return contexts

That code map makes the main local-vs-upstream difference easier to teach honestly:

- upstream Binaryen uses an AST postwalk plus helper classes inside `RemoveUnusedBrs.cpp`
- current Starshine uses a raw prefilter layer plus a HOT-region fixpoint with explicit cycle scans, context bits, and writeback-sensitive structural guards

### 4. The local evidence surface is broader than one focused pass file, and the CLI lanes are part of the contract

The re-check showed that the strongest local proof surface is spread across:

- `src/passes/remove_unused_brs_test.mbt` for reduced structural rewrites and legality-preservation cases
- `src/passes/perf_test.mbt` for raw/hot skip behavior and trace-guided cost-control families
- `src/passes/optimize_test.mbt` for repeated preset-slot exposure in `optimize` / `shrink`
- `src/cmd/cmd_wbtest.mbt` for direct `--remove-unused-brs` artifact and extracted-function replay lanes

That is a useful clarification because the older page mentioned artifact and perf history, but it did not point readers to the exact current owner files.

## Files changed because of this follow-up

### New raw-source manifest

- `docs/wiki/raw/binaryen/2026-04-22-remove-unused-brs-primary-sources.md`

### Refreshed living pages and catalogs

- `docs/wiki/binaryen/passes/remove-unused-brs/index.md`
- `docs/wiki/binaryen/passes/remove-unused-brs/starshine-hot-ir-strategy.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/index.md`
- `docs/wiki/log.md`

## Maintenance rule going forward

If future `remove-unused-brs` work needs a quick provenance anchor plus a practical Starshine read-along path, start with:

1. `docs/wiki/raw/binaryen/2026-04-22-remove-unused-brs-primary-sources.md`
2. `docs/wiki/binaryen/passes/remove-unused-brs/index.md`
3. `docs/wiki/binaryen/passes/remove-unused-brs/starshine-hot-ir-strategy.md`
4. `src/passes/pass_manager.mbt`
5. `src/passes/remove_unused_brs.mbt`
6. `src/passes/remove_unused_brs_test.mbt`
7. `src/passes/perf_test.mbt`
8. `src/cmd/cmd_wbtest.mbt`

That path now gives a clean bridge from official Binaryen release/source/test surfaces to the exact current MoonBit implementation, its focused local evidence surface, and the honest boundary between current HOT-region behavior and the upstream structured-control cleanup contract.
