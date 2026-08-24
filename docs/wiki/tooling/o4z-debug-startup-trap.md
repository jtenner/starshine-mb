---
kind: concept
status: supported
last_reviewed: 2026-08-24
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
- The apparent `dae-optimizing` failure was reduced to its typed-loop-safe nested `coalesce-locals` stage. The DAE boundary batch and nested SimplifyLocals output both remained runtime-safe; function-body hybridization isolated the first bad coalesced body to absolute function 8017.
- Dense-tee interval marking incorrectly treated a block as never falling through when its textual tail returned, even though an earlier nested branch targeted that block's continuation. The marker stopped scanning, classified continuation locals as unused, and merged simultaneously live values into one slot. Structured escape classification now checks for branches to the instruction's own continuation before declaring its tail terminal.
- The unmodified 69-pass main O4z sequence is runtime-safe. The apparent final-`precompute` failure was reduced to function 7851: deleting a valid dead constant forced Hot-IR lowering, which emitted a later void call before an earlier stack-carried call result consumed by control. Lowering now schedules only effectful value producers that predate and cross a void call-like root, preserving call order without changing Hot-IR root structure.
- The subsequent final-candidate canonicalization trap was isolated across 4,548 changed bodies to allocator function 29. Nested dead-tee cleanup inspected only an `if` arm suffix and removed local writes read after the `if`. Dead-tee recursion now carries enclosing continuations through blocks, loops, if arms, and try tables; the rebuilt artifact passes startup/help.
- The scalar-selected follow-up first exposed another main-pipeline ordering defect at prefix 17, `simplify-locals-nostructure`. Hybridization across 702 changed bodies isolated function 8102: root traversal visited a later void release call before an earlier stack-carried multivalue call dependency, so a pending initialization was sunk to the later read. SimplifyLocals now pre-scans earlier effectful call dependencies of future roots before intervening void calls.
- `scripts/lib/build-self-optimized.mjs` describes the build/copy flow that produces the debug artifact used by later self-optimize runs.
- `scripts/lib/self-optimized-artifacts.mjs` names the debug artifact path that the build pipeline copies into the node-dist layout.
- The runtime-trap semantics remain source-backed in [`../validate/runtime-trap-semantics.md`](../validate/runtime-trap-semantics.md); use that guide to remember that `RuntimeError: unreachable` is a wasm trap surface, not a Node-specific exception class.
- The detailed owner evidence and the repaired pass-owner follow-up live in the archived research note [research note 0693](../binaryen/passes/late-pipeline-dispatch.md).
- The Node-hosted WASI runner boundary lives in [`wasi-runner-and-preview-boundary.md`](wasi-runner-and-preview-boundary.md); this page uses that runner as replay evidence but does not make WASI 0.2/0.3, Component Model, JSPI, or sandboxing claims.

## Current-source self-opt evidence

- Exact main-pipeline runtime bisection placed the first failure at prefix 24, where `simplify-locals` followed a runtime-safe prefix ending in `local-cse`.
- Function-body hybridization reduced that failure to defined function 8037 and exposed a `local.get` moved before its corresponding producer write.
- The focused regression is `raw simplify-locals keeps stack-carried producer writes before destination reads`.
- The next apparent failure at `dae-optimizing` was narrowed through stage dumps: boundary batch runtime `0`, nested SimplifyLocals runtime `0`, nested coalescing runtime `1`. Hybridization across 345 changed coalesced functions isolated absolute function 8017.
- The focused coalescer regression is `coalesce-locals dense-tee intervals keep branch-reachable continuation locals distinct`; the repaired artifact-scale DAE replay passes `tests/spec/address.wast`.
- The current explicit 69-pass main artifact validates and passes runtime replay. Function-body hybridization across 676 precompute-changed functions isolated function 7851; the direct Hot lift/lower and pass-level precompute regressions preserve the producer call before the intervening effect.
- With that fix, exact main plus `precompute` and `vacuum` passes runtime. Canonicalized-body hybridization then isolated function 29; the focused regression is `O4z final canonicalizer preserves nested tees read by the continuation`.
- The rebuilt scalar-selected investigation then placed the next main-pipeline boundary at prefix 35, `precompute-propagate`; function 8102 itself is covered by `simplify-locals-nostructure keeps initialization before stack-carried call read` and prefix 17 now passes runtime.
- Generated replay and bisection artifacts remain under `.tmp/self-opt-current-prefix-bisect/`, `.tmp/self-opt-address-prefix-bisect/`, `.tmp/self-opt-main-after-coalesce/`, `.tmp/isolate-final-precompute.py`, and `.tmp/isolate-final-canonical.py`.

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
