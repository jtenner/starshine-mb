---
kind: concept
status: supported
last_reviewed: 2026-04-21
sources:
  - ../../../raw/research/0137-2026-04-20-memory-packing-binaryen-research.md
  - ../../../raw/research/0204-2026-04-21-memory-packing-source-confirmation-followup.md
related:
  - ./index.md
  - ./segment-op-rewrites-and-traps.md
  - ./wat-shapes.md
  - ./starshine-hot-ir-strategy.md
  - ./parity.md
  - ../../no-dwarf-default-optimize-path.md
---

# Binaryen `memory-packing` strategy

## Upstream source rule

Use Binaryen `version_129` as the primary source oracle for this pass.

Primary files:

- `src/passes/MemoryPacking.cpp`
- `src/passes/pass.cpp`

Most important helper dependencies visible in the implementation:

- `DisjointSpans`
- `ModuleUtils::ParallelFunctionAnalysis`
- `UnifiedExpressionVisitor`
- `Builder`
- `ExpressionManipulator::nop(...)`
- `ReFinalize`
- `Names::getValidGlobalName(...)`
- `std::ckd_add`
- `WebLimitations::MaxDataSegments`

The shipped lit surface is also part of the contract:

- `test/lit/passes/memory-packing_all-features.wast`
- `test/lit/passes/memory-packing_traps.wast`
- `test/lit/passes/memory-packing_zero-filled-memory.wast`
- `test/lit/passes/memory-packing_zero-filled-memory64.wast`
- `test/lit/passes/memory-packing_memory64-high-addr.wast`
- `test/lit/passes/memory-packing-gc.wast`

For a compact owner/test map, see [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md).

## High-level intent

Binaryen uses `memory-packing` to reduce code and data size by omitting large zero runs from data segments.

But the real contract is much larger than that sentence sounds.

The pass only stays correct because it preserves all of these at once:

1. startup memory semantics for active segments
2. runtime `memory.init` semantics for passive segments
3. dropped-segment trap behavior
4. startup trap behavior for active segments that may go out of bounds
5. imported-memory zero-initialization assumptions
6. GC segment-user correctness
7. module limits such as maximum data-segment count

That is why this must stay a module pass.

## Where the pass runs

In `pass.cpp`, the default no-DWARF global-prepass builder inserts `memory-packing`:

- after `remove-unused-module-elements`
- before `once-reduction`

The gate is simply:

- `addIfNoDWARFIssues("memory-packing")`

That is notable because `memory-packing` is **not** behind the `optimizeLevel >= 2` check that guards some neighboring module passes.

This makes sense once you see what the pass really does:

- it is an early whole-module byte/layout cleanup,
- not a later semantic micro-optimization that needs high optimization levels to justify itself.

## No nested rerun story here

`memory-packing` is not part of the function-rerun helper in `opt-utils.h`.
It is a one-shot module pre-pass.

The saved generated-artifact Binaryen debug log matches that:

- one visible top-level `running pass: memory-packing`

So a future scheduler port must model it as an early module rewrite, not a repeated hot cleanup slot.

## Phase 0: module-level legality in `canOptimize(...)`

This function is the whole-module proof that the rest of the pass depends on.

It refuses to optimize when:

- there are zero memories
- there are multiple memories
- the only memory is imported and `zeroFilledMemory` is false
- there are multiple active segments and some active offset is nonconstant
- active segments overlap

The overlap rule is especially important.
A later active segment can intentionally overwrite an earlier one, including with zeroes.
That means a locally redundant-looking zero byte can still be semantically necessary.

So the pass first proves:

- active data layout is globally predictable enough for zero elision.

## Phase 1: early segment-op simplification in `optimizeSegmentOps(...)`

This is one of the easiest phases to underestimate because it means `memory-packing` already owns real instruction rewrites before it ever decides how to split bytes.

Before splitting anything, Binaryen rewrites some existing segment operations.

This helper pass runs per function and handles active-segment uses such as:

- `memory.init` that must trap because constant offset/size is already out of range
- zero-length `memory.init`, which still needs the correct destination-bounds trap behavior
- nonpassive `memory.init`, which can become a compact explicit bounds check
- `data.drop` of active segments, which can be turned into `nop`

This phase matters because it simplifies later reasoning:

- impossible or trivial segment ops are reduced early
- later replacement logic can assume fewer weird edge cases

## Phase 2: referrer discovery in `getSegmentReferrers(...)`

Binaryen next gathers every instruction that refers to each data segment.

Important design choice:

- this is not just a handwritten scan for `memory.init` and `data.drop`
- it uses generated field delegation and a generic name-kind check for `DataSegment`

That lets the pass see:

- `memory.init`
- `data.drop`
- `array.new_data`
- `array.init_data`
- and other segment-carrying instruction fields surfaced through the generic visitor

This broad scan is one reason the pass stays future-proof and module-centric.

## Phase 3: dead passive-segment cleanup in `dropUnusedSegments(...)`

This step is easy to miss.
Upstream `memory-packing` is already doing some dead passive-segment cleanup.

Rules:

- active segments are always kept
- passive segments are kept only if some referrer does more than just `data.drop`
- passive segments referenced only by `data.drop` are removed
- those obsolete `data.drop`s are turned into `nop`

So the pass is not only shrinking zero-heavy segments.
It is also cleaning out passive dead weight it can now prove irrelevant.

## Phase 4: per-segment legality in `canSplit(...)`

Even if the module as a whole is legal, a particular segment might still be ineligible.

Binaryen refuses to split a segment when:

- its name begins with `__llvm`
- it is empty
- a passive-segment `memory.init` referrer has nonconstant offset or size
- a referrer is `array.new_data` or `array.init_data`
- it is active and its offset is nonconstant

These checks are important because they show the pass is not purely about bytes.
It is equally about whether **users** can be rewritten honestly afterward.

## Phase 5: range building and profitability in `calculateRanges(...)`

A useful source-confirmed teaching split is:

- `canSplit(...)` answers whether a segment may be transformed at all.
- `calculateRanges(...)` answers which zero runs are worth transforming once legality is already proven.

This function performs the core range analysis.

### First it builds raw ranges

Binaryen scans the segment bytes and creates alternating:

- zero ranges
- nonzero ranges

### Then it decides whether traps must be preserved

If the segment may trap and `trapsNeverHappen` is not allowed, the pass must preserve that effect.

For active segments, it tries to prove the write is in bounds using:

- constant offset
- segment size
- memory initial size
- overflow-safe addition

If it cannot prove that, the pass preserves the trap.

### Then it applies profitability thresholds

For passive segments, the threshold includes estimated overhead from:

- passive segment metadata
- extra `memory.fill`
- extra `memory.init`
- extra `data.drop`

For active segments, the threshold is a simpler ballpark constant:

- `8`

### Then it treats edge zeroes specially

For passive segments, leading and trailing zeroes are cheaper to split than interior zeroes.
That is why the implementation has a separate `edgeThreshold`.

### Then it merges across small zero runs

If a zero run is too small to justify the extra emitted code or metadata, Binaryen merges the neighboring nonzero ranges back together.

### Finally it preserves the top byte when needed

If trap behavior must survive and the final byte would otherwise disappear as part of a zero range, Binaryen forces that last byte to remain as a synthetic “nonzero” range.

This is one of the most important beginner lessons in the file:

- sometimes a byte stays not because its value matters,
- but because the *fact that a write reaches it* matters for trapping semantics.

## Phase 6: segment emission in `createSplitSegments(...)`

Once ranges are final, Binaryen emits only the nonzero ranges as actual segments.

Important details:

- active offsets are shifted by the range start
- passive segments keep null offset because they are passive
- named segments keep the original name for the first surviving range
- later split ranges get suffixes like `.1`, `.2`, and so on
- if emitting all remaining split ranges would exceed `WebLimitations::MaxDataSegments`, Binaryen stops splitting and merges the rest back together

