# Binaryen `simplify-globals` research

Date: 2026-04-21
Author: OpenAI Codex
Status: archived research feeding living wiki pages

## Scope

This note adds a first-class dossier for upstream Binaryen `simplify-globals`, the **plain** sibling of the already documented `simplify-globals-optimizing` pass.

The current campaign rules required picking exactly one Binaryen pass that still needed more wiki information. The main no-DWARF / saved-`-O4z` queue was already dossier-covered, and the first upstream-only expansion queue was already dossier-covered too. So this note explicitly widens the tracker again.

## Why this pass is an eligible tracker expansion

`simplify-globals` is a fair campaign target because all of the following are true:

1. it is already a named local boundary-only registry entry in `src/passes/optimize.mbt`
2. it is a real upstream Binaryen public pass name, not a speculative alias
3. it shares an implementation file with the already-covered `simplify-globals-optimizing` pass, so understanding the plain variant removes a real teaching gap rather than duplicating trivia
4. the plain-vs-optimizing split is scheduler-significant and easy to misunderstand
5. `agent-todo.md` currently has **no dedicated `simplify-globals` slice**, so the repo lacked a durable pass-specific explanation for the plain variant

## Main question

What does Binaryen `version_129` actually do for `simplify-globals`, and how is that different from `simplify-globals-optimizing`?

## Short answer

Binaryen `simplify-globals` is a late **whole-module global cleanup and propagation pass** that:

- scans global reads/writes/imports/exports across function code and module-level code
- discovers practical immutability
- folds one-time global initializers into later global initializers
- removes dead or same-as-init writes by turning them into `drop(value)`
- recognizes narrow `read-only-to-write` self-guard families
- prefers earlier immutable ancestors in copy chains
- propagates startup-known constants into later global initializers and segment offsets
- propagates globally constant or current-trace-known values into function bodies
- refinalizes changed functions when type-changing replacements require it

The **plain** pass stops there.

`simplify-globals-optimizing` is the same core engine plus a nested rerun of Binaryen’s default function optimization pipeline on each changed function.

That difference is the central reason this separate dossier is useful.

## Primary upstream sources reviewed

### Core implementation and scheduler

- Binaryen `version_129` `src/passes/SimplifyGlobals.cpp`
- Binaryen `version_129` `src/passes/pass.cpp`
- Binaryen `version_129` `src/pass.h`

### Helper dependencies referenced by the pass

- `src/ir/effects.h`
- `src/ir/find_all.h`
- `src/ir/linear-execution.h`
- `src/ir/properties.h`
- `src/ir/utils.h`

### Official test surfaces reviewed

- `test/lit/passes/simplify-globals-dominance.wast`
- `test/lit/passes/simplify-globals-gc.wast`
- `test/lit/passes/simplify-globals-nested.wast`
- `test/lit/passes/simplify-globals-non-init.wast`
- `test/lit/passes/simplify-globals-offsets.wast`
- `test/lit/passes/simplify-globals-prefer_earlier.wast`
- `test/lit/passes/simplify-globals-read_only_to_write.wast`
- `test/lit/passes/simplify-globals-single_use.wast`
- `test/lit/passes/simplify-globals_func-effects.wast`
- `test/lit/passes/propagate-globals-globally.wast`

## Relation to existing repo docs

I also reviewed the existing `simplify-globals-optimizing` dossier because it already captures official-source facts from the same upstream implementation file. That existing dossier was useful background, but it does **not** remove the need for a plain-pass home because it teaches the optimizing wrapper as the main subject.

The new dossier should therefore preserve two truths at once:

- the implementation is mostly shared
- the public pass contract is **not** identical because only the optimizing variant reruns the default function optimizer

## Key implementation findings

## 1. One implementation, two public pass names

`pass.cpp` exposes both:

- `simplify-globals`
- `simplify-globals-optimizing`

The implementation file uses one `SimplifyGlobals` class parameterized by an `optimize` flag.

So the real question is not “which file belongs to the plain variant?”
It is “what behavior disappears when `optimize = false`?”

Answer: the global rewrite engine stays, but the nested per-function default optimization rerun disappears.

## 2. This is a module/global pass, not a hot local peephole

