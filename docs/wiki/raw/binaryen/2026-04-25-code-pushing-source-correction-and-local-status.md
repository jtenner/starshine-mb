# Binaryen `code-pushing` source correction and Starshine status capture

_Capture date:_ 2026-04-25  
_Status:_ immutable corrective source manifest for `docs/wiki/binaryen/passes/code-pushing/`

## Scope

This capture supersedes the teaching interpretation in the older 2026-04-22 `code-pushing` raw manifest and research note where they described `BranchSeeker`, `Pusher`, generic target segments, and local `benefit > cost` profitability as if they existed in the reviewed `version_129` implementation.

The official sources rechecked in this run show a smaller and different pass:

- `code-pushing` rewrites block-local expression roots around a following `if`.
- The core generic mechanism is `tryPush` plus `canPushThrough`, not a `BranchSeeker` / `Pusher` / profitability engine.
- The key special case is an `if` whose one arm is unreachable, where the pass may push earlier expressions into the reachable arm when execution is preserved.
- A `canPushThrough` safety check determines whether an expression may move across later siblings.
- Current Starshine now has an active HOT subset in `src/passes/code_pushing.mbt`, so older “no transform yet” wording is stale.

Use the living dossier pages for interpretation:

- `docs/wiki/binaryen/passes/code-pushing/index.md`
- `docs/wiki/binaryen/passes/code-pushing/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/code-pushing/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/code-pushing/segment-selection-and-barriers.md`
- `docs/wiki/binaryen/passes/code-pushing/wat-shapes.md`
- `docs/wiki/binaryen/passes/code-pushing/starshine-strategy.md`

## Primary sources rechecked

### Official Binaryen release and current source

- Binaryen GitHub release `version_129`
  - URL: <https://github.com/WebAssembly/binaryen/releases/tag/version_129>
  - Previously observed on 2026-04-22 as the reviewed release anchor for this dossier.
- `CodePushing.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/CodePushing.cpp>
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/CodePushing.cpp>
- `pass.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
- `opt-utils.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/opt-utils.h>
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/opt-utils.h>

### Official Binaryen tests

- `code-pushing.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/code-pushing.wast>
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/code-pushing.wast>
- `code-pushing_into_if.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/code-pushing_into_if.wast>
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/code-pushing_into_if.wast>
- `code-pushing_ignore-implicit-traps.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/code-pushing_ignore-implicit-traps.wast>
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/code-pushing_ignore-implicit-traps.wast>
- `code-pushing_tnh.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/code-pushing_tnh.wast>
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/code-pushing_tnh.wast>
- `code-pushing-gc.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/code-pushing-gc.wast>
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/code-pushing-gc.wast>
- `code-pushing-eh.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/code-pushing-eh.wast>
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/code-pushing-eh.wast>

## Source locations that matter

- `CodePushing::visitBlock(...)` owns the main block walk and asks `optimizeIntoIf(...)` first, then tries to push earlier siblings across the current expression.
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/CodePushing.cpp#L66-L87>
- `CodePushing::optimizeIntoIf(...)` owns the one-arm-unreachable `if` sinking family.
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/CodePushing.cpp#L91-L233>
- The `skipTo` / `limit` logic is the source-backed reason this path preserves execution by pushing only the expressions between the preceding fallthrough separator and the `if`.
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/CodePushing.cpp#L122-L136>
- `CodePushing::canPushThrough(...)` is the safety predicate for moving one expression across another.
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/CodePushing.cpp#L239-L315>
- `CodePushing::tryPush(...)` performs the generic sibling-local one-expression motion by moving an expression directly before a later use.
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/CodePushing.cpp#L340-L395>
- The pass declares itself function-parallel and requires expression refs in the same source file.
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/CodePushing.cpp#L23-L46>

## Corrected durable observations

- The reviewed `version_129` source does **not** contain pass-local helpers named `BranchSeeker` or `Pusher`.
- The reviewed `version_129` source does **not** implement a documented local `benefit > cost` profitability gate in `CodePushing.cpp`.
- The reviewed `version_129` source does **not** teach a general “duplicate pure expressions into both reachable `if` arms” family. The dedicated `optimizeIntoIf(...)` path is specifically about the one-unreachable-arm case plus preservation of execution.
- `canPushThrough(...)` is the central movement-safety gate. It allows or rejects movement based on expression effects, values, traps-never-happen / ignore-implicit-traps options, `if`-condition special cases, `call_without_effects`, function references, `ref.func` use, `ref.as_non_null`, cast exactness, and nested traversal.
- The normal generic move is a local sibling-root move before a later use, not arbitrary CFG segment sinking.
- The official tests still prove broad enough behavior to require caution: ordinary positives, `into_if`, option-sensitive trap families, GC, and EH examples remain the right test roster. The living pages now avoid attributing unobserved helpers or heuristics to those tests.
- Current `main` was spot-checked against `version_129` for the same files in this run. No teaching-relevant drift was found for the corrected points above; the correction is an interpretation/source-reading fix, not a newly introduced upstream algorithm change.

## Starshine status source locations

- Active HOT pass registration and preset omission live in `src/passes/optimize.mbt`.
- The current local implementation lives in `src/passes/code_pushing.mbt`.
- Focused HOT tests live in `src/passes/code_pushing_test.mbt`.
- Registry classification coverage lives in `src/passes/registry_test.mbt`.
- Command/native adapter coverage lives in `src/cmd/cmd_wbtest.mbt`.
- The remaining broader parity work is tracked in `agent-todo.md` under the `CP` slice.

## Supersession note

This manifest supersedes the following teaching claims where they appear in older `code-pushing` wiki material:

- `BranchSeeker` / `Pusher` as the core upstream implementation structure.
- local `benefit > cost` profitability as a reviewed `CodePushing.cpp` contract.
- two-live-arm `if` duplication as a source-backed Binaryen `code-pushing` shape.
- “no transform yet” as the current Starshine status.

The older raw manifest remains in the repository as historical provenance. Prefer this 2026-04-25 capture plus the refreshed living pages for current teaching and port planning.
