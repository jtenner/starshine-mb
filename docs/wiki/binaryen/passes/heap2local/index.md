---
kind: entity
status: supported
last_reviewed: 2026-10-15
sources:
  - ../../release-horizon-and-oracles.md
  - ../tracker.md
  - ../../../../../src/passes/heap2local.mbt
  - ../../../../../src/passes/heap2local_test.mbt
  - ../../../../../src/passes/heap2local_primary_test.mbt
  - ../../../../../src/passes/optimize_test.mbt
  - ../../../../../src/passes/registry_test.mbt
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../agent-todo.md
  - ../late-pipeline-dispatch.md
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/Heap2Local.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/opt-utils.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/pass.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/type-updating.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/heap2local.wast
  - https://github.com/WebAssembly/binaryen/blob/main/src/passes/Heap2Local.cpp
  - https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp
  - https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/heap2local.wast
related:
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./validation-fixups-and-special-cases.md
  - ./wat-shapes.md
  - ./parity.md
  - ./starshine-hot-ir-strategy.md
  - ../tracker.md
  - ../../no-dwarf-default-optimize-path.md
  - ../heap-store-optimization/index.md
  - ../optimize-casts/index.md
  - ../local-subtyping/index.md
---

# `heap2local`

## October 15, 2026 current verification

The owner-publication and control-ownership repairs pass a fresh10,000-case
aggregate comparison on native `b29aee1d`, with verified Binaryen133 and actual
Node runtime observations. All observations agree; validation, determinism and
codec checks pass. The repaired generator supplies10,000 nonempty GC candidates.
All outputs are smaller in raw and repository-canonical bytes, with structural
differences independently inspected by family. The same build passes11,568
permanent Heap2Local runtime comparisons; the full WasmGC suite passes14,219.

