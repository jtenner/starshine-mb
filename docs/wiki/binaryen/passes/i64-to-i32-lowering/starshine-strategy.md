---
kind: concept
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
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/passes/registry_test.mbt
  - ../../../../../src/lib/types.mbt
  - ../../../../../src/lib/util.mbt
  - ../../../../../src/wast/keywords.mbt
  - ../../../../../src/wast/lower_to_lib.mbt
  - ../../../../../src/binary/decode.mbt
  - ../../../../../src/binary/encode.mbt
  - ../../../../../src/validate/env.mbt
  - ../../../../../src/validate/typecheck.mbt
  - ../../../raw/research/0063-2026-03-24-pass-port-batches-and-registry-map.md
  - ../../../../../agent-todo.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./flatness-helpers-and-boundaries.md
  - ./abi-surface-and-opcode-coverage.md
  - ./wat-shapes.md
  - ./starshine-port-readiness-and-validation.md
  - ../legalize-js-interface/index.md
  - ../flatten/index.md
  - ../tracker.md
---

# Starshine strategy for `i64-to-i32-lowering`

## Current local status

Starshine does **not** implement `i64-to-i32-lowering` today.

The exact local status is:

- [`src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt) lists `i64-to-i32-lowering` inside `pass_registry_boundary_only_names()`.
- The same file's pass expansion rejects boundary-only names before dispatching any pass, with the diagnostic that the flag is not implemented in the hot pipeline.
- [`src/passes/pass_manager.mbt`](../../../../../src/passes/pass_manager.mbt) has active module-pass dispatch for the implemented module passes only (`duplicate-function-elimination`, `remove-unused-module-elements`, `memory-packing`, `once-reduction`, `global-refining`, `global-struct-inference`, and `reorder-locals`). There is no `i64-to-i32-lowering` case.
- [`src/passes/registry_test.mbt`](../../../../../src/passes/registry_test.mbt) covers active, boundary-only, and removed category behavior, but there is no pass-specific `i64-to-i32-lowering` implementation or parity test.
- [`../../../raw/research/0063-2026-03-24-pass-port-batches-and-registry-map.md`](../../../raw/research/0063-2026-03-24-pass-port-batches-and-registry-map.md) still lists the pass in Batch 3 under whole-module or layout transforms.
- [`agent-todo.md`](../../../../../agent-todo.md) currently has no dedicated active `i64-to-i32-lowering` slice.

So the honest one-line summary is:

> Starshine preserves the pass name as a boundary-only planning surface, but has no owner file, no dispatcher case, no active preset role, and no committed backlog slice for it yet.

## Why this is not a HOT-only pass

Binaryen's pass rewrites ABI-visible module structure, not just function-local instructions.
A faithful Starshine implementation would need to coordinate at least:

- type-section function signatures
- function-section type indices
- imported and defined function boundaries
- defined globals and imported-global bailouts
- code-section locals and instruction bodies
- direct calls, indirect-call type uses, and `ref.func` signatures
- return ABI through a synthetic high-half global
- helper imports and scratch-memory assumptions for reinterpret / atomic support
- final module validation after rewriting all related surfaces

That means the first landing zone should be a **module or boundary pass**, not a plain HOT pass.
HOT IR may be useful for rewriting function bodies later, but the pass cannot be correct unless the module-level declarations and helper surfaces move in lockstep.

## Exact local code map

### Registry and dispatch

| Local file | Current role | Future port implication |
| --- | --- | --- |
| [`src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt) | owns the `BoundaryOnly` registry category, the `i64-to-i32-lowering` registry name, and the boundary-only rejection path | first implementation step would move the pass from boundary-only to module-pass only after real dispatcher and tests exist |
| [`src/passes/pass_manager.mbt`](../../../../../src/passes/pass_manager.mbt) | owns active module-pass dispatch and final / after-each-pass validation policy | a faithful port needs a new dispatch case only after the pass can rewrite the full module consistently |
| [`src/passes/registry_test.mbt`](../../../../../src/passes/registry_test.mbt) | proves the registry classification behavior | should gain explicit category / request coverage when the pass changes status |

### Type and module model

| Local file | Useful surface |
| --- | --- |
| [`src/lib/types.mbt`](../../../../../src/lib/types.mbt) | defines `ValType::i64`, `FuncType`, `FuncIdx`, `GlobalIdx`, `LocalIdx`, `Locals`, `LocalRun`, function bodies, calls, `ref.func`, globals, i64 loads/stores, atomics, and numeric i64 opcode variants |
| [`src/lib/util.mbt`](../../../../../src/lib/util.mbt) | owns `Locals` run normalization, insertion, mutation, indexing, and `FunctionLocals` construction; a future split-local implementation would need this layer or a module-local equivalent |
| [`src/lib/module.mbt`](../../../../../src/lib/module.mbt) | shows how defined function params plus body locals are viewed together for module display; useful for thinking about rebuilt function-local metadata |

