# Binaryen `dealign` research

- Date: 2026-04-21
- Researcher: OpenAI Codex
- Scope: justify and document Binaryen's public `dealign` pass as a new upstream-only living dossier after the tracker ran out of obvious `none` targets.

## Why this pass, why now

The recursive Binaryen wiki campaign currently has no obvious remaining tracker entries with wiki status `none`.
That means a new pass is only justified if neighboring living docs already depend on teaching it precisely.

`dealign` meets that bar.
The refreshed `alignment-lowering` dossier already mentions `dealign` as the opposite-direction sibling, but the wiki had no canonical home explaining what `dealign` actually does.
Without a dedicated page, it is easy to blur together:

- `alignment-lowering`, which legalizes weakly aligned scalar accesses by splitting them into smaller aligned scalar accesses, and
- `dealign`, which simply rewrites selected memory-access alignment immediates down to `1`.

`agent-todo.md` has **no dedicated `dealign` slice**.
This is therefore a tracker-expansion and teaching task, not a direct implementation handoff.

## Sources consulted

Official Binaryen `version_129` sources:

- `src/passes/DeAlign.cpp`
- `src/passes/pass.cpp`
- `test/lit/passes/dealign.wast`

Official current-`main` spot-check sources:

- `src/passes/DeAlign.cpp`
- `test/lit/passes/dealign.wast`

Local repo context:

- `docs/README.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
- `docs/wiki/binaryen/passes/alignment-lowering/*`
- `agent-todo.md`
- `src/passes/optimize.mbt`

## High-level conclusion

`dealign` is a **tiny module pass that forces selected memory-access alignment immediates to `1`**.
It is not a generic optimizer, not a legality pass like `alignment-lowering`, and not a transform that rewrites address arithmetic or splits loads/stores.

In reviewed `version_129`, the entire behavioral surface is:

- walk each defined function if the module has a memory
- visit `Load`, `Store`, `SIMDLoad`, and `SIMDStore`
- if the current node's `align` is greater than `1`, set it to `1`
- otherwise leave it alone

That is the core contract.

## Why it matters

This pass matters mostly as a **boundary-clarifying sibling**:

- `alignment-lowering` answers: “How do we preserve semantics when weak alignment is already present?”
- `dealign` answers: “How do we intentionally make accesses minimally aligned for testing, fuzzing, or later pass interaction?”

The pass therefore teaches a useful conceptual split:

- alignment metadata rewriting
- versus actual access legalization or performance tuning

## Implementation structure

## Public registration

`pass.cpp` registers a real public pass named `dealign` with the short description:

- `force all loads and stores to have align=1`

That public description is directionally right, but the implementation is slightly narrower and more precise than the wording suggests:

- it does **not** visit every possible memory instruction family
- it visits only `Load`, `Store`, `SIMDLoad`, and `SIMDStore`
- it only changes nodes whose `align` is already greater than `1`

## Main implementation file

Almost everything lives in `src/passes/DeAlign.cpp`.
The file defines:

- a small helper walker `DeAlignFunction`
- four visitor methods: `visitLoad`, `visitStore`, `visitSIMDLoad`, `visitSIMDStore`
- a tiny `DeAlign` module pass wrapper
- `createDeAlignPass()`

This is one of the smallest Binaryen passes in the whole public surface.

## Actual algorithm

The helper function is literally:

- if `align > 1`, assign `align = 1`

The four visit methods only forward the node's mutable `align` field into that helper.
There are no other mutations.

The module pass then:

- bails out immediately if `module->memory.exists()` is false
- iterates defined functions with `ModuleUtils::iterDefinedFunctions`
- runs the walker on each function

## Scope boundaries

Positive rewrite surface in reviewed `version_129`:

- scalar `load`
- scalar `store`
- SIMD `v128.load` family represented by `SIMDLoad`
- SIMD `v128.store` family represented by `SIMDStore`

Not directly visited by the reviewed file:

- atomics
- bulk-memory ops
- `memory.copy`, `memory.fill`, `memory.init`, `data.drop`
- tables
- GC instructions
- control flow
- address expressions
- alignment-lowering/chunk-splitting logic

## Important semantic consequence

`dealign` changes only the alignment immediate.
It does **not** change:

- width
- signedness
- offset
- pointer expression
- stored value expression
- opcode family
- trapping behavior implied by the actual memory access itself

That makes it a metadata-oriented pass.

## Relation to `alignment-lowering`

This is the most important durable teaching point.

`alignment-lowering` is about making weak alignment *legalizable* by replacing misaligned scalar accesses with several smaller aligned accesses.
`dealign` does the opposite sort of move:

- it preserves the same load/store node shape
- but weakens the static alignment promise to `1`

So the pass is best described as:

- **deliberate alignment pessimization / normalization to align=1**

not as an optimization pass.

That split is especially important because reviewed `dealign` includes SIMD load/store nodes while reviewed `alignment-lowering` is explicitly an ordinary scalar `Load` / `Store` pass.

## Proof surface in tests

The dedicated lit file `test/lit/passes/dealign.wast` is small but revealing.
It proves several important families.

### Scalar positives

The test shows ordinary scalar loads and stores with larger alignments becoming `align=1`.
Examples include:

- `i32.load align=4` -> `i32.load align=1`
- `i64.load align=8` -> `i64.load align=1`
- `f32.load align=4` -> `f32.load align=1`
- `f64.load align=8` -> `f64.load align=1`
- matching scalar stores too

### Already-weak no-op behavior

The input also includes `align=1` loads/stores.
Those remain unchanged, proving the pass is not rebuilding nodes unnecessarily.

### Offset preservation

The examples keep offsets intact while changing only the alignment immediate.
So the pass is not rewriting address arithmetic.

### Flat/stack syntax interaction

The golden output is printed in a more normalized textual shape than the input.
That output normalization is not the point of the pass.
The important contract is still only the alignment field change.

### SIMD uncertainty boundary

The reviewed dedicated lit file does **not** appear to contain an explicit SIMD example.
So SIMD coverage is source-confirmed from `DeAlign.cpp` itself rather than from a dedicated visible lit case in `dealign.wast`.
That should be recorded explicitly in the living dossier rather than silently overstating test coverage.

## Correctness constraints for a future port

A faithful Starshine port should preserve these exact rules:

- make it an explicit pass, not a hidden preset step
- no-op if the module has no memory
- rewrite only alignment metadata
- touch only `Load`, `Store`, `SIMDLoad`, and `SIMDStore` unless the scope is intentionally widened
- leave `align=1` nodes alone
- preserve offsets, widths, types, signedness, and child evaluation unchanged
- keep the split from `alignment-lowering` explicit

## Performance / cost profile

This pass is tiny.
Its cost model is effectively:

- one module-memory existence check
- one iteration over defined functions
- one very shallow AST walk mutating a single integer field on a few node kinds

So performance is not the interesting part here.
The interesting part is semantic clarity.

## Open questions / caveats

1. SIMD proof surface:
   - source confirms SIMD load/store support
   - the dedicated lit file does not visibly isolate that family
   - the living docs should say this explicitly
2. Scheduler placement:
   - `dealign` is a real public pass
   - it is not in the local no-DWARF `-O` / `-Os` path
   - it is not currently named in `src/passes/optimize.mbt`
3. Motivation surface:
   - the public docs do not elaborate much on why one would run `dealign`
   - the best source-backed framing is as a sibling/boundary pass near `alignment-lowering`, not as a throughput optimizer

## Living-wiki filing plan

Create a new upstream-only folder:

- `docs/wiki/binaryen/passes/dealign/`

with at least:

- `index.md`
- `binaryen-strategy.md`
- `implementation-structure-and-tests.md`
- `wat-shapes.md`
- one focused page on the exact rewrite surface and the split from `alignment-lowering`

Then update:

- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/index.md`
- `docs/wiki/log.md`

## Bottom line

`dealign` is a justified new upstream-only dossier because the tracker has no obvious remaining `none` targets and the neighboring `alignment-lowering` docs already needed a canonical home for its opposite-direction sibling.

Its real `version_129` contract is tiny and teachable:

- module has memory?
- walk defined functions
- set visited load/store/SIMD load/store alignments to `1` if they were larger

That is it.
But making that tiny contract explicit is still useful, because without it the wiki would keep risking the wrong lesson that `dealign` is somehow the same kind of pass as `alignment-lowering`.
