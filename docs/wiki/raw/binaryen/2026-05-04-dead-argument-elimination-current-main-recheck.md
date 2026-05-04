---
kind: raw-source
status: supported
last_reviewed: 2026-05-04
sources:
  - https://github.com/WebAssembly/binaryen/blob/main/src/passes/DeadArgumentElimination.cpp
  - https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp
  - https://github.com/WebAssembly/binaryen/blob/main/src/passes/param-utils.h
  - https://github.com/WebAssembly/binaryen/blob/main/src/passes/param-utils.cpp
  - https://github.com/WebAssembly/binaryen/blob/main/src/ir/lubs.h
  - https://github.com/WebAssembly/binaryen/blob/main/src/ir/return-utils.h
  - https://github.com/WebAssembly/binaryen/blob/main/src/ir/type-updating.h
  - https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/dae_tnh.wast
  - https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/dae-gc.wast
  - https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/dae-gc-refine-params.wast
  - https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/dae-gc-refine-return.wast
  - https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/dae-optimizing.wast
  - https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/dae-refine-params-and-optimize.wast
  - https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/dae2.wast
related:
  - ../research/0435-2026-05-04-dead-argument-elimination-current-main-recheck.md
  - ../../binaryen/passes/dead-argument-elimination/index.md
---

# Binaryen `dead-argument-elimination` current-main recheck

This is the 2026-05-04 current-`main` source ingest for plain `dead-argument-elimination` / upstream `dae`.
It supplements the immutable tagged manifest in [`2026-04-24-dead-argument-elimination-primary-sources.md`](./2026-04-24-dead-argument-elimination-primary-sources.md) and the earlier 2026-04-26 readiness check in [`2026-04-26-dead-argument-elimination-port-readiness-primary-sources.md`](./2026-04-26-dead-argument-elimination-port-readiness-primary-sources.md).

## Checked primary sources

- `src/passes/DeadArgumentElimination.cpp`
- `src/passes/pass.cpp`
- `src/passes/param-utils.h`
- `src/passes/param-utils.cpp`
- `src/ir/lubs.h`
- `src/ir/return-utils.h`
- `src/ir/type-updating.h`
- `test/lit/passes/dae_tnh.wast`
- `test/lit/passes/dae-gc.wast`
- `test/lit/passes/dae-gc-refine-params.wast`
- `test/lit/passes/dae-gc-refine-return.wast`
- `test/lit/passes/dae-optimizing.wast`
- `test/lit/passes/dae-refine-params-and-optimize.wast`
- `test/lit/passes/dae2.wast`

## Recheck result

This current-main spot check did not find teaching-relevant contract drift.
The durable story remains:

- plain `dae` still shares `DeadArgumentElimination.cpp` with `dae-optimizing`;
- `pass.cpp` still keeps the public registration split explicit;
- `opt-utils.h` still belongs only to the optimizing sibling's nested cleanup replay;
- the plain-pass proof family still centers on `dae_tnh`, `dae-gc`, `dae-gc-refine-params`, and `dae-gc-refine-return`;
- `dae2.wast` still belongs to the separate experimental sibling, not plain DAE.

## Teaching note

The useful wiki delta is just freshness:

- the 2026-05-04 recheck keeps the same plain-vs-optimizing split visible,
- but it does not change the pass model taught in the living dossier.

## Caveat

This was a focused owner/helper/lit-family spot check, not a whole-repository audit.
Treat it as the current-main freshness layer above the 2026-04-24 tagged manifest.