That last point is easy to overlook, but it is essential for validity.

## Phase 7: replacement planning in `createReplacements(...)`

This phase is the heart of passive-segment correctness.

### For `memory.init`

Binaryen computes the slice of the original segment used by that init and emits:

- `memory.fill` for zero ranges
- `memory.init` for nonzero ranges

If the original destination is nonconstant, the pass creates a closure that allocates a temp local later and patches all the replacement `local.get`s to refer to it.

### Why the destination temp is created late

The replacement plan is computed before per-function replacement runs.
But new locals can only be allocated once the enclosing function is available.
So the pass stores a closure rather than fully materialized IR.

### Why drop-state globals sometimes appear

`memory.init` implicitly checks whether the source segment was dropped.
`memory.fill` does not.

So when a rewritten sequence starts with `memory.fill`, Binaryen must emit an explicit check:

- `if (global.get $__mem_segment_drop_state) unreachable`

The drop-state global is created lazily and only when some replacement actually needs it.
That keeps the pass from polluting modules unnecessarily.

## Phase 8: `data.drop` replacement

After `memory.init` planning reveals whether a drop-state global is needed, Binaryen rewrites each original `data.drop` into:

- an optional `global.set dropState = 1`
- one `data.drop` per surviving nonzero split segment
- or `nop` if nothing remains

This means the passive-segment part of `memory-packing` is really a coordinated mini-lowering pass.

## Phase 9: final application in `replaceSegmentOps(...)`

The pass ends with a parallel function walker that replaces:

- `memory.init`
- `data.drop`
- and, structurally, can also look at `array.new_data`

Important nuance:

- in `version_129`, actual replacement plans are only created for `memory.init` and `data.drop`
- GC array-data users are instead used as a reason not to split in the first place

So the current GC story here is:

- conservative no-split, not full GC-segment rewrite.

## What this pass does **not** do

These non-goals are worth keeping explicit:

- no multimemory rewrite
- no optimistic handling of overlapping active segments
- no splitting of passive segments with dynamic `memory.init` offset or size
- no rewriting of `array.new_data` / `array.init_data` users today
- no generic symbolic overlap solver for dynamic offsets
- no nested function-pipeline rerun behavior

## Why the official tests matter so much

The real pass contract is easier to understand once you see the test split:

- `memory-packing_all-features.wast`
  - broad positive and profitability behavior
- `memory-packing_traps.wast`
  - trap preservation and TNH boundaries
- `memory-packing_zero-filled-memory*.wast`
  - imported-memory safety gate
- `memory-packing_memory64-high-addr.wast`
  - unsigned high-bit handling in memory64-related immediates
- `memory-packing-gc.wast`
  - conservative GC user handling

Taken together, those tests show that the pass is much more about semantic bookkeeping than the short registry description implies.

## Current freshness note

A narrow 2026-04-20 check found no semantic drift here:

- current `main` differs from `version_129` only by comment typo fixes in `MemoryPacking.cpp`
- the dedicated lit files are identical

So the current wiki should continue treating `version_129` as the semantic oracle without an active trunk-drift caveat.

## What a future port must preserve

A future strict-parity Starshine port or refactor must keep these Binaryen-backed rules honest:

- whole-module legality first, not just local range trimming
- active versus passive segments are different problems
- imported memory is only safe with a zero-filled guarantee
- passive-segment correctness depends on rewriting users, not just segment bytes
- explicit drop-state checks are required when `memory.fill` would otherwise skip dropped-segment trapping
- trap-preserving top-byte retention is intentional and necessary
- memory64/high-bit immediate handling must stay unsigned and overflow-safe
- GC array-data users are real boundaries today
- segment-count limits matter for validity, not just size heuristics

If local code intentionally broadens or narrows any of those rules, keep that as an explicit documented divergence.
