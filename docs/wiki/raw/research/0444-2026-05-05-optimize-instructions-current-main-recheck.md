# `optimize-instructions` current-main recheck and Starshine strategy bridge

## Why this follow-up exists

The `optimize-instructions` dossier was already strong on the upstream pass contract, the shape catalog, and the current Starshine HOT subset.
What it was missing was the conventional Starshine strategy page that points readers to the exact local code and test surfaces without forcing them to start from the deeper HOT code-map page.

This follow-up closes that navigation gap and refreshes the folder with a 2026-05-05 current-main spot check.

## Sources re-checked in this run

### Upstream Binaryen primary sources

Captured immutably in:

- `docs/wiki/raw/binaryen/2026-05-05-optimize-instructions-current-main-recheck.md`

The reviewed surfaces were the same core contract points the living dossier already teaches:

- `OptimizeInstructions.cpp`
- `pass.cpp`
- `opt-utils.h`
- representative default, sign-extension, bulk-memory, `call_ref`, GC, TNH-GC, multivalue, and branch-hint tests

### Local Starshine code surfaces re-checked

- `src/passes/optimize_instructions.mbt`
- `src/passes/optimize_instructions_test.mbt`
- `src/passes/optimize.mbt`
- `src/passes/pass_manager.mbt`
- `src/passes/registry_test.mbt`
- `src/cmd/cmd_wbtest.mbt`

## Durable findings

### 1. The source contract still reads as a broad local canonicalization pass

The current-main spot check did not surface teaching-relevant drift on the reviewed surfaces.
The dossier still correctly teaches the pass as a broad local rewrite engine with:

- local bit/sign-extension scanning
- iterative canonicalization
- arithmetic and compare cleanup
- memory and bulk-memory simplification
- `call_ref` and GC/reference-typed rewrites
- deferred refinalization and EH repair

### 2. The local navigation gap was real

The older dossier already had the implementation facts.
The missing piece was a dedicated Starshine strategy page that points at the exact MoonBit owner file, registry entry, dispatcher, tests, and CLI replay lanes in one place.

### 3. The new strategy page is a doc-structure improvement, not a new contract

The new `starshine-strategy.md` page simply packages the existing local evidence into a beginner-to-advanced overview.
The deeper helper map remains in `starshine-hot-ir-strategy.md`.

## Files changed because of this follow-up

- `docs/wiki/raw/binaryen/2026-05-05-optimize-instructions-current-main-recheck.md`
- `docs/wiki/binaryen/passes/optimize-instructions/starshine-strategy.md`
- `docs/wiki/binaryen/passes/optimize-instructions/index.md`
- `docs/wiki/binaryen/passes/optimize-instructions/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/optimize-instructions/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/optimize-instructions/starshine-hot-ir-strategy.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/index.md`
- `docs/wiki/log.md`

## Maintenance rule going forward

Use the new strategy page for the local overview, and keep the deeper helper map in `starshine-hot-ir-strategy.md` when you need the exact MoonBit helper flow.
