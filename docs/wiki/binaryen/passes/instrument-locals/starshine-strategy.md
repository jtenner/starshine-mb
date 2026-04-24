---
kind: concept
status: supported
last_reviewed: 2026-04-24
sources:
  - ../../../raw/binaryen/2026-04-24-instrument-locals-primary-sources.md
  - ../../../raw/research/0287-2026-04-24-instrument-locals-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0227-2026-04-21-instrument-locals-binaryen-research.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/registry_test.mbt
  - ../../../../../agent-todo.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./unsupported-types-effects-and-import-roster.md
  - ./wat-shapes.md
  - ../instrument-memory/index.md
  - ../global-effects/index.md
  - ../tracker.md
---

# Starshine strategy for `instrument-locals`

## Current local status

Starshine currently has **no `instrument-locals` implementation**.
This page is therefore a status and future-port map, not a description of a shipped transform.

The exact local status is sharper than just "not implemented":

- `src/passes/optimize.mbt` has no `instrument-locals` entry in `pass_registry_boundary_only_names()` or `pass_registry_removed_names()`.
- `src/passes/optimize.mbt` has no active `HotPass` or `ModulePass` entry for it in `pass_registry_entries()`.
- `run_hot_pipeline_expand_passes(...)` reports unknown names as `unknown pass flag ...`, so an explicit `instrument-locals` request would currently fail as unknown rather than boundary-only or removed.
- `src/passes/registry_test.mbt` classifies active, boundary-only, and removed examples, but it has no `instrument-locals` compatibility assertion.
- `agent-todo.md` has no dedicated `instrument-locals` backlog slice.

That means Starshine's present strategy is **non-adoption plus documentation**.
The wiki tracks the upstream pass because it is a real public Binaryen pass and because it explains the sibling split from [`instrument-memory`](../instrument-memory/index.md), not because Starshine is expected to run it in the optimization preset.

## Exact local code locations to read first

- `src/passes/optimize.mbt:126-153`
  - current boundary-only and removed name lists; `instrument-locals` is absent from both.
- `src/passes/optimize.mbt:156-267`
  - current active hot/module/preset registry construction; no `instrument-locals` entry exists.
- `src/passes/optimize.mbt:363-367`
  - `pass_registry_category(...)`, the public lookup used to classify pass names.
- `src/passes/optimize.mbt:446-489`
  - request expansion and rejection behavior; unknown names fail before the boundary-only / removed guards.
- `src/passes/optimize.mbt:407-421`
  - imported-function counting used by the pipeline for validation bookkeeping. This is not an instrumentation-helper ABI and should not be mistaken for a partial port.
- `src/passes/registry_test.mbt:1-90`
  - registry category smoke test for implemented and removed names; no `instrument-locals` expectation is present.
- `src/passes/registry_test.mbt:134-157`
  - preset expansion assertion showing the active preset stays on implemented pass names.

## Why there is no HOT-IR port today

Binaryen's pass is not a local peephole optimizer.
Per the upstream source captured in [`../../../raw/binaryen/2026-04-24-instrument-locals-primary-sources.md`](../../../raw/binaryen/2026-04-24-instrument-locals-primary-sources.md), it needs all of these module-level behaviors:

1. inject helper function imports into the module,
2. select helper signatures from the local value type,
3. rewrite `local.get` nodes into value-returning `call $get_*` wrappers,
4. rewrite `local.set` / `local.tee` assigned values into `call $set_*` wrappers,
5. preserve deliberate non-rewrite cases such as ordinary `i64`, unsupported reference families, `unreachable` assigned values, and legacy-EH `Pop`, and
6. mark the transform as effect-adding so effect-sensitive consumers stop assuming the same code is removable.

Starshine's active HOT passes mostly rewrite existing function bodies and then rely on validation/writeback guards.
`instrument-locals` would additionally require module import synthesis, helper ABI naming, and a product decision about whether debug instrumentation belongs in the same user-facing optimizer surface.

## If Starshine ever ports it

A faithful local port should start as a **module pass**, not as an isolated HOT peephole, because helper-import creation is part of the observable output.

Minimum acceptance criteria:

- public pass spelling and help text decided deliberately: either match Binaryen's `instrument-locals`, or keep it absent and document why;
- helper imports match Binaryen's `env` ABI shape `(i32 call_id, i32 local_id, value) -> value`;
- one shared call-id sequence covers both get and set wrappers in traversal order;
- ordinary `i64` local traffic stays uninstrumented until upstream parity changes or the local docs explicitly choose a divergence;
- nullable `funcref`, nullable `externref`, and feature-gated `v128` behavior is tested separately from scalar `i32` / `f32` / `f64` behavior;
- `Pop` and `unreachable` assigned-value bailouts are preserved;
- effect invalidation is explicit and covered by a test that composes with the local `global-effects` / `vacuum` story if those passes become active together;
- the sibling split from [`instrument-memory`](../instrument-memory/index.md) remains visible: locals instrumentation must not accidentally claim memory, `memory.grow`, `struct.*`, or `array.*` coverage.

## Validation plan for a future port

- Add registry tests first for whichever public status is chosen: active module pass, boundary-only compatibility name, removed compatibility name, or continued unknown-name rejection.
- Add shape tests modeled on [`wat-shapes.md`](./wat-shapes.md): scalar get/set positives, ref/SIMD positives, unchanged `i64`, unchanged `Pop`, and helper import injection.
- Add one effect-sensitive test modeled on Binaryen's `instrument-locals_effects.wast` so the pass cannot be misclassified as effect-neutral.
- Run the normal repo validation path for implemented behavior (`moon info`, `moon fmt`, `moon test`) and, if a parity harness supports instrumentation passes by then, compare against `wasm-opt --instrument-locals` on the covered subset.

## Non-goals today

- Do not add `instrument-locals` to the optimize or shrink preset just because the wiki documents it.
- Do not teach this pass as a local-traffic optimizer. It intentionally makes local traffic more observable and usually less removable.
- Do not infer `instrument-locals` support from the presence of imported-function counting helpers in `src/passes/optimize.mbt`; those helpers serve pipeline validation, not helper import synthesis for instrumentation.
- Do not merge this page into `instrument-memory`; the sibling split is one of the reasons both dossiers are useful.
