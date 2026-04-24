# Binaryen `reorder-functions-by-name` research

Supersession note (2026-04-24): this seed note remains useful for the initial dossier rationale, but raw primary-source provenance and current Starshine status are now superseded by `docs/wiki/raw/binaryen/2026-04-24-reorder-functions-by-name-primary-sources.md`, `docs/wiki/raw/research/0325-2026-04-24-reorder-functions-by-name-primary-sources-and-starshine-followup.md`, and `docs/wiki/binaryen/passes/reorder-functions-by-name/starshine-strategy.md`.

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
- the newly landed `reorder-functions` dossier

The original no-DWARF / saved-`-O4z` queue is already dossier-covered.
The first widened upstream-only queue is dossier-covered too.
So this thread needed to justify either a major-gap fallback or another genuine tracker expansion.

I chose the local boundary-only registry pass name **`reorder-functions-by-name`**.
That expansion is justified because:

- it is still explicitly named in `src/passes/optimize.mbt`
- it is a real public Binaryen pass registered in upstream `pass.cpp`
- it shares a real `version_129` implementation file with `reorder-functions` (`ReorderFunctions.cpp`)
- it has its own shipped dedicated lit file, `reorder-functions-by-name.wast`
- the previous `reorder-functions` dossier only covered it incidentally as a sibling, not as its own dedicated living pass home
- `agent-todo.md` currently has **no dedicated `reorder-functions-by-name` slice**

So this is not a duplicate of the new `reorder-functions` dossier.
It is a narrower sibling-pass dossier for a separate public pass name that still lacked its own canonical living folder.

## Main source set reviewed

### Core implementation

- Binaryen `version_129` `src/passes/ReorderFunctions.cpp`
- Binaryen `version_129` `src/passes/pass.cpp`

### Direct shipped test surface

- Binaryen `version_129` `test/lit/passes/reorder-functions-by-name.wast`

### Freshness / drift spot check

- Binaryen current `main` `src/passes/ReorderFunctions.cpp`

## Freshness check

I did a narrow current-`main` spot check on `ReorderFunctions.cpp`.

Durable result:

- the checked current-`main` file is identical to `version_129` on the reviewed surface

So `version_129` is a safe oracle for the behavior documented here.

## High-level conclusion

Binaryen `reorder-functions-by-name` is an extremely small **module-ordering** pass.
It does not inspect function bodies at all.
It just sorts the module's function list by **ascending function name**.

That means the real algorithm is simply:

1. look at every function currently in `module->functions`
2. compare their `Name`s lexicographically
3. sort ascending

Its job is not performance tuning or binary size tuning.
Upstream `pass.cpp` explicitly describes it as useful for **debugging**.

## What the pass does **not** do

`reorder-functions-by-name` does **not** in the reviewed `version_129` source:

- count direct calls
- inspect start/export/element-segment references
- compute runtime hotness
- use CFG, effects, liveness, or dataflow analyses
- rewrite function bodies
- repair locals, labels, or types
- appear in the repo's canonical no-DWARF `-O` / `-Os` optimize path

That makes it an important beginner-teaching contrast with its sibling `reorder-functions`.
The two passes share a file, but they do not share the same ordering policy.

## Exact implementation structure

## 1. Public pass registration

Upstream `pass.cpp` registers two public names from the same source file:

- `reorder-functions-by-name`
- `reorder-functions`

The descriptions matter:

- `reorder-functions-by-name`: useful for debugging
- `reorder-functions`: sorts by access frequency

Those registration strings are already the most honest summary of the split.

## 2. The by-name implementation itself is tiny

Inside `ReorderFunctions.cpp`, the `ReorderFunctionsByName` pass is a standalone `Pass` whose `run(Module* module)` method does one thing:

- `std::sort(module->functions.begin(), module->functions.end(), ...)`

and the comparator returns:

- `a->name < b->name`

So the pass is not a mode bit inside `reorder-functions`.
It is a distinct public pass with its own comparator and its own purpose.

## 3. The sibling file context matters

The same file also defines:

- `CallCountScanner`
- `ReorderFunctions`

That shared-file context helps teach the boundary clearly:

- `reorder-functions` = tiny static-use count sort
- `reorder-functions-by-name` = pure lexical sort

A future Starshine port should preserve that split instead of hiding both policies behind one vague "reorder functions" operation.

## What the dedicated lit file proves

The reviewed official lit file `reorder-functions-by-name.wast` proves the pass directly.
It shows modules whose function declarations are reordered into ascending lexical name order.

Durable lessons from the lit file:

- the pass is a real public surface, not an undocumented test hook
- the rewrite is at the module declaration-order level
- function-body contents stay unchanged
- the ordering policy is deterministic and purely name-based

That dedicated test surface is actually stronger for the by-name sibling than the direct official test surface reviewed for plain `reorder-functions`.

## Beginner-friendly summary

A good mental model is:

- Binaryen takes the module's function list and alphabetizes it by internal function name.

That is all.

This is best taught as:

- a debugging-oriented lexical declaration orderer
- not a semantic optimizer
- not a size optimizer
- not a runtime hotness pass

## Important positive shapes

The reviewed source and lit file imply these real positive module families:

1. scrambled named functions become lexical ascending order
2. already sorted named functions stay unchanged
3. function bodies are preserved while only declaration order changes
4. the same module can produce a different order than plain `reorder-functions`, because lexical order ignores call counts entirely

## Important negative / surprise shapes

The same reviewed surface also implies these boundaries:

1. a lexically later but frequently called helper does **not** move earlier under this pass just because it is called often
2. start/export/element-segment references do **not** matter here
3. this pass is only as meaningful as Binaryen's internal `Name` ordering; it is not source-text pretty-print sorting with comments or original formatting context
4. this pass is module-layout-only, so any downstream index remapping happens outside this tiny file

## Why this pass matters even though it is tiny

It is easy to dismiss `reorder-functions-by-name` as trivial.
But a dedicated dossier is still useful because it prevents two recurring misunderstandings:

1. treating it as if it were the same thing as `reorder-functions`
2. treating it as if it were not a real public pass at all

The dedicated lit file and public pass registration show both mistakes are wrong.

## Interaction with nearby passes

`reorder-functions-by-name` is conceptually near:

- `reorder-functions`
- `reorder-globals`
- `reorder-locals`
- `reorder-types`

But it is simpler than all of them.
It has:

- no count model
- no dependency DAG
- no type legality phase
- no body rewrite repair

So it should be taught as the smallest possible member of that general "layout pass" neighborhood.

## What a future Starshine port must preserve

A faithful port must preserve at least these facts:

- it is a separate public pass name from `reorder-functions`
- it sorts `module->functions` by ascending name
- it does not inspect or mutate bodies
- it does not count direct calls or module-level references
- it is debugging-oriented, not size-oriented

## Open questions / uncertainty

- I did not inspect Binaryen writer/index-remap internals in this thread, so I describe the pass as a module declaration reorder and avoid overclaiming about the exact serialization machinery downstream.
- I did not inventory every possible indirect upstream test that might exercise the pass outside the dedicated lit file; the claims here are grounded in the implementation file, `pass.cpp`, and the direct shipped lit test.

## Concrete dossier plan filed into the wiki

To make this durable in the living wiki, I am adding a new folder:

- `docs/wiki/binaryen/passes/reorder-functions-by-name/`

with:

- `index.md`
- `binaryen-strategy.md`
- `implementation-structure-and-tests.md`
- `module-shapes.md`

That keeps this sibling pass separate from the newer `reorder-functions` dossier while linking them together explicitly.

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
