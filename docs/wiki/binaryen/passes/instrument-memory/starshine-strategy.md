---
kind: concept
status: supported
last_reviewed: 2026-04-26
sources:
  - ../../../raw/binaryen/2026-04-26-instrument-memory-current-main-port-readiness.md
  - ../../../raw/research/0388-2026-04-26-instrument-memory-port-readiness.md
  - ../../../raw/binaryen/2026-04-24-instrument-memory-primary-sources.md
  - ../../../raw/research/0288-2026-04-24-instrument-memory-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0231-2026-04-21-instrument-memory-binaryen-research.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/registry_test.mbt
  - ../../../../../src/ir/hot_core.mbt
  - ../../../../../src/ir/hot_lift.mbt
  - ../../../../../src/ir/hot_lower.mbt
  - ../../../../../src/lib/types.mbt
  - ../../../../../src/binary/encode.mbt
  - ../../../../../src/binary/decode.mbt
  - ../../../../../agent-todo.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./helper-import-roster-filters-and-unsupported-types.md
  - ./wat-shapes.md
  - ./starshine-port-readiness-and-validation.md
  - ../instrument-locals/index.md
  - ../global-effects/index.md
  - ../tracker.md
---

# Starshine strategy for `instrument-memory`

## Current local status

Starshine currently has **no `instrument-memory` implementation**.
This page is therefore a status and future-port map, not a description of a shipped transform.

The exact local status is sharper than just "not implemented":

- `src/passes/optimize.mbt` has no `instrument-memory` entry in `pass_registry_boundary_only_names()` or `pass_registry_removed_names()`.
- `src/passes/optimize.mbt` has no active `HotPass` or `ModulePass` entry for it in `pass_registry_entries()`.
- `run_hot_pipeline_expand_passes(...)` reports unknown names as `unknown pass flag ...`, so an explicit `instrument-memory` request would currently fail as unknown rather than boundary-only or removed.
- `src/passes/registry_test.mbt` classifies active, boundary-only, and removed examples, but it has no `instrument-memory` compatibility assertion.
- `agent-todo.md` has no dedicated `instrument-memory` backlog slice.

That means Starshine's present strategy is **non-adoption plus documentation**.
The wiki tracks the upstream pass because it is a real public Binaryen pass, because it explains the sibling split from [`instrument-locals`](../instrument-locals/index.md), and because its helper imports intentionally change effect-sensitive downstream reasoning.
It is not part of Starshine's optimize or shrink preset today. If that status ever changes, use [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md) as the first-slice and validation checklist rather than inferring implementation order from the broad upstream strategy page.

## Exact local code locations to read first

- `src/passes/optimize.mbt:127-153`
  - current boundary-only and removed name lists; `instrument-memory` is absent from both.
- `src/passes/optimize.mbt:156-267`
  - current active hot/module/preset registry construction; no `instrument-memory` entry exists.
- `src/passes/optimize.mbt:363-367`
  - `pass_registry_category(...)`, the public lookup used to classify pass names.
- `src/passes/optimize.mbt:446-489`
  - request expansion and rejection behavior; unknown names fail before the boundary-only / removed guards.
- `src/passes/optimize.mbt:407-421`
  - imported-function counting used by the pipeline for validation bookkeeping. This is not instrumentation-helper ABI synthesis and should not be mistaken for a partial port.
- `src/passes/optimize.mbt:423-442`
  - memory-presence detection used by the pipeline. This is ordinary validation / pipeline gating, not Binaryen-style `load_ptr` / `store_ptr` helper injection.
- `src/passes/registry_test.mbt:2-90`
  - registry category smoke test for implemented and removed names; no `instrument-memory` expectation is present.
- `src/passes/registry_test.mbt:130-157`
  - preset expansion assertion showing the active preset stays on implemented pass names.
- `src/ir/hot_core.mbt:47-54`
  - HOT op categories already include `Load`, `Store`, `MemorySize`, `MemoryGrow`, and bulk-memory/data families, proving these are ordinary IR shapes, not instrumentation support.
- `src/ir/hot_lift.mbt:611-754` and `src/ir/hot_lower.mbt:1077-1080`
  - lift/lower surfaces for memory-like HOT ops. These are useful future building blocks but currently only preserve or rewrite existing instructions.
- `src/lib/types.mbt:740-751`
  - library instruction variants for `StructGet`, `StructSet`, `ArrayGet`, and related GC operations.
