---
kind: concept
status: supported
last_reviewed: 2026-04-25
sources:
  - ../../../raw/binaryen/2026-04-25-dae2-primary-sources.md
  - ../../../raw/research/0337-2026-04-25-dae2-source-bridge.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/cmd/cmd.mbt
  - ../../../../../src/lib/types.mbt
  - ../../../../../src/validate/typecheck.mbt
  - ../../../../../src/validate/validate.mbt
  - ../../../../../src/wast/
  - ../../../../../agent-todo.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./fixed-point-forwarding-type-trees-and-expression-removal.md
  - ./wat-shapes.md
  - ../dead-argument-elimination/starshine-strategy.md
  - ../dae-optimizing/starshine-strategy.md
---

# Starshine strategy for `dae2`

## Current status

Starshine does **not** currently implement Binaryen's `dae2` pass.

This matters because the pass is not just a spelling variant of the existing local `dead-argument-elimination` boundary-only name. Upstream `dae2` is a separate experimental engine with backward forwarding-graph analysis and optional referenced function-type-tree rewriting. See the source-backed upstream summary in [`./binaryen-strategy.md`](./binaryen-strategy.md) and the immutable manifest in [`../../../raw/binaryen/2026-04-25-dae2-primary-sources.md`](../../../raw/binaryen/2026-04-25-dae2-primary-sources.md).

## Exact local code map

| Local surface | Current role for `dae2` | What to read |
| --- | --- | --- |
| `src/passes/optimize.mbt` | Registry source of truth. `dae2` is absent from active, boundary-only, removed, and preset names. Requests therefore take the `unknown pass flag` path in `run_hot_pipeline_expand_passes(...)`. | `pass_registry_boundary_only_names()`, `pass_registry_removed_names()`, `run_hot_pipeline_expand_passes(...)` |
| `src/passes/pass_manager.mbt` | Active module dispatcher. It handles the current implemented module-pass set only; there is no DAE/DAE2 signature-rewrite dispatcher case. | `run_module_pass(...)` |
| `src/cmd/cmd.mbt` | CLI and config plumbing. It reports unknown pass flags and already threads `closed_world` into `HotPipelineOptions`; that is a prerequisite, not a DAE2 implementation. | `cmd_error_message(...)`, `resolve_closed_world(...)`, optimizer option assembly |
| `src/lib/types.mbt` | Core module/IR representation. It already has function types and the call/reference instructions a future pass must analyze and rewrite. | `FuncType`, `Instruction::call`, `CallIndirect`, `CallRef`, `ReturnCall*`, `RefFunc` |
| `src/validate/typecheck.mbt` | Validation surface for direct calls, indirect calls, reference calls, and `ref.func` result typing. Useful for tests after any future rewrite. | `typecheck_call*`, `typecheck_call_ref`, `typecheck_ref_func` |
| `src/validate/validate.mbt` | Module-level validation of declared function references. Useful for the referenced-function and element/declaration boundaries. | declared-`ref.func` checks |
| `src/wast/` | Text parser/lowering surface for fixtures containing typed `ref.func` and element-segment references. | `keywords.mbt`, `parser.mbt`, `lower_to_lib.mbt`, `module_wast*.mbt` |
| `agent-todo.md` | Active backlog source. No dedicated `dae2` slice exists today. | Current parity/backlog sections |

## Request behavior today

Because `dae2` is not registered at all, the user-visible behavior differs from tracked-but-unimplemented DAE-family names:

- `dead-argument-elimination` is boundary-only in `src/passes/optimize.mbt`;
- `dead-argument-elimination-optimizing` is boundary-only in `src/passes/optimize.mbt`;
- `dae2` is unknown.

That means a future pass owner must decide whether to:

1. add `dae2` as an upstream-exact public name;
2. add a descriptive local alias; or
3. keep it upstream-only and leave the name unknown.

Until that choice is explicit, this wiki page should keep saying **unknown pass**, not boundary-only or removed.

## Why `dae2` is not a HOT peephole

A faithful local port would need module-wide analysis and rewrite machinery:

