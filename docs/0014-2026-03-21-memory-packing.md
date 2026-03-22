# MemoryPacking

Status: research baseline plus slices 1-6. In Starshine today, the pass still has no segment splitting/materialization or final replacement-rewrite implementation, but the generated optimizer now dispatches `MemoryPacking` through a dedicated runner, threads the initial `zero_filled_memory` / `traps_never_happen` option surface, applies the documented analysis-only gating for unsupported memory/imported-memory/active-layout cases, performs the stage-3 pre-normalization of obvious `memory.init` / active `data.drop` cases, collects per-`DataIdx` referrers for `memory.init`, `data.drop`, `array.new_data`, and `array.init_data`, removes dead passive segments with the required `DataIdx` / `DataCntSec` remap, and computes the documented split-eligibility/range-analysis plan. This document remains the implementation blueprint for the later semantic slices.

## Purpose

Document the next pass in the default optimize pipeline after `RemoveUnusedModuleElements`, explain how Binaryen's `MemoryPacking` pass works in exact operational terms, and spell out what a correct Starshine implementation must do from scheduling through IR rewriting and validation.

## Why This Is The Next Pass

In Starshine's generated optimize pipeline, the first default global pre-pass sequence is currently:

1. `DuplicateFunctionElimination`
2. `RemoveUnusedModuleElements`
3. `MemoryPacking`
4. `OnceReduction`

The local proof points are:

- `OptimizePass::MemoryPacking` is the third enum entry in the default pipeline neighborhood.
- `add_default_global_optimization_pre_passes` inserts `RemoveUnusedModuleElements`, then `MemoryPacking`, then `OnceReduction`.
- `optimization_test.mbt` asserts that pipeline order for the default `opt_level=2` case.

Relevant local files:

- `src/optimization/optimization.mbt`
- `src/optimization/optimization_test.mbt`
- `src/cmd/cmd.mbt`

## Current Starshine State

The important thing to understand up front is that Starshine does not yet have an in-tree `MemoryPacking` implementation.

What exists now:

1. The pass is represented in the `OptimizePass` enum.
2. The pass is scheduled in the generated default pipeline.
3. The pass is classified as `ModuleWide`.
4. The generated optimizer dispatches `MemoryPacking` through a dedicated `run_memory_packing` runner.
5. The initial pass-option plumbing for `zero_filled_memory` and `traps_never_happen` now threads through generated-pipeline features and explicit pass expansion.
6. The runner now applies the documented analysis-only bailouts for unsupported memory topologies, imported memory without the zero-fill promise, overlapping active segments, and dynamic active offsets in the multi-segment case.
7. The runner now pre-normalizes the obvious active/passive `memory.init` trap and zero-length cases plus active `data.drop`.
8. The runner now collects per-`DataIdx` referrer lists for `memory.init`, `data.drop`, `array.new_data`, and `array.init_data`.
9. The runner now removes passive segments that are unreferenced or only referenced by `data.drop`, rewrites removed drop-only `data.drop`s to `nop`, and remaps later `DataIdx` users plus `DataCntSec`.
10. The runner now computes split eligibility plus final zero/nonzero range plans, including active/passive profitability thresholds, startup-trap preservation, and the Web segment-count cap merge rule.
11. The runner still has no segment splitting/materialization or final replacement-rewrite logic.

That means:

- The pass name and scheduling are real.
- Slices 1-3 from the implementation plan are complete.
- The semantics are not yet real in Starshine.
- Any correctness validation for this pass must currently be done against upstream Binaryen behavior, then ported into Starshine-specific IR mechanics.

## Upstream Sources Used

Primary implementation source:

- Binaryen `src/passes/MemoryPacking.cpp`
  - https://github.com/WebAssembly/binaryen/blob/main/src/passes/MemoryPacking.cpp

Primary test sources:

- https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/memory-packing_all-features.wast
- https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/memory-packing_traps.wast
- https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/memory-packing_zero-filled-memory.wast
- https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/memory-packing_zero-filled-memory64.wast
- https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/memory-packing_memory64-high-addr.wast
- https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/memory-packing-gc.wast
- https://github.com/WebAssembly/binaryen/blob/main/test/unit/test_memory_packing.py

High-level pass catalog entry:

- https://github.com/WebAssembly/binaryen/blob/main/README.md

