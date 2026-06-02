---
kind: entity
status: supported
last_reviewed: 2026-04-26
sources:
  - ../../../raw/binaryen/2026-04-26-i64-to-i32-lowering-port-readiness-primary-sources.md
  - ../../../raw/research/0412-2026-04-26-i64-to-i32-lowering-port-readiness.md
  - ../../../raw/binaryen/2026-04-24-i64-to-i32-lowering-primary-sources.md
  - ../../../raw/research/0299-2026-04-24-i64-to-i32-lowering-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0175-2026-04-21-i64-to-i32-lowering-binaryen-research.md
  - ../../../raw/research/0197-2026-04-21-i64-to-i32-lowering-abi-and-coverage-followup.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../agent-todo.md
  - ../../../raw/research/0063-2026-03-24-pass-port-batches-and-registry-map.md
  - ../../no-dwarf-default-optimize-path.md
  - ../tracker.md
related:
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./flatness-helpers-and-boundaries.md
  - ./abi-surface-and-opcode-coverage.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
  - ../tracker.md
---

# `i64-to-i32-lowering`

## Role

- `i64-to-i32-lowering` is a real public Binaryen pass.
- It is currently **unimplemented** in Starshine's active optimizer and still lives in the local **boundary-only** registry in [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt).
- It has no owner file or dispatcher case today; [`./starshine-strategy.md`](./starshine-strategy.md) maps the exact local code surfaces a future module pass would need.
- It is also still listed in the local whole-module transform roster in [`../../../raw/research/0063-2026-03-24-pass-port-batches-and-registry-map.md`](../../../raw/research/0063-2026-03-24-pass-port-batches-and-registry-map.md).
- It is **not** part of the repo's current canonical no-DWARF `-O` / `-Os` optimize path.

## Why this pass matters

- The original parity queue and the first tracker-expansion wave are already dossier-covered, so this folder is an explicit source-backed expansion for another real local boundary-only registry entry.
- `agent-todo.md` currently has **no dedicated `i64-to-i32-lowering` slice**.
- The pass name sounds like a small arithmetic lowering, but the real contract is much larger.
- It sits near already-documented neighbors like `flatten`, `inlining`, and JS-interface legalization, so a future port will benefit from a dedicated canonical explanation instead of scattering the facts across those folders.

## Beginner summary

A good beginner mental model is:

- each logical `i64` value is split into a **low `i32` half** and a **high `i32` half**
- params and locals are duplicated into low/high slots
- most expressions visibly produce only the low half
- the matching high half is tracked in a hidden temp-local side channel
- `i64` returns are lowered to an `i32` return plus one synthetic mutable global that carries the high bits

So this pass is best taught as:

- **whole-program i64 ABI reshaping for wasm2js-style targets**
- not generic integer optimization
- not just load/store splitting
- and not a default optimizer pass

## Most important durable takeaways

- The reviewed implementation is a **non-function-parallel** module-aware AST pass.
- It explicitly requires **flattened** function bodies via `Flat::verifyFlatness(func)`.
- It splits every `i64` param/local into adjacent low/high `i32` slots and names the high slot with a `$hi` suffix.
- It uses a hidden out-param map so the visible AST usually carries the low half while helper temps carry the high half.
- It lowers `i64` returns through the synthetic `INT64_TO_32_HIGH_BITS` global, not through multivalue.
- It rewrites direct and indirect calls, `ref.func` signatures, locals, globals, loads, stores, many unary ops, many binary ops, `select`, `drop`, and `return`.
- Some families still require helper imports or prior cleanup: reinterpret uses wasm2js scratch-memory helpers, some atomic families use wasm2js runtime helpers, and ops like `mul` / `div` / `rem` / `rot` / `popcnt` are expected to be gone already.
- The refreshed dossier now also has a dedicated ABI/opcode coverage ledger so future readers can see, in one place, which families are directly pair-lowered, helper-backed, fallback-only, or still explicitly unsupported.
- The folder is now anchored by an immutable 2026-04-24 raw primary-source manifest plus a 2026-04-26 port-readiness source recheck; the recheck did not correct the upstream algorithm, but it makes first-slice sequencing and local code surfaces explicit.
- The dedicated Starshine strategy page records the exact current local truth: boundary-only registry name, request rejection, no module-pass dispatcher case, no owner file, no active preset role, and no active backlog slice.
- The 2026-04-26 port-readiness bridge adds the missing implementation sequence: registry honesty first, then analyzer-only classification, then a deliberately narrow scalar type/param/local split before calls, globals, returns, memory, helper imports, or atomics.

## Page map

