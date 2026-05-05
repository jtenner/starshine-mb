---
kind: concept
status: supported
last_reviewed: 2026-05-05
sources:
  - ../../../raw/binaryen/2026-04-25-code-folding-current-main-recheck.md
  - ../../../raw/binaryen/2026-05-05-code-folding-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-22-code-folding-primary-sources.md
  - ../../../raw/research/0351-2026-04-25-code-folding-current-main-and-test-map.md
  - ../../../raw/research/0442-2026-05-05-code-folding-current-main-recheck.md
  - ../../../raw/research/0112-2026-04-20-code-folding-binaryen-research.md
  - ../../../raw/research/0257-2026-04-22-code-folding-primary-sources-and-starshine-followup.md
related:
  - ./index.md
  - ./implementation-structure-and-tests.md
  - ./terminating-tails.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
  - ../../no-dwarf-default-optimize-path.md
---

# Binaryen `code-folding` Strategy

## Upstream source rule

- Use Binaryen `version_129` as the current released source oracle for this pass.
- The raw source manifest for the 2026-04-22 tagged recheck lives in [`../../../raw/binaryen/2026-04-22-code-folding-primary-sources.md`](../../../raw/binaryen/2026-04-22-code-folding-primary-sources.md).
- The 2026-05-05 current-main bridge lives in [`../../../raw/binaryen/2026-05-05-code-folding-current-main-recheck.md`](../../../raw/binaryen/2026-05-05-code-folding-current-main-recheck.md) and found no teaching-relevant drift in the reviewed owner, registry, helper, constructor, or lit-test surfaces.
- On 2026-04-22 the reviewed official Binaryen `version_129` release page showed publish date **2026-04-01**.
- The core implementation is `src/passes/CodeFolding.cpp`.
- Scheduler placement comes from `src/passes/pass.cpp` and the after-inlining helper in `src/passes/opt-utils.h`.
- The key helper contracts come from:
  - `src/ir/utils.h`
  - `src/ir/branch-utils.h`
  - `src/ir/effects.h`
  - `src/ir/eh-utils.h`
  - `src/ir/label-utils.h`
- The shipped behavior examples come from `test/lit/passes/code-folding.wast`.

Primary source URLs:

- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/CodeFolding.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/opt-utils.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/utils.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/branch-utils.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/effects.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/eh-utils.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/label-utils.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/code-folding.wast>

## High-level intent

A focused 2026-05-05 spot check on current `main` (`CodeFolding.cpp`, `pass.cpp`, `opt-utils.h`, `passes.h`, and the dedicated `code-folding.wast` file) did not surface a new teaching-relevant drift beyond the `version_129` contract summarized here. See [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md) for the source-owner and lit-test map.


Binaryen uses `code-folding` to share duplicated tails of code.

That sentence is true but incomplete.

The actual implementation is split into two different strategies:

| Strategy family | What gets merged | Where the shared code moves |
| --- | --- | --- |
| Expression-exit folding | identical tails on named block exits or `if-else` arms | right after the expression whose exits merged |
| Function-terminating folding | identical tails on `return`, `return_call*`, or `unreachable` paths | to a shared suffix at the end of the function body |

That split is the single most important thing to remember when describing the pass.

## The pass in one table

| Phase | What Binaryen does | Why it exists |
| --- | --- | --- |
| Collect tails | Track unconditional end-of-block `br`s, block fallthroughs, `return`s, `return_call*`, and `unreachable`s | Build candidate merge sets without solving arbitrary CFG matching |
| Mark unoptimizable labels | Any unsupported branching form targeting a label poisons label-based folding for that label | Avoid unsound generic label folding |
| Check movement safety | Use `BranchUtils` and EH-aware `EffectAnalyzer` logic in `canMove(...)` | Do not hoist code past its own targets or out of EH-sensitive scope |
| Measure profitability | Count merged expressions with `Measurer`; only add helper blocks when the win is worth it | Size optimization, not rewrite-for-its-own-sake |
| Rewrite | Remove duplicated tails, add shared wrapper blocks or shared terminating label block | Keep a single shared copy of the suffix |
| Repair | Run EH block-pop fixups when needed and iterate again if more folds may now exist | Preserve valid Binaryen IR and reach a cheap fixpoint |