## One-Sentence Summary

`MemoryPacking` shrinks linear-memory initialization metadata by splitting data segments around profitable zero runs, dropping zero-only portions that do not need to exist as stored bytes, and rewriting all affected segment-consuming instructions so runtime behavior stays equivalent, including trap behavior.

## The Real Problem It Solves

The pass is not primarily about runtime speed. It is a binary-size pass.

The core observation is:

- A data segment often contains long zero runs.
- Encoding those zero bytes literally in the binary is expensive.
- For active segments, zero bytes often do not need to be stored at all because linear memory starts zero-initialized.
- For passive segments, zero bytes can often be recreated with `memory.fill` instead of storing them in the segment payload.

The difficulty is that data segments are observable in several ways:

1. Startup semantics for active segments must stay correct.
2. `memory.init` and `data.drop` must still behave correctly for passive segments.
3. Trap behavior must be preserved.
4. Segment users under GC instructions like `array.new_data` and `array.init_data` complicate splitting.
5. Imported memory is only safe to optimize if we know it starts zero-filled.
6. Overlapping active segments can rely on later zero bytes overwriting earlier nonzero bytes.

So the pass is not "drop zero bytes everywhere". It is "drop and reconstitute zero bytes only when the surrounding semantics can be preserved precisely enough".

## What The Pass Does At A High Level

Binaryen's top-level `run()` logic is conceptually:

```text
run(module):
  if !canOptimize(module.memories, module.dataSegments):
    return

  canHaveSegmentReferrers =
    module.features.hasBulkMemory || module.features.hasGC

  referrers = {}

  if canHaveSegmentReferrers:
    optimizeSegmentOps(module)
    referrers = collectSegmentReferrers(module)
    dropUnusedSegments(module, module.dataSegments, referrers)

  packed = []
  replacements = {}

  for each remaining segment:
    currReferrers = referrers[segment.name]
    if canSplit(segment, currReferrers):
      ranges = calculateRanges(module, segment, currReferrers)
    else:
      ranges = [{ isZero: false, start: 0, end: segment.data.size }]

    newSegments = createSplitSegments(segment, ranges)
    append newSegments to packed
    createReplacements(module, ranges, newSegments, currReferrers, replacements)

  replace module.dataSegments with packed
  rebuild data-segment lookup map

  if canHaveSegmentReferrers:
    apply replacements to memory.init and data.drop
```

That is the whole pass skeleton. Most of the complexity lives in:

1. deciding whether optimization is allowed at all,
2. deciding whether a particular segment may be split,
3. computing which zero ranges are profitable to drop,
4. preserving traps,
5. rewriting `memory.init` and `data.drop`.

## What Counts As "Equivalent"

The pass preserves:

1. Final observable memory contents after startup and after segment-consuming instructions run.
2. Traps from invalid `memory.init` and from active startup initialization, unless the pass runner says `trapsNeverHappen`.
3. Segment-drop semantics when `memory.init` should trap because the source segment was already dropped.
4. Behavior of active segments that may overlap or depend on ordering, by refusing to optimize in those cases.
5. Semantics of segment consumers the pass cannot yet rewrite precisely enough, by refusing to split those segments.

The pass intentionally changes:

1. Raw data-segment layout.
2. Number of data segments.
3. Some `memory.init` into multiple `memory.init` plus `memory.fill`.
4. Some `data.drop` into multiple `data.drop`.
5. Some obviously trapping or empty segment operations into smaller equivalent IR.

## Stage 1: Global Bailout Conditions

Binaryen first asks whether optimization is safe at all.

### 1. Exactly one memory

The pass bails out if the module has:

- no memory, or
- more than one memory.

So there is no multimemory support here.

Implication for Starshine:

- If Starshine later gains multimemory, a first port should preserve this bailout unless the port also adds the full multimemory semantics.

### 2. Imported memory requires a zero-filled-memory promise

The pass assumes unwritten memory is zero.

That is always true for a defined memory at instantiation.
That is not automatically safe for an imported memory unless pass options explicitly promise imported memory is zero-filled.

So:

- defined memory: allowed
- imported memory with `zeroFilledMemory=true`: allowed
- imported memory without that option: bail out

### 3. Multiple active segments with unknown offsets are unsafe

