# 0164 - Binaryen `optimize-added-constants` research

## Status

- Date: 2026-04-21
- Type: Upstream-pass research / wiki-ing dossier seed
- Pass chosen: `optimize-added-constants`
- Local registry status: `removed`
- Campaign status reason: explicit tracker expansion after the original no-DWARF queue, the saved generated-`-O4z` queue, and the first upstream-only expansion queue were already dossier-covered

## Why this pass was the next eligible target

I re-read:

- `docs/README.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
- `agent-todo.md`
- `docs/0063-2026-03-24-pass-port-batches-and-registry-map.md`
- `src/passes/optimize.mbt`

That check showed:

1. the original parity queue is already dossier-covered,
2. the earlier tracker-widening queue is already dossier-covered too,
3. `optimize-added-constants` is still a real named local registry entry in both `src/passes/optimize.mbt` and `docs/0063-2026-03-24-pass-port-batches-and-registry-map.md`,
4. there was still **no dedicated living wiki folder** for it, and
5. it sits directly beside already-deep arithmetic simplification neighbors such as `optimize-instructions`, `precompute`, and the public sibling name `optimize-added-constants-propagate`.

So this is a deliberate second-wave tracker expansion, not a forgotten main-queue pass.

## `agent-todo.md` status

`agent-todo.md` has **no dedicated slice** for `optimize-added-constants`.

That is important enough to say explicitly because several earlier campaign dossiers could piggyback on active implementation slices, but this one cannot. The current justification is documentation value and registry truthfulness, not an already-open execution slice.

## Main beginner summary

Binaryen's `optimize-added-constants` pass is much narrower than the name sounds.

It is **not** generic constant folding.
It is **not** full algebraic reassociation.
It is **not** local propagation.
It is **not** loop motion.

Instead, it is a small arithmetic tree reshaper for integer `add` / `sub` ladders. It looks for shapes like

- `(x + C1) + C2`
- `(x + C1) - C2`
- `C1 + (x + C2)`
- `C1 + (x - C2)`

and rewrites them so the constants are combined into one constant on the outside.

The practical goal is to make later passes see simpler trees such as:

- `x + 12` instead of `(x + 5) + 7`
- `x + 2` instead of `(x + 5) - 3`
- `x - 2` instead of `5 + (x - 7)`

That sounds tiny, but it matters because later passes often match better on canonical "base expression plus one constant" shapes than on nested add/sub ladders.

## Source inventory

### Local repo sources that justify tracking it

- `src/passes/optimize.mbt`
  - the pass is still a known removed-name registry entry
- `docs/0063-2026-03-24-pass-port-batches-and-registry-map.md`
  - the pass is still listed in the repo's removed-until-ported batch map
- `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
  - current canonical no-DWARF `-O` / `-Os` does **not** include it
- `agent-todo.md`
  - confirms there is no dedicated implementation slice today

### Official Binaryen `version_129` sources reviewed

- `src/passes/OptimizeAddedConstants.cpp`
- `src/passes/pass.cpp`
- `test/lit/passes/optimize-added-constants.wast`
- `README.md` pass list surface

## What Binaryen source files matter most

### 1. `OptimizeAddedConstants.cpp`

This is the real pass contract.

It answers the important questions directly:

- which operators are considered relevant,
- how constants are normalized onto the expected side,
- which nested add/sub families may be reassociated,
- when a rewrite should recur immediately,
- what the `propagate` mode changes,
- and how expression types are repaired after the rewrite.

### 2. `pass.cpp`

This matters for two reasons:

- it proves the public pass names exist in `version_129`, and
- it shows that Binaryen exposes **two** public entrypoints backed by the same engine:
  - `optimize-added-constants`
  - `optimize-added-constants-propagate`

That sibling relationship is easy to miss if you only read a pass list.

### 3. `optimize-added-constants.wast`

This is the easiest beginner-facing explanation surface.

The test file shows:

- the positive shapes Binaryen expects to combine,
- the left-vs-right constant normalization behavior,
- the tricky `add` / `sub` sign interactions,
- and the longer ladders where the propagate variant matters more than the plain variant.

### 4. `README.md`

This is weaker than the implementation file, but still useful as an official surface proving the pass is part of the public `wasm-opt` pass vocabulary.

## Implementation structure

## Top-level shape

`OptimizeAddedConstants.cpp` implements one small function-parallel tree rewrite pass.

The core structure is:

1. walk integer arithmetic expressions,
2. ignore anything that is not a relevant `add` / `sub` family,
3. normalize commutative cases so the constant sits where the matcher expects it,
4. look one level deeper for another relevant binary with its own constant child,
5. combine the two constants into a single constant expression,
6. rebuild the outer tree as a simpler `x +/- C` shape,
7. refinalize the rewritten expression,
8. optionally recurse again in propagate mode.

That is the whole pass story. There is no CFG pass, no dataflow fixed point over blocks, and no effect-analysis framework.

