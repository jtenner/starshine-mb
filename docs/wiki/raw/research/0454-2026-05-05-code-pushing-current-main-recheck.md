# 0454 - Code Pushing Current-Main Recheck

## Question

Does the current `code-pushing` dossier still match official Binaryen `main` on the reviewed source and scheduler surfaces, and what durable updates should the wiki keep?

## Finding

The 2026-05-05 source recheck did not find teaching-relevant drift on the reviewed current-main surfaces.
Binaryen still teaches `code-pushing` as a `LocalAnalyzer` + `Pusher` segment pass with `isPushable(...)`, `isPushPoint(...)`, `optimizeSegment(...)`, and `optimizeIntoIf(...)` at its core.

Starshine remains narrower: the active direct pass still only sinks const-like `local.set` roots into one consuming `if` arm and keeps a separate local dead-block flattening helper.

## Durable updates made

- Added `docs/wiki/raw/binaryen/2026-05-05-code-pushing-current-main-recheck.md`.
- Refreshed the living `code-pushing` dossier pages to point at the new source bridge.
- Updated the pass catalogs and wiki log so the new provenance is visible from the shared indexes.

## Remaining uncertainty

The raw GitHub source render still uses long logical lines, so the wiki should keep citing file URLs and function names rather than fragile line anchors for this pass.
