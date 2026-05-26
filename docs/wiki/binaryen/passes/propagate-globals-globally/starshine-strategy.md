---
kind: concept
status: supported
last_reviewed: 2026-05-05
sources:
  - ../../../raw/binaryen/2026-04-24-propagate-globals-globally-primary-sources.md
  - ../../../raw/binaryen/2026-05-05-propagate-globals-globally-current-main-recheck.md
  - ../../../raw/research/0320-2026-04-24-propagate-globals-globally-source-correction-and-starshine-followup.md
  - ../../../raw/research/0459-2026-05-05-propagate-globals-globally-current-main-recheck.md
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

Starshine now implements `propagate-globals-globally` as an active module pass through the shared SGO owner. The 2026-05-26 `[SGO]003H` slice in [`0699`](../../../raw/research/0699-2026-05-26-sgo-shared-family-exposure.md) moved it out of boundary-only status.

The exact local behavior is:

- the name is present as an active module-pass registry entry
- explicit requests dispatch through `run_hot_pipeline_apply_module_pass(...)`
- the pass is omitted from the active `optimize` and `shrink` presets
- the implementation owner is `src/passes/simplify_globals_optimizing.mbt`, via a startup-only core wrapper
- startup/global expressions are rewritten, while ordinary function bodies are preserved
- single-use complex-initializer inlining is disabled for this sibling to match Binaryen's startup-only boundary

## Exact code map

| Local file | What to read | Why it matters |
| --- | --- | --- |
| [`src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt) | `pass_registry_entries()` includes `propagate-globals-globally` as a module pass. | Source of truth for current active status. |
| [`src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt) | `optimize_preset_passes(...)` and `shrink_preset_passes(...)`. | The pass has no active preset role. |
| [`src/passes/pass_manager.mbt`](../../../../../src/passes/pass_manager.mbt) | `run_hot_pipeline_apply_module_pass(...)`. | Dispatches the name to the startup-only SGO wrapper. |
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

## Implemented shape

The active Starshine wrapper:

1. scans globals and startup/module-level global reads using the shared SGO fact collector;
2. rewrites later global initializers, table initializers, active element/data offsets, and exact typed element item expressions through the existing startup propagation helpers;
3. skips function-body rewriting entirely;
4. skips optimizing nested cleanup entirely;
5. disables single-use complex-initializer inlining for this startup-only sibling; and
6. compares green against `wasm-opt --propagate-globals-globally` in the direct 10k fuzz lane recorded in `0699`.

## Tests to preserve

Keep focused tests for:

- active module-pass registration;
- direct immutable-global chain propagation;
- startup expression propagation with function-body `global.get` preserved;
- no single-use inlining of complex initializer expressions;
- imported/global/value-type guardrails inherited from the SGO startup tests; and
- direct pass-fuzz comparison against Binaryen.

## Differences from Binaryen to preserve explicitly

The important behavior to preserve is not exact internal helper naming. It is the public contract:

- only startup/module-level propagation
- literal/constant-expression-backed facts
- active segment offset rewrites
- no ordinary function-body propagation

If Starshine later implements `simplify-globals`, that sibling may share helpers and rewrite function bodies. The two public pass contracts should remain separately testable.

## Current limitation statement for users

`--pass propagate-globals-globally` is active, but intentionally narrower than `simplify-globals`: it rewrites startup/global expressions and active segment offsets, not ordinary function bodies or optimizing cleanup.
