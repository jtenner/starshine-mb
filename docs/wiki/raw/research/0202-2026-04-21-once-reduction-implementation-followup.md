# Binaryen `once-reduction` implementation follow-up

Date: 2026-04-21
Status: archived research backing a living-dossier follow-up

## Scope and why this follow-up was justified

This thread had to continue the recursive Binaryen pass wiki campaign after the tracker had already been heavily filled.

I re-read:

- `docs/README.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
- `agent-todo.md`
- the existing `docs/wiki/binaryen/passes/once-reduction/` folder

and then chose **`once-reduction`** as an explicitly justified major-gap follow-up.

Why this still counted as a real gap even though the folder already had a deep dossier:

1. the folder already explained the pass at a high level, but it still lacked one dedicated source-confirmed page for the **exact implementation structure and test map**
2. the most port-critical ownership boundaries were still spread across the strategy page instead of being taught as one compact source-backed contract:
   - what `Scanner` owns
   - what `Optimizer` owns
   - what `OnceReduction::run(...)` itself owns
   - what `optimizeOnceBodies(...)` owns
3. the official lit file is large and subtle enough that future work benefits from a compact catalog of what it actually covers versus what only appears in source comments or helper code
4. `agent-todo.md` still has **no dedicated `once-reduction` slice**, so the wiki remains the main durable place to preserve this exact porting contract

In short: the dossier already taught the pass well, but it still did not isolate the file/test ownership and the exact phase split cleanly enough for a future Starshine port.

## Backlog status

`agent-todo.md` still has **no dedicated `once-reduction` slice**.

That remains worth stating explicitly because this pass is easy to mis-port as “a simple repeated-call cleanup” or “a once-wrapper peephole,” while the real Binaryen contract is a narrow module pass with scanning, fixed-point propagation, CFG/dominator reasoning, and a separate end-of-pass wrapper cleanup.

## Sources reviewed for this follow-up

### Core implementation

- `src/passes/OnceReduction.cpp`
- `src/passes/pass.cpp`
- `src/ir/intrinsics.h`

### Tests

- `test/lit/passes/once-reduction.wast`

### Freshness check

- `main/src/passes/OnceReduction.cpp`
- `main/test/lit/passes/once-reduction.wast`

A narrow current-main diff check found **no diff** between upstream `main` and `version_129` for either `src/passes/OnceReduction.cpp` or `test/lit/passes/once-reduction.wast`.

Inference: for the mechanics covered here, `version_129` is still a stable oracle.

## Main follow-up conclusion

The real Binaryen `version_129` pass is best taught as a four-owner structure:

1. `Scanner`
   - rejects bad reads and bad writes
   - recognizes the exact top-of-function once shape
   - seeds provisional function-to-global once associations
2. `OnceReduction::run(...)`
   - seeds candidate globals
   - invalidates exported globals
   - folds provisional scan results into final once-function decisions
   - adds the synthetic fake-global path for `@binaryen.idempotent`
   - runs the fixed-point loop
3. `Optimizer`
   - builds per-function CFG state
   - propagates once facts along immediate-dominator chains
   - nops redundant direct calls and redundant `global.set`s
   - exports “definitely set after calling this function” summaries for the next iteration
4. `optimizeOnceBodies(...)`
   - performs the tiny final cleanups on actual once-wrapper bodies
   - either deletes an empty wrapper body entirely
   - or strips the top two early-exit instructions from a pure single-call wrapper when the cycle guard allows it

That is a better source-confirmed teaching frame than simply saying “scan, optimize, then cleanup.”

## Exact source-backed ownership split

## `OptInfo` is the real shared contract

The core data structure is not hidden incidental state.

`OptInfo` contains:

- `onceGlobals`
  - candidate global name -> atomic bool meaning “still legal as a once-bit?”
- `onceFuncGlobals`
  - function name -> real or fake once-global name
- `onceGlobalsSetInFuncs`
  - fixed-point summary: which once-bits are definitely set after calling this function
- `newOnceGlobalsSetInFuncs`
  - the next-iteration version of that same summary

The pass logic only makes sense if those four maps stay conceptually distinct.

## `Scanner` owns candidacy and exact shape recognition

The `Scanner` responsibilities are narrower than “find optimization opportunities.”

It owns:

- counting every `GlobalGet`
- rejecting integer `GlobalSet`s whose values are zero or non-constant
- ignoring non-integer or unreachable-value sets
- recognizing the exact once pattern in `getOnceGlobal(...)`
- removing the one top-of-function guard read from the read count when the exact once pattern was found
- finally, disqualifying any global that still had leftover reads

That is the pass's proof that a global really behaves like a private monotonic once-bit.

## `getOnceGlobal(...)` is stricter than many summaries imply

The exact matcher requires all of these:

- function body root is a `Block`
- block has at least two items
- item `0` is an `If`
- the `If` condition is exactly `GlobalGet`
- the true arm is exactly `Return`
- there is no false arm
- item `1` is a `GlobalSet`
- the `GlobalSet` targets the same global
- the `GlobalSet` itself is not unreachable

It does **not** accept “morally similar” shapes like:

- a `nop` before the guard
- a `nop` between guard and set
- an `else` arm
- a mismatched `get` / `set` global pair
- a non-`Block` body root

## `OnceReduction::run(...)` owns the public/boundary setup and the idempotent extension

The top-level pass method owns several important facts that are easy to misattribute to `Scanner` or `Optimizer`.

### Initial candidate seeding

The pass first marks globals as possible once-bits only when they are:

- integer-typed
- not imported

It then marks every exported global as ineligible.

That means imported and exported globals are a top-level boundary filter, not a detail of CFG optimization.

### Provisional-to-final once-function merge

After `Scanner` runs, `run(...)` revisits `onceFuncGlobals` and removes any function whose chosen global no longer survives the `onceGlobals` legality test.

So the pass explicitly distinguishes:

- “this body looked like a once wrapper”
- “the controlling global was actually safe to reason about as a once-bit”

Both must hold.

### The fake-global idempotent path

The source-backed `@binaryen.idempotent` extension lives here, not in the lit file.

For no-param/no-result functions that are not already explicit once wrappers, Binaryen:

- checks `Intrinsics::getAnnotations(func.get()).idempotent`
- allocates a synthetic global name with `Names::getValidGlobalName(...)`
- writes that fake name into `onceFuncGlobals`
- inserts the fake name into `onceGlobals` as a valid once-bit key

So the annotation does not create a second algorithm.
It reuses the same once-global framework through a synthetic key.

## The fixed-point loop is driven by summary-cardinality growth

The loop inside `run(...)` is small but exact.

Binaryen:

- initializes each function summary with its own once-global, if any
- bails out entirely if there are no once functions
- repeatedly runs `Optimizer`
- swaps `newOnceGlobalsSetInFuncs` into `onceGlobalsSetInFuncs`
- counts the total number of summary entries across all functions
- stops once that count no longer increases

So the convergence signal is not “no function changed textually.”
It is the monotonic growth of the function-summary relation.

## `Optimizer` owns only two expression families

This is one of the most useful implementation facts for a future port.

`Optimizer` records only:

- `GlobalSet`
- `Call`

in each basic block's `BlockInfo::exprs` list.

It is not a general expression simplifier.
It only needs the node kinds that can directly prove or consume once facts.

## The CFG proof is immediate-dominator based, not all-predecessor merge based

The exact code copies facts from the block's immediate dominator.
The source comment explicitly says Binaryen could also intersect all predecessors, but does not.

That is the direct reason why:

- straight-line dominated chains optimize well
- many merge-point shapes remain conservative

## Redundant call and redundant set removal share the same helper

Inside block processing, `Optimizer` uses one local helper, conceptually:

- “this expression definitely writes once-global G”

If `G` was already known set in the block fact set, Binaryen nops the whole expression.
If not, Binaryen inserts `G` into the set and keeps going.

That exact helper is used for both:

- direct `global.set` to a legal once-global
- direct call to a known once function

So the pass's main local optimization is not “remove repeated calls” alone; it is “remove repeated writes of already-known once facts,” with calls just being one way to write those facts.

## Direct-call summary propagation is separate from direct once-call elimination

When the current `Call` target is not itself a once function, `Optimizer` still consults:

- `onceGlobalsSetInFuncs[target]`

and unions those proven globals into the current fact set.

That is the whole-program propagation path that lets callers learn facts from callees like:

- `A -> B -> C -> D -> once`

without requiring `A` itself to call the once function directly.

## The function summary written back is only entry-block knowledge

At the end of optimization, Binaryen stores:

- `std::move(onceGlobalsWrittenVec[0])`

as the function's summary.

That is a very specific contract.
The current implementation summarizes only the facts proved for the entry-root dominated path, not an intersection of all exits.
The source comment explicitly notes that a broader exit intersection would be a future improvement.

## `optimizeOnceBodies(...)` is deliberately tiny and restricted to real globals

The final cleanup phase skips:

- non-once functions
- fake-global idempotent functions

because it requires an actual module global to correspond to the once-bit.

It then looks only at actual once-wrapper `Block` bodies and distinguishes two cases:

### Empty wrapper body: list size `2`

That means the function is just:

- the guard `if`
- the nonzero `global.set`

with no payload.

Binaryen simply nops the whole body.

### Single-call wrapper body: list size `3`

That means the payload is exactly one expression.
If that payload is a direct `Call` to another once function, Binaryen may nop the first two list items instead of the whole body.
That preserves the call while deleting the wrapper's own early-exit logic.

Any larger body is left alone.

## The cycle guard is deterministic and asymmetric on purpose

`optimizeOnceBodies(...)` tracks `removedExitLogic`.
When considering `foo -> bar_once`, Binaryen only removes `foo`'s early-exit logic if `bar_once` is **not already** in `removedExitLogic`.

That makes the optimization order-dependent, so the function iteration is intentionally deterministic.
This is the source-backed mechanism that avoids turning a once-wrapper cycle into an infinite loop.

## What the official test file covers best

The dedicated `once-reduction.wast` file is large and varied.
Its strongest coverage groups are:

- basic dominated repeated-call positives
- nonzero initializer and nonzero later-write corner cases
- zero-write and non-constant-write invalidation
- exact shape-match failures (`nop`, `else`, short body, non-`Block` root, mismatched globals)
- self-recursion and loop behavior
- long control-flow chains
- try/catch CFG emission robustness
- multi-function propagation chains
- imported and exported mutable-global boundaries
- once-to-once, once-to-non-once, and non-once-to-once call patterns
- multi-node loop and dangerous triple-loop ordering cases

That test map matters because it shows the pass is not just checked on trivial two-call snippets.

## What the official test file does not appear to foreground

In the dedicated file I reviewed, the source-backed `@binaryen.idempotent` path is not surfaced as an obvious named section the way the explicit once-global families are.

So the durable teaching rule is:

- explicit once-global behavior is strongly lit-backed
- the idempotent extension is definitely real in source
- but the extension is easier to miss if you only skim the dedicated test headings

## Living-dossier changes this follow-up should justify

This follow-up justifies adding or refreshing living pages so the folder now explicitly records:

- the exact file/test ownership split
- the shared `OptInfo` state model
- the top-level-vs-scanner-vs-optimizer-vs-wrapper-cleanup phase ownership
- the entry-block-only function-summary rule
- the deterministic asymmetric cycle guard in wrapper cleanup
- the fact that the source-backed idempotent path is real even though the dedicated lit file is dominated by explicit once-global shapes

## Sources

- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/OnceReduction.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/intrinsics.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/once-reduction.wast>
- <https://github.com/WebAssembly/binaryen/blob/main/src/passes/OnceReduction.cpp>
- <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/once-reduction.wast>
- `docs/wiki/binaryen/passes/once-reduction/index.md`
- `docs/wiki/binaryen/passes/once-reduction/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/once-reduction/dominance-propagation-and-cycle-safety.md`
- `docs/wiki/binaryen/passes/once-reduction/wat-shapes.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
- `agent-todo.md`
