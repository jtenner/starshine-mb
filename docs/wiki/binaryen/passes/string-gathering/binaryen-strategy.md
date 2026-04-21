---
kind: concept
status: supported
last_reviewed: 2026-04-20
sources:
  - ../../../raw/research/0124-2026-04-20-string-gathering-binaryen-research.md
related:
  - ./index.md
  - ./reuse-naming-and-ordering.md
  - ./wat-shapes.md
  - ../simplify-globals-optimizing/index.md
  - ../../../strings/string-const-surface.md
  - ../../no-dwarf-default-optimize-path.md
---

# Binaryen `string-gathering` strategy

## Upstream source rule

- Use Binaryen `version_129` as the current source oracle for this pass.
- The core implementation lives in `src/passes/StringLowering.cpp`.
- Scheduler placement comes from `src/passes/pass.cpp`.
- Pass construction is declared in `src/passes/passes.h`.
- The helper constants for the string lowering family live in `src/passes/string-utils.{h,cpp}`.
- The parallel function scan helper comes from `src/ir/module-utils.h`.
- The module-code walk surface comes from `src/wasm-traversal.h`.
- The main shipped behavior examples come from `test/lit/passes/string-gathering.wast`.
- A useful neighboring string/global interaction example comes from `test/lit/passes/propagate-globals-globally.wast`.

Primary source URLs:

- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/StringLowering.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/passes.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/string-utils.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/string-utils.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/module-utils.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/wasm-traversal.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/string-gathering.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/propagate-globals-globally.wast>

## High-level intent

Binaryen uses `string-gathering` to make string literals cheaper to reuse by turning repeated `string.const` expressions into reads from one canonical immutable global per literal.

That sentence is true but incomplete.

The actual implementation is a very small late **scan + canonical-global + direct AST rewrite** pass with three stages:

| Stage | What Binaryen does | Why it exists |
| --- | --- | --- |
| Scan | Find every `StringConst` and remember the exact `Expression**` slots that contain them | Replacement later is precise and cheap |
| Canonicalize globals | Reuse or create one immutable non-null string global per literal | Keeps repeated string construction out of ordinary code |
| Rewrite uses | Replace every non-defining `StringConst` with `global.get` of the canonical global | Leaves later passes with shared string sources instead of scattered literals |

That means this pass is not:

- full string lowering
- string operation optimization
- dead global elimination
- final global layout tuning
- effect- or CFG-driven analysis
- a nested rerun wrapper

## Pass family and scheduler placement

`pass.cpp` exposes one production pass name here:

- `string-gathering`

The default global optimization post-pass cluster runs it only when:

- `optimizeLevel >= 2`, and
- `wasm->features.hasStrings()`

In the canonical no-DWARF `-O` / `-Os` path tracked in this repo, the pass appears:

- after `duplicate-import-elimination`
- after `simplify-globals-optimizing`
- after the late `remove-unused-module-elements`
- before `reorder-globals`
- before `directize`

`pass.cpp` also explains *why* it sits where it does: gather strings to globals right before `reorder-globals`, which will then sort them properly.

That means the intended late-tail division of labor is:

- `string-gathering`
  - create or pick canonical defining string globals
  - do only the minimum reorder needed for validity
- `reorder-globals`
  - perform the stronger final ordering heuristic

## Important implementation-location fact

The implementation lives in `StringLowering.cpp`, and `StringLowering` literally subclasses `StringGathering`.

So `string-gathering` is both:

- a real standalone late optimization pass, and
- the shared first phase of full `string-lowering`

That shared-file arrangement is easy to miss if you only search for a dedicated `StringGathering.cpp` file.

## Stage 1: scan every `StringConst`

## The walker only cares about one node kind

The scan phase uses a tiny `PostWalker` that implements just:

- `visitStringConst(StringConst* curr)`

On each match, it stores:

- `getCurrentPointer()`

That pointer storage is the key detail.
Binaryen is not doing a “find again later” pass. It records the exact mutable AST slot that contains each string constant.

## Functions are analyzed in parallel

For functions, the pass uses:

- `ModuleUtils::ParallelFunctionAnalysis<StringPtrs>`

Each function gets its own vector of `Expression**` string slots.
Imported functions are skipped.

This is a nice example of a pass that is not itself a `WalkerPass`, but still uses Binaryen’s parallel pass infrastructure to collect function-local data efficiently.

## Module-level code is scanned separately

After the function scan, the pass also walks module-level code using:

- `walkModuleCode(module)`

From `wasm-traversal.h`, that covers:

- table initializer expressions
- defined global initializers
- element-segment offsets and items
- data-segment offsets

Practical beginner takeaway:

- the pass is broader than “string literals in functions”
- it is meant to canonicalize string constants anywhere Binaryen stores module-level expression code

The shipped test file directly proves the defined-global side, including a nested `struct.new` case. Table and elem-item coverage is a source-derived inference from the walker surface.

## Literal deduplication is separate from use-site collection

Once analysis is done, Binaryen merges the per-function and module-code results into:

- `stringPtrs`
  - every exact string-constant slot to potentially rewrite
- `strings`
  - one deduplicated vector of literal payloads

The dedup key is the literal `Name` payload itself.
Not:

- first use site
- frequency
- dominance
- control-flow locality

Then the pass sorts the deduplicated literal list alphabetically for deterministic global creation order.

## Stage 2: choose or create canonical defining globals

## Reusable existing globals are very strict

The pass reuses an existing global only if all of these are true:

