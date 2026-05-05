# 0484 - `rereloop` current-main recheck

_Date:_ 2026-05-05  
_Status:_ filed into living wiki  
_Raw source:_ [`../binaryen/2026-05-05-rereloop-current-main-recheck.md`](../binaryen/2026-05-05-rereloop-current-main-recheck.md)

## Question

Does current `main` still match the corrected `rereloop` contract, and do the living wiki pages still explain the pass cleanly for Binaryen readers and future Starshine work?

## Findings

The recheck found no contract drift on the reviewed Binaryen surfaces.
Current `main` still teaches the same flat-IR-to-CFG-to-Relooper contract, with EH as a hard boundary and `ReFinalize` still closing the mutation loop.

## Wiki changes made

- Added `docs/wiki/raw/binaryen/2026-05-05-rereloop-current-main-recheck.md`.
- Added `docs/wiki/binaryen/passes/rereloop/starshine-port-readiness-and-validation.md`.
- Refreshed the living `rereloop` landing page and the upstream strategy / implementation / Starshine pages so the new freshness layer and local port-readiness bridge are discoverable together.
- Updated the wiki catalog and log so the new page is visible from the shared index.

## Uncertainty

This recheck is narrow. It covered the pass-local wrapper, scheduler registration, generic relooper helper, and representative fixtures, but it did not re-audit the broader control-flow pass family beyond the files listed in the raw source manifest.
