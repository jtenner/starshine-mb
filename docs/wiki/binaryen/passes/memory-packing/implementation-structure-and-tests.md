---
kind: concept
status: supported
last_reviewed: 2026-04-21
sources:
  - ../../../raw/research/0137-2026-04-20-memory-packing-binaryen-research.md
  - ../../../raw/research/0204-2026-04-21-memory-packing-source-confirmation-followup.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./segment-op-rewrites-and-traps.md
  - ./wat-shapes.md
  - ./parity.md
  - ../../no-dwarf-default-optimize-path.md
---

# `memory-packing`: implementation structure and tests

This page is the compact source-confirmed map for how Binaryen `version_129` actually implements `memory-packing` and where the shipped tests pin that behavior down.

## Why this page exists

The rest of the folder already explained the pass well, but it still lacked one page answering four recurring implementation questions in one place:

- which official file actually owns the pass,
- what the real phase split is,
- which helpers matter to each phase,
- and which lit files prove which parts of the contract.

That gap matters because `memory-packing` is easy to mis-teach as a one-loop data-segment splitter.
The real Binaryen pass is a small module pipeline.

## Official owner files

## `src/passes/MemoryPacking.cpp`

This is the real owner file.
It contains essentially the whole public contract:

- whole-module legality checks,
- early segment-op simplification,
- referrer discovery,
- dead passive-segment cleanup,
- per-segment split legality,
- profitability and range building,
- split-segment emission,
- replacement planning for passive users,
- lazy drop-state-global creation,
- and final function-code replacement.

If future docs disagree with this file, prefer the file.

## `src/passes/pass.cpp`

This file proves the public-pass identity and scheduler placement.

It shows that:

- the public pass name is `memory-packing`,
- the public description is “packs memory into separate segments, skipping zeros,”
- and the default no-DWARF optimize path schedules it as an early module pre-pass before `once-reduction`.

That scheduler fact is part of the meaning of the pass, because later module passes consume the already-rewritten segment layout.

## Implementation phases in `MemoryPacking.cpp`

## Phase 0: whole-module legality with `canOptimize(...)`

This is the first real gate.
The pass refuses to optimize when the module layout is too hard or too dangerous to reason about globally.

Important source-backed blockers include:

- zero memories,
- multiple memories,
- imported memory without `zeroFilledMemory`,
- multiple active segments with dynamic offsets,
- overlapping active segments.

Beginner takeaway:

- Binaryen proves the module shape first; it does **not** start from individual segments.

## Phase 1: early segment-op cleanup with `optimizeSegmentOps(...)`

Before any splitting, Binaryen rewrites active-segment users that can be simplified immediately.

This phase owns behavior like:

- active `data.drop -> nop`,
- active `memory.init` that must trap,
- active zero-size `memory.init` that still needs explicit bounds behavior,
- function refinalization after those instruction rewrites.

This is why `memory-packing` is partly an instruction-rewrite pass, not just a bytes/layout pass.

## Phase 2: referrer discovery with `getSegmentReferrers(...)`

Binaryen next discovers every instruction that refers to each data segment.

The source-backed important detail is that it uses a generic expression visitor plus field delegation, so the pass can see more than just the obvious pair:

- `memory.init`
- `data.drop`
- `array.new_data`
- `array.init_data`

That broader discovery is why the pass can conservatively refuse GC-sensitive splits instead of silently miscompiling them.

## Phase 3: dead passive-segment cleanup with `dropUnusedSegments(...)`

This phase removes passive segments that are referenced only by `data.drop` and turns those now-pointless `data.drop`s into `nop`.

This is a real owned piece of the pass contract.
It is not just incidental cleanup.

## Phase 4: per-segment legality with `canSplit(...)`

Even after the whole-module gate passes, a specific segment may still be unsplittable.

Important source-backed blockers include:

- names beginning with `__llvm`,
- empty segments,
- passive `memory.init` users with nonconstant offset or size,
- `array.new_data` / `array.init_data` users,
- active segments with nonconstant offset.

Beginner takeaway:

- module legality and segment legality are separate questions.

## Phase 5: range and profitability analysis with `calculateRanges(...)`

This phase computes the split plan itself.
It is where Binaryen:

- builds alternating zero and nonzero ranges,
- decides whether startup trap behavior must be preserved,
- uses different profitability thresholds for active versus passive segments,
- treats leading/trailing passive zeroes differently from interior zeroes,
- merges back across too-small zero runs,
- and forces the top byte to remain when trap preservation requires it.

That last rule is one of the easiest facts to forget:

- sometimes a kept byte matters because its **write effect** matters, not because its value matters.

## Phase 6: emitting split segments with `createSplitSegments(...)`

Once ranges are finalized, Binaryen emits only the surviving nonzero spans as actual data segments.

Important source-backed details:

- active split offsets are shifted by the kept-range start,
- passive segments stay passive,
- the first kept split may reuse the original name,
- later splits get suffixed names,
- and the pass stops splitting if continuing would exceed `WebLimitations::MaxDataSegments`.

So data-segment-count limits are a real validity boundary.

## Phase 7: passive replacement planning with `createReplacements(...)`

This is the heart of the passive story.

The pass plans replacement bodies for the original unsplit segment users.
Those plans can contain:

- `memory.init`,
- `memory.fill`,
- `data.drop`,
- temp locals when one destination expression must be reused,
- and optional explicit dropped-segment checks using a synthetic mutable global.

Beginner takeaway:

- splitting a passive segment is only legal because Binaryen also rewrites the users.

## Phase 8: applying those plans with `replaceSegmentOps(...)`

Finally, Binaryen walks function code again and substitutes the planned replacement expressions into the real bodies.

This is the last phase that makes the earlier planning observable in module code.

## Important helper utilities and what they prove

## `DisjointSpans`

Used to prove active-segment non-overlap during the whole-module legality phase.

## `ModuleUtils::ParallelFunctionAnalysis`

Used for function-parallel discovery work like segment-op cleanup and user collection.
This is one reason the pass stays a module pass while still using function-parallel subphases.

## `UnifiedExpressionVisitor`

Used in referrer discovery so the pass can notice all segment-using instruction fields, not just hand-coded `memory.init` / `data.drop` cases.

## `Builder`

Used to create the replacement expressions: `memory.fill`, explicit checks, sequences, globals, locals, and `nop` scaffolding.

## `ExpressionManipulator::nop(...)`

Used when dead segment users become explicit `nop`s rather than disappearing in-place.

## `ReFinalize`

Used after early segment-op rewrites that change instruction/type structure.
That proves `memory-packing` can change more than just raw segment metadata.

## `Names::getValidGlobalName(...)`

Used to synthesize a stable nonconflicting drop-state global name only when the transformed module actually needs one.

## `std::ckd_add`

Used in the range/trap/high-address logic so size and offset arithmetic stays overflow-safe.
This matters especially in the memory64/high-bit corner cases.

## `WebLimitations::MaxDataSegments`

Used to keep split-segment emission valid for the output module.

## Shipped lit tests and what each one proves

## `memory-packing_all-features.wast`

This is the broad behavior file.
It exercises:

- active segment splitting,
- passive segment splitting,
- profitability boundaries,
- replacement of `memory.init` and `data.drop`,
- temp-local destination reuse,
- drop-state-global-triggering families,
- and general all-features compatibility.

## `memory-packing_traps.wast`

This file proves the trap-preservation side of the contract, including:

- active startup-trap preservation,
- zero-size `memory.init` subtleties,
- and the interaction with `trapsNeverHappen` assumptions.

## `memory-packing_zero-filled-memory.wast`

This file proves the imported-memory gate in memory32 mode:

- imported memory is only optimizable when the pass is told it starts zero-filled.

## `memory-packing_zero-filled-memory64.wast`

This is the same imported-memory story, but under memory64.
It proves the gate is not accidentally i32-only.

## `memory-packing_memory64-high-addr.wast`

This file exists because some offsets/immediates need unsigned high-bit handling.
It proves the pass must not accidentally reinterpret large unsigned positions as negative signed values.

## `memory-packing-gc.wast`

This file proves the current GC boundary:

- data segments used by `array.new_data` / `array.init_data` are discovered,
- but that discovery currently feeds conservative no-split behavior rather than a full rewrite.

## What this page changes in the dossier

This page closes one concrete gap in the living folder:

- there is now a compact source-confirmed implementation/test map for `memory-packing`.

That means future campaign threads should not treat “the folder still needs a page explaining which official file/test owns which part of the pass” as an open default fallback.

## Bottom line

Binaryen `memory-packing` in `version_129` is not one optimization loop.
It is a small module pipeline:

1. prove the module is safe to optimize,
2. simplify active-segment ops early,
3. discover every segment user,
4. delete trivially dead passive baggage,
5. decide which segments may split,
6. decide which ranges are worth keeping,
7. emit valid split segments,
8. plan passive user rewrites,
9. apply those rewrites to function code.

That phase structure is the most important thing this page pins down.
