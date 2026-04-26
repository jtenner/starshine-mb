---
kind: concept
status: supported
last_reviewed: 2026-04-26
sources:
  - ../../../raw/binaryen/2026-04-26-alignment-lowering-current-main-port-readiness.md
  - ../../../raw/research/0379-2026-04-26-alignment-lowering-port-readiness.md
  - ../../../raw/binaryen/2026-04-23-alignment-lowering-primary-sources.md
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./chunk-selection-and-unreachable-semantics.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/wast/parser.mbt
  - ../../../../../src/wast/lower_to_lib.mbt
  - ../../../../../src/lib/types.mbt
  - ../../../../../src/binary/encode.mbt
  - ../../../../../src/ir/hot_core.mbt
  - ../../../../../src/ir/hot_builders.mbt
  - ../../../../../src/ir/hot_lift.mbt
  - ../../../../../src/ir/hot_lower.mbt
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./chunk-selection-and-unreachable-semantics.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../dealign/index.md
  - ../avoid-reinterprets/index.md
  - ../i64-to-i32-lowering/index.md
---

# Starshine Port Readiness And Validation For `alignment-lowering`

Use this as the implementation-readiness bridge for the `alignment-lowering` dossier.
The overview explains what the pass does, the Binaryen strategy page explains upstream mechanics, and the Starshine strategy page explains the current boundary-only status. This page answers the next practical question: what should a future Starshine implementer do first?

## Current readiness summary

`alignment-lowering` is ready for a future source-faithful first slice in the sense that:

- Binaryen's reviewed contract is small and source-backed;
- the important transformed shapes are already cataloged;
- Starshine already represents scalar memory opcodes and memargs in WAT, lib IR, binary encode, validation, and HOT;
- the local registry already preserves the public pass name as boundary-only;
- explicit pass requests already fail honestly until a real transform exists.

It is **not** ready in the sense of having a chosen landing zone. The main local decision remains whether the future port should be a HOT rewrite, a post-writeback/lib-instruction legalization pass, or a broader boundary lowering pass.

## Why the first slice should stay narrow

The upstream owner file teaches a very narrow pass:

- ordinary scalar loads and stores;
- weak alignment only;
- chunked scalar memory operations;
- fresh locals to avoid duplicated address/value evaluation;
- exact bit rebuild/split behavior;
- operand-preserving unreachable fast paths.

So the first Starshine slice should deliberately **not** include:

- atomics;
- SIMD memory instructions or lane ops;
- bulk-memory operations;
- generic memory CSE or value-numbering;
- unrelated memory64 lowering;
- feature-section rewriting.

Those may become separate later decisions, but they are not part of the reviewed Binaryen `alignment-lowering` core documented here.

## Local surfaces to read before coding

### Registry and request honesty

- `src/passes/optimize.mbt:127-140`
  - `pass_registry_boundary_only_names()` includes `alignment-lowering`.
- `src/passes/optimize.mbt:446-461`
  - explicit requests fail as boundary-only until an implementation lands.

Do not remove that rejection before transform code, tests, and dispatcher/preset decisions exist.

### WAT and lib instruction surfaces

- `src/wast/parser.mbt:255-257`
  - WAT-side `MemArg` shape.
- `src/wast/parser.mbt:1323-1348`
  - `offset=` and `align=` parsing.
- `src/wast/parser.mbt:1980-1995`
  - scalar memory opcode parsing into WAT `Load` / `Store` forms.
- `src/wast/lower_to_lib.mbt:224-229`
  - WAT-to-lib memarg conversion.
- `src/wast/lower_to_lib.mbt:1528-1555`
  - scalar WAT load/store lowering.
- `src/lib/types.mbt:475`
  - `MemArg` representation.
- `src/lib/types.mbt:543-565`
  - ordinary scalar load/store instruction variants.
- `src/lib/types.mbt:3077-3168`
  - constructor methods for scalar load/store families.

These surfaces are enough to express the Binaryen output shapes if the implementation chooses a lib-instruction or post-writeback landing zone.

### Binary and validation surfaces

- `src/binary/encode.mbt:1819-1840`
  - memarg binary encoding with align/offset and optional memory index.
- `src/validate/typecheck.mbt`
  - memory access typing and validation behavior.

A future port must keep the emitted chunked instructions valid under the existing typechecker and memarg encoder.

### HOT-side potential landing surfaces

- `src/ir/hot_core.mbt:47-48`
  - `HotOp::Load` / `HotOp::Store`.
- `src/ir/hot_core.mbt:230-232`
  - `HotMemArg`.