If there is more than one data segment, active segments with nonconstant offsets are a problem.

Why:

- Active segments are applied in order at startup.
- A later segment can overwrite bytes written by an earlier one.
- A zero byte inside the later segment may be semantically necessary because it clears an earlier nonzero byte.
- If the later segment offset is dynamic, the pass cannot know whether that overwrite matters.

Example:

```wat
(data (i32.const 100) "A")
(data (global.get $x) "\00")
```

If `$x` happens to be `100`, the second segment zeroes the `A`.
If the pass dropped the zero, that effect would disappear.

So if there are multiple segments and an active segment offset is nonconstant, Binaryen bails out entirely.

### 4. Overlapping active segments are unsafe

Even if all active offsets are constant, Binaryen still refuses to optimize when active segments overlap.

Reason:

- A later active segment may intentionally overwrite bytes from an earlier one.
- Removing zero runs from the later segment could change the final memory contents.

Binaryen checks overlap with `DisjointSpans`.

Example:

```wat
(data (i32.const 100) "A")
(data (i32.const 100) "\00")
```

The second segment's zero is observable. It cannot be dropped.

### 5. Single-segment special case

If the module has at most one data segment, Binaryen allows the pass to proceed even if the active offset is nonconstant.

That does not mean the segment will necessarily be split.

It only means the global "inter-segment trampling" concern disappears.
Later, per-segment splitting still requires constant offsets for active segments.

## Stage 2: Pre-normalize Segment Operations

This stage only runs if data segments can be referred to by instructions, which Binaryen models as:

- bulk memory enabled, or
- GC enabled

Binaryen does this before collecting referrers because it wants simpler referrer patterns and wants some segments to become obviously dead.

### What `optimizeSegmentOps` rewrites

It walks functions and rewrites:

1. `memory.init`
2. `data.drop`

#### Case A: `memory.init` of an active segment

For an active segment, runtime `memory.init` is already semantically odd because active segments are for instantiation-time initialization, not passive copying.

Binaryen reduces these cases to the actual trap behavior:

- If `offset != 0` or `size != 0`, the operation must trap.
- If `offset == 0` and `size == 0`, the only remaining effect is "trap if destination is out of bounds".

So:

```wat
(memory.init $active (dst) (i32.const 13) (i32.const 0))
```

becomes:

```wat
(drop dst)
(drop (i32.const 13))
(drop (i32.const 0))
(unreachable)
```

And:

```wat
(memory.init $active dst (i32.const 0) (i32.const 0))
```

becomes:

```wat
(if (dst > memory.size << 16) (then unreachable))
```

Then:

```wat
(data.drop $active)
```

becomes `nop`, because active segments are not runtime-droppable state in the same way passive segments are.

#### Case B: passive `memory.init` proven to trap

If a passive segment has size `N`, and `offset > N`, or `size > N`, or `offset + size > N`, the instruction must trap.

Binaryen rewrites it to:

```wat
(drop dest)
(drop offset)
(drop size)
(unreachable)
```

#### Case C: passive `memory.init` proven empty

If `offset == 0` and `size == 0`, the data copy is empty.

But `memory.init` may still trap if `dest` is out of bounds.

So Binaryen replaces it with only the destination bounds check:

```wat
(if (dest > memory.size << pageShift) (then unreachable))
```

#### Why this stage exists

It has two jobs:

1. Remove segment operations that can be simplified before splitting.
2. Make later replacement generation easier, because later code can assume away some degenerate patterns.

## Stage 3: Collect Segment Referrers

After pre-normalization, Binaryen scans all functions and records every expression that refers to each data segment.

This is generic, not hardcoded to only `memory.init` and `data.drop`.

It picks up any IR field whose module-item kind is `DataSegment`.

Practically, the important referrers are:

1. `memory.init`
2. `data.drop`
3. `array.new_data`
4. `array.init_data`

### Why this matters

The pass needs to know:

1. whether a passive segment is actually used,
2. whether splitting is legal,
3. how many runtime operations a split would introduce,
4. which instructions need replacement.

## Stage 4: Drop Unused Passive Segments Early

Binaryen removes passive segments that are never meaningfully used.

The rules are:

- Active segments are always kept here.
- Passive segments are kept if they have any referrer other than `data.drop`.
- Passive segments with only `data.drop` referrers are removed, and those `data.drop`s become `nop`.
- Passive segments with no referrers are removed.

