---
kind: concept
status: supported
last_reviewed: 2026-06-02
sources:
  - ../raw/node/2026-06-05-wasi-runner-preview-boundary-refresh.md
  - ../raw/research/0693-2026-06-01-o4z-debug-startup-func3750.md
  - ../raw/wasm/2026-06-04-runtime-trap-current-refresh.md
  - ../raw/wasm/2026-06-02-runtimeerror-unreachable-trap-sources.md
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

This page records the repaired `o4z` debug-startup trap and the permanent guard that keeps the committed debug-WASI artifact honest. The fast-path and path-normalization work still belong in [`cli-startup-path.md`](./cli-startup-path.md); this page is only about the separate startup trap that used to come from a stale debug artifact and now serves as a regression sentinel.

The host-visible symptom was `RuntimeError: unreachable` during startup. That message is still useful as a trap-classification hint; the reusable trap vocabulary now lives in [`../validate/runtime-trap-semantics.md`](../validate/runtime-trap-semantics.md). The replay host is the Node-hosted WASI Preview 1 runner documented in [`wasi-runner-and-preview-boundary.md`](wasi-runner-and-preview-boundary.md); use that page for `_start`/reactor and import-module boundaries. The important current fact is that the stale allocator-root shape has been repaired: the committed debug-WASI path and the reduced fixture now pass the reduced guard and the startup replay.

## Current understanding

- The stale committed debug-WASI artifact path is repaired. The reduced `malloc` shape now carries the TLSF root/control pointer into `tlsf/removeBlock` instead of leaving a literal zero on the stack.
- `scripts/lib/build-self-optimized.mjs` describes the build/copy flow that produces the debug artifact used by later self-optimize runs.
- `scripts/lib/self-optimized-artifacts.mjs` names the debug artifact path that the build pipeline copies into the node-dist layout.
- The runtime-trap semantics remain source-backed in [`../validate/runtime-trap-semantics.md`](../validate/runtime-trap-semantics.md) and [`../raw/wasm/2026-06-04-runtime-trap-current-refresh.md`](../raw/wasm/2026-06-04-runtime-trap-current-refresh.md); use that guide to remember that `RuntimeError: unreachable` is a wasm trap surface, not a Node-specific exception class.
- The detailed owner evidence and the repaired pass-owner follow-up live in the archived research note [`../raw/research/0693-2026-06-01-o4z-debug-startup-func3750.md`](../raw/research/0693-2026-06-01-o4z-debug-startup-func3750.md).
- The Node-hosted WASI runner boundary lives in [`wasi-runner-and-preview-boundary.md`](wasi-runner-and-preview-boundary.md); this page uses that runner as replay evidence but does not make WASI Preview 2, Component Model, JSPI, or sandboxing claims.

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

- Archived research note: [`../raw/research/0693-2026-06-01-o4z-debug-startup-func3750.md`](../raw/research/0693-2026-06-01-o4z-debug-startup-func3750.md)
- Runtime-trap semantics guide: [`../validate/runtime-trap-semantics.md`](../validate/runtime-trap-semantics.md)
- Runtime-trap source refresh: [`../raw/wasm/2026-06-04-runtime-trap-current-refresh.md`](../raw/wasm/2026-06-04-runtime-trap-current-refresh.md)
- Earlier focused source note: [`../raw/wasm/2026-06-02-runtimeerror-unreachable-trap-sources.md`](../raw/wasm/2026-06-02-runtimeerror-unreachable-trap-sources.md)
- Build pipeline: [`../../../scripts/lib/build-self-optimized.mjs`](../../../scripts/lib/build-self-optimized.mjs)
- Artifact-path helper: [`../../../scripts/lib/self-optimized-artifacts.mjs`](../../../scripts/lib/self-optimized-artifacts.mjs)
- Active reduced guard: [`../../../scripts/lib/o4z-debug-startup-map.test.ts`](../../../scripts/lib/o4z-debug-startup-map.test.ts)
- Reduced repro: [`../../../tests/repros/o4z-debug-startup-map-init-repro.wasm`](../../../tests/repros/o4z-debug-startup-map-init-repro.wasm)
- WASI runner / Preview boundary: [`wasi-runner-and-preview-boundary.md`](wasi-runner-and-preview-boundary.md), [`../raw/node/2026-06-05-wasi-runner-preview-boundary-refresh.md`](../raw/node/2026-06-05-wasi-runner-preview-boundary-refresh.md)
- Related audit: [`./cli-startup-path.md`](./cli-startup-path.md)
