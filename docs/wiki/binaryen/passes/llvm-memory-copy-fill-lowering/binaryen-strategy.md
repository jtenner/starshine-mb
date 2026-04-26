---
kind: pass-strategy
status: supported
last_reviewed: 2026-04-26
sources:
  - ../../../raw/binaryen/2026-04-26-llvm-memory-copy-fill-lowering-primary-sources.md
  - ../../../raw/research/0384-2026-04-26-llvm-memory-copy-fill-lowering-source-dossier.md
  - ../../../raw/binaryen/2026-04-26-llvm-memory-copy-fill-lowering-port-readiness-primary-sources.md
  - ../../../raw/research/0414-2026-04-26-llvm-memory-copy-fill-lowering-port-readiness.md
related:
  - ./index.md
  - ./wat-shapes.md
  - ./helper-call-lowering-and-boundaries.md
  - ./implementation-structure-and-tests.md
  - ./starshine-port-readiness-and-validation.md
---

# Binaryen strategy: `llvm-memory-copy-fill-lowering`

## High-level strategy

Binaryen treats `llvm-memory-copy-fill-lowering` as a small compatibility transform:

1. Require bulk memory to be enabled, and reject unsupported feature surfaces before rewriting.
2. Create module-local helper functions named from `__memory_copy` and `__memory_fill` with `(i32, i32, i32) -> none` signatures.
3. Walk function bodies looking for `memory.copy` and `memory.fill`.
4. Replace each bulk-memory instruction with a helper call that receives the same logical operands.
5. Populate only used helper bodies, remove unused helpers, and clear the bulk-memory optional feature bit.
6. Leave unrelated bulk-memory, data-segment, table-bulk, and memory-layout constructs to other passes.

This is different from most Starshine pass dossiers because the win is not smaller or faster WebAssembly. The win is output compatibility with consumers that expect helper calls instead of native bulk-memory instructions.

## Source ownership

The primary upstream owner is `src/passes/LLVMMemoryCopyFillLowering.cpp` in Binaryen `version_129` and current `main`.[^manifest]

Registration is separate from the memory optimizer family:

- `src/passes/pass.cpp` exposes the public pass name `llvm-memory-copy-fill-lowering`.
- `src/passes/passes.h` declares the factory.

The separate registration matters because this pass should not be documented as:

- `memory-packing` - that pass repacks data segments and rewrites segment users;
- `multi-memory-lowering` - that pass combines many memories into one and shifts addresses;
- `memory64-lowering` - that pass narrows 64-bit memory/table address surfaces;
- `llvm-nontrapping-fptoint-lowering` - a different LLVM compatibility lowering family for numeric conversions.

## Transform model

The source-backed model is helper-call replacement to local helper functions, not imports:

```wat
;; before
(local.get $dst)
(local.get $src)
(local.get $len)
memory.copy

;; after, schematic only
(local.get $dst)
(local.get $src)
(local.get $len)
call $__memory_copy
```

```wat
;; before
(local.get $dst)
(i32.const 0)
(local.get $len)
memory.fill

;; after, schematic only
(local.get $dst)
(i32.const 0)
(local.get $len)
call $__memory_fill
```

The public helper base names are source-confirmed as `__memory_copy` and `__memory_fill`; Binaryen still may choose conflict-avoiding variants through its normal name allocator, so oracle tests should normalize helper suffixes when needed.

## Correctness constraints

A helper-call lowering must preserve observable behavior:

- operands must be evaluated in the same order;
- traps from operand evaluation must remain before helper execution;
- memory writes must remain ordered with surrounding memory operations;
- `memory.copy` overlap semantics must be delegated to a helper that implements the same semantics;
- `memory.fill` byte-value truncation semantics must be preserved;
- the module must validate after helper functions are inserted;
- multi-memory and memory64 inputs must not be silently rewritten because Binaryen treats them as fatal boundaries here;
- passive data/table segments and `table.copy` / `table.fill` are outside this pass;
- bulk-memory feature metadata is removed only after covered uses are lowered.

Binaryen's owner file also notes that it does not model LLVM undefined behavior such as pointer overflow; Starshine parity tests should not impose stricter behavior than the upstream oracle.

## Current-main drift check

A 2026-04-26 spot check of official Binaryen current-main owner/registration/factory files found no teaching-relevant drift from the `version_129` contract recorded here. The pass remains a memory32 single-memory bulk-memory helper-function lowering pass with the same unsupported-boundary fatal checks.

## Test-surface caveat

The focused 2026-04-26 source ingest did not find a dedicated pass-named `llvm-memory-copy-fill-lowering.wast` file in the checked official `test/lit/passes` directories. This dossier therefore cites the owner file and registration files as the direct proof surface and treats any future standalone lit fixture as a thing to add when found, not as an already-existing proof.

[^manifest]: [`../../../raw/binaryen/2026-04-26-llvm-memory-copy-fill-lowering-primary-sources.md`](../../../raw/binaryen/2026-04-26-llvm-memory-copy-fill-lowering-primary-sources.md)
