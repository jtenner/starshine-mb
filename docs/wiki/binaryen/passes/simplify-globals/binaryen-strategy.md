---
kind: concept
status: supported
last_reviewed: 2026-04-21
sources:
  - ../../../raw/research/0160-2026-04-21-simplify-globals-binaryen-research.md
  - ../../../raw/research/0222-2026-04-21-simplify-globals-source-confirmation-followup.md
related:
  - ./index.md
  - ./implementation-structure-and-tests.md
  - ./plain-vs-optimizing-and-safety.md
  - ./wat-shapes.md
  - ../simplify-globals-optimizing/index.md
---

# Binaryen `simplify-globals` Strategy

## Upstream source rule

This page teaches the algorithmic behavior.
For the compact owner-file and shipped-test map, read [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md) alongside it.

- Use Binaryen `version_129` as the current source oracle for this pass.
- The core implementation is `src/passes/SimplifyGlobals.cpp`.
- Public registration and the plain-vs-optimizing split come from `src/passes/pass.cpp`.
- The optimizing variant's nested-runner behavior also depends on `src/pass.h`.
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

## The pass in one sentence

Binaryen `simplify-globals` is a late whole-module global cleanup and propagation pass that discovers practical immutability, removes useless writes, folds one-time initializer chains, and substitutes startup- or trace-known global values, but **does not** do the extra nested default-function cleanup rerun that the optimizing sibling performs.

## The pass in one table

| Phase | What Binaryen does | Why it exists |
| --- | --- | --- |
| Analyze | Count import/export/read/write/non-init-written/read-only-to-write facts | Every later rewrite depends on whole-module global traffic |
| Fold single uses | Copy one initializer into one later global initializer | Removes one-time startup indirections |
| Remove unneeded writes | Replace useless `global.set`s with `drop(value)` and sometimes iterate | Makes globals effectively immutable and exposes more cleanup |
| Prefer earlier immutable ancestors | Canonicalize immutable copy chains to the earliest compatible source | Reduces global-copy noise |
| Propagate to globals | Replace known global values in later initializers and segment offsets | Startup order makes these substitutions safe |
| Propagate to code | Replace immutable or current-trace-known values in function code | Exposes simpler code without a full CFG pass |
| ReFinalize when needed | Repair surrounding function typing after more refined substitutions | Keeps GC/reference rewrites valid |

## Biggest naming fact

`pass.cpp` exposes both:

- `simplify-globals`
- `simplify-globals-optimizing`

and both come from the same `SimplifyGlobals` implementation with an `optimize` flag.

So the plain pass is **not** a different algorithm file. It is the same core engine with the optimizing rerun disabled.

## Phase 1: `analyze()` builds the real fact table

Before rewriting anything, Binaryen collects a `GlobalInfo` summary per global.

Important facts include:

- `imported`
- `exported`
- `written`
- `read`
- `nonInitWritten`
- `readOnlyToWrite`

The pass seeds import/export facts from module structure and then scans:

- function bodies
- module-level code via `runOnModuleCode`

So the pass is reasoning across both runtime code and module-instantiation expressions.

## Practical immutability is discovered, not only read from syntax

After scanning, Binaryen can turn some mutable globals into immutable ones in place when they are:

- not imported
- not exported
- never meaningfully written

That means a future port cannot treat the declared mutability bit as the final truth for the rest of the algorithm.

## `nonInitWritten` means “this write changed the state in a meaningful way”

The scanner compares written values against the initializer using `Properties::isConstantExpression(...)` and literal extraction helpers.

If a `global.set` writes the exact initializer value again, Binaryen treats that as “still init-like,” not as evidence that the runtime state truly diverged.

That distinction is why `simplify-globals-non-init.wast` can legitimately collapse those writes to `drop(value)`.

## Phase 2: `foldSingleUses()` only folds startup expressions into startup expressions

This is one of the easiest places to overgeneralize the pass.

A “single use” here really means something like:

- `written == 0`
- `read == 1`
- not exported
- initializer exists and is copyable

But the source then looks only for uses in later **global initializers**, not in function bodies.

So Binaryen may copy a one-time initializer like `struct.new_default` into another global initializer because startup still executes once.
It deliberately does **not** copy that same expression into function code.

The shipped `simplify-globals-single_use.wast` file is the cleanest proof surface for this rule.

## Phase 3: `removeUnneededWrites()` is more than dead-store deletion

After single-use folding, the pass tries to prove that some globals no longer need real writes.

A non-imported, non-exported global can become a “no sets needed” candidate when, for example:

- it is never read,
- it is never written a non-init value,
- or all its reads are only `read-only-to-write` self-guards.

For those globals Binaryen:

- rewrites each `global.set` to `drop(value)`
- marks the global immutable
- resets write-related facts in the analysis summary

So the pass preserves operand evaluation while erasing the stateful meaning of the write.

## Why whole-pass iteration exists

If a global qualified only because its reads were `read-only-to-write`, Binaryen may ask for another whole-module iteration.

The reason is narrow but real:

- removing one inner self-guard can erase the extra effects that previously blocked an outer self-guard
- so the pass reruns to discover newly exposed outer cases

This is a specific fixed-point story, not a vague “rerun because maybe more optimization exists.”

## Phase 4: `read-only-to-write` is a genuine safety matcher

The positive beginner story is simple:

```wat
(if
  (global.get $g)
  (then
    (global.set $g (i32.const 1))
  )
)
```

But the real source contract is stricter.

### The body must effectively be “just write this global”

Binaryen uses `EffectAnalyzer` on the body and requires:

- exactly one written global effect
- no remaining effects after removing that one write from the effect set

So extra calls, memory effects, throws, or other global writes block the optimization.

### It insists on actual AST nodes

Even if Binaryen can infer via summaries that a call reads or writes a global, the matcher still wants:

- an actual `GlobalGet` node in the condition
- an actual `GlobalSet` node in the body

The `simplify-globals_func-effects.wast` test exists largely to pin down that distinction.

### It also checks how the global’s value flows upward

If the condition contains side effects, Binaryen does not automatically reject it.
Instead, it walks from the matched `global.get` up through parent expressions and asks whether that value can determine some side-effectful behavior in a dangerous way.

So the source distinguishes between:

- side effects merely existing nearby
- the global’s value actually controlling those effects

That is why the large `simplify-globals-read_only_to_write.wast` file matters so much.

### There is also one narrow whole-function pattern

`visitFunction(...)` recognizes a special body shape like:

```wat
(block
  (if (global.get $once)
    (then (return))
  )
  (global.set $once (i32.const 1))
)
```

The match is intentionally narrow:

- body is a two-item `block`
- first child is a no-else `if`
- true arm is `return`
- second child is the write code

Extra children or a different control shape bail out.

## Phase 5: immutable copy chains are canonicalized to the earliest compatible ancestor

The implementation's helper name mentions imports, but the actual logic is broader.

If an immutable, non-imported global is initialized from another immutable global, Binaryen can chase that chain transitively and rewrite uses to the earliest compatible ancestor.

The important constraints are:

- the copied-through globals must be immutable
- the final replacement type must match the use type exactly in `version_129`

The GC test file locks the negative case where a less-refined ancestor type blocks the rewrite.

## Phase 6: startup-time constant propagation is its own algorithm

`propagateConstantsToGlobals()` is not just the runtime code propagation run on different nodes.

It walks globals in definition order, records currently known constant values, and substitutes them into:

- later global initializers
- element-segment offsets
- data-segment offsets

This can be safe even for some mutable globals because no runtime code has executed yet.
So a future port must preserve the distinction between:

- “known at startup right now”
- “known for all later runtime execution”

## Phase 7: runtime code propagation uses a cheap linear-trace model

`propagateConstantsToCode()` starts from two sources of truth:

- truly constant globals
- current values established by constant `global.set`s along the current trace

