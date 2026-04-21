# Binaryen `reorder-functions` research

Date: 2026-04-21
Author: Codex recursive wiki campaign thread
Status: source-backed upstream-only dossier input

## Scope and candidate selection

I re-read:

- `docs/README.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
- `agent-todo.md`
- `src/passes/optimize.mbt`

The original no-DWARF / saved-`-O4z` queue is already dossier-covered.
The first widened upstream-only queue is dossier-covered too.
So this thread needed to justify a **new** eligible tracker expansion rather than picking an old `none` entry.

I chose the local boundary-only registry pass name **`reorder-functions`**.
That expansion is justified because:

- it is still explicitly named in `src/passes/optimize.mbt`
- it is a real public Binaryen pass registered in upstream `pass.cpp`
- it has a real `version_129` implementation file (`ReorderFunctions.cpp`)
- it sits beside already-documented layout neighbors such as `reorder-globals`, `reorder-locals`, and `reorder-types`
- its behavior is easy to over-assume from the name; the actual contract is much smaller and more mechanical
- `agent-todo.md` currently has **no dedicated slice** for `reorder-functions`

I also reviewed the sibling pass **`reorder-functions-by-name`**, because both public passes share the same implementation file and the sibling clarifies what `reorder-functions` is *not*.

## Main source set reviewed

### Core implementation

- Binaryen `version_129` `src/passes/ReorderFunctions.cpp`
- Binaryen `version_129` `src/passes/pass.cpp`

### Representative shipped test surface

- Binaryen `version_129` `test/lit/passes/reorder-functions-by-name.wast`

### Freshness / drift spot check

- Binaryen current `main` `src/passes/ReorderFunctions.cpp`

## Freshness check

I did a narrow current-`main` spot check on `ReorderFunctions.cpp`.

Durable result:

- the checked current-`main` file is identical to `version_129`

So `version_129` is a safe oracle for the behavior documented here.

## High-level conclusion

Binaryen `reorder-functions` is **not** a control-flow or body optimizer.
It is a very small **module-ordering pass** that only changes the order of function declarations inside the module's function list.

Its entire meaningful algorithm in `version_129` is:

1. seed every function with usage count `0`
2. walk function bodies in parallel and count direct `call` targets
3. add one count for the start function, if present
4. add one count for every function export
5. add one count for every function name found in element segment contents
6. sort functions by descending count
7. break ties by descending function name

The sibling `reorder-functions-by-name` is even smaller:

- sort functions by ascending function name

## What the pass does **not** do

The reviewed source is helpful because it shows several tempting assumptions are wrong.

`reorder-functions` does **not** in `version_129`:

- rewrite function bodies
- change any call target names or references directly
- count `ref.func` uses yet
- count declaration-section mentions yet
- inspect `call_ref` traffic
- model dynamic runtime hotness
- use CFG, effects, liveness, or dataflow analyses
- appear in the repo's canonical no-DWARF `-O` / `-Os` pipeline

The file even leaves explicit TODO comments for two missing count sources:

- `ref.func`
- declaration-section mentions

So this is best taught as a **static binary-size-oriented declaration reorderer**, not as a runtime profile pass and not as a full function-liveness or callgraph optimizer.

## Why Binaryen has this pass at all

The implementation comment at the top gives the durable reason:

- lower function indices for frequently referenced functions can reduce the number of bytes needed to encode those references in the binary

That is a binary-format/index-encoding story, not a semantic optimization story.

The same comment also records an important caveat:

- the reordered output may reduce wasm binary size but increase gzip size because original proximity may have been better for compression

So the pass deliberately optimizes one size metric while openly admitting it can hurt another.

## Exact implementation structure

## 1. Public pass registration

Upstream `pass.cpp` registers two public pass names from the same source file:

- `reorder-functions-by-name`
- `reorder-functions`

Their descriptions already capture the real split:

- by-name: useful for debugging
- plain reorder: sorts functions by access frequency

That split matters for a future Starshine port because the two passes share mechanics but have different intent.

## 2. Counting direct call uses

`ReorderFunctions.cpp` defines a `CallCountScanner` as a function-parallel `PostWalker`.
It only visits:

- `Call`

When it sees a direct call, it increments the target's count.

Important consequence:

- indirect calls and reference-typed call surfaces are outside the actual counting model here

## 3. Extra module-level roots

After scanning function bodies, the pass increments counts for three non-body sources:

- `module->start`
- exported functions
- function names mentioned in element segments via `ElementUtils::iterAllElementFunctionNames(...)`

This is the most important beginner correction.
The pass is not “count calls and sort.”
It also treats those module-level entry/reference surfaces as static uses.

## 4. Stable-enough tie behavior

The comparator sorts by:

- higher count first
- if counts are equal, larger function name first

That means ties are *not* preserved in original order.
They are deliberately broken by name.

This is easy to miss and matters for reproducibility.
If a future port uses stable original-order ties instead, it will disagree with Binaryen.

## 5. No content rewrite and no nondefaultable-local fixups

Both pass structs override:

- `requiresNonNullableLocalFixups() -> false`

That lines up with the source shape.
They only reorder function declarations.
They do not mutate bodies or local declarations.

A good porting rule is:

- this is a **module-index metadata reorder** pass, not a function-body rewrite pass

## 6. Sibling pass: `reorder-functions-by-name`

The sibling is helpful because it isolates the shared substrate.
Its `run(...)` method simply sorts by:

- ascending function name

So Binaryen treats these as two distinct public ordering policies over the same function list:

- debugging-friendly lexical order
- size-oriented static-use order

## Official test surface and what it proves

The reviewed official lit file is:

- `reorder-functions-by-name.wast`

That file proves the sibling by-name surface directly.
It checks that Binaryen rewrites module function order into lexical name order while leaving bodies untouched.

I did **not** find a dedicated `version_129` `test/lit/passes/reorder-functions.wast` file in the reviewed upstream `test/lit/passes` directory listing.
That absence is itself a useful maintenance note:

- the by-name sibling has a direct golden file
- the frequency-based main pass relies more on the implementation file and pass registration for its contract than on a rich dedicated lit corpus

This is an observation from the reviewed official directory listing, not a proof that no other upstream test exercises the pass indirectly elsewhere.

## Beginner-friendly behavior summary

If you want to predict `reorder-functions`, imagine each function gets “points” from only these sources:

- direct calls to it
- being the start function
- being exported as a function
- being placed in an element segment

Then Binaryen sorts higher-score functions earlier.
If two functions have the same score, it sorts them by descending name.

That is the whole pass.

## Important positive shapes

The source implies these real positive module families:

1. one helper function called many times moves earlier
2. an exported-but-never-called function still gets a nonzero score
3. a start function gets a nonzero score even with no direct callers
4. a table-populated function in an element segment gets a nonzero score even without direct calls
5. tied-count functions are reordered by name, not preserved in source order

## Important negative / bailout / surprise shapes

The source also implies these important boundaries:

1. `ref.func`-only functions are undercounted today because of the explicit TODO
2. declaration-only mentions are undercounted today because of the explicit TODO
3. `call_ref` does not directly help a function unless some other counted surface also mentions it
4. identical-count anonymous-or-weird-name cases still depend on Binaryen's name ordering, not source order
5. gzip-size regressions are explicitly part of the tradeoff surface
6. because the pass only reorders definitions, it depends on the module writer / index remap machinery outside this file to serialize the final order correctly

## Interaction with nearby passes

`reorder-functions` is best grouped conceptually with:

- `reorder-locals`
- `reorder-globals`
- `reorder-types`

But the algorithm is much simpler than those neighbors.
It does not do dependency DAGs, type-graph legality, or body-local rewrite repair.
It is closer to a declaration-list sort with a tiny static counting prepass.

It is also *not* part of the current repo's documented no-DWARF default optimize path, so it should be treated as an explicit upstream-only layout tool rather than a current parity blocker.

## What a future Starshine port must preserve

A faithful port must preserve at least these facts:

- count **direct `call`** targets only from function bodies
- add separate count bumps for **start**, **function exports**, and **element segment function names**
- do **not** silently invent `ref.func` or declaration counting unless the port deliberately targets newer/different upstream behavior
- sort by **descending count**
- break ties by **descending function name**
- keep the sibling `reorder-functions-by-name` split explicit
- treat the pass as a module-order rewrite, not a body optimizer

## Open questions / uncertainty

- I did not perform a whole-repo Binaryen test inventory beyond the reviewed `test/lit/passes` directory listing and the dedicated by-name lit file, so there may be indirect coverage elsewhere.
- I did not benchmark binary-size versus gzip-size outcomes; the size-tradeoff statement here comes from the implementation comment, not a fresh local measurement.
- I did not inspect Binaryen's writer/index-remap internals in this thread, so the dossier should teach the pass as a declaration-order pass and avoid overclaiming about the exact downstream serialization mechanics.

## Concrete dossier plan filed into the wiki

To make this durable in the living wiki, I am adding a new folder:

- `docs/wiki/binaryen/passes/reorder-functions/`

with:

- `index.md`
- `binaryen-strategy.md`
- `implementation-structure-and-tests.md`
- `module-shapes.md`

That keeps the pass separate from `reorder-globals`, `reorder-locals`, and `reorder-types`, while still linking them as conceptual neighbors.

## Sources

- Local registry and tracker inputs:
  - `src/passes/optimize.mbt`
  - `docs/wiki/binaryen/passes/tracker.md`
  - `docs/wiki/binaryen/passes/index.md`
  - `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
  - `agent-todo.md`
- Official Binaryen `version_129` sources:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/ReorderFunctions.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/reorder-functions-by-name.wast>
- Current-main freshness check:
  - <https://github.com/WebAssembly/binaryen/blob/main/src/passes/ReorderFunctions.cpp>
- Official reviewed directory listings used for the lit-file observation:
  - <https://api.github.com/repos/WebAssembly/binaryen/contents/test/lit/passes?ref=version_129>
  - <https://api.github.com/repos/WebAssembly/binaryen/contents/src/passes?ref=version_129>
