# 0124 - `string-gathering` Binaryen research

## Status

- Date: 2026-04-20
- Type: One-off raw investigation
- Scope: document one currently unimplemented Binaryen late string/global pass in Starshine, using Binaryen `version_129` plus the saved generated-artifact audit to explain what `string-gathering` actually does, which helpers it depends on, which IR shapes it rewrites or preserves, and what a future Starshine port must keep exact.

## Why this pass

- `docs/wiki/binaryen/passes/tracker.md` still listed `string-gathering` with wiki status `none` when this thread started.
- The pass sits in the canonical no-DWARF late tail, after the big global/boundary cleanup passes and immediately before `reorder-globals`.
- The saved generated-artifact `-O4z` audit records a real skipped top-level upstream slot:
  - slot `54`
- The saved Binaryen debug log shows the pass is real but small in that captured run:
  - `0.00280223` seconds
- The backlog already tracks it as slice `SG` in `agent-todo.md`.
- This pass is easy to misdescribe as either:
  - “lower strings”, or
  - “deduplicate string literals globally”, or
  - “optimize string operations”.
- The real source contract is narrower and more structural:
  - it only touches `string.const`
  - it canonicalizes those constants into immutable globals
  - it reuses only a very specific existing-global shape
  - it does a validity-first global reorder, not the final profitability/order heuristic
  - it does not lower string instructions, remove dead globals, or rerun nested optimizations

That combination makes it a very good dossier target: the implementation is short, but the scheduler meaning and the easy-to-miss module-order rules matter a lot.

## Saved local source material

### Local Starshine / audit sources

- `src/passes/optimize.mbt`
- `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/strings/string-const-surface.md`
- `docs/wiki/raw/research/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md`
- `docs/wiki/raw/research/0093-2026-04-18-generated-o4z-pass-audit-summary.md`
- `.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/summary.json`
- `.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/skipped-unimplemented-slots.json`
- `.artifacts/o4z-wasm-opt-debug.log`
- `agent-todo.md`

### Official Binaryen `version_129` sources

- `src/passes/StringLowering.cpp`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/StringLowering.cpp>
- `src/passes/pass.cpp`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- `src/passes/passes.h`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/passes.h>
- `src/passes/string-utils.h`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/string-utils.h>
- `src/passes/string-utils.cpp`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/string-utils.cpp>
- `src/ir/module-utils.h`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/module-utils.h>
- `src/wasm-traversal.h`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/wasm-traversal.h>
- `test/lit/passes/string-gathering.wast`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/string-gathering.wast>
- `test/lit/passes/propagate-globals-globally.wast`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/propagate-globals-globally.wast>
- `CHANGELOG.md`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/CHANGELOG.md>

## Fast answer

Binaryen’s `string-gathering` pass is a late **module-wide `string.const` hoisting and canonicalization pass**.

It does not optimize general string logic.
It does not lower stringref to imports.
It does not run effects or CFG analysis.
It does not remove dead globals.
It does not pick a final global order by cost.

Instead it does three small stages:

1. scan all functions and module-level code for every `string.const`
2. ensure each distinct string literal has one canonical immutable `(ref string)` global
3. replace every other `string.const` use with `global.get` of that canonical global

The most durable source-derived facts are:

- The implementation lives in `StringLowering.cpp`, not in its own standalone file.
- `StringLowering` inherits from `StringGathering` and runs it first, so the gathering logic is also the first phase of full string lowering.
- Deduplication is by the literal payload (`Name`), not by use site, frequency, or control-flow reachability.
- Existing globals are reusable only if they are:
  - defined, not imported
  - immutable
  - exact type `(ref string)` / non-null stringref
  - directly initialized by `string.const`
- Nullable, mutable, or nested users are **not** reusable as the canonical storage site.
- When Binaryen reuses an existing defining global, it deliberately preserves that initializer and avoids rewriting it into a self-referential `global.get`.
- Newly created defining globals get readable synthetic names based on the string contents.
- After creating or selecting defining globals, Binaryen performs a stable “defining globals first” reorder purely to keep later global initializers valid.
- The pass leaves actual layout tuning to the following `reorder-globals` pass.

## Where it appears in the scheduler

## Top-level no-DWARF path

Binaryen `version_129` registers one pass name here:

- `string-gathering`

`pass.cpp` schedules it inside `addDefaultGlobalOptimizationPostPasses()` only when:

- `optimizeLevel >= 2`, and
- the module has the strings feature enabled

In this repo’s canonical no-DWARF `-O` / `-Os` path, it appears after:

- `duplicate-import-elimination`
- `simplify-globals-optimizing`
- `remove-unused-module-elements`

and before:

- `reorder-globals`
- `directize`

The `pass.cpp` comment is unusually explicit here: Binaryen gathers strings to globals right before `reorder-globals`, which will then sort them properly.

