---
kind: research
status: supported
last_reviewed: 2026-04-25
sources:
  - ../binaryen/2026-04-25-string-lifting-signature-fatal-source-correction.md
  - ../binaryen/2026-04-24-string-lifting-primary-sources.md
  - ./0327-2026-04-24-string-lifting-primary-sources-and-starshine-followup.md
  - ../../binaryen/passes/string-lifting/index.md
  - ../../binaryen/passes/string-lifting/binaryen-strategy.md
  - ../../binaryen/passes/string-lifting/import-and-call-shapes.md
  - ../../binaryen/passes/string-lifting/implementation-structure-and-tests.md
  - ../../binaryen/passes/string-lifting/starshine-strategy.md
  - ../../../../src/passes/optimize.mbt
  - ../../../../src/lib/types.mbt
  - ../../../../src/wast/keywords.mbt
  - ../../../../src/wast/parser.mbt
  - ../../../../src/wast/lower_to_lib.mbt
  - ../../../../src/ir/hot_lift.mbt
  - ../../../../src/ir/hot_lower.mbt
related:
  - ../../binaryen/passes/string-gathering/index.md
  - ../../binaryen/passes/string-lowering/index.md
  - ../../strings/string-const-surface.md
---

# `string-lifting` signature-fatal source correction

## Question

The `string-lifting` dossier added on 2026-04-24 described wrong helper signatures as ordinary no-rewrite bailouts. A follow-up source re-read asked whether Binaryen actually preserves such calls or fails the pass when a known `wasm:js-string` helper name has the wrong type.

## Finding

Binaryen `version_129` treats wrong helper signatures as a fatal pass error for recognized helper names.

The corrected helper-import matrix is:

| Helper import shape | Binaryen behavior |
| --- | --- |
| wrong module | ignored / unchanged |
| helper module `wasm:js-string`, unknown base | warning / unchanged |
| helper module `wasm:js-string`, recognized base, wrong expected type | fatal pass error |
| helper module `wasm:js-string`, recognized base, exact expected type | calls are eligible for lifting |

The 2026-04-25 current-main recheck found no teaching-relevant drift for this matrix.

## Why the distinction matters

This is not just wording. A future Starshine implementation that silently leaves wrong-signature recognized helpers unchanged would not match the source-confirmed Binaryen pass behavior. The shape catalog and validation plan should therefore ask for an explicit fatal/error fixture, not only a preserved-call negative.

## Pages updated

- `docs/wiki/binaryen/passes/string-lifting/index.md`
- `docs/wiki/binaryen/passes/string-lifting/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/string-lifting/import-and-call-shapes.md`
- `docs/wiki/binaryen/passes/string-lifting/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/string-lifting/starshine-strategy.md`
- `docs/wiki/index.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/log.md`
- `CHANGELOG.md`

## Starshine local recheck

The local status did not change: Starshine still has no `string-lifting` registry entry, owner file, dispatcher case, or active backlog slice.

The local code map was sharpened so readers can inspect the exact prerequisite surfaces:

- `src/passes/optimize.mbt:127-154` for the absence from boundary-only and removed registries;
- `src/lib/types.mbt:725-735` for the currently modeled string instructions;
- `src/wast/keywords.mbt:101-109`, `src/wast/parser.mbt:2180-2191`, and `src/wast/lower_to_lib.mbt:1299-1309` for the currently parsed/lowered textual string surface;
- `src/ir/hot_lift.mbt:768-775` and `src/ir/hot_lower.mbt:185-197` for current HOT preservation of the subset Starshine already models.

## Supersession note

This note supersedes the 2026-04-24 `string-lifting` dossier and `0327` research note only for wrong-signature behavior. The earlier note remains the correct primary dossier provenance for pass direction, magic and JSON constant lifting, helper-call rewrite roster, refinalization, module-code coverage, Strings feature enablement, current unknown-pass local status, and the open upstream cast-repair TODO.
