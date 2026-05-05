---
kind: raw-source
status: supported
last_reviewed: 2026-05-05
sources:
  - https://github.com/WebAssembly/binaryen/blob/main/src/passes/DeadArgumentElimination2.cpp
  - https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp
  - https://github.com/WebAssembly/binaryen/blob/main/src/passes/passes.h
  - https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/dae2.wast
related:
  - ../research/0452-2026-05-05-dae2-current-main-recheck.md
  - ../../binaryen/passes/dae2/index.md
---

# Binaryen `dae2` current-main recheck

This is the 2026-05-05 current-`main` source ingest for Binaryen's experimental `dae2` pass.
It supplements the immutable tagged manifest in [`2026-04-25-dae2-primary-sources.md`](./2026-04-25-dae2-primary-sources.md) and the 2026-04-26 port-readiness manifest in [`2026-04-26-dae2-port-readiness-primary-sources.md`](./2026-04-26-dae2-port-readiness-primary-sources.md).

## Checked primary sources

- `src/passes/DeadArgumentElimination2.cpp`
- `src/passes/pass.cpp`
- `src/passes/passes.h`
- `test/lit/passes/dae2.wast`

## Recheck result

This current-main spot check did not find teaching-relevant contract drift.
The durable story remains:

- `dae2` is still a separate public Binaryen pass, not a spellable variant of plain `dae` or `dae-optimizing`;
- the pass still centers backward used/forwarded-parameter fixed-point analysis;
- the closed-world + GC referenced-function rewrite gate still exists as a separate mode;
- the official `dae2.wast` oracle still teaches the same direct/indirect/reference-call families and conservative bailout surfaces.

## Teaching note

The useful wiki delta is freshness:

- the 2026-05-05 recheck keeps the same experimental DAE model visible,
- but it does not change the living dossier's teaching contract.

## 2026-05-05 official GitHub web spotcheck

A short source-line spotcheck on the official Binaryen GitHub `main` branch confirmed the same public `dae2` surface:

- `src/passes/DeadArgumentElimination2.cpp` still starts with the same scope / non-goal comment that frames `dae2` as a backward fixed-point DAE reimplementation and keeps result / constant / type propagation out of scope.
- `src/passes/pass.cpp` still registers `dae2` beside `dae` and `dae-optimizing` as a public pass.
- `test/lit/passes/dae2.wast` still runs `wasm-opt -all --dae2 --closed-world -S` and still covers the same direct, indirect, reference, boundary, and replacement-type families.

Official URLs checked:

- <https://github.com/WebAssembly/binaryen/blob/main/src/passes/DeadArgumentElimination2.cpp>
- <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
- <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/dae2.wast>

## Caveat

This was a focused owner/registration/test-file spot check, not a whole-repository audit.
Treat it as the current-main freshness layer above the 2026-04-25 tagged manifest and the 2026-04-26 port-readiness bridge.
