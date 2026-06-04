# `version_130` MarkJSCalled / RemoveExports Tracker Expansion

Date: 2026-06-04

## Question

The release-horizon pages now say Binaryen `version_130` names `MarkJSCalled` and `RemoveExports`. Should the living pass tracker keep treating those as unresolved changelog facts, or are they source-backed enough to add as upstream-only pass rows?

## Findings

- The official `version_130` release/changelog surface is current release-horizon evidence for both names.
- `src/passes/MarkJSCalled.cpp` and `test/lit/passes/mark-js-called.wast` exist in Binaryen `version_130`, so `mark-js-called` deserves a living upstream-only landing page. Its local Starshine neighborhood is the function-annotation surface: `FuncAnnotationSec` in `src/lib/types.mbt` and the WAST `(@binaryen.js.called)` parse/lower tests in `src/wast/parser.mbt`, `src/wast/lower_to_lib.mbt`, and `src/wast/module_wast_tests.mbt`.
- `src/passes/RemoveExports.cpp` and `test/lit/passes/remove-exports.wast` exist in Binaryen `version_130`, so `remove-exports` deserves a living upstream-only landing page. Its local Starshine neighborhood is `Export` / `ExportSec` / `Module.export_sec` plus binary/WAST export mutation surfaces.
- Focused repo searches found no `mark-js-called`, `MarkJSCalled`, `remove-exports`, or `RemoveExports` local pass spelling in `src/`. Treat both as upstream-only / local-unknown, not boundary-only or removed.

## Updates Made

- Added landing pages for [`mark-js-called`](../../binaryen/passes/mark-js-called/index.md) and [`remove-exports`](../../binaryen/passes/remove-exports/index.md).
- Refreshed the Binaryen pass tracker, pass catalog, late-pipeline note, release-horizon note, and top-level wiki catalog so those names move from “release-note fact needing source read” to “tracked upstream-only landing pages.”
- Added the companion source manifest [`2026-06-04-v130-mark-js-called-remove-exports-source-read.md`](../binaryen/2026-06-04-v130-mark-js-called-remove-exports-source-read.md).

## Open Questions

- The landing pages are intentionally not full dossiers yet. A future implementation campaign should re-read the owner files line-by-line, map exact validation/lit expectations, and decide whether either pass should be registered as unknown, boundary-only, or active in Starshine.
- `remove-exports` is ABI-visible; any local implementation needs an explicit host-contract policy before it can be included in a preset.
- `mark-js-called` overlaps with `strip-toolchain-annotations` because both touch Binaryen toolchain annotations. Keep those pages cross-linked so one pass's annotation-preservation/removal policy does not silently contradict the other.
