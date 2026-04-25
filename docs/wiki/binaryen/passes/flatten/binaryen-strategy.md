---
kind: concept
status: supported
last_reviewed: 2026-04-25
sources:
  - ../../../raw/binaryen/2026-04-25-flatten-current-main-implementation-test-map.md
  - ../../../raw/binaryen/2026-04-23-flatten-primary-sources.md
  - ../../../raw/research/0360-2026-04-25-flatten-current-main-and-test-map.md
  - ../../../raw/research/0267-2026-04-23-flatten-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0127-2026-04-20-flatten-binaryen-research.md
related:
  - ./index.md
  - ./implementation-structure-and-tests.md
  - ./flat-ir-contract-and-preludes.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../simplify-locals-notee-nostructure/index.md
  - ../local-cse/index.md
---

# Binaryen `flatten` strategy

Use this page together with the tagged raw primary-source manifest in [`../../../raw/binaryen/2026-04-23-flatten-primary-sources.md`](../../../raw/binaryen/2026-04-23-flatten-primary-sources.md) and the 2026-04-25 current-main owner/test-map bridge in [`../../../raw/binaryen/2026-04-25-flatten-current-main-implementation-test-map.md`](../../../raw/binaryen/2026-04-25-flatten-current-main-implementation-test-map.md).

## Upstream source rule

- Use Binaryen `version_129` as the current source oracle for this pass.
- The reviewed official release surface on 2026-04-23 still anchored this dossier on Binaryen `version_129`, whose GitHub release page showed publish date **2026-04-01**.
- The core implementation lives in `src/passes/Flatten.cpp`.
- The formal flat-IR contract lives in `src/ir/flat.h`.
- Scheduler placement comes from `src/passes/pass.cpp`.
- Pass construction is declared in `src/passes/passes.h`.
- The main shipped behavior examples come from:
  - `test/lit/passes/flatten.wast`
  - `test/lit/passes/flatten_all-features.wast`
  - `test/lit/passes/flatten-eh-legacy.wast`
  - `test/lit/passes/opt_flatten.wast`
  - `test/lit/passes/flatten_rereloop.wast`
  - `test/lit/passes/flatten_i64-to-i32-lowering.wast`
- I also did a narrow freshness check against current upstream `main` for the most important drift points:
  - the top-of-file non-nullability TODO
  - the `Unsupported instruction for Flatten` fatal on `BrOn*` and `TryTable`
  - the formal Flat IR rule surface in `flat.h`
  - the dedicated `flatten`, `flatten_all-features`, and `flatten-eh-legacy` lit files
- As of `2026-04-25`, a focused current-main owner/test-map recheck still found no teaching-relevant drift from the `version_129` contract described in this dossier. The useful new detail is the proof-surface split now captured in [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md): `flatten.wast` is a tiny smoke file, `flatten_all-features.wast` is the broad behavior proof, and `flatten-eh-legacy.wast` is the EH nested-pop proof surface.

Primary source URLs:

- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/Flatten.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/flat.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/passes.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/flatten.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/flatten_all-features.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/flatten-eh-legacy.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/opt_flatten.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/flatten_rereloop.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/flatten_i64-to-i32-lowering.wast>
- <https://github.com/WebAssembly/binaryen/blob/main/src/passes/Flatten.cpp>
- <https://github.com/WebAssembly/binaryen/blob/main/src/ir/flat.h>
- <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/flatten_all-features.wast>
- <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/flatten-eh-legacy.wast>

## High-level intent

Binaryen uses `flatten` to convert ordinary Binaryen IR into a stricter Flat IR form.

That sentence is true but incomplete.

The actual implementation is a **postorder prelude + temp-local routing + control-value elimination** pass.

A good mental model is:

| Stage | What Binaryen does | Why it exists |
| --- | --- | --- |
| Define contract | Use `flat.h` rules to decide what flat IR means | Keep later flat-IR passes honest |
| Visit children first | Let complicated nested children rewrite themselves before parents decide what remains | Make parent decisions local |
| Build preludes | Move non-flat nested work into side-effect-preserving earlier statements | Replace hard children with `local.get` or placeholder `unreachable` |
| Remove value-carrying control flow | Route `block` / `if` / `loop` / `try` results through locals | Disallow control-flow-produced values |
| Remove tee and branch payload nesting | Route `local.tee`, `br` / `br_if`, and `switch` values through temp locals | Keep carried values explicit and flat |
| Repair EH stack shape | Fix nested pop locations after catch-local block insertion | Preserve valid exception structure |

That means this pass is not:

- a profitability pass
- a CFG simplifier
- a tail-merging pass
- a locals cleanup pass in the same sense as `simplify-locals`
- a CSE pass
- just “merge nested blocks”

## Pass name and scheduler placement

`pass.cpp` exposes one relevant public name here:

- `flatten`

Its registration summary is:

- “flattens out code, removing nesting”

That summary is directionally right, but it hides the more important formal truth:

- the pass is flattening into the exact `Flat IR` contract from `flat.h`
- not merely trying to make WAT look less nested

## Aggressive-only placement

In `pass.cpp`, `flatten` is inserted only when:

- `options.optimizeLevel >= 4`

The immediate scheduler neighborhood is:

- `ssa-nomerge`
- `flatten`
- `simplify-locals-notee-nostructure`
- `local-cse`
- `dce`
- ...

The comment above this block is one of the most important scheduler facts:

- if Binaryen is willing to “work very very hard,” it flattens the IR and then runs passes that depend on flat IR

The next comment makes the local-cleanup interaction explicit:

- `local-cse` is especially useful after flatten
- but flatten adds many new redundant locals
- so Binaryen first runs a little simplify-locals cleanup

That means scheduler placement is part of the actual pass contract.

## Contrast with the canonical no-DWARF path

This repo’s canonical no-DWARF `-O` / `-Os` page does **not** include flatten.

That is not an omission in local docs. It matches upstream source:

- ordinary `-O` / `-Os` is not aggressive enough to insert `flatten`
- `flatten` belongs to the `-O4` / `-O4z` family instead

That is why the tracker marks it:

- `Relevance = O4z-only`

## Saved generated-artifact `-O4z` evidence

The saved ordered audit records:

- slot `9`: `flatten`

The saved debug log shows:

- top-level `flatten` in the early aggressive cluster
- `18` total `flatten` executions in one full `-O4z` run

That total matters because it proves flatten is also part of the nested optimizing-rerun story, not just a one-time top-level prelude.

## Formal Flat IR contract

`flat.h` is the cleanest source for what flatten is actually trying to enforce.

## Rule 1: ordinary instruction children must be simple

For ordinary instructions, children must be one of:

- constant expression
- `local.get`
- `unreachable`
- `ref.as_non_null`

Anything more complicated must have been computed earlier and stored in a local.

## Rule 2: control flow cannot carry values anymore

After flattening, these structures may not have concrete value types:

- `block`
- `loop`
- `if`
- `try`

The function body also must not flow a value directly.

## Rule 3: no `local.tee`

Flat IR requires explicit `local.set` statements instead.

## Rule 4: `local.set` may not take control flow directly

Even if a control-flow child is otherwise valid Binaryen IR, it is still too structured for Flat IR in a `local.set` value position.

## `ref.as_non_null` is a deliberate special case

`flat.h` explicitly allows nested `ref.as_non_null`.

That is not a random exception. It means the flatness story around non-null references is more subtle than a blanket “spill all values to locals.”

At the same time, `Flatten.cpp` still begins with a non-nullability TODO.

So the safest summary is:

- some non-null families already work
- some still do not
- a future port must preserve that nuance instead of collapsing it into a simple yes/no claim

## Actual implementation structure

## 1. The pass is function-parallel and DWARF-invalidating

`Flatten` reports:

- `isFunctionParallel() == true`
- `invalidatesDWARF() == true`

The DWARF reason is explicitly documented in source:

- flatten splits original locals into many other locals
- Binaryen cannot keep debug info accurate after that yet