- function signature and local-index rewrites;
- direct-call argument rewrites;
- `call_ref` and `call_indirect` type-tree analysis;
- function-type replacement and global type-holder repair;
- public/root type, tag, continuation, JS-called, and `call.without.effects` blockers;
- effect-preserving expression removal;
- validation and refinalization after type changes.

The current HOT pass infrastructure is useful for local expression rewrites, but it is not enough by itself for the upstream `dae2` contract. The closer local building blocks are module-pass infrastructure plus the existing function/type/call representation and validator surfaces listed above.

## Beginner-to-advanced implementation roadmap

### 1. Name and scope decision

Decide whether Starshine wants upstream-exact `dae2` support. If yes, add a registry entry with an honest category before adding any preset placement.

Do **not** silently alias this to plain [`../dead-argument-elimination/index.md`](../dead-argument-elimination/index.md) or [`../dae-optimizing/index.md`](../dae-optimizing/index.md): upstream uses a different file and a different algorithm.

### 2. Direct unreferenced-function subset

The smallest useful subset would still need to:

- scan all function bodies;
- distinguish incoming params from overwritten local slots;
- build direct forwarding edges;
- compute the reverse fixed point;
- rewrite function params, locals, and direct-call operands;
- preserve side effects and control scaffolding around removed operands.

If this subset lands before referenced-function support, docs and tests must say it is **not full Binaryen `dae2` parity**.

### 3. Referenced function-type-tree mode

The hard upstream half requires `--closed-world` plus GC-like type infrastructure:

- group functions by root function-type tree;
- prove which parameter positions are used tree-wide;
- rewrite referenced function types and all holders;
- route unreferenced siblings through replacement types before the global rewrite;
- preserve public, tag, continuation, and intrinsic boundaries.

This is closer to future closed-world type-graph work than to current local DAE boundary tracking.

### 4. Validation and proof

A future implementation should validate at three layers:

- focused WAT fixtures mirroring [`./wat-shapes.md`](./wat-shapes.md);
- source-backed lit-family comparisons against Binaryen's `dae2.wast` positive and bailout clusters;
- direct request behavior tests proving `dae2` is no longer unknown only after a real owner exists.

## Non-goals to preserve

Current upstream `dae2` explicitly does **not** yet provide:

- dropped-result optimization;
- constant actual propagation;
- param/result type propagation.

Those features belong to the plain DAE-family pages today. If upstream grows them later, update [`./binaryen-strategy.md`](./binaryen-strategy.md), [`./wat-shapes.md`](./wat-shapes.md), and this page explicitly instead of implying parity from the shared name.

## Cross-links for the pass family

- [`./index.md`](./index.md) - `dae2` overview.
- [`./wat-shapes.md`](./wat-shapes.md) - concrete before/after families.
- [`./fixed-point-forwarding-type-trees-and-expression-removal.md`](./fixed-point-forwarding-type-trees-and-expression-removal.md) - core mechanics.
- [`./binaryen-strategy.md`](./binaryen-strategy.md) - upstream algorithm map.
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md) - source/test map.
- [`../dead-argument-elimination/index.md`](../dead-argument-elimination/index.md) - plain DAE sibling.
- [`../dae-optimizing/index.md`](../dae-optimizing/index.md) - optimizing DAE sibling.

## Sources

- Raw source manifest: [`../../../raw/binaryen/2026-04-25-dae2-primary-sources.md`](../../../raw/binaryen/2026-04-25-dae2-primary-sources.md)
- Research follow-up: [`../../../raw/research/0337-2026-04-25-dae2-source-bridge.md`](../../../raw/research/0337-2026-04-25-dae2-source-bridge.md)
- Starshine registry: [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- Starshine module dispatcher: [`../../../../../src/passes/pass_manager.mbt`](../../../../../src/passes/pass_manager.mbt)
- Starshine CLI/options: [`../../../../../src/cmd/cmd.mbt`](../../../../../src/cmd/cmd.mbt)
- Starshine core types: [`../../../../../src/lib/types.mbt`](../../../../../src/lib/types.mbt)
