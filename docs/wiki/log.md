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

## [2026-04-09] ingest | crystallize four more docs into Binaryen and IR2 wiki pages

- Added `binaryen/passes/duplicate-function-elimination/parity.md` from `0067` as the living summary of the module-wide merge contract, full `FuncIdx` rewrite surface, and the remaining direct artifact parity gap for `duplicate-function-elimination`.
- Added `binaryen/no-dwarf-default-optimize-path.md` from `0066` as the living summary of the real no-DWARF `-O` / `-Os` phase split, ordered pass path, and nested rerun rules for the MoonBit debug artifact.
- Added `ir2/execution-plan.md` from `0065` as the current IR2 handoff page covering the active registry surface, pipeline contract, and preferred next slice order.
- Added `ir2/test-matrix.md` from `0064` as the standing shared-helper and golden-fixture matrix for deterministic IR2 lift, analysis, lower, and pass-trace coverage.
- Updated `docs/wiki/index.md` so the new Binaryen and IR2 pages are discoverable under concepts and comparisons.

## [2026-04-09] ingest | crystallize four more IR2 handoff docs into wiki pages

- Added `ir2/registry-map.md` from `0063` as the living summary of the current registry categories, preset composition, and the now-partially-stale parts of the March batch map.
- Added `ir2/pass-porting-checklist.md` from `0062` as the standing helper and validation checklist for future IR2 pass ports.
- Added `ir2/local-ssa-policy.md` from `0061` as the current locals-only SSA policy page covering entry defs, overlay-only phis, rename policy, and predecessor-copy destruction.
- Added `ir2/cfg-contract.md` from `0060` as the normative CFG boundary and explicit-edge policy page for `HotFunc`.
- Updated `docs/wiki/index.md` so the new IR2 concept and decision pages are discoverable from the catalog.

## [2026-04-09] organize | reserve root docs for normative material

- Updated `AGENTS.md`, `docs/README.md`, and `docs/wiki/raw/README.md` so `docs/` is now the home for normative docs only, while numbered one-off investigations live under `docs/wiki/raw/research/`.
- Added `docs/wiki/raw/research/README.md` to define the absorbed-research archive rules.
- Moved the non-normative numbered docs out of root `docs/` into `docs/wiki/raw/research/`.
- Repointed `agent-todo.md`, `CHANGELOG.md`, and the Binaryen wiki pages so live references and archived sources still resolve after the move.
- Updated `docs/wiki/index.md` so the research archive rules are discoverable from the catalog.
