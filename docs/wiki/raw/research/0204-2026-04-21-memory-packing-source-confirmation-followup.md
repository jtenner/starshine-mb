# Binaryen `memory-packing` source-confirmation follow-up (`version_129`)

Date: 2026-04-21
Author: OpenAI Codex

## Why this follow-up exists

The existing `docs/wiki/binaryen/passes/memory-packing/` dossier was already useful, but it still lacked one compact source-confirmed page that mapped the real owner files, helper utilities, main algorithm phases, and shipped tests for Binaryen `version_129`.

That was a real gap for future Starshine work because `memory-packing` is easy to remember as “delete zero bytes from active segments,” while the actual Binaryen pass is a coordinated module rewrite over:

- whole-module legality gating,
- early active-segment op simplification,
- segment-referrer discovery,
- dead passive-segment cleanup,
- per-segment split legality and profitability,
- split-segment emission under segment-count limits,
- passive `memory.init` / `data.drop` replacement planning,
- lazy drop-state-global creation,
- and final function-parallel application of the replacement plans.

So this follow-up closes the specific missing piece:

- a source-confirmed implementation/test map for the real `version_129` pass structure.

## Scope and inputs

Re-read the repo maintenance docs first:

- `docs/README.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
- `agent-todo.md`

Re-read the existing living dossier:

- `docs/wiki/binaryen/passes/memory-packing/index.md`
- `docs/wiki/binaryen/passes/memory-packing/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/memory-packing/segment-op-rewrites-and-traps.md`
- `docs/wiki/binaryen/passes/memory-packing/wat-shapes.md`
- `docs/wiki/binaryen/passes/memory-packing/parity.md`

Official Binaryen sources reviewed:

- `version_129` `src/passes/MemoryPacking.cpp`
- `version_129` `src/passes/pass.cpp`
- `version_129` lit files:
  - `test/lit/passes/memory-packing_all-features.wast`
  - `test/lit/passes/memory-packing_traps.wast`
  - `test/lit/passes/memory-packing_zero-filled-memory.wast`
  - `test/lit/passes/memory-packing_zero-filled-memory64.wast`
  - `test/lit/passes/memory-packing_memory64-high-addr.wast`
  - `test/lit/passes/memory-packing-gc.wast`
- current `main` `src/passes/MemoryPacking.cpp`
- current `main` lit files above for drift checking

## Tracker / backlog check

`agent-todo.md` still has no dedicated `memory-packing` implementation slice today.

The only visible `MP` references in the current file are the high-level ordered-path mnemonics like:

- `DFE -> RUME -> MP -> OR -> GR -> ...`

So there is still no dedicated repo backlog slice that decomposes `memory-packing` the way some other pass folders now do.

That absence is worth recording explicitly because it makes the living dossier more important as the durable planning surface.

## Main source-confirmed findings

## 1. `memory-packing` is one file, but not one idea

`MemoryPacking.cpp` owns almost the whole public contract.

The main implementation split in `version_129` is:

1. `canOptimize(...)`
   - whole-module legality gate
2. `optimizeSegmentOps(...)`
   - early active-`memory.init` / active-`data.drop` cleanup
3. `getSegmentReferrers(...)`
   - whole-module discovery of every segment-using instruction field
4. `dropUnusedSegments(...)`
   - passive segments referenced only by `data.drop` are removed
5. `canSplit(...)`
   - per-segment legality gate
6. `calculateRanges(...)`
   - zero/nonzero ranges, profitability, trap-preserving tail retention
7. `createSplitSegments(...)`
   - emit surviving nonzero split segments with names/offsets/limits handled
8. `createReplacements(...)`
   - plan rewritten `memory.init` / `data.drop` bodies, including temp locals and optional drop-state globals
9. `replaceSegmentOps(...)`
   - apply those plans in function code

That means the real teaching structure is phase-based, not “active segments first, passive segments second” alone.

## 2. The official legality story begins before any segment is inspected

`canOptimize(...)` is not a tiny preflight check.
It is the semantic boundary that makes the rest of the pass legal.

The real early no-go cases include:

- zero or multiple memories,
- imported memory without `zeroFilledMemory`,
- multiple active segments when some active offset is nonconstant,
- overlapping active segments.

That matters because many later range decisions assume the module’s active-memory startup layout is globally predictable.

## 3. Active `memory.init` / `data.drop` simplification is a real owned phase

The pass does not go straight from bytes to split segments.

Instead it first runs `optimizeSegmentOps(...)`, which source-confirms these points:

- active `data.drop` becomes `nop`,
- active `memory.init` may become explicit dropped operands plus `unreachable`,
- zero-length `memory.init` is not dead by default because destination-bounds effects still matter,
- functions touched by those rewrites can need `ReFinalize`.

That is a major implementation detail the earlier folder explained conceptually, but did not yet pin to a dedicated owner-phase map.

## 4. Segment-user discovery is broader than just `memory.init` and `data.drop`

`getSegmentReferrers(...)` walks code using a generic `UnifiedExpressionVisitor` plus generated field delegation.

So Binaryen can discover users such as:

- `memory.init`
- `data.drop`
- `array.new_data`
- `array.init_data`

That matters because current `version_129` does **not** rewrite the GC array-data users here.
Instead, their presence is part of the reason `canSplit(...)` can reject a segment.

## 5. Dead passive-segment cleanup is part of `memory-packing`

`dropUnusedSegments(...)` is a real phase, not an incidental side effect.

Its source-confirmed rule is:

- keep active segments,
- keep passive segments only when some referrer does more than just `data.drop`,
- otherwise delete the passive segment and turn the dead `data.drop` users into `nop`.

So upstream `memory-packing` already owns a narrow passive dead-segment cleanup responsibility.

## 6. Split legality and range profitability are distinct phases

The source makes a useful teaching split that the older folder did not yet name explicitly enough:

- `canSplit(...)` answers **is rewriting this segment even legal?**
- `calculateRanges(...)` answers **if legal, which zero runs are worth splitting out?**

Key `canSplit(...)` blockers include:

- `__llvm*` segment names,
- empty segments,
- passive `memory.init` users with nonconstant offset or size,
- GC `array.new_data` / `array.init_data` users,
- active segments with nonconstant offset.

Key `calculateRanges(...)` work includes:

- building alternating zero/nonzero spans,
- deciding whether trap preservation is needed,
- different active vs passive profitability thresholds,
- separate edge-zero handling for passive segments,
- merging back across too-small zero runs,
- and forcing the top byte to remain when startup trap behavior must survive.

## 7. Split-segment emission is validity-aware, not just profitable

`createSplitSegments(...)` does more than create a few renamed segments.

The important source-confirmed constraints are:

- active split ranges get offset-shifted,
- passive split ranges remain passive,
- first kept range can reuse the original name,
- later ranges use suffixed names,
- and if continuing would exceed `WebLimitations::MaxDataSegments`, Binaryen stops splitting and merges the rest back together.

So segment-count limits are part of the correctness contract, not merely a size heuristic.

## 8. Passive replacement planning is the hardest real phase

`createReplacements(...)` is where the passive-segment story becomes concrete.

The source confirms that Binaryen plans replacement bodies that can mix:

- `memory.init`
- `memory.fill`
- `data.drop`
- temp locals for repeated dynamic destinations
- optional explicit dropped-segment checks via synthetic globals

The most important non-obvious rule is still:

- if a rewritten sequence begins with `memory.fill`, Binaryen may need an explicit dropped-segment check because `memory.fill` does not carry `memory.init`’s “segment already dropped” trap semantics.

## 9. The drop-state global is lazy and demand-driven

The source confirms that the synthetic mutable drop-state global is not unconditional module clutter.

Binaryen creates it only when some concrete passive replacement actually needs it.

That small detail is part of the real size/perf contract, and it is easy to miss when reading only the broad conceptual docs.

## 10. The official tests divide the pass into six real behavior clusters

The shipped lit files are not redundant.
They encode six distinct teaching surfaces:

- `memory-packing_all-features.wast`
  - broad positives, profitability, active/passive splitting, drop-state behavior
- `memory-packing_traps.wast`
  - startup/runtime trap preservation and TNH boundaries
- `memory-packing_zero-filled-memory.wast`
  - imported-memory zero-fill gate in memory32 mode
- `memory-packing_zero-filled-memory64.wast`
  - the same imported-memory story under memory64
- `memory-packing_memory64-high-addr.wast`
  - unsigned high-bit offset/immediate handling
- `memory-packing-gc.wast`
  - current GC user conservatism (`array.new_data` / `array.init_data` no-split boundary)

That makes the official test surface much richer than a single “split zero runs” summary.

## 11. Current `main` still matches the `version_129` contract

The follow-up drift check found no semantic change on the reviewed official surfaces.

Current durable answer:

- current `main` `MemoryPacking.cpp` still matches `version_129` semantically,
- the audited lit files still match too,
- so `version_129` remains a safe source oracle for this dossier.

## What changed in the living wiki

This follow-up should land as:

- a new raw research note,
- a new living page `docs/wiki/binaryen/passes/memory-packing/implementation-structure-and-tests.md`,
- and refreshes to the existing landing/strategy/support pages so the folder explicitly records that the former implementation/test-map gap is now closed.

## Durable conclusions for future Starshine work

If Starshine grows toward fuller Binaryen parity here, the most important things to preserve are:

- treat `memory-packing` as a multi-phase module pass, not as one byte-trimming helper,
- keep whole-module legality separate from per-segment legality,
- keep early active-segment op simplification separate from later split planning,
- keep GC array-data users as a real current boundary unless a full rewrite story is added,
- keep passive replacement planning explicit about temp locals and lazy drop-state globals,
- keep startup-trap preservation, dropped-segment trapping, imported zero-filled memory, memory64 high-bit handling, and data-segment-count limits as first-class correctness rules.

## Sources

- Repo docs and tracker pages listed in the scope section above.
- Official Binaryen `version_129` sources:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/MemoryPacking.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/memory-packing_all-features.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/memory-packing_traps.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/memory-packing_zero-filled-memory.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/memory-packing_zero-filled-memory64.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/memory-packing_memory64-high-addr.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/memory-packing-gc.wast>
- Drift-check surfaces:
  - <https://github.com/WebAssembly/binaryen/blob/main/src/passes/MemoryPacking.cpp>
  - <https://github.com/WebAssembly/binaryen/tree/main/test/lit/passes>
