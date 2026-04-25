---
kind: research
status: supported
last_reviewed: 2026-04-25
sources:
  - ../binaryen/2026-04-25-local-subtyping-implementation-test-map-source-correction.md
  - ../binaryen/2026-04-22-local-subtyping-primary-sources.md
  - ../../binaryen/passes/local-subtyping/index.md
  - ../../binaryen/passes/local-subtyping/binaryen-strategy.md
  - ../../binaryen/passes/local-subtyping/implementation-structure-and-tests.md
  - ../../binaryen/passes/local-subtyping/lubs-and-dominance.md
  - ../../binaryen/passes/local-subtyping/wat-shapes.md
  - ../../binaryen/passes/local-subtyping/starshine-strategy.md
  - ../../../../src/passes/optimize.mbt
  - ../../../../src/passes/optimize_test.mbt
  - ../../../../src/passes/pass_manager.mbt
  - ../../../../src/lib/types.mbt
  - ../../../../src/validate/typecheck.mbt
  - ../../../../src/ir/hot_core.mbt
  - ../../../../agent-todo.md
  - ../../binaryen/no-dwarf-default-optimize-path.md
  - ./0261-2026-04-22-local-subtyping-source-correction-and-starshine-followup.md
---

# `local-subtyping` implementation/test map source correction

## Why this follow-up exists

The existing `local-subtyping` dossier was useful but carried a second-order source error from the 2026-04-22 correction. It correctly rejected the old broad “generic local-flow collector plus `LocalUpdater` copy-local insertion” story, but it overcorrected too far by teaching that Binaryen `version_129` was set/tee-only, had no `visitLocalGet` surface, had no iterative `ReFinalize()` loop, skipped parameters during scanning, and relied on `TypeUpdating::canHandleAsLocal(...)`.

A fresh read of the official `version_129` and current-main sources showed those details are wrong. This note records the corrected source map and the living-page updates made from it.

## Primary source added in this run

- `docs/wiki/raw/binaryen/2026-04-25-local-subtyping-implementation-test-map-source-correction.md`

The new manifest captures official Binaryen URLs for `LocalSubtyping.cpp`, `pass.cpp`, `opt-utils.h`, `passes.h`, `lubs.h`, `lubs.cpp`, `local-structural-dominance.h`, and `local-subtyping.wast`, plus a current-main no-teaching-drift spot check.

## Corrected durable findings

### 1. The owner file is iterative and refinalizes between refinement rounds

`LocalSubtyping.cpp` runs a loop. After the first iteration, it calls `ReFinalize().walkFunctionInModule(func, module)` before rescanning. This matters because changing one local declaration can make a later set-value type more precise, enabling another refinement round.

### 2. Gets are real source locations, but not LUB evidence

The pass records `local.get` sites for each relevant local. Those gets are used for:

- non-null dominance checks
- deciding which undominated gets must keep the older nullable type
- retagging safe gets to the new declaration type

The LUB candidate still comes from set/tee value types, not from consumer-side wishful thinking. The correct short phrase is therefore **set-fed LUB plus get-aware dominance/type repair**, not “no get handling.”

### 3. Parameter handling is split

The scanner has a TODO about ignoring params and may record parameter gets/sets when their types are relevant. The actual declaration rewrite loop starts from `func->getVarIndexBase()`, so parameters remain unchanged. The living pages now distinguish “scan surface” from “rewrite surface.”

### 4. The tuple/nondefaultable story is not `TypeUpdating::canHandleAsLocal(...)`

The checked owner file does not use the `TypeUpdating::canHandleAsLocal(...)` gate described by the older dossier. The important visible gates are:

- relevant local types are references
- locals without sets are skipped
- nondefaultable candidates must be non-null references and dominance-safe, otherwise the pass uses a nullable version
- non-reference and tuple-like locals stay outside the transformation surface

### 5. The dedicated test file proves more than the old shape page said

`local-subtyping.wast` covers ordinary narrowing, non-null dominance, loops, tee typing, repeated refinement, named-type LUBs, parameter preservation, nondefaultable tuple preservation, and interaction clusters with `optimize-casts`, `coalesce-locals`, and `local-cse`.

## Living pages changed

- `docs/wiki/binaryen/passes/local-subtyping/index.md`
- `docs/wiki/binaryen/passes/local-subtyping/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/local-subtyping/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/local-subtyping/lubs-and-dominance.md`
- `docs/wiki/binaryen/passes/local-subtyping/wat-shapes.md`
- `docs/wiki/binaryen/passes/local-subtyping/starshine-strategy.md`
- `docs/wiki/index.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/log.md`
- `CHANGELOG.md`

## Local Starshine status refreshed

Starshine still has no `local-subtyping` implementation. The refreshed pages ground that status in exact code locations:

- `src/passes/optimize.mbt:144-151` tracks the removed upstream pass spelling.
- `src/passes/pass_manager.mbt:8688-8704` dispatches active hot passes and has no `local-subtyping` case.
- `src/passes/optimize_test.mbt:390-395` keeps current preset placement honest around missing neighboring local passes.
- `agent-todo.md:372-383` keeps the `LS` backlog slice.
- `src/lib/types.mbt:55-65`, `src/lib/types.mbt:230-238`, `src/lib/types.mbt:416-420`, and `src/lib/types.mbt:536-538` define the local type and local instruction surfaces a future port would mutate.
- `src/validate/typecheck.mbt:535-558` defines the local get/set/tee typing checks that would validate any retagged declarations.
- `src/ir/hot_core.mbt:150-178` defines HOT local metadata that a future implementation may need to keep aligned.

## Supersession note

This note does not delete the 2026-04-22 source-correction note. That note remains useful for documenting the first correction away from the old `LocalUpdater` overread. It is partially superseded here for the owner-file mechanics listed above.
