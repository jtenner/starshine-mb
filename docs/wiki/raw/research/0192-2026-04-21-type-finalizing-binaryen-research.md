# Binaryen `type-finalizing` research

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
- neighboring GC/type dossiers, especially `remove-unused-types`, `type-merging`, `type-generalizing`, and `unsubtyping`

The original no-DWARF queue, the saved generated-artifact `-O4z` queue, and the first widened tracker-expansion wave are already dossier-covered.
So this thread explicitly expands the tracker again to cover another real local-registry pass that still had no dedicated landing folder.

I picked exactly one pass:

- `type-finalizing`

I did **not** pick `type-generalizing` again.
I did **not** pick any excluded pass from the campaign list.

`agent-todo.md` currently has **no dedicated `type-finalizing` slice**.

## Why `type-finalizing` is a justified next target

This pass is a good tracker expansion because:

1. it is still named directly in the local boundary-only registry in `src/passes/optimize.mbt`
2. it sits in the same GC/type cluster as already-documented passes like `remove-unused-types`, `type-merging`, and `unsubtyping`
3. the local registry also names the sibling alias `type-un-finalizing`, so there is a real family-level teaching gap around final/open nominal types
4. Binaryen exposes `type-finalizing` as a real public pass in `version_129`, with a dedicated lit file
5. the implementation is tiny enough to misread badly unless the helper contracts and visibility rules are spelled out carefully

The neighboring `type-merging` research note already called out `type-finalizing` and `type-unfinalizing` as possible future expansions.
This thread closes one of those explicitly.

## Main source set

Primary official Binaryen `version_129` sources consulted:

- `src/passes/TypeFinalizing.cpp`
- `src/passes/pass.cpp`
- `test/lit/passes/type-finalizing.wast`

Important helper surfaces the pass depends on conceptually:

- `ModuleUtils::getPrivateHeapTypes(...)`
- `SubTypes`
- `GlobalTypeRewriter`
- `TypeBuilder::setOpen(...)`

For the helper meanings, I also cross-checked the existing repo dossiers that already distilled those shared helper contracts from official Binaryen sources:

- `docs/wiki/binaryen/passes/remove-unused-types/*`
- `docs/wiki/binaryen/passes/type-merging/*`
- `docs/wiki/binaryen/passes/signature-pruning/*`

## High-level conclusion

Binaryen `type-finalizing` is **not** a broad optimization pass.
It is a tiny whole-module GC type-graph cleanup pass that:

1. exits immediately when GC is disabled
2. collects the module's **private** heap types
3. if finalizing, filters that set down to **leaf** private types only
4. rebuilds the type section through `GlobalTypeRewriter`
5. toggles the selected type-builder entries from open to final

Its sibling `type-unfinalizing` / local alias `type-un-finalizing` uses the exact same engine, but toggles the chosen private types in the opposite direction.

A good beginner summary is:

- `type-finalizing` makes private leaf nominal types final
- `type-unfinalizing` makes private nominal types open again
- both use a global type-section rewrite helper rather than a function-body walk

## What the pass is *not*

This pass is **not**:

- dead-type elimination
- type merging
- subtype-edge pruning
- expression refinalization
- closed-world field/type inference
- a default `-O` / `-Os` optimization-pipeline pass

The actual implementation is much narrower:

- it only changes the open/final bit on selected private heap types
- it does so by rebuilding module type definitions coherently
- it does not do local CFG reasoning, effect analysis, or dataflow analysis

## Pipeline / scheduler status

From `pass.cpp` and the repo's `no-dwarf-default-optimize-path.md`:

- `type-finalizing` is a **real public registered pass** in Binaryen `version_129`
- it is **not** in the reviewed default no-DWARF `-O` / `-Os` path
- it does **not** appear in the saved generated-artifact `-O4z` skipped-slot audit
- in the local Starshine registry it remains **boundary-only** and unimplemented

So this dossier is another deliberate upstream-only registry expansion, not parity-queue archaeology.

## The core implementation structure

`TypeFinalizing.cpp` defines one small pass class:

- `struct TypeFinalizing : public Pass`

with one controlling field:

- `bool finalize;`

The two public passes are just two constructor modes:

- `createTypeFinalizingPass()` => `TypeFinalizing(true)`
- `createTypeUnFinalizingPass()` => `TypeFinalizing(false)`

That is the first durable teaching point:

- Binaryen treats finalizing and unfinalizing as **sibling passes over one shared engine**, not as unrelated implementations.

## Phase-by-phase reading of `TypeFinalizing.cpp`

### Phase 1: GC gate

The very first check is:

- if the module does not have GC, return immediately

So this is a **GC-only** pass family.