- [`./binaryen-strategy.md`](./binaryen-strategy.md)
  Deep dive into the actual Binaryen implementation, algorithmic phases, helper dependencies, and pass interactions.
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md)
  File-by-file and test-by-test map of the upstream sources that define the pass contract.
- [`./flatness-helpers-and-boundaries.md`](./flatness-helpers-and-boundaries.md)
  Focused guide to the hardest portability facts: flatness precondition, hidden high-half side channel, helper imports, scheduler assumptions, and explicit bailout boundaries.
- [`./abi-surface-and-opcode-coverage.md`](./abi-surface-and-opcode-coverage.md)
  Compact ledger for the real coverage surface: module ABI rewrites, directly pair-lowered opcode families, helper-backed families, fallback-only logic, and explicit unsupported shapes.
- [`./wat-shapes.md`](./wat-shapes.md)
  Beginner-friendly shape catalog showing the main positive, mixed, and bailout WAT families.
- [`./starshine-strategy.md`](./starshine-strategy.md)
  Current Starshine status and future port map: exact registry / dispatcher / type / WAT / binary / validation code surfaces, plus the reasons a faithful port must be a boundary/module pass rather than a HOT-only rewrite.
- [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md)
  Future implementation bridge: no-rewrite analyzer first, scalar local/type split first mutating slice, explicit unsupported-family negatives, and Binaryen oracle validation lanes.

## Current maintenance rule

- Treat this folder as the canonical home for future `i64-to-i32-lowering` research and port planning.
- Keep it explicitly marked as **unimplemented** until Starshine grows a real active pass for it.
- Cite [`../../../raw/binaryen/2026-04-24-i64-to-i32-lowering-primary-sources.md`](../../../raw/binaryen/2026-04-24-i64-to-i32-lowering-primary-sources.md) when restating upstream source-backed claims, cite [`./starshine-strategy.md`](./starshine-strategy.md) when restating local implementation status, and cite [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md) when discussing implementation order or validation lanes.
- Keep the scheduler fact explicit too: this is a real public Binaryen pass, but it is outside the current no-DWARF default optimize path.
- Keep the structural fact explicit too: the reviewed upstream pass expects flattened input and does not by itself cover every remaining `i64` opcode family.
- When future docs summarize the pass quickly, link the ABI/opcode coverage page instead of implying this is a universal arbitrary-`i64` legalizer.

## Sources

- [`../../../raw/binaryen/2026-04-26-i64-to-i32-lowering-port-readiness-primary-sources.md`](../../../raw/binaryen/2026-04-26-i64-to-i32-lowering-port-readiness-primary-sources.md)
- [`../../../raw/research/0412-2026-04-26-i64-to-i32-lowering-port-readiness.md`](../../../raw/research/0412-2026-04-26-i64-to-i32-lowering-port-readiness.md)
- [`../../../raw/binaryen/2026-04-24-i64-to-i32-lowering-primary-sources.md`](../../../raw/binaryen/2026-04-24-i64-to-i32-lowering-primary-sources.md)
- [`../../../raw/research/0299-2026-04-24-i64-to-i32-lowering-primary-sources-and-starshine-followup.md`](../../../raw/research/0299-2026-04-24-i64-to-i32-lowering-primary-sources-and-starshine-followup.md)
- [`../../../raw/research/0175-2026-04-21-i64-to-i32-lowering-binaryen-research.md`](../../../raw/research/0175-2026-04-21-i64-to-i32-lowering-binaryen-research.md)
- [`../../../raw/research/0197-2026-04-21-i64-to-i32-lowering-abi-and-coverage-followup.md`](../../../raw/research/0197-2026-04-21-i64-to-i32-lowering-abi-and-coverage-followup.md)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../../../../../agent-todo.md`](../../../../../agent-todo.md)
- [`../../../raw/research/0063-2026-03-24-pass-port-batches-and-registry-map.md`](../../../raw/research/0063-2026-03-24-pass-port-batches-and-registry-map.md)
- [`../../no-dwarf-default-optimize-path.md`](../../no-dwarf-default-optimize-path.md)
- [`../tracker.md`](../tracker.md)
- [`./starshine-strategy.md`](./starshine-strategy.md)
- [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md)
- Binaryen `version_129` and current-main sources:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/I64ToI32Lowering.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/passes.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/pass.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/abi/js.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/asmjs/shared-constants.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/flat.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/iteration.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/memory-utils.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/module-utils.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/names.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/flatten_i64-to-i32-lowering.wast>
  - <https://github.com/WebAssembly/binaryen/blob/main/src/passes/I64ToI32Lowering.cpp>
