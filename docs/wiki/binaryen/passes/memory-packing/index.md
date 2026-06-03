---
kind: entity
status: supported
last_reviewed: 2026-06-03
sources:
  - ../../../raw/research/0700-2026-06-03-memory-packing-o4z-audit.md
  - ../../../raw/binaryen/2026-04-22-memory-packing-primary-sources.md
  - ../../../raw/research/0137-2026-04-20-memory-packing-binaryen-research.md
  - ../../../raw/research/0204-2026-04-21-memory-packing-source-confirmation-followup.md
  - ../../../raw/research/0252-2026-04-22-memory-packing-primary-sources-and-code-map-followup.md
  - ../../../../../src/passes/memory_packing.mbt
  - ../../../../../src/passes/memory_packing_test.mbt
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/registry_test.mbt
  - ../../../../../agent-todo.md
  - ../../../../../.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/summary.md
  - ../../../../../.artifacts/o4z-wasm-opt-debug.log
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/MemoryPacking.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/memory-packing_all-features.wast
  - https://github.com/WebAssembly/binaryen/blob/main/src/passes/MemoryPacking.cpp
related:
  - ./binaryen-strategy.md
  - ./segment-op-rewrites-and-traps.md
  - ./wat-shapes.md
  - ./starshine-hot-ir-strategy.md
  - ./parity.md
  - ../../../binary/data-element-and-datacount-sections.md
  - ../tracker.md
  - ../../no-dwarf-default-optimize-path.md
  - ../remove-unused-module-elements/index.md
  - ../once-reduction/index.md
---

# `memory-packing`

## Role

- `memory-packing` is an active implemented **module pass** in Starshine.
- In upstream Binaryen `version_129`, the public `pass.cpp` description is only:
  - `packs memory into separate segments, skipping zeros`

That description is true, but too small.

A better beginner summary is:

- Binaryen first proves the module's memory/data layout is safe to optimize,
- then splits zero-heavy data segments into profitable zero and nonzero ranges,
- drops zero runs from active segments when memory's zero-initialized startup state already provides them,
- rewrites passive `memory.init` / `data.drop` users into `memory.init` plus `memory.fill` sequences when needed,
- preserves startup and dropped-segment trap behavior with top-byte retention or lazily-created drop-state globals,
- and stays conservative around overlapping active segments, imported memory, GC data-segment users, memory64 corner cases, and segment-count limits.

So this is **not** just an active-data peephole pass.
It is a whole-module segment-layout plus segment-op rewrite pass. For the underlying Starshine `DataMode`, data-count, and segment-header contract that this pass mutates, see [`../../../binary/data-element-and-datacount-sections.md`](../../../binary/data-element-and-datacount-sections.md).

## Why this pass matters

- When this thread started, `docs/wiki/binaryen/passes/tracker.md` named `memory-packing` as the strongest remaining implemented landing-page target.
- In the canonical no-DWARF `-O` / `-Os` scheduler it sits very early:
  - `duplicate-function-elimination -> remove-unused-module-elements -> memory-packing -> once-reduction -> global-refining -> ...`
- That placement is meaningful:
  - `remove-unused-module-elements` can shrink away obviously dead module baggage first
  - `memory-packing` then rewrites raw segment layout and passive-segment users
  - later module passes see the smaller rewritten layout
- In the saved generated-artifact `-O4z` audit, slot `3` (`memory-packing`) was already green:
  - canonical wasm equal: `yes`
  - normalized WAT equal: `yes`
  - Starshine wall/runtime: `650.310 ms`
  - Binaryen wall/runtime: `225.872 ms`
  - Starshine in-pass time: `12.684 ms`
  - Binaryen in-pass time: `31.292 ms`
- The 2026-06-03 `[O4Z-AUDIT-MP]` pass-local audit tightened the local implementation without changing that narrow contract:
  - active-only modules now skip code-section data-usage scanning when there are no passive segments
  - active overlap legality is sorted-span based instead of pairwise O(n²)
  - common single-kept-range active segments use a fast path that still preserves startup traps
  - direct `10000`-requested compare with command-failure keep-going stayed semantically green on all `9975` successfully compared cases, with only Binaryen/tool command failures
  - synthetic pass-local medians improved from `511 us` to `12 us` on an active-only large-code fixture and from `4421 us` to `825 us` on a many-active-segment fixture; the latter beat Binaryen's `975.6 us` median on the same fixture
- The saved Binaryen debug log contains one top-level `running pass: memory-packing` line, which fits the real story: this is an early module pre-pass, not a nested function-rerun cleanup pass.

## Most important durable takeaways

- Upstream `memory-packing` is not just “split active data segments around zeroes.”
- The folder now also has an immutable raw primary-source manifest plus a refreshed exact Starshine code-map page, so future readers no longer need to reconstruct release provenance or MoonBit navigation from prose alone.
- The real safety story starts with a whole-module legality gate:
  - exactly one memory only
  - imported memory only when `zeroFilledMemory` is enabled
  - overlapping active segments bail out
  - multiple active segments with dynamic offsets bail out
- Passive segments are a major part of the real pass contract.
- Upstream rewrites `memory.init` and `data.drop`, not just raw segment bytes.
- Preserving trap behavior is mandatory unless `trapsNeverHappen` is allowed.
- GC awareness exists here already, but mostly as a conservative boundary:
  - `array.new_data` and `array.init_data` users inhibit splitting today
- Current `main` matches the released `version_129` semantics here; the only visible drift is comment typo fixes.

## Biggest beginner correction

The easy wrong mental model is:

- `memory-packing` just deletes big zero runs from active segments

The safer mental model is:

- `memory-packing` is Binaryen's semantics-preserving data-segment packing pass, and it earns that name by coordinating:
  - data-segment splitting
  - passive user rewrites
  - explicit trap preservation
  - imported-memory safety
  - GC user conservatism
  - and output module validity limits

That difference matters a lot.
It explains why the pass happily optimizes some simple active segments, but immediately gives up or does much more work for passive segments, `memory.init`, dropped segments, GC array-data users, overlapping actives, or imported-memory cases.

## What the pass sounds like versus what it actually does

What it sounds like:

- pack memory by skipping zeroes

What it actually is in `version_129`:

- a module pass with a whole-module `canOptimize(...)` legality gate,
- an early active-`memory.init` / `data.drop` simplifier,
- a generic data-segment-referrer collector,
- a profitability calculator with different active versus passive thresholds,
- a split-segment emitter with name suffixing and segment-count limiting,
- and a passive-user replacement engine that mixes `memory.init`, `memory.fill`, `data.drop`, temp locals, and lazy drop-state globals.

## Page map

- [`./binaryen-strategy.md`](./binaryen-strategy.md)
  - Deep dive into the real `MemoryPacking.cpp` structure, helper utilities, scheduler placement, and the whole module-level algorithm.
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md)
  - Source-confirmed owner-file and lit-test map for `memory-packing`, including the real phase split between legality gating, early segment-op cleanup, referrer discovery, dead passive-segment cleanup, range analysis, split emission, and passive replacement planning.
- [`./segment-op-rewrites-and-traps.md`](./segment-op-rewrites-and-traps.md)
  - Focused guide to the hardest half of the pass: active-versus-passive differences, `memory.init` / `data.drop` rewrites, trap preservation, zero-filled imported memory, and memory64/high-bit corner cases.
- [`./wat-shapes.md`](./wat-shapes.md)
  - Beginner-friendly shape catalog covering positive active and passive families, profitability-driven no-split cases, bailout shapes, and the main “looks safe but is not” layouts.
- [`./starshine-hot-ir-strategy.md`](./starshine-hot-ir-strategy.md)
  - Current in-tree Starshine strategy and exact MoonBit code map: why this remains a module pass, where the local legality/range/dispatch/test surfaces live, and which major upstream surfaces are still missing.
- `docs/wiki/raw/binaryen/2026-04-22-memory-packing-primary-sources.md`
  - Immutable manifest for the official Binaryen release/source/test pages reviewed in this run.
- [`./parity.md`](./parity.md)
  - Current in-tree parity state, saved generated-artifact evidence, and the honest remaining gap between local and upstream surface area.

## Freshness note

A narrow 2026-04-22 direct source comparison found **no teaching-relevant semantic post-`version_129` drift** in this pass.

- The reviewed official Binaryen `version_129` release page on 2026-04-22 showed publish date **2026-04-01**.
- `MemoryPacking.cpp` still matched the released semantics on the reviewed `main` spot-check surfaces.
- The dedicated lit files used for this dossier still matched the released contract on the reviewed surfaces.

So the durable rule is:

- treat Binaryen `version_129` as the released oracle for this dossier
- keep the current-main note explicit only to say that the semantics still match

## Current maintenance rule

- Treat this folder as the canonical home for future `memory-packing` parity and scheduler research.
- Keep the main beginner correction explicit:
  - upstream `memory-packing` is a segment-plus-segment-op rewrite pass, not just an active-segment splitter
- Keep the active/passive split, trap-preservation story, imported-memory gate, GC conservative boundary, and memory64/high-bit unsigned handling explicit whenever future docs or code changes touch this pass.
- Treat the implementation/test-map page as the compact owner map for future follow-ups instead of re-deriving the phase split from chat history.
- Treat the raw primary-source manifest plus the refreshed Starshine page as the default provenance-and-navigation pair for future `memory-packing` work.

## Sources

- [`../../../raw/binaryen/2026-04-22-memory-packing-primary-sources.md`](../../../raw/binaryen/2026-04-22-memory-packing-primary-sources.md)
- [`../../../raw/research/0137-2026-04-20-memory-packing-binaryen-research.md`](../../../raw/research/0137-2026-04-20-memory-packing-binaryen-research.md)
- [`../../../raw/research/0700-2026-06-03-memory-packing-o4z-audit.md`](../../../raw/research/0700-2026-06-03-memory-packing-o4z-audit.md)
- [`../../../raw/research/0252-2026-04-22-memory-packing-primary-sources-and-code-map-followup.md`](../../../raw/research/0252-2026-04-22-memory-packing-primary-sources-and-code-map-followup.md)
- [`../../../../../src/passes/memory_packing.mbt`](../../../../../src/passes/memory_packing.mbt)
- [`../../../../../src/passes/memory_packing_test.mbt`](../../../../../src/passes/memory_packing_test.mbt)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../../../../../src/passes/registry_test.mbt`](../../../../../src/passes/registry_test.mbt)
- [`../../../../../agent-todo.md`](../../../../../agent-todo.md)
- [`../../../../../.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/summary.md`](../../../../../.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/summary.md)
- [`../../../../../.artifacts/o4z-wasm-opt-debug.log`](../../../../../.artifacts/o4z-wasm-opt-debug.log)
- Binaryen `version_129` sources:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/MemoryPacking.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/memory-packing_all-features.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/memory-packing_traps.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/memory-packing_zero-filled-memory.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/memory-packing_zero-filled-memory64.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/memory-packing_memory64-high-addr.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/memory-packing-gc.wast>
- Narrow freshness-check surface:
  - <https://github.com/WebAssembly/binaryen/blob/main/src/passes/MemoryPacking.cpp>