That matches the meaning of nominal final/open heap types: without GC nominal types, there is nothing to rewrite.

### Phase 2: subtype graph only when finalizing

When `finalize == true`, the pass constructs:

- `SubTypes(*module)`

It does **not** do that for unfinalizing.

Reason:

- to make a type final safely, Binaryen must know that the type has **no subtypes**
- to make a type open again, no subtype check is needed

This is one of the cleanest examples in the pass corpus of a sibling sharing nearly all code while differing by one exact safety proof.

### Phase 3: private-type visibility boundary

The pass then collects:

- `ModuleUtils::getPrivateHeapTypes(*module)`

This is the most important safety boundary.

The pass only modifies **private** heap types.
It deliberately leaves **public** heap types alone.

That makes the pass easy to under-teach.
If you only say “mark all types final,” you are saying something false.
The source does **not** do that.

It marks only the types Binaryen is allowed to rewrite safely in the module's internal world.

### Phase 4: leaf filter for finalization

For each private type:

- if unfinalizing, the pass always allows it
- if finalizing, the pass only allows it when `getImmediateSubTypes(type).empty()`

So `type-finalizing` is really:

- **finalize private leaf types**

not:

- finalize every private type

This leaf rule is the most important semantic contract in the whole pass.

### Phase 5: one tiny `GlobalTypeRewriter` subclass

The pass then creates a local subclass:

- `class TypeRewriter : public GlobalTypeRewriter`

and overrides only:

- `modifyTypeBuilderEntry(TypeBuilder& typeBuilder, Index i, HeapType oldType)`

If the old type is in the `modifiableTypes` set, it runs:

- `typeBuilder[i].setOpen(!parent.finalize);`

That means:

- `finalize == true` => set open bit to `false`
- `finalize == false` => set open bit to `true`

The entire pass's visible behavior reduces to that one toggle, plus the helper machinery that applies it coherently across the module.

### Phase 6: global rewrite handoff

Finally the pass runs:

- `TypeRewriter(*module, *this).update();`

This matters a lot.
The pass is not editing one type declaration in place and hoping the rest of the module still lines up.
It delegates to the same whole-module type-section rewrite infrastructure already visible in other GC/type dossiers.

That is why the pass can safely update:

- type declarations
- global types
- local types
- signature references
- any other heap-type uses that need the remapped graph

## What the dedicated lit file proves

`test/lit/passes/type-finalizing.wast` is small, but it proves the real contract surprisingly well.

### Lit family 1: public types never change

The first module includes:

- open public type
- final public type
- final private type
- open private type
- globals typed with references to those heap types
- exports keeping the public globals observable

The checks show:

- public types remain exactly as they were under both sibling passes
- private types change according to the selected mode

That is the clearest upstream proof that the pass is visibility-gated, not universal.

### Lit family 2: finalizing does not finalize parents with subtypes

The second module adds a small subtype tree:

- one parent
- one open child
- one final child

The checks show:

- the parent always stays open
- the children can be opened or finalized according to the sibling mode

This proves the leaf-only rule.

### Lit family 3: function heap types participate too

The same second module also keeps alive a function heap type used by a function declaration and locals.
The checks show that function types also participate in the open/final rewrite.

That matters because a beginner might wrongly assume this pass is only about struct/array types.
The implementation and lit file show it works over heap types more generally.

## Important positive module-shape families

### Positive family A: private open leaf type becomes final

Typical shape:

```wat
(type $leaf (sub (struct (field i32))))
```

After `type-finalizing`, Binaryen can print the finalized leaf as:

```wat
(type $leaf (struct (field i32)))
```

This is the core public example from the lit file.

### Positive family B: private final leaf type becomes open under the sibling

Typical shape:

```wat
(type $leaf (sub final (struct (field i64))))
```

After `type-unfinalizing`, Binaryen prints the type as open:

```wat
(type $leaf (sub (struct (field i64))))
```

### Positive family C: function heap types are rewritten too

The lit file's synthetic function type demonstrates that the pass also updates function-type declarations and the places that reference them.

### Positive family D: globals and locals keep following the remapped type graph

The test's globals and locals remain valid after the pass because the rewrite goes through `GlobalTypeRewriter`, not a naive text mutation.

## Important negative / bailout families

### Negative family A: no GC means no pass effect

If GC is off, the pass returns immediately.

### Negative family B: public heap types are never modified

Even if a public type is private-looking structurally, the pass leaves it alone because observability matters more than canonicalization here.

### Negative family C: non-leaf private types cannot be finalized

A parent with immediate subtypes remains open under `type-finalizing`.

### Negative family D: no function-body pattern matching

There is no visitor over:

- `struct.get`
- `struct.set`
- casts
- locals
- control flow

