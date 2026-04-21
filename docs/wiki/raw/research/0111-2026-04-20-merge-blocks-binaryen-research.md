# 0111 - `merge-blocks` Binaryen research

## Status

- Date: 2026-04-20
- Type: One-off raw investigation
- Scope: document one currently unimplemented `-O4z` pass in Starshine, using Binaryen `version_129` plus the saved generated-artifact `-O4z` audit to explain how Binaryen's `merge-blocks` pass really works and which IR shapes matter.

## Why this pass

- `merge-blocks` is still unimplemented in Starshine and remains listed under removed pass names in `src/passes/optimize.mbt`.
- The saved generated `cmd.wasm` `-O4z` audit shows `merge-blocks` as a real skipped upstream slot twice in the top-level path:
  - slot `39`
  - slot `42`
- The same saved Binaryen debug log also shows additional nested `merge-blocks` executions later under the optimizing global passes, so the top-level pair is not the whole story once `dae-optimizing`, `inlining-optimizing`, and `simplify-globals-optimizing` exist.
- `merge-blocks` is easy to underestimate because the implementation file is small. The small file is misleading: the pass is small because it leans on Binaryen's branch utilities, effect analysis, and refinalization machinery. The real porting work is understanding those contracts.

## Saved local source material

### Local Starshine / audit sources

- `src/passes/optimize.mbt`
- `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
- `.artifacts/o4z-wasm-opt-debug.log`
- `.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/summary.md`
- `.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/skipped-unimplemented-slots.json`

### Official Binaryen `version_129` sources

- `src/passes/MergeBlocks.cpp`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/MergeBlocks.cpp>
- `src/passes/pass.cpp`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- `src/ir/branch-utils.h`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/branch-utils.h>
- `src/ir/branch-utils.cpp`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/branch-utils.cpp>
- `src/ir/effects.h`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/effects.h>
- `src/wasm/wasm-traversal.h`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/wasm/wasm-traversal.h>
- `test/lit/passes/merge-blocks.wast`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/merge-blocks.wast>
- `test/passes/merge-blocks.wast`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/merge-blocks.wast>
- Binaryen README `Blocks` section
  - <https://github.com/WebAssembly/binaryen/blob/version_129/README.md>

## Fast answer

Binaryen's `merge-blocks` pass is a late, function-local structured-cleanup pass that only does one thing:

- if a block ends in another block,
- and flattening that tail child would not change result typing,
- and flattening it would not make branches or skipped side effects behave differently,
- then Binaryen splices the child block's contents into the parent block.

That sounds tiny, but the important parts are the safety rails:

1. the child must be the **last** item in the parent block
2. the child must be **unnamed** or share the **same name** as the parent
3. the parent and child block types must be **identical**
4. if the child has a name, Binaryen requires `!EffectAnalyzer::invalidates(child)`
5. if Binaryen finds the dangerous same-name descendant-branch family anywhere in the function, it bails out of the **entire function** before doing any merges
6. after every successful splice, Binaryen runs `ReFinalize` to recompute expression types

That is the whole pass in one page.

## Where it appears in the saved `-O4z` path

The saved generated-artifact audit captured these relevant top-level late-cleanup slots:

- `slot 38`: `code-folding`
- `slot 39`: `merge-blocks`
- `slot 40`: `remove-unused-brs`
- `slot 41`: `remove-unused-names`
- `slot 42`: `merge-blocks`
- `slot 43`: `precompute-propagate`
- `slot 44`: `optimize-instructions`
- `slot 45`: `heap-store-optimization`
- `slot 46`: `rse`
- `slot 47`: `vacuum`

Important takeaway:

- Binaryen does **not** run `merge-blocks` once as a generic block flattener.
- It runs it twice in the late cleanup cluster.
- The first run comes right after `code-folding`, which is a natural place for duplicate-region folding to leave behind nested block wrappers.
- The second run comes after `remove-unused-brs` and `remove-unused-names`, which is a natural place for branch cleanup to expose fresh redundant nesting.

The same `o4z-wasm-opt-debug.log` also contains many more later `merge-blocks` entries under nested optimizing-pass reruns. That is consistent with the repo's existing no-DWARF optimize-path note. I am treating that as a strongly supported inference from the saved log plus the documented nested-rerun helpers, not as a new source-level claim about a special `merge-blocks`-only scheduler path.

## Beginner mental model

A beginner-safe way to think about `merge-blocks` is this:

```wat
(block $outer
  ;; some code
  (block $inner
    ;; more code
  ))