## 2. The two key data structures are `preludes` and `breakTemps`

The entire implementation is built around:

- `preludes`
  - a map from expression pointer to expressions that should execute immediately before it
- `breakTemps`
  - a map from branch target name to the temp local index used for values sent to that target

These maps are much more important than any individual rewrite case.

## 3. The algorithm is postorder on purpose

`Flatten` uses `ExpressionStackWalker` in postorder style.

That means when visiting a parent expression:

- children have already had a chance to flatten themselves
- any child-specific preludes have already been created
- the parent can decide whether to absorb those preludes, materialize them in a control-flow position, or move them upward

This is why the source comment emphasizes that when a node is visited:

- either its children have already had side effects moved into preludes
- or the node is itself a control-flow structure that will explicitly place child preludes

## 4. `visitExpression` begins with a very conservative fast path

Binaryen immediately returns for:

- constant expressions
- `nop`

These are already flat enough.

That is an important beginner correction:

- flatten does **not** spill absolutely everything
- it preserves already-flat simple children where it can

## 5. Control-flow structures get custom rewrites

## `Block`

For a block, Binaryen:

1. inserts each child item’s preludes directly before that item in the block list
2. if the block had a concrete result type, chooses a temp local for that carried value
   - reusing `breakTemps[block->name]` when present
   - otherwise allocating a fresh temp
3. rewrites the block’s final concrete child to `local.set temp, child`
4. changes the block itself to `Type::none`
5. replaces the outer use with `local.get temp`
6. turns the block itself into a prelude

That means flatten rewrites both the inside and the outside of a value-carrying block.

## `If`

For an if, Binaryen splits responsibilities carefully:

- condition preludes go **before** the whole if
- arm preludes stay **inside** the corresponding arm
- if the if is value-typed, Binaryen writes arm results into a temp local
- the temp type is the least upper bound of the arm types when there is an else
- if the original outer position needed the if’s value, that outer position becomes `local.get temp`

The least-upper-bound rule is especially important for GC/reference cases.

## `Loop`

For a value-carrying loop, Binaryen:

- wraps the loop body in `local.set temp, body`
- changes the loop to `Type::none`
- leaves a `local.get temp` in the outer position
- and treats the whole loop as a prelude

## legacy `Try`

For a value-carrying legacy try, Binaryen:

- allocates one temp local for the try result
- stores the main body result into that temp when concrete
- stores each catch body result into that same temp when concrete
- changes the outer use into `local.get temp`
- treats the try as a prelude

This is one reason the later EH repair step exists.

## 6. `local.tee` is always eliminated

If Binaryen sees `local.tee`:

- if the tee value is `unreachable`, Binaryen simply replaces the tee with that unreachable value
- otherwise it converts the tee to a plain set, pushes the set into preludes, and leaves a `local.get` in place

That is the source-level meaning of Flat IR rule 3.

## 7. Carried branch values use named target temps

## `Break` / `br_if`

When a branch carries a concrete value:

- Binaryen finds the target block type with `findBreakTarget(...)`
- gets or creates the named target temp with `getTempForBreakTarget(...)`
- stores the branch value into that temp in a prelude
- clears the original `br->value`

The subtle part is conditional branches.

A `br_if` may still leave a value flowing outward when the branch is not taken. The source comment documents a case where:

- the branch target type differs from the innermost flowing-out type

When that happens, Binaryen allocates a **second** temp local of the flowing-out type and stores a copied value into it.

That double-temp rule is easy to miss and crucial for correctness.

## `Switch` / `br_table`

For a switch carrying a value:

- Binaryen first stores the carried value into one temp
- then copies that temp into all unique target temps found by `BranchUtils::getUniqueTargets(...)`
- then removes the original switch value field

This is a direct “make branch payloads explicit” rewrite, not a control simplification.

## 8. The generic spill rule catches everything still too rich

After special handling, Binaryen refinalizes the current node.

Then:

- if the current node is `unreachable`, Binaryen keeps the real node as a prelude and leaves behind a placeholder `unreachable`
- else if the current node still has a concrete type, Binaryen allocates a temp local, pushes `local.set temp, curr` into preludes, and replaces the current node with `local.get temp`

That is why flatten is so aggressive.

A lot of IR that is totally ordinary Binaryen IR still becomes temp-local traffic purely to satisfy the flatness contract.

## 9. Prelude migration preserves evaluation order

At the end of each visit, Binaryen decides where its preludes can move:

- if the parent exists and is **not** a control-flow structure, preludes migrate upward into the parent’s prelude list
- otherwise, preludes stay attached to the current expression so that a control-flow parent can place them explicitly later

This is the main source-derived answer to “how does Binaryen avoid reordering side effects?”

## 10. `visitFunction` performs two final repairs

At function exit, Binaryen:

1. wraps a concrete function body in `return`
2. attaches remaining body preludes with `getPreludesWithExpression(...)`

Then it runs:

- `EHUtils::handleBlockNestedPops(curr, *getModule())`

The comment says flatten can generate blocks inside `catch`, making `pop` placement invalid until repaired.

## Important helper utilities and analyses

`flatten` is not a big dataflow-analysis pass, but it still depends on a very specific helper surface:

- `Properties::isConstantExpression(...)`
  - cheap already-flat check
- `Properties::isControlFlowStructure(...)`
  - decides which nodes must explicitly place preludes
- `Type::getLeastUpperBound(...)`
  - picks safe temp type for value-carrying `if`
- `findBreakTarget(...)`
  - discovers carried branch target type
- `BranchUtils::getUniqueTargets(...)`
  - deduplicates switch targets before temp fanout
- `ExpressionManipulator::copy(...)`
  - needed for the `br_if` double-temp mismatch case
- `ReFinalizeNode()`
  - repairs node typing after rewrites
- `EHUtils::handleBlockNestedPops(...)`
  - fixes exception-pop placement after inserted blocks
- `Builder`
  - allocates locals and constructs replacement IR

Notice what is **not** central here:

- no CFG liveness analysis
- no value numbering
- no profitability cost model

Flatten’s complexity is structural, not analytical.

## What the pass does **not** do

Binaryen `flatten` is not:

- `merge-blocks`
- `code-folding`
- `simplify-locals`
- `local-cse`
- `merge-locals`
- a full fixpoint optimizer

It creates a flatter IR surface for other passes to exploit later.

That is exactly why the immediate scheduler neighbors are small locals cleanup passes.

## Hard limits and current `version_129` boundaries

## Unsupported instructions are hard failures, not soft bailouts

`Flatten.cpp` explicitly fatals on:

- `BrOn`
- `TryTable`

This is a very important portability note.

A future Starshine port must decide explicitly whether to:

- match that current source behavior
- gate the pass off for those features
- or intentionally diverge and document why

## The non-nullability story is partial

`Flatten.cpp` still opens with a non-nullability TODO.

At the same time, the shipped tests prove some non-null families already work.

So the best summary is:

- current support is selective
- do not overstate it in either direction

## A good porting checklist

A future Starshine port should preserve all of the following:

- the exact `flat.h` flatness rules
- the postorder `preludes` algorithm or something behaviorally equivalent
- explicit elimination of control-flow return values
- explicit elimination of `local.tee`
- named target temps for carried branch values
- the `br_if` double-temp mismatch rule
- switch target fanout to all unique targets
- unreachable-placeholder behavior
- function-body `return` wrapping
- EH nested-pop repair
- aggressive-only scheduler placement before `simplify-locals-notee-nostructure` and `local-cse`
- an explicit documented policy for unsupported `BrOn*` / `TryTable`
- explicit non-null test coverage for both currently working and still-open families

## Bottom line

The cleanest beginner-friendly summary is:

- `flatten` is Binaryen’s aggressive **Flat IR normalization** pass
- its real implementation trick is the `preludes` map
- its real correctness trick is explicit temp-local routing for control values and branch payloads
- and its real scheduler role is to prepare aggressive locals cleanup, not to be the locals cleanup itself
