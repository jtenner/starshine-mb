---
kind: source-capture
status: supported
last_reviewed: 2026-05-05
sources:
  - https://github.com/WebAssembly/binaryen/blob/main/src/passes/Unsubtyping.cpp
  - https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp
  - https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/unsubtyping.wast
  - https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/unsubtyping-casts.wast
  - https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/unsubtyping-cmpxchg.wast
  - https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/unsubtyping-desc.wast
  - https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/unsubtyping-desc-tnh.wast
  - https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/unsubtyping-jsinterop.wast
  - https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/unsubtyping-stack-switching.wast
related:
  - ../research/0444-2026-05-05-unsubtyping-current-main-recheck.md
  - ../../binaryen/passes/unsubtyping/index.md
---

# Binaryen `unsubtyping` current-main recheck

Captured: 2026-05-05

## Source set

- `src/passes/Unsubtyping.cpp`
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/Unsubtyping.cpp>
  - Reviewed surfaces: hard GC / closed-world gates, required subtype and descriptor seeding, fixed-point edge closure, descriptor-bearing allocation fixups, private-type rewrite, and refinalization.
- `src/passes/pass.cpp`
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
  - Reviewed surfaces: public `unsubtyping` registration and the closed-world GC/type-cluster placement.
- `test/lit/passes/unsubtyping.wast`
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/unsubtyping.wast>
  - Reviewed surfaces: the broad validation-surface baseline remains the same.
- `test/lit/passes/unsubtyping-casts.wast`
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/unsubtyping-casts.wast>
  - Reviewed surfaces: ordinary-vs-exact cast preservation and fixed-point cast chains remain the same.
- `test/lit/passes/unsubtyping-cmpxchg.wast`
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/unsubtyping-cmpxchg.wast>
  - Reviewed surfaces: ref cmpxchg typing boundaries remain part of the contract.
- `test/lit/passes/unsubtyping-desc.wast`
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/unsubtyping-desc.wast>
  - Reviewed surfaces: descriptor squares, `ref.get_desc`, descriptor-aware casts, and trap-preserving descriptor allocations remain part of the contract.
- `test/lit/passes/unsubtyping-desc-tnh.wast`
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/unsubtyping-desc-tnh.wast>
  - Reviewed surfaces: `trapsNeverHappen` still narrows the descriptor-fixup story.
- `test/lit/passes/unsubtyping-jsinterop.wast`
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/unsubtyping-jsinterop.wast>
  - Reviewed surfaces: JS boundary flow through `any`, prototype keepalive, and `extern.convert_any` remain the same.
- `test/lit/passes/unsubtyping-stack-switching.wast`
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/unsubtyping-stack-switching.wast>
  - Reviewed surfaces: continuation and stack-switching constraints remain the same.

## Recheck result

- The upstream contract still matches the living wiki frame on the reviewed surfaces: closed-world GC gate, minimal subtype-plus-descriptor fixed point, descriptor square completion, cast preservation, JS-boundary keepalive, allocation fixups, and refinalization.
- The current-main implementation shape still agrees with the existing `version_129` teaching frame for the reviewed surfaces.
- No teaching-relevant drift was found in the owner / registration / lit-file surfaces that were rechecked.
