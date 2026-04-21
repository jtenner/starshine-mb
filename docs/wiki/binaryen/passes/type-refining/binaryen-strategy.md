---
kind: concept
status: supported
last_reviewed: 2026-04-21
sources:
  - ../../../raw/research/0150-2026-04-21-type-refining-binaryen-research.md
related:
  - ./index.md
  - ./implementation-structure-and-tests.md
  - ./normal-vs-gufa-and-fixups.md
  - ./wat-shapes.md
  - ../global-refining/index.md
  - ../remove-unused-types/index.md
---

# Binaryen `type-refining` strategy

## Upstream source rule

Use Binaryen `version_129` as the current source oracle for this pass.

Primary files:

- `src/passes/TypeRefining.cpp`
- `src/passes/pass.cpp`
- `src/ir/struct-utils.h`
- `src/ir/lubs.h`
- `src/ir/possible-contents.h`
- `src/ir/type-updating.h`
- `src/ir/module-utils.h`
- `test/lit/passes/type-refining.wast`
- `test/lit/passes/type-refining-gufa.wast`
- `test/lit/passes/type-refining-gufa-exact.wast`
- `test/lit/passes/type-refining-gufa-rmw.wast`

I also did a narrow current-`main` check on the same surfaces.
Durable result:

- the checked `main` pass file still matches the reviewed `version_129` logic on the important gates, phase split, and fixup structure
- the checked pass registration and dedicated lit families still match on the reviewed surfaces

So this dossier treats `version_129` as the normative algorithm oracle.

## High-level intent

Binaryen uses `type-refining` to make **private struct fields** more specific when the whole closed-world module proves that every written value fits a narrower type.

That is more precise than either of these summaries:

- make types narrower
- infer GC types better

The real contract is closer to:

- **infer field contents from writes, preserve hierarchy legality, rewrite private struct declarations, then repair invalidated reads and writes**

## The pass in one table

| Phase | What Binaryen does | Why it exists |
| --- | --- | --- |
| Gate on GC + closed world | Require GC and `--closed-world` in the pass body | Open world is outside the proof boundary |
| Pick inference engine | Either direct `StructScanner` mode or `ContentOracle` / GUFA mode | Upstream ships two pass names with shared back-end rewriting |
| Infer field LUBs | Record written values per field and propagate through the struct hierarchy | Build the most specific safe field types Binaryen can justify |
| Freeze public types | Skip all public struct types | External ABI must remain stable here |
| Repair subtype legality | Make child fields compatible with refined super fields and mutability rules | Field refinement must still validate in the heap-type hierarchy |
| Repair reads | Replace impossible `struct.get`s with trap-equivalent unreachable code or retag valid gets | Reads do not constrain inference, so they must be fixed afterward |
| Rewrite types | Use `GlobalTypeRewriter` to update private struct declarations module-wide | Heap-type rewriting is global, not just local text patching |
| Refinalize + repair writes | Run `ReFinalize`, then add casts / nulls / `unreachable` at affected writes | New field types can make old write expressions too broad |

## Scheduler placement

`type-refining` is not part of the repo's main open-world no-DWARF path.

The relevant upstream `pass.cpp` neighborhood is:

- if GC is enabled and `optimizeLevel >= 2`
- and if `closedWorld`
- then run:
  - `type-refining`
  - `signature-pruning`
  - `signature-refining`
- then:
  - `global-refining`
  - optional `gto`
  - `remove-unused-module-elements`
  - optional `remove-unused-types`
  - optional `cfp` / `cfp-reftest`
  - `gsi`
  - optional `abstract-type-refining`
  - optional `unsubtyping`

That means this pass is an **early closed-world GC/type-tightening prepass**.
It is not a late cleanup and not part of the open-world parity queue this repo uses for the MoonBit debug artifact.

## Important scheduler subtlety: optimize level is a pipeline gate, not a pass-body gate

The default pipeline only adds `type-refining` when `optimizeLevel >= 2`.

