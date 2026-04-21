# Binaryen `type-generalizing` / upstream `experimental-type-generalizing` research

- Date: 2026-04-21
- Researcher: OpenAI Codex
- Scope: source-backed wiki expansion for the local boundary-only registry entry `type-generalizing`
- Status: supported, upstream-only dossier seed

## Why this note exists

The main no-DWARF / saved `-O4z` parity queues are already dossier-covered, and the wider upstream-only registry wave is mostly covered too.
The local registry in `src/passes/optimize.mbt` still contains `type-generalizing`, but there was no dedicated living dossier for it yet.

This pass is a good tracker expansion because:

- it is still named in the local boundary-only registry
- it sits directly beside already-documented GC/type passes like `type-refining`, `signature-*`, `global-type-optimization`, `abstract-type-refining`, `type-merging`, and `unsubtyping`
- the upstream implementation is real and source-readable in Binaryen `version_129`
- the teaching surface is easy to misread from the local alias alone, because upstream actually publishes two **experimental** pass names:
  - `experimental-type-generalizing`
  - `experimental-type-generalizing-with-optimizing-casts`

## Local status and scheduler relevance

- Local registry status: `boundary-only` in `src/passes/optimize.mbt`
- Local registry name: `type-generalizing`
- Upstream public names in `pass.cpp`:
  - `experimental-type-generalizing`
  - `experimental-type-generalizing-with-optimizing-casts`
- Canonical no-DWARF `-O` / `-Os` path: **not scheduled** there
- Saved generated-artifact `-O4z` skipped-slot audit: **not observed** there
- `agent-todo.md`: **no dedicated slice** for `type-generalizing` or the upstream experimental names

So this is a deliberate tracker expansion, not a parity-queue dossier.

## Main upstream sources consulted

Primary implementation and registration sources:

- Binaryen `version_129` `src/passes/TypeGeneralizing.cpp`
- Binaryen `version_129` `src/passes/pass.cpp`
- Binaryen `version_129` `test/lit/passes/type-generalizing.wast`
- Binaryen `version_129` `test/lit/passes/type-generalizing-with-optimizing-casts.wast`

Important neighboring/helper sources:

- `src/ir/possible-contents.h` for `ContentOracle`
- `src/ir/lubs.h` for the LUB helper used on possible contents
- existing local dossiers for `type-refining`, `type-merging`, `gufa`, and `gufa-cast-all`

## High-level contract

This pass is **not** a general heap-type optimizer.
It is a small closed-world GC pass that tries to make a few expression types more precise when Binaryen can prove a narrower subtype at the use site.

The actual visitor surface in `version_129` is tiny:

- `visitStructGet`
- `visitStructSet`
- `visitCallRef`
- `visitRefCast`

That small visitor roster is one of the most important teaching facts.
The pass name sounds broad, but the implementation is narrow.

## The two experimental siblings

The constructor takes one boolean:

- `optimizeCasts`

Upstream publishes two pass constructors:

- `createTypeGeneralizingPass()` → `optimizeCasts = false`
- `createTypeGeneralizingWithOptimizingCastsPass()` → `optimizeCasts = true`

So the family split is:

- plain experimental type generalizing
- same pass plus one extra cast-tightening behavior

This is analogous to several other Binaryen sibling dossiers in the wiki: same engine, different flag.

## Required gates and assumptions

`getPassOptions()` requests:

- `PassOptions::ClosedWorld`
- `optimizeLevel = 3`

The pass also returns `isFunctionParallel() = true`.

Practical reading:

- closed-world knowledge is required
- this is intended as a fairly aggressive late type-shaping pass, not an early open-world cleanup
- each function can be visited independently once module-wide knowledge exists

## Core dependency: `ContentOracle`

The pass stores:

- `std::unique_ptr<ContentOracle> contentOracle;`

and builds it in `doWalkModule` with:

- `contentOracle = std::make_unique<ContentOracle>(wasm, getPassOptions());`

This is the same whole-program possible-contents analysis family already documented for `gufa`.
The pass does **not** invent a new inference engine.
It consumes oracle facts.

## What the pass really tries to improve

The central idea is:

- if a reference-producing site is statically typed too broadly,
- and closed-world possible-contents information proves a narrower subtype is always what reaches it,
- then Binaryen can rewrite the operation to expose that narrower type.

But in `version_129`, Binaryen only does this in a few carefully selected shapes.

## Phase breakdown

### 1. Build the oracle

`doWalkModule` first constructs the `ContentOracle` for the whole module.

### 2. Walk each function in parallel

The pass is a `WalkerPass<PostWalker<TypeGeneralizing>>`, so it visits the supported expressions post-order.

### 3. Retype a few supported shapes

The pass directly mutates expression and field types in place when it can prove a narrower safe type.

### 4. Refinalize only if something changed

At the end of `doWalkFunction`, it checks `getModule()->features.hasGC()` and `refinalize = true`, then runs `ReFinalize().walkFunctionInModule(curr, getModule())`.

Important implication:

- this pass is GC-only in practice
- it relies on post-rewrite refinalization for correctness

## Detailed rewrite surface

### A. `visitStructGet`

The pass only handles nullable reference result types here.
If the current `struct.get` result type is not nullable, it returns early.

Then it asks the oracle for the possible contents of the receiver expression and computes a LUB over the heap types of those possible contents.
If Binaryen finds a `leastUpperBound` and that LUB is a subtype of the current heap type, it rewrites the expression type to:

- same nullability as before
- narrower heap type from the oracle

