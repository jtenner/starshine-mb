---
kind: concept
status: supported
last_reviewed: 2026-04-25
sources:
  - ../../../raw/binaryen/2026-04-25-discard-global-effects-primary-sources.md
  - ../../../raw/binaryen/2026-04-24-global-effects-primary-sources.md
  - ../../../raw/research/0305-2026-04-24-global-effects-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0168-2026-04-21-global-effects-binaryen-research.md
related:
  - ./index.md
  - ./metadata-naming-and-consumers.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../discard-global-effects/index.md
  - ../simplify-locals/index.md
  - ../vacuum/index.md
---

# Binaryen strategy for `global-effects` / `generate-global-effects`

## What the pass really is

Upstream Binaryen publishes this pass as `generate-global-effects`.
The local Starshine registry shortens it to `global-effects`.

The implementation is a **metadata-producing interprocedural analysis pass**:

- it does **not** rewrite function bodies directly
- it computes per-function effect summaries
- it stores those summaries in `Function.effects`
- later `EffectAnalyzer` queries on calls may consult them

That makes the pass easy to mis-teach.
The right mental model is not “another code cleanup pass.”
It is “teach the optimizer more precise global read/write facts across calls.”

## Scheduler placement

`src/passes/pass.cpp` registers `generate-global-effects` and also registers the sibling cleanup pass [`discard-global-effects`](../discard-global-effects/index.md).
The same registration block contains a direct policy note:

- Binaryen does **not** run `generate-global-effects` in the default optimize pipeline today.
- The comment says that if it becomes useful enough, Binaryen can add it automatically later.

So the scheduler truth is:

- real public pass: yes
- default no-DWARF `-O` / `-Os` pass: no
- explicit/manual or specialized-pipeline pass: yes

For Starshine's wiki tracker, that puts it in the expanded upstream-only registry bucket, not in the main parity queue.

## Core implementation phases

## Phase 1: shallow per-function effect summaries

`GlobalEffects.cpp` begins with a parallel analysis over defined functions.
For each function, the pass builds a `FuncInfo` record from a shallow `EffectAnalyzer`.

This first phase deliberately stays shallow.
It records the function body's own obvious effect surface, then separates direct static callees from ordinary call effects.
The reviewed `version_129` source also tracks an `unknownEffects` flag for call forms it cannot fully resolve through a defined callee.

That split is important:

- direct global reads and writes become local summary facts
- direct function calls become call-graph edges for later propagation
- imported, indirect, or otherwise unknown call surfaces remain conservative
- the pass is not trying to summarize all control/dataflow facts; it wants a clean global/call summary that can be propagated interprocedurally

## Phase 2: build static call reachability and conservative boundaries

After the shallow scan, the `version_129` pass computes static call reachability from each caller to the defined functions it can reach.
The beginner-friendly shape is still “callee facts flow back to callers,” but the source-backed implementation detail is more concrete:

- direct calls seed the reachable-callee set
- transitive static callees are added with a deferred queue
- unknown effects remain attached to callers that cross opaque call boundaries
- recursive call chains are detected and treated conservatively by marking affected summaries as trapping

The conservative recursion/unknown-effect behavior is part of the real contract, not incidental bookkeeping.

## Phase 3: fixed-point propagation over defined functions

Once callee reachability is known, the `version_129` pass constructs each full summary from:

1. the shallow local effects,
2. any conservative unknown-call effects,
3. the summaries of reachable defined callees, and
4. the extra trap marking needed for recursive call chains.

This is the real algorithmic heart of the pass.

It means the pass is:

- interprocedural
- fixed-point-like in the beginner model
- conservative around recursion and opaque calls
- naturally capable of teaching later passes about wrapper chains

A beginner-friendly summary is still:

- start local
- separate known static calls from unknown calls
- then keep learning from known callees until the function summaries are safe to store

## Phase 4: store summaries in `Function.effects`

The reviewed `wasm.h` source shows that each `Function` can hold optional `EffectAnalyzer` metadata named `effects`.

`GlobalEffects.cpp` writes the computed summaries into that field. The owner-file header still says effects are stored on `PassOptions`, but the reviewed implementation and data model both point to `Function.effects`; this wiki treats the header phrase as stale wording unless upstream later changes the implementation contract.

This is why the pass itself often leaves the printed WAT unchanged:

- it is changing module metadata
- not the visible body structure

That also explains why the sibling [`discard-global-effects`](../discard-global-effects/index.md) pass exists: upstream Binaryen treats this metadata as explicit state that may need to be cleared when it becomes stale or unnecessary.

## How later passes consume the result

The reviewed `effects.h` source shows the exact handoff point.
When `EffectAnalyzer` visits a direct `Call`, it can look up the call target function and, if a stored summary exists, merge that function's global effects into the call's own effect model.

So the generated summaries make later questions more precise, such as:

- does this call read global `$g`?
- does this call write global `$g`?
- can a later pass move a `global.get` across this call?
- can an unused call result be erased because the call is effect-free enough?

Without this pass, later passes must be more conservative around calls.

## Current-`main` drift

