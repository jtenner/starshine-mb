---
kind: concept
status: working
last_reviewed: 2026-04-20
sources:
  - ../../../raw/research/0137-2026-04-20-memory-packing-binaryen-research.md
  - ../../../../../src/passes/memory_packing.mbt
  - ../../../../../src/passes/memory_packing_test.mbt
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/registry_test.mbt
  - ../../../../../agent-todo.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./segment-op-rewrites-and-traps.md
  - ./wat-shapes.md
  - ./parity.md
---

# Current Starshine `memory-packing` strategy

This page is the local “what is actually implemented today?” companion to the upstream Binaryen strategy page.

## Short version

Current Starshine `src/passes/memory_packing.mbt` follows the same **core goal** as upstream Binaryen:

- shrink zero-heavy data-segment layout without changing memory semantics

But it is not a literal source port of Binaryen `MemoryPacking.cpp`.

The local pass is much narrower, more direct, and focused almost entirely on the easy active-segment subset.

## Current rule about the filename

Despite the folder schema name `starshine-hot-ir-strategy.md`, this pass does **not** currently have a HOT-IR implementation.
It is intentionally a module pass.

That is the right shape for this pass because even the narrow local implementation still needs whole-module access to:

- memories
- data segments
- overlap checks
- data-count section updates

## What current Starshine already models well

The local pass already covers these useful active-segment behaviors:

- one-memory-only legality gating
- active segment byte scanning into zero and nonzero ranges
- a simple merge threshold of `8`
- leading, trailing, and middle active zero-run trimming
- constant i32 and i64 active offsets
- startup-trap preservation by keeping the topmost byte
- overlap bailout for active segments
- data-count section recomputation when the number of data segments changes

The focused tests in `src/passes/memory_packing_test.mbt` lock in three core families:

- profitable active zero-range splitting
- trapping active-segment top-byte preservation
- overlap bailout

That is already enough to explain why the saved generated-artifact slot can be green.

## What local Starshine does differently from Binaryen

## 1. The local pass only optimizes active segments

This is the biggest difference.

Current Starshine rewrites:

- active segments only

It leaves:

- passive segments completely untouched

That means it does **not** currently model the main upstream passive-segment story:

- `memory.init` rewriting
- `memory.fill` insertion
- `data.drop` expansion
- drop-state globals

## 2. Imported memory is a hard local bailout

Upstream Binaryen can optimize imported memory when the pass option says imported memory is zero-filled.

Current Starshine instead bails out whenever there is any imported memory:

- `mp_imported_mem_count(mod_) != 0` => `false`

So the local implementation is stricter and smaller here.

## 3. No segment-op rewrite pass exists locally yet

There is no local equivalent of upstream `optimizeSegmentOps(...)` today.

That means local Starshine does **not** currently simplify:

- active `memory.init` into explicit trap/bounds-check forms
- active `data.drop` into `nop`

The local implementation only changes the segment list itself.

## 4. No referrer collection or passive dead-segment cleanup exists locally yet

Upstream Binaryen scans the whole module for data-segment referrers and can remove passive segments that are only dropped.

Current Starshine does not yet do that.
It leaves passive segments and their users in place.

So there is no local equivalent yet of:

- `getSegmentReferrers(...)`
- `dropUnusedSegments(...)`

## 5. No GC-aware conservative boundary is modeled locally yet

Upstream `version_129` sees `array.new_data` and `array.init_data` users and refuses to split those segments.

Current Starshine does not scan for those users at all because it never reaches the passive-segment / referrer-rewrite half of the problem.

That means the local implementation is not yet making the same GC-aware decision.
It is simply operating on a smaller problem.

## 6. The local offset story is simpler

Current Starshine parses only these active offset forms:

- exact `i32.const`
- exact `i64.const`

That is enough for the current active subset, but it is much smaller than upstream Binaryen's broader module-level reasoning about what can or cannot be split.

## 7. No segment-count limiting exists locally yet

Binaryen stops splitting further when it would exceed `WebLimitations::MaxDataSegments`.

Current Starshine does not model that output-limit guard today.
So the local pass is currently relying on the narrow tested subset rather than the full upstream output-validity story.

## Important current gaps versus upstream Binaryen

## 1. No passive-segment rewrite engine

This is the headline gap.
Current Starshine has no local equivalent of upstream `createReplacements(...)` or `replaceSegmentOps(...)`.

That means the local pass does **not** yet preserve the official passive families involving:

- `memory.init`
- `memory.fill`
- `data.drop`
- dropped-segment trap checks
- destination temp locals

## 2. No `zeroFilledMemory` imported-memory mode

A future parity port must decide whether to model Binaryen's explicit option or to keep a documented stricter local policy.
Right now the local policy is just:

- imported memory => no optimization

## 3. No upstream-style active-op simplification

The current local file does not yet cover the source-backed active `memory.init` rewrites that Binaryen performs before splitting.

That means the local pass is semantically smaller even for active-segment-heavy modules.

## 4. No GC segment-user boundary modeling

Because the local pass does not collect referrers, it does not yet encode the upstream rule:

- do not split segments used by `array.new_data` / `array.init_data`

A future port must make that conservative boundary explicit.

## 5. No current equivalent of `MaxDataSegments` limiting

This is a correctness and validity issue, not just a perf or heuristic issue.
If local splitting ever grows beyond the narrow tested subset, it will need an honest output-segment-count guard.

## Current scheduler story in-tree

The local preset and registry surfaces show that Starshine already schedules `memory-packing` as an explicit module pass:

- it is registered in `src/passes/optimize.mbt`
- it is dispatched through `run_hot_pipeline_apply_module_pass(...)` in `src/passes/pass_manager.mbt`
- the optimize and shrink presets place it before `once-reduction` and `global-refining`

So the local scheduler slot is already aligned with upstream at a coarse level.
The remaining gaps are about surface area, not the existence of the slot itself.

## Current evidence and honest status

## The saved generated-artifact slot is green

The saved `-O4z` audit reports slot `3` as:

- canonical wasm equal: `yes`
- normalized WAT equal: `yes`

That is good evidence that the current local active-segment subset is already useful.

## But it is not evidence of full upstream parity

The local pass still lacks the main upstream passive-segment machinery.
So the honest reading is:

- current Starshine matches the saved artifact's exercised subset,
- but does not yet cover the full official `MemoryPacking.cpp` contract.

## The current tests are still very small

`src/passes/memory_packing_test.mbt` currently covers only three focused shapes.
That is enough for the landed subset, but still much smaller than upstream Binaryen's dedicated lit surface.

## Best current mental model

Upstream Binaryen tells us what `memory-packing` **means** semantically:

- a module-level data-segment plus segment-op packing pass with trap preservation

Current Starshine tells us what a smaller local implementation already **gets right** today:

- active constant-offset segment packing with overlap and trap guards

When those two stories differ, treat Binaryen `version_129` as the semantic oracle and treat the current Starshine file as the narrower local strategy that still needs to grow.

## What a future local refactor must preserve

If Starshine rewrites this pass again, keep these lessons explicit:

- keep the pass module-scoped
- preserve the overlap and dynamic-layout legality gate
- preserve top-byte trap retention for active segments
- add passive-segment rewriting instead of pretending active-segment splitting is the whole pass
- add imported-memory `zeroFilledMemory` semantics honestly or document a stricter divergence
- add GC data-referrer conservatism before widening the split surface
- add output-segment-count guarding if broader splitting is implemented
- keep the saved artifact green while expanding surface area