- `src/ir/hot_side_tables.mbt:111-119`
  - HOT memarg side-table allocation and lookup.
- `src/ir/hot_builders.mbt:535-557`
  - HOT load/store builders.
- `src/ir/hot_lift.mbt:741-760`
  - scalar lib load/store instructions lift to HOT `Load` / `Store` families.
- `src/ir/hot_lower.mbt:1077-1086`
  - exact HOT memory nodes lower back through exact-instruction lowering.

These surfaces make a HOT implementation plausible, but not automatic. The future port must prove it can preserve the exact source opcode family (`i32.load8_u`, `i32.store16`, `f32.load`, etc.) and memarg offsets/alignment across any HOT rewrite.

## Minimum viable test order

Write tests before implementation. The smallest useful red-test ladder is:

1. **Registry honesty before implementation**
   - requesting `alignment-lowering` still reports the boundary-only error until the transform lands;
   - once the transform lands, update the registry category and request tests in the same change.
2. **Natural-alignment no-ops**
   - `i32.load align=4`, `i64.load align=8`, and matching stores stay untouched.
3. **Integer chunking positives**
   - `i32.load align=1` splits into four byte loads and bit-or/shift rebuilds;
   - `i32.load align=2` splits into two halfword loads;
   - matching `i32.store` cases split values with shifts and narrow stores.
4. **Signed-load repair**
   - signed `load16_s` and related shapes rebuild bits and then sign-extend exactly as Binaryen does.
5. **Float reinterpret staging**
   - `f32` and `f64` loads/stores move through integer bit patterns, not numeric conversion.
6. **64-bit split/rebuild**
   - `i64` and `f64` full-width cases split through two 32-bit halves with explicit `offset` and `offset + 4` chunks.
7. **Offset preservation**
   - nonzero base offsets remain explicit on emitted chunks rather than being folded into the pointer expression.
8. **Unreachable operand preservation**
   - unreachable load/store operands are preserved according to the Binaryen shape catalog, not expanded into ordinary chunk traffic.
9. **Negative scope tests**
   - atomics, SIMD memory ops, lane ops, and bulk-memory instructions are left alone unless a later documented widening slice explicitly chooses otherwise.

## First implementation slice

A first faithful Starshine slice should be:

- public pass name remains `alignment-lowering`;
- active request rejection is replaced only when the real pass is callable;
- ordinary scalar load/store families are handled;
- natural-alignment accesses are no-ops;
- all generated helper locals are fresh and typed correctly;
- pointer/value side effects are evaluated once;
- memarg offsets and alignments follow the Binaryen chunk matrix;
- final module validation runs after the pass;
- all non-reviewed instruction families remain no-ops.

Do not make the first slice depend on the no-DWARF default optimizer path. This pass is not currently part of the documented canonical no-DWARF route, so direct pass comparison against Binaryen is the right oracle.

## Validation ladder after implementation

1. Run targeted MoonBit tests for the reduced WAT shapes above.
2. Run `moon test src/passes` and `moon test src/cmd` once the registry/dispatcher behavior changes.
3. Compare focused fixtures against Binaryen with `wasm-opt --alignment-lowering`.
4. Add randomized comparison only after deterministic fixtures cover the exact chunk families.
5. Revisit `docs/wiki/binaryen/no-dwarf-default-optimize-path.md` only if the pass becomes part of a real local preset route; otherwise keep its omission explicit.

## Open landing-zone decision

There are two plausible local strategies:

| Landing | Why it may fit | Risk to prove |
| --- | --- | --- |
| HOT-side rewrite | HOT already has load/store nodes, memarg side tables, builders, lift, and lower support | Must preserve exact source opcode families and memarg adjustments through HOT rather than collapsing everything into generic load/store too early |
| Lib-instruction / post-writeback pass | Direct access to `@lib.Instruction` variants may make opcode-family preservation easier | Needs a clear pass scheduling, owner-file, validation, and command-dispatch story outside the current HOT-centric pass work |

The docs should keep this decision open until an implementation slice resolves it with tests.

## Maintenance rule

If future code starts this port, update all of these together:

- this page;
- [`./starshine-strategy.md`](./starshine-strategy.md);
- [`./binaryen-strategy.md`](./binaryen-strategy.md) if upstream behavior changes;
- [`./wat-shapes.md`](./wat-shapes.md) if local output intentionally diverges;
- [`../tracker.md`](../tracker.md);
- `docs/wiki/index.md` and `docs/wiki/log.md`;
- `CHANGELOG.md`.
