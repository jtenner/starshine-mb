---
kind: research
status: supported
last_reviewed: 2026-04-26
sources:
  - ../binaryen/2026-04-26-duplicate-function-elimination-current-main-and-starshine-strategy-health.md
  - ../../binaryen/passes/duplicate-function-elimination/index.md
  - ../../binaryen/passes/duplicate-function-elimination/binaryen-strategy.md
  - ../../binaryen/passes/duplicate-function-elimination/wat-shapes.md
  - ../../binaryen/passes/duplicate-function-elimination/starshine-strategy.md
  - ../../../../src/passes/duplicate_function_elimination.mbt
  - ../../../../src/passes/pass_manager.mbt
  - ../../../../src/passes/optimize.mbt
---

# Duplicate function elimination strategy-health follow-up

## Question

Does the existing `duplicate-function-elimination` dossier still teach the right Binaryen and Starshine strategy, and are there stale references that make the module-pass status harder to understand?

## Answer

The core strategy is still correct, but one durable health issue needed cleanup: the Starshine strategy file was named `starshine-hot-ir-strategy.md` even though both upstream Binaryen and local Starshine treat DFE as a module pass. The page has been renamed to `starshine-strategy.md`, and living wiki links now point to the neutral module-pass strategy name.

## Sources checked

- Official Binaryen current-main owner and helper surfaces for DFE.
- Existing Binaryen `version_129` raw-source dossier and prior follow-up notes.
- Starshine registry, module dispatcher, DFE implementation, and DFE tests.
- Living wiki pages under `docs/wiki/binaryen/passes/duplicate-function-elimination/` plus global and pass indexes.

## Durable findings

1. Upstream DFE remains a whole-module pass: it hashes defined functions, exact-compares candidate collisions, keeps the earliest equivalent survivor, rewrites function references, and can repeat depending on optimization/shrink settings.
2. Starshine's `duplicate-function-elimination` remains a module pass: `src/passes/optimize.mbt` registers it with `pass_registry_entry_module(...)`, and `src/passes/pass_manager.mbt` dispatches it through the module-pass switch.
3. The Starshine strategy page should not carry HOT-IR wording in its filename. That stale filename was a documentation hazard for beginners and for search results.
4. The important parity caveat remains unchanged: Starshine's implementation currently performs one explicit duplicate-elimination iteration and bundles extra cleanup that is broader than upstream DFE proper.

## Wiki changes made

- Renamed `docs/wiki/binaryen/passes/duplicate-function-elimination/starshine-hot-ir-strategy.md` to `docs/wiki/binaryen/passes/duplicate-function-elimination/starshine-strategy.md`.
- Refreshed the DFE overview and Starshine strategy frontmatter to cite the 2026-04-26 current-main / health manifest.
- Updated local DFE page links plus the global wiki index and Binaryen pass index so living pages no longer point at the stale filename.
- Added this note and the raw primary-source manifest for future auditability.

## Uncertainties

- Older raw-source and research notes still mention the historical filename. Those are intentionally not rewritten because they are audit records; living pages now use the renamed page.
- No new parity claim is made for Binaryen current-main beyond the focused owner/registration/helper recheck on 2026-04-26.