But `TypeRefining::run(Module* module)` itself checks only:

- `module->features.hasGC()`
- `getPassOptions().closedWorld`

So if a user invokes `--type-refining` directly, the pass does not inspect `optimizeLevel` itself.
That optimize-level condition belongs to the default scheduler, not to the core algorithm.

## Phase 0: strict early pass-body gates

`TypeRefining::run(Module* module)` begins by:

- returning immediately on `!module->features.hasGC()`
- `Fatal()`ing if `!getPassOptions().closedWorld`

This is a real semantic boundary.
The pass is not trying to be “mostly okay” in open world.

## Phase 1: shared back end, two different inference front ends

The top-level structure is:

- if `!gufa`, call `computeFinalInfos(module, propagator)`
- else call `computeFinalInfosGUFA(module, propagator)`
- then always call `useFinalInfos(module, propagator)`

That is the key teaching model.

- `type-refining` and `type-refining-gufa` do **not** differ mainly in the rewrite step
- they differ mainly in **how they infer what is written to each field**

## Phase 2: the normal variant uses `StructScanner`, not generic dataflow

The normal path constructs:

- `StructUtils::FunctionStructValuesMap<FieldInfo> functionNewInfos`
- `StructUtils::FunctionStructValuesMap<FieldInfo> functionSetGetInfos`
- `FieldInfoScanner scanner(...)`

and then runs the scanner on:

- function bodies with `scanner.run(...)`
- module code with `scanner.runOnModuleCode(...)`

The scanner is shared-infrastructure-heavy.
The important dependencies are:

- `StructUtils::StructScanner`
- `StructUtils::StructValuesMap`
- exactness-aware keys `(HeapType, Exactness)`
- `Properties::getFallthrough(...)`
- `LUBFinder`

### Important negative fact

The normal pass does **not** do general local/global/call flow analysis.
It watches direct struct traffic plus limited fallthrough copies.
That is why GUFA exists as a separate variant.

## Phase 3: field facts are LUB summaries, not full value sets

The pass defines:

- `using FieldInfo = LUBFinder;`

`LUBFinder` stores only the current least upper bound of everything noted so far.
So the pass is intentionally summarizing each field's possible contents instead of carrying a giant explicit value graph.

That keeps the pass small and conservative.

## Phase 4: default values preserve nullability without pinning wide heap types

`FieldInfoScanner::noteDefault(...)` has a subtle rule.
For ref fields it does **not** note the original declared heap type.
Instead it notes:

- bottom of the heap type
- but nullable

So default construction mainly means:

- “this field may be null”

It does **not** mean:

- “keep the old wide heap type forever”

This is why the tests can refine a field from `anyref` or `(ref null struct)` down to things like:

- `nullref`
- `nullfuncref`
- `(ref null $child)`

when the non-null writes are precise enough.

## Phase 5: reads do not constrain inference; copies sometimes do

`FieldInfoScanner::noteRead(...)` does nothing.
That means ordinary `struct.get` uses do not constrain the inferred field type.

Instead, the pass relies on later read repair.

But copies are treated specially.
`noteExpressionOrCopy(...)` tries to look through a limited fallthrough wrapper and, if the final producer is a `StructGet`, it calls `noteCopy(...)`.

### Same-field copies can be ignored

If the copy is literally:

- same source heap type
- same destination heap type
- same field index

then `noteCopy(...)` ignores it as not adding any new requirement.

That is why `struct.set` of `struct.get`-from-the-same-field can still optimize.

## Phase 6: tee / `br_if` fallthrough is deliberately excluded

The pass overrides `getFallthroughBehavior()` to return:

- `Properties::FallthroughBehavior::NoTeeBrIf`

The source comment gives the reason.
A `local.tee` fallthrough can leave the tee itself typed too broadly after field refinement, forcing extra casts later.
Rather than assume all of those repairs are worth it, the normal pass simply ignores those tee/`br_if` fallthroughs.

