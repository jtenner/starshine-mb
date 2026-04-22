---
kind: research
status: supported
last_reviewed: 2026-04-22
sources:
  - ../binaryen/2026-04-22-dead-code-elimination-primary-sources.md
  - ../../binaryen/passes/dead-code-elimination/index.md
  - ../../binaryen/passes/dead-code-elimination/binaryen-strategy.md
  - ../../binaryen/passes/dead-code-elimination/implementation-structure-and-tests.md
  - ../../binaryen/passes/dead-code-elimination/typed-control-voidification-and-eh.md
  - ../../binaryen/passes/dead-code-elimination/wat-shapes.md
  - ../../binaryen/passes/dead-code-elimination/starshine-hot-ir-strategy.md
  - ../../../../src/passes/dead_code_elimination.mbt
  - ../../../../src/passes/pass_manager.mbt
  - ../../../../src/passes/optimize.mbt
  - ../../../../src/passes/dead_code_elimination_test.mbt
  - ../../../../src/passes/dead_code_elimination_live_repro_test.mbt
  - ../../../../src/passes/perf_test.mbt
  - ../../../../src/cmd/cmd_wbtest.mbt
---

# `dead-code-elimination` primary-source and code-map follow-up

## Why this follow-up exists

The living `dead-code-elimination` dossier was already strong on the upstream algorithm correction and on the key transformed-shape teaching.
Two practical gaps still remained:

- the folder still lacked an immutable raw primary-source manifest
- the Starshine page still described the local HOT strategy honestly, but it did not yet give readers a compact exact code map for the MoonBit owner file, raw-skip heuristics, writeback guards, and focused proof lanes

This follow-up closes that provenance-and-navigation gap without claiming the earlier dossier lacked a real overview, Binaryen strategy page, transformed-shape page, or Starshine strategy page.

## Sources re-checked in this run

### Upstream Binaryen primary sources

Captured immutably in:

- `docs/wiki/raw/binaryen/2026-04-22-dead-code-elimination-primary-sources.md`

The most important reviewed surfaces were:

- the official Binaryen GitHub release pages for `version_129`
- `DeadCodeElimination.cpp` on `version_129` and `main`
- `pass.cpp` on `version_129` and `main`
- the dedicated `dce_all-features`, combo-neighbor, EH, legacy-EH, and stack-switching lit files

### Local Starshine code surfaces re-checked

- `src/passes/dead_code_elimination.mbt`
- `src/passes/pass_manager.mbt`
- `src/passes/optimize.mbt`
- `src/passes/dead_code_elimination_test.mbt`
- `src/passes/dead_code_elimination_live_repro_test.mbt`
- `src/passes/perf_test.mbt`
- `src/cmd/cmd_wbtest.mbt`

## Durable findings

### 1. The release anchoring is now explicit instead of implicit

The earlier dossier already treated `version_129` as the upstream oracle, but it did not preserve the exact release-page provenance in the raw-source system.
The 2026-04-22 capture now records that the reviewed official release page for `version_129` showed publish date **2026-04-01**, and that the releases index was re-checked on the same day.

### 2. The local teaching gap was navigation, not missing pass pages

The folder already had the required living pass pages:

- overview/landing page
- Binaryen strategy page
- transformed-shapes page
- Starshine strategy page
- supporting implementation/test map

What was still missing was a compact read-along answer to:

- where is the local descriptor and summary?
- where does the real HOT rewrite live?
- which helper clusters own branch-user, fallthrough, purity, payload-forwarder, and tail-repair behavior?
- where do raw-skip heuristics and writeback guards live?
- which tests lock the current local contract?

That exact navigation layer is what this follow-up adds.

### 3. Current Starshine `dead-code-elimination` is still broader than upstream Binaryen `dce`

Re-checking the local code confirmed the earlier correction remains important.
Upstream Binaryen `version_129` `dce` is still the smaller unreachable-shape postwalk.
Current Starshine still owns a broader HOT rewrite family, including:

- branch-user, fallthrough, purity, and node-use caches
- branch-payload-forwarder rewrites
- split-`local.set` wrapper rewrites
- dropped-control voidification helpers
- explicit nonfallthrough tail repair
- raw-skip heuristics in the hot pipeline manager
- writeback-validation and suspicious-carrier guard rails in the pipeline manager

That contrast should stay explicit in the living docs.

### 4. The local proof surface is broader than one pass-local test file

The exact code map made one practical point clearer:
local DCE behavior is not proven only by `dead_code_elimination_test.mbt`.
The real proof surface today spans:

- `dead_code_elimination_test.mbt` for the main HOT rewrite families
- `dead_code_elimination_live_repro_test.mbt` for extracted artifact-sensitive carriers and typed loop-input drops
- `perf_test.mbt` for raw-skip boundaries and skip-trace behavior
- `cmd_wbtest.mbt` for CLI flag resolution and debug-artifact replay

That matters because future readers can now follow pass behavior from the core file directly into the exact focused tests.

## Files changed because of this follow-up

### New raw-source manifest

- `docs/wiki/raw/binaryen/2026-04-22-dead-code-elimination-primary-sources.md`

### Refreshed living pages and catalogs

- `docs/wiki/binaryen/passes/dead-code-elimination/index.md`
- `docs/wiki/binaryen/passes/dead-code-elimination/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/dead-code-elimination/starshine-hot-ir-strategy.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/index.md`
- `docs/wiki/log.md`

## Maintenance rule going forward

If future `dead-code-elimination` work needs a quick provenance anchor plus a practical Binaryen/Starshine read-along path, start with:

1. `docs/wiki/raw/binaryen/2026-04-22-dead-code-elimination-primary-sources.md`
2. `docs/wiki/binaryen/passes/dead-code-elimination/index.md`
3. `docs/wiki/binaryen/passes/dead-code-elimination/implementation-structure-and-tests.md`
4. `docs/wiki/binaryen/passes/dead-code-elimination/starshine-hot-ir-strategy.md`
5. `src/passes/dead_code_elimination.mbt`
6. `src/passes/pass_manager.mbt`
7. `src/passes/dead_code_elimination_test.mbt`
8. `src/passes/dead_code_elimination_live_repro_test.mbt`
9. `src/passes/perf_test.mbt`
10. `src/cmd/cmd_wbtest.mbt`

That path now gives a clean bridge from official Binaryen release/source/test surfaces to the exact current MoonBit implementation, the local raw-skip and writeback-guard behavior, the focused test evidence, and the honest semantic gap between the current HOT rewrite family and upstream Binaryen's smaller `TypeUpdater`-centered pass.
