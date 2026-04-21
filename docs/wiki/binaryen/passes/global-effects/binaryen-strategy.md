---
kind: concept
status: supported
last_reviewed: 2026-04-21
sources:
  - ../../../raw/research/0168-2026-04-21-global-effects-binaryen-research.md
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/GlobalEffects.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/effects.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/wasm.h
related:
  - ./index.md
  - ./metadata-naming-and-consumers.md
  - ./wat-shapes.md
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

`src/passes/pass.cpp` registers `generate-global-effects` and also registers the sibling cleanup pass `discard-global-effects`.
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

`GlobalEffects.cpp` begins with a parallel analysis over functions using `ModuleUtils::ParallelFunctionAnalysis<EffectAnalyzer>`.
For each function it constructs a `ShallowEffectAnalyzer(func, module)`.

This first phase deliberately stays shallow.
It records the function body's own obvious effect surface, such as:

- direct global reads
- direct global writes
- direct call targets
- ordinary effect facts already tracked by `EffectAnalyzer`

The pass asserts that these shallow summaries have no branch or local effects.
That is a strong clue about the pass boundary:

- this pass is not trying to summarize all control/dataflow facts
- it wants a clean global/call summary that can be propagated interprocedurally

## Phase 2: build reverse call dependencies

After the shallow scan, the pass builds a reverse dependency map from callees back to callers.

That gives Binaryen two useful structures:

- “who does this function call?”
- “which callers depend on this function's summary?”

The reverse direction matters because whenever a callee summary becomes more precise, every caller that depends on it may need recomputation.

## Phase 3: fixed-point propagation over defined functions

The pass seeds a `UniqueDeferredQueue<Function*>` with defined functions and repeatedly:

1. removes one function from the queue
2. recomputes its full summary from its shallow summary plus all currently known callee summaries
3. compares the new summary against the old stored summary
4. if the summary changed, requeues that function's callers

This is the real algorithmic heart of the pass.

It means the pass is:

- interprocedural
- iterative
- monotone/fixed-point in style
- naturally capable of handling wrapper chains and recursive SCCs

A beginner-friendly summary is:

- start local
- then keep learning from callees until nothing changes

## Phase 4: store summaries in `Function.effects`

The reviewed `wasm.h` source shows that each `Function` can hold an optional `std::unique_ptr<EffectAnalyzer>` named `effects`.

`GlobalEffects.cpp` writes the computed summaries into that field.

This is why the pass itself often leaves the printed WAT unchanged:

- it is changing module metadata
- not the visible body structure

That also explains why the sibling `discard-global-effects` pass exists: upstream Binaryen treats this metadata as explicit state that may need to be cleared when it becomes stale or unnecessary.

## How later passes consume the result

The reviewed `effects.h` source shows the exact handoff point.
When `EffectAnalyzer` visits a direct `Call`, it can look up the call target function and, if a stored summary exists, merge that function's global effects into the call's own effect model.

So the generated summaries make later questions more precise, such as:

- does this call read global `$g`?
- does this call write global `$g`?
- can a later pass move a `global.get` across this call?
- can an unused call result be erased because the call is effect-free enough?

Without this pass, later passes must be more conservative around calls.

## Key helper dependencies

A future Starshine port must preserve the role of these helpers and data structures:

- `ModuleUtils::ParallelFunctionAnalysis`
  - produces the initial shallow summaries in parallel
- `ShallowEffectAnalyzer`
  - strips the problem down to the immediate per-function global/call surface
- `EffectAnalyzer`
  - owns the actual effect-summary representation later passes consume
- `UniqueDeferredQueue`
  - drives the caller-requeue fixed point without duplicate spam
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

Because the pass uses a deferred work queue and requeues callers on change, recursive groups can stabilize to summaries that include their transitive effects.

## Important bailout / conservative families

### 1. Not part of default optimization scheduling

Even upstream Binaryen chooses not to run this automatically in the default optimize path today.
That means users and downstream docs must not pretend its precision is always present.

### 2. Opaque/imported boundaries

The pass cannot inspect external code bodies the same way it can inspect local defined functions.
That naturally limits how precise the propagated summaries can become around imports or other opaque surfaces.

### 3. Missing or stale metadata

Later passes only benefit when the summaries exist and are still valid.
The existence of `discard-global-effects` is direct source-backed evidence that Binaryen considers invalidation and lifecycle management part of the contract.

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

- [`../../../raw/research/0168-2026-04-21-global-effects-binaryen-research.md`](../../../raw/research/0168-2026-04-21-global-effects-binaryen-research.md)
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/GlobalEffects.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/effects.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/wasm.h>