This explains an easy-to-miss test split:

- tee-based copied-read families may block refinement
- `if` / block / try families may still refine, because `ReFinalize` can update those control expressions later

## Phase 7: `struct.new` and `struct.set` traffic propagate differently

After scanning, the normal mode combines data and then propagates it in two different ways.

### `combinedNewInfos`

- `propagateToSuperTypes(combinedNewInfos)`

Rationale:

- `struct.new $Child` knows the exact concrete type being created
- that exact information must flow upward to shared super fields
- but it should not automatically flow downward into unrelated subtypes

### `combinedSetGetInfos`

- `propagateToSuperAndSubTypes(combinedSetGetInfos)`

Rationale:

- `struct.set` operates through a reference that may be inexact
- copies read from one field and write to another also need hierarchy-aware repair
- so Binaryen propagates this information both upward and downward

This is one of the main reasons the pass keeps exact and inexact entries separate in its struct-value maps.

## Phase 8: GUFA mode replaces the direct scanner with `ContentOracle`

The GUFA path does:

- `ContentOracle oracle(*module, getPassOptions());`
- iterate `ModuleUtils::collectHeapTypes(*module)`
- for each struct type, query `oracle.getContents(DataLocation{type, i}).getType()`

That lets upstream infer field contents through flows the normal pass does not model directly:

- locals
- globals
- calls
- cross-function cycles
- other whole-program edges GUFA understands

So the correct mental model is:

- the normal pass is a direct-struct-traffic refiner
- the GUFA pass is a whole-program contents-oracle refiner that reuses the same rewrite logic afterward

## Phase 9: GUFA exactness is stronger, but still constrained

The GUFA front end immediately applies three important brakes.

### 1. Do not introduce new exact fields when exact casts may be invalid

If the original field is not exact, GUFA uses:

- `withInexactIfNoCustomDescs(module->features)`

The dedicated `type-refining-gufa-exact.wast` file proves the point:

- with custom descriptors enabled, GUFA may refine to exact and insert later `ref.cast`s
- with custom descriptors disabled, it stays inexact in those cases
- fields that were already exact remain exact

### 2. Do not use inferred continuation types that later fixups cannot cast to

If GUFA infers a continuation type for a field, the pass falls back to the original field type.
The source comment is explicit that later cast repair is not available for that case.

### 3. Take global initializers into account because write fixups do not run there

GUFA explicitly scans non-imported global initializers for `StructNew` and notes the child operand types.
That protects the pass from refining a field so far that the global initializer would later need a cast, because the later `WriteUpdater` only repairs function bodies.

## Phase 10: public types are frozen before the main refinement walk

`useFinalInfos(...)` begins by computing:

- `ModuleUtils::getPublicHeapTypes(*module)`

and then skipping public types in the main type walk.

So this pass refines **private** struct types only.

The tests show two important consequences:

- public children can effectively make important ancestors unoptimizable too
- private descendants may still refine, but only when they remain legal relative to those frozen public ancestors

## Phase 11: unnoted fields fall back to the old type

During the main hierarchy walk, if a field has no noted writes at all, Binaryen sets its `LUBFinder` to the field's old type.

That prevents nonsense like “unreachable field type just because nothing was written directly to this child type.”
It is especially important when:

- a type is referenced but never instantiated
- a child type inherits pressure from a refined supertype

## Phase 12: subtype legality and mutability are enforced after inference

For each child field Binaryen compares it against the refined super field.

### If the child field is not a subtype of the refined super field

Binaryen copies the super field type down.
This handles cases where an unused child would otherwise become invalid after its parent refined.

### If the field is mutable

Binaryen forces the child field type to equal the super field type.
Mutable fields may not specialize relative to the super.

That is why public/mutable examples can end up as total no-ops while private/immutable examples still refine.

## Phase 13: `ReadUpdater` repairs reads before type rewriting

If anything changed, Binaryen first runs `updateInstructions(...)`.
That installs `ReadUpdater`, which visits `StructGet` in both function bodies and module code.

