# 0122 - `simplify-globals-optimizing` Binaryen research

## Status

- Date: 2026-04-20
- Type: One-off raw investigation
- Scope: document one currently unimplemented no-DWARF / `-O4z` Binaryen pass in Starshine, using Binaryen `version_129` plus the saved generated-artifact audit to explain how `simplify-globals-optimizing` really works, which helpers it leans on, which IR shapes it rewrites or preserves, and what a future Starshine port must keep correct.

## Why this pass

- `docs/wiki/binaryen/passes/tracker.md` still listed `simplify-globals-optimizing` with wiki status `none` when this thread started.
- The pass is still only a boundary-only placeholder in `src/passes/optimize.mbt`.
- The canonical Binaryen no-DWARF `-O` / `-Os` path runs it in the late global post-pass cluster after:
  - `duplicate-function-elimination`
  - `duplicate-import-elimination`
- and before:
  - `remove-unused-module-elements`
  - `string-gathering`
  - `reorder-globals`
  - `directize`
- The saved generated-artifact `-O4z` audit records it as a real skipped top-level upstream slot:
  - slot `52`
- This pass is easy to underread as “replace `global.get` with constants.” The actual Binaryen implementation is much richer:
  - it first analyzes all global traffic across functions and module-level init code
  - it has a special whole-program `read-only-to-write` elimination family
  - it can fold single-use globals into other global initializers, even when that means copying a generative initializer exactly once
  - it canonicalizes immutable global-copy chains to the earliest ancestor when types still match
  - it distinguishes startup-time propagation into later globals and segment offsets from runtime propagation into function code
  - the `optimizing` variant reruns the default function optimization pipeline on changed functions, but notably **without** the extra prepended `precompute-propagate` used by `dae-optimizing` and `inlining-optimizing`
- That combination makes it a strong follow-up dossier after the freshly documented `dae-optimizing` and `inlining-optimizing` passes: it is the remaining no-DWARF late boundary/global cleanup pass with a nested rerun contract and several easy-to-misunderstand sub-algorithms.

## Saved local source material

### Local Starshine / audit sources