Owner staging adds scalar locals and traffic while removing allocations. Keep
that tradeoff and the bounded execution/shape scope visible. See the
[current generated evidence](fuzzing.md#october-15-current-source-owner-publication-renewal)
for exact identities, raw reports, independent replay and exclusions.

## October 14, 2026 owner publication repair

Two branch-selected allocations can replace the same owner. The old scalar
rewrite published each field while evaluating constructor operands. A later
operand that reads the previous owner's field therefore read the new value.
Original and Binaryen 133 returned `11`/`10`; Starshine returned `200`/`100`.
Validation alone did not detect this value error.

Each replacement producer now has separate staging locals. It evaluates every
operand before it publishes the shared owner fields. Separate producer scratch
also preserves an outer operand across a nested owner update. Constructor
effects and exceptions remain in source order. This adds locals and copies;
runtime and memory costs require measurement before a footprint claim.

An additional reduced test exposed branches to a result-if label that the
variant rewrite removed. Variant admission now retains allocations when a
branch targets one of the control owners or wrappers that scalarization would
remove. Reference-valued branch transfers need a separate scalar payload
representation. Branches to retained operand blocks remain eligible.

Sources: [value regressions](../../../../../src/passes/heap2local_owner_update_test.mbt),
[label regressions](../../../../../src/passes/heap2local_variant_escape_test.mbt),
[command regressions](../../../../../src/cmd/heap2local_owner_update_wbtest.mbt),
[V8 runtime lane](../../../../../scripts/test/heap2local-owner-update-runtime.ts),
and [owner-update generator](../../../../../src/validate/gen_valid_heap2local_owner_updates.mbt).
The current verification above supplies the runtime, WasmGC and10,000-case
v133 results. Earlier historical closure below does not cover these cases.

Generic struct scalarization also transfers fresh wrapper ownership to its
live replacement and retires the unused builder wrapper. Control-label owners
therefore name the retained control node. The [ownership invariant and
straight-line non-null tests](../../../../../src/passes/heap2local_straightline_nonnull_regression_wbtest.mbt)
cover this transfer. A separate combined-pipeline null trap came from
[SimplifyLocals revisiting a moved pending write](../simplify-locals/structure-result-lifting-and-carrier-cleanup.md),
rather than owner-field publication.

The [control ownership regressions](../../../../../src/passes/heap2local_control_owner_regression_wbtest.mbt)
also cover variant publication, variant tees, drop-only owners, and direct
equality, reference-test, descriptor, and bounds-trap replacements. Fresh
wrappers transfer their labels and body storage to the retained node and then
retire. A borrowed control-valued field or array element remains a child of a
new typed wrapper, so another consumer retains the original control's
evaluation behavior. Bare shared HOT controls do not declare a value capture:
the test's original and repaired lowering both emit two marked calls. V8 also
executes both original fixtures as return `42` with two recorded effects.
Both the borrowed control and the wrapper retain distinct owners
and body spans. Non-control forwarding keeps its existing path.
All fourteen ownership tests failed before this repair on owner/span checks.
These failures establish an IR defect; no engine failure was established for
this family. Borrowed controls can add a wrapper to emitted code. Fresh native
size and runtime checks remain pending, and no memory or performance win is
claimed.

Straight-line array replacements use a separate element-local vector for each
allocation epoch. Reads inside the next constructor belong to the previous
epoch because a direct root `local.set` publishes its owner only after all
operands complete. The repeated-allocation fence now permits that boundary
when both adjacent writes are direct root `local.set` allocations; nested and
scratch-tee boundaries keep the existing fence. Constant out-of-bounds accesses
lower to an explicit trap at the access position. An `array.set` value still
executes before the bounds trap. Dynamic indices remain outside this proof.
Array control wrappers use the same ownership transfer as struct wrappers.
Direct array tees also place the initializer before their one consuming scalar
access. Later local reads reuse the initialized fields and do not repeat the
constructor. This fixes a pre-existing wrong result and lost constructor
effects in direct tee reads and stores. The same order keeps all constructor
effects before an intentional bounds trap, with a stored-value effect after
construction and before the trap.
Both new regions retain the original tee/access positions. A fresh initializer
position otherwise makes HOT lowering carry the stored value before the
constructor, despite the region root order. The store-effect regression
confirmed that failure before this position repair.

The [pass regressions](../../../../../src/passes/heap2local_straightline_array_regression_wbtest.mbt)
and [dispatcher regressions](../../../../../src/cmd/heap2local_straightline_array_regression_wbtest.mbt)
require old-value reads, swaps, cycles, packed signed reads, ordered constructor
effects, and the negative-index trap frontier to survive with zero heap
allocation/access operations. Their original failures established the parity
gap before this repair. The direct tee effect tests also failed before the tee
repair in both pass and dispatcher lanes. Focused validation and fresh native replay are pending;
these changes make no new runtime or memory claim.

> **Comparison baseline:** New comparisons require a verified [Binaryen 133](../../release-horizon-and-oracles.md) oracle. Older sources, commands, artifacts, and results retain their original versions.

## September 24, 2026 root-slot lookup measurement

Sequential struct and array epochs formerly located each write and read by
walking the entire HOT root tree. A pass-local NodeId-to-root-slot index now
visits that tree once before candidate discovery; it preserves the first root
slot selected by the old lookup, including nested block and loop bodies. The
[white-box regression](../../../../../src/passes/heap2local_root_slot_wbtest.mbt)
compares both lookups for every node in a structured fixture, and all 33
existing `heap2local_test.mbt` tests pass on wasm-gc.

The [dedicated native benchmark](../../../../../src/passes_perf_long/heap2local_root_slot_perf_test.mbt)
validates a straight-line repeated-struct-owner fixture outside timing and
measures a direct `heap2local` pipeline invocation with final validation
disabled. At 16 allocation/read epochs, mean time fell from `467.67 µs` to
`294.51 µs` (`1.59×`); at 32 epochs, from `1.78 ms` to `381.12 µs` (`4.67×`).
These are synthetic pass-local measurements, not Binaryen timing or broad
workload claims.

## September 2026 runtime repair

Dewdrop's late Heap2Local order exposed a reference field initialized inside
one result block and read outside it. Declaring its scalar replacement as a
non-null local violates Wasm definite initialization even though Starshine's
validator accepted the output. The same hazard applies to array elements and
variant scalar fields.

Scalar reference locals now use nullable storage. Reads of non-null fields use
`ref.as_non_null` to restore the field type, after the allocation's field write.
This preserves scalar replacement and exact-reference type information while
making each local declaration defaultable. Numeric fields are unchanged.

The [native regression](../../../../../src/passes/heap2local_dew_regression_test.mbt)
failed before the repair and passes afterward. All 53 focused Heap2Local tests
pass. The [execution lane](../../../../../scripts/test/heap2local-reference-runtime.ts)
checks struct fields, reference results, and reference array elements after one
and two Heap2Local passes: 30 transformed Node checks pass, with independent
`wasm-tools` validation (0.087 seconds). Run it with an explicit native CLI path.
The broader generated-pass and composition recheck remains part of the active
Dewdrop repair work; previous parity closure did not cover this runtime shape.

## Binaryen v131 status

The representable v131 surface is **closed**. Starshine now handles sequential branch-target struct/array candidates without stale candidate state, the released unreachable-flow array case, nullable GC-supertype owners whose only uses are drops, and direct fresh packed/unpacked struct and array reads. The remaining official `must-optimize-ref-eq` case uses shared reference-valued `acqrel` cmpxchg; Starshine decodes the binary but its validator still rejects reference-valued aggregate atomic RMW/cmpxchg, so that family remains an explicit representation/atomic-semantics blocker rather than a hidden H2L success claim.

## Role

- `heap2local` is an active implemented **hot pass** in Starshine.
- In upstream Binaryen `version_129`, the public `pass.cpp` description is only:
  - `replace GC allocations with locals`

That description is true, but too small.

A better beginner summary is:

- Binaryen finds a freshly created GC object that never escapes the current function,
- proves that every reachable use is exclusive to that exact allocation,
- lowers small fixed-size arrays into synthetic structs first,
- scalarizes the surviving struct fields into locals,
- folds some direct ref operations (`ref.is_null`, `ref.eq`, `ref.test`, `ref.cast`, `ref.get_desc`) using exact knowledge of the allocation,
- and then repairs nullability, expression types, and EH shape so the result still validates.

So this is **not** a generic heap-to-stack pass for all GC traffic.
It is a conservative, shape-driven scalarization pass for nonescaping, exclusive allocations.

## Why this pass matters

- When this thread started, `docs/wiki/binaryen/passes/tracker.md` named `heap2local` as the strongest remaining implemented landing-page target.
- In the canonical no-DWARF `-O` / `-Os` function scheduler, it sits in the middle GC/local cleanup cluster:
  - `... -> remove-unused-brs -> heap2local -> optimize-casts -> local-subtyping -> coalesce-locals -> local-cse -> simplify-locals -> ...`
- That placement is meaningful:
  - earlier cleanup reduces noisy control/local traffic first
  - `heap2local` turns some GC object traffic into ordinary locals
  - later cast/subtyping/local-cleanup passes can exploit the newly scalarized shapes
- The historical saved generated-artifact `-O4z` audit put `heap2local` in the expensive-but-successful cluster rather than the corruption cluster:
  - `17.00x` wall ratio
  - `3.66x` pass ratio
- The current 2026-07-02 generated `-O4z` slot refresh rebuilt `_build/wasm/debug/build/cmd/cmd.wasm`, generated the predecessor under `.tmp/h2l-o4z-slot-evidence-20260702/prefix-before-h2l.wasm`, and replayed direct H2L as an exact canonical match inside the pass-local floor (`67.539ms` Starshine vs `153.397ms` Binaryen). The H2L+optimize-casts+local-subtyping neighborhood is also exact; the later coalesce-locals/local-cse size gap is neighbor-owned ordered-pipeline evidence, not an H2L blocker.
- The saved Binaryen debug log contains `18` `running pass: heap2local` lines, so nested reruns matter here too.

## Most important durable takeaways

- Upstream `heap2local` is not just “replace a local-held struct with field locals.”
- The real safety contract is:
  1. **no escape from the function**
  2. **exclusive use** at every reachable use site
- Arrays are only handled when they are small fixed struct-like shapes:
  - constant size
  - size `< 20`
  - analyzable indexed access
- Upstream Binaryen lowers arrays through an explicit **array -> synthetic struct -> locals** pipeline.
- The pass handles more than `struct.get` / `struct.set`:
  - comparisons and null checks
  - tests and casts
  - descriptor reads and descriptor-based cast cases
  - packed field semantics
  - atomic and RMW/cmpxchg corner cases
- Validation repair is part of the real pass contract, not optional polish:
  - `ReFinalize`
  - `EHUtils::handleBlockNestedPops`
  - generic nondefaultable-local fixups through the pass framework

## Biggest beginner correction

The easy wrong mental model is:

- `heap2local` is Binaryen's generic escape-analysis stack-allocation pass

The safer mental model is:

- `heap2local` is a conservative **GC scalarization** pass for exact fresh allocations whose identity never matters outside the function and never mixes with another possible value.

That difference matters a lot.
It explains why the pass happily optimizes some direct local, tee, block, and small-array shapes, but immediately gives up on call escapes, return escapes, if-else mixes, ambiguous local provenance, and most dynamic array indexing.

## What the pass sounds like versus what it actually does

What it sounds like:

- replace GC objects with locals

What it actually is in Binaryen v131:

- a function-parallel pass that rebuilds per-function `Parents`, `BranchTargets`, and `LazyLocalGraph` analysis after each successful allocation rewrite,
- an `EscapeAnalyzer` that tracks child-parent flow and branch-sent values,
- a struct rewrite engine that introduces locals, scratch temps, nullable placeholders, and exact rewrites for direct ref operations,
- a separate array-to-struct lowering stage for small fixed-size arrays,
- and mandatory type / local / EH repair afterwards.

## Page map

- [`./binaryen-strategy.md`](./binaryen-strategy.md)
  - Deep dive into the real `Heap2Local.cpp` structure, helper analyses, scheduler placement, and the multi-stage array + struct algorithm.
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md)
  - Source-confirmed owner-file, helper, lit-test, and Starshine code-map page for `heap2local`, including exact local registry, dispatcher, candidate-analysis, rewrite, focused-test, and preset line ranges.
