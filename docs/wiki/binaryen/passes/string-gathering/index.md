---
kind: entity
status: supported
last_reviewed: 2026-05-19
sources:
  - ../../../raw/research/0526-2026-05-06-string-gathering-direct-revalidation.md
  - ../../../raw/binaryen/2026-05-04-string-gathering-current-main-recheck.md
  - ../../../raw/research/0431-2026-05-04-string-gathering-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-25-string-gathering-current-main-and-port-readiness.md
  - ../../../raw/research/0377-2026-04-25-string-gathering-port-readiness.md
  - ../../../raw/binaryen/2026-04-23-string-gathering-primary-sources.md
  - ../../../raw/research/0124-2026-04-20-string-gathering-binaryen-research.md
  - ../../../raw/research/0206-2026-04-21-string-gathering-source-confirmation-followup.md
  - ../../../raw/research/0280-2026-04-23-string-gathering-primary-sources-and-starshine-followup.md
  - ../../../../../src/passes/string_gathering.mbt
  - ../../../../../src/passes/string_gathering_test.mbt
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/cmd/cmd_wbtest.mbt
  - ../../no-dwarf-default-optimize-path.md
  - ../../../../../agent-todo.md
  - ../../../strings/string-const-surface.md
  - ../../../../../.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/skipped-unimplemented-slots.json
  - ../../../../../.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/summary.json
  - ../../../../../.artifacts/o4z-wasm-opt-debug.log
  - ../tracker.md
related:
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./reuse-naming-and-ordering.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
  - ../simplify-globals-optimizing/index.md
  - ../string-lowering/index.md
  - ../string-lifting/index.md
  - ../../../strings/string-const-surface.md
  - ../../no-dwarf-default-optimize-path.md
  - ../tracker.md
---

# `string-gathering`

## Role

- `string-gathering` is an upstream Binaryen late module / boundary-shaped cleanup pass.
- It is now implemented in Starshine as an active direct module pass and is scheduled in the public `optimize` / `shrink` late tail before `reorder-globals` and `directize`.
- In Binaryen `version_129`, it runs only when strings are enabled and the optimize level is high enough.
- Its job is very specific: hoist or reuse canonical immutable globals for `string.const` values, then replace ordinary `string.const` uses with `global.get` of those globals.

## Why this dossier needed a follow-up

The earlier folder already had a good working explanation of the pass, but it still lacked three durable pieces:

- an immutable raw primary-source manifest
- a dedicated Starshine strategy page
- and one compact source-confirmed page for the real owner-file map, implementation phases, and test-vs-source coverage boundary

That follow-up closed those gaps without overturning the basic earlier picture. The 2026-04-25 refresh added a current-main no-drift / port-readiness bridge and a dedicated Starshine validation ladder; the 2026-04-30 landing then turned that research into an active direct module pass, and the 2026-05-04 recheck refreshed the exact local code anchors without changing the contract.

## Why it matters

- The canonical Binaryen no-DWARF `-O` / `-Os` post-pass phase runs `string-gathering` after:
  - `duplicate-import-elimination`
  - `simplify-globals-optimizing`
  - `remove-unused-module-elements`
- and before:
  - `reorder-globals`
  - `directize`
- The saved generated-artifact `-O4z` audit records one real skipped top-level upstream slot:
  - slot `54`
- The saved Binaryen debug log shows it is small but real:
  - `0.00280223` seconds in the captured generated-artifact run
- The backlog now records no active v0.1.0 SG/RG/DIR preset-order blocker; after regenerating `tests/node/dist/starshine-debug-wasi.wasm` with `moon build --target wasm`, the targeted `string-gathering -> reorder-globals -> directize` replay reached canonical wasm and normalized WAT equality.
- The repo’s own string-constant surface page already called this out as the next durable string follow-up after literal plumbing.

## Beginner summary

A safe beginner mental model is:

- Binaryen looks for every `string.const` in the module,
- makes sure each distinct literal has one canonical immutable string global,
- then rewrites other uses to read from that global.

That is much closer to the real pass than either:

