# 0112 - `code-folding` Binaryen research

## Status

- Date: 2026-04-20
- Type: One-off raw investigation
- Scope: document one currently unimplemented no-DWARF / `-O4z` Binaryen pass in Starshine, using Binaryen `version_129` plus the saved generated-artifact audit to explain how `code-folding` really works, which helpers it leans on, and which IR shapes a future Starshine port must preserve.

## Why this pass

- `code-folding` is still unimplemented in Starshine and remains listed under removed pass names in `src/passes/optimize.mbt`.
- The canonical no-DWARF `-O` / `-Os` path runs it once in the late function cleanup cluster.
- The saved generated-artifact `-O4z` audit records it as a real skipped top-level upstream slot at slot `38`.
- The same saved Binaryen debug log also shows repeated nested runs of the same late cleanup cluster under optimizing passes, so the top-level slot is not the whole scheduler story.
- This pass is easy to misdescribe as “generic common-tail merging.” The actual implementation is narrower and more structured:
  - one subsystem folds duplicate tails that reach the outside of a named block or an `if-else`
  - another subsystem folds duplicate tails that terminate control flow at the function level (`return`, `return_call*`, `unreachable`)
- That split matters for porting. A future Starshine implementation will need two related but different algorithms, not one vague suffix matcher.

## Saved local source material

### Local Starshine / audit sources