- [`./validation-fixups-and-special-cases.md`](./validation-fixups-and-special-cases.md)
  - Focused guide to the easiest parts to misunderstand: nondefaultable locals, `ReFinalize`, packed fields, atomics, descriptor families, prior corner-case refinements, and v131 stale-analysis repair.
- [`./wat-shapes.md`](./wat-shapes.md)
  - Beginner-friendly shape catalog covering positive struct/array flows, bailout shapes, explicit trap families, and the important source-only corner cases.
- [`./parity.md`](./parity.md)
  - Current in-tree Starshine parity state, focused coverage, dedicated GenValid profile status, and the current boundary between active Starshine parity and broader upstream-only fixup surface.
- [`./starshine-hot-ir-strategy.md`](./starshine-hot-ir-strategy.md)
  - Current Starshine HOT-IR strategy, now with an exact MoonBit registry / dispatcher / candidate-analysis / rewrite / test map so readers can move directly from the dossier into `src/passes/heap2local.mbt`.
- research note 0365
  - Absorbed 2026-04-25 source/code-map follow-up retaining the tagged `version_129` release, source, and lit-test provenance used by this dossier.

## V131 freshness note

The repo-wide release oracle is now Binaryen `version_131`. It includes the previously recorded array/cmpxchg/unreachable refinements and adds a broader correctness repair: after each successful array or struct scalarization, `heap2local` rebuilds `LazyLocalGraph`, `Parents`, and `BranchTargets` before analyzing the next allocation. This prevents scratch locals and rewritten parent/flow edges from being interpreted through stale analysis state.

