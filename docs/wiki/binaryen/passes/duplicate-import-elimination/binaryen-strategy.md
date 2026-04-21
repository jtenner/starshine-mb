---
kind: concept
status: supported
last_reviewed: 2026-04-20
sources:
  - ../../../raw/research/0123-2026-04-20-duplicate-import-elimination-binaryen-research.md
related:
  - ./index.md
  - ./identity-and-rewrite-surface.md
  - ./wat-shapes.md
  - ../simplify-globals-optimizing/index.md
  - ../../no-dwarf-default-optimize-path.md
---

# Binaryen `duplicate-import-elimination` strategy

## Upstream source rule

- Use Binaryen `version_129` as the current source oracle for this pass.
- The core implementation is `src/passes/DuplicateImportElimination.cpp`.
- Scheduler placement comes from `src/passes/pass.cpp`.
- The import-identity key comes from:
  - `src/ir/import-utils.h`
  - `src/ir/import-utils.cpp`
- The exact per-kind user-remap surface comes from:
  - `src/passes/opt-utils.h`
- The relevant IR field layout also appears in:
  - `src/wasm.h`
- The shipped behavior examples come from:
  - `test/lit/passes/duplicate-import-elimination.wast`

Primary source URLs:

- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/DuplicateImportElimination.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/import-utils.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/import-utils.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/opt-utils.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/wasm.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/duplicate-import-elimination.wast>

## High-level intent

Binaryen uses `duplicate-import-elimination` to collapse multiple internal import aliases that request the same external object.

That sentence is true but incomplete.

The actual implementation is a very small late **module planner plus name-rewrite pass** with three key stages:

| Stage | What Binaryen does | Why it exists |
| --- | --- | --- |
| Scan imports | Build structural identity keys for imported functions, globals, tables, and memories | Detect which imported declarations are duplicate aliases |
| Retarget users | Rewrite later duplicate users to the first-seen canonical import name | Preserve behavior while collapsing aliases |
| Remove duplicates | Delete the redundant imported declarations by name | Leave the late module pipeline with one canonical import per identity class |

That means the pass is not:

- dead-import elimination
- unused-import elimination
- function-only import merging
- callgraph optimization
- a cleanup rerun wrapper

## Pass family and scheduler placement

`pass.cpp` exposes one production pass name here:

- `duplicate-import-elimination`

The default global optimization post-pass cluster uses it when:

- `optimizeLevel >= 2`, or
- `shrinkLevel >= 2`

In the canonical no-DWARF `-O` / `-Os` path documented in this repo, the pass appears:

- after the second `duplicate-function-elimination`
- before `simplify-globals-optimizing`
- before `remove-unused-module-elements`
- before `string-gathering`
- before `reorder-globals`
- before `directize`

A future Starshine port should preserve that placement because later late module passes should see the already-canonicalized import surface, not duplicate alias declarations.

That “why” sentence is an inference from source order plus pass behavior, but it is the practical scheduler consequence.

## Saved `-O4z` local evidence

The saved generated-artifact audit and debug log add two useful local facts:

- the pass is a real top-level skipped slot in the saved `-O4z` path:
  - slot `51`
- the pass is tiny in the captured Binaryen run:
  - `2.133e-05` seconds

So the expected implementation difficulty is mostly in getting the exact user-remap surface right, not in reproducing some expensive analysis.

## Stage 1: imported-item scanning and identity keys

## Imported kinds actually handled by the pass

`DuplicateImportElimination.cpp` scans these imported declaration families only:

- functions
- globals
- tables
- memories

It does **not** scan imported tags.

That is one of the most important scope facts in the entire dossier. The pass name sounds generic, but the current source is not “all imports.”

## `ImportInfo` is the real duplicate key

The source relies on `ImportInfo`, which stores:

- `kind`
- `module`
- `base`
- `type`

So two imports only count as duplicates if all of those match according to the helper.

The mental model should be:

- same host module string
- same host field/base string
- same handled import kind
- same helper-defined import type metadata

not just “same visible import name.”

## Kind-specific identity details

### Functions

Functions use the stored `Function::type` as the key.

Practical beginner takeaway:

- same module/base + same signature-like type => merge
- same module/base + different signature => preserve both

### Globals

Globals use `Type(curr.type, curr.mutable_)`.

Practical beginner takeaway:

- value type must match
- mutability must match

### Memories

Memories use a dedicated helper struct containing:

- initial limit
- max limit
- shared flag
- address type
- page size

So memory equality is stricter than only comparing min/max limits.

### Tables

Tables use a helper struct containing:

- initial limit
- max limit
- address type
- heap type

Source caveat:

- this helper stores `HeapType`, not the full table element `Type`
- so the helper surface we traced does not visibly carry table nullability or exactness here

That does not by itself prove a user-visible bug, but it is a source-level nuance a future implementer should know.

## First-import-wins canonicalization

The pass keeps a map from `ImportInfo` to the first import name seen for that key.

For each later duplicate import:

- remember a replacement from the duplicate name to the first name
- add the duplicate declaration name to `importsToRemove`

So the canonical representative is:

- not a fresh synthetic import
- not an arbitrary lexicographic choice
- simply the first imported declaration encountered in module order for that identity class

A future Starshine port should preserve that deterministic choice.

## Stage 2: user retargeting via `OptUtils`

This is the real “porting danger zone.”

The detection logic is short.
The correctness risk lives in all the places that still mention the duplicate imported name.

## `replaceFunctions(...)`

Binaryen retargets:

- `Call.target`
- `RefFunc.func`
- function exports
- module start name
- module-code expression trees

So future Starshine work must not forget:

- `ref.func`
- start
- exported aliases
- module-level expression users like element payload expressions

## `replaceGlobals(...)`

Binaryen retargets:

- `GlobalGet.name`
- `GlobalSet.name`
- global exports
- module-code expression trees

So global initializer and segment-offset code paths matter too, not just ordinary function bodies.

## `replaceTables(...)`

Binaryen retargets:

- `TableGet.table`
- `TableSet.table`
- `TableSize.table`
- `TableGrow.table`
- `TableFill.table`
- `TableCopy.destTable`
- `TableCopy.sourceTable`
- `TableInit.table`
- table exports
- module-code expression trees

The practical lesson is:

- table import alias cleanup is a bulk-table rewrite problem too, not just a `table.get` rewrite problem

## `replaceMemories(...)`

Binaryen retargets:

- load/store families
- atomics
- SIMD memory ops
- `memory.size` / `memory.grow`
- `memory.init` / `memory.copy` / `memory.fill`
- array-data helpers that reference memories
- memory exports
- module-code expression trees

The practical lesson is:

- memory import alias cleanup is much wider than a simple section rename or `memory.size` rewrite

## `runOnModuleCode(...)` is intentionally narrower than “all module fields”

`runOnModuleCode(...)` explicitly walks expression trees in:

- globals
- element segments
- data segments

That is an important positive fact because it means Binaryen does not forget module-level init expressions.

But it is also an important limit:

- it is about expression trees
- not obviously about all non-expression name fields on module objects

That leads directly to the main uncertainty recorded on the identity/rewrite page.

## What the pass does **not** use

This pass is notable for what it avoids.

It does **not** use:

- `EffectAnalyzer`
- CFG or dominance reasoning
- liveness
- branch utilities
- refinalization
- nested rerun helpers
- fixpoint loops

That means a faithful port should stay simple and structural.

If a Starshine implementation starts accreting heavy dataflow machinery here, it is probably drifting away from the `version_129` source contract.

## Stage 3: import removal

After building replacement maps and applying them, the pass removes the redundant imported declarations named in `importsToRemove`.

The important practical consequence is:

- the pass completes the alias collapse immediately
- it does not leave redundant declarations around waiting for `remove-unused-module-elements`

That makes the pass a true canonicalization step for the handled import kinds.

## Shipped test coverage worth remembering

`duplicate-import-elimination.wast` is small but high-value. It demonstrates:

- positive function import merging
- direct-call rewrite
- `ref.func` rewrite
- start rewrite
- export rewrite
- positive global import merging with `global.get` / `global.set`
- positive table import merging across ordinary and bulk ops
- positive memory import merging across ordinary and bulk ops
- negative function case with different signature
- negative global case with different type
- negative table case with different type/metadata
- negative memory case with different limits/metadata

It is the cleanest source for the beginner-friendly WAT shape catalog.

## Easy-to-misunderstand points

## 1. “Duplicate” means duplicate import request, not duplicate runtime behavior proof

Binaryen is not proving semantic equivalence of two arbitrary host objects.
It is canonicalizing two imported declarations that request the same external binding according to the helper key.

## 2. The pass does not care whether a duplicate is unused

A duplicate imported alias can be very live and still be merged safely, as long as every use is retargeted.

## 3. The hardest bugs would be forgotten user edges

Examples of easy-to-forget edges:

- `ref.func`
- start
- exports
- `table.copy`
- `memory.copy`
- module-level init expressions

## 4. The tag omission is real current scope

Do not describe the current `version_129` pass as deduplicating all import kinds.
It does not.

## 5. The table-key caveat deserves an asterisk

For tables, the helper source is slightly more nuanced than “full type equality.”
That should stay documented so future work does not silently overstate the current upstream rule.

## Future Starshine port checklist

- Keep this a late module pass.
- Preserve the first-import-wins canonical choice.
- Preserve kind/module/base/type-key equality, not just module/base strings.
- Preserve the four handled kinds exactly unless deliberately expanding beyond upstream:
  - functions
  - globals
  - tables
  - memories
- Preserve the current tag omission unless deliberately documenting a divergence.
- Preserve the broad user-remap surface in `OptUtils`.
- Preserve the immediate removal of redundant imports.
- Record any explicit decision about active-segment target-name handling instead of silently assuming it is covered.
- Keep the scheduler slot before late global/string/layout cleanup.
