---
kind: implementation-map
status: supported
last_reviewed: 2026-04-26
sources:
  - ../../../raw/binaryen/2026-04-26-llvm-memory-copy-fill-lowering-primary-sources.md
  - ../../../raw/research/0384-2026-04-26-llvm-memory-copy-fill-lowering-source-dossier.md
  - ../../../raw/binaryen/2026-04-26-llvm-memory-copy-fill-lowering-port-readiness-primary-sources.md
  - ../../../raw/research/0414-2026-04-26-llvm-memory-copy-fill-lowering-port-readiness.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
---

# Implementation structure and tests: `llvm-memory-copy-fill-lowering`

## Upstream owner files

| Surface | Role |
| --- | --- |
| `src/passes/LLVMMemoryCopyFillLowering.cpp` | Primary Binaryen owner file. Finds `memory.copy` / `memory.fill`, rejects unsupported memory64/multi-memory/passive/table-bulk surfaces, creates local `__memory_copy` / `__memory_fill` helpers, rewrites uses to calls, populates used helpers, removes unused helpers, and clears bulk-memory features. |
| `src/passes/pass.cpp` | Registers the public pass name `llvm-memory-copy-fill-lowering`. |
| `src/passes/passes.h` | Declares the pass factory. |

The first 2026-04-26 current-main spot check found no teaching-relevant drift from the `version_129` source contract recorded in the raw manifest. The later 2026-04-26 port-readiness recheck refined the dossier by confirming helper functions, exact unsupported fatal boundaries, and feature cleanup; it did not find a current-main behavioral drift.

## Upstream proof surface

The source owner file is the direct proof for behavior. A focused check of official `version_129` and current-main `test/lit/passes` directories did **not** find a dedicated pass-named `llvm-memory-copy-fill-lowering.wast` fixture.

Practical implication for this wiki:

- cite `LLVMMemoryCopyFillLowering.cpp` and pass registration for the source contract;
- do not claim a standalone upstream lit fixture until one is found;
- if Starshine implements the pass, add local reduced tests that directly cover the shapes in [`wat-shapes.md`](wat-shapes.md).

## What a Starshine owner would need

A future local implementation would likely be a module/function rewrite rather than a pure HOT peephole, because helper declarations may need to be inserted or reused.

Minimum owner responsibilities:

1. scan function bodies for eligible memory32 single-memory `MemoryCopy` and `MemoryFill`;
2. reject or preserve memory64, multi-memory, passive segment, and table-bulk shapes according to a documented local policy;
3. ensure local `__memory_copy` / `__memory_fill` helper functions exist with `(i32, i32, i32) -> none` signatures;
4. replace the instruction with a call while preserving operand order;
5. generate the helper bodies with bounds checks and byte-loop behavior, including overlap-sensitive copy direction;
6. update function/type metadata and any feature metadata required by the helper functions;
7. validate the resulting module.

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
| `src/passes/optimize.mbt:118-129` | Public boundary-only registry names omit `llvm-memory-copy-fill-lowering`; current requests should be unknown, not boundary-only. |

## Regression tests to add if implemented

- Registry test: `llvm-memory-copy-fill-lowering` appears with the chosen implementation category.
- Module rewrite tests:
  - helper function creation and population for first `memory.copy`;
  - helper reuse for multiple copies/fills;
  - `memory.copy` operand order;
  - `memory.fill` operand order and value truncation behavior delegated to helper;
  - no rewrite of `memory.init` / `data.drop`;
  - explicit unsupported-boundary behavior for memory64, multi-memory, passive segment, `table.copy`, and `table.fill`.
- Validation tests:
  - helper function type is well-formed;
  - imports and function indices remain consistent;
  - rewritten module validates.
- Oracle tests:
  - compare reduced memory32 single-memory fixtures against `wasm-opt --llvm-memory-copy-fill-lowering` after normalizing helper-name suffixes if Binaryen chooses conflict-avoiding names.
