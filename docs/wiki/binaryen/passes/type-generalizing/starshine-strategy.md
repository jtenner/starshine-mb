---
kind: concept
status: supported
last_reviewed: 2026-05-05
sources:
  - ../../../raw/binaryen/2026-04-27-type-generalizing-primary-source-correction.md
  - ../../../raw/research/0421-2026-04-27-type-generalizing-source-correction-and-port-readiness.md
  - ../../../raw/binaryen/2026-05-05-type-generalizing-current-main-recheck.md
  - ../../../raw/research/0479-2026-05-05-type-generalizing-current-main-recheck.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/registry_test.mbt
  - ../../../../../src/lib/types.mbt
  - ../../../../../src/ir/hot_core.mbt
  - ../../../../../src/ir/hot_lift.mbt
  - ../../../../../src/ir/hot_lower.mbt
  - ../../../../../src/wast/lower_to_lib.mbt
  - ../../../../../src/validate/typecheck.mbt
  - ../../../../../src/binary/encode.mbt
  - ../../../../../src/binary/decode.mbt
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./type-requirements-cfg-and-unsupported-families.md
  - ./wat-shapes.md
  - ./starshine-port-readiness-and-validation.md
  - ../gufa/index.md
  - ../type-refining/index.md
---

# Starshine `type-generalizing` strategy

## Current status

Starshine does **not** implement `type-generalizing` today.

The current local truth is:

- `src/passes/optimize.mbt` lists `type-generalizing` in `pass_registry_boundary_only_names()`.
- The registry category is `BoundaryOnly`, not `HotPass` and not `ModulePass`.
- `run_hot_pipeline_expand_passes(...)` rejects boundary-only requests with the standard boundary-only error.
- `optimize` and `shrink` preset expansion lists do not include `type-generalizing`.
- `src/passes/registry_test.mbt` locks active preset expansion to implemented pass names; it does not prove a hidden implementation.
- No `src/passes/type_generalizing.mbt` owner file exists.
- No active `agent-todo.md` slice currently tracks a `type-generalizing` implementation.

So the correct Starshine strategy is a **boundary/status and future-port map**, not a code guide for an existing pass. A 2026-05-05 current-main recheck did not change that status; it only tightened the local code anchors below.

## Exact local code locations

| Local surface | Code location | Why it matters |
| --- | --- | --- |
| Registry category enum | `src/passes/optimize.mbt:2-8` | Defines `BoundaryOnly`, `HotPass`, `ModulePass`, `Removed`, and `Preset` categories |
| Boundary-only entry builder | `src/passes/optimize.mbt:84-94` | Ensures boundary-only names have no descriptor and no expansion |
| Boundary-only name list | `src/passes/optimize.mbt:127-133` | Contains `type-generalizing` today |
| Request rejection | `src/passes/optimize.mbt:505-525` | Returns “boundary-only and is not implemented in the hot pipeline” before dispatch |
| Active presets | `src/passes/optimize.mbt:434-459` | Do not include `type-generalizing` |
| Registry and preset tests | `src/passes/registry_test.mbt:197-224` | Protect active pass categories and preset honesty |
| Type model | `src/lib/types.mbt` | Defines value/reference/heap/type-section concepts a future implementation would need |
| WAT lowering | `src/wast/lower_to_lib.mbt` | Converts textual GC/ref/local shapes into lib IR |
| HOT model | `src/ir/hot_core.mbt`, `src/ir/hot_lift.mbt`, `src/ir/hot_lower.mbt` | Possible function-local analysis surfaces, though a faithful port may need richer CFG/stack requirements than HOT currently exposes |
| Validator | `src/validate/typecheck.mbt` | Must validate generalized local declarations and retagged local get/tee result types |
| Binary roundtrip | `src/binary/encode.mbt`, `src/binary/decode.mbt` | Must preserve rewritten local declaration and instruction type metadata |

## How Starshine should map the corrected Binaryen strategy

The corrected Binaryen pass is not a small HOT peephole. It is a CFG/type-requirement analysis with mutation at the local-declaration boundary.

A faithful Starshine implementation would need to model:

- function CFG edges and joins;
- value-stack type requirements, not just local use-def pairs;
- local declaration rewrite safety;
- call and `call_ref` signature constraints;
- global/table/ref/struct/array instruction constraints;
- oracle-like facts for possible runtime contents, or an explicitly narrower first slice;
- DCE-before-analysis or equivalent unreachable-code handling;
- local get/tee type repair and final validation/refinalization.

## What not to build first

Do **not** port this as:

- a direct alias to `gufa`;
- a type-section pass like `type-refining` or `type-merging`;
- a simple local-set/local-tee evidence pass;
- a `local.get` drop-plus-zero peephole;
- a default preset pass.

Those choices either match superseded notes or overstate upstream's hidden not-yet-sound status.

## Current validation guidance

Because Starshine has no implementation, current validation is status validation:

- direct requests for `type-generalizing` must fail as boundary-only;
- presets must not expand to it;
- no wiki page should imply a local owner file or active dispatcher exists;
- future docs should cite the 2026-04-27 corrective manifest and the 2026-05-05 current-main recheck for mechanics.

## Relationship to neighboring Starshine code

- `src/passes/simplify_locals.mbt` is useful as local-cleanup style, but it is not semantically close enough for this CFG/type-requirement solver.
- `src/passes/global_refining.mbt` and `src/passes/global_struct_inference.mbt` are examples of type-sensitive module passes, but they rewrite different surfaces.
- `src/passes/heap2local.mbt` and `src/passes/heap_store_optimization.mbt` show GC/reference-aware local rewrites, but they do not provide the backward requirement analysis needed here.
- `src/validate/typecheck.mbt` is the critical safety backstop for any future mutation.

## Uncertainties and caveats

- Binaryen itself labels the pass not yet sound. Starshine may choose to keep the local name boundary-only indefinitely.
- A faithful port may require infrastructure that is broader than a normal pass port: CFG, stack requirements, oracle facts, local declaration rewriting, and local-use type repair.
- The safest first implementation slice is analysis-only; see [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md).

## Source chain

1. [`../../../raw/binaryen/2026-04-27-type-generalizing-primary-source-correction.md`](../../../raw/binaryen/2026-04-27-type-generalizing-primary-source-correction.md)
2. [`../../../raw/research/0421-2026-04-27-type-generalizing-source-correction-and-port-readiness.md`](../../../raw/research/0421-2026-04-27-type-generalizing-source-correction-and-port-readiness.md)
3. [`../../../raw/binaryen/2026-05-05-type-generalizing-current-main-recheck.md`](../../../raw/binaryen/2026-05-05-type-generalizing-current-main-recheck.md)
4. [`../../../raw/research/0479-2026-05-05-type-generalizing-current-main-recheck.md`](../../../raw/research/0479-2026-05-05-type-generalizing-current-main-recheck.md)
5. [`./binaryen-strategy.md`](./binaryen-strategy.md)
6. [`./type-requirements-cfg-and-unsupported-families.md`](./type-requirements-cfg-and-unsupported-families.md)
7. [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md)