- “lower stringref to imports”, or
- “optimize string operations”, or
- “delete duplicate globals”.

## Current durable takeaways

- `string-gathering` is a **module-wide structural rewrite**, not a function-local peephole.
- The 2026-05-04 current-main recheck refreshed the exact local line anchors and still found no teaching-relevant upstream drift.
- In `version_129`, the implementation lives inside `src/passes/StringLowering.cpp` as a standalone `StringGathering` pass struct.
- `StringLowering` subclasses `StringGathering` and runs it first, so this pass is also the shared first phase of full string lowering.
- [`string-lifting`](../string-lifting/index.md) is the opposite-direction sibling that raises known JS-string imports and helper calls back into wasm strings; it is related to the string family but does not replace this canonicalization pass.
- The function-body scan is parallel, but module-level expression code is scanned separately through `walkModuleCode(...)`.
- The dedicated lit file directly proves the global-initializer / reuse / reorder families, while some broader module-code coverage remains source-derived from the walker surface.
- The pass only rewrites `StringConst` nodes; it does not rewrite preexisting `global.get` users.
- Reusable existing globals are much narrower than many first guesses:
  - defined, not imported
  - immutable
  - exact non-null stringref type
  - direct `string.const` initializer
- Nullable, mutable, or nested users are **not** reused as canonical defining globals.
- The pass remembers exact expression-pointer locations, so replacement is a direct AST-slot rewrite rather than a second search.
- A focused 2026-04-25 current-main bridge found no teaching-relevant drift from the tagged `version_129` contract in the checked source and test surfaces.
- It scans function bodies in parallel and also scans module-level code, including defined global initializers and other module expression slots reached by `walkModuleCode(...)`.
- Its internal global reorder is only a validity repair: defining string globals first.
- Final global layout is intentionally left to the following `reorder-globals` pass.

## Current repo caveat

- The direct pass is active in `src/passes/string_gathering.mbt`, registered in `src/passes/optimize.mbt`, dispatched from `src/passes/pass_manager.mbt`, and accepted by the compare harness.
- On 2026-05-18, refreshed direct-pass signoff in `.tmp/pass-fuzz-string-gathering-order-20260518` reached 6759 / 10000 compared cases with 6759 normalized matches, 0 semantic mismatches, 0 validation failures, 0 generator failures, and 20 Binaryen empty-recursion-group parser/canonicalization command failures.
- The direct pass now sorts fresh literal globals deterministically, reuses eligible existing immutable non-null direct `string.const` globals in module order, preserves the selected defining initializer, aliases later matching globals, and still creates fresh canonical globals when no reusable definition exists.
- Focused edge tests now also lock that imported string globals are never reused as defining globals, that a nested global initializer containing `string.const` is collected/replaced but not treated as the canonical definition, that table initializer / typed element expression constants are rewritten to the canonical string global, and that module-expression global references are remapped after inserted string globals shift existing defined globals.
- Nullable string global non-reuse remains a local representation caveat: `ValType::stringref()` is currently represented as `AbsHeapTypeRefType(String)`, whose `RefType::is_nullable()` reports nullable, so Starshine cannot yet write a meaningful focused test that distinguishes Binaryen's nullable-vs-exact-non-null string global eligibility.
- Binary wasm inputs with string proposal result types previously exposed decoder coverage gaps outside this pass (`DecodeAt(InvalidValType, ...)`). The first decoder-breadth fix now accepts bare `0x64` stringref value types when the explicit non-null-reference form cannot be completed, so standalone stringref result-type modules can reach later passes. Broader proposal encoding coverage may still need future tests as new fixtures appear.
- Public `optimize` / `shrink` preset scheduling now appends `string-gathering -> reorder-globals -> directize`; the regenerated debug-artifact replay is semantically/canonically green, with a combined-tail performance follow-up candidate (`62.619ms` Starshine pass runtime vs `28.215ms` Binaryen).

## Page map

