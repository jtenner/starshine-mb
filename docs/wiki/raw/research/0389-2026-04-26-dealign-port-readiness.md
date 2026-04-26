# `dealign` port-readiness follow-up

_Date:_ 2026-04-26  
_Status:_ absorbed into living wiki pages under `docs/wiki/binaryen/passes/dealign/`

## Question

The `dealign` dossier already had corrected source coverage, but it was still classified as `dossier` rather than `deep` and lacked the now-standard first-slice / validation ladder page that future Starshine implementers can follow without re-reading the whole memory-pass area.

## Sources re-read

- `AGENTS.md`
- `docs/README.md`
- `docs/wiki/index.md`
- `docs/wiki/log.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/binaryen/passes/dealign/`
- `docs/wiki/binaryen/passes/alignment-lowering/`
- `docs/wiki/raw/research/`
- Binaryen primary sources captured in [`../binaryen/2026-04-26-dealign-port-readiness-primary-sources.md`](../binaryen/2026-04-26-dealign-port-readiness-primary-sources.md)
- Starshine local anchors in `src/passes/optimize.mbt`, `src/wast/parser.mbt`, `src/wast/lower_to_lib.mbt`, `src/lib/types.mbt`, `src/lib/show.mbt`, and `src/validate/typecheck.mbt`

## Findings

- Binaryen current `main` still matches the corrected `version_129` contract: `dealign` is a function-parallel `WalkerPass<PostWalker<DeAlign>>` over `Load`, `Store`, and `SIMDLoad`, with direct assignment of each node's alignment field to `1`.
- The direct lit proof remains narrower than the source surface. It shows scalar `i32.load` / `i32.store` normalization; `SIMDLoad` and broader scalar widths are source-confirmed, not individually isolated in the fixture.
- Starshine still does not track `dealign` at all. It is not active, module, boundary-only, or removed in `src/passes/optimize.mbt`, so `--pass dealign` reaches the generic unknown-pass error.
- Starshine already has the key substrate for a future faithful port: WAT memarg parsing, text-align-to-exponent lowering, library IR `MemArg`, WAT printing, and validation of memarg alignment bounds.
- A future first slice should be registry-honesty first, then ordinary library-IR scalar load/store memarg normalization, then optional source-confirmed broader load/store families, and only later `SIMDLoad` if the parser/IR/binary/HOT surfaces can round-trip it.

## Changes filed back

- Added [`../binaryen/2026-04-26-dealign-port-readiness-primary-sources.md`](../binaryen/2026-04-26-dealign-port-readiness-primary-sources.md).
- Added `docs/wiki/binaryen/passes/dealign/starshine-port-readiness-and-validation.md`.
- Refreshed the `dealign` overview, Binaryen strategy, implementation/test-map, WAT-shape catalog, Starshine strategy, pass catalog, tracker, index, and log so the port-readiness page is linked and the pass can be treated as a deep upstream-only dossier.

## Remaining uncertainty

- Whether a future local port should land as a library-IR module/function traversal or HOT pass remains an implementation decision. The safer first slice is library IR because `MemArg` is already the shared parsed/lowered/printed representation.
- Current docs should not claim local `SIMDLoad` readiness beyond prerequisite audit status; Binaryen's source covers it, but Starshine's exact SIMD memory round-trip surface was not audited in this follow-up.
