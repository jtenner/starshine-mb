---
kind: research
status: absorbed
last_reviewed: 2026-04-26
sources:
  - ../binaryen/2026-04-26-alignment-lowering-current-main-port-readiness.md
  - ../binaryen/2026-04-23-alignment-lowering-primary-sources.md
  - ../../binaryen/passes/alignment-lowering/index.md
  - ../../binaryen/passes/alignment-lowering/binaryen-strategy.md
  - ../../binaryen/passes/alignment-lowering/implementation-structure-and-tests.md
  - ../../binaryen/passes/alignment-lowering/chunk-selection-and-unreachable-semantics.md
  - ../../binaryen/passes/alignment-lowering/wat-shapes.md
  - ../../binaryen/passes/alignment-lowering/starshine-strategy.md
  - ../../binaryen/passes/alignment-lowering/starshine-port-readiness-and-validation.md
  - ../../../../src/passes/optimize.mbt
  - ../../../../src/wast/parser.mbt
  - ../../../../src/wast/lower_to_lib.mbt
  - ../../../../src/lib/types.mbt
  - ../../../../src/binary/encode.mbt
  - ../../../../src/ir/hot_core.mbt
  - ../../../../src/ir/hot_builders.mbt
  - ../../../../src/ir/hot_lift.mbt
  - ../../../../src/ir/hot_lower.mbt
---

# `alignment-lowering` Port-Readiness Follow-up

## Question

The `alignment-lowering` folder had the required overview, transformed-shape catalog, Binaryen strategy, Starshine strategy, implementation/test map, and chunk-selection explainer, but the tracker still classified it as only `dossier` and future implementers still had to infer the first Starshine slice and validation ladder from several pages.

This follow-up asks whether a source-backed port-readiness bridge can make the already-correct dossier more actionable without duplicating the existing strategy pages.

## Sources rechecked

New immutable raw source bridge:

- `docs/wiki/raw/binaryen/2026-04-26-alignment-lowering-current-main-port-readiness.md`

The recheck used official Binaryen `version_129` and current-main sources for:

- `src/passes/AlignmentLowering.cpp`
- `src/passes/pass.cpp`
- `src/passes/passes.h`
- `src/pass.h`
- `src/ir/bits.h`
- `test/lit/passes/alignment-lowering.wast`

It also rechecked local Starshine registry, WAT/lib/binary/HOT memory-op surfaces, and the existing planning docs.

## Findings

### 1. Upstream semantics did not need another correction

The 2026-04-26 current-main spot check found no teaching-relevant drift from the existing `version_129` explanation.
The maintained upstream contract remains:

- public pass name `alignment-lowering`;
- ordinary scalar `Load` / `Store` scope;
- natural-alignment no-op behavior;
- fresh-local single-evaluation staging for pointer and value expressions;
- chunked `i32` rebuild/split core;
- signed-load repair through the bit helper;
- float reinterpret staging rather than numeric conversion;
- 64-bit split/rebuild through two 32-bit halves;
- explicit offset increments on emitted chunks;
- operand-preserving unreachable handling;
- no reviewed owner-file rewrite surface for atomics, SIMD, or bulk-memory instructions.

### 2. The durable Starshine gap is port readiness, not concept coverage

The existing living pages already covered purpose, invariants, shape families, Binaryen implementation, and current boundary-only Starshine status.
The remaining reader problem was sequencing:

- which local files show the prerequisite load/store/memarg surfaces?
- what tests should be written first?
- what should stay out of the first slice?
- how should validation work when the pass is outside the no-DWARF default path?

The new living page answers those questions directly instead of scattering them across the overview, strategy, and local-status pages.

### 3. The first local slice should stay scalar and source-faithful

A minimum viable Starshine port should not start by widening scope.
It should first prove Binaryen-equivalent ordinary scalar memory behavior:

1. registry/request honesty before transform code lands;
2. natural-alignment no-op tests;
3. `align=1` and `align=2` integer chunking tests;
4. signed `load16_s` repair tests;
5. float reinterpret staging tests;
6. 64-bit split/rebuild tests;
7. offset-preservation tests;
8. unreachable operand-preservation tests;
9. direct `wasm-opt --alignment-lowering` comparison.

Atomics, SIMD, bulk memory, memory64-only proof, and broader lowering-family interactions should remain separate scope decisions until a future source-backed implementation slice chooses them explicitly.

### 4. The local landing-zone question remains unresolved and should stay visible

This follow-up does not decide whether `alignment-lowering` belongs as:

- a HOT-side rewrite using `HotOp::Load` / `HotOp::Store` plus memarg side tables;
- a post-writeback legalization pass over lib instructions;
- a broader module/boundary lowering step.

The raw source map shows all three need real care. HOT has useful memory nodes and memarg side tables, but the pass must preserve exact instruction-family and bit-rebuild choices. A later lib-instruction pass may preserve opcode families more directly, but it would need its own pass scheduling and validation story. The living page therefore records the open architectural choice instead of pretending the landing zone is settled.

## Durable wiki changes

Added:

- `docs/wiki/raw/binaryen/2026-04-26-alignment-lowering-current-main-port-readiness.md`
- `docs/wiki/raw/research/0379-2026-04-26-alignment-lowering-port-readiness.md`
- `docs/wiki/binaryen/passes/alignment-lowering/starshine-port-readiness-and-validation.md`

Refreshed:

- `docs/wiki/binaryen/passes/alignment-lowering/index.md`
- `docs/wiki/binaryen/passes/alignment-lowering/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/alignment-lowering/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/alignment-lowering/chunk-selection-and-unreachable-semantics.md`
- `docs/wiki/binaryen/passes/alignment-lowering/wat-shapes.md`
- `docs/wiki/binaryen/passes/alignment-lowering/starshine-strategy.md`
- `docs/wiki/index.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/log.md`
- `CHANGELOG.md`

## Maintenance rule

Future `alignment-lowering` work should start with the new port-readiness page after the overview. If a future slice resolves the landing-zone question, update the Starshine strategy page, port-readiness page, tracker row, and no-DWARF/default-path note together so the pass does not remain in boundary-only limbo by accident.
