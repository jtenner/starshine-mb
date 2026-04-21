# Binaryen `string-gathering` source-confirmation follow-up (`version_129`)

- Date: 2026-04-21
- Pass: `string-gathering`
- Upstream version reviewed: `version_129`
- Follow-up type: source-confirmation / implementation-structure-and-tests deepening

## Why this follow-up exists

The existing `docs/wiki/binaryen/passes/string-gathering/` folder was already a useful dossier, but it still had one real gap:

- it did not yet have one compact source-confirmed page that mapped the exact owner files, the real implementation phases, and the shipped tests proving the contract.

That gap matters because `string-gathering` is easy to mis-teach as either:

- a vague prelude to `string-lowering`,
- a generic string optimizer, or
- a pure global-reordering pass.

Binaryen `version_129` implements something narrower and more teachable:

- a late module pass that scans exact `StringConst` slots,
- chooses or creates one canonical immutable `(ref string)` global per literal,
- reorders those defining globals earlier only when needed for validity,
- and rewrites the remaining literal sites to `global.get`.

This follow-up keeps the earlier dossier, but adds the missing compact source-confirmed owner/test map and tightens a few implementation details that future Starshine port work could otherwise miss.

## Canonical repo inputs consulted first

Per repo process, I re-read these before choosing the pass and writing the follow-up:

- `docs/README.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
- `agent-todo.md`
- existing folder: `docs/wiki/binaryen/passes/string-gathering/`

The tracker still listed `string-gathering` as an unimplemented dossier-level pass, not one of the passes excluded by the thread instructions.
The backlog does have a dedicated slice for it:

- `SG` with `[SG]001` and `[SG]002`

So unlike some earlier tracker-expansion targets, this pass already has an active implementation queue home.

## Official Binaryen sources reviewed

### Primary implementation and registration sources

- `src/passes/StringLowering.cpp`
- `src/passes/pass.cpp`
- `src/passes/passes.h`
- `src/passes/string-utils.h`
- `src/passes/string-utils.cpp`
- `src/ir/module-utils.h`
- `src/wasm-traversal.h`

### Official shipped tests reviewed

- `test/lit/passes/string-gathering.wast`

### Current-main drift spot check

I also spot-checked current upstream `main` for the same `StringGathering` surface in `src/passes/StringLowering.cpp`.
On the reviewed surface, I did not find a drift that changed the `version_129` contract this dossier teaches.

## High-confidence findings

## 1. The real owner file is `StringLowering.cpp`, not a dedicated `StringGathering.cpp`

This is the first compact fact the living dossier still needed in one place.

Binaryen implements the standalone pass class `StringGathering` inside:

- `src/passes/StringLowering.cpp`

and then implements full `StringLowering` by subclassing it.

That means `string-gathering` is both:

- a real public late optimization pass, and
- the shared first phase of full string lowering.

A future Starshine port should probably mirror that split as shared helper logic plus two public entry points rather than copy-pasting two separate implementations.

## 2. The scheduler gate is small and explicit

`pass.cpp` registers the public pass name:

- `string-gathering`

and schedules it in the late post-pass cluster only when:

- `optimizeLevel >= 2`, and
- `wasm->features.hasStrings()`

It appears after:

- `duplicate-import-elimination`
- `simplify-globals-optimizing`
- the late `remove-unused-module-elements`

and before:

- `reorder-globals`
- `directize`

The source comment there explicitly frames the ordering as:

- gather strings to globals first,
- then let `reorder-globals` sort them properly.

So `string-gathering` owns canonicalization and minimum validity repair, not the final global layout heuristic.

## 3. The scan is exact-slot based, not “search again later”

`StringGathering` uses a tiny `StringScanner` postwalker that only visits:

- `StringConst`

and records:

- `getCurrentPointer()`

That means the pass saves exact `Expression**` slots for later mutation.
It is not doing a second matcher pass over the AST when it rewrites.

This exact-slot design is important because it explains both:

- why the final rewrite is so small, and
- how the preserve-set for defining initializers works safely.

## 4. Function-body coverage is parallel, but module-code coverage is separate and broader than the test file proves directly

For defined functions, the pass uses:

- `ModuleUtils::ParallelFunctionAnalysis<StringPtrs>`

with a per-function `StringScanner`.
Imported functions are skipped.

Separately, it scans module-level expression code through:

- `walkModuleCode(module)`

from `wasm-traversal.h`.
That helper covers module expression surfaces such as:

- defined global initializers,
- element-segment offsets and items,
- data-segment offsets,
- table initializer expression code.

The dedicated lit file directly proves the defined-global initializer side.
The broader elem/data/table coverage is a source-derived inference from the `walkModuleCode(...)` helper surface, not from an isolated shipped test case in `string-gathering.wast`.

## 5. Literal deduplication and canonical-global choice are two separate phases

After gathering all `Expression**` sites, the pass does two distinct things:

1. collect every exact string slot into `stringPtrs`
2. collect one deduplicated literal payload list into `strings`

The dedup key is the literal payload `Name`, not:

- frequency,
- first use site,
- dominance,
- or control-flow position.

Then Binaryen sorts the deduplicated literal list alphabetically before creating any fresh globals.
That gives deterministic fresh-global creation order.

## 6. Reusable existing globals are stricter than “already contains this string”

A global is reused as the canonical defining global only if all of these are true:

- it is defined, not imported,
- immutable,
- exact non-null `stringref` / `(ref string)`,
- and its initializer is directly a `StringConst`.

So Binaryen does **not** reuse as canonical definers:

- mutable string globals,
- nullable string globals,
- nested initializers that contain a `string.const` somewhere inside,
- imported globals,
- or globals already rewritten into aliases.

This matches the folder's earlier strategy page, but the owner/test-map follow-up makes the rule easier to recover quickly.

## 7. The canonical representative is first reusable global in module order

When Binaryen sees several reusable defining globals for the same literal, it keeps the first one it encounters in the current module global list.

So the rule is not:

- alphabetical name order,
- shortest name,
- or always create a fresh synthetic name.

It is simply:

- first reusable global wins.

That exact choice is visible in the shipped lit file and directly encoded in the `stringToGlobalName.emplace(...)` behavior.

## 8. The preserve set is the key to avoiding self-rewrites

When Binaryen adopts an existing global as the canonical defining one, it also remembers the pointer to that exact initializer in:

- `stringPtrsToPreserve`

The final rewrite then skips preserved initializer slots.

Without this set, a reused defining global could be rewritten into:

- `global.get` of itself

which would destroy the defining literal rather than preserve it.

This is one of the most important tiny implementation details for a faithful port.

## 9. Fresh globals use readable, collision-safe names, but the literal payload remains the real identity key

For literals with no reusable defining global, Binaryen creates a fresh immutable `(ref string)` global.

The name pipeline is:

1. convert WTF-16 literal contents to WTF-8 for readability,
2. print them escaped,
3. prefix them with `STRING_CONST_PREFIX` from `string-utils.h`,
4. pass the result through `Names::getValidGlobalName(...)`.

So the generated global names are readable and stable-looking, but they are not the semantic identity key.
The semantic identity is still the literal payload itself.

## 10. The reorder is only a validity repair, and the code makes that intent explicit

After deciding which globals are defining string globals, Binaryen does a `std::stable_sort` over module globals so that:

- defining string globals come before non-defining globals.

The source comment explicitly says this is to ensure validity because later global initializers may now read those canonical globals.

So this pass does not try to be:

- `reorder-globals`,
- a size optimizer,
- or a use-count layout pass.

It is a minimum validity-first reorder, deliberately followed by `reorder-globals` for the stronger final layout work.

## 11. The final rewrite surface is narrower than the module scan surface

The scan surface is broad because it records all `StringConst` sites it can reach.
But the final rewrite itself is tiny:

- for each recorded `Expression**` slot,
- unless the slot is preserved as a defining initializer,
- replace the `StringConst` with `builder.makeGlobalGet(globalName, Type(HeapType::string, NonNullable))`.

This means the pass rewrites only:

- actual `StringConst` nodes.

It does **not** try to simplify or canonicalize preexisting:

- `global.get` users,
- string operations,
- or alias globals that already use `global.get`.

## 12. The dedicated lit file proves several key families, but not all source-visible module-code coverage

`test/lit/passes/string-gathering.wast` directly proves these important cases:

- repeated function-body literals become one canonical defining global,
- an existing immutable direct `(ref string)` global is reused,
- first reusable global wins when multiple existing definers match,
- nullable and mutable string globals are not reused as definers,
- nested global-initializer users can be rewritten to `global.get`,
- and canonical defining globals may be moved earlier to keep later global initializers valid.

What the dedicated test does **not** directly isolate is the broader `walkModuleCode(...)` coverage for:

- element items,
- table initializer expressions,
- or data/elem offsets.

So the clean teaching split is:

- global-initializer and reuse/order cases are test-proven,
- broader module-code coverage is source-proven.

## What this follow-up changes in the living dossier

This follow-up does not overturn the folder the way the `duplicate-import-elimination` or `dead-code-elimination` corrections did.
Instead, it upgrades the dossier by making the following more explicit and easier to recover:

- the real owner-file map,
- the shared-engine relation to `StringLowering`,
- the exact implementation phases in one compact page,
- the exact shipped test families, and
- the boundary between test-proven and source-derived module-code coverage.

## Porting checklist crystallized from this follow-up

A faithful Starshine `string-gathering` port should preserve all of these:

- feature gate: strings only
- late scheduler placement before `reorder-globals`
- exact-slot scanning of `StringConst` nodes
- parallel defined-function scan plus separate module-code walk
- literal dedup by exact payload, not by use-site shape
- deterministic sorted fresh-literal order
- reuse only direct immutable defined non-null string globals
- first reusable global in module order wins
- preserve defining initializer slots so reused globals do not self-alias
- readable collision-safe fresh names based on literal contents
- stable defining-global-before-user-global validity repair
- final rewrite only of `StringConst` sites into `global.get`
- explicit separation from full `string-lowering`

## Files added or updated because of this follow-up

- Added `docs/wiki/binaryen/passes/string-gathering/implementation-structure-and-tests.md`
- Updated `docs/wiki/binaryen/passes/string-gathering/index.md`
- Updated tracker/index/catalog pages so future campaign threads can see that this owner/test-map gap is now closed

## Source links

- Binaryen `version_129` `StringLowering.cpp`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/StringLowering.cpp>
- Binaryen `version_129` `pass.cpp`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- Binaryen `version_129` `passes.h`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/passes.h>
- Binaryen `version_129` `string-utils.h`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/string-utils.h>
- Binaryen `version_129` `string-utils.cpp`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/string-utils.cpp>
- Binaryen `version_129` `module-utils.h`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/module-utils.h>
- Binaryen `version_129` `wasm-traversal.h`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/wasm-traversal.h>
- Binaryen `version_129` `string-gathering.wast`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/string-gathering.wast>
- Binaryen current `main` `StringLowering.cpp`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/StringLowering.cpp>