V131 also adds direct fixture evidence in `heap2local-rmw.wast` for multiple optimized allocations around cmpxchg scratch locals and in `heap2local.wast` for unreachable control flow. Starshine now closes the sequential branch-target and unreachable-flow behavior it can represent. The shared reference-valued `acqrel` cmpxchg fixture remains blocked at validation/atomic semantics, and must be reopened with that instruction surface rather than approximated inside H2L.

## Current maintenance rule

- 2026-05-06 direct revalidation: `bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass heap2local --out-dir .tmp/pass-fuzz-heap2local` compared 6759/10000 cases with 6759 normalized matches, 0 mismatches, and 20 Binaryen empty-recursion-group parser/canonicalization command failures. See research note 0531.
- Treat this folder as the canonical home for future `heap2local` parity and scheduler research.
- Keep the main correction explicit:
  - upstream `heap2local` is conservative GC scalarization, not generic stack allocation
- Keep the array-first, exclusivity-proof, and validation-repair stories explicit whenever future docs or code changes touch this pass.
- Keep the v131 matrix explicit: `.tmp/h2l-v131-regular-10000-final` is `10000/10000` normalized; `.tmp/h2l-v131-wasm-smith-10000-final` is `9955` normalized plus one generic unreachable-control normalized match, with `44` Binaryen tool failures; `.tmp/h2l-v131-all-10000-final` has `2474` normalized and `7526` smaller Starshine residuals after both tools remove generated H2L traffic; `.tmp/h2l-v131-random-all-10000-final` has `8517` normalized and `1483` smaller residuals with no H2L-operation-presence differences. Keep these families raw and agent-classified so future allocation traffic cannot hide behind a broad normalizer.
- Keep the 2026-05-08 backlog-closure boundary explicit too: the old `[H2L]002` neighbor-slot work is done, while nondefaultable-local repair remains an upstream/source-contract note until Starshine accepts that validator surface.
- Keep the exact local navigation path explicit too: registry / preset placement in `src/passes/optimize.mbt`, dispatch in `src/passes/pass_manager.mbt`, rewrite logic in `src/passes/heap2local.mbt`, proof coverage in the focused local test files, and the line-range map in [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md).
- Keep the v131 boundary explicit: independent and immediate-branch sequential candidates are proven; shared reference-valued ordered cmpxchg remains blocked by Starshine's validator/atomic model.

