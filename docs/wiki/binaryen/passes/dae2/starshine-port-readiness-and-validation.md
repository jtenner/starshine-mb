---
kind: concept
status: supported
last_reviewed: 2026-05-05
sources:
  - ../../../raw/binaryen/2026-05-05-dae2-current-main-recheck.md
  - ../../../raw/research/0452-2026-05-05-dae2-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-26-dae2-port-readiness-primary-sources.md
  - ../../../raw/research/0410-2026-04-26-dae2-port-readiness.md
  - ../../../raw/binaryen/2026-04-25-dae2-primary-sources.md
  - ../../../raw/research/0337-2026-04-25-dae2-source-bridge.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/lib/types.mbt
  - ../../../../../src/validate/typecheck.mbt
  - ../../../../../src/validate/validate.mbt
  - ../../../../../src/wast/
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./fixed-point-forwarding-type-trees-and-expression-removal.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../dead-argument-elimination/starshine-port-readiness-and-validation.md
  - ../signature-pruning/starshine-port-readiness-and-validation.md
  - ../signature-refining/starshine-port-readiness-and-validation.md
---

# Starshine port readiness and validation for `dae2`

## Current answer

Starshine is **not ready to claim `dae2` support**.

The useful next wiki-backed step is not to jump directly into a mutating port. It is to make `dae2` an explicit registry/status decision and then build a no-rewrite analyzer that proves the same facts Binaryen's experimental engine needs: real parameter uses, forwarded parameter edges, referenced function/type roots, and the boundary between private direct calls and closed-world referenced type-tree rewrites.

This page is the first-slice / validation bridge for the pass. Read it after:

- [`./index.md`](./index.md) for the overview,
- [`./wat-shapes.md`](./wat-shapes.md) for concrete transformed shapes,
- [`./binaryen-strategy.md`](./binaryen-strategy.md) for upstream strategy,
- [`./fixed-point-forwarding-type-trees-and-expression-removal.md`](./fixed-point-forwarding-type-trees-and-expression-removal.md) for the hard mechanics,
- [`./starshine-strategy.md`](./starshine-strategy.md) for current local status.

## What the 2026-04-26 source recheck changed

The recheck did **not** find a new Binaryen strategy. It made the Starshine landing sequence concrete:

- official Binaryen current `main` still teaches the same `dae2` contract captured for `version_129`;
- the 2026-05-05 current-main freshness layer kept that reading unchanged, and the GitHub web spotcheck matched it;
- local Starshine still has no `dae2` registry entry, owner file, dispatcher case, preset role, or backlog slice;
- local IR/validator surfaces already expose the call/type/reference forms a future implementation must analyze;
- the first safe implementation path should be analyzer-first, not a blind alias to plain DAE.

Primary source capture: [`../../../raw/binaryen/2026-04-26-dae2-port-readiness-primary-sources.md`](../../../raw/binaryen/2026-04-26-dae2-port-readiness-primary-sources.md). Research note: [`../../../raw/research/0410-2026-04-26-dae2-port-readiness.md`](../../../raw/research/0410-2026-04-26-dae2-port-readiness.md). Freshness layer: [`../../../raw/binaryen/2026-05-05-dae2-current-main-recheck.md`](../../../raw/binaryen/2026-05-05-dae2-current-main-recheck.md), [`../../../raw/research/0452-2026-05-05-dae2-current-main-recheck.md`](../../../raw/research/0452-2026-05-05-dae2-current-main-recheck.md).

## Exact local code map