The pass starts by building `GlobalInfo` facts per global, including whether the global is:

- imported
- exported
- read
- written
- written outside initialization semantics
- only read in order to decide whether to write it (`readOnlyToWrite`)

The scan covers both:

- function bodies
- module-level code such as later global initializers and segment offsets

That whole-module scope is the first reason beginner summaries like “constant-fold global.get” are misleading.

## 3. Practical immutability is discovered, not just read from the declaration

A mutable global can become effectively immutable for later reasoning when the pass proves it is:

- not imported
- not exported
- never meaningfully written

So the pass is partly a global-traffic analyzer that sharpens the semantic status of globals before later rewrites happen.

## 4. `foldSingleUses()` is narrower than it sounds

The official tests make this easy to teach incorrectly.

The pass does **not** clone a one-time initializer into arbitrary function code.
Instead, it only folds a global initializer into another **later global initializer** when the source global is:

- read exactly once
- written zero times
- not exported
- locally defined
- initialized by copyable code

Reason: global initializers run once at module startup, while function bodies may run many times. Copying a generative initializer such as `struct.new_default` into function code would not be semantics-preserving.

## 5. `read-only-to-write` is a real safety proof, not a name match

The pass has a famous family where a global is only consulted in order to decide whether to write it.

But the source insists on more than “the same global name appears in condition and body.”
The body must have:

- exactly one written-global effect
- no remaining effects after clearing that one global write from the effect set

And the pass wants real AST nodes:

- an actual `global.get` in the condition
- an actual `global.set` in the body

The reviewed `simplify-globals_func-effects.wast` test is especially important because it locks down the difference between:

- effect summaries used for safety reasoning
- concrete syntax required for pattern ownership

That distinction is easy to miss and worth preserving in any future Starshine port.

## 6. The pass distinguishes startup propagation from runtime propagation

This was the other big teaching gap.

### Startup propagation

When the pass rewrites:

- later global initializers
- data-segment offsets
- element-segment offsets

it is still operating in module-instantiation order.
So an earlier mutable global may still have a known constant value **at startup time**, even if runtime code can change it later.

### Runtime propagation

Inside function code, the pass uses a much cheaper and more conservative model:

- truly constant globals are always replaceable
- additionally, a `LinearExecutionWalker` tracks current constant values established by constant `global.set`s along a simple current trace
- calls, nonlinear control, and relevant writes clear that current-value map

So startup and runtime propagation are different algorithms with different safety stories.

## 7. `connectAdjacentBlocks = true` is a real part of the contract

The runtime propagation logic uses `LinearExecutionWalker` with adjacent-block connection enabled.

That means Binaryen deliberately captures some cheap domination-like shapes across immediately adjacent blocks without paying for a full dominator-tree proof.

The official dominance test shows the intended boundary:

- some dominated adjacent-block positives are optimized
- broader dominance cases still remain unoptimized
- calls remain barriers

A future port should preserve that **cheap narrow model**, not silently widen it into a different dataflow pass.

## 8. Removed writes become `drop(value)`, not silent deletion

When Binaryen proves a `global.set` does not matter, it still preserves operand evaluation by rewriting the write to `drop(value)`.

That happens for important families such as:

- writes to globals never read later
- writes that only repeat the initializer value
- read-only-to-write self-guard families after the global becomes effectively immutable

This is one of the most important beginner-facing shape rules because “dead global write” does **not** mean “erase the whole subtree.”

## 9. Immutable copy chains are canonicalized to the earliest compatible ancestor

Another source-backed subtlety: the implementation’s “prefer earlier imports” helper is really broader than imports.

It walks immutable copy chains like:

- global B initialized from global A
- global C initialized from global B

and prefers the earliest compatible ancestor when rewriting uses.

But compatibility is strict:

- the ancestor must still be immutable
- the replacement type must match the use type exactly in `version_129`

The GC tests lock the negative cases where a more refined ancestor type would require extra type repair that Binaryen does not attempt here.

## 10. Type-changing replacements can force refinalization

When a replacement expression ends up with a different type than the original `global.get`, the pass marks the function for `ReFinalize()`.