This is intentionally conservative:

- it removes whole dead passive segments,
- but it does not do partial dead-range trimming based on actual subranges used by `memory.init`.

That TODO is still open upstream.

## Stage 5: Decide Whether Each Segment May Be Split

Binaryen does not split every segment.

### Hard "do not split" rules

#### 1. LLVM coverage segments

If the segment name starts with `__llvm`, Binaryen refuses to split it.

Reason:

- downstream tooling expects those segments in recognizable form.

#### 2. Empty segments

Empty segments are left alone.

Reason:

- they may still matter for startup trap behavior,
- and `RemoveUnusedModuleElements` is the pass that decides whether such segments can be removed.

#### 3. Passive segments with nonconstant `memory.init` offset or size

If a passive segment is referenced by `memory.init` whose segment `offset` or `size` operand is not constant, Binaryen refuses to split that segment.

Reason:

- replacement generation assumes constant slicing into segment subranges.

#### 4. GC data-segment consumers

If the segment is referenced by `array.new_data` or `array.init_data`, Binaryen refuses to split it.

Upstream TODO:

- support splitting these GC users later.

#### 5. Active segment with nonconstant offset

Active segments may only be split if their startup offset is constant.

## Stage 6: Compute Candidate Ranges

If a segment may be split, Binaryen computes alternating zero and nonzero half-open byte ranges `[start, end)`.

Example:

```text
bytes = "ab\0\0cd\0"
```

initial ranges become:

```text
[0,2) nonzero
[2,4) zero
[4,6) nonzero
[6,7) zero
```

This is just the raw segmentation. Profitability and trap preservation come later.

## Stage 7: Preserve Startup Traps When Required

This is one of the most important details in the pass.

For active segments, dropping all-zero bytes can accidentally remove a startup trap.

Example:

```wat
(memory 1 2)
(data (i32.const 65536) "\00")
```

That segment is out of bounds and traps during instantiation.
If the pass removed the segment entirely because it is "all zero", it would silently remove the trap.

So Binaryen computes:

```text
preserveTrap =
  !trapsNeverHappen && segment is active
```

Then it tries to prove the segment is definitely in bounds:

- if the offset is constant,
- and `offset + data.size` fits without overflow,
- and the end is within the initial memory size,

then trap preservation is not needed.

Otherwise trap preservation stays on.

### How the trap is preserved

If the final byte of the segment would have been inside a zero range that would normally be dropped, Binaryen forces preservation of exactly the topmost byte.

It does that by:

1. shrinking the trailing zero range by one byte,
2. appending a new one-byte range marked as nonzero, even though that byte may actually be zero.

This is intentionally a semantic trick:

- the byte is kept not because its value matters,
- but because writing that highest byte is enough to preserve the original startup trap.

This is a key correctness invariant.

## Stage 8: Profitability Heuristics

The pass does not split on every zero run. It tries to shrink binary size overall.

### Active segments

For active segments, Binaryen uses a coarse fixed threshold:

- interior zero runs of length `<= 8` are merged back into neighbors

So active splitting is intentionally rough.

### Passive segments

For passive segments, the threshold is estimated from the runtime rewrite cost.

The pass starts with:

- `2` bytes of passive-segment metadata overhead

Then, for each referrer:

- `memory.init` contributes the estimated size of one added `memory.fill` plus one added `memory.init`
- other referrers, effectively `data.drop`, contribute one `data.drop`

There is also a smaller `edgeThreshold` for zero runs at the beginning or end of the segment, because trimming edge zeroes does not create additional segment payloads the same way interior splits do.

### Conceptual interpretation

Binaryen asks:

- "If I split here, how much segment payload do I save?"
- "How many replacement instructions do I pay for?"

If the zero run is too short, it is cheaper to keep the zero bytes in the original segment.

### Range merging step

After thresholds are known, Binaryen merges across zero runs that are too small to be worth splitting.

Conceptually:

```text
merged = [firstRange]
for each interior range:
  if current range is zero and current.length <= threshold:
    merge left + current + right
  else:
    keep current
```

Then it applies the trap-preservation fixup if needed.

## Stage 9: Create New Split Segments

After final ranges are chosen, Binaryen emits new data segments for the nonzero ranges only.