| Surface | Current `dae2` role | Why it matters for the first slice |
| --- | --- | --- |
| `src/passes/optimize.mbt:124-142` | `pass_registry_boundary_only_names()` lists `dead-argument-elimination` and `dead-argument-elimination-optimizing`, but not `dae2`. | A future port must first choose whether `dae2` stays unknown, becomes boundary-only, or becomes an active module pass. |
| `src/passes/optimize.mbt:145-152` | `pass_registry_removed_names()` also omits `dae2`. | Current behavior is not “removed”; docs and tests should keep saying unknown until the registry changes. |
| `src/passes/optimize.mbt:457-519` | `run_hot_pipeline_expand_passes(...)` emits `unknown pass flag {name}` when lookup fails and distinct errors for boundary-only/removed entries. | Request-behavior tests should pin the transition when `dae2` changes status. |
| `src/passes/pass_manager.mbt:8660-8694` | `run_hot_pipeline_apply_module_pass(...)` handles the current active module-pass set only. | A mutating `dae2` port would be a module pass; there is no dispatcher hook today. |
| `src/lib/types.mbt:416` | `FuncType` exists as the core signature value. | Parameter deletion and referenced type-tree repair must rewrite function types and all users consistently. |
| `src/lib/types.mbt:527-532` | IR has `Call`, `CallIndirect`, `ReturnCall`, `ReturnCallIndirect`, `CallRef`, and `ReturnCallRef`. | These are the call families Binaryen analyzes; direct-call-only work is only a subset. |
| `src/lib/types.mbt:722` | IR has `RefFunc`. | `ref.func` makes functions referenced and moves them out of the simplest private direct-call bucket. |
| `src/lib/types.mbt:2996-3019`, `src/lib/types.mbt:3980-3981`, `src/lib/types.mbt:8447-8451` | Constructor helpers exist for indirect/reference calls, `ref.func`, and function types. | Future rewrites should use constructor helpers rather than open-struct or ad hoc instruction literals. |
| `src/validate/typecheck.mbt` | Typechecks direct, indirect, reference-call, and `ref.func` forms. | Every mutating slice needs validation fixtures that fail before repair and pass after repair. |
| `src/validate/validate.mbt` | Performs module-level reference/declaration validation. | Referenced-function/type-tree rewrites must preserve declared reference validity. |
| `src/wast/` | Text parser/lowering surface for typed calls and reference fixtures. | Port tests should start from focused WAT shapes and only add unsupported syntax when the parser can lower it. |

## Implementation sequence

### Slice 0: registry honesty

Before implementing rewrites, decide the public status:

- keep `dae2` unknown and document it as upstream-only;
- add `dae2` as boundary-only to make the upstream spelling discoverable but rejected;
- or add an active module-pass entry only once a real owner/dispatcher/test surface exists.

Do **not** map `dae2` to plain [`../dead-argument-elimination/index.md`](../dead-argument-elimination/index.md) or [`../dae-optimizing/index.md`](../dae-optimizing/index.md). Upstream uses a separate owner file and a different fixed-point algorithm.

Validation for this slice:

- request `--pass dae2` and assert the expected status message;
- assert plain DAE names keep their current boundary-only behavior;
- assert no preset expands to `dae2` until a real pass exists.

### Slice 1: no-rewrite analyzer

Build a module analyzer that reports, without mutating:

- candidate private functions;
- per-function parameter use seeds;
- direct forwarded-parameter edges;
- reasons a parameter is live because it feeds a condition, effectful expression, return, global write, or other real use;
- functions made referenced by `ref.func`, element/declaration surfaces, exports/imports, or equivalent roots.

Validation for this slice:

- direct unused param is classified dead;
- condition-used param is classified live;
- `global.set(local.get p)` is classified live;
- recursive and mutual-recursive pure forwarding cycles remain dead until a real use seed appears;
- `ref.func` target is classified as referenced, not as an ordinary private function.

### Slice 2: private direct-call scalar deletion

The smallest useful mutating subset should stay private and direct-call-only:

- delete dead parameters from unreferenced/private functions;
- convert removed params to locals only when body/local-index invariants require it;
- remove matching direct-call operands;
- preserve effects and control scaffolding around removed argument expressions;
- repair local indices, type declarations, and call signatures.

Validation for this slice:

- trivial direct dead-param deletion;
- caller-retains-own-param / callee-loses-forwarded-copy shape;
- effectful removed operand stays as an effect-preserving expression if needed;
- `return_call` is either supported with tests or explicitly preserved;
- imported/exported/`ref.func` functions are not rewritten by this slice.