## The real operator surface

The implementation is intentionally small.

It only targets integer add/sub-style binary trees.

Important consequence:

- floating-point arithmetic is out,
- multiplication/division/rem shifts are out,
- comparison trees are out,
- generic local propagation is out,
- and arbitrary n-ary reassociation is out.

So the pass name sounds broad, but the actual implementation is a narrow canonicalizer for one arithmetic family.

## The real matching idea

The pass looks for an outer relevant binary where **one side is a constant** and the other side is itself a relevant binary that also has a constant child.

Then it tries to collapse the two constants together while leaving the nonconstant payload expression in place.

A good beginner shorthand is:

- find `payload +/- const` nested under another `+/- const`,
- then make it just one `payload +/- merged_const`.

## Constant-side normalization

A subtle but important detail in the source is the normalization step for commutative operators.

When the outer or inner node is commutative, Binaryen will swap children so the constant is in the expected position before trying to match.

That matters because the pass wants to treat these as equivalent teaching shapes:

- `(x + 5) + 7`
- `7 + (x + 5)`
- `(5 + x) + 7`
- `7 + (5 + x)`

Without that normalization, the pass would need many extra special-case branches.

## How the sign logic really works

The pass is simple, but the sign bookkeeping is the part beginners are most likely to misread.

Examples:

- `(x + 5) + 7` becomes `x + 12`
- `(x + 5) - 7` becomes `x + -2` and can later become `x - 2`
- `5 + (x - 7)` becomes `x - 2`
- `(x - 5) + 7` becomes `x + 2`

So the pass is not just adding two literals together blindly. It is preserving the exact add/sub meaning while moving the arithmetic burden onto one merged constant.

## The `propagate` sibling mode

Binaryen exposes a second public pass name backed by the same file:

- `optimize-added-constants-propagate`

The implementation difference is small but meaningful: after a successful local rewrite, propagate mode immediately tries again on the fresh result so longer ladders can collapse farther in the same run.

Beginner mental model:

- plain mode: "combine one local pair while walking"
- propagate mode: "after combining, see if the new result can combine again right now"

That makes the propagate sibling a better fit for more aggressive cleanup contexts.

## Helper utilities and dependencies

Compared to many other Binaryen passes, this one has very light dependencies.

### Main helpers visible in the source

- `ExpressionManipulator`
  - used for safe tree surgery / replacement helpers
- `Builder`
  - used to construct the replacement constant and binary nodes
- `reFinalize(...)`
  - repairs the expression type after rebuilding the tree
- core `Binary` / `Const` node inspection
  - the pass mostly lives on explicit AST node shapes, not external analyses

### What it does **not** depend on

- no CFG construction
- no liveness pass
- no dominance pass
- no effects summary framework
- no branch utilities
- no refinalization over whole functions or modules
- no closed-world type oracle

That makes this pass a good teaching example of a **small local AST canonicalizer** rather than a large whole-function optimizer.

## Scheduler placement meaning

## What is confirmed

From the reviewed official sources and local docs, the durable confirmed facts are:

- `version_129` publicly registers both `optimize-added-constants` and `optimize-added-constants-propagate`
- the repo's current canonical no-DWARF `-O` / `-Os` page does **not** include either name
- the local Starshine registry still tracks both names as removed legacy passes

## What is inference

I did **not** confirm a default `version_129` top-level placement for plain `optimize-added-constants` in the same way we confirmed the no-DWARF and saved-`-O4z` queues.

So the safe statement is:

- this pass is a real public Binaryen pass,
- it is a meaningful arithmetic neighbor of `precompute` and `optimize-instructions`,
- but it is **not** part of the repo's currently documented no-DWARF `-O` / `-Os` pathway.

Anything stronger than that would need a dedicated preset audit.

## Important IR / WAT shapes

The shipped test file and implementation make the key shape families clear.

### Positive shapes

1. nested integer add chains
   - `(i32.add (i32.add X (i32.const C1)) (i32.const C2))`
2. mixed add/sub chains with one payload expression
   - `(i32.sub (i32.add X (i32.const C1)) (i32.const C2))`
3. commuted-add versions of the same trees
   - `(i32.add (i32.const C1) (i32.add X (i32.const C2)))`
4. longer ladders where repeated immediate reassociation helps
   - `(((X + 1) + 2) + 3)`-style trees

### Negative / bailout shapes

1. non-integer trees
2. operators outside the targeted add/sub family
3. trees without two explicit constant leaves in the right local pattern
4. shapes where reassociation would need broader algebra than the pass implements
5. shapes that only become profitable after separate propagation, CSE, or constant folding

### Easy-to-misread shapes

1. `sub` trees where the merged constant changes sign
2. commuted `add` trees where the constant starts on the left
3. ladders that need the propagate sibling to fully collapse in one run
4. trees that still need a later pass to canonicalize `+ -N` into `- N`