Zero ranges do not become data segments.

### Active segments

For an active segment, each nonzero range becomes a new active segment whose offset is:

```text
newOffset = originalOffset + range.start
```

But this addition is checked and saturating:

- if the arithmetic overflows, Binaryen saturates to unsigned max

Why:

- overflow must not wrap to a small valid address,
- that could accidentally turn a trapping case into a non-trapping case,
- saturating keeps the operation maximally out of bounds.

This detail matters for both `i32` and `i64` memories.

### Passive segments

For passive segments, the new segments simply contain the nonzero payload pieces in order.

### Naming

If the original segment has a name:

- the first emitted nonzero range reuses the original name,
- later emitted ranges get suffixes like `.1`, `.2`, and so on.

If the segment is unnamed, Binaryen still creates new segment objects; printed output may assign display names later.

### Web segment-count guardrail

Binaryen refuses to create more than the Web data-segment limit.

If splitting would exceed the limit, it stops splitting the rest of that segment and merges the remaining ranges back together, except for final trailing zeroes that can still be omitted.

This behavior is also covered by upstream unit tests.

## Stage 10: Create Instruction Replacements

Once the split segments exist conceptually, Binaryen prepares replacements for instructions that referred to the original segment.

This is where the pass becomes semantically interesting.

### Important design pattern

Replacement creation happens in two stages:

1. compute the replacement shape now,
2. materialize any needed locals later, during the final replacement walk

Binaryen does this because the replacement might need a fresh local to hold the original destination address, but local allocation requires access to the enclosing function.

## Rewriting `memory.init`

This is the center of the pass.

Suppose a passive segment was:

```text
range 0: zero    [0, 30)
range 1: bytes   [30, 45)
```

and the original instruction was:

```wat
(memory.init $seg
  (i32.const 0)
  (i32.const 0)
  (i32.const 45))
```

The replacement becomes conceptually:

```wat
(if (global.get $__mem_segment_drop_state) (then unreachable))
(memory.fill (i32.const 0) (i32.const 0) (i32.const 30))
(memory.init $seg (i32.const 30) (i32.const 0) (i32.const 15))
```

### Why a drop-state global exists

Original `memory.init` on a dropped segment traps.

But a synthesized `memory.fill` does not know anything about segment drop state.

So when a rewritten `memory.init` begins with a zero range, Binaryen may need an explicit global:

```text
__mem_segment_drop_state
```

which is:

- initialized to `0`,
- set to `1` when the corresponding rewritten `data.drop` executes,
- checked before any leading synthesized `memory.fill`.

This preserves the rule:

- "if the original segment had already been dropped, the operation traps before writing anything"

### Zero-length `memory.init`

Zero-length `memory.init` is handled specially.

After pre-normalization, such a case only remains in interesting form when:

- the offset is nonzero, or
- segment-drop state matters

Binaryen rewrites it to:

```wat
(if
  (or
    (dest > memory.size << pageShift)
    (global.get $__mem_segment_drop_state))
  (then unreachable))
```

### Nonconstant destination

If `dest` is not constant, the replacement may need to reuse it multiple times.

Binaryen therefore:

1. creates a fresh local at replacement time,
2. stores the original destination in that local once,
3. reads it back and adds `bytesWritten` offsets for each split chunk.

Conceptually:

```text
tmp = dest
emit op for first overlapping range at tmp + 0
emit op for next overlapping range at tmp + bytesWritten
emit op for next overlapping range at tmp + bytesWritten
...
```

### How the rewritten loop works

For each overlapping final range:

1. compute the destination for that range,
2. compute how many bytes of the original `memory.init` fall into that range,
3. emit:
   - `memory.fill(dest, 0, bytes)` if the range is zero
   - `memory.init(splitSegment, dest, localOffset, bytes)` if the range is nonzero

### Pseudocode

