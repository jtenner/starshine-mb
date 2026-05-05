---
kind: raw-source
status: supported
last_reviewed: 2026-05-05
sources:
  - https://github.com/WebAssembly/binaryen/blob/main/src/passes/DeadArgumentElimination.cpp
  - https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp#L2394-L2402
  - https://github.com/WebAssembly/binaryen/blob/main/src/passes/opt-utils.h#L536-L565
  - https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/dae-optimizing.wast
  - https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/dae-refine-params-and-optimize.wast
  - https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/dae-gc.wast
  - https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/dae-gc-refine-params.wast
  - https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/dae-gc-refine-return.wast
  - https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/dae_tnh.wast
related:
  - ../research/0487-2026-05-05-dae-optimizing-current-main-recheck.md
  - ../../binaryen/passes/dae-optimizing/index.md
---

# Binaryen `dae-optimizing` current-main recheck

This is the 2026-05-05 current-`main` source ingest for upstream `dae-optimizing` / the optimizing DAE sibling.
It supplements the immutable tagged manifest in [`2026-04-24-dae-optimizing-primary-sources.md`](./2026-04-24-dae-optimizing-primary-sources.md) and the earlier 2026-04-25 implementation/test-map bridge in [`2026-04-25-dae-optimizing-current-main-and-test-map.md`](./2026-04-25-dae-optimizing-current-main-and-test-map.md).

## Checked primary sources

- `src/passes/DeadArgumentElimination.cpp`
- `src/passes/pass.cpp`
- `src/passes/opt-utils.h`
- `test/lit/passes/dae-optimizing.wast`
- `test/lit/passes/dae-refine-params-and-optimize.wast`
- `test/lit/passes/dae-gc.wast`
- `test/lit/passes/dae-gc-refine-params.wast`
- `test/lit/passes/dae-gc-refine-return.wast`
- `test/lit/passes/dae_tnh.wast`

## Recheck result

This current-main spot check did not find teaching-relevant contract drift.
The durable story remains:

- `DeadArgumentElimination.cpp` still owns the shared direct-call boundary engine for both public DAE siblings;
- `pass.cpp` still keeps the public `dae` / `dae-optimizing` split explicit;
- `opt-utils.h` still owns the optimizing-only nested cleanup replay;
- the distributed lit surface still splits into the optimizing-specific file plus shared GC / result / TNH families;
- the local Starshine naming caveat remains unchanged: the current registry spelling is `dead-argument-elimination-optimizing`, not the exact upstream `dae-optimizing` alias.

## Teaching note

The useful wiki delta is just freshness:

- the 2026-05-05 recheck keeps the same plain-vs-optimizing split visible,
- but it does not change the pass model taught in the living dossier.

## Caveat

This was a focused owner/helper/lit-family spot check, not a whole-repository audit.
Treat it as the current-main freshness layer above the 2026-04-24 tagged manifest.
