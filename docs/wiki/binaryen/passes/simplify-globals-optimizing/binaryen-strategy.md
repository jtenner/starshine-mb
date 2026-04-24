---
kind: concept
status: supported
last_reviewed: 2026-04-24
sources:
  - ../../../raw/binaryen/2026-04-24-simplify-globals-optimizing-primary-sources.md
  - ../../../raw/research/0286-2026-04-24-simplify-globals-optimizing-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0122-2026-04-20-simplify-globals-optimizing-binaryen-research.md
related:
  - ./index.md
  - ./implementation-structure-and-tests.md
  - ./linear-traces-read-only-to-write-and-reruns.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../simplify-globals/index.md
  - ../propagate-globals-globally/index.md
  - ../remove-unused-module-elements/index.md
  - ../../no-dwarf-default-optimize-path.md
---

# Binaryen `simplify-globals-optimizing` Strategy

## Upstream source rule

- Use Binaryen `version_129` as the current source oracle for this pass.
- The immutable source manifest for this dossier is [`../../../raw/binaryen/2026-04-24-simplify-globals-optimizing-primary-sources.md`](../../../raw/binaryen/2026-04-24-simplify-globals-optimizing-primary-sources.md), which records the official release page, reviewed `version_129` and current-`main` source URLs, helper headers, and lit-test roster.
- The core implementation is `src/passes/SimplifyGlobals.cpp`.
- Scheduler placement comes from `src/passes/pass.cpp`.
- The nested-runner behavior also depends on `src/pass.h`.
- The most important helper contracts come from:
  - `src/ir/effects.h`
  - `src/ir/find_all.h`
  - `src/ir/linear-execution.h`
  - `src/ir/properties.h`
  - `src/ir/utils.h`
- The shipped behavior examples come from the `simplify-globals-*` lit tests plus `propagate-globals-globally.wast`.

Primary source URLs:

- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/SimplifyGlobals.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/pass.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/effects.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/find_all.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/linear-execution.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/properties.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/utils.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/simplify-globals-dominance.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/simplify-globals-gc.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/simplify-globals-nested.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/simplify-globals-non-init.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/simplify-globals-offsets.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/simplify-globals-prefer_earlier.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/simplify-globals-read_only_to_write.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/simplify-globals-single_use.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/simplify-globals_func-effects.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/propagate-globals-globally.wast>

## High-level intent

Binaryen uses `simplify-globals-optimizing` to make globals easier to reason about and then immediately cash in on the function-level cleanup opportunities that creates.

That sentence is true but incomplete.

The actual implementation is a late **module/global planner** with six important rewrite families plus one nested scheduler hook:

| Phase | What Binaryen does | Why it exists |
| --- | --- | --- |
| Analyze | Count imported/exported/read/written/non-init-written/read-only-to-write facts | Every later rewrite depends on whole-module global traffic |
| Fold single uses | Copy a single-use global initializer into one later global initializer | Removes trivial one-time global indirections |
| Remove unneeded writes | Turn useless `global.set`s into `drop(value)` and sometimes ask for another full iteration | Makes globals effectively immutable and can expose nested self-guard cases |
| Prefer earlier immutable ancestors | Canonicalize immutable copy chains to the earliest compatible ancestor | Reduces global-copy noise and exposes later cleanup |
| Propagate to globals | Replace known constant globals inside later global initializers and segment offsets | Module instantiation order makes this safe even for some mutable globals |
| Propagate to code | Replace immutable or trace-known global values inside functions | Exposes ordinary local / control / constant cleanup |
| Optimize-after-change | Rerun the default function optimization pipeline on changed functions only | The optimizing variant is designed to cash in on the new cleanup surface immediately |

That means the pass is not just:

- “constant globals”
- “immutable globals”
- “replace `global.get` with a literal”
- or “cleanup inside functions only”

## Pass family and scheduler placement

`pass.cpp` exposes two production pass names:

- `simplify-globals`
- `simplify-globals-optimizing`

and one testing-oriented helper surface:

- `propagate-globals-globally`

The default global optimization post-pass cluster uses the optimizing variant when:

- `optimizeLevel >= 2`, or
- `shrinkLevel >= 2`

Otherwise it uses plain `simplify-globals`.

In the canonical no-DWARF `-O` / `-Os` path documented in this repo, the pass appears:

