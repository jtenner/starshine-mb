# Wasm Knowledge Base Log

Append new entries; do not rewrite prior history except to fix obvious formatting mistakes or redact sensitive data.

## [2026-04-09] bootstrap | initialize wasm knowledge base

- Added `docs/README.md` as the canonical docs and wiki schema.
- Added `docs/wiki/index.md` and `docs/wiki/log.md` as the initial catalog and audit trail.
- Added `docs/wiki/raw/README.md` to define committed raw-source handling.
- Updated `AGENTS.md` so wiki and knowledge-base work starts from `docs/README.md`.

## [2026-04-09] schema | tighten AGENTS wiki contract

- Rewrote `AGENTS.md` to split general work rules from docs and wiki rules.
- Made the numbered docs vs. living wiki distinction explicit.
- Added clear requirements for keeping `docs/wiki/index.md` and `docs/wiki/log.md` current on wiki schema and maintenance changes.
- Mirrored the same operational summary in `docs/README.md`.

## [2026-04-09] ingest | crystallize recent numbered docs into wiki pages

- Added `heap2local-binaryen-parity.md` from `0075` as the living summary of the current Binaryen transform surface, in-tree coverage, and remaining refinalization gap.
- Added `reorder-locals-binaryen-parity.md` from `0073` as the living summary of the exact ordering rule, module-pass scope, and current signoff boundary.
- Added `reorder-locals-multivalue-call-scope.md` from `0074` as the current scope decision for multivalue-call writeback parity.
- Added `binaryen-invalid-tag-index-parser-gap.md` from `0072` as the standing oracle parser-gap rule for `remove-unused-names` compare failures.
- Updated `docs/wiki/index.md` so the new decision and comparison pages are discoverable from the wiki catalog.

## [2026-04-09] organize | namespace Binaryen pass pages

- Moved the new pass-focused wiki pages under `docs/wiki/binaryen/passes/<pass>/...` so future Binaryen pass notes have one stable home.
- Kept `heap2local` parity under `binaryen/passes/heap2local/parity.md`.
- Kept `reorder-locals` parity and multivalue-call scope notes together under `binaryen/passes/reorder-locals/`.
- Moved the `remove-unused-names` parser-gap note under `binaryen/passes/remove-unused-names/invalid-tag-index-parser-gap.md`.
- Updated `docs/wiki/index.md` and intra-page links to point at the new namespace layout.

## [2026-04-09] ingest | crystallize four more recent pass docs

- Added `binaryen/passes/remove-unused-brs/parity.md` from `0070` as the living summary of Binaryen phase structure, current MoonBit coverage, and the remaining late-shape gap for `remove-unused-brs`.
- Added `binaryen/passes/remove-unused-brs/returned-ladder-hot-shapes.md` from `0071` as the standing HOT-shape note for returned-ladder families that do not look like their printed WAT form after lift.
- Added `binaryen/passes/pick-load-signs/parity.md` from `0069` as the living summary of the active rewrite surface, signoff state, and fast-skip behavior for `pick-load-signs`.
- Added `binaryen/passes/global-struct-inference/parity.md` from `0068` as the living summary of the current closed-world direct-global slice and its present scope limit.
- Updated `docs/wiki/index.md` so the new Binaryen pass pages are discoverable under concepts and comparisons.