The 2026-04-24 primary-source capture also spot-checked current Binaryen `main`.
The visible teaching drift is in implementation structure, not in the high-level contract:

- `version_129` uses a deferred reachability propagation style over function infos.
- current `main` builds an explicit call graph, computes SCCs, processes components in reverse topological order, aggregates component effects, and applies component summaries back to functions.
- both reviewed versions keep the durable story: shallow scan, conservative unknown effects, recursive-cycle conservatism, per-function effect metadata, and a discard sibling.

When matching `version_129` oracle behavior, teach and test against the tagged release first. When reading upstream `main`, expect the SCC-shaped implementation.

## Key helper dependencies

A future Starshine port must preserve the role of these helpers and data structures:

- `ModuleUtils::ParallelFunctionAnalysis`
  - produces the initial shallow summaries in parallel
- `ShallowEffectAnalyzer`
  - strips the problem down to the immediate per-function global/call surface
- `EffectAnalyzer`
  - owns the actual effect-summary representation later passes consume
- `UniqueDeferredQueue` / current-main SCC graph processing
  - drives the transitive-call propagation story in the reviewed release / current source shapes
- `Function.effects` in `wasm.h`
  - stores the resulting summary as explicit function metadata

The correctness story is not contained in one tiny rewrite function.
It depends on the pass, the effect model, and the consumer-side lookup all matching.

## Important positive families

Because this is a metadata pass, “positive rewrite families” really mean “positive precision families.”

### 1. Direct read-only callee

If a callee only reads globals, later passes can treat the call as a read barrier rather than a write barrier for those globals.
That can unlock safe motion or cleanup in nearby passes.

### 2. Direct writer callee

If a callee writes a global, the pass preserves that fact.
This is a positive result too, because the pass is supposed to improve precision, not merely optimism.

### 3. Transitive wrapper chains

If one function calls another wrapper which eventually calls a global reader/writer, the fixed point can still propagate that fact back to the outer caller.

### 4. Recursive call groups

Because the release pass detects recursive call chains and current `main` uses SCCs, recursive groups are handled conservatively instead of being treated as one-shot acyclic wrapper chains.

## Important bailout / conservative families

### 1. Not part of default optimization scheduling

Even upstream Binaryen chooses not to run this automatically in the default optimize path today.
That means users and downstream docs must not pretend its precision is always present.

### 2. Opaque/imported boundaries

The pass cannot inspect external code bodies the same way it can inspect local defined functions.
That naturally limits how precise the propagated summaries can become around imports or other opaque surfaces.

### 3. Missing or stale metadata

Later passes only benefit when the summaries exist and are still valid.
The existence of [`discard-global-effects`](../discard-global-effects/index.md) is direct source-backed evidence that Binaryen considers invalidation and lifecycle management part of the contract.

### 4. Not a generic alias analysis

This pass improves global-effect knowledge across calls.
It does not replace the rest of Binaryen's effect system, nor does it attempt full heap/value analysis.

## Pass interactions that are easy to misunderstand

## `simplify-locals`

The neighboring dossier records that generated global-effect summaries can let `simplify-locals` distinguish calls that only read globals from calls that write them.
That is exactly the kind of consumer behavior the `effects.h` handoff implies.

## `vacuum`

The reviewed upstream test `vacuum-global-effects.wast` proves the other important interaction:

- with generated summaries, some calls become effect-free enough that `vacuum` can erase them when their results are unused

## `discard-global-effects`

This sibling pass matters conceptually even if the current dossier is about the producer.
It is explicit evidence that Binaryen models global-effect summaries as managed pass-state, not as ambient forever-valid truth.

The cleanup sibling now has its own dossier at [`../discard-global-effects/index.md`](../discard-global-effects/index.md). Keep the producer and cleanup contracts separate: `generate-global-effects` writes summaries; `discard-global-effects` clears them.

## What a future Starshine port must preserve

A faithful port should preserve:

- the **metadata-only** nature of the pass
- the **upstream/local naming split**
- the fact that it is **not in the current default optimize pipeline**
- the **shallow-summary + fixed-point** algorithm structure
- the **consumer contract** through later call-effect queries
- honest behavior around **opaque boundaries** and **metadata invalidation**

If Starshine ever ports this and accidentally turns it into a direct code-rewriting pass or treats its summaries as permanent after arbitrary later rewrites, it will stop matching Binaryen's real contract.

## Sources

- [`../../../raw/binaryen/2026-04-25-discard-global-effects-primary-sources.md`](../../../raw/binaryen/2026-04-25-discard-global-effects-primary-sources.md)
- [`../../../raw/binaryen/2026-04-24-global-effects-primary-sources.md`](../../../raw/binaryen/2026-04-24-global-effects-primary-sources.md)
- [`../../../raw/research/0305-2026-04-24-global-effects-primary-sources-and-starshine-followup.md`](../../../raw/research/0305-2026-04-24-global-effects-primary-sources-and-starshine-followup.md)
- [`../../../raw/research/0168-2026-04-21-global-effects-binaryen-research.md`](../../../raw/research/0168-2026-04-21-global-effects-binaryen-research.md)
