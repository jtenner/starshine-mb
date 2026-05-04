---
kind: raw-source
status: supported
last_reviewed: 2026-05-04
sources:
  - https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/ReorderTypes.cpp
  - https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/pass.cpp
  - https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/ir/type-updating.cpp
  - https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/ir/type-updating.h
  - https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/ir/module-utils.cpp
  - https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/ir/module-utils.h
  - https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/reorder-types.wast
related:
  - ../research/0438-2026-05-04-reorder-types-current-main-recheck.md
  - ../../binaryen/passes/reorder-types/index.md
---

# Binaryen `reorder-types` current-main recheck

This is the 2026-05-04 current-`main` source ingest for Binaryen `reorder-types`.
It supplements the immutable tagged manifest in [`2026-04-24-reorder-types-primary-sources.md`](./2026-04-24-reorder-types-primary-sources.md) and the earlier source-confirmation follow-up in [`2026-04-21-reorder-types-source-confirmation-followup.md`](../research/0199-2026-04-21-reorder-types-source-confirmation-followup.md).

## Checked primary sources

- `src/passes/ReorderTypes.cpp`
- `src/passes/pass.cpp`
- `src/ir/type-updating.cpp`
- `src/ir/type-updating.h`
- `src/ir/module-utils.cpp`
- `src/ir/module-utils.h`
- `test/lit/passes/reorder-types.wast`

## Recheck result

The current-main spot check did not find teaching-relevant contract drift.
The durable story remains:

- `ReorderTypes.cpp` still centers the private-type reordering / encoded-cost search engine;
- `pass.cpp` still registers public `reorder-types` plus the hidden testing sibling;
- `GlobalTypeRewriter` still owns the private/public split, predecessor graph, and full-module remap;
- the dedicated lit file still proves profitability, legality, and regression boundaries;
- the pass still requires GC and `--closed-world`.

## Teaching note

The useful wiki delta is freshness:

- the 2026-05-04 recheck keeps the same contract visible,
- but it does not change the living dossier model.

## Caveat

This was a focused owner/helper/lit-family spot check, not a whole-repository audit.
Treat it as the current-main freshness layer above the 2026-04-24 tagged manifest.