- after `duplicate-import-elimination`
- before `remove-unused-module-elements`
- before `string-gathering`
- before `reorder-globals`
- before `directize`

A future Starshine port must preserve that placement because this pass can make globals dead, simplify remaining global initializers, and change which later module cleanup and layout passes can fire honestly.

## Same engine, different variant

The implementation file contains one main `SimplifyGlobals` pass parameterized by an `optimize` flag.

That split matters:

| Variant | Core global rewrites | Nested default function rerun |
| --- | --- | --- |
| `simplify-globals` | yes | no |
| `simplify-globals-optimizing` | yes | yes |

So the optimizing variant is not a cosmetic alias. It is the same global algorithm **plus** follow-up function cleanup.

## Phase 1: `analyze()` builds the real fact table

Before rewriting anything, Binaryen collects a `GlobalInfo` summary per global.

Important recorded facts include:

- `imported`
- `exported`
- `written`
- `read`
- `nonInitWritten`
- `readOnlyToWrite`

The pass seeds import/export facts from module structure and then runs `GlobalUseScanner` over:

- function bodies
- module-level code (`runOnModuleCode`)

That means the pass is reasoning across both runtime code and instantiation-time global/segment expressions.

## Practical immutability is discovered, not only read from syntax

After scanning, `analyze()` turns some mutable globals into immutable ones in-place when they are:

- not imported
- not exported
- never written

So “mutable” in the original module is not the last word. The pass can discover that a global behaves as immutable and tighten later reasoning accordingly.

## `nonInitWritten` is the dead-write discriminator

When the scanner visits `global.set`, it compares the written value against the initializer using `Properties::isConstantExpression(...)` and `Properties::getLiterals(...)`.

If both sides are compile-time constants and equal, the pass treats the write as “still the init value,” not as evidence of a meaningful state change.

That is why `simplify-globals-non-init.wast` can turn “write the initial value again” into `drop(value)` instead of keeping the actual mutation.

## Phase 2: `read-only-to-write` is a serious safety algorithm

One of the most important parts of the pass is deciding when a global is only read in order to decide whether to write that same global.

The simple positive story is:

```wat
(if
  (global.get $g)
  (then
    (global.set $g (i32.const 1))
  )
)
```

But the real source contract is much stricter.

### The body must have exactly one global write and no other effects

Binaryen uses `EffectAnalyzer` on the body code and requires:

- exactly one written global
- no remaining effects after removing that one written-global effect from the effect set

So calls, memory effects, throws, extra global writes, and other side effects all block the match.

### It insists on actual AST `GlobalSet` / `GlobalGet` nodes

Even when function-effects analysis knows that some call reads or writes a global, the matcher still scans for an actual `GlobalSet` in the body and an actual `GlobalGet` in the condition.

This is one of the clearest places where Binaryen distinguishes:

- effect summaries used for safety and invalidation
- actual syntax used for semantic pattern matching

The `simplify-globals_func-effects.wast` test exists largely to lock that subtle rule down.

### It also checks how the global’s value flows upward

If the condition contains other side effects, Binaryen does not reject immediately.

Instead, `FlowScanner` walks from the matched `GlobalGet` up through its parents and asks whether the global’s value can determine a side effect in a dangerous way.

So the source distinguishes between:

- the global’s value causing an effectful behavior choice
  - reject
- unrelated side effects that happen while the global’s value only flows safely to the final condition result
  - allow

This is why the giant `simplify-globals-read_only_to_write.wast` test contains both “side effects in the condition” negatives and a few “side effects exist, but the global value does not reach them dangerously” positives.

### The matcher also recognizes one narrow whole-function pattern

`visitFunction(...)` recognizes exactly this whole-body family:

```wat
(block
  (if (global.get $once)
    (then (return))
  )
  (global.set $once (i32.const 1))
)
```

The body has to be exactly:

- a `Block`
- with exactly two children
- first child is `if` with no `else`
- true arm is `return`
- second child is the write code

Extra children, `else`, or a non-`return` true arm all bail out.

## Phase 3: `foldSingleUses()` only folds global initializers into global initializers

This is another easy place to misread the pass.

A “single use” here means:

- `written == 0`
- `read == 1`
- not exported
- initializer exists

and crucially the source only walks **global initializers**, not function code.

So the pass may copy a generative initializer like `struct.new_default` into another global initializer because module instantiation runs that once.