```text
rewriteMemoryInit(init, ranges, splitSegments):
  start = const(offset)
  end = start + const(size)

  if start == end:
    return trapIf(destOutOfBounds || dropped)

  firstRange = first range intersecting [start, end)
  initIndex = number of nonzero ranges before firstRange

  result = []
  if dest is nonconst:
    tmp = freshLocal
    result += [tmp = dest]

  if firstRange.isZero:
    result += [if dropped then unreachable]

  bytesWritten = 0
  for range in ranges that intersect [start, end):
    destExpr = baseDest + bytesWritten
    bytes = intersectionSize(range, [start, end))
    if range.isZero:
      result += [memory.fill(destExpr, 0, bytes)]
    else:
      relativeOffset = max(start, range.start) - range.start
      result += [memory.init(splitSegments[initIndex], destExpr, relativeOffset, bytes)]
      initIndex += 1
    bytesWritten += bytes

  return block(result)
```

## Rewriting `data.drop`

If the original segment split into multiple nonzero segments, `data.drop` becomes:

1. optional `global.set dropState = 1`, but only if some rewritten `memory.init` needed drop-state tracking,
2. one `data.drop` for each nonzero split segment

If a segment became entirely zero and there are no remaining nonzero pieces:

- rewritten `data.drop` becomes `nop`, unless a drop-state global still needs to be set

### Pseudocode

```text
rewriteDataDrop(ranges, splitSegments):
  result = []
  if dropStateGlobalWasNeeded:
    result += [global.set(dropState, 1)]
  for each nonzero range in ranges:
    result += [data.drop(correspondingSplitSegment)]
  if result empty:
    return nop
  return block(result)
```

## Stage 11: Final Replacement Walk

After all replacements are prepared, Binaryen runs a parallel function walker that replaces:

1. `memory.init`
2. `data.drop`

Only those expressions are replaced.

The replacement closures allocate any fresh locals at this moment.

## Worked Example 1: Active Segment With Middle Zeroes

Input:

```wat
(module
  (memory 1 1)
  (data (i32.const 1024) "ABC\00\00\00XYZ")
)
```

Reasoning:

1. single memory, allowed
2. defined memory, zero-filled by definition
3. one segment, so no inter-segment overlap concern
4. active segment has constant offset, so splitting is allowed
5. zero run is long enough to beat the active threshold

Result shape:

```wat
(data $d   (i32.const 1024) "ABC")
(data $d.1 (i32.const 1030) "XYZ")
```

No `memory.init` or `data.drop` rewrite is needed because active segments are applied at startup.

## Worked Example 2: Passive Segment Rewritten Into `memory.fill` Plus `memory.init`

Input:

```wat
(module
  (memory 1 1)
  (data $s "\00\00\00\00HELLO\00\00\00\00")
  (func
    (memory.init $s
      (i32.const 100)
      (i32.const 0)
      (i32.const 13))
    (data.drop $s))
)
```

Assume the zero runs are profitable to split.

Final ranges:

```text
[0,4) zero
[4,9) nonzero  "HELLO"
[9,13) zero
```

Split segments:

```wat
(data $s "HELLO")
```

Rewritten body shape:

```wat
(block
  (if (global.get $__mem_segment_drop_state) (then unreachable))
  (memory.fill (i32.const 100) (i32.const 0) (i32.const 4))
  (memory.init $s (i32.const 104) (i32.const 0) (i32.const 5))
  (memory.fill (i32.const 109) (i32.const 0) (i32.const 4))
)
(block
  (global.set $__mem_segment_drop_state (i32.const 1))
  (data.drop $s)
)
```

Key point:

- the pass has moved the zero bytes out of static segment payload and into runtime zero-fills,
- while still preserving segment-drop trapping.

## Worked Example 3: Preserve A Startup Trap

Input:

```wat
(module
  (memory 1 2)
  (data (i32.const 65535) "\00\00")
)
```

Reasoning:

1. The original segment writes two bytes starting at `65535`.
2. Memory size is one page, so valid byte indices end at `65535`.
3. Writing the second byte traps during instantiation.
4. If the pass dropped this all-zero segment entirely, it would remove the trap.

So Binaryen preserves exactly the topmost byte needed to keep the trap:

```wat
(data $data (i32.const 65536) "\00")
```

That looks odd at first glance, but it is exactly the correct semantic move:

- keep the minimum out-of-bounds write needed to preserve the original effect.

## Worked Example 4: Simplify Obvious `memory.init` Trap

Input:

```wat
(func
  (memory.init $active
    (i32.const 42)
    (i32.const 13)
    (i32.const 0))
  (data.drop $active))
```

If `$active` is an active segment, this always traps.

Rewritten shape:

```wat
(block
  (drop (i32.const 42))
  (drop (i32.const 13))
  (drop (i32.const 0))
  (unreachable))
(nop)
```

This happens before range splitting.

## Edge Cases You Must Match

These are the correctness-sensitive corners most likely to be implemented incorrectly in a port.

### 1. Imported memory without zero-filled guarantee

Must bail out entirely.

### 2. Multimemory

Must bail out entirely.

### 3. Overlapping active segments

Must bail out entirely.

### 4. Dynamic active offsets with multiple segments

Must bail out entirely.

### 5. Empty segments

Do not split them here.

### 6. Passive segment only referenced by `data.drop`

Remove the segment and rewrite drops to `nop`.

### 7. Passive segment referenced by `array.new_data` or `array.init_data`

Do not split it.

### 8. High-bit constants in memory64 and in `memory.init` offset or size

Treat them as unsigned quantities for bounds reasoning.

This is explicitly covered by upstream `memory-packing_memory64-high-addr.wast`.

### 9. Active offset arithmetic overflow

Use checked arithmetic and saturate, do not wrap.

### 10. `trapsNeverHappen`

If enabled, trap-preservation logic for active startup segments may be relaxed exactly the way upstream does.

### 11. Segment-count limit

Do not generate more segments than the target format permits.

### 12. Leading zero range in rewritten `memory.init`

If the first emitted action is `memory.fill`, you need an explicit dropped-segment check first.

That is easy to miss and semantically critical.

## Starshine-Specific Porting Notes

Binaryen's internal representation is not Starshine's representation.

This matters a lot here.

### 1. Binaryen uses named data segments internally

Binaryen replacements refer to segment names.

Starshine IR uses `DataIdx`.

So a Starshine port cannot just "swap segments and keep references working". It needs explicit `DataIdx` remapping.

The local IR surface that matters is:

1. `Instruction::memory_init(DataIdx, MemIdx)`
2. `Instruction::data_drop(DataIdx)`
3. `Instruction::array_new_data(TypeIdx, DataIdx)`
4. `Instruction::array_init_data(TypeIdx, DataIdx)`
5. `DataCntSec`

### 2. Starshine needs full data-index rewrite support

Binaryen's pass only constructs replacements for `memory.init` and `data.drop`.

That is enough there because names stay attached to the surviving segments.

In Starshine, segment compaction or splitting means you need:

1. a mapping from original `DataIdx` to zero, one, or many replacement indices,
2. instruction rewriting for all data-index consumers,
3. `data_count` maintenance,
4. binary/text printer and validator agreement after the rewrite.

### 3. Starshine may need a dedicated segment-operation lowering phase

Binaryen mutates `memory.init` and `data.drop` directly with full IR builders.

In Starshine, it will likely be cleaner to model this as:

1. analyze segment uses,
2. compute a rewrite plan per data segment,
3. rewrite instruction trees using explicit builder helpers,
4. run any necessary refinalization or validation repair.

### 4. `RemoveUnusedModuleElements` overlap

Some responsibilities sit near the boundary between this pass and `RemoveUnusedModuleElements`.

Binaryen lets `MemoryPacking` drop wholly unused passive segments discovered in its own analysis.

That is fine, but in Starshine you must ensure the two passes do not fight over:

1. `DataIdx` compaction,
2. `DataCntSec`,
3. passive-segment removal semantics,
4. trap-preserving active all-zero segments.

My recommendation is:

- keep `MemoryPacking` responsible only for segments it directly transforms or proves dead because of segment-op analysis,
- and keep general dead segment liveness in `RemoveUnusedModuleElements`.

That mirrors upstream intent closely enough.

## Implementation Blueprint For Starshine

If implementing this pass in Starshine, the safest decomposition is:

### Slice 1: Scheduler and no-op plumbing

1. Replace the current module-wide no-op dispatch for `MemoryPacking`.
2. Keep it in the same pipeline slot.
3. Thread pass options needed for:
   - `zero_filled_memory`
   - `traps_never_happen`

### Slice 2: Analysis-only gating

1. detect unsupported memory topologies,
2. detect imported-memory-without-zero-fill promise,
3. detect active overlap,
4. detect dynamic active offsets in the multi-segment case,
5. return the input module unchanged if any bailout triggers

