---
kind: concept
status: working
last_reviewed: 2026-06-02
sources:
  - ../raw/research/0693-2026-06-01-o4z-debug-startup-func3750.md
  - ../raw/wasm/2026-06-02-runtimeerror-unreachable-trap-sources.md
  - ../../../scripts/lib/build-self-optimized.mjs
  - ../../../scripts/lib/self-optimized-artifacts.mjs
  - ./cli-startup-path.md
related:
  - ./cli-command-and-dispatcher.md
  - ./cli-startup-path.md
  - ./validation-gates.md
  - ../binaryen/no-dwarf-default-optimize-path.md
---

# O4z Debug Startup Trap

## Overview

This page tracks the runtime blocker that remains after the CLI startup-path audit is done. The fast-path and path-normalization work belong in [`cli-startup-path.md`](./cli-startup-path.md); this page is only about the separate `o4z` debug-startup trap that appears once the self-debug artifact is runnable.

The current symptom is a WebAssembly runtime trap surfaced as `RuntimeError: unreachable` during startup. The active research note records the exact call chain, the bucket-array and map-header evidence, and the reduced fixture used to isolate the failure. The host-facing error shape is expected: WebAssembly uses `RuntimeError` for traps, and `unreachable` is the unconditional trap instruction.

## Current understanding

- The blocker is not a parser or globbing issue.
- The best current evidence points at the committed debug-WASI artifact generation path, not at the live pass sequence itself.
- `scripts/lib/build-self-optimized.mjs` describes the end-to-end build/copy flow that produces the debug artifact used by later self-optimize runs.
- `scripts/lib/self-optimized-artifacts.mjs` names the debug artifact path that the build pipeline copies into the node-dist layout.
- The runtime-trap semantics are now source-backed in [`../raw/wasm/2026-06-02-runtimeerror-unreachable-trap-sources.md`](../raw/wasm/2026-06-02-runtimeerror-unreachable-trap-sources.md), so the message text should be treated as a trap wrapper rather than a special local exception class.
- The detailed owner evidence, reduced reproduction, and temporary instrumentation notes live in the archived research note [`../raw/research/0693-2026-06-01-o4z-debug-startup-func3750.md`](../raw/research/0693-2026-06-01-o4z-debug-startup-func3750.md).

## How to use this page

1. Keep this investigation separate from the path-handling audit in [`cli-startup-path.md`](./cli-startup-path.md).
2. Check the debug-artifact generation path before changing optimizer passes.
3. Use the raw research note for the exact reduced-fixture guard, scratch instrumentation, and owner hypothesis.
4. After the reduced guard is green, retry the full self/debug `-O4z` startup path.
5. If the host message still says `RuntimeError: unreachable`, classify it as a wasm trap first and use the trap site plus surrounding execution path to distinguish artifact corruption from a live optimizer regression.

## Sources

- Archived research note: [`../raw/research/0693-2026-06-01-o4z-debug-startup-func3750.md`](../raw/research/0693-2026-06-01-o4z-debug-startup-func3750.md)
- Runtime-trap semantics source note: [`../raw/wasm/2026-06-02-runtimeerror-unreachable-trap-sources.md`](../raw/wasm/2026-06-02-runtimeerror-unreachable-trap-sources.md)
- Build pipeline: [`../../../scripts/lib/build-self-optimized.mjs`](../../../scripts/lib/build-self-optimized.mjs)
- Artifact-path helper: [`../../../scripts/lib/self-optimized-artifacts.mjs`](../../../scripts/lib/self-optimized-artifacts.mjs)
- Related audit: [`./cli-startup-path.md`](./cli-startup-path.md)
