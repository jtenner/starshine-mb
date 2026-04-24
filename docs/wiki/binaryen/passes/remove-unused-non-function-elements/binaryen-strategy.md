---
kind: concept
status: supported
last_reviewed: 2026-04-24
sources:
  - ../../../raw/binaryen/2026-04-24-remove-unused-non-function-elements-primary-sources.md
  - ../../../raw/research/0328-2026-04-24-remove-unused-non-function-elements-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0194-2026-04-21-remove-unused-non-function-elements-binaryen-research.md
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/RemoveUnusedModuleElements.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/passes.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/remove-unused-nonfunction-module-elements_all-features.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/remove-unused-module-elements-configureAll.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/remove-unused-module-elements-refs.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/remove-unused-module-elements-tables.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/remove-unused-module-elements_tnh.wast
related:
  - ./index.md
  - ./implementation-structure-and-tests.md
  - ./shared-engine-rooting-and-defined-vs-imported-functions.md
  - ./module-shapes.md
  - ./starshine-strategy.md
  - ../remove-unused-module-elements/index.md
  - ../remove-unused-module-elements/binaryen-strategy.md
---

# Binaryen `remove-unused-nonfunction-module-elements` strategy

## Upstream source rule

Use Binaryen `version_129` as the source oracle for this pass. The 2026-04-24 immutable raw manifest is [`../../../raw/binaryen/2026-04-24-remove-unused-non-function-elements-primary-sources.md`](../../../raw/binaryen/2026-04-24-remove-unused-non-function-elements-primary-sources.md).
The core sources are:

- `src/passes/RemoveUnusedModuleElements.cpp`
- `src/passes/pass.cpp`
- `src/passes/passes.h`
- `test/passes/remove-unused-nonfunction-module-elements_all-features.wast`

Important shared-engine surfaces the pass still relies on conceptually:

- the same `Analyzer` logic as full `remove-unused-module-elements`
- the same startup-root and startup-trap rules
- the same removal and function-type cleanup stages
- the same helper-backed table / segment / heap-type reachability model

Primary source URLs:

- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/RemoveUnusedModuleElements.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/passes.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/remove-unused-nonfunction-module-elements_all-features.wast>

## The pass in one sentence

Binaryen `remove-unused-nonfunction-module-elements` is the same whole-module reachability-and-cleanup engine as `remove-unused-module-elements`, but with every **defined** function rooted before the shared cleanup runs.

## Biggest naming fact

The local Starshine registry uses:

- `remove-unused-non-function-elements`

Upstream Binaryen registers:

- `remove-unused-nonfunction-module-elements`

So there are two real naming differences:

- local splits `non-function`; upstream uses `nonfunction`
- local drops `module`; upstream keeps it

Keep that split explicit in future port and CLI docs.

## Scheduler fact

This pass is **registered publicly** in Binaryen `pass.cpp`, but it is **not scheduled** in the reviewed default no-DWARF `-O` / `-Os` pipeline and it does not appear in the saved generated-artifact `-O4z` audit.
So this dossier is a deliberate upstream-only registry expansion.

## Core idea

The source-backed teaching rule is:

- keep the ordinary RUME analyzer and ordinary RUME cleanup rules
- only change the initial root set by force-keeping all **defined** functions

That is why the pass deserves its own page even though the code delta is small.
The public contract changes materially.

## Shared engine with `remove-unused-module-elements`

`RemoveUnusedModuleElements.cpp` defines one pass type:

- `RemoveUnusedModuleElements(bool rootAllFunctions)`

The public constructors are just two modes:

| Public pass name | Constructor mode | Practical effect |
| --- | --- | --- |
| `remove-unused-module-elements` | `rootAllFunctions = false` | ordinary full RUME |
| `remove-unused-nonfunction-module-elements` | `rootAllFunctions = true` | keep all defined functions, still prune other removable module structure |

So the sibling story is exactly:

- same engine
- same analyzer
- same helpers
- one changed root policy

## Phase 0: disabled `prepare()` still means the conservative shared path

The file still calls `prepare(module);`, but `prepare()` returns immediately because the old shortcut logic is disabled in shipped `version_129`.

That means the sibling does **not** rely on a distinct or smarter prepass.
A future port should preserve the conservative shared path, not try to resurrect a speculative optimization shortcut as part of the core contract.

## Phase 1: ordinary start handling still happens first

The shared pass first checks the module start function.
If the start body is a defined `nop`, Binaryen removes the start declaration itself before adding roots.
Otherwise the start function becomes a root.

This matters for the sibling because it creates a surprising but real outcome:

- a no-op start section can disappear
- while the underlying defined function body still remains later because the sibling roots all defined functions

## Phase 2: the sibling's special step is `iterDefinedFunctions`

If `rootAllFunctions` is true, Binaryen runs:

- `ModuleUtils::iterDefinedFunctions(*module, ...)`

and roots every defined function.

This is the real public-contract difference.
It also reveals the most important boundary:

- **defined** functions are force-rooted
- imported functions are **not** force-rooted by this special step

That one distinction explains why the pass can still remove unused imported functions.

## Phase 3: all the ordinary RUME roots still apply too

After that sibling-specific step, Binaryen still adds the ordinary shared roots:

- exports
- active segments that write to imported memories or tables
- active segments that may trap during startup unless `trapsNeverHappen`
- potentially trapping element-segment initializers
- potentially trapping global initializers

So the sibling is not “functions plus a generic sweep.”
It is still a startup-semantics-aware module pass.

