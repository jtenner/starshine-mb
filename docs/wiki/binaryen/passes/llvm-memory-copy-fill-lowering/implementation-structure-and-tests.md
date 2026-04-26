---
kind: implementation-map
status: supported
last_reviewed: 2026-04-26
sources:
  - ../../../raw/binaryen/2026-04-26-llvm-memory-copy-fill-lowering-primary-sources.md
  - ../../../raw/research/0384-2026-04-26-llvm-memory-copy-fill-lowering-source-dossier.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
---

# Implementation structure and tests: `llvm-memory-copy-fill-lowering`

## Upstream owner files

| Surface | Role |
| --- | --- |
| `src/passes/LLVMMemoryCopyFillLowering.cpp` | Primary Binaryen owner file. Finds `memory.copy` / `memory.fill` and rewrites them to LLVM/Emscripten-style helper calls. |
| `src/passes/pass.cpp` | Registers the public pass name `llvm-memory-copy-fill-lowering`. |
| `src/passes/passes.h` | Declares the pass factory. |

The 2026-04-26 current-main spot check found no teaching-relevant drift from the `version_129` source contract recorded in the raw manifest.

## Upstream proof surface

The source owner file is the direct proof for behavior. A focused check of official `version_129` and current-main `test/lit/passes` directories did **not** find a dedicated pass-named `llvm-memory-copy-fill-lowering.wast` fixture.

Practical implication for this wiki:

- cite `LLVMMemoryCopyFillLowering.cpp` and pass registration for the source contract;
- do not claim a standalone upstream lit fixture until one is found;
- if Starshine implements the pass, add local reduced tests that directly cover the shapes in [`wat-shapes.md`](wat-shapes.md).

## What a Starshine owner would need

A future local implementation would likely be a module/function rewrite rather than a pure HOT peephole, because helper declarations may need to be inserted or reused.

Minimum owner responsibilities:

1. scan function bodies for `MemoryCopy` and `MemoryFill`;
2. ensure helper import/function declarations exist with source-confirmed signatures;
3. replace the instruction with a call while preserving operand order;
4. update any function/type/import metadata required by the helper declarations;
5. validate the resulting module.

## Local source map today

| Starshine surface | Current role |
| --- | --- |
| `src/wast/types.mbt:309-310` | WAST opcode tags include `MemoryFill` and `MemoryCopy`. |
| `src/wast/lower_to_lib.mbt:2295-2301` | WAST lowering maps those opcodes to lib IR for memory zero in text-format lowering. |
| `src/lib/types.mbt:780-781` | Lib IR represents `MemoryCopy(MemIdx, MemIdx)` and `MemoryFill(MemIdx)`. |
| `src/binary/encode.mbt:3055-3074` | Binary encoder emits bulk-memory opcodes for `memory.copy` and `memory.fill`. |
| `src/validate/typecheck.mbt:3137-3138` | Typechecker dispatches to memory copy/fill typing rules. |
| `src/validate/validate.mbt:2086-2118` | Data-count requirement tracks `MemoryInit` / `DataDrop`, not `MemoryCopy` / `MemoryFill`. |
| `src/ir/hot_lift.mbt:717-718` | HOT lift recognizes `MemoryCopy` and `MemoryFill`. |
| `src/ir/hot_lower.mbt:970-977` | HOT lower can emit `MemoryCopy` and `MemoryFill` back to lib IR. |
| `src/passes/optimize.mbt:107-129` | Public pass registry arrays omit `llvm-memory-copy-fill-lowering`; current requests should be unknown, not boundary-only. |

## Regression tests to add if implemented

- Registry test: `llvm-memory-copy-fill-lowering` appears with the chosen implementation category.
- Module rewrite tests:
  - helper import insertion for first `memory.copy`;
  - helper reuse for multiple copies/fills;
  - `memory.copy` operand order;
  - `memory.fill` operand order and value truncation behavior delegated to helper;
  - no rewrite of `memory.init` / `data.drop`.
- Validation tests:
  - helper function type is well-formed;
  - imports and function indices remain consistent;
  - rewritten module validates.
- Oracle tests:
  - compare reduced fixtures against `wasm-opt --llvm-memory-copy-fill-lowering` after normalizing helper naming if Binaryen chooses implementation-specific helper names.