- `src/binary/decode.mbt:2755-2758` and `src/binary/encode.mbt:2731-2751`
  - binary decode/encode surfaces for `memory.grow` and array access instructions that a future module pass would need to preserve.

## Why there is no HOT-IR port today

Binaryen's pass is not a local peephole optimizer.
Per the upstream source captured in [`../../../raw/binaryen/2026-04-24-instrument-memory-primary-sources.md`](../../../raw/binaryen/2026-04-24-instrument-memory-primary-sources.md), it needs all of these module-level behaviors:

1. inject helper function imports into the module,
2. optionally parse an exact comma-separated filter set,
3. choose helper signatures from the selected memory's address type and observed scalar value type,
4. rewrite `load` pointer children through `load_ptr(...)` and wrap loaded scalar results with `load_val_*`,
5. rewrite `store` pointer/value children through `store_ptr(...)` and `store_val_*`,
6. split `memory.grow` through `memory_grow_pre(...)` and `memory_grow_post(...)`,
7. with GC enabled, wrap selected scalar `struct.get` / `struct.set` / `array.get` / `array.set` payloads and array indices,
8. preserve unsupported instruction and payload families rather than pretending to trace everything, and
9. mark the transform as effect-adding so effect-sensitive consumers stop assuming the same code is removable.

Starshine's active HOT passes mostly rewrite existing function bodies and then rely on validation/writeback guards.
`instrument-memory` would additionally require module import synthesis, helper ABI naming, memory64-aware helper typing, filter parsing, and a product decision about whether debug instrumentation belongs in the same user-facing optimizer surface.

## If Starshine ever ports it

A faithful local port should start as a **module pass**, not as an isolated HOT peephole, because helper-import creation is part of the observable output.

Minimum acceptance criteria:

- public pass spelling and help text decided deliberately: either match Binaryen's `instrument-memory`, or keep it absent and document why;
- helper imports match Binaryen's `env` ABI shape for scalar memory, `memory.grow`, and GC helpers;
- filter keys are exactly `load`, `store`, `memory.grow`, `struct.get`, `struct.set`, `array.get`, and `array.set`;
- scalar load/store rewrites preserve the original memory operation shape while wrapping the pointer and/or scalar value child in helper calls;
- `memory.grow` uses the pre/post helper split;
- memory64 changes pointer-side helper signatures and offset literals to `i64` without changing scalar value helper types;
- GC support stays scalar-only unless a future source recheck or deliberate local divergence expands it;
- unsupported families stay explicitly tested as preserved: `memory.size`, bulk memory ops, atomics, cmpxchg, ref-valued GC payloads, and SIMD payloads;
- helper IDs remain documented as observation IDs rather than stable one-per-source-operation IDs;
- effect invalidation is explicit and covered by a test that composes with the local `global-effects` / `vacuum` story if those passes become active together;
- the sibling split from [`instrument-locals`](../instrument-locals/index.md) remains visible: memory instrumentation must not accidentally claim local-access coverage.

## Validation plan for a future port

Use the detailed ladder in [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md). In short:

- Add registry tests first for whichever public status is chosen: active module pass, boundary-only compatibility name, removed compatibility name, or continued unknown-name rejection.
- Add reduced shape tests modeled on [`wat-shapes.md`](./wat-shapes.md): scalar load/store positives, `memory.grow`, filtered no-op stores, GC struct/array positives, memory64 address widening, and unsupported family preservation.
- Add one effect-sensitive test modeled on the Binaryen `addsEffects()` contract so the pass cannot be misclassified as effect-neutral.
- Run the normal repo validation path for implemented behavior (`moon info`, `moon fmt`, `moon test`) and, if a parity harness supports instrumentation passes by then, compare against `wasm-opt --instrument-memory` on the covered subset.

## Non-goals today

- Do not add `instrument-memory` to the optimize or shrink preset just because the wiki documents it.
- Do not teach this pass as a memory optimizer. It intentionally makes memory and selected heap traffic more observable and usually less removable.
- Do not infer `instrument-memory` support from HOT `Load` / `Store` / `MemoryGrow` op categories or from import-counting helpers in `src/passes/optimize.mbt`; those surfaces are ordinary IR and validation infrastructure, not helper import synthesis for instrumentation.
- Do not merge this page into `instrument-locals`; the sibling split is one of the reasons both dossiers are useful.