## Phase 4: the ordinary shared analyzer still drives meaning

The pass then constructs the shared:

- `Analyzer analyzer(module, options, roots);`

That means it still inherits the same deeper RUME ideas:

- strong use versus weaker reference-like reachability
- table/segment/index/heap-type edges
- startup-trap retention
- ordinary import/export semantics
- the shared decision to clean up function types after function reachability is settled

So the sibling should be thought of as a **mode of RUME**, not a new whole-module algorithm.

## Phase 5: function cleanup code still runs, but the rooted set changes the outcome

The shared code still calls `module->removeFunctions(...)`.
That sounds contradictory until you remember the rooted set changed.

In ordinary RUME, functions may be:

- kept
- replaced with `unreachable` when only reference-kept
- or removed entirely

In the sibling mode, every defined function is already rooted, so the practical outcome is:

- defined functions stay as real bodies
- dead defined cycles stay
- dead defined helpers stay
- the “replace dead defined function body with `unreachable`” path stops mattering for defined functions

But imported functions are outside that special root-all step, so unused imported functions can still be removed.

## Phase 6: non-function cleanup still behaves like RUME

The rest of the cleanup still uses the ordinary shared rules for:

- globals
- tags
- memories
- tables
- data segments
- element segments

So the sibling still really can:

- remove dead memories and tables
- remove dead globals or tags
- remove dead data and element segments
- preserve imported-parent segments when they are semantically observable
- preserve startup-trapping segments unless TNH changes the rules

## Phase 7: function-type cleanup still matters

Because the shared pass still cleans up the module after function reachability is known, the sibling can still shrink function types even though defined function bodies remain.

This is one of the easiest things to miss if you read only the public pass name.
The pass is still allowed to simplify **module structure around functions**.

## The most important semantic correction

Do **not** teach this pass as:

- “never change anything involving functions”

Teach it as:

- “never delete dead defined function bodies, because they are rooted up front”

That phrasing matches the source much better.

## Observed official-test output families

The dedicated upstream all-features test and local `wasm-opt version 129` runs confirm these durable points.

### Family 1: dead defined helpers stay

Dead helper chains and dead defined recursion cycles remain in the output.
That is the direct result of rooting all defined functions.

### Family 2: dead memories and tables still vanish

Modules containing only a dead memory or dead table reduce to an empty module.

### Family 3: exports still keep non-function items alive

Exported memories, tables, globals, or tags still survive.

### Family 4: active imported-parent segments still keep parents alive

Active data or element segments that write into imported parents still keep those imported parents alive.

### Family 5: dead imported functions can still vanish

The dedicated upstream test file contains an imported function pair where one import is live and the other is dead.
The dead imported function is removed.

### Family 6: dead function types still shrink away

Duplicate or unused function types disappear even though the defined functions remain.

### Family 7: dead no-op start metadata can disappear

The ordinary shared start cleanup still applies before the root-all-defined-functions step.

## Open-world versus closed-world nuance

The sibling still inherits the ordinary RUME analyzer, so the same open-world versus closed-world model still exists underneath the pass.
But because defined functions are force-rooted, many of the most visible function-dropping differences become less central than in full RUME.

A beginner-safe summary is:

- world-mode reasoning is still shared
- the sibling does not replace it
- the sibling simply overrides a large slice of ordinary defined-function deletion by rooting those functions up front

## Positive families to preserve in a future port

A faithful port must preserve these visible successes:

- dead defined helper chains survive
- dead defined cycles survive
- dead non-function declarations disappear when truly unused
- dead imported functions may still disappear
- duplicate or unused function types still compact away
- startup-visible segments still keep parents alive

## Negative / preserved families to preserve in a future port

A faithful port must also preserve these non-rewrites:

- exported non-function declarations stay
- active imported-parent segments stay when visible
- startup-trapping segments stay unless TNH says otherwise
- imported functions do not get special sibling protection just because they are functions

## Starshine mapping

Current Starshine keeps the local spelling `remove-unused-non-function-elements` as a boundary-only registry name, not an active module pass. Use [`./starshine-strategy.md`](./starshine-strategy.md) for exact local code locations and the future landing-zone map.

## What a future Starshine port must preserve

If Starshine ever implements this sibling honestly, preserve all of these rules together:

1. use the same shared RUME-style module analyzer, not a new simplified sweep
2. root all **defined** functions, not all functions
3. keep the no-op start cleanup behavior before or alongside the rooting rule
4. keep shared startup trap retention and active imported-parent retention
5. keep imported functions removable when dead
6. keep function-type cleanup active
7. keep the local-vs-upstream naming split explicit
8. keep the pass out of the default no-DWARF optimize-path documentation unless that upstream fact changes

## Easy mistakes to avoid

### Mistake 1: “This is just a spelling alias for full RUME.”

Wrong.
The shared engine is the same, but the root policy changes the visible contract.

### Mistake 2: “It preserves every function declaration.”

Wrong.
It preserves all **defined** functions, not necessarily imported ones.

### Mistake 3: “Because functions are force-kept, type cleanup stops mattering.”

Wrong.
Function types can still shrink.

### Mistake 4: “The pass name is precise enough on its own.”

Wrong.
The real distinction between defined and imported functions is easy to miss unless the docs say it explicitly.

## Bottom line

The best durable teaching sentence is:

- `remove-unused-nonfunction-module-elements` is **RUME with defined functions rooted up front**.

That one line preserves the real Binaryen strategy much better than the public name alone.
