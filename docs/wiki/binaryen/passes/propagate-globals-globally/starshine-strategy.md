---
kind: concept
status: supported
last_reviewed: 2026-04-24
sources:
  - ../../../raw/binaryen/2026-04-24-propagate-globals-globally-primary-sources.md
  - ../../../raw/research/0320-2026-04-24-propagate-globals-globally-source-correction-and-starshine-followup.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/lib/types.mbt
  - ../../../../../src/validate/validate.mbt
  - ../../../../../src/wast/parser.mbt
  - ../../../../../src/wast/lower_to_lib.mbt
  - ../../../../../src/binary/encode.mbt
  - ../../../../../src/binary/decode.mbt
  - ../../../../../agent-todo.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./shared-engine-and-startup-boundaries.md
  - ./wat-shapes.md
  - ../simplify-globals/index.md
  - ../simplify-globals-optimizing/index.md
---

# Starshine strategy for `propagate-globals-globally`

## Current status

Starshine currently has **no implementation** of `propagate-globals-globally`.

The exact local behavior is:

- the name is present in the boundary-only registry
- explicit requests are rejected before pass execution
- the pass is omitted from the active `optimize` and `shrink` presets
- there is no module-dispatcher case
- there is no owner file
- there is no active backlog slice in `agent-todo.md`

## Exact code map

| Local file | What to read | Why it matters |
| --- | --- | --- |
| [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt) | `pass_registry_boundary_only_names()` includes `propagate-globals-globally`. | Source of truth for current boundary-only status. |
| [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt) | `optimize_preset_passes(...)` and `shrink_preset_passes(...)`. | The pass has no active preset role. |
| [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt) | `run_hot_pipeline_expand_passes(...)`. | Boundary-only requests return the standard not-implemented error before dispatch. |
| [`../../../../../src/passes/pass_manager.mbt`](../../../../../src/passes/pass_manager.mbt) | `run_hot_pipeline_apply_module_pass(...)`. | There is no module-pass case for this name. |
| [`../../../../../src/lib/types.mbt`](../../../../../src/lib/types.mbt) | `GlobalSec`, `Global`, `Expr`, `ElemSec`, `DataSec`, `ElemMode`, `DataMode`, `Instruction::GlobalGet`. | These are the structural surfaces a future module pass would rewrite. |
| [`../../../../../src/validate/validate.mbt`](../../../../../src/validate/validate.mbt) | constant-expression validation, immutable-global `global.get` checks, active data/elem offset checks. | These validators define important safety boundaries for tests and future rewrites. |
| [`../../../../../src/wast/parser.mbt`](../../../../../src/wast/parser.mbt) and [`../../../../../src/wast/lower_to_lib.mbt`](../../../../../src/wast/lower_to_lib.mbt) | global declarations, `global.get`, active segments, and WAT-to-lib lowering. | These make focused WAT fixtures possible for future TDD. |
| [`../../../../../src/binary/encode.mbt`](../../../../../src/binary/encode.mbt) and [`../../../../../src/binary/decode.mbt`](../../../../../src/binary/decode.mbt) | global, elem, and data section roundtrip code. | A module rewrite must stay encodable and decodable. |
| [`../../../../../agent-todo.md`](../../../../../agent-todo.md) | backlog search. | No dedicated slice exists as of 2026-04-24. |

## Why this should be a module pass, not a HOT pass

Binaryen's public pass rewrites module-level startup expressions:

- global initializers
- active element offsets
- active data offsets

It deliberately does not walk ordinary function bodies. Starshine's HOT pipeline is function-local and is the wrong home for a faithful first port. A future implementation should be a module pass beside existing module passes such as `global-refining`, `global-struct-inference`, `memory-packing`, and `once-reduction`.

## Future port outline

A conservative Starshine port could land in small TDD slices:

1. **Registry change**
   - move `propagate-globals-globally` from boundary-only to module-pass registration only when implementation tests exist
   - add a dispatcher case in `run_hot_pipeline_apply_module_pass(...)`
2. **Known-global collection**
   - scan defined globals in declaration order
   - record values only for initializers the local validator / helper layer can prove are constant expressions
   - avoid knowing imported global runtime values
3. **Global initializer substitution**
   - replace `global.get` uses inside later global initializer expressions when the target has a recorded literal expression
   - preserve type and validation invariants
4. **Active segment offsets**
   - apply the same substitution to active `ElemMode` offsets
   - apply the same substitution to active `DataMode` offsets
5. **Negative boundaries**
   - do not rewrite function bodies
   - do not rewrite mutable-global values
   - do not touch passive/declarative segment payloads except through existing validation-preserving structure
6. **Parity signoff**
   - compare against `wasm-opt --propagate-globals-globally`
   - only consider preset scheduling if a broader global-pass strategy later justifies it

## Tests a future implementation should add first

Use TDD and start with failing tests before implementation:

- direct immutable-global chain positive
- arithmetic constant-expression chain positive
- active data offset positive
- active elem offset positive
- function-body `global.get` remains unchanged
- mutable-global or unknown-value negative
- imported-global no-known-literal caveat
- passive/declarative segment no-op

## Differences from Binaryen to preserve explicitly

The important behavior to preserve is not exact internal helper naming. It is the public contract:

- only startup/module-level propagation
- literal/constant-expression-backed facts
- active segment offset rewrites
- no ordinary function-body propagation

If Starshine later implements `simplify-globals`, that sibling may share helpers and rewrite function bodies. The two public pass contracts should remain separately testable.

## Current limitation statement for users

Today, `--pass propagate-globals-globally` is a recognized but boundary-only name in Starshine. It is useful for registry honesty and future planning, but not for optimization. Users should expect the standard boundary-only rejection until a real module pass lands.