- `src/passes/optimize.mbt`
- `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `agent-todo.md`
- `.artifacts/o4z-wasm-opt-debug.log`
- `.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/summary.json`
- `.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/skipped-unimplemented-slots.json`
- `docs/wiki/raw/research/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md`
- `docs/wiki/raw/research/0093-2026-04-18-generated-o4z-pass-audit-summary.md`

### Official Binaryen `version_129` sources

- `src/passes/SimplifyGlobals.cpp`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/SimplifyGlobals.cpp>
- `src/passes/pass.cpp`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- `src/pass.h`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/pass.h>
- `src/ir/effects.h`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/effects.h>
- `src/ir/find_all.h`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/find_all.h>
- `src/ir/linear-execution.h`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/linear-execution.h>
- `src/ir/properties.h`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/properties.h>
- `src/ir/utils.h`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/utils.h>
- `test/lit/passes/simplify-globals-dominance.wast`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/simplify-globals-dominance.wast>
- `test/lit/passes/simplify-globals-gc.wast`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/simplify-globals-gc.wast>
- `test/lit/passes/simplify-globals-nested.wast`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/simplify-globals-nested.wast>
- `test/lit/passes/simplify-globals-non-init.wast`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/simplify-globals-non-init.wast>
- `test/lit/passes/simplify-globals-offsets.wast`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/simplify-globals-offsets.wast>
- `test/lit/passes/simplify-globals-prefer_earlier.wast`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/simplify-globals-prefer_earlier.wast>
- `test/lit/passes/simplify-globals-read_only_to_write.wast`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/simplify-globals-read_only_to_write.wast>
- `test/lit/passes/simplify-globals-single_use.wast`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/simplify-globals-single_use.wast>
- `test/lit/passes/simplify-globals_func-effects.wast`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/simplify-globals_func-effects.wast>
- `test/lit/passes/propagate-globals-globally.wast`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/propagate-globals-globally.wast>
- Binaryen `version_129` release page
  - <https://github.com/WebAssembly/binaryen/releases/tag/version_129>

## Fast answer

Binaryen’s `simplify-globals-optimizing` pass is a late module/global cleanup pass that repeatedly:

1. scans the module to learn which globals are imported, exported, written, read, written with non-initial values, or only read in order to be written
2. folds some single-use globals into other global initializers
3. removes useless `global.set`s and may need another whole iteration when doing so exposes nested `read-only-to-write` patterns
4. rewrites immutable global-copy chains to earlier equivalent ancestors when types still match
5. propagates compile-time-known global values into later global initializers and segment offsets
6. propagates immutable or currently known global values into function code using a cheap linear-execution model
7. if the `optimizing` variant is active, reruns the default function optimization pipeline on changed functions

That means the pass is **not** just:

- “turn immutable globals into constants”
- “replace `global.get` with `i32.const`”
- “optimize globals only inside functions”
- or “the same nested rerun helper used by `dae-optimizing` and `inlining-optimizing`”

The most durable source-derived facts are:

- The plain and optimizing variants share the same core `SimplifyGlobals` implementation.
- The pass has several distinct transformation families:
  - single-use global-init folding
  - dead or redundant `global.set` removal
  - `read-only-to-write` global elimination
  - immutable copy-chain canonicalization
  - startup-time constant propagation into later globals and segment offsets
  - runtime constant/global-value propagation into code
- The optimizing variant is triggered only when code actually changed inside a function, and it reruns `addDefaultFunctionOptimizationPasses()` directly.
- Unlike `dae-optimizing` and `inlining-optimizing`, this pass does **not** prepend `precompute-propagate` before its nested cleanup reruns.
- The pass is conservative around imports, exports, actual calls, nonlinear control flow, actual AST-node identity for gets/sets, and type changes that would require more repair than the current helper does.

## CLI names and scheduler placement

## Pass registration surface

`pass.cpp` registers three relevant names from this implementation file:

- `simplify-globals`
- `simplify-globals-optimizing`
- `propagate-globals-globally`

The first two are production surfaces. The third is a testing-oriented sub-pass that runs only the startup-time global-to-global propagation phase.

The registration descriptions in `pass.cpp` are informative:

- `simplify-globals`
  - “miscellaneous globals-related optimizations”
- `simplify-globals-optimizing`
  - “miscellaneous globals-related optimizations, and optimizes where we replaced global.gets with constants”

That wording already hints that the optimizing variant is not a separate algorithm from scratch. It is the same pass body with extra follow-up function cleanup.

## Top-level no-DWARF placement

In `PassRunner::addDefaultGlobalOptimizationPostPasses()`, Binaryen `version_129` schedules:

- `simplify-globals-optimizing` when:
  - `optimizeLevel >= 2`, or
  - `shrinkLevel >= 2`
- otherwise plain `simplify-globals`

In the canonical no-DWARF `-O` / `-Os` path tracked in this repo, that means the late post-pass tail is:

- `dae-optimizing`
- `inlining-optimizing`
- `duplicate-function-elimination`
- `duplicate-import-elimination`
- `simplify-globals-optimizing`
- `remove-unused-module-elements`
- `string-gathering`
- `reorder-globals`
- `directize`

That placement matters. `simplify-globals-optimizing` can expose dead globals and simpler global initializers, so it is intentionally followed by module cleanup and global-layout passes.

## Saved generated-artifact `-O4z` evidence

The committed saved ordered audit records:

- slot `52`: `simplify-globals-optimizing`

The saved `o4z-wasm-opt-debug.log` also shows that the pass is not “one top-level name and done.” Between the top-level `simplify-globals-optimizing` line and the next top-level `remove-unused-module-elements` line, the saved log contains:

- `3` nested pass batches

That matches the implementation shape: the optimizing variant reruns function optimizations per changed function, so each changed function can trigger one nested batch.

Unlike the `dae-optimizing` / `inlining-optimizing` helper path, the current saved log does not prove an extra prepended `precompute-propagate` here. The direct source proof is stronger: `SimplifyGlobals.cpp` calls `addDefaultFunctionOptimizationPasses()` directly on a nested `PassRunner`, without using `OptUtils::addUsefulPassesAfterInlining(...)`.

## Actual implementation structure

## 1. One core pass, one boolean, one fixpoint loop

The main implementation is `struct SimplifyGlobals : public Pass` with one key data member:

- `bool optimize`

The plain and optimizing variants are created by:

- `createSimplifyGlobalsPass()`
  - `optimize = false`
- `createSimplifyGlobalsOptimizingPass()`
  - `optimize = true`

The pass runs as:

- `while (iteration()) {}`

That is important because it means Binaryen expects some global simplifications to expose **new** global simplifications in later full scans.

However, it is not an unconstrained “rerun until nothing changes anywhere” design. The implementation only returns `true` from `iteration()` for a specific reason: removing one `read-only-to-write` family can expose another nested one. The other phases do not themselves ask for extra whole-pass iterations.

## 2. `analyze()` builds the real global fact table

The core per-global record is `GlobalInfo`, which stores:

- whether the global is imported
- whether the global is exported
- how many times it is written
- how many times it is read
- whether it is ever written a value that may differ from its initializer
- how many `read-only-to-write` pattern appearances were found

This analysis is not restricted to function bodies.

The pass first seeds import/export facts from the module structure, then runs `GlobalUseScanner` over:

- normal function bodies
- module-level code (`runOnModuleCode`)

So Binaryen is reasoning across both runtime code and instantiation-time expressions.

## 3. Practical immutability is stronger than declared immutability

After scanning, `analyze()` marks some mutable globals as immutable in practice:

- the global must be mutable now
- it must not be imported
- it must not be exported
- it must have no writes

That is a good beginner reminder that `simplify-globals` is not limited to what the original module declared. It can discover that a mutable global behaves like an immutable one and tighten that fact for later phases.

## 4. `nonInitWritten` is how Binaryen distinguishes redundant writes from meaningful writes

When `GlobalUseScanner` sees a `global.set`, it increments the write count and then asks whether the write may differ from the global’s initializer.

It sets `nonInitWritten = true` if any of these hold:

- the global is imported
- the written value is not a constant expression
- the initializer is not a constant expression
- the written literals differ from the initializer literals

So the pass does **not** treat every write as equally meaningful.

A write of the exact same compile-time value as the initializer is closer to dead bookkeeping than to a state transition, and later phases exploit that.

## 5. `read-only-to-write` is a real sub-algorithm, not a one-line special case

This is one of the most distinctive parts of the file.

The pass looks for cases where a global is read only to decide whether to write that same global, such as:

```wat
(if
  (global.get $g)
  (then
    (global.set $g (i32.const 1))
  )
)
```

If all reads of `$g` are of this kind, then `$g` is not really being observed for useful outside behavior. It is just self-guarding its own write.

But Binaryen is much stricter than “condition reads same global and body writes same global.”

### The body must have exactly one written global and no other effects

`readsGlobalOnlyToWriteIt(...)` first uses `EffectAnalyzer` on the body code and requires:

- exactly one written global
- no remaining other effects after clearing that one written global from the effect set

So a body with memory writes, calls, throws, other global writes, or other noticeable behavior is rejected.

### It must see an actual `GlobalSet`, not just a call whose computed effects write a global

This is a subtle but important source rule.

Even if global-effects analysis says “this call writes `$g`,” the pass still refuses to count that as the required write. It explicitly scans for an actual `GlobalSet` AST node targeting that global.

The shipped `simplify-globals_func-effects.wast` test locks this in.

That preserves a whole-program counting invariant: Binaryen only trusts this elimination when it can count the concrete `global.get` and `global.set` sites itself.

### The condition must contain an actual `GlobalGet`, not just a call whose effects read the global

The same conservatism applies to reads.

Binaryen requires both:

- the effect summary to show a mutable-global read of that exact global
- and an actual `GlobalGet` node for that global somewhere in the condition AST

So effect summaries help with invalidation and safety, but they do not substitute for direct syntax matching in the `read-only-to-write` family.

### The global’s value must not flow into side-effectful behavior

Even when the condition has side effects somewhere, that alone is not an automatic rejection.

Binaryen does a second-stage flow check using `FlowScanner`:

- find the relevant `global.get`
- walk upward through its parents in the current expression stack
- reject if the global’s value reaches a parent where it can determine side-effectful behavior in a dangerous way

The shipped tests show the key distinction:

- **negative**: the global’s value chooses whether `foo()` is called
- **positive**: some other side effect exists in the condition, but the global’s value only flows safely out to the final condition result

That is much more precise than “any side effect in the condition blocks the optimization.”

### Nested appearances of the same pattern are explicitly allowed

The flow logic treats a nested appearance of the same `read-only-to-write` pattern as safe.

This explains why the big `simplify-globals-read_only_to_write.wast` test has multi-layer nested positive examples.

### There is also a whole-function `clinit`-style pattern

`visitFunction(...)` looks for a separate special case:

```wat
(block
  (if (global.get $once)
    (then (return))
  )
  (global.set $once (i32.const 1))
)
```

The function body must be exactly:

- a `Block`
- with exactly two children
- first child is an `if` with no `else`, whose `then` is a `return`
- second child is the code checked by `readsGlobalOnlyToWriteIt(...)`

The tests also lock the negatives:

- extra trailing `nop`
- `if` with `else`
- non-`return` true arm
- effectful condition

So this family is intentionally narrow.

## 6. `foldSingleUses()` is only about global-initializer users

Another easy misunderstanding is thinking “single use” means any single `global.get` in the whole module.

It does not.

The source only walks global initializers, not function code.

A fold is allowed when:

- `written == 0`
- `read == 1`
- the global is not exported
- the global has an initializer to copy

Then Binaryen copies the initializer expression into that single global-initializer use.

The key reason this is safe is execution count:

- another global initializer runs exactly once during instantiation
- function code might run zero, one, or many times

So the pass can duplicate a generative initializer into another global initializer once, but not into a function body that may execute repeatedly.

The shipped tests show the positive and negative families clearly:

- **positive**: one global used once by another global, even nested inside another initializer
- **negative**: second use anywhere
- **negative**: only use is in function code
- **negative**: imported global has no initializer to copy
- **negative**: exported global stays observable and must not be folded away casually

This is also why GC-allocating initializer examples matter: generativity is acceptable only because module instantiation executes that copied code once.

## 7. `removeUnneededWrites()` is a second real sub-algorithm

After folding single uses, the pass tries to delete `global.set`s whose written value will never matter.

A non-imported, non-exported global with writes qualifies if **any** of these hold:

- it is never read
- it is never written a value that differs from the initializer
- all reads are `read-only-to-write`

The consequences are:

- all sets to that global are replaced with `drop(value)`
- the global is marked immutable
- the write count is reset in the analysis map

This single phase covers three beginner-friendly stories:

### Story A: never-read globals

If nothing ever reads the global, the writes are dead bookkeeping. Keep the value expression for effects via `drop`, but remove the actual state mutation.

### Story B: writes always re-store the initial value

A mutable global that is only ever written its initializer is effectively constant. The writes are preserved only as side-effect-carrying operand evaluation via `drop(value)`.

### Story C: self-guarded initialization globals

If every read is only to decide whether to write the same global, the global state can collapse away and the write operands remain as drops.

## 8. Why this phase can request another whole iteration

`removeUnneededWrites()` returns `more = true` only for the `onlyReadOnlyToWrite` family.

The source comment gives the reason: nested self-guard patterns may become visible only after the inner one is removed.

Example intuition:

```wat
(if (global.get $a)
  (then
    (global.set $a (i32.const 1))
    (if (global.get $b)
      (then
        (global.set $b (i32.const 1))
      )
    )
  )
)
```

The inner `$b` cleanup can remove effects from the outer body, making the outer `$a` case newly eligible on the next full iteration.

So the pass is intentionally a tiny global fixpoint, but only for a specific nested-pattern reason.

## 9. `preferEarlierImports()` is useful but its name is a little misleading

Despite the helper name, this phase is not about imports only.

What it actually does is:

- find immutable, non-imported globals whose initializer is `global.get $parent`
- require the parent global to be immutable too
- chase transitive chains so each child maps to the earliest available immutable ancestor
- rewrite `global.get`s in functions and module code to use that earliest ancestor when types still match exactly

So a better mental model is:

- “prefer the earliest immutable ancestor in a copy chain”

not:

- “prefer imports specifically”

The shipped `simplify-globals-prefer_earlier.wast` test demonstrates the chain case.

### Important bailout: exact type match only

`GlobalUseModifier` only rewrites a `global.get` if the original ancestor’s type is exactly equal to the current use type.

The source contains a TODO noting that more-refined replacements could be allowed with refinalization.

That TODO matters because the GC test shows a preserved case where a parent has a more refined reference type than a child use expects. Binaryen leaves it alone today rather than silently changing types under the user.

## 10. Startup-time propagation into globals is different from runtime propagation into code

This is maybe the single most important beginner concept in the whole file.

### `propagateConstantsToGlobals()` is about module instantiation order

This phase walks globals in order and records constant global values as it goes.

It can replace `global.get`s inside later initializers and segment offsets because:

- global initialization happens before runtime code executes
- runtime writes have not happened yet
- so even a mutable global’s current startup value is known while later globals are being initialized

This phase therefore applies to:

- later global initializers
- element-segment offsets
- data-segment offsets
- nested occurrences inside those init expressions

It also gracefully ignores passive segments whose offset is `null`.

The shipped tests `simplify-globals-nested.wast`, `simplify-globals-offsets.wast`, and `propagate-globals-globally.wast` cover this family.

### `propagateConstantsToCode()` is stricter

Runtime code runs after arbitrary writes and control flow, so the code phase is much stricter.

It only starts with globals that are:

- immutable
- non-imported
- initialized with a constant expression

Those may be replaced anywhere as true constant globals.

In addition, the phase tracks **current** constant global values along a cheap linear execution trace when it sees constant `global.set`s.

So the pass can also replace a `global.get` with a constant when a dominating earlier `global.set` in the same linear window established the value.

This is why the pass can optimize some mutable-global reads in code even though the global is not globally constant.

## 11. `ConstantGlobalApplier` uses a cheap linear-execution model, not a full CFG

The runtime code propagator inherits from `LinearExecutionWalker` and sets:

- `connectAdjacentBlocks = true`

That means it can connect some immediately dominated adjacent blocks cheaply without building a full CFG or dominator tree.

The shipped `simplify-globals-dominance.wast` test shows the exact intended flavor:

- **positive**: a `global.get` in a dominated adjacent block can see a preceding constant `global.set`
- **negative**: after a call, Binaryen forgets the current constant value
- **negative / TODO**: not every dominated else-path opportunity is currently handled

This is a deliberately cheap analysis. The file does **not** try to solve general whole-function dominance.

## 12. What invalidates the current-value map in code

`ConstantGlobalApplier` keeps a `currConstantGlobals` map for the current trace.

It updates or invalidates that map as follows:

- seeing `global.set $g <constant>`
  - records `$g = constant`
- seeing `global.set $g <nonconstant>`
  - erases `$g`
- seeing a call according to `ShallowEffectAnalyzer`
  - clears **everything**
- seeing any shallow effect that writes specific globals
  - erases only those globals
- hitting nonlinear control via `noteNonLinear()`
  - clears **everything**

So calls and nonlinear control are the major beginner-visible barriers, while plain local work or unrelated shallow effects are not.

The `simplify-globals_func-effects.wast` test is especially useful here:

- it shows that computed function effects **do** participate in invalidation
- but those same computed effects are **not** enough to count as actual AST `global.get` / `global.set` nodes for the `read-only-to-write` matcher

That distinction is easy to miss and worth preserving.

## 13. `ReFinalize` is required when replacement changes expression types

`ConstantGlobalApplier::replaceCurrent(...)` checks whether the replacement expression type differs from the old expression type.

If so, it sets `refinalize = true`, and `visitFunction()` later runs:

- `ReFinalize().walkFunctionInModule(...)`

The GC test shows why this matters:

- replacing a `global.get` of a mutable `funcref` global with `ref.func` can make a later `ref.cast` become more precise
- without refinalization, the new AST may fail validation

So the pass is not just mutating leaves. It knows those mutations can change surrounding inferred types.

## 14. The optimizing variant reruns default function optimizations directly

This is the key scheduler fact the repo had previously summarized at a distance and that I rederived directly here.

There are two places where the optimizing variant can trigger nested function cleanup:

- `ConstantGlobalApplier::visitFunction()` after successful replacements
- `GlobalSetRemover::visitFunction()` after removing sets

In both places the code does the same basic thing:

- build `PassRunner runner(getPassRunner())`
- `runner.addDefaultFunctionOptimizationPasses()`
- `runner.runOnFunction(curr)`

Important implications:

- the nested runner is genuinely nested because `PassRunner(const PassRunner* runner)` sets `isNested = true` in `src/pass.h`
- the rerun is **per changed function**, not one filtered batch over a whole touched-function set
- the rerun is the ordinary default function optimization pipeline only
- there is **no** extra prepended `precompute-propagate`

That last point is the main scheduler difference from `dae-optimizing` and `inlining-optimizing`.

## 15. `propagate-globals-globally` is a useful source clue

The file also defines:

- `struct PropagateGlobalsGlobally : public SimplifyGlobals`

whose `run()` method only calls:

- `propagateConstantsToGlobals()`

The corresponding lit test explicitly contrasts this with full `simplify-globals`:

- `propagate-globals-globally` updates later globals and offsets
- `simplify-globals` also propagates constants into function code where allowed

That is a strong source-derived hint that Binaryen itself thinks of “startup global propagation” as a separable sub-algorithm within the wider pass.

## Important helper dependencies

## `EffectAnalyzer` and `ShallowEffectAnalyzer`

These power:

- the `read-only-to-write` safety checks
- current-value invalidation in code
- distinguishing body-only global writes from bodies that have other effects

## `FindAll` and `FindAllPointers`

These let the pass insist on actual AST `GlobalGet` / `GlobalSet` nodes and rewrite nested gets inside init expressions and segment offsets.

## `LinearExecutionWalker`

This provides the cheap runtime trace model for current-value propagation in code, including the `connectAdjacentBlocks` option.

## `Properties`

This provides:

- `isConstantExpression(...)`
- `getLiterals(...)`

which the pass uses both for initializer/write equality testing and for deciding what values can propagate as compile-time constants.

## `ExpressionManipulator::copy(...)`

Used when folding single-use global initializer code into another global initializer or replacing a constant global with a copied initializer expression.

## `Builder`

Used to construct constant expressions and to turn removed `global.set`s into `drop(value)` nodes.

## `ReFinalize`

Required when replacing a `global.get` changes the surrounding inferred type structure.

## `PassRunner`

Used directly for the optimizing variant’s nested rerun behavior. The relevant direct source is `src/pass.h`, not `opt-utils.h`.

## What the shipped tests teach

These lit tests are all worth keeping in the long-term dossier because each covers a distinct family:

- `simplify-globals-dominance.wast`
  - dominated constant `global.set` -> `global.get` propagation in code, plus call invalidation and current TODO limits
- `simplify-globals-gc.wast`
  - GC/reference-type refinalization after replacement, type-mismatch copy-chain bailout, export-sensitive generativity
- `simplify-globals-nested.wast`
  - nested constant propagation inside later global initializers
- `simplify-globals-non-init.wast`
  - writes of the initializer value becoming drops, and the limits when init/write are not compile-time comparable
- `simplify-globals-offsets.wast`
  - propagation into data/elem segment offsets and passive-segment null-offset safety
- `simplify-globals-prefer_earlier.wast`
  - immutable copy-chain canonicalization to the earliest ancestor
- `simplify-globals-read_only_to_write.wast`
  - the huge positive/negative shape suite for self-guarded writes, nested patterns, side-effectful value flow, and the `if return; set` whole-function family
- `simplify-globals-single_use.wast`
  - single-use fold positives and the runtime-count / import / export / multi-use negatives
- `simplify-globals_func-effects.wast`
  - computed-effects invalidation versus actual-node matching for `read-only-to-write`
- `propagate-globals-globally.wast`
  - the cleanest official illustration of the split between startup-only propagation and full pass behavior

## Key positive, negative, and bailout shapes

## Positive families

- immutable or practically immutable constant global used in function code
  - replace `global.get` with copied constant expression
- mutable global set to a constant earlier in the same linear trace
  - replace later same-trace `global.get` with that constant
- later global initializer or segment offset reads an earlier constant global
  - replace nested `global.get` during module-init propagation
- global initializer used exactly once by another global initializer
  - copy the initializer into that one use
- global copy chain
  - later `global.get $child` rewrites to earliest immutable ancestor with same exact type
- non-exported global with writes but no meaningful reads
  - replace `global.set` with `drop(value)` and mark global immutable
- whole-program `read-only-to-write` family
  - self-guarded writes collapse away, operand values remain as drops
- `if (already-set) return; set-it` two-item function body
  - special clinit-style family optimized the same way

## Negative / bailout families

- imported or exported globals
  - too observable for these destructive rewrites
- a second read outside the recognized self-guard family
  - breaks `read == readOnlyToWrite`
- `if` with `else` in the self-guard matcher
  - rejected
- body has effects besides the relevant `global.set`
  - rejected for `read-only-to-write`
- global value flows into deciding a side effect
  - rejected even if the body writes the same global
- call in runtime code after a known constant set
  - current-value map is cleared
- nonlinear control in runtime propagation
  - current-value map is cleared
- single-use read only in function code
  - not folded, because runtime execution count may exceed one
- exported single-use global with generative initializer
  - preserved as an observable boundary
- immutable-copy chain where ancestor type differs from use type
  - preserved today; source TODO suggests a more aggressive future with refinalization

## Pass interactions

`pass.cpp` placement makes the intended interaction story fairly clear:

- `duplicate-import-elimination`
  - can reduce late module noise before simplify-globals runs
- `simplify-globals-optimizing`
  - simplifies global initializers, global writes, and function code that reads globals
- `remove-unused-module-elements`
  - then removes globals or other module items that simplify-globals made dead
- `string-gathering`
  - then sees cleaner remaining global initializers when strings are enabled
- `reorder-globals`
  - then sorts the remaining globals after simplify-globals and RUME have reduced clutter
- `directize`
  - runs after the late global cleanup cluster has stabilized the module a bit more

The optimizing rerun also means this pass can expose extra local / instruction / control-flow cleanup opportunities inside touched functions **before** the later top-level module cleanup runs.

But again, that rerun is only the default function optimization list, not the stronger “precompute-propagate plus default function pipeline” used by the after-inlining helper.

## Easy things to misunderstand

## 1. “It only optimizes immutable globals.”

False.

The pass can:

- discover practical immutability
- remove writes that never matter
- propagate mutable global values during startup global initialization
- propagate mutable global values along a runtime linear trace after a constant `global.set`

## 2. “Single-use means anywhere in the module.”

False.

The single-use fold only applies when the single use is in another global initializer. Function uses are intentionally excluded.

## 3. “Any effect summary proving a get/set is enough for `read-only-to-write`.”

False.

Binaryen requires actual AST `GlobalGet` / `GlobalSet` nodes for that matcher, even when global-effects analysis is available.

## 4. “The optimizing variant uses the same nested helper as DAE and inlining.”

False.

This pass uses a direct nested `PassRunner` plus `addDefaultFunctionOptimizationPasses()` and does not prepend `precompute-propagate`.

## 5. “The helper named `preferEarlierImports` is really about imports.”

Only partly.

In practice it canonicalizes immutable copy chains to the earliest compatible ancestor, whether or not that earliest ancestor is imported.

## 6. “Startup-time global propagation and runtime code propagation are the same thing.”

False.

They rely on different safety arguments:

- startup propagation relies on module-instantiation order
- runtime propagation relies on a cheap linear current-value trace with aggressive invalidation

## Future Starshine port checklist

- Model this as a boundary/module pass, not a HOT local peephole.
- Preserve the full phase split:
  - analyze
  - single-use fold
  - remove unneeded writes
  - prefer earlier immutable ancestors
  - startup propagation into globals/offsets
  - runtime propagation into code
- Preserve the narrow actual-node requirement for `read-only-to-write`; do not trust effect summaries alone there.
- Preserve the difference between startup propagation and runtime propagation.
- Preserve the cheap linear-trace invalidation rules around calls and nonlinear control.
- Preserve the whole-function `if return; set` family exactly as a separate narrow shape.
- Preserve the exact-type gate on copy-chain canonicalization unless a future port intentionally adds a refinalizing extension.
- Preserve refinalization after type-changing replacements.
- Preserve that removed `global.set`s become `drop(value)` rather than deleting value computation.
- Preserve the optimizing variant’s nested default-function rerun, while also preserving that it does **not** prepend `precompute-propagate`.
- Preserve the fact that later module cleanup (`remove-unused-module-elements`) is expected to finish removing globals that become dead here.

## Uncertainty and open questions

- `simplify-globals-dominance.wast` contains an explicit TODO showing that the current cheap adjacent-block linear model does not cover every dominated else-path opportunity. I am treating that as an upstream `version_129` limitation, not as something the pass “logically meant” to do already.
- `GlobalUseModifier` contains an explicit TODO about allowing a more refined ancestor replacement with refinalization. The current dossier should therefore treat exact-type matching as the real current contract, not merely a conservative summary.
- I did not inspect current Binaryen trunk beyond using the `version_129` release page as the main version anchor. This dossier is therefore intentionally a `version_129` contract, not a claim about newer trunk behavior.
- The saved local `-O4z` debug log proves `3` nested rerun batches under `simplify-globals-optimizing`, but at the current saved debug level it does not print the inner pass names there. The direct source proof for the inner pipeline shape is therefore stronger than the log for exact nested roster details in this pass’s case.
