---
kind: research
status: supported
last_reviewed: 2026-04-25
sources:
  - ../binaryen/2026-04-25-de-nan-current-main-recheck.md
  - ../binaryen/2026-04-24-de-nan-primary-sources.md
  - ./0283-2026-04-24-de-nan-primary-sources-and-starshine-followup.md
  - ../../binaryen/passes/de-nan/index.md
  - ../../../../src/passes/optimize.mbt
  - ../../../../src/passes/registry_test.mbt
related:
  - ../../binaryen/passes/de-nan/index.md
  - ../../binaryen/passes/de-nan/binaryen-strategy.md
  - ../../binaryen/passes/de-nan/starshine-strategy.md
---

# `de-nan` / `denan` current-main recheck

## Question

Does Binaryen current `main` change the teaching contract for `denan` after the 2026-04-24 primary-source dossier, and do the Starshine pages need any strategy correction?

## Short answer

No teaching-relevant drift was found. The `version_129` dossier remains the correct oracle for beginner-to-advanced documentation and future Starshine port planning.

The useful update is provenance and confidence: the living pages can now cite a 2026-04-25 focused raw recheck that confirms the same public spelling, owner file, helper-call instrumentation strategy, skip rules, helper-name collision behavior, and dedicated lit proof surface.

## Durable findings

- Upstream public spelling remains `denan`; Starshine still tracks the compatibility alias `de-nan` as a removed registry name.
- The implementation remains a module/function instrumentation pass, not a normal optimizer peephole.
- The pass still advertises `addsEffects()` because helper calls are inserted.
- Constant NaNs still become zero constants, including contexts where call insertion would be illegal.
- Nonconstant `f32`, `f64`, and `v128` producers inside function bodies still get helper-call wrapping.
- Defined-function params still get entry repair; imported functions are still skipped.
- Plain `local.get` and result-fallthrough shells remain skip families.
- Helper names remain collision-safe, and helpers are appended after the walk to avoid self-instrumentation.
- The SIMD helper still depends on scalar lane extraction rather than vector equality.
- The shipped `denan.wast` proof surface remains compact but adequate for the major beginner-facing families.

## Starshine consequences

No implementation status changed.

The correct local story is still:

- no `src/passes/de_nan.mbt` / `src/passes/denan.mbt` owner file
- `src/passes/optimize.mbt` keeps `de-nan` in `pass_registry_removed_names()`
- removed-name request rejection is covered by `src/passes/registry_test.mbt`
- `agent-todo.md` still has no dedicated `de-nan` / `denan` slice
- any faithful future port probably needs a module owner that can add helper functions and entry-param fixups, even if expression walking reuses HOT-style utilities

## Pages refreshed

- `docs/wiki/binaryen/passes/de-nan/index.md`
- `docs/wiki/binaryen/passes/de-nan/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/de-nan/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/de-nan/helper-functions-fallthrough-and-boundaries.md`
- `docs/wiki/binaryen/passes/de-nan/wat-shapes.md`
- `docs/wiki/binaryen/passes/de-nan/starshine-strategy.md`
- `docs/wiki/index.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/log.md`

## Uncertainty retained

This note does not identify the historical introduction point for `denan`, and it does not survey downstream packaging docs. It only supersedes uncertainty about whether current `main` has drifted from the 2026-04-24 `version_129` teaching contract.