That matters especially for GC/reference-typed cases, where replacing a `global.get` with something like a more refined `ref.func` or exact nullary value can change surrounding inferred expression types.

So even though the pass often looks like leaf substitution, it owns some real type-repair responsibilities.

## 11. The plain-vs-optimizing split is scheduler-significant

This is the main repo-level conclusion.

The optimizing variant uses a nested `PassRunner`, adds Binaryen’s default function optimization passes, and reruns them on changed functions.

The plain pass does **not** do that.

This means plain `simplify-globals` should be taught as:

- a self-contained late module/global cleanup and propagation pass
- without automatic follow-up cleanup of the newly simplified function bodies

That is why some debris visible after plain-pass conceptual rewrites may disappear only in the optimizing variant or in later explicitly scheduled passes.

## Scheduler findings

## Public variants

The reviewed upstream scheduler exposes at least three relevant surfaces:

- `simplify-globals`
- `simplify-globals-optimizing`
- `propagate-globals-globally` (testing/helper surface)

## Preset placement

The existing repo docs already source-check that:

- lower optimization settings use plain `simplify-globals`
- the no-DWARF `-O` / `-Os` path in this repo’s current orientation page uses `simplify-globals-optimizing`

So plain `simplify-globals` is a real upstream preset participant even though it is not part of the repo’s current no-DWARF `-O` / `-Os` path focus.

## Interaction findings

The pass sits in the same late-global neighborhood as:

- `duplicate-import-elimination`
- `remove-unused-module-elements`
- `string-gathering`
- `reorder-globals`
- `directize`

That placement matters because `simplify-globals` can:

- make globals dead for later module cleanup
- simplify later global initializers that `string-gathering` and `reorder-globals` will see
- change how much global traffic survives into the final late-global layout stage

## Test-backed shape lessons

From the reviewed lit files, the most important durable shape families are:

### Positive shapes

- one-time global-to-global initializer folding
- writes of the init value collapsing to `drop(value)`
- self-guarded `if (global.get g) then global.set g ...` families
- startup propagation into later globals and segment offsets
- simple current-trace runtime propagation in function code
- immutable copy-chain canonicalization

### Negative / bailout shapes

- imports or exports block many rewrites
- function-code use blocks single-use initializer folding
- calls and nonlinear control block runtime current-value propagation
- extra effects in `read-only-to-write` bodies block the self-guard optimization
- value flow from the guard into dangerous side-effect choices blocks `read-only-to-write`
- type mismatch blocks earlier-ancestor replacement

### Easy-to-miss shapes

- startup-time mutation later does not block startup-time constant propagation now
- runtime propagation is intentionally weaker than a full CFG/global-constant pass
- the plain pass can leave function-local debris that only the optimizing variant’s nested rerun immediately cleans up

## What a future Starshine port must preserve

1. keep this as a **module/boundary pass**, not a hot local pass
2. preserve the distinction between startup propagation and runtime propagation
3. preserve `read-only-to-write` as an actual safety matcher, not a loose heuristic
4. preserve `drop(value)` when removing writes
5. preserve exact-type gating on earlier-ancestor replacement unless deliberately extended
6. preserve refinalization after type-changing replacements
7. keep the plain-vs-optimizing split explicit in the scheduler surface
8. do not silently fold the optimizing variant’s nested rerun into the plain pass contract

## What is still uncertain

I did not do a full fresh line-by-line trunk-vs-`version_129` drift audit for this pass in this thread.
The new dossier therefore treats `version_129` as the source oracle and avoids claiming current `main` internals are unchanged.

I also relied on existing repo scheduler notes for the exact default-opt-level switch between plain and optimizing variants, rather than duplicating a full new preset audit here. That is acceptable for this dossier because the key new teaching goal is the **shared-engine but different public contract** split.

## Deliverables created from this note

This note feeds a new living folder:

- `docs/wiki/binaryen/passes/simplify-globals/index.md`
- `docs/wiki/binaryen/passes/simplify-globals/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/simplify-globals/plain-vs-optimizing-and-safety.md`
- `docs/wiki/binaryen/passes/simplify-globals/wat-shapes.md`

It also requires tracker/index/log updates because `simplify-globals` is now an explicit upstream-only registry dossier.

## Source URLs

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
