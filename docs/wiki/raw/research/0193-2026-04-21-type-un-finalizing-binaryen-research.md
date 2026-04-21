# Binaryen `type-un-finalizing` / upstream `type-unfinalizing` research

Date: 2026-04-21
Author: OpenAI Codex
Status: archived research feeding living wiki pages

## Scope and selection note

I re-read:

- `docs/README.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
- `agent-todo.md`
- `src/passes/optimize.mbt`
- `docs/0063-2026-03-24-pass-port-batches-and-registry-map.md`
- the new neighboring `type-finalizing` dossier and older GC/type dossiers such as `remove-unused-types`, `type-merging`, and `unsubtyping`

The original no-DWARF queue, the saved generated-artifact `-O4z` queue, and the first widened tracker-expansion wave are already dossier-covered.
The immediately previous thread also completed the dedicated `type-finalizing` dossier.
So this thread explicitly expands the tracker again to cover the remaining named sibling that still lacked its own dedicated landing folder.

I picked exactly one pass:

- local registry alias `type-un-finalizing`
- upstream public Binaryen pass `type-unfinalizing`

I did **not** pick `type-finalizing` again.
I did **not** pick any excluded pass from the campaign list.

`agent-todo.md` currently has **no dedicated `type-un-finalizing` or `type-unfinalizing` slice**.

## Why `type-un-finalizing` is a justified next target

This is a justified upstream-only registry expansion because:

1. `src/passes/optimize.mbt` still names `type-un-finalizing` directly in the local boundary-only registry
2. `docs/0063-2026-03-24-pass-port-batches-and-registry-map.md` still lists the same local alias in the GC/type boundary-only cluster
3. the just-landed `type-finalizing` dossier repeatedly shows that Binaryen exposes a **separate public sibling** `type-unfinalizing`, not just an internal mode bit
4. the sibling has the same core implementation file and the same dedicated lit test surface, but its contract is different in a teaching-important way: it reopens **all private types**, not just private leaves
5. without a separate folder it is too easy to mis-teach the sibling as either a synonym for `type-finalizing`, a closed-world preparatory pass, or a broad type optimizer

So even though the engine is shared, the public pass identity is real enough to deserve its own canonical wiki home.

## Main source set

Primary official Binaryen `version_129` sources consulted:

- `src/passes/TypeFinalizing.cpp`
- `src/passes/pass.cpp`
- `test/lit/passes/type-finalizing.wast`

Important helper surfaces the pass depends on conceptually:

- `ModuleUtils::getPrivateHeapTypes(...)`
- `GlobalTypeRewriter`
- `TypeBuilder::setOpen(...)`
- `SubTypes` only insofar as the sibling deliberately **does not** need it for its own legality proof

For helper meaning and neighboring context, I also cross-checked existing repo dossiers already grounded in official sources:

- `docs/wiki/binaryen/passes/type-finalizing/*`
- `docs/wiki/binaryen/passes/remove-unused-types/*`
- `docs/wiki/binaryen/passes/type-merging/*`

## High-level conclusion

Binaryen `type-unfinalizing` is a tiny GC-only module pass that:

1. exits immediately when GC is disabled
2. collects the module's **private** heap types
3. rebuilds the type graph coherently through `GlobalTypeRewriter`
4. toggles those selected private type-builder entries to **open** with `setOpen(true)`

The pass is therefore best understood as:

- **private type reopening**
- not general type simplification
- not subtype pruning
- not declaration deletion
- not a closed-world analysis pass

A good beginner summary is:

- `type-finalizing` finalizes safe private leaves
- `type-unfinalizing` reopens private types again
- both are tiny whole-module type-state passes over one shared engine

## What the pass is *not*

This pass is **not**:

- dead-type removal
- type merging
- subtype-edge pruning
- field/signature inference
- AST refinalization
- a default no-DWARF `-O` / `-Os` pipeline pass
- a closed-world-only preparation step

The real implementation is much narrower:

- pick private heap types
- set them open through one global type rewrite
- leave public types alone

## Scheduler / pipeline status

From `pass.cpp` and the repo's `no-dwarf-default-optimize-path.md`:

- `type-unfinalizing` is a **real public registered Binaryen pass**
- it is **not** in the reviewed default no-DWARF `-O` / `-Os` path
- it does **not** appear in the saved generated-artifact `-O4z` skipped-pass audit
- the local Starshine registry tracks the sibling under the alias `type-un-finalizing`
- locally it remains **boundary-only** and unimplemented

So this is another deliberate upstream-only registry expansion.

## Core implementation structure

`TypeFinalizing.cpp` contains one shared implementation:

- `struct TypeFinalizing : public Pass`
- constructor flag `bool finalize`

The public constructors split it into siblings:

- `createTypeFinalizingPass()` => `TypeFinalizing(true)`
- `createTypeUnFinalizingPass()` => `TypeFinalizing(false)`

That means `type-unfinalizing` is not a separate large file.
It is a separate **public pass identity** over the same engine.

## Phase-by-phase reading of the upstream implementation

### Phase 1: GC gate

The first hard gate is:

- return immediately if `!module->features.hasGC()`

So the sibling is GC-only for the same reason the finalizing mode is GC-only: final/open nominal heap-type state only matters when GC heap types exist.

### Phase 2: private-type boundary

The pass collects candidates from:

- `ModuleUtils::getPrivateHeapTypes(*module)`

That means the sibling only changes **private** heap types.
Public heap types stay untouched even when the goal is only to make the graph more permissive.

This is the biggest beginner correction:

- `type-unfinalizing` does **not** mean “make every type open again”
- it means “reopen the private types Binaryen is allowed to rewrite internally”

### Phase 3: no leaf proof required for the sibling

When `finalize == true`, the shared implementation builds:

- `SubTypes(*module)`

and checks for immediate children before changing a type.

When `finalize == false`, it does **not** do that.
The sibling simply inserts every private type into the modifiable set.

So the key source-backed split is:

- finalizing: private **leaf** types only
- unfinalizing: **all private** types

This is why a separate dossier is worth having.
The sibling is not just “the same thing backward”; it has a visibly broader modification set.

### Phase 4: tiny actual mutation

The local `TypeRewriter : public GlobalTypeRewriter` overrides:

- `modifyTypeBuilderEntry(TypeBuilder& typeBuilder, Index i, HeapType oldType)`

If the old type is modifiable, it runs:

- `typeBuilder[i].setOpen(!parent.finalize);`

For the sibling that means exactly:

- `setOpen(true)`

So the actual behavioral core of `type-unfinalizing` is one tiny state toggle during a coherent module-wide rewrite.

### Phase 5: module-wide rewrite handoff

The pass finishes with:

- `TypeRewriter(*module, *this).update();`

That is why the pass safely updates more than the declaration line itself.
The helper rebuilds the type graph and remaps uses consistently.

A future port must preserve that whole-module coherence.
A text-only declaration tweak would not be enough.

## What the dedicated lit file proves for the sibling

`test/lit/passes/type-finalizing.wast` covers both siblings.
For `type-unfinalizing`, it proves several durable points.

### Lit family 1: private final types reopen

The first module includes a final private type.
Running `--type-unfinalizing` makes it open.

That is the simplest positive case.

### Lit family 2: public final types stay final

The same module includes a final public type.
Running `--type-unfinalizing` leaves it alone.

That is the cleanest upstream proof that private-vs-public visibility still governs the sibling.

### Lit family 3: non-leaf private parents may reopen too

The second module includes a parent with children.
The finalizing mode cannot mark that parent final, but the unfinalizing mode can still reopen private types because it does not need the leaf proof.

This is the deepest teaching difference between the siblings.

### Lit family 4: function heap types participate

The test file also includes a function heap type.
That proves the sibling is not only about struct declarations.
Nominal function heap types are part of the same final/open graph.

## Important non-obvious rule: no closed-world requirement

It would be easy to assume that “reopen private types before later GC rewrites” must be a closed-world-only operation.
But `TypeFinalizing.cpp` does **not** ask for closed world.

The actual upstream safety argument is smaller:

- only private types are touched
- the module-wide helper rewrites the graph coherently

So the pass is more like a private type-state cleanup than a whole-program inference phase.

## Important non-obvious rule: no explicit `ReFinalize`

Like `type-finalizing`, the sibling does **not** call `ReFinalize`.
That makes sense once the implementation is clear:

- the pass is not walking function bodies to tighten expression result types
- it is rebuilding heap-type declarations and their uses through the global type-rewrite helper

So the absence of an explicit AST refinalization step is part of the real contract, not an omission in the docs.

## WAT / IR shape families that matter

This pass is module-shape-driven more than expression-driven.
The main families are:

### Positive shapes

- final private singleton type becomes open
- final private child type becomes open
- final private function heap type becomes open
- globals/locals/signatures that mention those types stay coherent after the global rewrite

### Preserved shapes

- any public type, open or final, stays exactly as declared
- non-GC modules are no-ops
- expression bodies are not directly optimized

### Bailout / non-goal shapes

- no type deletion for unused declarations
- no type merging for equivalent declarations
- no subtype-edge removal
- no cast insertion or cast tightening
- no field retyping

## Practical sibling comparison

A concise comparison table captures the family best:

| Pass | Candidate set | Safety proof | Actual mutation |
| --- | --- | --- | --- |
| `type-finalizing` | private leaf types | must prove no immediate subtypes | `setOpen(false)` |
| `type-unfinalizing` | private types | privacy only | `setOpen(true)` |

That table is the cleanest mental model for beginners and future ports.

## What a future Starshine port must preserve

A faithful local `type-un-finalizing` port should preserve at least these rules:

1. local-vs-upstream naming split: local `type-un-finalizing`, upstream `type-unfinalizing`
2. public pass identity separate from `type-finalizing`
3. GC-only gate
4. private-type visibility boundary
5. no leaf restriction for the unfinalizing sibling
6. coherent module-wide heap-type remap through a global helper
7. function heap types participate too
8. no closed-world requirement upstream
9. no expression-level optimization or explicit AST refinalization phase

## Biggest beginner correction

If someone says:

- “`type-unfinalizing` is just a generic prep pass that opens all types before other optimizations”

that is too broad.
A much better sentence is:

- “Binaryen `type-unfinalizing` is a tiny GC-only module pass that reopens private heap types through the same global type-rewrite engine used by `type-finalizing`, but without the leaf-only restriction.”

## Sources

Official Binaryen `version_129` sources:

- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/TypeFinalizing.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/type-finalizing.wast>

Repo-local supporting sources:

- `src/passes/optimize.mbt`
- `docs/0063-2026-03-24-pass-port-batches-and-registry-map.md`
- `docs/wiki/binaryen/passes/type-finalizing/*`
