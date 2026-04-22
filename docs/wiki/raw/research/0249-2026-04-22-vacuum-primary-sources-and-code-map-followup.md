---
kind: research
status: supported
last_reviewed: 2026-04-22
sources:
  - ../binaryen/2026-04-22-vacuum-primary-sources.md
  - ../../binaryen/passes/vacuum/index.md
  - ../../binaryen/passes/vacuum/binaryen-strategy.md
  - ../../binaryen/passes/vacuum/implementation-structure-and-tests.md
  - ../../binaryen/passes/vacuum/effect-pruning-and-traps-never-happen.md
  - ../../binaryen/passes/vacuum/wat-shapes.md
  - ../../binaryen/passes/vacuum/starshine-hot-ir-strategy.md
  - ../../../../src/passes/pass_manager.mbt
  - ../../../../src/passes/optimize.mbt
  - ../../../../src/passes/optimize_test.mbt
  - ../../../../src/passes/trace_golden_test.mbt
  - ../../../../src/passes/perf_test.mbt
  - ../../../../src/passes/pass_manager_wbtest.mbt
  - ../../../../src/cmd/cmd.mbt
  - ../../../../src/cmd/cmd_wbtest.mbt
---

# `vacuum` primary-source and code-map follow-up

## Why this follow-up exists

The living `vacuum` dossier was already strong on upstream strategy, proof surface, and transformed-shape teaching.
Two practical gaps still remained:

- the folder still lacked an immutable raw primary-source manifest
- the Starshine page still described the local subset honestly, but it did not yet point readers to the exact MoonBit registry, dispatch, helper, validation-guard, trace, perf, and CLI proof surfaces

This follow-up closes that provenance-and-navigation gap without claiming the earlier dossier lacked a real overview, shape catalog, or Binaryen strategy page.

## Sources re-checked in this run

### Upstream Binaryen primary sources

Captured immutably in:

- `docs/wiki/raw/binaryen/2026-04-22-vacuum-primary-sources.md`

The most important reviewed surfaces were:

- the official Binaryen GitHub release pages for `version_129`
- `Vacuum.cpp` on `version_129` and `main`
- `pass.cpp`, `passes.h`, `opt-utils.h`, `branch-hints.h`, and `drop.h`
- representative dedicated lit files for function cleanup, removable-if-unused behavior, branch-hint flips, global-effects interaction, GC, strings, EH, and TNH

### Local Starshine code surfaces re-checked

- `src/passes/pass_manager.mbt`
- `src/passes/optimize.mbt`
- `src/passes/optimize_test.mbt`
- `src/passes/trace_golden_test.mbt`
- `src/passes/perf_test.mbt`
- `src/passes/pass_manager_wbtest.mbt`
- `src/cmd/cmd.mbt`
- `src/cmd/cmd_wbtest.mbt`

## Durable findings

### 1. The release anchoring is now explicit instead of implicit

The earlier dossier already treated `version_129` as the source oracle, but it did not preserve the exact release-page provenance in the raw-source system.
The 2026-04-22 capture now records that the reviewed official release page for `version_129` showed publish date **2026-04-01**, and that the releases index was re-checked on the same day.

### 2. The local teaching gap was navigation, not semantics

The existing `starshine-hot-ir-strategy.md` page already taught the honest local subset correctly:
Starshine only removes explicit HOT `nop` entries today.
The practical missing piece was a read-along answer to:

- where is the registry entry?
- where does the pass dispatch?
- where is the recursive helper?
- where do the writeback safeguards live?
- which local tests prove the current contract?

That exact navigation layer is now filled in.

### 3. Current Starshine `vacuum` is best taught as a tiny HOT cleanup plus pipeline hygiene

Re-checking the local code confirms that the real local contract is split across a few small surfaces:

- `src/passes/optimize.mbt` registers `vacuum` as a hot pass and explains the user-visible summary
- `src/passes/pass_manager.mbt` owns both the recursive HOT rewrite and the `vacuum`-specific writeback-validation guard
- `src/passes/optimize_test.mbt`, `trace_golden_test.mbt`, and `perf_test.mbt` lock the current local semantics and the traced/perf-visible pipeline behavior
- `src/cmd/cmd_wbtest.mbt` proves the CLI surface and the saved generated-artifact replay lanes that retired the old slot-23 / slot-33 visibility failures

That is more useful for future readers than a second high-level explanation of upstream Binaryen.

### 4. The local-vs-upstream gap is still large and should stay explicit

The new code map does not change the semantic bottom line:

- upstream Binaryen `vacuum` is a broad AST cleanup pass with effect-aware unused-result pruning, condition flipping, drop rebuilding, EH/TNH handling, and refinalization
- current Starshine `vacuum` is still the intentionally smaller HOT recursive `nop`-trimming slice, plus pipeline-level validation/writeback hygiene around that slice

The new docs make that contrast easier to follow directly from code and tests rather than only from prose.

## Files changed because of this follow-up

### New raw-source manifest

- `docs/wiki/raw/binaryen/2026-04-22-vacuum-primary-sources.md`

### Refreshed living pages and catalogs

- `docs/wiki/binaryen/passes/vacuum/index.md`
- `docs/wiki/binaryen/passes/vacuum/starshine-hot-ir-strategy.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/index.md`
- `docs/wiki/log.md`

## Maintenance rule going forward

If future `vacuum` work needs a quick provenance anchor plus a practical Binaryen/Starshine read-along path, start with:

1. `docs/wiki/raw/binaryen/2026-04-22-vacuum-primary-sources.md`
2. `docs/wiki/binaryen/passes/vacuum/index.md`
3. `docs/wiki/binaryen/passes/vacuum/implementation-structure-and-tests.md`
4. `docs/wiki/binaryen/passes/vacuum/starshine-hot-ir-strategy.md`
5. `src/passes/pass_manager.mbt`
6. `src/passes/optimize_test.mbt`
7. `src/passes/trace_golden_test.mbt`
8. `src/passes/perf_test.mbt`
9. `src/cmd/cmd_wbtest.mbt`

That path now gives a clean bridge from official Binaryen release/source/test surfaces to the exact current MoonBit implementation, the local validation/perf/CLI evidence surface, and the honest boundary between the current HOT subset and upstream Binaryen's much larger pass contract.