## Phase 1: the pass is function-parallel and fixpoint-driven

`CodeFolding` reports `isFunctionParallel() == true`, so Binaryen treats it as a per-function pass that can run across functions in parallel.

Inside each function, though, it is deliberately iterative.

`doWalkFunction(...)` does this:

1. clear per-iteration state
2. walk the function and record candidates
3. run terminating-tail folding on `unreachableTails`
4. run terminating-tail folding on `returnTails`
5. clear the candidate maps/sets
6. run EH fixups if a rewrite added blocks
7. loop again if `anotherPass` was set

That means a faithful port should expect "one successful fold exposes another" to be normal, not exceptional.

## Phase 2: candidate collection is deliberately narrow

## Named block exits

Binaryen only tries label-based folding on a block when all of these are true:

- the block is non-empty
- the block has a **name**
- the name is not in `unoptimizables`
- unconditional block-ending branches to that name were recorded earlier

Then it may also add the block's own **fallthrough** as another tail if the end of the block is reachable.

So the candidate family is not “anything that eventually reaches a label.” It is:

- unconditional tail `br`s to a named block exit
- maybe the normal fallthrough to the same exit

## `if-else` arms

Binaryen only tries `if` folding when:

- there is an `else` arm
- the condition is not unreachable
- both arms are unnamed blocks, or
- one arm is an unnamed block and the other can be wrapped into a synthetic unnamed block because it exactly matches the block arm's suffix

This is much narrower than generic arm-to-arm similarity.

## Function-ending terminators

Binaryen separately records:

- `return`
- `return_call`
- `return_call_indirect`
- `return_call_ref`
- `unreachable`

It prefers the end-of-parent-block case, but it can also track root-level terminating expressions via an `Expression**` replacement pointer.

## Phase 3: unsupported branch forms poison label folding

The generic visitor comment in `CodeFolding.cpp` is explicit:

- for any branching instruction not explicitly handled by this pass, mark the labels it branches to unoptimizable
- TODO: `br_on_*` instructions are still not handled here

That gives the pass a very important negative contract:

- a label target can look profitable
- but the presence of an unsupported branch form to that label is enough to make the pass skip label-based folding there entirely

The shipped `br-on-null` test is the easiest beginner-facing example of this rule.

## Phase 4: movement safety is the real correctness boundary

The helper `canMove(items, outOf)` is where most of the hidden correctness work lives.

## Branch-target scope check

Binaryen computes:

- all targets defined inside `outOf`
- all exiting branches inside the candidate item being moved

If the moved item exits to a target that lives inside `outOf`, then moving the item out of `outOf` would strand that branch outside the scope it needs. Binaryen rejects the move.

This is the key reason the pass is safer than a naive “common suffix + alpha equivalence” algorithm.

Even if:

- `ExpressionAnalyzer::equal(...)` says two suffixes are structurally equivalent, and
- internal names can be matched flexibly,

Binaryen still refuses the transformation if actual branch-target scope would become invalid.

## Exception-handling safety

When exception handling is enabled, `canMove(...)` adds two more barriers.

### `danglingPop`

If moving the item could leave a `pop` outside the required immediate post-`catch` position, Binaryen rejects the move.

### throwing code inside `try` / `try_table`

If the item may throw, and `outOf` contains a `Try` or `TryTable`, Binaryen also rejects the move.

The source comment is candid that this is conservative. Some safe subcases may exist, but the pass intentionally does not try to prove them.

Beginner takeaway:

- `code-folding` is not just about equality and labels
- EH-sensitive motion is part of the contract too

