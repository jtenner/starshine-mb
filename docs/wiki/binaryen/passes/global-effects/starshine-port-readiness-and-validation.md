---
kind: concept
status: supported
last_reviewed: 2026-05-05
sources:
  - ../../../raw/binaryen/2026-05-05-global-effects-current-main-recheck.md
  - ../../../raw/research/0480-2026-05-05-global-effects-current-main-recheck.md
  - ../../../raw/binaryen/2026-05-05-global-effects-current-main-line-anchor-refresh.md
  - ../../../raw/research/0490-2026-05-05-global-effects-current-main-line-anchor-refresh.md
  - ../../../raw/binaryen/2026-05-04-global-effects-current-main-recheck.md
  - ../../../raw/research/0438-2026-05-04-global-effects-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-27-global-effects-port-readiness-primary-sources.md
  - ../../../raw/research/0417-2026-04-27-global-effects-port-readiness.md
  - ../../../raw/binaryen/2026-04-24-global-effects-primary-sources.md
  - ../../../raw/binaryen/2026-04-25-discard-global-effects-primary-sources.md
  - ./index.md
  - ./binaryen-strategy.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/cli/cli_test.mbt
  - ../../../../../src/ir/effects.mbt
  - ../../../../../src/ir/analysis_cache.mbt
  - ../../../../../src/passes/pass_common.mbt
  - ../../../../../src/lib/types.mbt
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./metadata-naming-and-consumers.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../discard-global-effects/index.md
  - ../vacuum/index.md
  - ../simplify-locals/index.md
  - ../tracker.md
---

# Starshine port-readiness and validation for `global-effects`

## Current local hold point

`global-effects` is still a **boundary-only** Starshine compatibility name. The local code accepts the spelling but refuses to run a transform, and the 2026-05-05 current-main recheck did not change that hold point:

- [`src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt) lines 127-137 include `global-effects` in `pass_registry_boundary_only_names()`.
- [`src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt) lines 481-487 reject boundary-only pass requests during expansion.
- [`src/cli/cli_test.mbt`](../../../../../src/cli/cli_test.mbt) lines 207-210 prove `--global-effects` parses to the pass flag.
- [`src/passes/pass_manager.mbt`](../../../../../src/passes/pass_manager.mbt) lines 8661-8687 show the active module-pass dispatcher; there is no `global-effects` arm.
- No `src/passes/global_effects.mbt` owner file exists today.

That status is correct. Binaryen's `generate-global-effects` is a module-level metadata producer, so a HOT peephole under this name would be misleading.

## First implementation slice: no-rewrite analyzer

The safest first Starshine slice should not try to make `vacuum` or movement passes less conservative immediately. Start with a module analysis whose observable test surface is the summary itself.

Minimum scanner responsibilities:

1. map absolute function indices to imports versus defined bodies
2. scan each defined body for direct `call` / `return_call` edges
3. mark `call_indirect`, `return_call_indirect`, `call_ref`, `return_call_ref`, imported calls, and unknown bodies conservatively
4. record direct `global.get` and `global.set` facts separately
5. record trap/throw/call unknown flags without dropping them during propagation

Local source surfaces already available:

- [`src/lib/types.mbt`](../../../../../src/lib/types.mbt) lines 527-540 define direct calls, indirect calls, `call_ref`, return-call variants, and global get/set instructions.
- [`src/ir/effects.mbt`](../../../../../src/ir/effects.mbt) lines 5-32 define the current coarse effect bits.
- [`src/ir/effects.mbt`](../../../../../src/ir/effects.mbt) lines 133-148 map HOT global, memory, and table operations to those bits.

Important caveat: the current HOT `EFFECT_MASK_GLOBAL_STATE` bit is too coarse for full Binaryen parity. A faithful consumer needs at least separate global-read and global-write sets, not just “some global state happened.”

## Summary model requirements

A useful local summary should be module-level and per-function. It should not reuse the current HOT cache as if that were already Binaryen-compatible metadata.

Required fields for a first useful model:

- reads: set of global indices read by this function or its known callees
- writes: set of global indices written by this function or its known callees
- callsUnknown: whether the function crosses an imported, indirect, `call_ref`, or otherwise opaque call boundary
- mayTrap or recursionConservative: enough information to preserve Binaryen's recursive-cycle conservatism
- directCallees: defined callees used by the solver

Local cache surfaces to reuse carefully:

- [`src/ir/analysis_cache.mbt`](../../../../../src/ir/analysis_cache.mbt) lines 19-23 define `HotEffectsSummary`, but it is node/block/root-region mask data for one HOT function.
- [`src/ir/analysis_cache.mbt`](../../../../../src/ir/analysis_cache.mbt) lines 70-85 build those summaries from one function and CFG.
- [`src/ir/analysis_cache.mbt`](../../../../../src/ir/analysis_cache.mbt) lines 217-227 cache those summaries by HOT revision.
- [`src/passes/pass_common.mbt`](../../../../../src/passes/pass_common.mbt) lines 318-338 expose `pass_require_effects(...)` for function-local HOT passes.

Those are useful patterns for invalidation and performance counters, but not a substitute for persistent module-level global-effect summaries.

## Solver choices

There are two defensible solver targets:

1. **Tagged `version_129` parity target**: mirror the older reachability/deferred propagation structure described in [`./binaryen-strategy.md`](./binaryen-strategy.md).
2. **Current-main structure target**: implement call-graph SCC/component propagation, then compare behavior against tagged and current Binaryen in paired consumer tests.