## Positive shape catalog

### Shape A: pure add ladder

Before:

```wat
(i32.add
  (i32.add
    (local.get $x)
    (i32.const 5))
  (i32.const 7))
```

After:

```wat
(i32.add
  (local.get $x)
  (i32.const 12))
```

### Shape B: add then subtract

Before:

```wat
(i32.sub
  (i32.add
    (local.get $x)
    (i32.const 5))
  (i32.const 3))
```

After, conceptually:

```wat
(i32.add
  (local.get $x)
  (i32.const 2))
```

### Shape C: outer constant on the left

Before:

```wat
(i32.add
  (i32.const 5)
  (i32.add
    (local.get $x)
    (i32.const 3)))
```

After:

```wat
(i32.add
  (local.get $x)
  (i32.const 8))
```

### Shape D: mixed add/sub where the result stays a subtraction

Before:

```wat
(i32.add
  (i32.const 5)
  (i32.sub
    (local.get $x)
    (i32.const 7)))
```

After:

```wat
(i32.sub
  (local.get $x)
  (i32.const 2))
```

## What the pass does **not** do

This is one of the most important teaching sections.

The pass does **not**:

- hoist loop invariants,
- propagate constants through locals,
- remove duplicate computations,
- fold arbitrary side-effect-free subtrees,
- simplify comparisons,
- rewrite loads/stores,
- change control flow,
- or canonicalize all equivalent arithmetic expressions.

If the expression does not already look like a small nested add/sub-with-constants ladder, this pass mostly does nothing.

## Pass interactions

## Upstream neighbor interactions

### With `precompute`

`optimize-added-constants` often feeds `precompute` simpler trees by collapsing two constants into one explicit literal site.

But it is still different from `precompute`:

- `precompute` evaluates broader compile-time-known expressions
- `optimize-added-constants` only reassociates a narrow arithmetic family

### With `optimize-instructions`

This pass can expose the more canonical "payload plus one constant" shapes that instruction peepholes tend to like.

### With the propagate sibling

The plain and propagate variants share the same core matcher, but the propagate variant is better at long ladders because it immediately retries after rewriting.

## Things that are easy to misunderstand

1. **The name sounds larger than the implementation.**
   It does not optimize every "added constant" situation in a function.
2. **`propagate` is not a whole new algorithm.**
   It is the same local engine with a more aggressive immediate-revisit behavior.
3. **This is still tree-local work.**
   There is no block-wide or function-wide analysis phase.
4. **It is not a synonym for constant folding.**
   It mostly improves tree shape so later passes can do more.
5. **The tricky part is sign correctness, not dataflow.**
   The hard bugs here would be algebra/sign mistakes, not missing CFG metadata.

## Future Starshine port invariants

A future Starshine port should preserve these facts:

1. **Scope**
   - keep it a small local arithmetic-tree pass, not a disguised generic propagation pass
2. **Operator surface**
   - restrict it to the upstream integer add/sub family unless the docs are updated intentionally
3. **Normalization**
   - preserve commutative constant-side normalization before matching
4. **Sign correctness**
   - preserve the exact add/sub algebra for all mixed shapes
5. **Sibling distinction**
   - keep plain `optimize-added-constants` distinct from `optimize-added-constants-propagate`
6. **Type repair**
   - refinalize rewritten expressions rather than assuming rebuilt trees are automatically well-typed
7. **Pass interaction honesty**
   - do not quietly attribute later `precompute` / `optimize-instructions` wins to this pass alone

## Open questions

1. I confirmed public registration and implementation in `version_129`, but I did not finish a fresh preset-placement audit for higher optimize levels. That should stay explicit rather than being guessed.
2. The shipped lit file was enough to document the main shape families, but a future follow-up could catalog exactly which longer ladders differ between plain and propagate modes under one pass run.
3. If a future Starshine scheduler wants this pass, it should decide explicitly whether the plain or propagate variant is the honest upstream analog for the chosen slot.

## Durable conclusions

- `optimize-added-constants` is a real Binaryen public pass that still exists in `version_129` and still exists as a removed local registry name in Starshine.
- The real implementation is a **small integer add/sub reassociation pass**, not a broad arithmetic optimizer.
- The pass's main job is to collapse nested constant ladders into one merged constant near a single payload expression.
- `optimize-added-constants-propagate` is a real sibling public pass, not just an undocumented internal mode.
- The repo's current no-DWARF `-O` / `-Os` page does not use this pass, so the dossier is a tracker expansion rather than unfinished parity queue work.
- `agent-todo.md` currently has no dedicated slice for it.

## Sources

### Local repo

- `docs/README.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
- `agent-todo.md`
- `docs/0063-2026-03-24-pass-port-batches-and-registry-map.md`
- `src/passes/optimize.mbt`

### Official Binaryen `version_129`

- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/OptimizeAddedConstants.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/optimize-added-constants.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/README.md>