### Read outcome A: replace with trap-equivalent unreachable code

If:

- the reference is null
- or the new field type is `unreachable`
- or the new field type is not a subtype of the old `struct.get` result type

Binaryen replaces the `struct.get` with:

- `drop(ref)`
- `unreachable`

This is the origin of the test comments about:

- `replaces unreachable StructGet we can't emit`

### Read outcome B: retag the `struct.get` directly

Otherwise it simply sets:

- `curr->type = newFieldType`

The source comment explains why this direct retagging is necessary even though `ReFinalize` comes later: recursive bottoming-out cases can otherwise make `ReFinalize` lose the type it needed to rediscover.

## Phase 14: `GlobalTypeRewriter` performs the actual private-type rewrite

`updateTypes(...)` uses a `TypeRewriter : GlobalTypeRewriter` and overrides only `modifyStruct(...)`.
For each ref-typed field, it writes the final LUB into the temporary rewritten struct definition.

Then `GlobalTypeRewriter(...).update()` applies the module-wide heap-type rewrite.
So the pass is using shared whole-module type remapping, not ad hoc in-place edits.

## Phase 15: `ReFinalize` repairs surrounding expression types

Immediately after rewriting the struct types, Binaryen runs:

- `ReFinalize().run(getPassRunner(), &wasm)`

This updates enclosing control-flow expressions and other users to the new field types.
It is the reason that block / `if` / try families can become well-typed after refinement even when the original inference phase treated only the field write as the important fact.

## Phase 16: `WriteUpdater` repairs writes that became too broad

After `ReFinalize`, Binaryen still may have write sites that no longer fit the refined field type.
So it runs `WriteUpdater` over function bodies and repairs:

- `StructNew`
- `StructSet`
- `StructRMW`
- `StructCmpxchg`

### Standard repair: insert `ref.cast`

If the value type is broader than the refined field type, Binaryen wraps it in `ref.cast`.
This is what many exactness-related GUFA test diffs are showing.

### Bottom-type repair: emit `ref.null` or `unreachable`

If the target heap type is bottom, a cast is not the right answer.
Binaryen instead emits either:

- `drop(value); ref.null bottom` for nullable bottoms
- `drop(value); unreachable` for non-nullable bottoms

That is how the pass stays valid for some continuation and uninhabited-type families.

### Extra refinalization only when needed

`WriteUpdater` tracks whether a bottom/unreachable rewrite changed control flow enough to require function-local refinalization.
If so, it re-runs `ReFinalize` only for those functions.

## What the pass does **not** do

These non-goals are worth keeping explicit:

- no open-world mode
- no public-type refinement
- no array refinement yet
- no ordinary-read-based inference
- no generic local/global/call dataflow in the normal variant
- no unconditional tee / `br_if` fallthrough analysis
- no signature rewriting here
- no rewrite contract that can skip read/write repair

## Bottom line

Binaryen `type-refining` in `version_129` is a **closed-world private struct-field refiner with a mandatory repair pipeline**.

The pass name sounds broader than the implementation really is.
The source says otherwise:

- infer field contents from writes
- preserve hierarchy legality
- rewrite private struct declarations
- repair affected reads and writes

That is the real strategy a future strict-parity port must preserve.

## Sources

- [`../../../raw/research/0150-2026-04-21-type-refining-binaryen-research.md`](../../../raw/research/0150-2026-04-21-type-refining-binaryen-research.md)
- Binaryen `version_129`:
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/TypeRefining.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/pass.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/struct-utils.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/lubs.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/possible-contents.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/type-updating.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/module-utils.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/type-refining.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/type-refining-gufa.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/type-refining-gufa-exact.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/type-refining-gufa-rmw.wast>
- Narrow freshness check:
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/TypeRefining.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/pass.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/type-refining.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/type-refining-gufa.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/type-refining-gufa-exact.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/type-refining-gufa-rmw.wast>
