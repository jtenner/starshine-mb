---
kind: concept
status: supported
last_reviewed: 2026-04-25
sources:
  - ../../../raw/binaryen/2026-04-25-local-cse-current-main-code-map.md
  - ../../../raw/binaryen/2026-04-22-local-cse-primary-sources.md
  - ../../../raw/research/0119-2026-04-20-local-cse-binaryen-research.md
  - ../../../raw/research/0262-2026-04-22-local-cse-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0358-2026-04-25-local-cse-current-main-and-test-map.md
related:
  - ./index.md
  - ./basic-block-windows-and-barriers.md
  - ./implementation-structure-and-tests.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../coalesce-locals/index.md
  - ../simplify-locals/index.md
---

# Binaryen `local-cse` Strategy

## Upstream source rule

- Use Binaryen `version_129` as the tagged source oracle for this pass.
- The reviewed official Binaryen `version_129` release page rechecked on 2026-04-22 showed publish date **2026-04-01**; the exact release/source/test URLs from that refresh are captured immutably in [`../../../raw/binaryen/2026-04-22-local-cse-primary-sources.md`](../../../raw/binaryen/2026-04-22-local-cse-primary-sources.md).
- A focused 2026-04-25 current-`main` bridge on `LocalCSE.cpp`, `pass.cpp`, `opt-utils.h`, helper files, and `local-cse.wast` found no teaching-relevant contract drift and is captured at [`../../../raw/binaryen/2026-04-25-local-cse-current-main-code-map.md`](../../../raw/binaryen/2026-04-25-local-cse-current-main-code-map.md).
- The core implementation is `src/passes/LocalCSE.cpp`.
- Scheduler placement comes from `src/passes/pass.cpp` and the after-inlining helper in `src/passes/opt-utils.h`.
- The key helper contracts come from:
  - `src/ir/linear-execution.h`
  - `src/ir/effects.h`
  - `src/ir/properties.h`
  - `src/ir/properties.cpp`
  - `src/ir/intrinsics.h`
  - `src/ir/cost.h`
- The shipped behavior examples come from `test/lit/passes/local-cse.wast`.

Primary source URLs:

- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/LocalCSE.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/opt-utils.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/linear-execution.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/effects.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/properties.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/properties.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/intrinsics.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/cost.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/local-cse.wast>

## High-level intent

Binaryen uses `local-cse` for a very specific kind of reuse.

The real question is not:

- “did we compute something similar somewhere in this function?”

It is:

- “did we already compute this exact whole tree in the current linear execution window, and is it still safe and worthwhile to replace the later copy with a temp-local read?”

That is why the implementation is small, local, and temp-local based.

For the source/test-file map behind this strategy, read [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md).

## The pass in one table

| Phase | What Binaryen does | Why it exists |
| --- | --- | --- |
| Scan | Hash whole trees, find repeats, and record which later copies want to reuse which earlier original | Cheaply find candidates before doing expensive effect work |
| Check | Rewalk the same windows and remove requests invalidated by intervening effects or nondeterminism | Make the greedy scan safe |
| Apply | Add `local.tee` on surviving originals and replace later repeats with `local.get` | Materialize the reuse in normal wasm locals |

## Phase 1: pass shape and scheduling facts matter

`LocalCSE` reports:

- `isFunctionParallel() == true`
- `invalidatesDWARF() == true`

That tells us three useful things immediately:

- this is a **function pass**, not a module pass
- Binaryen expects to run it across functions in parallel
- the pass changes locals enough that current DWARF updating cannot keep debug information aligned

## Phase 2: the core data structures explain the algorithm

## `HashedExpression`

Binaryen wraps each candidate expression with:

- the raw `Expression*`
- a cached hash digest

The digest is just a fast bucket key.

## `HEComparer`

If the digests match, Binaryen still performs a full equality check with `ExpressionAnalyzer::equal(...)`.

A subtle but important comment here: equality deliberately ignores metadata differences.

That means `local-cse` can merge semantically identical trees even if they carry different metadata such as branch hints.

## `HashedExprs`

The scanner maps each hashed expression bucket to a vector of active matching expressions.

The first element of that vector becomes the chosen original.
Later equal occurrences request reuse of that first one.

## `RequestInfo`

Each tracked expression can be in exactly one of two roles:

- **original**
  - `requests > 0`
- **repeat**
  - `original != nullptr`

The file asserts that an expression cannot be both at once.

That matters because if a tree appears three times, the second and third both point back to the first, not to each other.

## Phase 3: `Scanner` finds reuse requests

`Scanner` is where most of the “what counts as a candidate?” logic lives.

