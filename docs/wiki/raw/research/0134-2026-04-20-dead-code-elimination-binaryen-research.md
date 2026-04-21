# 0134 - `dead-code-elimination` Binaryen research

## Status

- Date: 2026-04-20
- Type: One-off raw investigation
- Scope: deepen the currently shallow `dead-code-elimination` pass docs using official Binaryen `version_129` sources, shipped tests, the repo's canonical no-DWARF scheduler note, the updated pass tracker, the active `DCE` backlog slices in `agent-todo.md`, the current Starshine HOT implementation and tests, the saved generated-artifact `-O4z` audit, and a narrow current-`main` freshness check.

## Why this pass

- `docs/wiki/binaryen/passes/tracker.md` now names `dead-code-elimination` as the top suggested next implemented landing-page target after the `heap-store-optimization` dossier landed.
- The pass is already **implemented** in Starshine, but it only had a landing page.
- It sits in a strategically important place:
  - in the canonical no-DWARF `-O` / `-Os` function pipeline it is the **first** cleanup pass after `ssa-nomerge`
  - in the saved generated-artifact `-O4z` audit it appears at top-level Binaryen slot `12`
  - the saved Binaryen debug log shows `18` total `dce` executions in the full run, so nested reruns matter too
- The public name is misleading in two different ways.
  - Binaryen's short `pass.cpp` description sounds like pure unreachable-code cleanup.
  - Local Starshine discussions sometimes use “DCE” as a catch-all name for dead-result simplification, unreachable-tail trimming, or even later writeback hardening.
  - The actual Binaryen `version_129` pass is more specific: it does child-first unreachable cleanup, unused-result pruning driven by effect analysis, block simplification, dead typed-control voidification, and then type / EH repair.
- `agent-todo.md` already has dedicated DCE work:
  - `[DCE]001 - Binaryen-Shape Cleanup Hardening`
  - `[DCE]002 - Prefix Regression and Artifact Replay`
  - `[DCE]003 - Runtime Budget and Oracle Refresh`
- The tracker hint was right to prioritize this dossier now.
  - DCE is already implemented and artifact-backed.
  - It is one of the most important passes for understanding the whole early post-SSA cleanup neighborhood.
  - It interacts directly with `remove-unused-names`, `remove-unused-brs`, `vacuum`, and the nested `optimizeAfterInlining` rerun helper.

## Local source material

### Repo scheduler / backlog / audit sources