It uses `LinearExecutionWalker` with adjacent-block connection enabled.
That means Binaryen can capture some cheap domination-like positives across immediately adjacent blocks.

But this is **not** a full CFG or dominator-tree pass.

The runtime current-value map is invalidated when the walker sees:

- a call
- nonlinear control
- shallow writes to tracked globals

So the pass is intentionally conservative once execution stops looking simple.

## `connectAdjacentBlocks = true` is a useful clue

The reviewed `simplify-globals-dominance.wast` file shows what Binaryen is aiming for:

- cheap adjacent dominated positives are allowed
- call barriers still block propagation
- wider dominance cases remain intentionally unoptimized

That is a source-backed sign that future Starshine work should preserve the narrow cheap model rather than broadening it silently.

## Phase 8: type-changing replacements trigger `ReFinalize()`

When a replacement expression type differs from the original expression type, Binaryen records that and later runs `ReFinalize()` on the function.

This matters especially for GC/reference-typed substitutions, where replacing a `global.get` with a more refined value can change the surrounding expression typing.

So the pass owns both:

- expression replacement
- targeted type repair afterward

## Scheduler placement

The plain pass lives in the late global-optimization family.
Its exact preset use depends on Binaryen optimization settings, and the repo’s current orientation docs already record the important split:

- the repo's current no-DWARF `-O` / `-Os` path uses `simplify-globals-optimizing`
- lower optimization settings can use plain `simplify-globals`

Either way, this pass belongs in the same late-global neighborhood as:

- `duplicate-import-elimination`
- `remove-unused-module-elements`
- `string-gathering`
- `reorder-globals`
- `directize`

That placement matters because it can change which globals survive and what later global initializers look like.

## Important helper dependencies

## `EffectAnalyzer`

Used for:

- `read-only-to-write` body legality
- invalidation after calls or writes in code propagation

## `FindAll` / `FindAllPointers`

Used to:

- insist on actual AST `GlobalGet` / `GlobalSet` ownership for some patterns
- rewrite nested initializer and segment-offset expressions

## `LinearExecutionWalker`

Provides the cheap runtime current-value propagation model, including adjacent-block connection.

## `Properties`

Defines what counts as a constant expression and how literals are compared against initializers.

## `ExpressionManipulator::copy(...)`

Used when copying initializer code or constant expressions into new sites.

## `Builder`

Used to synthesize replacement constants and `drop(value)` wrappers.

## `ReFinalize`

Required after type-changing substitutions.

## Shipped tests worth rereading

- `simplify-globals-dominance.wast`
  - cheap dominated runtime propagation and call barriers
- `simplify-globals-gc.wast`
  - refinalization and type-compatible ancestor limits
- `simplify-globals-nested.wast`
  - propagation into nested later initializers
- `simplify-globals-non-init.wast`
  - same-as-init writes becoming drops
- `simplify-globals-offsets.wast`
  - segment-offset propagation
- `simplify-globals-prefer_earlier.wast`
  - immutable copy-chain canonicalization
- `simplify-globals-read_only_to_write.wast`
  - self-guard positives and the main bailout families
- `simplify-globals-single_use.wast`
  - one-time startup folding only
- `simplify-globals_func-effects.wast`
  - actual-node versus inferred-effect distinction
- `propagate-globals-globally.wast`
  - startup-only propagation as a separately testable sub-algorithm

## Future Starshine port checklist

- Keep this a module/boundary pass.
- Preserve startup propagation and runtime propagation as distinct sub-algorithms.
- Preserve the actual-node requirement in `read-only-to-write` matching.
- Preserve `drop(value)` when removing writes.
- Preserve exact-type gating in immutable-copy-chain rewrites unless deliberately extended.
- Preserve `ReFinalize()` after type-changing replacements.
- Keep the plain-vs-optimizing split explicit in the scheduler surface.
- Do not silently import the optimizing variant's nested rerun into the plain pass contract.