It inherits from `LinearExecutionWalker` and sets:

- `connectAdjacentBlocks = true`

It keeps two main state tables:

- `activeExprs`
  - all active repeated-tree candidates in the current linear window
- `activeIncrementalInfo`
  - a stack of cached `(hash, possible)` results for children, so parent hashes can be assembled in linear time

## Window resets are deliberate

Whenever `LinearExecutionWalker` reports non-linear control flow, `Scanner::doNoteNonLinear(...)` clears:

- `activeExprs`
- `activeIncrementalInfo`

But it does **not** clear the recorded `requestInfos`.

So the pass forgets which expressions are still active in the current window, while remembering the reuse plan it already discovered.

## Hashing is bottom-up and linear-time

For each expression, the scanner:

1. takes a shallow hash for the root
2. pops cached child hash info from the stack
3. combines those child hashes into the parent hash
4. combines child “possible” flags into the parent possibility flag too

If a child came from another window and the stack is empty at the wrong time, the scanner gives up on that parent as a cross-window candidate.

That is one reason the pass stays local and cheap.

## `isRelevant(...)` is about profitability and local materializability

Before deeper safety reasoning, Binaryen throws away roots that are obviously not worth local-cse work.

It rejects:

- non-concrete results
- `local.get`
- `local.set`
- constant expressions

The comment’s intuition is simple: this pass only makes sense for values that are worth saving in a temp local and reusing later.

### Shrink-oriented threshold

When `shrinkLevel > 0`, Binaryen only considers roots whose measured size is at least `3`.

So it is conservative when code size matters.

### Speed-oriented threshold

When `shrinkLevel == 0`, Binaryen accepts roots whose:

- measured size is at least `2`
- and `CostAnalyzer(curr).cost > 0`

The comment explains why size-1 values are skipped even in speed mode:

- `local.get` is cheap
- but VMs also perform their own CSE/GVN
- so tiny size-1 wins are not worth introducing extra temp-local traffic

That is why repeated `global.get` stays unchanged in the shipped test.

## `isPossible(...)` is about semantic safety in principle

This early filter is not the same as profitability.
It exists because the scanner is greedy.

The comment gives the key motivation:

- if a larger effectful parent were allowed into the candidate set,
- it could hide a pure child opportunity,
- and by the time the parent failed later, it would be too late to recover the child.

So Binaryen rejects roots early when they could never work later.

### Positive special-case: idempotent direct calls

If the root is a direct `call` and the callee’s annotations say `idempotent`, Binaryen treats it as possible.

This is a narrow exception. The pass does **not** do the same for arbitrary call-site annotations or indirect calls.

### Negative rule: shallow non-trap side effects

Binaryen computes a `ShallowEffectAnalyzer` and rejects roots whose shallow effects include non-trap side effects.

The root idea is:

- pure or trap-only roots may still be reusable
- roots that write or otherwise visibly affect state are not

### Negative rule: shallow generativity

Binaryen also rejects roots where `Properties::isShallowlyGenerative(...)` is true.

From `properties.cpp`, that shallow generativity set includes roots like:

- ordinary non-idempotent direct `call`
- `call_indirect`
- `call_ref`
- `struct.new`
- `array.new*`
- `cont.new`

So even if such a root had no visible side effects, it is still not reusable if it may produce a fresh value each time.

That is one of the pass’s most important GC-era correctness rules.

## Repeats point to the first original only

When the scanner sees a repeated candidate:

- the repeat records `original = vec[0]`
- the first original increments `requests`

So the pass is intentionally first-occurrence-biased.

## Parent repeats cancel child requests

This is the most important piece to explain well for beginners.

If a repeated parent tree is going to reuse the earlier whole parent, then Binaryen walks the parent’s direct children and removes any child-level requests that were recorded earlier.

That is why the pass prefers:

- “reuse the bigger exact repeated tree”

instead of:

- “reuse every smaller repeated node inside that tree too”

This is the real reason the file header spends time on the `eqz(A)` example.

## Phase 4: `Checker` validates requests against effects

The scanner records *planned* reuse.
`Checker` is where Binaryen decides which of those plans remain valid after considering intervening code.

It keeps `activeOriginals`, mapping each currently-live original to:

- `requestsLeft`
  - how many future repeats still hope to reuse it in the current window
- `effects`
  - a full `EffectAnalyzer` result for that original

## In-between expressions invalidate active originals

For each expression `curr`, the checker first computes shallow effects for `curr` and compares them against every active original’s saved effects using `effects.invalidates(...)`.

If `curr` invalidates an original:

- Binaryen subtracts all not-yet-seen future requests for that original
- erases the original if no requests remain at all
- removes it from `activeOriginals`

So once an intervening effect makes future reuse unsafe, Binaryen abandons those future copies instead of trying to salvage them with a more complex scheme.

## Trap differences are deliberately ignored

Before invalidation testing, the checker sets:

- `effects.trap = false`

The source comment explains the reasoning:

- the first retained original would still trap first
- the later repeated copies would never execute

That is why repeated loads remain eligible even though loads may trap.

## Idempotent current expressions do not invalidate their own kind

If the current expression is idempotent and shallowly equal to an active original, the checker skips invalidating that original.

This is the invalidation-side half of the same narrow idempotent-call exception.

## Only originals with future requests pay for full effect analysis

If a tracked expression is an original with `requests > 0`, the checker computes a full `EffectAnalyzer` for it and activates it.

If an expression never attracted future repeats, it never pays for that analysis.

That is a nice example of the pass doing expensive work only after the cheap scan says it might matter.

## Repeats disappear if their original already died

If the current expression is a repeat but its original has already been removed from `activeOriginals`, Binaryen just erases that repeat’s `RequestInfo`.

So the later applier never sees it as a valid optimization at all.

## Phase 5: `Applier` materializes the reuse with locals

`Applier` takes the surviving request map and rewrites the function.

It keeps `originalLocalMap`, which records:

- original expression -> fresh temp local index

It also clears that map between non-linear windows.

## Originals become `local.tee`

If an original still has requests:

1. `Builder::addVar(getFunction(), curr->type)` allocates a new temp local
2. the original expression becomes `local.tee temp, curr`

## Repeats become `local.get`

If a repeat still points to a valid original whose requests remain positive:

- the repeat is replaced by `local.get temp`
- the original’s remaining request count is decremented

## Temp-local lifetime stays window-local in practice

The locals are function-scoped in the declaration list, but the logical reuse state is cleared between windows.

That is a big part of why this pass stays a small temp-local cleanup instead of becoming a large whole-function register-allocation problem.

## Scheduler placement is part of the real contract

## Ordinary no-DWARF slot

In `pass.cpp`, the late ordinary slot is:

- after `coalesce-locals`
- before full `simplify-locals`

That is a very meaningful neighborhood:

- `coalesce-locals` can make repeated local-fed trees easier to recognize
- `local-cse` then turns some of those repeated trees into temp-local reuse
- full `simplify-locals` can then clean up the resulting local traffic further

## Extra aggressive slot after flatten

At `optimizeLevel >= 4`, Binaryen also inserts:

- `flatten`
- `simplify-locals-notee-nostructure`
- `local-cse`

The source comment says `local-cse` is especially useful after flatten, but only if Binaryen first simplifies some of the redundant locals that flatten creates.

That is an explicit scheduler-design fact, not just an accident.

## Nested reruns matter too

`opt-utils.h` reruns the default function optimization pipeline after inlining-oriented changes, so `local-cse` also reappears inside:

- `dae-optimizing`
- `inlining-optimizing`

The saved `-O4z` debug log shows `36` total `local-cse` executions in one run, which matches that nested-rerun story.

## What the pass does **not** do

Binaryen `version_129` `local-cse` is not:

- full CFG-wide common-subexpression elimination
- arbitrary subtree extraction
- loop-invariant code motion
- a replacement for `flatten`
- a replacement for `coalesce-locals`
- a replacement for `simplify-locals`
- a pass that tries to optimize every tiny repeated size-1 value

The file header even points at future global GVN-like work as a separate possible direction, which is a clear sign that current `local-cse` is intentionally smaller.

## A good porting checklist

A future Starshine port should preserve all of the following:

- the three-stage `scan -> check -> apply` structure, or an equivalent design
- first-occurrence originals
- parent-over-child request cancellation
- shallow impossibility filtering before full effect work
- the limited `LinearExecutionWalker` window model
- trap-ignoring reasoning for repeated roots
- shallow-generativity rejection
- the idempotent-call carveout
- the size/cost thresholds
- the early `flatten -> simplify-locals-notee-nostructure -> local-cse` slot
- the late `coalesce-locals -> local-cse -> simplify-locals` slot
- the nested rerun story under optimizing passes

## Bottom line

The cleanest beginner-friendly summary is:

- `local-cse` is a **small, window-local, temp-localizing tree-reuse pass**
- its real complexity is not in huge dataflow machinery, but in getting the exact scan, barrier, and scheduler rules right
- if a future Starshine port preserves those rules, it will match what Binaryen actually does, not just what the pass name seems to promise
