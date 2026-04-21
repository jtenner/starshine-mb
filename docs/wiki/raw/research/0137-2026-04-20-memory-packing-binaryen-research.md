# Memory-Packing Binaryen Research

## Scope

- Deepen the existing `memory-packing` landing page into a real Binaryen dossier.
- Use Binaryen `version_129` as the primary semantic oracle.
- Explain the actual implementation structure in beginner-friendly language.
- Record the most important correction to the old local summary: upstream `memory-packing` is not only an active-segment splitter.
- Keep the result useful for future Starshine parity work in the early module-prepass cluster.

## Why this pass was the right target now

- The updated tracker named `memory-packing` as the strongest remaining implemented landing-page target after `pick-load-signs` was deepened.
- It is already implemented locally, but the living wiki surface was still just a short landing page.
- In the canonical no-DWARF path it sits at the front of the nontrivial memory/layout cleanup cluster:
  - `duplicate-function-elimination -> remove-unused-module-elements -> memory-packing -> once-reduction -> global-refining -> ...`
- The saved generated-artifact `-O4z` audit already shows `memory-packing` as an implemented, successful slot rather than an open corruption family:
  - slot `3`
  - canonical wasm equal: `yes`
  - normalized WAT equal: `yes`
  - Starshine wall/runtime: `650.310 ms`
  - Binaryen wall/runtime: `225.872 ms`
  - Starshine in-pass time: `12.684 ms`
  - Binaryen in-pass time: `31.292 ms`
- That makes this a high-value documentation target: the pass is semantically important, early in the scheduler, and green on the saved artifact, but its real upstream scope is much larger than the old stub implied.

## Local source material audited first

Repo docs and trackers:

- `docs/README.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
- `agent-todo.md`
- existing living page under `docs/wiki/binaryen/passes/memory-packing/`
- saved generated-artifact audit:
  - `.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/summary.json`
  - `.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/summary.md`
  - `.artifacts/o4z-wasm-opt-debug.log`

Current in-tree Starshine implementation surfaces:

- `src/passes/memory_packing.mbt`
- `src/passes/memory_packing_test.mbt`
- `src/passes/pass_manager.mbt`
- `src/passes/optimize.mbt`
- `src/passes/registry_test.mbt`
- `src/cmd/cmd_wbtest.mbt`

## Important local backlog note

- `agent-todo.md` currently has **no dedicated `MP` slice**.
- The relevant local backlog surface is indirect:
  - the canonical no-DWARF pre-pass order entry `DFE -> RUME -> MP -> OR -> GR -> GSI`
  - the shared post-RUME / pre-GSI prefix notes
  - the in-tree implementation and tests for the already-landed module pass

That is itself a useful durable fact:

- `memory-packing` is already far enough along locally that its remaining work is not tracked as a standalone emergency implementation slice, but the wiki still needed a much better explanation of the upstream contract.

## Official upstream source-of-truth files

Primary `version_129` sources:

- `src/passes/MemoryPacking.cpp`
- `src/passes/pass.cpp`

Important helper surfaces visible directly in the implementation:

- `support/space.h`
- `support/stdckdint.h`
- `ir/manipulation.h`
- `ir/module-utils.h`
- `ir/names.h`
- `wasm-builder.h`
- `wasm-limits.h`

Dedicated official test surfaces:

- `test/lit/passes/memory-packing_all-features.wast`
- `test/lit/passes/memory-packing_traps.wast`
- `test/lit/passes/memory-packing_zero-filled-memory.wast`
- `test/lit/passes/memory-packing_zero-filled-memory64.wast`
- `test/lit/passes/memory-packing_memory64-high-addr.wast`
- `test/lit/passes/memory-packing-gc.wast`

Those test files matter a lot here because the implementation is more semantically subtle than the pass name suggests:

- active versus passive segments behave differently
- zero runs on the edges and in the middle have different economics
- preserving startup/runtime traps matters
- imported memory depends on the `zeroFilledMemory` option
- GC data-segment referrers affect whether splitting is legal at all
- memory64 high-bit constants must be treated as unsigned

## Beginner summary

Binaryen `memory-packing` is a module pass that tries to shrink data-segment bytes by removing large zero runs.

But the real story is two-part:

1. **Active segments**
   - memory starts zero-initialized,
   - so large zero runs can often just be omitted,
   - as long as startup trap behavior is preserved.

2. **Passive segments**
   - later `memory.init` still needs to behave exactly the same,
   - so Binaryen rewrites segment-using instructions into a mix of:
     - smaller `memory.init`s for nonzero subranges
     - `memory.fill`s for zero subranges
     - updated `data.drop`s
     - and, when necessary, explicit drop-state globals used only to preserve trapping behavior.

That means a better beginner summary is:

- `memory-packing` is a semantics-preserving **segment plus segment-op rewrite pass** that shrinks zero-heavy data while keeping startup and runtime memory semantics intact.

## Biggest beginner-facing correction

The easiest wrong mental model is:

- `memory-packing` just splits active data segments around zeroes

That is only the smallest and easiest part of the pass.

A more accurate model for Binaryen `version_129` is:

- a module pass that
  - checks whether segment layout is safe to optimize at all,
  - optionally simplifies impossible or trivial active `memory.init` / `data.drop` sequences first,
  - discovers all segment referrers,
  - drops unused passive segments,
  - computes profitable zero/nonzero ranges,
  - creates replacement split segments,
  - rewrites passive `memory.init` / `data.drop` users,
  - preserves traps with explicit top-byte retention or lazily-created drop-state globals,
  - and respects GC, imported-memory, memory64, and segment-count boundaries.

That is the most important durable correction from this research pass.

## Scheduler placement

## Top-level no-DWARF `-O` / `-Os`

From `pass.cpp` and the repo's canonical pathway page:

- `memory-packing` is a **global pre-pass**.
- It runs after `remove-unused-module-elements` and before `once-reduction`.
- Unlike `once-reduction` and `global-refining`, the default global pre-pass builder adds it **without** an `optimizeLevel >= 2` guard:
  - `addIfNoDWARFIssues("memory-packing")`

That placement matters because:

- it is allowed to change raw segment layout before later whole-module reasoning
- it can expose smaller module state to later pre-passes
- it deliberately happens before the GC/global-refinement cluster

## Nested-rerun story

Unlike many hot passes, `memory-packing` is **not** part of the function rerun helper in `opt-utils.h`.
It is a module pre-pass.

The saved generated-artifact Binaryen debug log matches that expectation:

- `.artifacts/o4z-wasm-opt-debug.log` contains a single visible top-level `running pass: memory-packing` line

So the durable scheduler rule is:

- `memory-packing` matters as an early module layout rewrite,
- not as a repeatedly rerun hot cleanup pass.

## Actual implementation structure in `MemoryPacking.cpp`

The file is moderately sized, but its whole phase structure matters.

## 1. The pass type

Upstream defines:

- `struct MemoryPacking : public Pass`

Important consequences:

- this is a module pass, not a per-function AST peephole
- it needs whole-module data-segment and memory state
- it does **not** rely on HOT-style local reasoning
- it explicitly overrides `requiresNonNullableLocalFixups()` to return `false`
  - because it only touches linear-memory segment logic, not reference locals

## 2. `run(Module* module)` is the real phase scheduler

The top-level algorithm is:

1. bail out if `canOptimize(...)` says the module layout is unsafe
2. detect whether the module can even have data-segment referrers worth rewriting
   - `bulk memory` or `GC`
3. if so:
   - `optimizeSegmentOps(...)`
   - `getSegmentReferrers(...)`
   - `dropUnusedSegments(...)`
4. for each segment:
   - decide if it can be split
   - calculate zero/nonzero ranges
   - create replacement segments
   - create replacement code for referrers
5. swap in the new segment list
6. update the segment map
7. replace referrer instructions if needed

That makes the real pass structure much clearer:

- **analyze safety first**
- **rewrite easy segment ops first**
- **collect referrers**
- **split segments**
- **rewrite users**

## 3. `canOptimize(...)` is a whole-module legality gate

This is one of the most important functions in the file.
It refuses to optimize when:

- there is no memory
- there is more than one memory
- the only memory is imported and the pass option `zeroFilledMemory` is not set
- there are multiple active segments and some active offset is nonconstant
- active segments overlap (the trampling problem)

The trampling logic is beginner-important.
Consider:

```wat
(data (i32.const 100) "a")
(data (i32.const 100) "\00")
```

It would be wrong to drop the zero byte from the second segment just because it looks redundant in isolation.
It has a visible effect because active segments initialize memory in order.

So the durable rule is:

- `memory-packing` is not just local range trimming; it is guarded by a module-wide layout proof.

## 4. `optimizeSegmentOps(...)` runs before normal referrer collection

This nested helper pass simplifies some segment ops immediately.

Most important cases:

- active `memory.init` with impossible constant offset/size becomes explicit `drop`s plus `unreachable`
- active zero-size `memory.init` becomes an out-of-bounds check on `dest` only
- active nontrapping `memory.init` becomes a compact explicit check
- `data.drop` of active segments becomes `nop`
- refinalization is triggered when the rewrites introduce new unreachable block structure

This phase is easy to miss if you only skim the top-level comments.
But it is a core part of why later replacement logic can make stronger assumptions.

## 5. `getSegmentReferrers(...)` is deliberately broad

Binaryen does not hardcode just `memory.init` and `data.drop` scanning by hand.
Instead it uses a generic expression-field visitor and collects all uses of `DataSegment` names.

Important helper surface:

- `ModuleUtils::ParallelFunctionAnalysis<ReferrersMap>`
- a `UnifiedExpressionVisitor`
- generated delegation over `wasm-delegations-fields.def`

Why that matters:

- the pass is future-proofed against multiple data-segment-carrying instructions
- GC array ops such as `array.new_data` and `array.init_data` are seen here too

Important nuance:

- the pass **tracks** GC data-segment referrers,
- but today it uses them mostly as a reason to avoid splitting rather than as a rewritten replacement surface.

## 6. `dropUnusedSegments(...)` is a real part of the transform

Passive segments with no meaningful users are removed entirely.
More precisely:

- active segments are always considered used
- passive segments are considered used only if they have some referrer that is not just `data.drop`
- passive segments with only `data.drop` users are removed, and those drops become `nop`

That means upstream `memory-packing` already contains a small amount of dead passive-segment cleanup.
It is not purely a split-only pass.

## 7. `canSplit(...)` is the per-segment legality filter

A segment cannot be split when:

- its name starts with `__llvm`
  - downstream coverage tools expect those bytes to stay intact
- it is empty
  - leave trap-sensitive empties for other cleanup passes
- a passive-segment `memory.init` referrer has nonconstant offset or size
- it is referenced by `array.new_data` or `array.init_data`
- it is active and has a nonconstant offset

This is another big beginner correction:

- seeing a zero-heavy segment is not enough
- the pass also asks whether all of that segment's users remain legally rewritable afterward

## 8. `calculateRanges(...)` has the real profitability logic

This function does much more than “find zero runs.”
It does all of these:

1. create initial alternating zero/nonzero ranges
2. decide whether trap behavior must be preserved
3. compute different thresholds for active versus passive segments
4. give edge zeroes a lower threshold for passive segments
5. merge across small zero runs when splitting would not pay off
6. preserve the top byte when trap behavior must survive

### Active threshold

For active segments, `version_129` uses a simple approximate threshold:

- `8` bytes

### Passive threshold

For passive segments, the threshold is estimated from expected replacement overhead:

- base passive-segment metadata cost
- extra `memory.fill`
- extra `memory.init`
- extra `data.drop`

So the pass is doing **economics**, not just semantics.

### Edge zeroes versus interior zeroes

For passive segments, edge zeroes are cheaper to split because they do not necessarily increase the number of split segments and drops in the same way interior zeroes do.

That is why a beginner comparing two similar-looking segments can see different outcomes.

## 9. Trap preservation is a first-class rule

If a segment might trap and `trapsNeverHappen` is **not** set, Binaryen must preserve that effect.

The most striking implementation trick is:

- if the last byte would otherwise be removed as part of a zero range,
- Binaryen keeps exactly that topmost byte as a synthetic nonzero range.

That looks odd, because the byte may literally be zero.
But the pass marks it “nonzero” in range bookkeeping so it survives later output and still triggers the same trap.

That is a great beginner example of the difference between:

- byte-content optimization
- and observable-behavior preservation

## 10. `createSplitSegments(...)` emits only nonzero ranges

Once ranges are final:

- zero ranges are omitted from actual segment output
- nonzero ranges become new split data segments
- named segments get suffixes like `.1`, `.2`, and so on
- active offsets are shifted by the range start
- if the output would exceed `WebLimitations::MaxDataSegments`, Binaryen merges the remaining ranges back together instead of producing an invalid module

That segment-count guard is an important implementation detail that is easy to miss in a prose summary.

## 11. `createReplacements(...)` is where passive-segment semantics are preserved

This is the most important phase for understanding what upstream `memory-packing` really does.

For each `memory.init` referrer, Binaryen may emit:

- one or more `memory.init`s for nonzero subranges
- one or more `memory.fill`s for zero subranges
- a temporary local for nonconstant destinations
- an explicit dropped-state trap check when the first emitted operation is `memory.fill`

### Why the explicit drop-state check exists

`memory.init` implicitly traps if the source segment was already dropped.
But `memory.fill` does not.

So if splitting means a transformed sequence begins with `memory.fill`, Binaryen must add its own explicit check against a drop-state global.

That lazy drop-state global is one of the most important non-obvious parts of the pass.

## 12. `data.drop` replacement is also part of the contract

Once splitting is known, a `data.drop` must update every surviving split passive segment.

Binaryen therefore rewrites one original `data.drop` into:

- an optional `global.set dropState = 1`
- followed by one `data.drop` per surviving nonzero split segment

If no split segments remain, the replacement is just `nop`.

## 13. The pass handles zero-size and out-of-bounds runtime shapes carefully

The dedicated test suite shows several important corner cases that match the implementation:

- zero-length `memory.init`
- constant out-of-bounds offset
- constant out-of-bounds size
- constant offset+size overflow
- unreachable destinations
- memory64 destinations and high-bit i32 immediates that must be interpreted unsigned

That is why the implementation uses:

- `std::ckd_add`
- memory address-type-specific constants
- destination locals created late inside replacement closures

## Important helper utilities and what they are doing

- `DisjointSpans`
  - whole-module overlap detection for active segments
- `std::ckd_add`
  - overflow-safe address math, especially for trap preservation and memory64/high-bit cases
- `Builder`
  - constructs replacement `memory.init`, `memory.fill`, `data.drop`, `if`, `unreachable`, and local temp logic
- `ExpressionManipulator::nop(...)`
  - turns obsolete active `data.drop`s and drop-only passive users into `nop`
- `ModuleUtils::ParallelFunctionAnalysis`
  - parallel referrer collection across all functions
- `Names::getValidGlobalName(...)`
  - creates lazily needed drop-state globals
- `ReFinalize`
  - repairs types when `optimizeSegmentOps(...)` emits explicit trapping blocks
- `WebLimitations::MaxDataSegments`
  - prevents the transform from creating an invalid module

## What the pass does not do

These non-goals are useful to keep explicit:

- no multimemory optimization
- no attempt to handle overlapping active segments safely today
- no splitting of segments referenced by `array.new_data` / `array.init_data`
- no splitting of passive segments whose `memory.init` users have nonconstant offset or size
- no generic runtime symbolic reasoning about segment overlaps
- no nested optimizeAfterInlining-style rerun behavior

## Important WAT / IR shapes this research pass distilled

### Positive families

- active constant-offset segments with large edge or interior zero runs
- passive segments whose users are constant `memory.init` / `data.drop`
- imported memory only when `--zero-filled-memory` is set
- memory64 forms with honest unsigned handling
- dynamic `dest` in `memory.init`, handled by a synthetic temp local

### Negative or bailout families

- overlapping or potentially trampling active segments
- active segments with nonconstant offsets when more than one segment exists
- `__llvm*` named segments
- empty segments
- passive segments with dynamic `memory.init` offset/size
- GC array-data referrers
- multimemory modules

### Easy-to-misunderstand special families

- leading zero ranges in passive segments often require explicit dropped-state checks
- startup-trapping active segments keep only their topmost byte
- zero-size `memory.init` can still trap, so it is not just deleted
- a green saved-artifact slot does not imply the local implementation already covers passive-segment rewriting

## Official test surface audited and why it matters

## `memory-packing_all-features.wast`

This is the broad semantic test file.
It covers:

- active split positives
- threshold-based no-split cases
- passive `memory.init` + `data.drop` rewrites
- drop-state globals
- zero-size and out-of-bounds constant cases
- destination temp locals
- many-range segment-count limiting
- active trampling bailout
- imported memory without `zeroFilledMemory`
- memory64 behavior
- unreachable destinations
- shared memory cases
- array.init_data retention

## `memory-packing_traps.wast`

This isolates the trap-preservation rules:

- startup-trapping active segments must remain trapping
- top-byte preservation
- `-tnh` contrast
- unknown offset conservatism
- unused passive segments being removable

## `memory-packing_zero-filled-memory*.wast`

These show the imported-memory rule explicitly:

- imported memory is only safe to optimize when the pass option guarantees zero-filled initial memory
- both i32 and memory64 variants are covered

## `memory-packing_memory64-high-addr.wast`

This is a very useful specialized test.
It locks in the fact that high-bit i32 immediates used in memory64 contexts must be treated as unsigned quantities, not sign-extended negatives.

## `memory-packing-gc.wast`

This shows the current GC boundary honestly:

- data segments referred to by `array.new_data` or `array.init_data` must not be split away or mis-renumbered

That file is especially important because it proves upstream `memory-packing` is already GC-aware, even though it mostly reacts by conservatively refusing some rewrites.

## Freshness note

A narrow 2026-04-20 direct source comparison found **no semantic post-`version_129` drift** in the real pass surface.

What changed on current `main`:

- two comment typo fixes in `MemoryPacking.cpp`
  - `orginal` -> `original`
  - `canot` -> `cannot`

What did **not** change:

- the actual implementation logic in `MemoryPacking.cpp`
- the dedicated lit files listed above

So the durable rule is:

- treat Binaryen `version_129` as the released oracle for this dossier
- note that current `main` matches it semantically for this pass

## Current Starshine comparison

The current local implementation in `src/passes/memory_packing.mbt` is much narrower than upstream Binaryen.

What local Starshine already does:

- active-segment zero/nonzero range collection
- a simple merge threshold of `8`
- top-byte preservation for startup-trapping active segments
- constant i32 and i64 active offsets
- overlap bailout
- data-count section update after changed segment counts

What local Starshine does **not** currently model:

- passive-segment splitting
- `memory.init` / `data.drop` rewriting
- lazy drop-state globals
- imported-memory optimization via `zeroFilledMemory`
- GC data-segment referrer scanning
- segment renumbering for `array.new_data` / `array.init_data`
- segment-count limiting via `MaxDataSegments`
- the full active-`memory.init` simplification pass

That difference explains an important seeming contradiction:

- the saved generated-artifact slot is green,
- but the local pass still does not cover the full official surface.

The most likely explanation is simply that the saved artifact exercises the active-segment subset that Starshine already handles well.

## What a future Starshine port must preserve

A future stricter-parity Starshine port or refactor must keep these Binaryen-backed rules honest:

- the module-wide safety gate, especially overlap and dynamic-offset bailouts
- the active-versus-passive semantic split
- imported-memory optimization only when zero-filled memory is guaranteed
- active `memory.init` / `data.drop` simplification before later replacement work
- GC array-data referrer conservatism
- threshold-based profitability, including cheaper edge-zero handling for passive segments
- top-byte trap preservation when TNH is not allowed
- lazy drop-state globals only when they are actually needed
- memory64 and high-bit unsigned-immediate correctness
- segment-count limiting to avoid emitting invalid modules

If local code intentionally broadens or narrows any of those rules, keep that as an explicit documented divergence.

## Sources

Local repo sources:

- `docs/README.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
- `agent-todo.md`
- `src/passes/memory_packing.mbt`
- `src/passes/memory_packing_test.mbt`
- `src/passes/pass_manager.mbt`
- `src/passes/optimize.mbt`
- `src/passes/registry_test.mbt`
- `src/cmd/cmd_wbtest.mbt`
- `.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/summary.json`
- `.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/summary.md`
- `.artifacts/o4z-wasm-opt-debug.log`

Official Binaryen sources:

- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/MemoryPacking.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/memory-packing_all-features.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/memory-packing_traps.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/memory-packing_zero-filled-memory.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/memory-packing_zero-filled-memory64.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/memory-packing_memory64-high-addr.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/memory-packing-gc.wast>

Freshness-check surfaces:

- <https://github.com/WebAssembly/binaryen/blob/main/src/passes/MemoryPacking.cpp>
- <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/memory-packing_all-features.wast>
- <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/memory-packing_traps.wast>
- <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/memory-packing_zero-filled-memory.wast>
- <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/memory-packing_zero-filled-memory64.wast>
- <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/memory-packing_memory64-high-addr.wast>
- <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/memory-packing-gc.wast>
