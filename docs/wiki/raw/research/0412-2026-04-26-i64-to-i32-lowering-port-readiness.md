# `i64-to-i32-lowering` port-readiness bridge

_Date:_ 2026-04-26  
_Status:_ absorbed into living wiki pages

## Question

The existing `i64-to-i32-lowering` dossier already had source-backed overview, Binaryen strategy, WAT-shape, ABI-surface, implementation/test-map, and Starshine status pages. What was still missing was the newer campaign's explicit first-slice / validation ladder for a future Starshine port.

## Source base

- Raw primary-source recheck: [`../binaryen/2026-04-26-i64-to-i32-lowering-port-readiness-primary-sources.md`](../binaryen/2026-04-26-i64-to-i32-lowering-port-readiness-primary-sources.md)
- Earlier raw source manifest: [`../binaryen/2026-04-24-i64-to-i32-lowering-primary-sources.md`](../binaryen/2026-04-24-i64-to-i32-lowering-primary-sources.md)
- Living folder: [`../../binaryen/passes/i64-to-i32-lowering/index.md`](../../binaryen/passes/i64-to-i32-lowering/index.md)

## Findings

- Binaryen's current owner/test surfaces still support the 2026-04-24 contract: this is a flat-input whole-module ABI legalization pass, not a small arithmetic peephole.
- Starshine still keeps `i64-to-i32-lowering` boundary-only in `src/passes/optimize.mbt` and has no module dispatcher case or owner file.
- The safest next work is a no-rewrite analyzer / classifier while preserving boundary-only request rejection.
- The first mutating slice should be deliberately narrow: scalar defined-function type/param/local splitting plus validation. Calls, returns, globals, helper imports, atomics, reinterpret, and imported `i64` globals should remain rejected until separate slices prove them.
- The existing living pages did not need an upstream correction; they needed an implementation-readiness bridge and refreshed index/tracker classification from `dossier` to `deep`.

## Living-page updates made

- Added [`../../binaryen/passes/i64-to-i32-lowering/starshine-port-readiness-and-validation.md`](../../binaryen/passes/i64-to-i32-lowering/starshine-port-readiness-and-validation.md).
- Refreshed the landing, Binaryen strategy, WAT-shape, ABI-surface, hard-boundaries, implementation/test-map, and Starshine strategy pages so the new bridge is discoverable from every main reader path.
- Updated `docs/wiki/index.md`, `docs/wiki/binaryen/passes/index.md`, `docs/wiki/binaryen/passes/tracker.md`, and `docs/wiki/log.md`.

## Follow-up risks

- A future implementation must not move the pass out of boundary-only status until a real module rewrite and validation tests exist.
- Helper import materialization is still a separate high-risk slice.
- Binaryen's unsupported shapes must remain explicit until Starshine either matches the rejection behavior or documents a deliberate extension.