The recommended local first slice is SCC-shaped because it is easier to test for cycles and matches current upstream structure. If Starshine uses that route while comparing to a `version_129` oracle, document it as an implementation-shape difference with the same semantic contract.

## Registry and dispatcher sequencing

Do not move `global-effects` out of boundary-only status until the no-rewrite analyzer and validation hooks exist.

When the first real slice lands, the minimum code changes should include:

- a new owner file such as `src/passes/global_effects.mbt`
- registry category change in [`src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- a dispatcher arm in [`src/passes/pass_manager.mbt`](../../../../../src/passes/pass_manager.mbt) lines 8669-8685
- tests that prove explicit `--global-effects` no longer fails only after real summaries exist
- no default `optimize` / `shrink` preset scheduling unless a later consumer payoff is also proven

## Consumer sequencing

Only after summary production is stable should a follow-up slice make consumers use the metadata.

Good first consumers:

- [`../vacuum/index.md`](../vacuum/index.md), because upstream has `vacuum-global-effects.wast` proof that generated summaries can make unused calls removable.
- [`../simplify-locals/index.md`](../simplify-locals/index.md), because upstream has `global-effects_simplify-locals.wast` proof that global read/write precision affects local movement.

Do not fold consumer rewrites into the producer pass. The visible before/after belongs to the downstream pass; `global-effects` only produces the facts.

## Validation ladder

### Analyzer-only tests

- direct global reader: summary reads `$g`, writes nothing
- direct global writer: summary writes `$g`
- wrapper chain: outer function inherits callee reads/writes
- imported call: summary marks unknown effects conservatively
- indirect / `call_ref`: summary marks unknown effects conservatively until a precise target model exists
- recursion: SCC members converge without being treated as acyclic one-shot wrappers

### Registry tests

- before implementation: `--global-effects` still parses but expansion rejects boundary-only execution
- after implementation: `pass_registry_category("global-effects")` becomes module-pass and dispatcher support exists
- no accidental preset scheduling until consumer payoff is intentionally enabled

### Binaryen oracle tests

Use paired pipelines because standalone `generate-global-effects` often has no textual WAT diff:

- `wasm-opt --generate-global-effects --vacuum`
- `wasm-opt --generate-global-effects --simplify-locals`
- negative comparisons where `--vacuum` or `--simplify-locals` alone must remain more conservative

For Starshine fuzzing, compare the paired consumer pipeline rather than expecting a standalone metadata pass to normalize into a different text module.

## Main risks

- **Over-coarse global effects:** the current local `EFFECT_MASK_GLOBAL_STATE` cannot distinguish `$a` reads from `$b` writes.
- **Stale summaries:** any mutating pass that changes calls, globals, or function bodies can invalidate stored summaries.
- **Opaque calls:** imports, indirect calls, and `call_ref` must remain conservative until proven otherwise.
- **False visible-diff expectations:** a green standalone text diff proves very little for this pass.
- **Scheduler overreach:** upstream does not run `generate-global-effects` in the default optimize pipeline today, so Starshine should not add it to presets without new evidence.

## Definition of done for a faithful first local port

A first local implementation is worth calling `global-effects` only when it has:

- a module-level owner file
- registry and dispatcher support
- per-function stored summaries with separate global read/write facts
- conservative unknown-call and recursion handling
- analyzer-only tests for direct, transitive, opaque, and recursive cases
- at least one paired downstream validation lane against Binaryen
- explicit invalidation or discard story for later mutating passes

Until then, keep the local boundary-only status described in [`./starshine-strategy.md`](./starshine-strategy.md).

## Sources

- [`../../../raw/binaryen/2026-05-05-global-effects-current-main-recheck.md`](../../../raw/binaryen/2026-05-05-global-effects-current-main-recheck.md)
- [`../../../raw/research/0480-2026-05-05-global-effects-current-main-recheck.md`](../../../raw/research/0480-2026-05-05-global-effects-current-main-recheck.md)
- [`../../../raw/binaryen/2026-05-05-global-effects-current-main-line-anchor-refresh.md`](../../../raw/binaryen/2026-05-05-global-effects-current-main-line-anchor-refresh.md)
- [`../../../raw/research/0490-2026-05-05-global-effects-current-main-line-anchor-refresh.md`](../../../raw/research/0490-2026-05-05-global-effects-current-main-line-anchor-refresh.md)
- [`../../../raw/binaryen/2026-05-04-global-effects-current-main-recheck.md`](../../../raw/binaryen/2026-05-04-global-effects-current-main-recheck.md)
- [`../../../raw/research/0438-2026-05-04-global-effects-current-main-recheck.md`](../../../raw/research/0438-2026-05-04-global-effects-current-main-recheck.md)
- [`../../../raw/binaryen/2026-04-27-global-effects-port-readiness-primary-sources.md`](../../../raw/binaryen/2026-04-27-global-effects-port-readiness-primary-sources.md)
- [`../../../raw/research/0417-2026-04-27-global-effects-port-readiness.md`](../../../raw/research/0417-2026-04-27-global-effects-port-readiness.md)
- [`./index.md`](./index.md)
- [`./binaryen-strategy.md`](./binaryen-strategy.md)
- [`./wat-shapes.md`](./wat-shapes.md)
- [`./starshine-strategy.md`](./starshine-strategy.md)