- `docs/README.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
- `docs/wiki/binaryen/passes/dead-code-elimination/index.md`
- `docs/wiki/raw/research/0093-2026-04-18-generated-o4z-pass-audit-summary.md`
- `.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/summary.json`
- `.artifacts/o4z-wasm-opt-debug.log`
- `agent-todo.md`
- `src/passes/optimize.mbt`
- `src/passes/registry_test.mbt`

### Local Starshine implementation files

- `src/passes/dead_code_elimination.mbt`
  - current summary: `Prune unreachable tails, dead dropped values, and dead-result structured control in hot IR regions.`
  - actual current shape: a large HOT-region pass with caches for branch users, node uses, purity, and fallthrough; dead-root pruning; control-result voidification; explicit-`unreachable` tail insertion; detached-subtree deletion; and several artifact-driven branch-payload / split-wrapper repairs that go beyond upstream Binaryen's AST implementation shape
- `src/passes/dead_code_elimination_test.mbt`
  - extensive reduced coverage for pure-drop preservation, unreachable tails, dead typed `if` / `block` / `loop` wrappers, payload-forwarder rewrites, explicit-`unreachable` preservation, label-owner safety, and detached-shared-subtree cleanup
- `src/passes/dead_code_elimination_live_repro_test.mbt`
  - exact reduced reproductions for the inner carrier and typed loop-input families that matter to real lowering safety
- `src/passes/perf_test.mbt`
  - explicit raw-skip coverage for “no DCE candidates” functions and explicit non-skip coverage for real dead-drop and nonfallthrough typed-control families
- `src/cmd/cmd_wbtest.mbt`
  - debug-artifact CLI replay coverage for `--dead-code-elimination`, plus the remaining native-default-I/O blocker note

## Official Binaryen `version_129` sources

### Main implementation and scheduler

- `src/passes/DeadCodeElimination.cpp`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/DeadCodeElimination.cpp>
  - especially relevant pieces from a direct read:
    - `BranchSeeker` and `UnneededBlockSeeker`
    - `canRemove(...)`
    - `optimizeExpression(...)`
    - `visitDrop(...)`
    - `visitBlock(...)`
    - `visitFunction(...)`
- `src/passes/pass.cpp`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - public registration under `dce`
  - default function pipeline placement right after `ssa-nomerge`
- `src/passes/opt-utils.h`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/opt-utils.h>
  - important because the shared `optimizeAfterInlining` rerun helper includes `dce` in the nested cleanup sequence on changed functions

### Helper headers the pass directly depends on

- `src/ir/effects.h`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/effects.h>
  - reviewed for `EffectAnalyzer`, `hasSideEffects`, `branchesOut`, `conditionallyBranchesOut`, and the general “removable if unused” effect model that powers DCE's `canRemove(...)`
- `src/ir/type-updating.h`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/type-updating.h>
  - reviewed for `TypeUpdater::handleNonDefaultableLocals(...)`, which repairs local types after DCE removes result traffic
- `src/ir/eh-utils.h`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/eh-utils.h>
  - reviewed because `visitFunction(...)` explicitly repairs nested EH pops after DCE simplification
- `src/ir/properties.h`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/properties.h>
  - reviewed for `Properties::isControlFlowStructure(...)`, which is part of the “voidify instead of blindly delete” split
- `src/ir/flatten.h`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/flatten.h>
  - reviewed because DCE finishes with `Flatten::flatten(...)` before refinalization

### Shipped test surface reviewed for this note

Binaryen `version_129` does not have just one tiny `dce.wast` file.
The dedicated pass surface is spread across multiple files:

- `test/lit/passes/dce_all-features.wast`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/dce_all-features.wast>
- `test/lit/passes/dce_vacuum_remove-unused-names.wast`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/dce_vacuum_remove-unused-names.wast>
- `test/lit/passes/dce-eh.wast`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/dce-eh.wast>
- `test/lit/passes/dce-eh-legacy.wast`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/dce-eh-legacy.wast>
- `test/lit/passes/dce-stack-switching.wast`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/dce-stack-switching.wast>

Representative test names and families I checked directly:

- `code-to-kill`
  - dead code after `return` and `unreachable`
- `blocks-can-become-dead`
  - blocks whose results are only immediately dropped
- `side-effects`
  - DCE must keep effectful work in order while deleting dead pure values
- `kept-in-order`
  - DCE must not reorder side effects while simplifying unused results
- `dce_vacuum_remove-unused-names.wast`
  - proves the intended pass interaction: DCE can expose structural/name residue that `vacuum` and `remove-unused-names` clean up later
- `dce-eh*.wast`
  - exception-handling families with dead `catch`, `rethrow`, `delegate`, and typed EH wrappers
- `dce-stack-switching.wast`
  - stack-switching shapes that confirm DCE's effect/type repairs are not only MVP-era control-flow cleanup

## Freshness check

I did a narrow direct `version_129` vs current-`main` check for the owning source file and the dedicated test surface.

### What I checked directly

- current `main` `src/passes/DeadCodeElimination.cpp`
  - <https://github.com/WebAssembly/binaryen/blob/main/src/passes/DeadCodeElimination.cpp>
- current `main` `test/lit/passes/`
  - <https://github.com/WebAssembly/binaryen/tree/main/test/lit/passes>

### Result

The narrow check did **not** reveal an obvious post-`version_129` contract drift.
What I directly re-confirmed on `main`:

- the same `BranchSeeker` / `UnneededBlockSeeker` helper structure is still present
- the same `DCE` pass shell and `visitDrop(...)` / `visitBlock(...)` / `visitFunction(...)` shape are still present
- the same dedicated `dce_all-features`, `dce_vacuum_remove-unused-names`, `dce-eh*`, and `dce-stack-switching` test files are still present

So the honest freshness note is:

- I did **not** prove byte-for-byte identity for the entire file the way the `heap-store-optimization` note did
- but I also did **not** find an obvious newer drift story that would make `version_129` a weak oracle for DCE on `2026-04-20`

## Fast answer

Binaryen `dead-code-elimination` is **not** just:

- “delete instructions after `return`”

And it is also **not**:

- a full dataflow dead-store or dead-load pass

A better beginner summary is:

- recursively simplify children first
- remove code after non-fallthrough points
- erase unused pure values
- keep side effects in place when dead values are dropped
- turn dead typed control wrappers into **void** control instead of tearing them down unsafely
- then repair local types, EH nested pops, and nested blocks so the function stays valid

So the real contract is:

- **unreachable-suffix cleanup plus unused-result structural repair**

not:

- “generic dead-code analysis across the whole function.”

## Public name and scheduler placement

## Registered public surface

`pass.cpp` registers:

- `dce`
  - description: `removes unreachable code`

That short description is incomplete.
The pass clearly also handles:

- dead unused values under `drop`
- typed `block` / `if` / `loop` / `try` / `try_table` wrappers whose result is no longer needed
- post-rewrite type and EH repair

So the repo should keep treating `dead-code-elimination` as the stable living-page name, but it should also keep documenting that upstream Binaryen's short description understates the pass.

## Canonical no-DWARF placement

In the default no-DWARF function optimizer, `dce` runs immediately after `ssa-nomerge`:

- `ssa-nomerge -> dce -> remove-unused-names -> remove-unused-brs -> ...`

That placement matters.
DCE is the first cleanup pass that gets to exploit the newly simplified SSA-ish local traffic, and it is expected to expose more cleanup for:

- `remove-unused-names`
- `remove-unused-brs`
- later `vacuum`

## Saved generated-artifact `-O4z` evidence

The saved ordered generated-artifact audit saw one top-level DCE slot:

- Binaryen slot `12`: `dce`

The saved summary for that step is important and a little subtle:

- `normalizedWatEqual = true`
- `canonicalFuncPrettyEqual = true`
- `wasmEqual = false`
- `starshinePassSkippedRaw = true`
- Starshine wall time `8154.268 ms` vs Binaryen `281.126 ms`
- Starshine pass time `4330.418 ms` vs Binaryen `77.488 ms`

So the durable reading is:

- the current Starshine DCE slot matches Binaryen at the normalized / canonical function level on the saved artifact
- but the local implementation reached that slot outcome through the raw-skip path there
- and performance is still dramatically worse than Binaryen even on a successful top-level audit step

The saved aggregate audit summary also calls DCE out explicitly in the expensive-but-successful cluster:

- `29.01x` wall ratio
- `55.89x` pass ratio

The saved Binaryen debug log contains `18` total `running pass: dce` lines, which means:

- nested reruns matter for understanding real Binaryen behavior here
- the top-level slot is only the visible beginning of the story

## What Binaryen DCE actually does

## The biggest beginner correction

The easy wrong mental model is:

- DCE is a generic pass that somehow knows all dead work everywhere

The safer mental model is:

- DCE is a **tree and structure cleanup** pass driven by local effect reasoning and branch-target awareness
- it removes dead pure values and unreachable suffixes eagerly
- but when typed control is involved it often **changes the structure's type to void** instead of deleting the whole node
- then it runs repair helpers because the result traffic and EH shape may have changed

That is a much more accurate picture of the real Binaryen source.

## Core implementation structure

### 1. `BranchSeeker` and `UnneededBlockSeeker` decide which blocks are safe to simplify

The file starts with two small helper walkers.

`BranchSeeker` answers:

- does any nested branch target this specific block?

`UnneededBlockSeeker` then uses that to find blocks whose labels are not needed.

This is a very important safety gate.
Binaryen does **not** erase or flatten blocks just because their tail value looks dead.
A block with a live branch target is structurally different from one that is only serving as a sequence wrapper.

### 2. `canRemove(...)` is effect-based, not syntax-based

The next big helper is `canRemove(Expression*)`.
It uses `EffectAnalyzer` with the current pass options and module context.

The key rule is simple but powerful:

- if an expression is removable when unused, DCE may erase it
- if not, DCE must preserve its side effects somehow

That is why:

- `drop (i32.add ...)` may disappear entirely
- `drop (call $impure ...)` cannot just disappear
- `drop (block (result i32) (call $x) (i32.const 1))` may simplify to “just the call side effect” rather than vanish wholesale

### 3. `optimizeExpression(...)` is child-first and removes unreachable suffixes immediately

This helper recursively optimizes children before the parent.
Then it scans the children in order and, once it finds a child that cannot fall through, it clears the remaining siblings.

That means the pass does not wait for a separate whole-function sweep to kill dead tails.
It does this locally while walking.

This is the direct source reason DCE handles families like:

- `return` followed by dead work
- `throw` / `delegate` / `rethrow` followed by dead work
- nested children that become non-fallthrough after recursive simplification

### 4. `visitDrop(...)` is where unused-result cleanup becomes real structure editing

`visitDrop(...)` is the most revealing function in the file.
It does much more than “remove `drop` if the child is pure.”

Its behavior splits roughly like this:

- if the dropped child is fully removable, remove the whole `drop`
- otherwise, recursively optimize the child
- if the child is now an impossible / dead-value shape that can simplify to contents, do that
- if the child is a control-flow structure whose result is dead, **voidify it** instead of deleting it blindly
- if a non-fallthrough structure now ends the function, ensure the function still has an explicit `unreachable` tail when needed

That is the heart of the pass's “sounds simpler than it is” story.

### 5. `visitBlock(...)` is conservative about live labels and live internal side effects

DCE does not flatten every block whose final value is unused.
`visitBlock(...)` first asks whether the block label is actually unneeded.
Then it checks whether intermediate children have side effects.

The source behavior boils down to:

- if the block label is still targeted, keep it
- if the block is just sequencing removable work before a final value, it may simplify aggressively
- if earlier children have side effects, keep those side effects in order
- if only the final value is dead, reduce the block to the useful contents rather than pretending the whole block never mattered

This explains why some “result block under drop” shapes vanish and others survive as void sequencing blocks.

### 6. `visitFunction(...)` finishes with repair, not just deletion

The function-level cleanup is one of the most important pieces to teach clearly.
After the local rewrites, Binaryen still runs:

- `TypeUpdater::handleNonDefaultableLocals(function)`
- `EHUtils::handleBlockNestedPops(function, getPassOptions())`
- `Flatten::flatten(function->body, wasm)`
- `ReFinalize().walkFunctionInModule(function, getModule())`

That means DCE's real contract includes:

- local type repair after result traffic disappears
- EH nested-pop repair after structural rewrites
- flattening away some newly nested blocks
- final refinalization so all expression types are consistent again

This is why DCE should be described as a **cleanup plus repair** pass, not just a deletion pass.

## Important helper dependencies and what they mean

### `EffectAnalyzer`

This is the main semantic safety oracle for unused-result cleanup.
DCE relies on it to answer questions like:

- is this expression removable if nobody uses its result?
- does this subtree still have side effects that must remain in order?
- does this child branch out or only conditionally branch out?

If a future Starshine port or refactor gets the effect model wrong, DCE will silently cross the line from “dead value pruning” into “wrongly deleting behavior.”

### `Properties::isControlFlowStructure(...)`

This helper matters because value-producing control structures are the hardest unused-result case.
DCE often cannot replace them with a single child the way it can for simpler expressions.
It must instead:

- preserve the control skeleton
- change the result type to void
- and then repair the surrounding type state

### `TypeUpdater::handleNonDefaultableLocals(...)`

This helper is easy to miss.
When DCE removes value traffic, some locals may stop carrying a previously needed nondefaultable type.
Binaryen fixes that explicitly instead of assuming the old types are still fine.

### `EHUtils::handleBlockNestedPops(...)`

DCE's control simplification can expose or invalidate nested exception-pop structure.
Binaryen repairs that at function end instead of pretending ordinary control cleanup is enough for EH.

### `Flatten::flatten(...)` and `ReFinalize`

These two are the practical cleanup tail.
DCE often creates simpler but still structurally nested content.
Flatten removes some of the newly pointless nesting, and refinalization re-computes consistent types afterward.

## What the pass rewrites versus what it does not

## Positive families

The direct source plus test-driven positive surface includes:

- unreachable suffix removal after non-fallthrough children
- dead pure value removal
- dead `drop` cleanup while preserving side effects in order
- dead result `block` simplification when the label is not needed
- dead typed `if` / `loop` / `try` / `try_table` voidification
- block simplification that keeps only the still-observable contents
- some impossible-condition cleanup when child simplification proves a branch cannot produce a useful value

## Negative or deliberately preserved families

The same sources make several non-goals explicit.
DCE is **not** trying to be:

- a whole-function local liveness optimizer
- a load/store dead-store elimination pass
- a global dead-write pass
- a branch-target retargeting pass in the style of `remove-unused-brs`
- a final name / label cleanup pass
- a final `nop` / empty-wrapper janitor pass

That is why nearby passes still matter:

- `remove-unused-names`
- `remove-unused-brs`
- `vacuum`

## Important pass interactions

### `remove-unused-names` and `vacuum` are part of the real cleanup story

The dedicated Binaryen test file `dce_vacuum_remove-unused-names.wast` is strong evidence that upstream expects cooperation here.
The run line intentionally chains:

- `--dce`
- `--vacuum`
- `--remove-unused-names`

That is not accidental.
DCE deliberately leaves some residue that later structural cleanup and label pruning are meant to erase.

### `remove-unused-brs` follows immediately for a reason

In the default function pipeline, DCE is immediately followed by name and branch cleanup.
That ordering makes sense after reading the source:

- DCE can voidify or simplify typed control wrappers
- that can expose stale labels or branch structure
- then `remove-unused-brs` can do the targeted branch-level cleanup that DCE is not trying to own

### Nested optimizing reruns matter

`opt-utils.h` makes the nested rerun story explicit.
When optimizing passes like `dae-optimizing` or `inlining-optimizing` change a function, Binaryen reruns the function optimizer helper that starts with:

- `precompute-propagate`
- then `dce`
- then the same familiar cleanup neighborhood

So future Starshine parity work must remember:

- a correct top-level DCE slot is necessary but not sufficient
- the nested cleanup helper is part of the real Binaryen contract too

## Shipped-test-backed WAT shape lessons

The official tests repeatedly reinforce these beginner-important lessons:

- dead work after `return` is the easy case, not the whole pass
- dropped pure arithmetic or constants can vanish completely
- effectful calls must stay in order even if their result dies
- dead typed blocks can become simple sequencing blocks
- named or branch-targeted wrappers often survive until later cleanup passes
- EH and stack-switching families require structural repair, not just dead-value deletion

## Current Starshine state relative to upstream Binaryen

## What Starshine already models well

The current local implementation clearly tries to preserve the same big semantic ideas:

- unreachable-tail pruning
- dropped pure-value cleanup
- dead-result control voidification
- explicit `unreachable` tail insertion when needed
- careful branch-target accounting

It also has a much wider reduced regression corpus than the upstream shipped tests for the specific HOT-lowering families that have mattered on the checked-in artifact.

## Where the local implementation shape differs

Starshine's `dead_code_elimination.mbt` is **not** a line-by-line port of `DeadCodeElimination.cpp`.
The local file is much larger because HOT IR introduces additional survival problems that upstream AST Binaryen does not need to solve the same way.

Especially local-only or local-heavy themes include:

- cached branch-user maps and fallthrough maps over HOT regions
- purity caching and detached-subtree deletion
- branch-payload forwarder rewrites
- split `local.set` wrapper rewrites
- explicit writeback-valid `unreachable` materialization rules
- raw-skip heuristics in `pass_manager.mbt` when the function obviously has no DCE candidates

Those are important local implementation facts.
But they are **not** the same thing as the upstream Binaryen DCE contract.

## Honest current local parity state

The saved top-level generated-artifact audit is encouraging but only partially so:

- canonical and normalized-WAT equality were green on the top-level slot
- raw wasm equality was still false
- Starshine reached that slot through raw skip
- performance remained far behind Binaryen

`agent-todo.md` also keeps the open work honest:

- source-mode artifact replay and pass-fuzz evidence are now much healthier
- the remaining frontier is runtime budget, valid-baseline replay proof, and the native-release lowering divergence families rather than a newly isolated pass-local semantic mismatch in the reduced source-mode path

## What a future Starshine port or refactor must preserve

A future port must keep these Binaryen-backed invariants explicit:

- DCE is not generic dataflow dead-store elimination
- effect-order preservation is the core safety rule for unused-result pruning
- branch-targeted blocks are not simplifiable in the same way as plain sequencing blocks
- dead typed control often needs **voidification plus repair**, not blind deletion
- explicit `unreachable` tails can be required after non-fallthrough simplification
- type repair and EH nested-pop repair are part of the pass contract
- later cleanup passes are expected to erase some residue that DCE intentionally leaves behind

## Open questions and uncertainty

- The narrow freshness check did not show obvious post-`version_129` drift, but I did not prove whole-file identity against `main`.
- Binaryen's child-level impossible-condition cleanup is subtle in `optimizeExpression(...)`; the durable beginner-facing story should emphasize the broad rule (“simplify dead children and turn impossible dead-result shapes into simpler forms”) without pretending every exact `ifFalse(...)` or `canTurnToUnreachable(...)` branch has already been exhaustively re-derived here.
- The local Starshine implementation contains artifact-driven HOT-specific repairs whose names sound DCE-like but do not necessarily correspond to upstream AST-level algorithms one-for-one. The living pages should keep that distinction explicit.

## Durable conclusions to file into the living wiki

1. Binaryen `dce` is more than unreachable-tail deletion and less than general dataflow dead-code analysis.
2. The pass's real center of gravity is **unused-result structural cleanup** driven by effect analysis.
3. The non-obvious half of the implementation is dead typed-control **voidification** plus later type / EH / flatten / refinalize repair.
4. The official test surface explicitly treats `vacuum` and `remove-unused-names` as part of the cleanup story, so pass-order documentation must keep those interactions visible.
5. Starshine's current implementation has the right broad goal, but its HOT-IR machinery and raw-skip heuristics are local execution details, not the semantic definition of Binaryen DCE.

## Sources

### Repo sources

- `docs/README.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
- `docs/wiki/raw/research/0093-2026-04-18-generated-o4z-pass-audit-summary.md`
- `.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/summary.json`
- `.artifacts/o4z-wasm-opt-debug.log`
- `agent-todo.md`
- `src/passes/dead_code_elimination.mbt`
- `src/passes/dead_code_elimination_test.mbt`
- `src/passes/dead_code_elimination_live_repro_test.mbt`
- `src/passes/perf_test.mbt`
- `src/cmd/cmd_wbtest.mbt`

### Official Binaryen sources

- `DeadCodeElimination.cpp`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/DeadCodeElimination.cpp>
- `pass.cpp`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- `opt-utils.h`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/opt-utils.h>
- `effects.h`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/effects.h>
- `type-updating.h`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/type-updating.h>
- `eh-utils.h`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/eh-utils.h>
- `properties.h`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/properties.h>
- `flatten.h`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/flatten.h>
- `dce_all-features.wast`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/dce_all-features.wast>
- `dce_vacuum_remove-unused-names.wast`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/dce_vacuum_remove-unused-names.wast>
- `dce-eh.wast`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/dce-eh.wast>
- `dce-eh-legacy.wast`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/dce-eh-legacy.wast>
- `dce-stack-switching.wast`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/dce-stack-switching.wast>
- narrow freshness-check surfaces on `main`
  - <https://github.com/WebAssembly/binaryen/blob/main/src/passes/DeadCodeElimination.cpp>
  - <https://github.com/WebAssembly/binaryen/tree/main/test/lit/passes>
