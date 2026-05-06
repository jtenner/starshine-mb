# `alignment-lowering` Current-Main Recheck

## Question

Did the 2026-04-26 `alignment-lowering` dossier need a fresh current-main refresh, or had the upstream contract changed enough to require semantic corrections?

## Rechecked source

New immutable raw source manifest:

- [`../binaryen/2026-05-06-alignment-lowering-current-main-recheck.md`](../binaryen/2026-05-06-alignment-lowering-current-main-recheck.md)

The recheck covered the official Binaryen `version_129` and current-main sources for:

- `src/passes/AlignmentLowering.cpp`
- `src/passes/pass.cpp`
- `src/passes/passes.h`
- `src/pass.h`
- `src/ir/bits.h`
- `test/lit/passes/alignment-lowering.wast`

It also rechecked the local Starshine registry and memory-op surfaces already named in the living dossier pages.

## Findings

### 1. Upstream semantics stayed the same

The 2026-05-06 current-main recheck found no teaching-relevant drift from the already captured `version_129` contract.
The pass remains a narrow scalar `Load` / `Store` chunk-lowering pass with fresh-local single-evaluation staging, `Bits::makeSignExt(...)` signed-load repair, reinterpret-based float handling, 64-bit split/rebuild, and operand-preserving unreachable handling.

### 2. The living dossier still needs the same conceptual split

The upstream strategy is still easy to misread as generic memory optimization.
The maintained page split remains the right one:

- `index.md` for pass overview and navigation;
- `binaryen-strategy.md` for the upstream contract;
- `implementation-structure-and-tests.md` for source/test map;
- `chunk-selection-and-unreachable-semantics.md` for the helper matrix and operand-preserving rewrites;
- `wat-shapes.md` for beginner-to-advanced concrete shapes;
- `starshine-strategy.md` for current local status;
- `starshine-port-readiness-and-validation.md` for the future first-slice ladder.

### 3. The useful new work was freshness, not correction

The previous dossier already covered the pass correctly.
This refresh added a newer current-main source anchor layer so later readers can follow exact upstream line locations without guessing whether the older 2026-04-26 bridge was still current.

### 4. The open local question did not change

Starshine still does not have a committed landing zone for the pass.
The honest local decision remains:

- HOT-side rewrite;
- post-writeback / boundary legalization;
- or some later boundary-lowering pass.

That is a port-planning question, not a semantics correction.

## Durable wiki changes

Added:

- `docs/wiki/raw/binaryen/2026-05-06-alignment-lowering-current-main-recheck.md`
- `docs/wiki/raw/research/0496-2026-05-06-alignment-lowering-current-main-recheck.md`

Refreshed:

- `docs/wiki/binaryen/passes/alignment-lowering/index.md`
- `docs/wiki/binaryen/passes/alignment-lowering/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/alignment-lowering/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/alignment-lowering/chunk-selection-and-unreachable-semantics.md`
- `docs/wiki/binaryen/passes/alignment-lowering/wat-shapes.md`
- `docs/wiki/binaryen/passes/alignment-lowering/starshine-strategy.md`
- `docs/wiki/binaryen/passes/alignment-lowering/starshine-port-readiness-and-validation.md`
- `docs/wiki/index.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/log.md`
- `CHANGELOG.md`

## Maintenance rule

Future `alignment-lowering` work should start from the new 2026-05-06 raw recheck when updating the living dossier, but should keep the semantics unchanged unless Binaryen itself changes.