That one comment explains a lot of the real scheduler meaning:

- `string-gathering` does a minimal validity-preserving reorder
- `reorder-globals` is responsible for the better final layout

## Saved generated-artifact `-O4z` audit

The saved ordered generated-artifact replay records:

- slot `54`: `string-gathering`

The saved Binaryen debug log records one top-level runtime sample:

- `0.00280223` seconds

So this is not an expensive analysis pass. The implementation difficulty is in the exact rewrite and ordering contract, not in reproducing a large optimizer.

## Repo-local registry caveat

There is one local bookkeeping wrinkle worth recording explicitly.

- `docs/wiki/binaryen/passes/tracker.md` already tracked `string-gathering` as a late boundary-only / module-shaped missing pass.
- But the current literal name `string-gathering` does **not** appear in `src/passes/optimize.mbt`’s `pass_registry_boundary_only_names()` array today.

The most plausible reading is that this is a local tracker/registry bookkeeping gap, not evidence that the pass is unimportant. I am treating that as an inference from the no-DWARF scheduler doc, the tracker intent, the backlog slice, and the saved `-O4z` audit all agreeing that the pass matters.

## Actual implementation structure

## 1. One small module pass inside `StringLowering.cpp`

`passes.h` declares:

- `createStringGatheringPass()`

`pass.cpp` registers:

- `string-gathering`
  - “gathers wasm strings to globals”

The implementation itself is a `struct StringGathering : public Pass` inside `src/passes/StringLowering.cpp`.

That file placement matters.
`StringGathering` is not just a neighboring utility; `StringLowering : public StringGathering` literally subclasses it and calls `StringGathering::run(module)` first.

So a future Starshine port should think of `string-gathering` as:

- a real standalone pass in the default optimize pipeline, and also
- the shared first phase of full string lowering

## 2. Stage one scans for `string.const` and records exact pointer locations

The scan phase has two outputs:

- `strings`: one deduplicated vector of literal payloads
- `stringPtrs`: pointers to every `Expression*` slot that currently contains a `StringConst`

Binaryen collects those pointers with a tiny `PostWalker`:

- visit only `StringConst`
- push `getCurrentPointer()` for each one

That pointer detail is important. The pass is not just logging “I saw this literal.” It remembers the exact AST slot so it can replace that slot later.

## 3. Function scanning is parallel, module code scanning is separate

For function bodies, `StringGathering` uses:

- `ModuleUtils::ParallelFunctionAnalysis<StringPtrs>`

That means each function gets its own vector of string-expression pointers, gathered through Binaryen’s built-in parallel pass infrastructure.

Then the pass separately scans module-level code by calling:

- `walkModuleCode(module)`

on another `StringWalker`.

From `wasm-traversal.h`, that module-code walk includes:

- table initializer expressions
- defined global initializers
- element-segment offsets and items
- data-segment offsets

Important nuance:

- the pass is broader than “function bodies plus direct globals”
- it is designed to catch any `string.const` that appears in Binaryen’s module-level expression slots

The shipped test file directly exercises defined global initializers, including a nested `struct.new` case. The table/elem coverage is a source-derived inference from `walkModuleCode(...)`; I did not find a dedicated `string-gathering.wast` assertion that isolates those shapes specifically.

## 4. Deduplication key is the literal `Name`, not use order

After the parallel analysis completes, Binaryen:

- inserts every encountered literal into an `unordered_set<Name>`
- appends every recorded pointer into the flat `stringPtrs` list
- copies the set into `strings`
- sorts `strings` alphabetically for determinism

This gives two separate invariants:

- the replacement phase still knows every exact use site
- global creation is deterministic and literal-keyed, not “first appearance wins” by use position

That deterministic sort is a real contract. The test file explicitly checks that the gathered globals appear in alphabetical order before later `reorder-globals` gets a chance to do anything smarter.

## 5. Stage two first tries to reuse existing defining globals

The pass does **not** always create fresh globals.

It first scans existing module globals and reuses only globals that already match the emitted defining form exactly:

- type is `Type(HeapType::string, NonNullable)`
- not imported
- immutable
- initializer is directly a `StringConst`

That means all of these are *not* reusable as canonical storage:

- imported globals
- mutable globals
- nullable string globals
- globals whose initializer is a nested expression that contains a string somewhere inside
- globals whose initializer is already a `global.get` alias to another defining global

This is one of the most important beginner traps. “Contains the right string” is not enough. The global has to already be in the exact defining shape Binaryen wants.

## 6. Existing reusable globals use a first-match rule

When scanning reusable existing globals, the pass writes into `stringToGlobalName[string]` only if no name is already recorded.

So the rule is:

- first reusable defining global seen in current module order wins
- later reusable globals for the same string become aliases after replacement

This is different from the earlier dedup set ordering.

