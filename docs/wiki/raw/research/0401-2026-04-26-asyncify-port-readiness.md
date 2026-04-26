---
kind: research
status: supported
last_reviewed: 2026-04-26
sources:
  - ../binaryen/2026-04-26-asyncify-port-readiness-primary-sources.md
  - ../binaryen/2026-04-25-asyncify-current-main-and-eh-options.md
  - ../binaryen/2026-04-24-asyncify-primary-sources.md
  - ../../binaryen/passes/asyncify/index.md
  - ../../binaryen/passes/asyncify/starshine-strategy.md
  - ../../../../src/passes/optimize.mbt
  - ../../../../src/lib/types.mbt
  - ../../../../src/validate/typecheck.mbt
  - ../../../../src/binary/encode.mbt
related:
  - ../../binaryen/passes/asyncify/starshine-port-readiness-and-validation.md
---

# `asyncify` port-readiness bridge

## Question

The existing `asyncify` dossier had a sourced overview, Binaryen strategy, transformed-shape catalog, implementation/test map, and Starshine status page.
What it still lacked was the standard bridge from those facts to a safe first Starshine implementation slice and validation ladder.

## Finding

`asyncify` should remain documented as **upstream-only / unknown-pass in Starshine today**, but the next useful local work is now clearer:

1. keep registry honesty first;
2. add an explicit decision about whether `asyncify` should become boundary-only, removed, or active;
3. if active, start with a tiny module pass that rejects unsupported options and unsupported EH/tail-call families deliberately;
4. implement a direct imported-root scalar-local slice before indirect calls, memory64, EH/catch, and host round-trip integration;
5. validate static module shape before attempting dynamic unwind/rewind parity.

## Source review

The 2026-04-26 primary-source recheck reviewed official current-main Binaryen `Asyncify.cpp`, `pass.cpp`, and `asyncify.wast`, plus Emscripten's Asyncify docs.
It found no teaching-level drift from the 2026-04-25 dossier.
The current source still supports the same core contract:

- whole-module pause/resume instrumentation;
- runtime state/data globals and API exports;
- import and callgraph analysis;
- direct and indirect call instrumentation;
- live-local save/restore through Asyncify memory;
- memory32 versus memory64 pointer-width selection;
- option-sensitive catch/EH behavior;
- tail-call unsupport in the reviewed path.

## Starshine code surfaces checked

- `src/passes/optimize.mbt:128-154` still has no `asyncify` entry in boundary-only or removed registries.
- `src/passes/optimize.mbt:158-252` still has no active hot/module/preset entry.
- `src/passes/optimize.mbt:455-459` remains the generic unknown-pass path for unregistered explicit pass requests.
- `src/lib/types.mbt:351-398` owns module sections; `src/lib/types.mbt:224`, `227`, `433`, `442`, `460`, and `493` provide the global/export/function/code section surfaces a port would mutate.
- `src/lib/types.mbt:527-530` includes direct, indirect, and tail-call instruction constructors relevant to call instrumentation and rejection.
- `src/validate/typecheck.mbt:3216-3223` checks indirect and return-call forms; validation must remain a first-class port gate.
- `src/binary/encode.mbt:2002-2028` encodes direct, indirect, and return-call forms; `src/binary/encode.mbt:2088` and `2250` cover global set and memory grow surfaces adjacent to Asyncify helper code.
- `src/wast/keywords.mbt:87-90`, `137`, and `174` keep WAT fixtures possible for indirect/tail calls, `global.set`, and `memory.grow`.

## Recommended first slices

1. **Registry/status slice:** add or intentionally keep absent `asyncify` with tests for user-facing request behavior.
2. **Rejecting analyzer slice:** parse a tiny module, identify async import roots, and reject tail calls/EH/options with clear diagnostics while producing no rewrite.
3. **Direct-call scalar slice:** synthesize helper globals/exports and instrument one direct call to one async import with no live locals.
4. **Scalar local-save slice:** save and restore one `i32` local live across that direct call.
5. **Callgraph fanout slice:** propagate instrumentation through direct callers and preserve functions outside the async closure.
6. **Indirect-call slice:** add conservative indirect-call instrumentation and one ignored-indirect negative if the option model exposes it.
7. **Memory64 slice:** choose `i64` pointer traffic for memory64 input.
8. **EH/catch slice:** either match Binaryen's catch-unwind behavior or retain deliberate rejection with tests.
9. **Dynamic harness slice:** prove one real unwind/rewind round trip, because normalized WAT equality is insufficient for Asyncify correctness.

## Health-check outcome

The touched area needed a dedicated port-readiness page rather than more strategy prose.
No stale Binaryen strategy claim was found in the existing pages during this focused check; the main hygiene fix is to cross-link the new validation bridge from the overview, Starshine status, pass catalog, tracker, and global wiki index.

## Unresolved decisions

- Whether `asyncify` should become a `BoundaryOnly` registry entry before implementation starts.
- Whether the first local implementation should reject all EH/catch input or support the source-backed catch-unwind option from the beginning.
- How to host-test unwind/rewind without making the pass compare lane depend only on static WAT text.