## Phase 5: expression-exit folding works backward from the tail

`optimizeExpressionTails(...)` handles both named block exits and foldable `if-else` arms.

## Backward matching rule

Binaryen compares tails from the end backward.

For a branch tail, the indexing is special:

- if the branch has a value, the branch value is treated as the first mergeable item
- if the branch has no value, the branch itself is skipped and is not part of the moved suffix

That is how Binaryen can share branch payloads without needing to remove and re-create the branches themselves.

## Equality and hashing inputs

At this stage Binaryen uses:

- `ExpressionAnalyzer::equal(...)` for actual suffix equality
- `Measurer::measure(...)` for size accounting

For `if` arm wrapping, the source comment also makes an important policy choice explicit:

- metadata is ignored while looking for a matching suffix worth folding

## Profitability heuristic

The constant is:

- `WORTH_ADDING_BLOCK_TO_REMOVE_THIS_MUCH = 3`

That means Binaryen wants to remove at least three measured expressions before it is happy to add a helper block.

But it also has two deliberate escape hatches.

### Escape hatch 1: emptying a tail block

If the fold will empty a block or leave it with one item, later cleanup can often remove the wrapper, so Binaryen may accept a smaller immediate win.

### Escape hatch 2: the parent is already a block

If the current expression is already a direct child of a parent block, Binaryen may accept the fold because the new helper block is likely to be merged away later.

This is a good example of a pass interacting with its scheduler neighbors by design.

## Rewrite shape for expression exits

Once Binaryen commits to an expression-exit fold, it:

1. marks the mutated block subtree as modified for this iteration
2. strips the duplicated suffix from every tail block
3. preserves the original tail branch shell where needed
4. refinalizes each tail block
5. builds a new wrapper block containing:
   - the original expression (or `drop(condition)` if an `if` became empty in both arms)
   - then the shared suffix code
6. refinalizes the inner expression
7. finalizes the wrapper block back to the original outer type
8. replaces the current expression with the wrapper block

Important nuance:

- for block-based folds with no fallthrough, Binaryen may need to `drop` a concrete expression still sitting at the old block tail, because the value-producing part of the block was moved out

## Phase 6: function-terminating folding is a different algorithm

`optimizeTerminatingTails(...)` is not a small variant of the expression-exit algorithm.

The big differences are:

- it looks for a profitable **subset** of matching terminating tails, not necessarily all tails in one group
- it searches deeper equal suffixes first, recursively
- it builds a fresh label block at the end of the function body and rewrites tails to branch there

That is why this family deserves its own dedicated page: [`terminating-tails.md`](./terminating-tails.md).

## Phase 7: helper dependencies are doing real semantic work

## `ExpressionAnalyzer`

- equality for suffix matching
- hashing for subgroup discovery in terminating tails
- hash comments in `utils.h` make it explicit that superficial internal-name differences are ignored

## `Measurer`

- the size heuristic input
- counts expressions, not literal emitted bytes

## `BranchUtils`

- scope-name traversal
- defined target discovery
- exiting branch discovery

This is the core control-flow safety dependency.

## `EffectAnalyzer`

Used here for two very specific reasons:

- `hasExternalBreakTargets()` in terminating-tail search
- EH movement barriers in `canMove(...)`

That makes it easy to overstate its role. `code-folding` is not primarily an effect-optimization pass, but effect analysis still matters at the exact points where unsound motion would occur.

## `LabelUtils::LabelManager`

- creates fresh `folding-innerN` labels for function-ending tail merges

## `EHUtils::handleBlockNestedPops`

- repairs EH-sensitive block nesting after the pass adds helper blocks

## Phase 8: scheduler placement is part of the meaning

In `pass.cpp`, Binaryen schedules `code-folding` late in the default function pipeline:

- after the late `vacuum`
- before `merge-blocks`
- before late `remove-unused-brs`
- before late `remove-unused-names`
- before the second late `merge-blocks`
- before late `precompute(-propagate)`, `optimize-instructions`, `heap-store-optimization`, `rse`, and final `vacuum`

That placement says a lot about intended use:

- earlier local cleanup has already made tails easier to compare
- `code-folding` may introduce helper structure
- late structural and branch cleanup then simplify the helper structure again
- late peepholes and `rse` run after the single-copy tail exists

`opt-utils.h` shows that after-inlining cleanup prepends `precompute-propagate` and then reruns the full default function pipeline on touched functions, which means `code-folding` also reappears under optimizing passes like `dae-optimizing` and `inlining-optimizing`.

## What the pass does **not** do

A future Starshine port should avoid accidentally broadening the pass beyond upstream behavior.

`code-folding` does **not**:

- solve arbitrary CFG tail merging
- fold every kind of branch form
- act as plain local CSE
- replace `merge-blocks`
- replace `remove-unused-brs`
- guarantee globally optimal merge selection
- treat every equal suffix as movable

The real Binaryen contract is narrower and more structured than the CLI name suggests.

## The most important porting lessons

If Starshine ports `code-folding`, preserve these facts first:

1. two distinct algorithms: expression exits and function-ending terminators
2. only unconditional end-of-block `br` tails participate in label-based folding
3. unsupported branch forms poison label-based folding
4. `if` arm folding is unnamed-block-only, plus the one-arm synthetic-block helper case
5. movement safety is a first-class requirement, not a bonus check
6. EH fixups are part of the rewrite contract
7. the pass is allowed to add helper blocks when the heuristic says it is worth it
8. the pass is intentionally iterative and non-overlapping within one iteration
9. late scheduler placement is part of why the transform pays off

For the staged local implementation order, HOT prerequisites, and validation ladder, see [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md).

Those are the durable upstream-level truths.

## Sources

- [`../../../raw/binaryen/2026-04-25-code-folding-current-main-recheck.md`](../../../raw/binaryen/2026-04-25-code-folding-current-main-recheck.md)
- [`../../../raw/binaryen/2026-05-05-code-folding-current-main-recheck.md`](../../../raw/binaryen/2026-05-05-code-folding-current-main-recheck.md)
- [`../../../raw/binaryen/2026-04-22-code-folding-primary-sources.md`](../../../raw/binaryen/2026-04-22-code-folding-primary-sources.md)
- [`../../../raw/research/0351-2026-04-25-code-folding-current-main-and-test-map.md`](../../../raw/research/0351-2026-04-25-code-folding-current-main-and-test-map.md)
- [`../../../raw/research/0442-2026-05-05-code-folding-current-main-recheck.md`](../../../raw/research/0442-2026-05-05-code-folding-current-main-recheck.md)
- [`../../../raw/research/0112-2026-04-20-code-folding-binaryen-research.md`](../../../raw/research/0112-2026-04-20-code-folding-binaryen-research.md)
- [`../../../raw/research/0257-2026-04-22-code-folding-primary-sources-and-starshine-followup.md`](../../../raw/research/0257-2026-04-22-code-folding-primary-sources-and-starshine-followup.md)
- Binaryen `version_129` pass source: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/CodeFolding.cpp>
- Binaryen `version_129` scheduler source: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- Binaryen `version_129` after-inlining helper: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/opt-utils.h>
- Binaryen `version_129` IR utilities: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/utils.h>
- Binaryen `version_129` branch utilities: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/branch-utils.h>
- Binaryen `version_129` effects helpers: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/effects.h>
- Binaryen `version_129` EH helpers: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/eh-utils.h>
- Binaryen `version_129` label helpers: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/label-utils.h>
- Binaryen `version_129` lit tests: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/code-folding.wast>
- Binaryen current `main` pass source: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/CodeFolding.cpp>
- Binaryen current `main` lit tests: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/code-folding.wast>