```

If `$inner` is just a wrapper around the last chunk of `$outer`, then Binaryen wants to turn that into:

```wat
(block $outer
  ;; some code
  ;; more code
)
```

But Binaryen only does that when three beginner-visible things stay true:

- branches still land in the same semantic place
- the resulting value type is still the same
- no observable side effects disappear because some branch now skips over code it used to execute

That is the whole pass philosophy.

## What the actual Binaryen source does

## 1. Pass shape

`MergeBlocks` is a `WalkerPass<PostWalker<MergeBlocks>>`.

Important consequences:

- it is a **function pass**, not a module pass
- it is **post-order**, so inner blocks are visited before outer blocks
- it reports `isFunctionParallel() == true`, so Binaryen considers it embarrassingly parallel across functions
- it reports `modifiesBinaryenIR() == true`

Porting takeaway:

- Starshine does not need module-wide global analysis to start a faithful port
- but it does need a reliable per-function branch/effect/type repair story

## 2. The whole-function hazard prescan: `ProblemFinder`

Before it runs the real post-order walk, Binaryen runs a special prescan called `ProblemFinder`.

The prescan looks for a very narrow but very nasty family:

- a block whose **last child** is another block
- the child block has the **same label name** as the parent block
- and there are branches in the dangerous descendant family that would become ambiguous if the child were removed before branch names were rewritten

The source comment is the most important part of the entire file:

- Binaryen removes the inner block first
- only then does it retarget branches
- in the bad same-name family, once the inner block is gone, branches that used to target the inner block can become indistinguishable from branches that target the outer block
- that means a naive update can rewrite **too much**

This is why `ProblemFinder` exists.

### Crucial detail: function-wide bailout

If `ProblemFinder` sees the bad family **anywhere** in the function, Binaryen returns from `doWalkFunction(...)` early and skips the normal merge walk for that entire function.

That is stronger than a candidate-local bailout.

Binaryen is not saying:

- "skip only this one merge candidate"

It is saying:

- "this function contains a shadowed-label family that makes the current merge/update strategy unsafe, so do no block merging here at all"

That whole-function bailout is one of the most important porting details to keep.

## 3. The candidate shape: only `block` ending in `block`

The real walker only calls `optimizeBlock(...)` on block expressions.

Inside `optimizeBlock(...)`, Binaryen immediately requires:

- the parent block must be non-empty
- the parent block's **last** list element must itself be a block

This means `merge-blocks` is **not** a general "flatten nested blocks anywhere" pass.

It only looks at the tail child.

Why this matters:

- when the nested child is the last item, retargeting some branches from child to parent can be semantically valid because both labels end at the same continuation point
- if the child were in the middle, flattening could drag later siblings into or out of branch reachability, which is much harder to preserve

## 4. The naming gate

Binaryen next requires one of these:

- the child block is unnamed, or
- the child block has the same name as the parent block

So Binaryen deliberately does **not** merge arbitrary named children.

### Why unnamed children are easy

An unnamed child cannot be a branch target by name.

That means Binaryen can often flatten it without worrying about control-flow retargeting.

### Why same-name children are the only named family Binaryen accepts

If the child has the same name as the parent and the other safety gates pass, the child and parent are already trying to represent the same branch exit point.

That makes flattening plausible.

### What Binaryen does not try

Binaryen does **not** try to solve the general case:

- parent label `$A`
- child label `$B`
- arbitrary branches elsewhere that target `$B`

That broader retargeting problem is out of scope for this pass.

## 5. The type-equality gate

Binaryen then requires:

- `curr->type == child->type`

The source comment explains why:

- if the types differ, changing branch targets can change which value a branch is expected to carry, and the merge can become invalid

This is one of the easiest gates to explain to newer contributors:

- a block's type is part of the control-flow contract
- flattening is only safe when the parent and child promise the same result shape

## 6. The effect barrier for named children

If the child has a name, Binaryen also requires:

- `!EffectAnalyzer::invalidates(child)`

The code comment explains the intent:

- because the child is the last item in the parent, Binaryen can retarget branches to the child so they go to the parent instead
- but if the child has observable side effects, that retargeting could make those side effects stop happening
- so named children only flatten when the child's body does **not** invalidate earlier state

This is the best beginner phrasing:

- "if some branch can now skip the child body entirely, then the child body must not contain work that users could observe disappearing"

Important nuance:

- this effect gate is only enforced for **named** children
- unnamed children bypass it because unnamed blocks are not branch targets by name in the first place

## 7. The rewrite itself is tiny

Once all gates pass, the actual rewrite is mechanically small:

1. `BranchUtils::operateOnScopeNameUses(curr, ...)`
2. `curr->list.pop_back()`
3. append the child's list items directly into the parent list
4. `ReFinalize().walk(curr)`
5. set `optimized = true`

That is the entire mutation.

### Why `ReFinalize` matters

After splicing the child's list into the parent, the types of the parent block and surrounding expressions may need recomputation.

Binaryen uses `ReFinalize` as the standard "repair the expression types now that structure changed" step.

Porting takeaway:

- a faithful Starshine port must not treat block flattening as purely structural
- it must update or recompute the type/result metadata after every successful splice

## 8. The branch utility call is more defensive than magical

`operateOnScopeNameUses(...)` works on the current scope and unnamed descendant scopes.

What matters for understanding `merge-blocks`:

- Binaryen is not performing a whole-function arbitrary label renamer here
- it is using a scoped helper that only touches branch-relevant names inside the relevant scope shape

My reading of the current `MergeBlocks.cpp` gates is:

- under the allowed merge cases, this helper is mostly a **safety belt**
- the real semantic work is the gating logic, not a heroic branch retargeting algorithm

That is an inference from the current source structure, not an explicit Binaryen comment.

## Important shape catalog

## Positive shape 1: unnamed tail child

This is the simplest merge family and is directly covered by Binaryen's lit tests.

Before:

```wat
(block $A
  (i32.const 0)
  (block
    (drop
      (i32.const 1))
    (br $A
      (i32.const 2))))
