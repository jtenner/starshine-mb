---
kind: concept
status: supported
last_reviewed: 2026-04-26
sources:
  - ../../../raw/binaryen/2026-04-26-avoid-reinterprets-port-readiness-primary-sources.md
  - ../../../raw/research/0381-2026-04-26-avoid-reinterprets-port-readiness.md
  - ../../../raw/binaryen/2026-04-24-avoid-reinterprets-primary-sources.md
  - ../../../raw/research/0281-2026-04-24-avoid-reinterprets-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0172-2026-04-21-avoid-reinterprets-binaryen-research.md
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/AvoidReinterprets.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/local-graph.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/properties.h
  - https://github.com/WebAssembly/binaryen/blob/main/src/passes/AvoidReinterprets.cpp
related:
  - ./index.md
  - ./implementation-structure-and-tests.md
  - ./single-load-chains-and-bailouts.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
---

# Binaryen strategy for `avoid-reinterprets`

## What the pass really is

Upstream Binaryen publishes this pass as `avoid-reinterprets`.

The 2026-04-24 primary-source capture is [`../../../raw/binaryen/2026-04-24-avoid-reinterprets-primary-sources.md`](../../../raw/binaryen/2026-04-24-avoid-reinterprets-primary-sources.md), and the 2026-04-26 port-readiness recheck is [`../../../raw/binaryen/2026-04-26-avoid-reinterprets-port-readiness-primary-sources.md`](../../../raw/binaryen/2026-04-26-avoid-reinterprets-port-readiness-primary-sources.md).
Together they confirm that the reviewed implementation is a **small function-parallel AST pass** whose real job is:

- identify reinterpret users of a full-width load value,
- prove that value still comes from one load through a simple local chain,
- and replace the reinterpret with an alternate-type load of the same address.

That means the best mental model is:

- **duplicate eligible loads in the reinterpreted type**
- not “rewrite the local web to a new type”
- not “erase all reinterprets”
- and not “perform load CSE”

## Scheduler placement

`src/passes/pass.cpp` registers `avoid-reinterprets` as a normal public pass.

The local repo makes these scheduler facts explicit:

