---
kind: research
status: supported
last_reviewed: 2026-04-25
sources:
  - ../binaryen/2026-04-25-asyncify-current-main-and-eh-options.md
  - ../binaryen/2026-04-24-asyncify-primary-sources.md
  - ../../binaryen/passes/asyncify/index.md
  - ../../binaryen/passes/asyncify/binaryen-strategy.md
  - ../../binaryen/passes/asyncify/implementation-structure-and-tests.md
  - ../../binaryen/passes/asyncify/wat-shapes.md
  - ../../binaryen/passes/asyncify/starshine-strategy.md
  - ../../../../src/passes/optimize.mbt
related:
  - ../../binaryen/passes/memory64-lowering/index.md
  - ../../binaryen/passes/inline-main/index.md
  - ../../binaryen/passes/legalize-js-interface/index.md
---

# `asyncify` current-main and EH/options follow-up

## Question

The existing `asyncify` dossier had the required page set, but it still had two teaching gaps:

1. it did not isolate Binaryen's exception/catch unwind option boundary;
2. it told readers to look for a separate `AsyncifyLocals` owner even though the reviewed owner file should be taught as a single mini-pipeline in `Asyncify.cpp`.

This run asked whether current upstream changed the teaching-level `asyncify` contract and what wiki corrections would make the folder more useful for beginner through advanced readers.

## Sources reviewed

- Official Binaryen current-`main` and `version_129` `src/passes/Asyncify.cpp`.
- Official Binaryen current-`main` and `version_129` `test/lit/passes/asyncify.wast`.
- Official Binaryen `pass.cpp` and `passes.h` registration surfaces.
- Official Emscripten Asyncify documentation for user-visible tuning options and overhead context.
- Local Starshine registry and prerequisite representation surfaces in `src/passes/optimize.mbt`, `src/lib/types.mbt`, `src/binary/*`, `src/validate/*`, and `src/wast/*`.

## Findings

- No teaching-level current-main drift was found: Binaryen still exposes `asyncify` as a public whole-module pause/resume rewrite, not a no-DWARF optimizer or function-local peephole pass.
- The existing pages were right to center the state-machine shape: runtime helper exports, mutable state/data globals, memory-backed local save/restore, direct/indirect call instrumentation, option-pruned reachability, memory64-aware pointer traffic, and tail-call rejection.
- Exception/catch behavior deserves its own guide text. The source and lit surface expose an explicit catch/unwind option boundary; future Starshine tests should include this family rather than treating EH as only a generic validation concern.
- The source owner split needed correction: keep `ModuleAnalyzer`, `AsyncifyFlow`, the top-level `Asyncify` pass, and `ModAsyncify` as the durable navigation handles, but do not teach `AsyncifyLocals` as a standalone upstream owner.
- Starshine status remains unknown-pass. `src/passes/optimize.mbt` has no `asyncify` entry in boundary-only, removed, active, or preset entries, so explicit requests still hit the generic unknown-pass error.

## Durable wiki updates made

- Added `docs/wiki/raw/binaryen/2026-04-25-asyncify-current-main-and-eh-options.md`.
- Added `docs/wiki/binaryen/passes/asyncify/state-machine-memory-and-eh-boundaries.md` as a focused hard-half guide for state values, memory/pointer traffic, indirect-call/call-index behavior, catch unwinding, tail calls, and helper-pass separation.
- Refreshed the overview, Binaryen strategy, implementation/test map, WAT-shape catalog, and Starshine strategy pages so the folder has no stale `AsyncifyLocals` owner claim and now teaches EH/catch boundaries explicitly.
- Updated `docs/wiki/index.md`, `docs/wiki/binaryen/passes/index.md`, `docs/wiki/binaryen/passes/tracker.md`, `docs/wiki/log.md`, and `CHANGELOG.md`.

## Uncertainty

- A faithful Starshine implementation will need a host/runtime test harness. WAT diffing can verify helper/export/instrumentation shape, but it cannot prove actual pause/resume by itself.
- The wiki still intentionally does not pick whether Starshine should reserve `asyncify` as boundary-only; that is a future backlog/registry policy decision.
- `mod-asyncify-*` helper passes may deserve their own small dossier if a future implementation campaign decides to expose or emulate them locally.

## Follow-up questions

- Should `asyncify` move from unknown-pass to boundary-only before implementation, so users get a more specific diagnostic?
- Should Starshine's future whole-module rewrite framework model host/runtime integration tests centrally for `asyncify`, JS-interface legalization, and feature-lowering passes?
- Should EH/catch test coverage be planned before or after the scalar direct-call/local-save proof cases in a first local port?