- [`./binaryen-strategy.md`](./binaryen-strategy.md)
  Deep dive into the actual Binaryen `version_129` implementation: scheduler placement, phase breakdown, helper dependencies, module-code scan surface, and the real “what this is not” facts.
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md)
  Compact owner-file and shipped-test map showing that the real pass lives in `StringLowering.cpp`, shares structure with `StringLowering`, uses exact-slot `StringConst` scanning plus separate `walkModuleCode(...)` coverage, and is directly proven by `test/lit/passes/string-gathering.wast`.
- [`./reuse-naming-and-ordering.md`](./reuse-naming-and-ordering.md)
  Focused guide to reusable-global detection, first-match canonicalization, generated global names, stability across repeated runs, and the validity-first reorder before `reorder-globals`.
- [`./wat-shapes.md`](./wat-shapes.md)
  Beginner-friendly before/after WAT and module-shape catalog for the main positive, negative, bailout, and interaction families.
- [`./starshine-strategy.md`](./starshine-strategy.md)
  Exact current Starshine status and code-map page: the active direct module pass, public preset-tail scheduling, the existing `string.const` / `stringrefs` encode-decode plumbing, and the still-separate late-tail boundary with `reorder-globals`.
- [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md)
  Current validation ledger: landed registry/module-pass/direct-site collection work, focused reduced tests, direct Binaryen oracle evidence, public preset-order coverage, and the remaining decoder / artifact-replay caveat.

## Current maintenance rule

- Treat this folder as the canonical home for future `string-gathering` research, maintenance, and remaining follow-up planning.
- Keep it explicitly marked as **implemented as a direct module pass scheduled in public presets** while the remaining gaps stay visible: broader standalone string-proposal decoder coverage and any future combined-tail performance work.
- Keep the strategy page and the reuse/order page in sync whenever new evidence changes the answer to either:
  - “which globals can be reused?” or
  - “when must gathered globals move earlier?”

## Sources

- [`../../../raw/research/0526-2026-05-06-string-gathering-direct-revalidation.md`](../../../raw/research/0526-2026-05-06-string-gathering-direct-revalidation.md)
- [`../../../raw/binaryen/2026-04-25-string-gathering-current-main-and-port-readiness.md`](../../../raw/binaryen/2026-04-25-string-gathering-current-main-and-port-readiness.md)
- [`../../../raw/research/0377-2026-04-25-string-gathering-port-readiness.md`](../../../raw/research/0377-2026-04-25-string-gathering-port-readiness.md)
- [`../../../raw/binaryen/2026-04-23-string-gathering-primary-sources.md`](../../../raw/binaryen/2026-04-23-string-gathering-primary-sources.md)
- [`../../../raw/research/0124-2026-04-20-string-gathering-binaryen-research.md`](../../../raw/research/0124-2026-04-20-string-gathering-binaryen-research.md)
- [`../../../raw/research/0206-2026-04-21-string-gathering-source-confirmation-followup.md`](../../../raw/research/0206-2026-04-21-string-gathering-source-confirmation-followup.md)
- [`../../../raw/research/0280-2026-04-23-string-gathering-primary-sources-and-starshine-followup.md`](../../../raw/research/0280-2026-04-23-string-gathering-primary-sources-and-starshine-followup.md)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../../no-dwarf-default-optimize-path.md`](../../no-dwarf-default-optimize-path.md)
- [`../../../../../agent-todo.md`](../../../../../agent-todo.md)
- [`../../../strings/string-const-surface.md`](../../../strings/string-const-surface.md)
- [`../../../../../.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/skipped-unimplemented-slots.json`](../../../../../.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/skipped-unimplemented-slots.json)
- [`../../../../../.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/summary.json`](../../../../../.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/summary.json)
- [`../../../../../.artifacts/o4z-wasm-opt-debug.log`](../../../../../.artifacts/o4z-wasm-opt-debug.log)
- [`../tracker.md`](../tracker.md)
- Binaryen `version_129` implementation and test sources:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/StringLowering.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/passes.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/string-utils.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/string-utils.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/module-utils.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/wasm-traversal.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/string-gathering.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/propagate-globals-globally.wast>