### Slice 3: Segment-op pre-normalization

1. rewrite obvious `memory.init` traps,
2. rewrite zero-length `memory.init`,
3. rewrite active `data.drop` to `nop`

### Slice 4: Referrer collection

1. build per-`DataIdx` referrer lists,
2. include GC data consumers,
3. prove coverage with tests before splitting anything

### Slice 5: Dead passive segment removal

1. remove unreferenced passive segments,
2. remove passive segments referenced only by `data.drop`,
3. remap all later data indices,
4. update `DataCntSec`

### Slice 6: Range analysis

1. raw zero/nonzero ranges,
2. profitability thresholds,
3. trap-preservation fixups,
4. segment-count cap handling

### Slice 7: Segment materialization

1. emit split data segments,
2. build original-index to replacement-index mapping,
3. preserve active offsets with checked arithmetic,
4. retain unsplittable segments as single replacements

### Slice 8: Instruction rewriting

1. rewrite `memory.init`,
2. rewrite `data.drop`,
3. rewrite `array.new_data` and `array.init_data` index references when earlier segments were removed or renumbered,
4. allocate new locals for nonconstant destinations where needed

### Slice 9: Validation and final cleanup

1. validate `data_count`,
2. validate rewritten memory index and data index references,
3. validate trap-preserving cases,
4. run idempotence tests

## Test Plan

The pass absolutely needs strict TDD. The minimum useful test buckets are:

### Correctness

1. active single segment with leading, trailing, and middle zero runs
2. passive single segment with `memory.init`
3. passive segment with both `memory.init` and `data.drop`
4. passive segment used only by `data.drop`
5. passive segment unused entirely
6. active segment that traps at startup and must be preserved
7. same cases with `traps_never_happen=true`
8. imported memory with and without zero-filled-memory promise
9. overlapping active segments bailout
10. dynamic active offset multi-segment bailout
11. active `memory.init` simplification cases
12. passive `memory.init` out-of-bounds simplification cases
13. GC `array.new_data` and `array.init_data` no-split cases
14. memory64 high-bit offset and size cases
15. segment-count cap case

### Stability

1. second run is a no-op
2. remapping remains valid after previous segment removals
3. `DataCntSec` stays correct

### Local integration

1. pipeline dispatch test proving `MemoryPacking` is no longer a no-op
2. inline/dispatch test in the pass file
3. generated pipeline test keeping `MemoryPacking` in its current slot

## Performance Notes

This is mostly a size pass, but the implementation can still be made pathological if done carelessly.

Likely cost centers in a Starshine port:

1. scanning every function to collect data-segment referrers,
2. rebuilding large data sections,
3. repeated full-tree instruction rewrites,
4. repeated `DataIdx` remaps across the module,
5. naive concatenation or copying of large byte arrays

Practical implementation advice:

1. keep range scanning linear in segment size,
2. precompute referrer lists in one module walk,
3. avoid repeated whole-module remaps by planning a single data-index rewrite per structural phase,
4. preserve original byte slices by reference where possible before final construction,
5. short-circuit quickly when the module has zero or one unsplittable segment

## Open Questions For The Port

1. Should Starshine copy Binaryen's exact profitability constants, or expose them as internal tuning knobs?
2. Should the first port intentionally skip GC consumers entirely, or support their index remapping while still refusing segment splitting?
3. Should passive dead-segment removal remain duplicated here and in `RemoveUnusedModuleElements`, or should Starshine centralize that responsibility?
4. Does Starshine need an explicit pass option for `zero_filled_memory`, or should it initially assume false for imported memory?
5. Do we want byte-for-byte Binaryen parity first, including the current coarse active threshold of `8`, before any local tuning?

## Bottom Line

`MemoryPacking` is a deceptively tricky pass.

At a glance it looks like "remove zeros from data segments". In reality it is a semantic rewrite pass over:

1. active startup memory initialization,
2. passive segment runtime consumers,
3. trap preservation,
4. GC data consumers,
5. data-segment topology and indexing.

For Starshine specifically, the biggest additional burden compared to Binaryen is the index-based segment model. A faithful port will need not just Binaryen's split-and-rewrite logic, but also a robust `DataIdx` remapping story across `memory.init`, `data.drop`, `array.new_data`, `array.init_data`, and `DataCntSec`.