So the pass can turn a broad nullable result like “nullable parent field type” into “nullable narrower child field type” when the receiver is known to always be a narrower struct.

### B. `visitStructSet`

This is similar but acts on the **field type** being written.

The pass:

- checks the receiver's possible contents
- finds the field type in the inferred narrower receiver heap type
- if that field type is a subtype of the field type currently named by the `struct.set`, rewrites `curr->field.type`

So this pass can make the write-side field type more precise too.

This is easy to miss because many people expect “type generalizing” to only touch result types, but the upstream implementation also rewrites the write-side field signature.

### C. `visitCallRef`

This is the richest rewrite.

The pass:

- asks the oracle for possible contents of the call target expression
- collects the signatures of all reachable function targets
- if there is no possible target, returns early
- if the set of possible signatures is empty, rewrites the target to `unreachable`
- if there is more than one possible signature, bails
- if exactly one signature remains, narrows `curr->target->type` to `Type(sig, NonNullable)`
- then checks whether the call result type can be narrowed to the signature's result type and rewrites `curr->type` if so

This gives the pass two visible `call_ref` wins:

- target type sharpening
- result type sharpening

And one strong bailout boundary:

- if multiple different signatures remain possible, no rewrite

### D. `visitRefCast`

This behavior is only enabled when `optimizeCasts` is true, which is why upstream exposes a second experimental pass name.

The pass looks at the operand's possible contents and computes a LUB heap type.
If it can prove a narrower heap type than the cast target's current heap type, it rewrites the cast target type.

So the extra sibling is not a different algorithm.
It is plain type generalizing plus cast-target tightening.

## Negative and bailout rules

The main preserved/no-op boundaries in `version_129` are:

- no GC features → no meaningful effect
- no closed-world facts → pass is not intended to run
- unsupported node kinds outside the four visitors → untouched
- `struct.get` with non-nullable result type → untouched by this visitor
- no oracle LUB → no type change
- inferred type not a subtype of current type → no type change
- `call_ref` with multiple possible signatures → no type change
- cast optimization disabled → `ref.cast` untouched

These negative cases are as important as the positive ones because they show the pass is conservative.

## Why the pass is easy to misunderstand

### Misread 1: “It is the same as `type-refining`.”

It is not.

`type-refining` is a broader closed-world type pass over struct field traffic and read/write repair.
`experimental-type-generalizing` is a much narrower consumer of oracle facts on four expression families.

### Misread 2: “It is the same as `gufa-cast-all`.”

Also false.

`gufa-cast-all` can insert **new** casts after the shared GUFA rewrite phase.
This pass only tightens types already attached to certain existing expressions.
It does not insert arbitrary new cast scaffolding.

### Misread 3: “Generalizing means making types broader.”

The upstream name is counterintuitive.
Operationally, the pass usually makes visible types **narrower / more precise** at specific use sites.

## What the test files prove

### `type-generalizing.wast`

The base lit file shows the plain sibling.
It demonstrates:

- `struct.get` result narrowing
- `struct.set` field-type narrowing
- `call_ref` target/result sharpening when the possible target set collapses to one signature
- preserved no-op cases when the proof is insufficient

### `type-generalizing-with-optimizing-casts.wast`

The second lit file proves the sibling split is real.
It shows that enabling `optimizeCasts` lets Binaryen tighten `ref.cast` target types using the same underlying oracle facts.

## Important implementation boundaries for a future Starshine port

A faithful port would need to preserve at least these rules:

1. local registry alias versus upstream experimental pass-name split
2. hard dependence on closed-world analysis
3. reuse of a whole-program possible-contents oracle
4. tiny supported visitor surface: `struct.get`, `struct.set`, `call_ref`, `ref.cast`
5. one-signature-only rule for `call_ref`
6. exact `unreachable` rewrite when `call_ref` target set is impossible
7. sibling flag split for cast optimization
8. post-pass refinalization when GC is enabled and anything changed

## Relationship to nearby passes

The best way to situate this pass is:

- earlier or parallel analysis family: `gufa`, `gufa-cast-all`
- nearby type-tightening family: `type-refining`, `signature-refining`, `abstract-type-refining`
- later type-compaction family: `type-merging`, `unsubtyping`

It is a narrow bridge pass, not a whole-cluster replacement.

## Suggested living-page structure

Recommended dossier pages:

- landing page
- `binaryen-strategy.md`
- `implementation-structure-and-tests.md`
- focused page on call_ref, casts, and exactness/bailouts
- `wat-shapes.md`

## Open questions and uncertainty

- I did not find this pass in the default no-DWARF or saved `-O4z` queue material, so this remains a registry expansion rather than a parity target.
- I did not do a full current-`main` drift audit beyond the `version_129` source-backed reading and the visible continued presence of the files and test names. If a future thread wants a freshness audit, it should compare current `main` `TypeGeneralizing.cpp`, `pass.cpp`, and both lit files directly.
- The local registry currently uses the simpler alias `type-generalizing`, while upstream explicitly labels both public names as `experimental-*`. A future port/design thread should decide whether the local name should stay simplified or grow the upstream experimental spelling too.

## Durable conclusion

Binaryen `type-generalizing` in local registry terms is really the upstream experimental pair `experimental-type-generalizing` and `experimental-type-generalizing-with-optimizing-casts`.
Its real `version_129` contract is a small closed-world GC oracle consumer that narrows types on `struct.get`, `struct.set`, `call_ref`, and optionally `ref.cast`, then refinalizes.
It is not a generic type optimizer, not a scheduler-default pass, and not already explained well enough by neighboring dossiers.