- literal discovery is sorted alphabetically for deterministic creation
- reusable-global selection is “first matching existing global in module order”

A future port needs to preserve both facts.

## 7. `stringPtrsToPreserve` prevents self-trampling

Whenever the pass decides to reuse an existing defining global, it adds the pointer to that global’s initializer into `stringPtrsToPreserve`.

Later, the replacement phase skips those exact pointers.

Without that preserved-pointer set, the pass would accidentally rewrite:

```wat
(global $g (ref string) (string.const "foo"))
```

into something like:

```wat
(global $g (ref string) (global.get $g))
```

which would be nonsense.

This preserved-pointer mechanism is the key reason repeated runs of the pass are stable instead of growing alias chains or destroying the defining globals they reuse.

## 8. Fresh global names are readable but not semantic

For strings that do not already have a reusable global, Binaryen creates a new immutable defining global.

The name-generation pipeline is:

1. convert the stored literal from WTF-16 to WTF-8
2. escape it to valid text
3. prefix it with `string.const_`
4. pass it through `Names::getValidGlobalName(...)`

So a string like `"bar"` can become a global name like:

- `$"string.const_\"bar\""`

Important durable takeaway:

- the literal payload is the semantic key
- the printed global name is only a readable, collision-safe label

## 9. Stage two then does a validity-first stable reorder

After choosing reusable globals and creating new ones, `addGlobals(...)` performs a `std::stable_sort` over `module->globals`.

The comparator simply moves defining globals to the front:

- defining globals before non-defining globals
- stable within those groups

This is intentionally conservative.
The source comment says it exists so later global initializers that now use `global.get` will remain valid, while leaving better ordering to `reorder-globals`.

So this is **not** the final global cost model.
It is just the minimum reorder necessary to avoid invalid “use before defining global” cases.

## 10. Stage three replaces every other `string.const` with `global.get`

Finally, `replaceStrings(...)` walks the flat `stringPtrs` list and, for every non-preserved pointer:

- reads the literal payload
- looks up the canonical global name for that string
- replaces the original `StringConst` with `builder.makeGlobalGet(globalName, nnstringref)`

Notably, the pass does not refinalize afterward.
That makes sense from the source:

- `string.const` already has non-null string type
- the replacement `global.get` is emitted with the same non-null string type

So there is no type-repair phase here.

## Important shape families

## Positive shape: repeated function-body literals collapse to one global

If multiple function bodies contain the same literal:

```wat
(func
  (drop (string.const "foo")))
(func
  (drop (string.const "foo")))
```

Binaryen creates or reuses one defining global and rewrites both uses to:

```wat
(global.get $some_string_global)
```

This is the main intended use case.

## Positive shape: a direct immutable `(ref string)` global can be reused

If the module already has:

```wat
(global $g (ref string) (string.const "foo"))
```

then that existing global becomes the canonical storage site.
No fresh defining global is created for `"foo"`.

## Positive shape: nested module-code uses still get rewritten

The shipped test covers a global initializer like:

```wat
(global $struct (ref $struct)
  (struct.new $struct
    (string.const "")))
(global $string (ref string) (string.const ""))
```

After gathering:

- the nested `string.const` becomes `global.get $string`
- `$string` is sorted before `$struct`

That proves the pass is not limited to function bodies or direct global initializers.

## Positive shape: multiple direct string globals can collapse to one canonical source

If a module already contains several immutable direct string globals with the same literal, Binaryen reuses the first matching one and rewrites the later ones into aliases:

```wat
(global $g1 (ref string) (string.const "foo"))
(global $g2 (ref string) (string.const "foo"))
```

becomes conceptually:

```wat
(global $g1 (ref string) (string.const "foo"))
(global $g2 (ref string) (global.get $g1))
```

## Negative shape: nullable or mutable globals are not canonical defining globals

The shipped test explicitly covers:

- nullable string globals
- mutable string globals

Those globals are not reused as the defining source.
Instead, Binaryen creates or reuses a separate immutable non-null defining global and rewrites the old global initializer into a `global.get` of that canonical one.

## Negative shape: existing `global.get` users are left alone

The pass only visits and replaces `StringConst` nodes.
It does not walk around rewriting preexisting `global.get` uses of reusable globals into anything shorter.

So if a function already says:

```wat
(drop (global.get $g))
```

that remains as-is.
The test file even calls this out explicitly.

## Negative shape: this pass does not lower string operations

After `string-gathering`, instructions like:

- `string.concat`
- `string.eq`
- `string.measure_*`
- `string.encode_*`

are still string instructions.

Only `StringLowering` turns the whole string feature surface into imported externref-based helpers.

## Negative shape: this pass does not do final global layout work

The internal stable sort is only “defining globals first.”
It does not claim to be the same thing as `reorder-globals`.

That is exactly why the no-DWARF scheduler places `string-gathering` immediately before `reorder-globals`.