### Text and binary surface

| Local file | Useful surface |
| --- | --- |
| [`src/wast/keywords.mbt`](../../../../../src/wast/keywords.mbt) | contains the current WAT spelling table for `i64`, local/global/call/ref instructions, i64 memory ops, i64 arithmetic, conversions, reinterpret, and SIMD names |
| [`src/wast/lower_to_lib.mbt`](../../../../../src/wast/lower_to_lib.mbt) | lowers WAT type uses, i64 literals, locals, globals, calls, return calls, `ref.func`, i64 numeric ops, loads, and stores into `@lib` IR |
| [`src/binary/decode.mbt`](../../../../../src/binary/decode.mbt) | decodes value types, locals, function/code/global sections, and i64 instruction opcodes |
| [`src/binary/encode.mbt`](../../../../../src/binary/encode.mbt) | encodes value types, locals, function/code/global sections, and i64 instruction opcodes; any lowered module must roundtrip here |

### Validation and proof of correctness

| Local file | Useful surface |
| --- | --- |
| [`src/validate/env.mbt`](../../../../../src/validate/env.mbt) | builds the environment for function, global, memory, local, and type lookups; a future module rewrite must leave this environment coherent |
| [`src/validate/typecheck.mbt`](../../../../../src/validate/typecheck.mbt) | validates `i64` constants, loads/stores, atomics, locals, globals, calls, return calls, `ref.func`, and numeric op stack behavior |

### HOT IR cautionary surfaces

| Local file | Why it is only a neighbor today |
| --- | --- |
| [`src/ir/hot_lift.mbt`](../../../../../src/ir/hot_lift.mbt) | proves Starshine can lift many function-body shapes, including i64 examples in tests, but it does not own module ABI rewriting |
| [`src/ir/hot_lower.mbt`](../../../../../src/ir/hot_lower.mbt) | proves Starshine can lower rewritten HOT bodies back to `@lib`, but it does not own type-section, import, global, or helper-import surgery |

## Strategy shape for a future Starshine port

For the newer implementation sequence and validation ladder, start with [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md). The key update from the 2026-04-26 recheck is that the first Starshine work should be registry-honesty and analyzer-only classification before any mutating ABI rewrite.

A faithful local port should be staged as a module pass with explicit gates.
The minimum strategy is:

1. **Registry and validation gate**
   - keep the pass boundary-only until a full module rewrite exists
   - add focused request tests before moving it to module-pass status
   - validate the final module after the rewrite
2. **Flatness policy**
   - either require an equivalent of Binaryen's flattened input or run a local flatten-equivalent step first
   - do not silently run the pair-lowering algorithm on arbitrary nested trees without proving single-evaluation behavior
3. **Type/signature rewrite**
   - rewrite every function type that mentions `i64` params/results according to the Binaryen pair-lowering ABI
   - update function-section references and `call_indirect` / `ref.func` type uses consistently
4. **Global rewrite**
   - split defined `i64` globals into low/high globals
   - preserve Binaryen's unsupported imported-`i64` global boundary unless the local port intentionally implements a larger contract and documents that divergence
5. **Local rewrite**
   - rebuild params and body locals so each original `i64` slot becomes adjacent low/high `i32` slots
   - decide how Starshine will represent the high-half side channel in function-body rewrite code
6. **Body rewrite**
   - lower the ABI and expression families summarized in [`./abi-surface-and-opcode-coverage.md`](./abi-surface-and-opcode-coverage.md)
   - preserve single-evaluation temps for pointers, conditions, calls, returns, and helper-backed conversions
7. **Helper imports and memory assumptions**
   - materialize wasm2js helper imports and scratch-memory support only where the upstream contract does
   - keep helper effects visible to downstream analysis rather than treating them as pure rewrites
8. **Unsupported families and parity tests**
   - preserve upstream fatal / unsupported boundaries for imported `i64` globals, `i64` result `return_call`, direct `i64` atomic load/store splitting, `i64` atomic cmpxchg, and assumed-gone hard arithmetic families unless a future port deliberately expands scope
   - record any deliberate expansion as Starshine-specific behavior, not Binaryen parity

## Binaryen-to-Starshine mapping