Any visible body changes are consequences of the global type remap, not AST optimization.

### Negative family E: no refinalization pass step

Unlike `type-merging`, `type-generalizing`, `gufa*`, or `signature-refining`, this pass does **not** call `ReFinalize`.

That makes sense: final/open declaration bits change the nominal type graph and its references, but this pass is not performing expression-level type narrowing that needs a second AST type recomputation walk.

I am treating that as a source-backed observation, not as a stronger theorem about every future variant.

## Easy-to-misunderstand details

### Misunderstanding 1: “finalizing all types”

False.
The pass only modifies:

- private heap types
- and, when finalizing, only those with no immediate subtypes

### Misunderstanding 2: “needs closed world”

The source does **not** request `ClosedWorld`.
That is notable because many neighboring GC/type passes do.

The pass gets away without it by restricting itself to private types and by leaving public observable type relationships untouched.

### Misunderstanding 3: “must worry about JS configureAll callers”

The source comment explicitly says it does not need to worry about signature-called functions here because those calls do not care about finality.

That is a subtle and useful sibling-specific rule.

### Misunderstanding 4: “same as remove-unused-types or type-merging”

Not true.

- `remove-unused-types` removes dead private types
- `type-merging` merges compatible live private types
- `unsubtyping` removes unnecessary subtype relations
- `type-finalizing` only toggles open/final state on a safe subset of surviving private types

## Neighbor interactions worth preserving in a future port

A future Starshine port should keep these distinctions explicit:

- `remove-unused-types` and `type-merging` can change *which* private types exist
- `type-finalizing` changes whether surviving private leaf types are open or final
- `type-unfinalizing` can be used as the inverse cleanup/setup sibling when a workflow wants more flexible internal types during transformation and more final leaf types afterward

The top-of-file comment in `TypeFinalizing.cpp` makes that workflow explicit in plain language: a typical pattern is to unfinalize before doing lots of optimizations, then finalize at the end.

That suggests this family is best taught as **type-graph mode cleanup**, not as a standalone optimizer.

## Future Starshine port invariants

A faithful Starshine implementation should preserve at least these invariants:

1. **GC gate**
   - do nothing when GC is disabled
2. **public/private boundary**
   - only private heap types are candidates
3. **leaf-only finalization**
   - `type-finalizing` must never finalize a type with immediate subtypes
4. **unconditional sibling reopening**
   - `type-unfinalizing` may reopen private types without the leaf check
5. **shared engine split**
   - the siblings should stay one implementation with a mode bit, not drift into unrelated behavior
6. **global rewrite helper**
   - perform a coherent module-wide heap-type rewrite, not local ad hoc edits
7. **public observability caution**
   - do not start mutating public types casually just because the local registry names the pass
8. **no fake analysis inflation**
   - do not pretend this needs CFG, effects, or dataflow reasoning when upstream does not
9. **no accidental refinalization dependency**
   - do not add an AST refinalization phase unless the local implementation truly needs one for correctness
10. **naming honesty**
    - keep the local registry spelling split explicit: Starshine tracks `type-un-finalizing`, while upstream registers `type-unfinalizing`

## Open questions or deliberate non-goals

I did **not** turn this thread into a second dedicated dossier for `type-un-finalizing`.
I only documented that sibling where necessary to explain `type-finalizing` correctly.
A future thread could still justify a separate landing folder for the sibling if the campaign wants one exact page per public/local pass name.

I also did not try to recover a default preset slot because the reviewed sources here show this as a standalone registered pass, not as a default no-DWARF scheduler step.

## Deliverables filed back into the wiki

This note feeds a new living folder:

- `docs/wiki/binaryen/passes/type-finalizing/`

with:

- `index.md`
- `binaryen-strategy.md`
- `implementation-structure-and-tests.md`
- `leaf-types-public-boundaries-and-sibling-split.md`
- `wat-shapes.md`

It also requires shared catalog updates in:

- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/index.md`
- `docs/wiki/log.md`

## Source list

Repo sources consulted first:

- `docs/README.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
- `agent-todo.md`
- `src/passes/optimize.mbt`
- `docs/0063-2026-03-24-pass-port-batches-and-registry-map.md`
- `docs/wiki/raw/research/0181-2026-04-21-type-merging-binaryen-research.md`

Official Binaryen `version_129` sources:

- `src/passes/TypeFinalizing.cpp`
- `src/passes/pass.cpp`
- `test/lit/passes/type-finalizing.wast`

Supporting helper interpretations cross-checked against existing repo dossiers that already distilled official Binaryen helper behavior:

- `docs/wiki/binaryen/passes/remove-unused-types/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/type-merging/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/signature-pruning/binaryen-strategy.md`