```

After:

```wat
(block $A
  (i32.const 0)
  (drop
    (i32.const 1))
  (br $A
    (i32.const 2)))
```

Why it merges:

- child is last
- child is unnamed
- block type matches parent
- flattening exposes no named-child branch-target problem

## Positive shape 2: same-name tail child with a direct branch on the child's root list

Binaryen's lit tests also show a same-name family that still merges:

Before:

```wat
(block $A (result i32)
  (i32.const 0)
  (block $A (result i32)
    (drop (i32.const 1))
    (br $A (i32.const 2))))
```

After:

```wat
(block $A (result i32)
  (i32.const 0)
  (drop (i32.const 1))
  (br $A (i32.const 2)))
```

Why this example matters:

- it proves the bad same-name family is **narrower** than "same-name child plus any branch to that label"
- Binaryen is willing to flatten at least some direct same-name branch shapes

That nuance is important because a too-conservative port could easily reject profitable legal merges.

## Negative shape 1: same-name child with the dangerous descendant-branch family

Binaryen's lit tests explicitly preserve this shape:

```wat
(block $A (result i32)
  (block $A (result i32)
    (drop (i32.const 1))
    (block (result i32)
      (br $A (i32.const 2)))))
```

Binaryen keeps it as-is.

This is the exact family `ProblemFinder` is there to avoid.

Beginner explanation:

- once the inner `$A` disappears, a branch to `$A` from deeper inside the former child can become ambiguous to update safely
- Binaryen chooses safety over cleverness and skips merges for the whole function when it sees that hazard family

## Negative shape 2: named child with observable branch-like effects

Binaryen's lit tests also preserve a named child with branch effects:

```wat
(block $B (result i32)
  (block $A (result i32)
    (i32.const 1)
    (br $B (i32.const 2))))
```

This is a good beginner example of the broader rule:

- once a child has a name, Binaryen treats it as potentially branch-reachable
- if flattening could make its internal effects disappear under retargeted control flow, Binaryen declines the merge

## Negative shape 3: different child name

Derived directly from the source gates:

```wat
(block $outer
  (block $inner
    ...))
```

This does **not** merge just because the child is last.

The child must be unnamed or share the parent's name.

Why it matters:

- `merge-blocks` is intentionally narrow
- the pass is not a generic label retargeter for arbitrary named block pairs

## Negative shape 4: result-type mismatch

Derived directly from the source gate `curr->type == child->type`:

```wat
(block (result i32)
  (block
    ...))