- `src/passes/optimize.mbt`
- `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `.artifacts/o4z-wasm-opt-debug.log`
- `.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/summary.md`
- `.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/skipped-unimplemented-slots.json`
- `agent-todo.md`

### Official Binaryen `version_129` sources

- `src/passes/CodeFolding.cpp`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/CodeFolding.cpp>
- `src/passes/pass.cpp`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- `src/passes/opt-utils.h`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/opt-utils.h>
- `src/ir/branch-utils.h`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/branch-utils.h>
- `src/ir/effects.h`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/effects.h>
- `src/ir/eh-utils.h`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/eh-utils.h>
- `src/ir/label-utils.h`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/label-utils.h>
- `src/ir/utils.h`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/utils.h>
- `test/lit/passes/code-folding.wast`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/code-folding.wast>
- `test/passes/code-folding.wast`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/code-folding.wast>

## Fast answer

Binaryen’s `code-folding` pass is a late, function-parallel size optimization that merges identical code tails when all candidate paths already converge on the same semantic exit.

The implementation has two distinct families:

1. **expression-exit tail folding**
   - merge duplicate suffixes on:
     - named block exits (`br $label` plus any shared code right before them)
     - `if-else` arms
2. **function-terminating tail folding**
   - merge duplicate suffixes on:
     - `return`
     - `return_call`, `return_call_indirect`, `return_call_ref`
     - `unreachable`

Important durable facts:

- The pass is **not** generic CFG tail-merging and **not** ordinary local CSE.
- It only records a `br` tail when the branch is **unconditional** and is the **last item** in its enclosing block.
- It only folds `if-else` arms when both arms are unnamed blocks, or when one non-block arm can be wrapped into a synthetic block because it exactly matches the suffix of the block arm.
- Unsupported branch forms deliberately poison block-label folding. The source comment calls out `br_on_*` as TODO, and the shipped tests lock that behavior in.
- It walks a function to a **fixpoint**: once one fold happens, Binaryen reruns the same pass logic on the rewritten function because the new shape may expose more folds.
- Binaryen refuses to move code when `BranchUtils` says the moved suffix would drag a branch past one of its own internal targets.
- With exception handling enabled, Binaryen also refuses moves that would create dangling `pop`s or move throwing code out of a `try` / `try_table` scope.
- Adding helper blocks is part of the normal design. Binaryen uses a size heuristic to decide whether the extra structure is worth it, and then relies on later cleanup passes like `merge-blocks`, `remove-unused-brs`, `remove-unused-names`, and `vacuum` to simplify the new structure again.

## Where it appears in the scheduler

## Top-level no-DWARF path

Binaryen `version_129` `pass.cpp` schedules `code-folding` here in the default function pipeline:

- after the late `vacuum`
- before `merge-blocks`
- before the late `remove-unused-brs`
- before the second late `merge-blocks`
- before the late `precompute(-propagate)` / `optimize-instructions` / `heap-store-optimization` / `rse` / final `vacuum` cluster

The canonical no-DWARF page in this repo already records the same order.

The saved generated-artifact `-O4z` audit confirms a real skipped top-level slot:

- slot `38`: `code-folding`

The saved debug log also captures the immediate neighborhood on the large artifact:

- `slot 37`: `vacuum`
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

That ordering is a useful hint about intended role:

- `code-folding` creates new shared-tail blocks and branch structure
- `merge-blocks` and branch cleanup then simplify the newly shared shape
- late peepholes and `rse` profit from the cleaner single-copy tail

## Nested reruns

`opt-utils.h` shows that `optimizeAfterInlining(...)` prepends `precompute-propagate` and then reruns `addDefaultFunctionOptimizationPasses()` on touched functions.

That means `code-folding` definitely reruns inside the nested cleanup helper used by passes like:

- `dae-optimizing`
- `inlining-optimizing`

The saved `o4z-wasm-opt-debug.log` confirms repeated nested `code-folding -> merge-blocks -> remove-unused-brs -> remove-unused-names -> merge-blocks -> precompute-propagate -> optimize-instructions -> heap-store-optimization -> rse -> vacuum` clusters later in the same full optimization run.

The repo’s no-DWARF path page already notes that `simplify-globals-optimizing` also reruns the default function pipeline on changed functions, without the extra prepended `precompute-propagate`. I am treating that page as the current durable local summary of the wider nested-rerun picture.

## Actual implementation structure

## 1. Pass shape

`CodeFolding` is a `WalkerPass<ControlFlowWalker<...>>` and reports:

- `isFunctionParallel() == true`
- `create() -> new CodeFolding()`

Important consequences:

- it is a **function pass**, not a module pass
- it runs happily in Binaryen’s function-parallel scheduler
- it has direct access to `controlFlowStack` and `getCurrentPointer()`, which is how it recognizes “tail” positions and can replace root-level `return` / `unreachable` expressions that are not inside a block

## 2. The pass state tells the real story

The state fields reveal the actual algorithmic split:

- `breakTails: map<Name, vector<Tail>>`
  - all block-exit tails grouped by target label
- `unreachableTails: vector<Tail>`
  - function-terminating unreachable tails
- `returnTails: vector<Tail>`
  - function-terminating return tails, including `return_call*`
- `unoptimizables: set<Name>`
  - labels the pass refuses to code-fold at block exits because some unsupported branch form targets them
- `modifieds: set<Expression*>`
  - mutated subtrees are not processed again in the same iteration
- `anotherPass`
  - fixpoint flag
- `needEHFixups`
  - whether the iteration added blocks and now needs `EHUtils::handleBlockNestedPops(...)`

That makes a good beginner summary:

- collect possible tails
- fold a few safe ones
- mark rewritten regions as off-limits for this iteration
- run cleanup/fixups
- repeat if the new structure created new opportunities

## 3. `Tail` is a key abstraction

Binaryen’s `Tail` struct models three cases:

- **fallthrough tail**
  - `expr == nullptr`, `block != nullptr`
  - “normal flow reaches the end of this block”
- **block-ending branch tail**
  - `expr` is the tail branch, `block` is the enclosing block
- **root pointer tail**
  - `expr` plus `Expression** pointer`
  - used when a terminating tail is not wrapped in a block and the pass needs to replace the expression in-place

This is why `code-folding` can handle both:

- tails inside named blocks / `if` arms
- tails at the top level of a function body

without pretending they are the same storage problem.

## 4. What the walker records

### Generic branch poisoning

The generic `visitExpression(...)` comment is very explicit:

- any branching instruction not explicitly handled by the pass marks its labels unoptimizable
- TODO: `br_on_*` is not handled yet

This matters because many first impressions of the pass are too broad. Binaryen is not saying “all branch instructions can participate if the AST happens to look similar.” It is saying:

- only a narrow supported subset is foldable today
- everything else poisons the relevant label for block-exit folding

The shipped `br-on-null` test exists specifically to lock this down.

### `visitBreak`

Binaryen only records a break tail if all of these are true:

- the branch is unconditional (`condition == nullptr`)
- the branch is the **last child** of its parent block
- that parent is indeed a `Block`

Otherwise the label is marked unoptimizable.

That is a huge scope restriction.

Binaryen is not folding arbitrary “branches somewhere in a region.” It only handles the easy case where the branch is the block tail.

### `visitUnreachable`

An `unreachable` only becomes a candidate function-terminating tail if it is the last child of its parent block.

### `handleReturn`

The pass records:

- plain `return`
- `return_call`
- `return_call_indirect`
- `return_call_ref`

If the return-like instruction is the last child of a parent block, Binaryen stores a block tail.

Otherwise it still records the tail using `getCurrentPointer()` so the pass can replace the expression directly later.

That subtle pointer path is why the function-terminating subsystem can handle root-level returns at all.

### `visitBlock`

A block is only considered for expression-exit folding when all of these are true:

- it is non-empty
- it has a **name**
- its name is not in `unoptimizables`
- some unconditional block-ending branch tails were recorded for that name

Then Binaryen may add one more tail: the **fallthrough**.

But it only adds fallthrough if the end of the block is reachable. The source tests this conservatively by checking whether any child in the block has `type == unreachable`.

So for named blocks, the foldable family is:

- several explicit `br $label` tails
- maybe also the normal fallthrough to the same block exit

That is how Binaryen can turn “branch with value” plus “fallthrough value” into one shared tail.

### `visitIf`

This is the second expression-level family.

Binaryen requires:

- `ifFalse` exists
- condition is **not** unreachable
- the arms are unnamed blocks, or one arm can be wrapped into a synthetic nameless block because it exactly matches the block-arm suffix

The `maybeAddBlock(...)` helper is important and surprising:

- if one arm is a block and the other is not
- and the non-block arm equals the last element of the block arm
- Binaryen allocates a synthetic `block` around the non-block arm and then continues as though both arms had been blocks all along

The helper comment also says Binaryen ignores metadata for this test, preferring optimization over profiling metadata preservation.

Important guardrails:

- named arm blocks do **not** participate
- unreachable-condition `if`s are skipped because rewriting them into concrete blocks can be type-invalid in context, and Binaryen prefers to leave that to DCE

## 5. Movement safety: `canMove(...)`

This helper is the real “don’t be clever and wrong” firewall.

For a candidate list of items to move out of `outOf`, Binaryen rejects the move if either of these families occurs.

### A. Branch-target escape hazard

Binaryen computes:

- `allTargets = BranchUtils::getBranchTargets(outOf)`
- `exiting = BranchUtils::getExitingBranches(item)`

If an item exits to a target that is defined somewhere in `outOf`, then moving the item out of `outOf` would move the branch past a target it still needs. That is rejected.

This is the key to understanding the `careful-of-the-switch` and “outer target outside merged code” negative families.

Important nuance:

- `ExpressionAnalyzer::equal/hash` can consider two regions equivalent even if they use different internal names in corresponding places
- but `canMove(...)` still rejects actually hoisting them if the moved code would cross a real branch-target scope boundary

So the pass is **not** relying on equality alone for correctness.

### B. Exception-handling movement hazards

When EH is enabled, Binaryen adds two more barriers.

1. `danglingPop`
   - `EffectAnalyzer` rejects moving code that would leave `pop` pseudo-instructions outside the required immediate post-`catch` position.
2. throwing code moving out of `try` / `try_table`
   - if the item may throw, and `outOf` contains a `Try` or `TryTable` anywhere, Binaryen refuses the move
   - the source comment calls this a conservative approximation because a nested safe case may still exist, but Binaryen intentionally does not try to prove that more precise case here

That means a faithful port needs real EH-aware movement guards, not just label reasoning.

## 6. Expression-exit folding algorithm

The function `optimizeExpressionTails(...)` handles both named-block exits and foldable `if-else` arms.

## Candidate precheck

Binaryen first bails out if:

- fewer than two tails exist
- any candidate subtree is in `modifieds`

So one iteration only performs a conservative, non-overlapping set of folds.

## Tail indexing rule

`getMergeable(tail, num)` walks backward from the tail and interprets branches specially:

- if the tail is a branch **with a value**, the branch value is the first mergeable item
- if the tail is a branch **without** a value, the branch instruction itself is skipped and not considered part of the merged suffix
- for fallthroughs, Binaryen just indexes backward through the block list

This is why the pass can merge branch values while leaving the branches themselves in place.

## Backward common-suffix scan

Binaryen repeatedly:

1. reads the next candidate item from the first tail
2. checks that every other tail has an equal corresponding item via `ExpressionAnalyzer::equal(...)`
3. asks `canMove({item}, curr)` whether that item can be moved out
4. if yes, records the item and adds its `Measurer::measure(...)` size to `saved`
5. stops on first mismatch, length exhaustion, or movement failure

This is a true **common suffix** walk, not a search for arbitrary duplicated subsequences.

## Cost model for expression exits

The pass constant is:

- `WORTH_ADDING_BLOCK_TO_REMOVE_THIS_MUCH = 3`

So Binaryen only wants to add helper structure when the merged code saves at least three measured expressions, unless one of two special justifications applies.

### Justification 1: emptying a block

If merging would leave a candidate tail block empty or with just one element, later cleanup can often remove the wrapper entirely.

### Justification 2: the parent is already a block

If `curr` is itself a direct child of a parent block, Binaryen accepts a smaller win because the new wrapper block it adds is likely to be cleaned up later by structural passes.

This is an easy thing to miss:

- Binaryen’s heuristic is not just “suffix length >= 3”
- it explicitly anticipates later cleanup passes making the temporary extra block cheaper than it looks locally

## Rewrite for expression exits

For each tail, Binaryen:

1. marks the tail block as modified using `ExpressionMarker`
2. preserves the tail branch if there is one
   - if the branch had a value, it nulls out the value and keeps the branch
   - if the branch had no value, it temporarily pops and then re-pushes the branch after removing moved items
3. pops the merged suffix items from the tail block
4. refinalizes the tail block
   - fallthrough tails finalize to `none`
   - branch tails keep their previous block type

Then Binaryen builds a new wrapper block:

- first child: the original `curr`, unless this was an `if` whose arms both became empty, in which case it uses `drop(condition)` instead
- then: the merged suffix items, in forward order

Extra nuance for blocks:

- if the original block’s end was unreachable, Binaryen may have moved out the block value while leaving a now-concrete final expression still inside the block
- it calls `builder.dropIfConcretelyTyped(...)` on that final expression to keep typing valid

Finally Binaryen:

- finalizes `curr`
- finalizes the new wrapper block back to the old outer type
- `replaceCurrent(block)`
- sets `anotherPass = true`
- sets `needEHFixups = true`

The “old outer type” preservation is important for ref types and other refined results.

## 7. Function-terminating tail folding algorithm

The second subsystem is `optimizeTerminatingTails(...)`.

This one is fundamentally different from expression exits.

Instead of “all paths to this named exit must share a suffix,” Binaryen looks for any **subset** of terminating tails that share a suffix worth merging at the end of the function body.

## What counts as terminating tails

Candidates come from:

- `unreachableTails`
- `returnTails`

This includes `return_call*` because `handleReturn(...)` records them as return tails.

## Recursive depth search

The `num` parameter means:

- how many trailing items are already known equal in this subgroup

Binaryen searches deeper first.

At each depth it:

1. removes tails that are too short
2. removes tails whose new depth item has external break targets according to `EffectAnalyzer(...).hasExternalBreakTargets()`
3. hashes each remaining depth item with `ExpressionAnalyzer::hash(...)`
4. groups matching hashes
5. confirms equal items with `ExpressionAnalyzer::equal(...)`
6. recursively explores each equal subgroup at depth `num + 1`

This is not an exhaustive optimal search. The source comment is explicit:

- Binaryen does not look hard for the globally most optimal merge
- if it finds a profitable deeper merge, it performs that and leaves more for later passes / later iterations

That is a very port-relevant detail. Upstream prefers a cheap deterministic improvement over an expensive exact optimum.

## Cost model for terminating tails

`worthIt(...)` estimates:

- saved size = sum of merged item sizes times `(tails.size() - 1)`
- cost = replacing each tail with a branch, plus adding helper block structure

Important details:

- Binaryen assumes two helper blocks are likely needed
- if the merged items cannot be safely moved all the way to the function end (`canMove(items, getFunction()->body)`), the current implementation refuses the optimization instead of inserting the helper blocks at some smarter intermediate position
- comments acknowledge this is conservative and could be improved later with parent tracking

So the current upstream implementation is intentionally simpler than the general problem.

## Rewrite for terminating tails

When Binaryen commits to a terminating-tail fold, it:

1. creates a fresh label like `folding-inner0` with `LabelUtils::LabelManager`
2. rewrites every selected tail to branch to that label
   - block-backed tails pop the merged suffix and end in `br $folding-innerN`
   - pointer-backed tails are replaced directly with `br $folding-innerN`
3. builds a new inner block with that label
4. puts the old function body inside the inner block
   - if the old body is still reachable, Binaryen adds `return` logic so flow cannot fall through into the merged suffix accidentally
5. builds an outer block containing:
   - the inner labeled block with the old body
   - the merged suffix code
6. finalizes the new outer body to the function result type
7. sets `getFunction()->body = outer`
8. sets `anotherPass = true` and `needEHFixups = true`

This is why the pass can share function-ending `return` / `unreachable` code without turning the whole function body inside out.

## 8. Why `modifieds` and the fixpoint loop both matter

At first glance `modifieds` and `anotherPass` can look redundant. They are not.

### `modifieds`

Prevents the same iteration from reprocessing a region that was just structurally changed.

That keeps the implementation simple and avoids subtle within-iteration bugs.

### `anotherPass`

Allows later iterations to benefit from the newly simplified shape.

That is how upstream gets a controlled fixpoint without trying to reason perfectly about every newly created fold in one traversal.

## 9. EH fixups are part of the main algorithm, not cleanup garnish

Every successful fold that adds helper blocks sets `needEHFixups = true`.

At the end of the iteration, `doWalkFunction(...)` runs:

- `EHUtils::handleBlockNestedPops(func, *getModule())`

This is a real correctness requirement:

- code folding can create new block nesting around code that interacts with `pop`
- Binaryen has dedicated EH fixup machinery for exactly that problem

A future Starshine port should not treat EH repair as optional “nice to have” cleanup.

## Important WAT / IR shape families

## Positive family 1: if arms with identical whole value block

From the tests:

```wat
(func $negative-zero-b (result f32)
  (if (result f32)
    (i32.const 0)
    (then
      (block (result f32)
        (f32.const -0)
      )
    )
    (else
      (block (result f32)
        (f32.const -0)
      )
    )
  )
)
```

Binaryen folds this to:

```wat
(drop (i32.const 0))
(f32.const -0)
```

Takeaway:

- if both unnamed block arms become empty after moving the identical tail out, Binaryen replaces the `if` itself with `drop(condition)` rather than keeping an empty `if`

## Positive family 2: block-exit branches with identical branch values

From the tests:

```wat
(block $l (result i32)
  (block
    (br $l (i32.const 1)))
  (block
    (br $l (i32.const 1)))
  (i32.const 1))
