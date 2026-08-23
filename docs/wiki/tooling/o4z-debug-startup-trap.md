---
kind: concept
status: supported
last_reviewed: 2026-08-23
sources:
  - ../binaryen/passes/late-pipeline-dispatch.md
  - ../../../scripts/lib/build-self-optimized.mjs
  - ../../../scripts/lib/self-optimized-artifacts.mjs
  - ../../../scripts/lib/o4z-debug-startup-map.test.ts
  - ../../../tests/repros/o4z-debug-startup-map-init-repro.wasm
  - ./cli-startup-path.md
related:
  - ./wasi-runner-and-preview-boundary.md
  - ./cli-command-and-dispatcher.md
  - ./cli-startup-path.md
  - ./validation-gates.md
  - ../validate/runtime-trap-semantics.md
  - ../binaryen/no-dwarf-default-optimize-path.md
---

# O4z Debug Startup Trap

## Overview

This page records `o4z` startup-trap investigations and the permanent guards that keep debug and self-optimized WASI artifacts honest. The fast-path and path-normalization work still belong in [`cli-startup-path.md`](./cli-startup-path.md); this page covers optimizer-induced startup corruption and the separate stale-debug-artifact regression sentinel.

The historical host-visible symptom was `RuntimeError: unreachable`; the August 23, 2026 current-source self-optimization regression trapped as `RuntimeError: memory access out of bounds`. Those messages are trap-classification hints, not proof of structural invalidity: the failing self-optimized artifact passed `wasm-tools validate --features all`. The replay host is the Node-hosted WASI Preview 1 runner documented in [`wasi-runner-and-preview-boundary.md`](wasi-runner-and-preview-boundary.md). The debug-artifact regression is repaired; current-source self-optimization remains under active repair.

## Current understanding

- The stale committed debug-WASI artifact path is repaired. The reduced `malloc` shape now carries the TLSF root/control pointer into `tlsf/removeBlock` instead of leaving a literal zero on the stack.
- One current-source owner is repaired: raw SimplifyLocals effectful-suffix sinking moved a stack-carried producer containing `local.set` or `local.tee` writes behind instructions that read those locals. The rewrite now tracks producer-written locals and treats conflicting reads and writes as movement barriers.
- The next independent failure remains open at the O4z `dae-optimizing` slot. Plain `dae` happened not to reproduce the artifact-scale crash, but module-size-based pass substitution is not a semantic fix and is intentionally not retained.
- Smaller final-precompute, global-refining, and scalar-cleanup portfolio candidates also reproduced runtime failure during isolation. Those pass owners must be reduced and repaired individually; the portfolio is not disabled by an artifact-size threshold.
- `scripts/lib/build-self-optimized.mjs` describes the build/copy flow that produces the debug artifact used by later self-optimize runs.
- `scripts/lib/self-optimized-artifacts.mjs` names the debug artifact path that the build pipeline copies into the node-dist layout.
- The runtime-trap semantics remain source-backed in [`../validate/runtime-trap-semantics.md`](../validate/runtime-trap-semantics.md); use that guide to remember that `RuntimeError: unreachable` is a wasm trap surface, not a Node-specific exception class.
- The detailed owner evidence and the repaired pass-owner follow-up live in the archived research note [research note 0693](../binaryen/passes/late-pipeline-dispatch.md).
- The Node-hosted WASI runner boundary lives in [`wasi-runner-and-preview-boundary.md`](wasi-runner-and-preview-boundary.md); this page uses that runner as replay evidence but does not make WASI 0.2/0.3, Component Model, JSPI, or sandboxing claims.

## Current-source self-opt evidence

- Exact main-pipeline runtime bisection placed the first failure at prefix 24, where `simplify-locals` followed a runtime-safe prefix ending in `local-cse`.
- Function-body hybridization reduced that failure to defined function 8037 and exposed a `local.get` moved before its corresponding producer write.
- The focused regression is `raw simplify-locals keeps stack-carried producer writes before destination reads`.
- After that repair, the next runtime failure appears when the main pipeline adds `dae-optimizing`; structural validation remains green, so runtime and native-equivalence evidence remain mandatory.
- Generated replay and bisection artifacts remain under `.tmp/self-opt-current-prefix-bisect/` and `.tmp/isolate-self-opt-address-dae.py`.

## Current TDD guard

- [`../../../scripts/lib/o4z-debug-startup-map.test.ts`](../../../scripts/lib/o4z-debug-startup-map.test.ts) is the permanent reduced-fixture guard.
- [`../../../tests/repros/o4z-debug-startup-map-init-repro.wasm`](../../../tests/repros/o4z-debug-startup-map-init-repro.wasm) is the current reproduction.
- The first assertion prints the WAT and rejects the stale allocator-root shape if `malloc` ever reintroduces `i32.const 0` immediately before `global.get 0` at the `removeBlock` call site.
- The second assertion replays the fixture through `runWasmStart(..., args: ["--help"])` and expects a zero exit code.

## How to use this page

1. Keep this investigation separate from the path-handling audit in [`cli-startup-path.md`](./cli-startup-path.md).
2. Check the debug-artifact generation path before changing optimizer passes if this guard ever regresses.
3. Use the raw research note for the exact reduced-fixture guard, scratch instrumentation, and historical owner hypothesis.
4. If the guard fails again, repair the artifact/fixture path first, then retry the full self/debug `-O4z` startup path and spec smoke.
5. If the host message still says `RuntimeError: unreachable`, classify it as a wasm trap first and use the trap site plus surrounding execution path to distinguish artifact corruption from a live optimizer regression.

## Sources

- Archived research note: [research note 0693](../binaryen/passes/late-pipeline-dispatch.md)
- Runtime-trap semantics guide: [`../validate/runtime-trap-semantics.md`](../validate/runtime-trap-semantics.md)
- Build pipeline: [`../../../scripts/lib/build-self-optimized.mjs`](../../../scripts/lib/build-self-optimized.mjs)
- Artifact-path helper: [`../../../scripts/lib/self-optimized-artifacts.mjs`](../../../scripts/lib/self-optimized-artifacts.mjs)
- Active reduced guard: [`../../../scripts/lib/o4z-debug-startup-map.test.ts`](../../../scripts/lib/o4z-debug-startup-map.test.ts)
- Reduced repro: [`../../../tests/repros/o4z-debug-startup-map-init-repro.wasm`](../../../tests/repros/o4z-debug-startup-map-init-repro.wasm)
- WASI runner / Preview boundary: [`wasi-runner-and-preview-boundary.md`](wasi-runner-and-preview-boundary.md), [Node `node:wasi` documentation](https://nodejs.org/api/wasi.html)
- Related audit: [`./cli-startup-path.md`](./cli-startup-path.md)
