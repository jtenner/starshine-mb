---
kind: comparison
status: working
last_reviewed: 2026-05-07
sources:
  - ../../../raw/binaryen/2026-04-22-memory-packing-primary-sources.md
  - ../../../raw/research/0137-2026-04-20-memory-packing-binaryen-research.md
  - ../../../raw/research/0252-2026-04-22-memory-packing-primary-sources-and-code-map-followup.md
  - ../../../raw/research/0555-2026-05-07-aud001-backlog-split-after-current-head-rerun.md
  - ../../../../../.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/summary.md
  - ../../../../../.artifacts/o4z-wasm-opt-debug.log
  - ../../../../../src/passes/memory_packing.mbt
  - ../../../../../src/passes/memory_packing_test.mbt
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/registry_test.mbt
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./segment-op-rewrites-and-traps.md
  - ./wat-shapes.md
  - ./starshine-hot-ir-strategy.md
---

# `memory-packing` Binaryen parity

## Durable conclusions

- Binaryen `version_129` `memory-packing` is a module-level segment-plus-segment-op rewrite pass, not just an active-segment splitter.
- Current Starshine only models the active-segment subset today.
- The saved generated-artifact `-O4z` slot `3` is already green, which shows the local active subset is useful and exercised by that artifact.
- A 2026-05-07 current-head smoke rerun reopened a narrow direct mismatch family: empty active-segment and dead passive-segment normalization still drift from Binaryen on saved `wasm-smith` cases under `.tmp/recheck-memory-packing/`.
- That saved green slot is **not** proof that Starshine already covers passive-segment rewriting, imported-memory `zeroFilledMemory`, GC data-referrer conservatism, or segment-count limiting.

## Current in-tree status

- The explicit implementation lives in [`../../../../../src/passes/memory_packing.mbt`](../../../../../src/passes/memory_packing.mbt).
- Focused coverage lives in [`../../../../../src/passes/memory_packing_test.mbt`](../../../../../src/passes/memory_packing_test.mbt).
- Preset scheduling coverage lives in [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt) and [`../../../../../src/passes/registry_test.mbt`](../../../../../src/passes/registry_test.mbt).

The current Starshine subset covers:

- one defined memory only
- constant i32 or i64 active offsets
- profitable active zero-range trimming
- trap-preserving top-byte retention
- overlap bailout
- data-count section updates after changed segment counts

## Remaining gap

The main documented Binaryen gap is the entire passive-segment and segment-user half of the official pass:

- no local `memory.init` rewrite engine
- no local `memory.fill` insertion for zero slices
- no local `data.drop` expansion or passive dead-segment cleanup
- no local lazy drop-state globals
- no imported-memory `zeroFilledMemory` mode
- no GC `array.new_data` / `array.init_data` no-split boundary
- no `MaxDataSegments` limiting guard

So the honest parity rule is:

- current Starshine has **artifact-local parity on the exercised active subset**
- but not yet full official-surface parity with Binaryen `MemoryPacking.cpp`

## Current evidence

The 2026-04-22 raw primary-source capture did not change the upstream-teaching verdict.
A later 2026-05-07 current-head rerun did change the direct-status note:

- `memory-packing` is no longer best described as simply artifact-green plus incomplete upstream coverage
- the remaining direct mismatch family is now specifically empty active-segment and dead passive-segment normalization drift, tracked in backlog slice `[MP]001`

The earlier source capture still made one freshness point explicit:

- the reviewed official Binaryen `version_129` release page still showed publish date **2026-04-01** on 2026-04-22
- the narrow `main` spot check did not surface a teaching-relevant drift from the released `memory-packing` contract on the reviewed source surfaces

## Saved generated-artifact audit

The saved `-O4z` audit reports slot `3` (`memory-packing`) as:

- canonical wasm equal: `yes`
- normalized WAT equal: `yes`
- Starshine runtime: `650.310 ms`
- Binaryen runtime: `225.872 ms`
- Starshine pass time: `12.684 ms`
- Binaryen pass time: `31.292 ms`

That is encouraging in two different ways:

- the local implementation already matches the artifact's exercised semantics
- the pass itself is not the local runtime bottleneck on that artifact; the wall-time gap is larger than the in-pass gap

## Saved Binaryen debug log

The saved Binaryen debug log shows one top-level `running pass: memory-packing` line.
That matches the documented scheduler story:

- this is a module pre-pass
- not a nested hot-rerun pass

## In-tree focused tests

The local focused suite currently covers three families:

- active profitable zero-range splitting
- active trap-preserving top-byte retention
- overlap bailout

Those tests are real, but still much smaller than the upstream lit surface.

## Practical signoff rule

For now, treat `memory-packing` as:

- **green on the saved generated artifact**
- **narrowly implemented locally**
- **not yet a full port of Binaryen `MemoryPacking.cpp`**

That is the honest status this dossier should preserve.

## Sources

- [`../../../raw/binaryen/2026-04-22-memory-packing-primary-sources.md`](../../../raw/binaryen/2026-04-22-memory-packing-primary-sources.md)
- [`../../../raw/research/0137-2026-04-20-memory-packing-binaryen-research.md`](../../../raw/research/0137-2026-04-20-memory-packing-binaryen-research.md)
- [`../../../raw/research/0252-2026-04-22-memory-packing-primary-sources-and-code-map-followup.md`](../../../raw/research/0252-2026-04-22-memory-packing-primary-sources-and-code-map-followup.md)
- [`../../../../../.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/summary.md`](../../../../../.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/summary.md)
- [`../../../../../.artifacts/o4z-wasm-opt-debug.log`](../../../../../.artifacts/o4z-wasm-opt-debug.log)
- Binaryen `version_129` pass source: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/MemoryPacking.cpp>
- Implementation: [`../../../../../src/passes/memory_packing.mbt`](../../../../../src/passes/memory_packing.mbt)
- Focused tests: [`../../../../../src/passes/memory_packing_test.mbt`](../../../../../src/passes/memory_packing_test.mbt)
