# Binaryen `remove-unused-names` current-main recheck

_Capture date:_ 2026-07-11  
_Status:_ immutable primary-source freshness manifest for `docs/wiki/binaryen/passes/remove-unused-names/`

## Scope

This narrow reread refreshes the active `remove-unused-names` dossier against Binaryen `version_130` and current `main`. The older April 2026 research notes remain useful historical provenance, but they are not a substitute for a committed current primary-source manifest.

The review checks the owner, public registration/default scheduling, generic scope-target helpers, caller-delegate sentinel, and dedicated before/after fixture. It does **not** claim that every neighboring cleanup-combination fixture or every upstream commit was exhaustively audited.

## Primary sources reread

### Upstream Binaryen `version_130` and `main`

- Owner:
  - <https://github.com/WebAssembly/binaryen/blob/version_130/src/passes/RemoveUnusedNames.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/main/src/passes/RemoveUnusedNames.cpp>
- Public registration and default function scheduler:
  - <https://github.com/WebAssembly/binaryen/blob/version_130/src/passes/pass.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
- Generic scope-name use and retarget helpers:
  - <https://github.com/WebAssembly/binaryen/blob/main/src/ir/branch-utils.h>
- Caller-delegate sentinel declaration:
  - <https://github.com/WebAssembly/binaryen/blob/main/src/shared-constants.h>
- Dedicated fixture and expected output:
  - <https://github.com/WebAssembly/binaryen/blob/version_130/test/passes/remove-unused-names.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_130/test/passes/remove-unused-names.txt>
  - <https://github.com/WebAssembly/binaryen/blob/main/test/passes/remove-unused-names.wast>
  - <https://github.com/WebAssembly/binaryen/blob/main/test/passes/remove-unused-names.txt>

### Current Starshine evidence

- Active pass and focused tests: `src/passes/remove_unused_names.mbt`, `src/passes/remove_unused_names_test.mbt`
- Registry/preset repetition: `src/passes/optimize.mbt`, `src/passes/registry_test.mbt`
- Compare-harness admission: `scripts/lib/pass-fuzz-compare-task.ts`

## Current upstream result

The reviewed `RemoveUnusedNames.cpp` source is unchanged between `version_130` and current `main` on the pass's core contract:

- it is a function-parallel postwalk;
- it keeps `requiresNonNullableLocalFixups() == false`;
- `branchesSeen` maps each used scope name to the exact expression users;
- `visitExpression(...)` records generic scope-name uses through `BranchUtils::operateOnScopeNameUses(...)`;
- `handleBreakTarget(...)` clears an unused label or retires bookkeeping for a used label;
- same-typed, one-child named blocks are merged after `BranchUtils::replacePossibleTarget(...)` retargets parent users to the child label;
- a loop becomes its body only after its label is dead and the body type equals the loop type;
- `visitTry(...)` re-visits the expression to include its delegate target; and
- function exit removes `DELEGATE_CALLER_TARGET` before asserting no other unresolved scope-name users remain.

The helper boundary remains equally important. Current `branch-utils.h` implements `replacePossibleTarget(...)` by invoking the generic `operateOnScopeNameUses(...)` mechanism, so the owner does not hard-code only plain `br` handling. Current `shared-constants.h` still declares `DELEGATE_CALLER_TARGET` as the special caller-delegation pseudo-target.

`pass.cpp` still registers `remove-unused-names` with the public description “removes names from locations that are never branched to.” Its no-DWARF function pipeline still runs the pass immediately after `dce`, again after the first `remove-unused-brs`, and a final time after the late `merge-blocks -> remove-unused-brs` cleanup sequence. The third occurrence retains the source comment that `remove-unused-brs` opens opportunities.

The dedicated fixture and expected output are also unchanged between `version_130` and current `main`. They still prove the core families: dead outer-label removal, loop non-demotion when type information requires the wrapper, same-type named block merging, and retargeting for both `br` and `br_table`.

## Starshine reconciliation

Starshine still exposes `remove-unused-names` as an active hot pass and admits it to the compare-pass allowlist. Its current direct implementation is intentionally narrower than Binaryen's generic name-to-user map:

- it uses a HOT label-use bitset rather than `branchesSeen` expression sets;
- it performs safe same-typed block-chain peeling with target retagging and dead-label loop demotion;
- it does not implement generic label clearing for structurally retained named scopes or Binaryen's caller-delegate sentinel model.

This is a current local representation/coverage boundary, not a claim that the two algorithms are automatically equivalent. The focused MoonBit tests cover the implemented branch, `br_if`, `br_table`, `try_table`, delegate-label-use, loop, and name-section metadata behavior; the Binaryen fixture remains the upstream contract evidence.

## Consumability rule

Use this capture for the `version_130` / current-main owner-and-fixture freshness claim. Use the older research notes for historical source-reading provenance and the living dossier for the current beginner-to-advanced explanation.

Do not infer from this narrow reread that every cleanup-combination fixture is byte-identical or that Starshine implements all general Binaryen label clearing. Those questions require their own source or parity evidence.