### Slice 3: fixed-point forwarding cycles

Add the real backward propagation loop for direct calls:

- recursive self-forwarding cycles;
- mutual-recursive forwarding cycles;
- mixed cycles with one real-use seed;
- overwritten local slots that are not true incoming-param forwarding.

Validation for this slice:

- shape 2 and shape 3 from [`./wat-shapes.md`](./wat-shapes.md) shrink;
- shape 4 stays live;
- tests include a local-slot overwrite case so slot reuse is not mistaken for boundary-param forwarding.

### Slice 4: referenced root function-type trees

Only attempt this after Starshine has enough shared module/type rewrite infrastructure:

- root function-type tree grouping;
- `call_ref` and `call_indirect` aggregation;
- public/root/tag/continuation/intrinsic blockers;
- replacement-type generation for unreferenced siblings;
- global type-holder and function type remapping;
- post-rewrite validation/refinalization equivalent.

Validation for this slice:

- `call_ref` and `call_indirect` positives from Binaryen's `dae2.wast`;
- public roots, continuations, tags, and `call.without.effects` negatives;
- replacement-type regression fixtures;
- full module validation after type remap.

## Binaryen oracle lanes

Use official Binaryen as an oracle, but keep the lane honest:

- early local tests: focused WAT fixtures mirroring [`./wat-shapes.md`](./wat-shapes.md);
- first Binaryen comparison lane: private direct-call cases that do not require referenced function-type-tree rewriting;
- later comparison lane: `wasm-opt -all --dae2 --closed-world -S` against the official `dae2.wast` families;
- final parity lane: randomized or reduced modules that include direct, indirect, reference-call, and escaped-function surfaces.

Do not use plain `--dae` or `--dae-optimizing` as the oracle for this pass. They prove neighboring DAE-family behavior, not `dae2`'s fixed-point forwarding/type-tree contract.

## Non-goals to keep explicit

Current upstream `dae2` is still incomplete relative to the broader DAE family. Unless a future source recheck proves otherwise, Starshine should not promise `dae2` support for:

- dropped-result optimization;
- constant actual propagation;
- param/result type propagation.

Those behaviors belong to the plain DAE-family pages today.

## Health checklist for future updates

When this page changes, also check:

- [`./index.md`](./index.md) - overview and page map;
- [`./binaryen-strategy.md`](./binaryen-strategy.md) - current upstream contract;
- [`./wat-shapes.md`](./wat-shapes.md) - shape families and caveats;
- [`./starshine-strategy.md`](./starshine-strategy.md) - current status wording;
- [`../dead-argument-elimination/index.md`](../dead-argument-elimination/index.md) and [`../dae-optimizing/index.md`](../dae-optimizing/index.md) - sibling contrast;
- [`../tracker.md`](../tracker.md) and [`../index.md`](../index.md) - classification and catalog entries.

## Sources

- 2026-04-26 current-main / port-readiness source capture: [`../../../raw/binaryen/2026-04-26-dae2-port-readiness-primary-sources.md`](../../../raw/binaryen/2026-04-26-dae2-port-readiness-primary-sources.md)
- Research note: [`../../../raw/research/0410-2026-04-26-dae2-port-readiness.md`](../../../raw/research/0410-2026-04-26-dae2-port-readiness.md)
- Original raw source manifest: [`../../../raw/binaryen/2026-04-25-dae2-primary-sources.md`](../../../raw/binaryen/2026-04-25-dae2-primary-sources.md)
- Source bridge: [`../../../raw/research/0337-2026-04-25-dae2-source-bridge.md`](../../../raw/research/0337-2026-04-25-dae2-source-bridge.md)
- Starshine registry source: [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- Starshine module dispatcher: [`../../../../../src/passes/pass_manager.mbt`](../../../../../src/passes/pass_manager.mbt)
- Starshine core IR/types: [`../../../../../src/lib/types.mbt`](../../../../../src/lib/types.mbt)
