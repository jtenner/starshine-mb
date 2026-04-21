# 0230 - `dead-argument-elimination` implementation-structure follow-up

- Date: 2026-04-21
- Scope: close the remaining major wiki gap in the existing `dead-argument-elimination` dossier by adding the missing source-confirmed implementation/test-map page and tightening the owner/test split against neighboring `dae-optimizing` and `dae2` material.
- Chosen pass: `dead-argument-elimination`.
- Upstream public CLI alias: `dae`.
- Local Starshine registry name: `dead-argument-elimination` in `src/passes/optimize.mbt`.
- Current registry status: boundary-only.
- `agent-todo.md` status: there is still **no dedicated `dead-argument-elimination` slice** in the current backlog.

## Why this follow-up was the right gap to close

The existing `dead-argument-elimination` folder was already a real dossier, but it still had one obvious practical gap:

- the landing page already linked to `implementation-structure-and-tests.md`,
- but that page did not exist yet,
- and readers still had to reconstruct the real owner/test split from the broader strategy note.

That made the folder easy to misread in three ways:

1. as if plain `dae` had its own standalone source file that was separate from `dae-optimizing`;
2. as if the official proof surface lived in one dedicated `dae.wast` file;
3. as if neighboring `dae-optimizing.wast` and `dae2.wast` were interchangeable evidence for the plain pass.

So this follow-up is not a random polish pass. It closes a concrete missing-page and owner/test-attribution gap in an otherwise useful dossier.

## Sources re-reviewed for this follow-up

### Core implementation / registration sources

- `src/passes/DeadArgumentElimination.cpp`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/DeadArgumentElimination.cpp>
- `src/passes/pass.cpp`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- `src/passes/opt-utils.h`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/opt-utils.h>
- `src/passes/param-utils.h`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/param-utils.h>
- `src/ir/return-utils.h`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/return-utils.h>
- `src/ir/lubs.h`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/lubs.h>
- `src/ir/type-updating.h`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/type-updating.h>

### Reviewed test files

- `test/lit/passes/dae_tnh.wast`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/dae_tnh.wast>
- `test/lit/passes/dae-gc.wast`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/dae-gc.wast>
- `test/lit/passes/dae-gc-refine-params.wast`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/dae-gc-refine-params.wast>
- `test/lit/passes/dae-gc-refine-return.wast`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/dae-gc-refine-return.wast>
- `test/lit/passes/dae-optimizing.wast`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/dae-optimizing.wast>
- `test/lit/passes/dae-refine-params-and-optimize.wast`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/dae-refine-params-and-optimize.wast>

### Neighbor checked only as boundary evidence, not as the plain oracle

- `test/lit/passes/dae2.wast`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/dae2.wast>

## Main follow-up conclusions

## 1. Plain `dae` and `dae-optimizing` really do share one owner file

The real owner split in `version_129` is:

- `DeadArgumentElimination.cpp` owns the full direct-call boundary algorithm for **both** plain `dae` and `dae-optimizing`;
- `pass.cpp` owns the public registration split;
- `opt-utils.h` owns only the extra nested cleanup helper used by the optimizing variant.

So the best short teaching sentence is:

> plain `dae` is the shared `DeadArgumentElimination.cpp` engine with `optimize = false`.

That is stronger and more source-confirmed than the older vague wording “same core engine, but no rerun.”

## 2. There is no single dedicated plain-`dae` lit file

The official proof surface for plain `dae` is distributed.

The files that most directly prove the plain contract are:

- `dae_tnh.wast`
- `dae-gc.wast`
- `dae-gc-refine-params.wast`
- `dae-gc-refine-return.wast`

Those four files cover the core plain algorithm families:

- dead params,
- constant actuals,
- `call(unreachable)` / TNH repair,
- GC param refinement,
- GC result refinement,
- export / `ref.func` / tail-call conservatism.

The neighboring files

- `dae-optimizing.wast`
- `dae-refine-params-and-optimize.wast`

still matter, but they are best treated as **shared-core contrast plus optimizing-wrapper evidence**, not as the main plain-pass oracle.

## 3. `dae2.wast` is explicit non-evidence for plain `dae`

The follow-up re-check confirms the neighboring `dae2.wast` file belongs to a separately registered experimental pass, not to plain `dae`.

That means the dossier should keep one explicit warning:

- `dae2` is a nearby sibling,
- not a hidden extra test suite for the original DAE engine.

This matters because `dae2` also talks about dead arguments and forwarding, so it is easy for future readers to over-credit its much larger test file to the wrong pass.

## 4. Helper ownership is compact and teachable

The main helper split is now clear enough to teach compactly:

- `param-utils.h` owns used-param discovery, constant actual materialization, parameter removal, and operand localization;
- `lubs.h` owns param/result LUB logic;
- `type-updating.h` owns signature/type repair after param/result refinement;
- `return-utils.h` owns callee-body return rewriting once result removal is legal;
- `opt-utils.h` owns only the optimizing variant's nested cleanup replay.

That owner map is the missing compact answer the folder lacked before this follow-up.

## 5. The biggest test-surface teaching point is the split between core and polish

The reviewed file set supports a clean split:

### Plain-core proof families

- direct-call ownership and unseen-call bailouts;
- constant actual promotion;
- GC param/result narrowing;
- dropped-return removal;
- `call; unreachable` / TNH repair.

### Optimizing-only proof families

- the extra visible cleanup after DAE changes;
- cases where plain DAE would leave intermediate locals/debris but `dae-optimizing` cleans them up immediately via `optimizeAfterInlining(...)`.

So the folder should not silently use optimizing output as if it described the whole plain contract.

## What changed in the living wiki

This follow-up should add the previously missing `docs/wiki/binaryen/passes/dead-argument-elimination/implementation-structure-and-tests.md` page and refresh the landing/strategy/catalog notes so they explicitly teach:

- the shared `DeadArgumentElimination.cpp` owner story,
- the `pass.cpp` / `opt-utils.h` split,
- the real plain test map across the `dae_tnh` + `dae-gc*` files,
- and the explicit exclusion of `dae2.wast` from the plain pass oracle.

## Durable takeaways to file back into the wiki

- The `dead-argument-elimination` dossier's missing implementation/test-map page was a real gap, not cosmetic polish.
- Official Binaryen `version_129` gives plain `dae` no single dedicated `dae.wast`; its real proof surface is the combined `dae_tnh` and `dae-gc*` family, with optimizing files used only as sibling-boundary evidence.
- The real owner split is compact: shared `DeadArgumentElimination.cpp` core, public registration split in `pass.cpp`, helper ownership in `param-utils.h` / `lubs.h` / `type-updating.h` / `return-utils.h`, and optimizing-only rerun ownership in `opt-utils.h`.
- `dae2.wast` must stay explicitly marked as neighboring-but-separate evidence so future threads do not misattribute the experimental pass's larger surface to the original DAE engine.