- the global type is exact non-null stringref (`(ref string)`)
- the global is defined, not imported
- the global is immutable
- the initializer is directly a `StringConst`

That means these are all excluded from reuse:

- imported globals
- mutable globals
- nullable string globals
- globals whose initializer is a nested expression containing a string somewhere inside
- globals already rewritten into `global.get` aliases

This exact-shape reuse rule is one of the most important source facts in the entire dossier.

## First reusable global wins

The pass keeps a `stringToGlobalName` map.
When it sees reusable globals, it only records the first one found for each literal.

So the canonical representative is:

- not a fresh merged synthetic name if a reusable one already exists
- not chosen alphabetically
- simply the first reusable global seen in current module order

A future port should preserve that deterministic choice.

## Preserved pointers prevent self-rewrites

Whenever a reusable defining global is adopted, the pass also stores the pointer to that global’s initializer in `stringPtrsToPreserve`.

Later, when replacing uses, those preserved slots are skipped.

This is the mechanism that avoids rewriting a defining global into a self-referential `global.get`.

## Fresh names are readable, escaped, and collision-safe

For strings without a reusable defining global, Binaryen creates a new immutable `(ref string)` global.

The name pipeline is:

1. convert the literal from WTF-16 to WTF-8 for readability
2. escape it to valid text
3. prefix with `string.const_`
4. pass the result through `Names::getValidGlobalName(...)`

So the printed name is a readable label, not the semantic identity key.
The literal payload itself remains the real dedup key.

## The reorder here is validity-first, not cost-based

After it knows which globals define strings, the pass performs a `std::stable_sort` on the global list.

The comparator only enforces:

- defining globals before non-defining globals

That is intentionally simple.
The source comment says this is just to ensure validation because later global initializers may now use those globals.

So this pass deliberately does **not** try to be the same thing as `reorder-globals`.

## Stage 3: replace non-defining `StringConst` uses

The final rewrite is simple:

- for each recorded `Expression**` string slot
- unless that slot is preserved as a defining initializer
- replace the old `StringConst` with `builder.makeGlobalGet(globalName, nnstringref)`

A few important consequences fall out of that implementation:

- only actual `StringConst` nodes are rewritten
- existing `global.get` users are untouched
- no refinalization pass is needed, because the replacement `global.get` has the same non-null string type as the original literal

## Analysis and helper dependencies

This pass depends on:

- `PostWalker`
  - child-first AST scan without recursion
- `getCurrentPointer()`
  - direct mutation of exact AST slots later
- `ModuleUtils::ParallelFunctionAnalysis`
  - parallel function scanning
- `walkModuleCode(...)`
  - module-level expression coverage
- `Builder`
  - creation of `StringConst`, `Global`, and `GlobalGet`
- `Names::getValidGlobalName(...)`
  - collision-safe generated names
- `String::convertWTF16ToWTF8(...)`
  - readable names from stored literal data
- `String::printEscaped(...)`
  - identifier-safe escaping

This pass notably does **not** depend on:

- `Effects`
- CFG or liveness analyses
- linear-execution helpers
- type-updating helpers
- refinalization
- nested `PassRunner` reruns

## Main interactions with nearby passes

## After `simplify-globals-optimizing`

Because gathering runs after the late globals cleanup cluster, it can canonicalize string constants that earlier global propagation or folding exposed.

That “exposed string constants” story is partly an inference from scheduler order plus neighboring tests like `propagate-globals-globally.wast`, but it is a very practical way to understand why gathering belongs near the end rather than near the parser or early constant folding.

## After `remove-unused-module-elements`

Gathering also runs after late module pruning, so it works over the already-surviving module surface instead of manufacturing new canonical globals for declarations that were about to disappear anyway.

## Before `reorder-globals`

This is the most explicit source-backed interaction.

- gathering may add new defining globals
- gathering may force them earlier for validity
- `reorder-globals` then performs the stronger final layout step

A port that collapses those two responsibilities together may still work, but it will no longer mirror Binaryen’s actual scheduler contract cleanly.

## Relation to `string-lowering`

Since `StringLowering` subclasses `StringGathering`, a future Starshine port should seriously consider implementing the literal-gathering logic as a shared helper that both:

- the standalone late optimize pass, and
- any later full string-lowering pass

can reuse.

## What this pass is not

A useful beginner correction list:

- It is not `string-lowering`.
- It is not string instruction canonicalization.
- It is not dead-global elimination.
- It is not `global.get` propagation into code.
- It is not the final global layout heuristic.
- It is not a profitability or dataflow pass.

If a future port starts accreting those jobs, it is no longer a faithful `string-gathering` port.

## Source-derived port checklist

A future Starshine port should preserve all of these:

- scan defined functions in parallel or equivalent whole-module coverage
- scan module-level expression code, not just function bodies
- deduplicate by exact literal payload
- reuse only immutable defined direct `(ref string)` globals
- preserve the first reusable global encountered in module order
- skip rewriting the defining initializer slots of reused globals
- generate fresh readable global names safely when needed
- move defining globals earlier stably for validity
- leave smarter final ordering to `reorder-globals`
- keep the pass narrow: only `string.const` hoisting/canonicalization

## Sources

- [`../../../raw/research/0124-2026-04-20-string-gathering-binaryen-research.md`](../../../raw/research/0124-2026-04-20-string-gathering-binaryen-research.md)
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/StringLowering.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/passes.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/string-utils.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/string-utils.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/module-utils.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/wasm-traversal.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/string-gathering.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/propagate-globals-globally.wast>