```

or the reverse mismatch family.

If the block types do not match, Binaryen refuses to flatten.

Why it matters:

- flattening is not just about syntax
- branch payload expectations and block result typing must remain identical

## Negative shape 5: non-tail nested block

Also derived directly from the source:

```wat
(block
  (block
    ...)
  (call $later))
```

No merge.

Why it matters:

- the pass only knows how to flatten the **last** child safely
- a middle child would change the continuation structure for later siblings

## What `merge-blocks` is intentionally not

`merge-blocks` is not:

- `flatten`
  - `flatten` is an earlier and broader control-structure cleanup in the saved `-O4z` path
- `remove-unused-brs`
  - `remove-unused-brs` reasons about redundant exits and branch structure; `merge-blocks` only makes some nested block wrappers disappear
- `vacuum`
  - `vacuum` removes obviously dead structural garbage like `nop` roots; `merge-blocks` cares about preserving branch and type semantics while flattening
- a general CFG simplifier
- a general label renamer
- a type repair pass by itself

A good beginner summary is:

- `merge-blocks` does one small structured transformation,
- but it does it late, repeatedly, and only after earlier passes have made the nesting cheap enough to collapse safely.

## Why the pass is late

The saved `-O4z` audit explains the surrounding neighborhood better than the tiny source file does.

Late placement makes sense because earlier passes can create mergeable wrappers:

- `code-folding` can leave duplicated regions unified behind a block shell
- `remove-unused-brs` can turn branch-heavy shapes into simpler tails
- `remove-unused-names` can reduce label clutter before the second `merge-blocks` slot

Then after `merge-blocks` runs, later passes can exploit the simpler structure:

- `precompute-propagate`
- `optimize-instructions`
- `heap-store-optimization`
- `rse`
- final `vacuum`

So `merge-blocks` is best understood as a **late structural enabler**.

## Porting floor for Starshine

A faithful Starshine port needs at least these capabilities:

1. a way to inspect a block's ordered child list and see whether the tail child is a block
2. a block/result-type query strong enough to enforce parent-child type equality
3. a branch-usage helper equivalent to Binaryen's scoped `BranchUtils` utilities
4. an effects query with the same practical meaning as `EffectAnalyzer::invalidates(child)` for named children
5. a type-repair / refinalization step after splicing
6. a whole-function hazard prescan for the same-name descendant-branch family
7. honest scheduling in both late top-level slots, plus awareness that nested optimizing passes can replay the same cleanup family later

## Suggested reduced test matrix for a future Starshine port

Minimum high-value fixtures:

1. unnamed tail child merges
2. same-name typed tail child merges
3. same-name descendant-branch hazard bails the function
4. different-name child stays intact
5. named child with invalidating effects stays intact
6. type mismatch stays intact
7. non-tail child stays intact
8. repeated late-slot run is stable when nothing more can be merged
9. `merge-blocks -> remove-unused-brs` interaction reduces a wrapper that only becomes useless after flattening
10. `code-folding -> merge-blocks` interaction on a synthetic duplicated-region example

## Open questions

1. The Binaryen comments make the shadowed-branch hazard clear, and the lit tests prove the preserved bad family, but the exact boundary between the directly mergeable same-name branch case and the non-mergeable descendant-shadow case is easy to misread at first glance. A future Starshine implementation should pin this down with reduced oracle tests before writing a more aggressive local matcher.
2. The saved `-O4z` debug log strongly suggests nested optimizing-pass reruns include `merge-blocks`, but the exact helper composition should be re-documented on the dedicated optimizing-pass pages when those passes are researched.
3. The source file is small enough that a tempting first port would inline the logic directly into a bigger cleanup pass. That would be a mistake. Binaryen treats this as a distinct late pass with distinct safety gates and repeated slots; Starshine should keep that separation.

## Durable conclusions

- `merge-blocks` is a narrow late cleanup pass, not a general flattening pass.
- The pass only looks at a block's **tail child**.
- Safe merges require: matching block types, acceptable naming, and no named-child invalidation.
- Binaryen has a dedicated same-name shadow hazard detector and uses a **whole-function bailout** when it sees that unsafe family.
- The rewrite itself is tiny; the real work is in the branch/effect/type contracts around it.
- The saved generated-artifact `-O4z` audit confirms `merge-blocks` is a real missing upstream slot twice in the top-level path today, not a theoretical future pass.