## Helper dependencies

The pass is small, but it does depend on a useful set of Binaryen helper infrastructure:

- `ModuleUtils::ParallelFunctionAnalysis`
  - parallel per-function scan framework
- `PostWalker`
  - child-first scan over AST nodes without recursion
- `getCurrentPointer()`
  - lets the pass store exact mutable AST slots to rewrite later
- `walkModuleCode(...)`
  - expands the scan beyond function bodies
- `Builder`
  - constructs `StringConst`, `Global`, and `GlobalGet` nodes
- `Names::getValidGlobalName(...)`
  - generates collision-safe readable global names
- `String::convertWTF16ToWTF8(...)`
  - makes the stored literal readable as text
- `String::printEscaped(...)`
  - ensures identifier-safe escaping

What it notably does **not** depend on:

- `Effects`
- CFG or liveness analyses
- linear-execution reasoning
- type-updating or refinalization helpers
- nested `PassRunner` reruns

## Pass interactions

## With `simplify-globals-optimizing`

The no-DWARF scheduler runs `string-gathering` after `simplify-globals-optimizing`.

That means `string-gathering` can canonicalize `string.const` nodes that earlier global propagation or global simplification exposed.
`propagate-globals-globally.wast` is a helpful neighboring test here: Binaryen is willing to propagate string constants through global relationships earlier, so it makes sense that gathering runs after the late global cleanup cluster.

The exact “this scheduler order is why” claim is partly an inference from source order plus the neighboring tests, but it fits the implementation story well.

## With `remove-unused-module-elements`

The no-DWARF scheduler also runs gathering after the late `remove-unused-module-elements` post-pass. That means gathering sees the already-pruned surviving global/module surface, not globals that a previous cleanup already deleted.

## With `reorder-globals`

This interaction is direct and explicit in source comments.

- gathering makes sure the defining globals exist and appear early enough to validate
- `reorder-globals` then applies the stronger final global-order heuristic

A Starshine port should preserve that division of labor.

## With `string-lowering`

`StringLowering` subclasses `StringGathering` and runs it first.
So even if Starshine eventually ports full string lowering separately, it should probably share the same literal-gathering helper rather than independently reimplementing a slightly different “hoist string constants to globals” phase.

## What a future Starshine port must preserve

- Scan **all defined functions** and **module-level expression code**, not just top-level global initializers.
- Deduplicate by the exact literal payload, not by syntactic position.
- Reuse only existing globals in the exact defining shape:
  - immutable
  - defined
  - non-null stringref
  - direct `string.const` initializer
- Preserve the first reusable global encountered in module order.
- Preserve the separate `stringPtrsToPreserve` idea so reused defining globals stay defining globals.
- Generate stable readable names for fresh defining globals, but do not make semantics depend on the printed name.
- Perform the validity-first stable reorder of defining globals before other globals.
- Leave final layout tuning to `reorder-globals`.
- Do not silently widen the pass into string lowering, dead-global elimination, or `global.get` constant propagation.

## Beginner-friendly “what this pass sounds like vs what it really is”

What it sounds like:

- “collect strings somewhere”

What it actually is:

- a late module-wide rewrite that turns every ordinary `string.const` use into a read from one canonical immutable global per distinct literal, while carefully preserving reusable defining globals and keeping later global initializers valid.

That is the right mental model to carry into a future implementation.

## Open questions and uncertainty

- The local tracker currently treats `string-gathering` as a boundary-only missing pass, but the literal name is absent from `src/passes/optimize.mbt`’s boundary-only array today. I am treating that as a repo bookkeeping gap, not as a reason to deprioritize the dossier.
- The module-code scan clearly includes tables and element-segment items from `walkModuleCode(...)`, but I did not find a shipped `string-gathering.wast` case that isolates those exact shapes. Claims about those sites are therefore source-based inferences from the walker surface, not directly test-backed examples in this note.
- Binaryen `CHANGELOG.md` highlights `string-lowering` and later `string-lifting`, but I did not find a separate public changelog bullet for `string-gathering` itself. The pass is definitely present in `version_129`; I just do not have a neat public release-note breadcrumb for when the standalone CLI surface first appeared.

## Sources

### Local repo sources

- `src/passes/optimize.mbt`
- `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/strings/string-const-surface.md`
- `docs/wiki/raw/research/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md`
- `docs/wiki/raw/research/0093-2026-04-18-generated-o4z-pass-audit-summary.md`
- `.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/summary.json`
- `.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/skipped-unimplemented-slots.json`
- `.artifacts/o4z-wasm-opt-debug.log`
- `agent-todo.md`

### Official Binaryen sources

- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/StringLowering.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/passes.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/string-utils.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/string-utils.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/module-utils.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/wasm-traversal.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/string-gathering.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/propagate-globals-globally.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/CHANGELOG.md>