| Binaryen concept | Starshine equivalent / gap |
| --- | --- |
| `Flat::verifyFlatness(func)` | no dedicated `i64-to-i32-lowering` flatten precondition yet; future port must choose an explicit policy |
| low-visible / high-hidden expression model | no current local side-channel abstraction; likely needs module-pass-local metadata or carefully structured temp locals |
| adjacent low/high locals | `Locals` / `FunctionLocals` can express the result, but no current pass rebuilds params/body locals for this ABI |
| `INT64_TO_32_HIGH_BITS` global | no current helper global materialization for this pass |
| `legalfunc$...` imported-call retargeting | Starshine has no `legalize-js-interface` pass; see the neighboring [`../legalize-js-interface/index.md`](../legalize-js-interface/index.md) dossier for the upstream prerequisite story |
| wasm2js helpers | no current helper-import materialization layer for this pass |
| direct / indirect call and `ref.func` signature rewrite | core `@lib` types can represent the rewrite, but no current pass owns the coordinated remap |

## Non-goals for current Starshine

Do not claim any of these today:

- that `i64-to-i32-lowering` is available through `--optimize` or `--shrink`
- that the pass can be requested successfully
- that a HOT-only body rewrite would be enough
- that Starshine has an in-tree equivalent of Binaryen's helper-import and synthetic high-global ABI
- that the pass is part of current no-DWARF Binaryen parity work

## Reader path

For this pass, read in this order:

1. [`./index.md`](./index.md) for purpose, status, validation, and page map
2. [`./wat-shapes.md`](./wat-shapes.md) for transformed shapes
3. [`./binaryen-strategy.md`](./binaryen-strategy.md) for upstream algorithm
4. [`./flatness-helpers-and-boundaries.md`](./flatness-helpers-and-boundaries.md) for the main correctness constraints
5. [`./abi-surface-and-opcode-coverage.md`](./abi-surface-and-opcode-coverage.md) for coverage boundaries
6. this page for current Starshine status and future code-map landing zones
7. [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md) before writing implementation code, so the first slice and validation lane are explicit

## Sources

- [`../../../raw/binaryen/2026-04-26-i64-to-i32-lowering-port-readiness-primary-sources.md`](../../../raw/binaryen/2026-04-26-i64-to-i32-lowering-port-readiness-primary-sources.md)
- [`../../../raw/research/0412-2026-04-26-i64-to-i32-lowering-port-readiness.md`](../../../raw/research/0412-2026-04-26-i64-to-i32-lowering-port-readiness.md)
- [`../../../raw/binaryen/2026-04-24-i64-to-i32-lowering-primary-sources.md`](../../../raw/binaryen/2026-04-24-i64-to-i32-lowering-primary-sources.md)
- [`../../../raw/research/0299-2026-04-24-i64-to-i32-lowering-primary-sources-and-starshine-followup.md`](../../../raw/research/0299-2026-04-24-i64-to-i32-lowering-primary-sources-and-starshine-followup.md)
- [`../../../raw/research/0175-2026-04-21-i64-to-i32-lowering-binaryen-research.md`](../../../raw/research/0175-2026-04-21-i64-to-i32-lowering-binaryen-research.md)
- [`../../../raw/research/0197-2026-04-21-i64-to-i32-lowering-abi-and-coverage-followup.md`](../../../raw/research/0197-2026-04-21-i64-to-i32-lowering-abi-and-coverage-followup.md)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../../../../../src/passes/pass_manager.mbt`](../../../../../src/passes/pass_manager.mbt)
- [`../../../../../src/passes/registry_test.mbt`](../../../../../src/passes/registry_test.mbt)
- [`../../../../../src/lib/types.mbt`](../../../../../src/lib/types.mbt)
- [`../../../../../src/lib/util.mbt`](../../../../../src/lib/util.mbt)
- [`../../../../../src/wast/keywords.mbt`](../../../../../src/wast/keywords.mbt)
- [`../../../../../src/wast/lower_to_lib.mbt`](../../../../../src/wast/lower_to_lib.mbt)
- [`../../../../../src/binary/decode.mbt`](../../../../../src/binary/decode.mbt)
- [`../../../../../src/binary/encode.mbt`](../../../../../src/binary/encode.mbt)
- [`../../../../../src/validate/env.mbt`](../../../../../src/validate/env.mbt)
- [`../../../../../src/validate/typecheck.mbt`](../../../../../src/validate/typecheck.mbt)
- [`../../../raw/research/0063-2026-03-24-pass-port-batches-and-registry-map.md`](../../../raw/research/0063-2026-03-24-pass-port-batches-and-registry-map.md)
- [`../../../../../agent-todo.md`](../../../../../agent-todo.md)
