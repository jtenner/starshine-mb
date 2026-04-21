---
kind: concept
status: working
last_reviewed: 2026-04-20
sources:
  - ../../../raw/research/0135-2026-04-20-heap2local-binaryen-research.md
  - ../../../../../src/passes/heap2local.mbt
  - ../../../../../src/passes/heap2local_test.mbt
  - ../../../../../src/passes/heap2local_primary_test.mbt
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/optimize_test.mbt
  - ../../../../../src/passes/registry_test.mbt
  - ../../../../../agent-todo.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./validation-fixups-and-special-cases.md
  - ./wat-shapes.md
  - ./parity.md
---

# Current Starshine `heap2local` strategy

This page is the local “what is actually implemented today?” companion to the upstream Binaryen strategy page.

## Short version

Current Starshine `src/passes/heap2local.mbt` follows the same **core goal** as upstream Binaryen:

- replace some nonescaping GC allocation traffic with locals

But it is not a literal source port of Binaryen `Heap2Local.cpp`.

The local pass is narrower, more direct, and much more HOT/use-def driven.

## What current Starshine already models well

The current in-tree pass covers the green primary suite described in `agent-todo.md` and `src/passes/heap2local_primary_test.mbt`.
That includes:

- direct exclusive struct owners through locals
- exclusive local-copy chains
- direct tee owners
- simple block-result flow
- `ref.as_non_null`
- successful `ref.cast` on the optimized struct allocation
- direct `ref.eq` against `ref.null`
- descriptor-bearing `struct.new_desc` / `struct.new_default_desc` with `ref.get_desc`
- constant-size `array.new_default`, `array.new`, and `array.new_fixed`
- constant-index `array.get`, `array.get_s`, `array.get_u`, and `array.set`
- direct array `ref.test`
- bailout on parameter-backed mixed provenance

That is already a meaningful subset of the upstream pass.

## What local Starshine does differently from Binaryen

## 1. The local pass depends only on HOT use-def

The registry descriptor currently requires only:

- `@ir.HotAnalysis::use_def()`

That is much smaller than the upstream Binaryen helper stack, which explicitly uses:

- `LazyLocalGraph`
- `Parents`
- `BranchTargets`
- `ScratchInfo`
- `ReFinalize`
- pass-runner nondefaultable-local fixups
- EH nested-pop repair

So the local proof model is simpler and narrower.

## 2. Struct candidates are discovered directly from local write/read shapes

Starshine's candidate finder looks for:

- a non-parameter local
- exactly one write to that local
- that write being `local.set` or `local.tee`
- a directly supported `struct.new` / `struct.new_default` initializer
- a family of reads whose uses all match a limited supported pattern

That is a much more direct local-pattern approach than upstream Binaryen's general child->parent + branch-target flow analyzer.

## 3. Array support is direct, not array->struct->locals

This is the biggest architectural difference.

Upstream Binaryen:

- turns eligible arrays into synthetic structs first
- then reuses the struct scalarization engine

Current Starshine:

- allocates one local per array element directly
- rewrites supported array gets/sets straight to those element locals

That means the local implementation can be simpler, but it also means it does **not** currently model all the type-flow, cast, atomic, and cmpxchg behaviors that upstream gets “for free” from the shared struct stage.

## 4. Local Starshine currently supports only a narrow flow-through set

The local source explicitly supports:

- direct field users
- `ref.as_non_null` passthrough
- successful `ref.cast` passthrough
- simple block-root flow in a specific last-root-only shape
- direct local-copy chains

It does **not** implement the full upstream interaction matrix for:

- general loop result flow
- branch-target flow with exclusivity proofs
- broader child/parent mixing checks
- many multi-parent control-flow combinations

So the current local pass is still more of a carefully curated pattern matcher than a full Binaryen-style flow analysis engine.

## 5. Current local folding of direct ref ops is narrower

The local pass currently folds some direct uses outside the main candidate machinery:

- `ref.eq` against fresh struct + `ref.null`
- `ref.get_desc` on direct descriptor-bearing allocations
- direct array `ref.test`

That is useful, but it is still a smaller surface than upstream Binaryen, which also reasons about:

- `ref.is_null`
- wider `ref.test` / `ref.cast`
- descriptor-based cast families
- more type/nullability repair around those rewrites

## Important current gaps versus upstream Binaryen

## 1. No general exclusivity engine

Upstream Binaryen proves exclusivity with `LazyLocalGraph`, parent walking, and branch-target reasoning.
Current Starshine instead requires a much narrower family of supported read/write/use shapes.

That means several upstream-legal cases are still not naturally modeled locally.

## 2. No upstream-style array synthetic-struct stage

This means current Starshine does not naturally inherit the upstream handling for:

- array type-flow rewrites
- array `ref.cast` source semantics before conversion
- some array atomic / cmpxchg special cases
- the unified packed/atomic/RMW handling that upstream gets after the array becomes a struct-like allocation

## 3. No documented local equivalent of Binaryen's nondefaultable-local fixups

The backlog and parity note still treat this as a remaining gap.
Binaryen relies on generic pass-runner `TypeUpdating::handleNonDefaultableLocals(...)` plus in-pass refinalization.
Current Starshine's HOT pipeline does not currently advertise an equivalent automatic repair layer here.

That is why the backlog still calls out:

- non-nullable-local / refinalization fixups

as the main remaining local `heap2local` gap.

## 4. No full upstream atomic / RMW / cmpxchg surface

The local file rewrites:

- supported struct gets/sets
- supported array gets/sets

but it does **not** expose an upstream-sized source surface for:

- packed-field repair helpers
- `struct.rmw`
- `struct.cmpxchg`
- `array.rmw`
- `array.cmpxchg`
- shared-atomic local lowering rules

Those are important future parity targets.

## 5. Broader control-flow families are still missing

The current local pass does not claim full upstream coverage for:

- loop-result flow-through cases
- sole branch-to-block value flow
- more general mixed-branch exclusion proofs
- wider unreachable and cast-driven type-repair stories

So the dossier should keep upstream behavior explicit even where the local implementation is not there yet.

## Current scheduler story in-tree

The local preset tests show that Starshine currently schedules `heap2local` in a simplified mid-function GC slot:

- `remove-unused-brs -> heap2local -> simplify-locals`

That is intentionally smaller than upstream Binaryen's full neighborhood, which continues with:

- `optimize-casts`
- `local-subtyping`
- `coalesce-locals`
- `local-cse`
- `simplify-locals`

So the current Starshine scheduler story is honest but incomplete.
The local slot exists, but several important neighbors are still missing.

## Current evidence and honest status

## Local parity evidence is already good

The backlog and parity page record:

- green in-tree primary suite
- `10000`-case `gen-valid` compare with no mismatches
- `1000`-case mixed-generator sample with no mismatches and only Binaryen-side parser rejects
- `2026-04-11` smoke rerun with `199 / 200` compared and `0` mismatches

That means current Starshine `heap2local` is already strong on the subset it claims.

## But the generated-artifact perf story is still not closed

The saved `-O4z` audit summary still lists `heap2local` in the expensive-but-successful cluster.
So the honest reading is:

- semantics are much healthier than many earlier hot-pass stories
- but runtime and deeper surface parity still matter

## Best current mental model

Upstream Binaryen tells us what `heap2local` **means** semantically:

- nonescaping + exclusive GC scalarization with real type/atomic/EH repair

Current Starshine tells us what a smaller HOT/use-def implementation already **gets right** today:

- direct local, tee, block, descriptor, and small-array patterns

When those two stories differ, treat Binaryen `version_129` as the semantic oracle and treat the current Starshine file as the narrower local strategy that still needs to grow.

## What a future local refactor must preserve

If Starshine rewrites this pass again, keep these lessons explicit:

- preserve the distinction between nonescape and exclusivity
- do not treat arrays as fully solved unless the upstream-sized synthetic-struct and type-repair story is really ported
- keep descriptor-bearing support honest
- add nondefaultable-local / refinalization repair instead of papering over it
- keep the preset slot aligned with the future `optimize-casts -> local-subtyping -> coalesce-locals -> local-cse` neighbor cluster
- keep the strong existing parity evidence visible, but do not overstate it as full upstream surface parity