- it is now an active Starshine module pass for direct full-width load flips in [`src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`docs/0063-2026-03-24-pass-port-batches-and-registry-map.md#L42-L43`](../../../../../docs/0063-2026-03-24-pass-port-batches-and-registry-map.md#L42-L43) is now stale for this pass because it listed the name as removed-until-hot-implementation work
- it is absent from `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
- [`./starshine-strategy.md`](./starshine-strategy.md) records the active-partial local status and remaining indirect-analysis question
- [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md) records the landed direct full-width `reinterpret(load)` slice and future indirect local-chain helper-local work

So the scheduler truth is:

- real public pass: yes
- current local active pass: partial direct-load slice
- default no-DWARF `-O` / `-Os` pass: no
- explicit tracker-expansion dossier target: yes

## Implementation shape

The reviewed upstream implementation is compact.
Nearly everything important lives in `src/passes/AvoidReinterprets.cpp`.

The pass class is:

- `AvoidReinterprets : WalkerPass<PostWalker<AvoidReinterprets>>`

Important consequences:

- it is a normal Binaryen post-order tree walker
- it is function-parallel
- it uses helper analysis, but not a broad interprocedural planner
- the safety proof is local and provenance-based, not profitability-based

## Core implementation phases

## Phase 1: mark loads that feed reinterpret users

The initial walk only reacts to `Unary` nodes that are one of the four reinterpret ops.

If the reinterpret operand falls through to a `local.get`, the pass asks `getSingleLoad(...)` whether that get still resolves to exactly one source load.

If yes, the pass records:

- this source `Load*` has reinterpreting users

The pass does **not** rewrite anything yet.
This first phase is just candidate discovery.

## Phase 2: filter candidates to full-width reachable loads

A marked load survives only if `canReplaceWithReinterpret(load)` succeeds.
That helper requires:

- load type is not `unreachable`
- loaded byte width exactly matches the result type width

So the eligible core family is deliberately tiny:

- full-width `i32`, `f32`, `i64`, `f64` loads only
- no narrow loads
- no unreachable loads

For each surviving load, the pass allocates:

- `ptrLocal` with the memory's `addressType`
- `reinterpretedLocal` with `load->type.reinterpret()`

## Phase 3: final rewrite walk

The nested `FinalOptimizer` does the real transformations.

### Direct family: `reinterpret(load(...))`

If the reinterpret directly wraps a load, Binaryen flips the load type immediately.

So:

- `f32.reinterpret_i32 (i32.load ptr)`

becomes:

- `f32.load ptr`

provided the load is full-width and reachable.

No helper locals are needed here.

### Indirect family: `reinterpret(local.get ...)`

If the reinterpret wraps a `local.get`, Binaryen reruns the single-load proof.
If the proof still succeeds and the source load is tracked, it replaces the reinterpret with:

- `local.get reinterpretedLocal`

This is only half the rewrite.
The source load site is modified separately.

### Source-load family: duplicate the load once and preserve both views

When the final walker reaches the tracked original load, it rewrites it into a small block that:

1. saves the pointer once
2. performs the alternate-type load and stores it in `reinterpretedLocal`
3. performs the original load and leaves that as the value of the rewritten position

That design preserves both consumers:

- ordinary uses still see the original type
- reinterpreting uses now read from `reinterpretedLocal`

This is the most important thing future ports must preserve.
The pass duplicates the load instead of retargeting the original variable graph.

## What `getSingleLoad(...)` really enforces

This helper is the real legality engine.

Starting from a `local.get`, it repeatedly asks `LocalGraph` for its reaching sets.
The chain only continues when all of the following stay true:

- the get has exactly one reaching set
- that reaching set is not `nullptr`
- the set's value falls through to either another `local.get` or a `Load`

That produces these practical rules:

- copy chains are okay
- merged definitions are not
- params or entry values are not
- arbitrary computed definitions are not
- cycles in unreachable code are rejected

So the pass does not prove “same bits globally.”
It proves “this reinterpreting local chain still comes from one load.”

## Why `Properties::getFallthrough(...)` matters

The pass never just looks at raw children.
It normalizes through `Properties::getFallthrough(...)` before asking whether a set value is another `local.get` or a `Load`.

That means:

- transparent wrappers may be ignored
- but non-fallthrough wrappers still block the transformation

The dedicated `nofallthrough` test proves this boundary explicitly.

## The sign bit rule is more subtle than it looks

`makeReinterpretedLoad(...)` always creates the alternate load with:

- `signed = false`

The source comment explains why that is valid:

- if the original load was integer, the alternate load is float, so sign is irrelevant
- if the original load was float, the alternate load is integer, but there is no semantic signedness choice to preserve for reinterpretation

This is another reason the pass is restricted to full-width load pairs.

## Positive rewrite families

## 1. Direct full-width scalar pairs

The obvious positive family is:

- `f32.reinterpret_i32 (i32.load ...) -> f32.load ...`
- `i32.reinterpret_f32 (f32.load ...) -> i32.load ...`
- `f64.reinterpret_i64 (i64.load ...) -> f64.load ...`
- `i64.reinterpret_f64 (f64.load ...) -> i64.load ...`

## 2. Single-load local chains

The pass also handles:

- `load -> local.set x -> local.get x -> reinterpret`

and copy-chain variants like:

- `load -> local.set x -> local.set y (local.get x) -> reinterpret(local.get y)`

provided the chain stays single-source.

## 3. Multiple reinterpret users of one source load

If several reinterpret users all trace back to the same tracked load,
Binaryen emits one helper local for the alternate-type load and reuses it.

## 4. Mixed-use webs

If some users need the original type and others reinterpret the bits, both survive:

- original users keep the original load result
- reinterpret users read from the helper local

## Negative and bailout families

## 1. Partial loads

Narrow loads like `load8_u` and `load16_u` are left alone.
This is a hard source-backed boundary.

## 2. Unreachable loads

These are also rejected directly by `canReplaceWithReinterpret(...)`.

## 3. Parameters and entry values

A `nullptr` reaching set in `LocalGraph` causes bailout.

## 4. Multi-source local merges

If `LocalGraph` reports more than one reaching set, the pass refuses to choose.

## 5. Non-fallthrough wrappers

Named or effectful wrapper shapes that do not qualify as fallthrough keep the original reinterpret.

## 6. Cycles in unreachable-code local webs

The helper tracks seen gets and bails out on cycles instead of trying to reason through unreachable-code copy loops.

## Helper dependencies

## `LocalGraph`

Used to prove that a `local.get` has exactly one reaching source load through a simple chain.
That is the main provenance dependency.

## `Properties::getFallthrough(...)`

Used to look through transparent wrappers when following a set value.
That is the main wrapper-sensitivity dependency.

## `Builder`

Used for all helper-local and block construction:

- fresh temp locals
- `local.set`
- `local.get`
- wrapper blocks
- retyped load nodes

## Memory `addressType`

The pass queries the memory for its `addressType` when creating pointer temps.
That is the core memory32 vs memory64 portability rule.

## Current-main drift check

I compared:

- `version_129` `src/passes/AvoidReinterprets.cpp`
- current upstream `main` `src/passes/AvoidReinterprets.cpp`

The original dossier found the files identical on 2026-04-21.
The 2026-04-24 source-capture follow-up did not surface teaching-relevant drift in the main pass file, registration surface, helper headers, or dedicated lit files.
The 2026-04-26 port-readiness follow-up rechecked the official `version_129` and current-main implementation, registration, and dedicated lit surfaces again and found no teaching-relevant drift from this contract.

That does not prove every neighboring helper file is frozen, but it does mean the reviewed implementation summary still matches the official sources checked for this dossier.

## Pass interactions

This pass has fewer scheduler interactions than most, but a few teaching contrasts matter.

### Versus `alignment-lowering`

- `alignment-lowering` legalizes one misaligned access into several smaller aligned accesses
- `avoid-reinterprets` duplicates a full-width load in another type

### Versus `local-cse`

- `local-cse` tries to remove repeated work
- `avoid-reinterprets` can intentionally add a second load

### Versus `simplify-locals`

- `simplify-locals` reshapes local traffic
- `avoid-reinterprets` depends on a preexisting single-load chain but does not rewrite the whole local web to another type

### Later cleanup opportunity

The helper-local blocks and dead original users it creates may become good cleanup targets for later passes,
but those follow-up cleanups are not part of this pass's own contract.

## What a future Starshine port must preserve

A faithful port should preserve:

- exact reinterpret-op recognition
- exact full-width-only eligibility
- exact single-load provenance proof for the indirect local-get family
- a direct-load first slice that does not pretend to solve local-chain provenance
- fallthrough-wrapper sensitivity
- memory32 vs memory64 pointer temp typing
- helper-local duplication for indirect reinterpret users
- mixed-use preservation when both original and reinterpreted views are live
- conservative bailouts on merges, params, partial loads, unreachable loads, and cycles

## Easy-to-miss teaching summary

If someone remembers only one sentence, it should be this:

> Binaryen `avoid-reinterprets` is a narrow provenance-checked load-duplication pass: it replaces reinterpret users with alternate-type loads only when one full-width source load can still be proven through a single local chain.

## Sources

- [`../../../raw/binaryen/2026-04-26-avoid-reinterprets-port-readiness-primary-sources.md`](../../../raw/binaryen/2026-04-26-avoid-reinterprets-port-readiness-primary-sources.md)
- [`../../../raw/research/0381-2026-04-26-avoid-reinterprets-port-readiness.md`](../../../raw/research/0381-2026-04-26-avoid-reinterprets-port-readiness.md)
- [`../../../raw/binaryen/2026-04-24-avoid-reinterprets-primary-sources.md`](../../../raw/binaryen/2026-04-24-avoid-reinterprets-primary-sources.md)
- [`../../../raw/research/0281-2026-04-24-avoid-reinterprets-primary-sources-and-starshine-followup.md`](../../../raw/research/0281-2026-04-24-avoid-reinterprets-primary-sources-and-starshine-followup.md)
- [`../../../raw/research/0172-2026-04-21-avoid-reinterprets-binaryen-research.md`](../../../raw/research/0172-2026-04-21-avoid-reinterprets-binaryen-research.md)
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/AvoidReinterprets.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/local-graph.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/properties.h>
- <https://github.com/WebAssembly/binaryen/blob/main/src/passes/AvoidReinterprets.cpp>