```

Binaryen turns the two branch values into one shared tail after the block.

Takeaway:

- a branch-with-value tail is modeled as “branch value + branch shell”
- the value can move out while the branch remains in place, now valueless

## Positive family 3: branch tail plus fallthrough tail sharing the same value

Also from the tests:

```wat
(block $l (result i32)
  (drop
    (block (result i32)
      (br $l (i32.const 1))))
  (drop
    (block (result i32)
      (br $l (i32.const 1))))
  (i32.const 1))
```

Binaryen can treat the block’s own fallthrough as another tail and share the value.

That is one of the easiest details to miss if you only read the CLI name and not the code.

## Positive family 4: one non-block if arm wrapped to match the other arm’s suffix

The `positive-zero-extra-*` tests show Binaryen can create a synthetic block around a non-block arm when it exactly matches the block arm’s tail.

Takeaway:

- the pass is willing to add structure in order to expose a profitable fold
- it is not limited to source trees that already have symmetric block arms

## Positive family 5: function-ending duplicated tail code

The `determinism` and `break-target-inside-all-good` tests show Binaryen lifting identical terminating tails into a shared suffix at the end of the function body.

Takeaway:

- `code-folding` is not only about block labels or `if` arms
- it also performs a late whole-function tail merge for control-flow terminators

## Negative family 1: simple non-block `if` arms are left alone

`positive-zero` is intentionally not optimized by this pass.

Reason:

- `code-folding` only wants `if`s with block arms (or a synthetic block-wrappable arm)
- the simpler pure-expression case is left to `optimize-instructions`

So a future port should not broaden `code-folding` just because the CLI name sounds generic.

## Negative family 2: named arm blocks do not fold

`positive-zero-names` keeps identical values in both arms because the arm blocks have names.

Reason:

- a named arm block could be branched to, and moving its suffix out could skip code that the branch expects to execute

## Negative family 3: unreachable-condition `if` with concrete arms is skipped

The source comment explicitly says Binaryen leaves this for DCE.

Reason:

- replacing an unreachable `if` with a concrete block result can produce invalid surrounding typing depending on context

## Negative family 4: unsupported branch forms poison label folding

The shipped `br-on-null` test makes this concrete.

Two tails may look identical, but the presence of `br_on_null` to the same label prevents folding.

Reason:

- the generic visitor deliberately marks labels reached by unsupported branch forms as unoptimizable

## Negative family 5: control targets inside moved code forbid hoisting

The `careful-of-the-switch` test is a classic trap.

Two blocks are structurally equal if you mentally alpha-rename their internal labels, but they branch to a target that is defined in the outer region they would be hoisted out of.

`canMove(...)` rejects that move.

This is a major easy-to-misunderstand point:

- equality is not enough
- branch-target scope must still be valid after movement

## Negative family 6: effect differences remain visible

`atomic-load-different` shows that a normal load and an atomic load are not equal tails.

That sounds obvious, but it matters because the pass runs late in size-optimization mode where many shapes look syntactically close.

## Negative family 7: refined type contexts can go stale

The `refined-type` and `refined-type-blocks` tests show that result typing is subtle in ref-typed contexts.

Takeaway:

- direct non-block arm folding can leave stale surrounding types
- Binaryen’s block-arm discipline plus outer-type preservation are part of the correctness story

## What this pass does not do

`code-folding` is not:

- `local-cse`
  - it does not just reuse equivalent computations inside one flat basic block
- `merge-blocks`
  - it may create helper blocks, while `merge-blocks` later removes safe wrappers
- `remove-unused-brs`
  - it does not primarily remove redundant control flow; it creates shared tails that later branch cleanup can simplify further
- `rse`
  - it is not about redundant writes
- generic CFG tail-merging for all branch forms
- an optimal global search for best merges

A good beginner summary is:

- it shares obviously duplicated tails in a few high-value structured families
- then it lets later cleanup passes simplify the helper structure it introduced

## Helper and analysis dependencies that matter for a port

## `ExpressionAnalyzer`

Used for:

- structural equality
- structural hashing for subgroup discovery in terminating tails

Important nuance from `utils.h`:

- hashing ignores superficial internal-name differences

That makes folding more powerful, but it also makes `canMove(...)` indispensable.

## `Measurer`

Used for the size heuristic.

Important nuance:

- it counts expressions, not exact emitted bytes
- the threshold constant is therefore a rough AST-size heuristic, not a literal binary-byte threshold

## `BranchUtils`

Used for:

- iterating scope-name uses
- discovering branch targets defined in a region
- discovering which branches exit a subtree

This is the main control-flow safety dependency.

## `EffectAnalyzer`

Used for:

- detecting external break targets in terminating-tail search
- detecting EH hazards in `canMove(...)`
  - `danglingPop`
  - throwing code moved past `try` / `try_table`

## `LabelUtils::LabelManager`

Used for generating fresh `folding-innerN` labels in function-ending tail merges.

## `EHUtils`

Used after rewrites that add helper blocks.

That is not a cosmetic cleanup. It is part of preserving EH-valid Binaryen IR.

## What a future Starshine port must preserve first

If Starshine ports `code-folding`, the implementation should preserve these upstream-level facts before trying to be cleverer or broader:

1. two separate families:
   - expression exits
   - function-ending terminators
2. unconditional end-of-block `br` requirement for block-exit folding
3. nameless-arm discipline for `if` folding
4. unsupported branch-form poisoning for label folding
5. `canMove(...)`-style branch-target scope checks
6. EH movement guards for dangling `pop` and throwing code in `try` / `try_table`
7. size heuristic and “worth adding a block” rule
8. fixpoint iteration with “modified in this pass” suppression
9. EH fixups after block-adding rewrites
10. late scheduler placement before `merge-blocks` / late branch cleanup / `rse`

Those are the real contracts. A port that only “finds common suffixes” but ignores those guardrails will not be a faithful Binaryen port.

## Suggested reduced regression matrix for a future Starshine port

Minimum high-value fixtures:

1. unnamed `if` blocks with identical whole-arm tail
2. one block arm plus one wrappable non-block arm
3. named arm blocks must not fold
4. simple non-block `if` arms left for other passes
5. block-exit branch values shared across multiple `br $label` tails
6. block-exit branch value shared with fallthrough value
7. terminating `return` tails shared at function end
8. terminating `unreachable` tails shared at function end
9. outer-target branch hazard refuses move (`careful-of-the-switch` family)
10. unsupported branch form poisons label (`br_on_null` family)
11. unreachable-condition `if` skipped
12. ref-typed surrounding context keeps correct outer type after fold
13. EH-only regression: moved code containing `pop` or throwing-through-`try` must bail
14. repeated-pass regression: first fold unlocks second fold only in next iteration

## Easy misunderstandings

1. **“This is just common suffix merging.”**
   - Not quite. There are two subsystems with different storage and profitability logic.
2. **“Any branch to a label can participate.”**
   - False. Only a narrow subset is handled. Unsupported branch forms poison the label.
3. **“If the tails are equal, hoisting is safe.”**
   - False. `canMove(...)` still checks branch-target scope and EH hazards.
4. **“The pass just removes code.”**
   - Not always. It often adds helper blocks and branches to save more total code later.
5. **“One traversal is enough.”**
   - Upstream explicitly runs to a fixpoint because folds expose more folds.
6. **“Type repair is trivial.”**
   - Not in ref-typed and unreachable-adjacent contexts. The tests prove Binaryen is careful here.

## Open questions / uncertainty

1. The pass comments explain the high-level safety conditions very well, but some profitability decisions still rely on heuristics rather than a formal optimality proof. That is intentional upstream behavior, not missing documentation.
2. The exact nested-rerun story for `simplify-globals-optimizing` is already summarized on the repo’s no-DWARF page, but I did not re-open that pass’s source in this thread. I am treating the repo page plus the observed repeated late-cluster log entries as the durable local source for that broader scheduler note.
3. The current terminating-tail implementation refuses some theoretically valid moves when it cannot cheaply reinsert helper blocks in the ideal intermediate location. The source comments acknowledge this. A future Starshine port should match current Binaryen behavior before considering broader generalization.

## Durable conclusions

- `code-folding` is a late, size-oriented, function-parallel Binaryen pass with two separate rewrite families: expression exits and function-ending terminators.
- It only handles a deliberately narrow set of branch shapes. Unsupported branch forms are explicit bailouts, not accidental omissions.
- The heart of correctness is not just equality testing; it is the combination of structural equality, scope-aware movement checks, EH-aware movement checks, outer-type preservation, and iteration discipline.
- The pass is comfortable introducing helper blocks when the size heuristic says the fold is worthwhile, because late cleanup neighbors are expected to simplify that structure afterwards.
- The saved generated-artifact audit proves this pass is not hypothetical future scope: it is a real missing slot today, both at top level and inside nested cleanup reruns.
- A faithful Starshine port should preserve upstream narrowness first, and only then consider broader or HOT-native experimentation.