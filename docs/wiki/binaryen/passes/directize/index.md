---
kind: entity
status: working
last_reviewed: 2026-04-21
sources:
  - ../../../raw/research/0126-2026-04-20-directize-binaryen-research.md
  - ../../../raw/research/0209-2026-04-21-directize-source-confirmation-followup.md
  - ../../../../../src/passes/optimize.mbt
  - ../../no-dwarf-default-optimize-path.md
  - ../../../../../agent-todo.md
  - ../../../../../.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/skipped-unimplemented-slots.json
  - ../../../../../.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/summary.json
  - ../../../../../.artifacts/o4z-wasm-opt-debug.log
  - ../tracker.md
related:
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./table-info-and-immutability.md
  - ./wat-shapes.md
  - ../reorder-globals/index.md
  - ../../no-dwarf-default-optimize-path.md
  - ../tracker.md
---

# `directize`

## Role

- `directize` is an upstream Binaryen late boundary / module-shaped indirect-call cleanup pass.
- It is currently **unimplemented** in Starshine.
- In Binaryen `version_129`, it is the **last top-level pass** in the canonical no-DWARF optimize tail.
- Its job is to replace some `call_indirect` / `return_call_indirect` sites with either:
  - a direct `call` / `return_call`, or
  - a known trap represented as `unreachable`, or
  - for a narrow `select` target shape, an `if` whose arms are direct calls and/or `unreachable`.

## Why it matters

- The canonical Binaryen no-DWARF `-O` / `-Os` post-pass phase ends with:
  - `duplicate-import-elimination`
  - `simplify-globals-optimizing`
  - `remove-unused-module-elements`
  - `string-gathering`
  - `reorder-globals`
  - `directize`
- The saved generated-artifact `-O4z` audit records one real skipped top-level upstream slot:
  - slot `56`
- The saved Binaryen debug log shows it is real, but small, in that captured run:
  - about `0.0198565` seconds total around the directize stage
- The backlog already tracks it as slice `DIR` in [`../../../../../agent-todo.md`](../../../../../agent-todo.md).
- `pass.cpp` explicitly says this final rewrite can enable more `inlining` / `dae` opportunities, but that you need `--converge` to come back and exploit them.

That makes `directize` a very important late-tail dossier even though the implementation file is short.

## Beginner summary

A safe beginner mental model is:

- Binaryen first asks whether it really understands a table’s current entry layout,
- then asks whether a specific indirect-call target is definitely one function, definitely a trap, or still unknown,
- and only then rewrites the call.

That is much closer to the real pass than either:

- “constant index means direct call”, or
- “the pass rewrites every kind of indirect call”, or
- “imported tables can never be optimized”.

## Current durable takeaways

- `directize` is a **late table-facts-driven call rewrite pass**, not a generic constant-propagation pass.
- The refreshed dossier now also has a compact source-confirmed owner/test-map page, making explicit that the real `version_129` contract is split across `Directize.cpp`, `call-utils.h`, `table-utils.{h,cpp}`, `type-updating.h`, and the three dedicated `directize*` lit files.
- In `version_129`, the main implementation lives in `src/passes/Directize.cpp`.
- It computes module-wide table facts first with `TableUtils::computeTableInfo(...)`.
- It only visits `CallIndirect` nodes.
  - That includes the tail-call form via `isReturn`, but it does **not** mean `call_ref` is handled here.
- Tables are only entry-optimizable when Binaryen can flatten the relevant element-segment contents and trust the needed entries.
- Imported, exported, and runtime-written tables are conservatively treated as modifiable.
- The optional `--pass-arg=directize-initial-contents-immutable` mode loosens that by allowing optimization from known initial contents even when later growth or mutation may still happen.
- Constant targets classify into three answers:
  - known direct callee
  - known trap
  - unknown
- Known traps become `unreachable`, but child side effects are preserved.
- A narrow `select`-between-known-targets shape lowers to an `if` with fresh locals for the operands.
- Type compatibility uses subtype checking, not just exact signature-name equality.
- Rewrites can refine result types and add locals, so `ReFinalize()` is part of the real contract.

## Current repo caveat

- The current Starshine pass registry already tracks `directize` as a missing late boundary-only name in `src/passes/optimize.mbt`.
- A future port should preserve that this is boundary-shaped work even though the actual body rewrite happens function-by-function, because the correctness gate depends on module-wide table analysis first.

## Page map

- [`./binaryen-strategy.md`](./binaryen-strategy.md)
  Deep dive into the actual Binaryen `version_129` implementation: scheduler placement, pass arg surface, module-wide table analysis, constant-vs-trap-vs-unknown classification, select-lowering, and the real “what this is not” facts.
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md)
  Compact source-confirmed owner/test map for `directize`: what `Directize.cpp`, `call-utils.h`, `table-utils.{h,cpp}`, `type-updating.h`, `pass.cpp`, `passes.h`, and the three shipped lit files each prove about the real pass contract.
- [`./table-info-and-immutability.md`](./table-info-and-immutability.md)
  Focused guide to `TableUtils`, flat-table construction, mutation barriers, the `initial-contents-immutable` mode, hole-vs-out-of-range behavior, and the main table-analysis corner cases a future port must preserve.
- [`./wat-shapes.md`](./wat-shapes.md)
  Beginner-friendly before/after WAT shape catalog for direct-call positives, trap/unreachable rewrites, `select` lowering, mutation and flat-table bailouts, wasm64 width correctness, and GC subtype behavior.

## Current maintenance rule

- Treat this folder as the canonical home for future `directize` research and port planning.
- Keep it explicitly marked as **unimplemented** until Starshine grows a real late boundary/module pass with the correct table-info prepass, constant/`select` target handling, trap preservation, and refinalization behavior.
- Keep the strategy page and the table-info page in sync whenever new evidence changes the answer to either:
  - “when does Binaryen know enough to directize?” or
  - “when does Binaryen intentionally leave the indirect call alone?”

## Sources

- [`../../../raw/research/0126-2026-04-20-directize-binaryen-research.md`](../../../raw/research/0126-2026-04-20-directize-binaryen-research.md)
- [`../../../raw/research/0209-2026-04-21-directize-source-confirmation-followup.md`](../../../raw/research/0209-2026-04-21-directize-source-confirmation-followup.md)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../../no-dwarf-default-optimize-path.md`](../../no-dwarf-default-optimize-path.md)
- [`../../../../../agent-todo.md`](../../../../../agent-todo.md)
- [`../../../../../.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/skipped-unimplemented-slots.json`](../../../../../.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/skipped-unimplemented-slots.json)
- [`../../../../../.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/summary.json`](../../../../../.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/summary.json)
- [`../../../../../.artifacts/o4z-wasm-opt-debug.log`](../../../../../.artifacts/o4z-wasm-opt-debug.log)
- [`../tracker.md`](../tracker.md)
- Binaryen `version_129` implementation and test sources:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/Directize.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/passes.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/call-utils.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/table-utils.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/table-utils.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/type-updating.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/directize_all-features.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/directize-gc.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/directize-wasm64.wast>