It does **not** fold the same code into function bodies, because function code could execute many times and change semantics.

The shipped `simplify-globals-single_use.wast` test is the cleanest illustration:

- one global-to-global use is positive
- a second use blocks it
- function use blocks it
- import blocks it because there is no initializer to copy
- export blocks it because the boundary is still observable

## Phase 4: `removeUnneededWrites()` makes globals effectively immutable

After single-use folding, the pass asks whether writes to a global matter at all.

A non-imported, non-exported global with writes becomes a “no sets needed” candidate if:

- it is never read, or
- it is never written a non-init value, or
- all reads are `read-only-to-write`

For those globals Binaryen:

- replaces each `global.set` with `drop(value)`
- marks the global immutable
- resets the write count in the analysis summary

That is the phase that turns several families into later constant/global cleanup opportunities.

## Why whole-pass iteration exists at all

If the global qualified only because it was `read-only-to-write`, Binaryen returns `more = true` from `iteration()`.

The source comment explains the reason: removing an inner self-guard family can erase the extra effects that blocked an outer one, so a fresh whole-module scan is needed to discover the newly exposed outer case.

That is the fixpoint reason here, and it is narrower than “keep rerunning because maybe anything changed.”

## Phase 5: `preferEarlierImports()` really means “prefer the earliest immutable ancestor”

Despite the helper name, the actual logic is broader than imports.

The pass finds immutable, non-imported globals whose initializer is a `global.get` of another immutable global, then chases the chain transitively and rewrites uses to the earliest compatible ancestor.

The two important practical constraints are:

- child must be immutable and non-imported
- ancestor type must match the current use type exactly

That exact-type gate is source-important. `GlobalUseModifier` contains a TODO about allowing more refined replacements with refinalization, which means the current `version_129` contract is still “exact match only.”

The GC lit test locks the negative case where a less-refined type prevents the rewrite.

## Phase 6: startup-time constant propagation is a separate safety story

`propagateConstantsToGlobals()` is not using the same reasoning as runtime code propagation.

It walks globals in definition order and records compile-time constant global values as it goes.

Then it replaces matching `global.get`s inside:

- later global initializers
- element-segment offsets
- data-segment offsets

This is safe even for some mutable globals because no runtime code has executed yet.

The pass is operating in module-instantiation order, not in arbitrary dynamic code.

That is why `propagate-globals-globally.wast` exists as a separate helper-pass test: Binaryen itself treats this startup-only sub-algorithm as a distinct thing worth isolating.

## Phase 7: runtime code propagation uses a cheap linear-trace model

`propagateConstantsToCode()` is stricter than startup propagation.

It starts with globals that are:

- immutable
- non-imported
- constant-initialized

Those are true constant globals and can always be replaced in functions.

But the phase also tracks **current** constant values established by constant `global.set`s along a linear trace using `LinearExecutionWalker`.

So the pass can also optimize cases like:

```wat
(global.set $g (i32.const 10))
(drop (global.get $g))
```

without requiring `$g` to be globally immutable.

## `connectAdjacentBlocks = true` is a useful clue

The walker enables adjacent-block connection. That lets it cheaply connect some dominator-and-immediately-followed block cases without paying for a full CFG and dominator tree.

The `simplify-globals-dominance.wast` test shows the intended scope:

- dominated adjacent block positive
- call barrier negative
- else-path / wider dominance still limited enough to leave a TODO

So this is deliberately a small, cheap analysis window.

## Calls and nonlinear control are the main barriers

`ConstantGlobalApplier` invalidates its current-value map when:

- it sees a call
- it sees nonlinear control (`noteNonLinear`)
- it sees shallow writes to a tracked global

That means the pass is optimistic only while the current execution story still looks very simple.

A future Starshine port should preserve that cheap conservatism rather than trying to silently generalize it into a different dataflow algorithm.

## Type-changing replacements trigger refinalization

If the replacement expression type differs from the old expression type, `ConstantGlobalApplier` sets a flag and later runs `ReFinalize()` on the function.

The GC test shows why this matters: replacing a global read with a more refined `ref.func` can require the surrounding cast or expression typing to change.

So the pass is not just substituting leaf values. It knows those substitutions can alter surrounding type structure.

## Phase 8: the optimizing rerun is direct, nested, and smaller than after-inlining

When `optimize = true` and a function changed, the pass does:

- `PassRunner runner(getPassRunner())`
- `runner.addDefaultFunctionOptimizationPasses()`
- `runner.runOnFunction(curr)`

That happens in two places:

- after constant replacement in `ConstantGlobalApplier`
- after removed sets in `GlobalSetRemover`

Important consequences:

- the nested runner is truly nested because `PassRunner(const PassRunner* runner)` sets `isNested = true` in `src/pass.h`
- the rerun is per changed function, not one filtered batch over a function set
- the rerun is only the ordinary default function optimization pipeline
- there is **no** extra `precompute-propagate` prefix

That last point is the most important scheduler distinction from `dae-optimizing` and `inlining-optimizing`.

## Saved `-O4z` log evidence

The saved `o4z-wasm-opt-debug.log` shows three nested pass batches under the top-level `simplify-globals-optimizing` slot before the run proceeds to top-level `remove-unused-module-elements`.

That does not expose the inner pass names at the saved debug level, but it is consistent with the direct source story: three changed functions each triggered one nested default-function rerun.

## Important helper dependencies

## `EffectAnalyzer` / `ShallowEffectAnalyzer`

These power:

- `read-only-to-write` safety checks
- invalidation after calls or writes in code propagation

## `FindAll` / `FindAllPointers`

Used to:

- insist on actual AST `GlobalGet` / `GlobalSet` nodes
- rewrite nested init-expression and segment-offset global reads

## `LinearExecutionWalker`

Provides the cheap runtime current-value propagation model and the `connectAdjacentBlocks` knob.

## `Properties`

Defines what counts as a constant expression for this pass and how to compare literal equality to initializers.

## `ExpressionManipulator::copy(...)`

Used when folding single-use initializer code or copying constant global initializers into code.

## `Builder`

Used to synthesize constant expressions and `drop(value)` replacements.

## `ReFinalize`

Required whenever replacement changes types and surrounding AST typing must be repaired.

## `PassRunner`

Provides the optimizing variant’s nested rerun contract directly, without using `opt-utils.h`.

## Shipped test coverage worth remembering

- `simplify-globals-dominance.wast`
  - dominated-constant runtime propagation and call barriers
- `simplify-globals-gc.wast`
  - refinalization and type-compatible ancestor selection limits
- `simplify-globals-nested.wast`
  - propagation into nested later global initializers
- `simplify-globals-non-init.wast`
  - same-as-init writes becoming drops
- `simplify-globals-offsets.wast`
  - segment-offset propagation and passive-segment null handling
- `simplify-globals-prefer_earlier.wast`
  - immutable copy-chain canonicalization
- `simplify-globals-read_only_to_write.wast`
  - self-guard positives, nested positives, function-body `clinit` shape, and the major negative/bailout families
- `simplify-globals-single_use.wast`
  - one-time global-init folding only
- `simplify-globals_func-effects.wast`
  - actual-node versus computed-effect distinction
- `propagate-globals-globally.wast`
  - startup-only propagation versus full-pass runtime propagation

## Future Starshine port checklist

- Keep this a module/boundary pass.
- Preserve the multi-phase order and the narrow extra-iteration reason.
- Preserve startup-time propagation and runtime propagation as distinct sub-algorithms.
- Preserve the actual-node requirement for `read-only-to-write`.
- Preserve exact-type gating in the immutable-copy-chain rewrite unless deliberately extending the algorithm.
- Preserve refinalization after type-changing replacements.
- Preserve `drop(value)` replacement for removed writes.
- Preserve the optimizing variant’s nested default-function rerun and its lack of extra `precompute-propagate`.
- Preserve the intended follow-up relationship with `remove-unused-module-elements`.

## Sources

- [`../../../raw/binaryen/2026-04-24-simplify-globals-optimizing-primary-sources.md`](../../../raw/binaryen/2026-04-24-simplify-globals-optimizing-primary-sources.md)
- [`../../../raw/research/0286-2026-04-24-simplify-globals-optimizing-primary-sources-and-starshine-followup.md`](../../../raw/research/0286-2026-04-24-simplify-globals-optimizing-primary-sources-and-starshine-followup.md)
- [`../../../raw/research/0122-2026-04-20-simplify-globals-optimizing-binaryen-research.md`](../../../raw/research/0122-2026-04-20-simplify-globals-optimizing-binaryen-research.md)