## Sources

- research note 1402
- research note 0531
- research note 0365
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md)
- research note 0135
- research note 0075
- [research note 0078](../tracker.md)
- [`../../../../../src/passes/heap2local.mbt`](../../../../../src/passes/heap2local.mbt)
- [`../../../../../src/passes/heap2local_test.mbt`](../../../../../src/passes/heap2local_test.mbt)
- [`../../../../../src/passes/heap2local_primary_test.mbt`](../../../../../src/passes/heap2local_primary_test.mbt)
- [`../../../../../src/passes/optimize_test.mbt`](../../../../../src/passes/optimize_test.mbt)
- [`../../../../../src/passes/registry_test.mbt`](../../../../../src/passes/registry_test.mbt)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../../../../../agent-todo.md`](../../../../../agent-todo.md)
- [research note 0093](../late-pipeline-dispatch.md) preserves the saved generated-artifact `-O4z` slot, summary, and Binaryen debug-log facts; older `.artifacts` paths are replay identifiers, not durable wiki source links.
- Binaryen `version_129` sources:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/Heap2Local.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/opt-utils.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/pass.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/type-updating.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/heap2local.wast>
- Narrow freshness-check surfaces:
  - <https://github.com/WebAssembly/binaryen/blob/main/src/passes/Heap2Local.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/heap2local.wast>
