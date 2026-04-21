---
kind: entity
status: working
last_reviewed: 2026-04-21
sources:
  - ../../../raw/research/0165-2026-04-21-optimize-added-constants-propagate-binaryen-research.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../docs/0063-2026-03-24-pass-port-batches-and-registry-map.md
  - ../../no-dwarf-default-optimize-path.md
  - ../tracker.md
  - ../../../../../agent-todo.md
related:
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./wat-shapes.md
  - ../optimize-added-constants/index.md
  - ../precompute/index.md
  - ../tracker.md
---

# `optimize-added-constants-propagate`

## Role

- `optimize-added-constants-propagate` is an upstream Binaryen function pass.
- It is currently **unimplemented** in Starshine and still lives in the removed-name registry in [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt).
- It shares `version_129` implementation code with the plain sibling [`../optimize-added-constants/index.md`](../optimize-added-constants/index.md), but it enables the extra local-pair propagation mode.
- It is **not** part of the repo's current canonical no-DWARF `-O` / `-Os` path because that path is not documented with `--low-memory-unused` enabled.

## Why this pass matters

- The original campaign queues are closed, so this dossier is an explicit tracker expansion for another real local registry name.
- `agent-todo.md` currently has **no dedicated `optimize-added-constants-propagate` slice**.
- The pass is easy to mis-teach because its name sounds like generic constant propagation, but the real contract is about **rewriting memory addresses into load/store offsets**.
- The `propagate` sibling adds a real extra algorithm on top of the plain pass: it can look through certain `local.set` / `local.get` pairs and move the offset to the memory access anyway.

## Beginner summary

A good beginner mental model is:

- find a memory access like `load(base + 8)`,
- turn it into `load offset=8 (base)`,
- and in `propagate` mode, still do that even if `base + 8` first got stored in a local.

So the pass is best read as:

- **memory-address offset propagation**, not arithmetic expression propagation.

## Current durable takeaways

- The pass only matters for `Load` / `Store` pointer expressions.
- It requires `--low-memory-unused`; otherwise Binaryen aborts the pass.
- The reviewed `version_129` threshold comes from `PassOptions::LowMemoryBound = 1024`.
- Plain mode handles direct memory-address shapes; propagate mode also uses `LazyLocalGraph` to chase certain local pairs.
- Propagation is intentionally conservative: extra uses can block it, and helper locals may be inserted when direct SSA reuse is unsafe.

## Page map

- [`./binaryen-strategy.md`](./binaryen-strategy.md)
  Deep dive into the actual Binaryen `version_129` implementation: phases, helper utilities, scheduler meaning, and what the pass really does.
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md)
  File-by-file and test-by-test map of the upstream sources that define the pass contract.
- [`./wat-shapes.md`](./wat-shapes.md)
  Beginner-friendly before/after shape catalog for the main positive, bailout, preserved, and easy-to-misread load/store-address families.

## Current maintenance rule

- Treat this folder as the canonical home for future `optimize-added-constants-propagate` research and port planning.
- Keep it explicitly marked as **unimplemented** until Starshine grows a real pass for it.
- Keep the relationship to the plain sibling explicit: the shared implementation file is real, but `propagate` mode is still a separate public contract with extra analysis and rewrite behavior.

## Sources

- [`../../../raw/research/0165-2026-04-21-optimize-added-constants-propagate-binaryen-research.md`](../../../raw/research/0165-2026-04-21-optimize-added-constants-propagate-binaryen-research.md)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../../../../../docs/0063-2026-03-24-pass-port-batches-and-registry-map.md`](../../../../../docs/0063-2026-03-24-pass-port-batches-and-registry-map.md)
- [`../../no-dwarf-default-optimize-path.md`](../../no-dwarf-default-optimize-path.md)
- [`../tracker.md`](../tracker.md)
- [`../../../../../agent-todo.md`](../../../../../agent-todo.md)
- Binaryen `version_129` implementation and test sources:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/OptimizeAddedConstants.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/pass.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/optimize-added-constants-propagate_low-memory-unused.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/optimize-added-constants-propagate_low-memory-unused.txt>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/optimize-added-constants-memory64.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/optimize-added-constants-nomemory.wast>
