---
kind: concept
status: supported
last_reviewed: 2026-06-02
sources:
  - ../../../raw/binaryen/2026-04-25-loop-invariant-code-motion-current-main-port-readiness.md
  - ../../../raw/binaryen/2026-06-02-loop-invariant-code-motion-current-main-recheck.md
  - ../../../raw/research/0378-2026-04-25-loop-invariant-code-motion-port-readiness.md
  - ../../../raw/research/0696-2026-06-02-loop-invariant-code-motion-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-24-loop-invariant-code-motion-primary-sources.md
  - ../../../raw/research/0282-2026-04-24-loop-invariant-code-motion-primary-sources-and-source-correction-followup.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/registry_test.mbt
  - ../../../raw/research/0063-2026-03-24-pass-port-batches-and-registry-map.md
  - ../../../raw/research/0065-2026-03-24-ir2-execution-plan.md
  - ../../../../../agent-todo.md
  - ../../no-dwarf-default-optimize-path.md
  - ../tracker.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./effects-loops-and-hoisting-rules.md
  - ./wat-shapes.md
  - ./starshine-port-readiness-and-validation.md
  - ../local-subtyping/index.md
  - ../flatten/index.md
  - ../code-pushing/index.md
  - ../local-cse/index.md
  - ../simplify-locals/index.md
---

# Starshine strategy for `loop-invariant-code-motion`

For the implementation-readiness sequence and reduced-test ladder, see [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md). This page stays focused on current in-tree status and local code locations.

## Current status

Starshine currently has **no active `loop-invariant-code-motion` implementation**.
The durable local status is preserved-name bookkeeping and honest rejection:

- [`../../../../../src/passes/optimize.mbt:144-151`](../../../../../src/passes/optimize.mbt) keeps `"loop-invariant-code-motion"` in `pass_registry_removed_names()`.
- [`../../../../../src/passes/optimize.mbt:98-106`](../../../../../src/passes/optimize.mbt) builds removed entries with category `HotPassRegistryCategory::removed()`, no descriptor, and no expansion.
- [`../../../../../src/passes/optimize.mbt:469-472`](../../../../../src/passes/optimize.mbt) rejects removed entries with the message shape `pass flag ... is removed from the active hot pipeline registry`.
- [`../../../../../src/passes/registry_test.mbt:171-179`](../../../../../src/passes/registry_test.mbt) tests the generic removed-name rejection path with `de-nan`; it does not contain a LICM-specific behavior regression because there is no local transform yet.
- [`../../../raw/research/0063-2026-03-24-pass-port-batches-and-registry-map.md`](../../../raw/research/0063-2026-03-24-pass-port-batches-and-registry-map.md) and [`../../../raw/research/0065-2026-03-24-ir2-execution-plan.md`](../../../raw/research/0065-2026-03-24-ir2-execution-plan.md) now list `loop-invariant-code-motion` in the current removed-name migration gap; `local-subtyping` is already an active module pass.
- [`../../../../../agent-todo.md`](../../../../../agent-todo.md) currently has no dedicated `loop-invariant-code-motion` or `licm` backlog slice.
- [`../../no-dwarf-default-optimize-path.md`](../../no-dwarf-default-optimize-path.md) does not list LICM in the current canonical no-DWARF optimize path.

## Exact code locations to follow

### Registry and request handling

- `src/passes/optimize.mbt`
  - `pass_registry_removed_names()` contains `loop-invariant-code-motion` at lines 144-151.
  - `pass_registry_entry_removed(...)` assigns removed entries category `Removed`, no descriptor, and no expansion at lines 98-106.
  - `pass_registry_entries()` appends removed entries after active and boundary-only names.
  - `run_hot_pipeline_expand_passes(...)` rejects `Removed` before dispatching any active pass at lines 469-472.

### Tests proving current behavior shape

- `src/passes/registry_test.mbt`
  - `pass registry classifies active, boundary-only, and removed names` proves removed-name classification through an existing removed-name sample.
  - `run_hot_pipeline rejects removed registry names` proves active request rejection for removed entries at lines 171-179.

### Planning references

- `../../../raw/research/0063-2026-03-24-pass-port-batches-and-registry-map.md`
  - The refreshed registry map lists `loop-invariant-code-motion` under removed names and lists `local-subtyping` under active module passes.
- `../../../raw/research/0065-2026-03-24-ir2-execution-plan.md`
  - The refreshed execution plan treats the old batch labels as historical context and lists `loop-invariant-code-motion` as a remaining removed hot/local gap.
- `agent-todo.md`
  - No active LICM slice was found in this run.

## Relationship to current Starshine infrastructure

A future port would likely need to compose with these existing concepts, but none of them is a LICM implementation today:

- HOT control regions and loop bodies, because Binaryen moves statements out of loop body prefixes.
- HOT effect / validation guards, because Binaryen's legality proof is effect-sensitive.
- Local-use analysis, use-def, or local SSA helpers, because Binaryen uses `LazyLocalGraph` to prove `local.get` dependencies do not come from loop-local sets.
- `nop` cleanup in neighboring passes, because Binaryen replaces moved loop-body slots with `nop` and relies on later cleanup opportunities.
- Neighbor dossiers such as [`../flatten/index.md`](../flatten/index.md), [`../code-pushing/index.md`](../code-pushing/index.md), [`../local-cse/index.md`](../local-cse/index.md), and [`../simplify-locals/index.md`](../simplify-locals/index.md), because LICM is easy to confuse with those passes but has a distinct direction and proof obligation.

## Porting strategy implied by Binaryen

A faithful first Starshine implementation should mirror the corrected Binaryen contract rather than the older temp-local overread.

### 1. Keep the naming split explicit

Binaryen users request `licm`.
Starshine currently tracks `loop-invariant-code-motion`.
A future compatibility decision must decide whether to add `licm` as an alias, rename the local spelling, or preserve both.
Until that decision is made, docs should mention both.

### 2. Start with loop-entry statement motion

The first local pass should target eligible none-result statements at the start of loop bodies.
Do not start by caching arbitrary invariant value expressions in fresh locals; that would implement a different pass than reviewed Binaryen `version_129` LICM.

### 3. Build loop-body summaries before rewriting

For each loop, Starshine needs conservative summaries equivalent to Binaryen's checked hazards:

- global-state effects,
- exception effects,
- control-transfer effects,
- mutable-state effects,
- loop-local `local.set`s,
- and local reads whose reaching sets are inside the loop.

### 4. Preserve the entrance-scan boundary

The scan should stop once control transfer is encountered.
This prevents hoisting statements that are not guaranteed to execute on loop entry.

### 5. Preserve local dependency safety

A future port needs a `LazyLocalGraph`-equivalent proof.
Possible local foundations include use-def and local SSA infrastructure, but this run did not choose an implementation API.
The design question is still open.

### 6. Emit cleanup-safe placeholders

Binaryen leaves `nop`s where statements moved out.
A Starshine port can either preserve explicit `nop` placeholders or use a different internal deletion shape, but it must be cleanup-safe and must not invalidate branch/region ownership invariants.

## Beginner-to-advanced mapping table

| Binaryen behavior | Starshine status today | Future Starshine implication |
| --- | --- | --- |
| public pass name `licm` | not registered locally | Decide alias policy before exposing a new pass flag. |
| local pass concept `loop-invariant-code-motion` | removed registry entry only | Keep honest request rejection until implementation lands. |
| loop discovery | no LICM owner file | Reuse HOT/IR2 loop-region traversal or wait for stronger IR2 loop APIs. |
| unconditional entry scan | no local implementation | Port as prefix statement motion, not whole-loop expression search. |
| `EffectAnalyzer` legality | no LICM-specific effect summary | Build conservative effect summary over HOT / module IR. |
| `LazyLocalGraph` local dependencies | no LICM-specific dependency proof | Reuse or extend use-def / local SSA helpers. |
| moved statement + `nop` placeholder | no local rewrite | Ensure HOT region splice / placeholder handling is validation-safe. |
| flattening helps expose candidates | `flatten` still unimplemented | Decide whether LICM waits for flatten-like work or handles only current HOT shapes first. |

## Open uncertainties

- The repo has no active backlog slice for this pass, so there is no committed local acceptance test set yet.
- It is not yet decided whether LICM should be a HOT pass, an IR2 pass, or a module/boundary pass with function-local rewriting.
- It is not yet decided whether a future port should expose upstream `licm` as an alias in addition to the local long name.
- It is not yet clear whether existing use-def / local SSA APIs are strong enough to replace Binaryen's `LazyLocalGraph` proof without adding new analysis surfaces.

## Current non-goals

Until implementation work starts, this page should not claim that Starshine:

- moves loop-invariant statements,
- has a LICM owner file,
- has a LICM parity test suite,
- or has a chosen `licm` alias policy.

The current in-tree behavior is removed-name tracking and request rejection only.

## Sources

- [`../../../raw/binaryen/2026-04-25-loop-invariant-code-motion-current-main-port-readiness.md`](../../../raw/binaryen/2026-04-25-loop-invariant-code-motion-current-main-port-readiness.md)
- [`../../../raw/binaryen/2026-06-02-loop-invariant-code-motion-current-main-recheck.md`](../../../raw/binaryen/2026-06-02-loop-invariant-code-motion-current-main-recheck.md)
- [`../../../raw/research/0378-2026-04-25-loop-invariant-code-motion-port-readiness.md`](../../../raw/research/0378-2026-04-25-loop-invariant-code-motion-port-readiness.md)
- [`../../../raw/research/0696-2026-06-02-loop-invariant-code-motion-current-main-recheck.md`](../../../raw/research/0696-2026-06-02-loop-invariant-code-motion-current-main-recheck.md)
- [`../../../raw/binaryen/2026-04-24-loop-invariant-code-motion-primary-sources.md`](../../../raw/binaryen/2026-04-24-loop-invariant-code-motion-primary-sources.md)
- [`../../../raw/research/0282-2026-04-24-loop-invariant-code-motion-primary-sources-and-source-correction-followup.md`](../../../raw/research/0282-2026-04-24-loop-invariant-code-motion-primary-sources-and-source-correction-followup.md)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../../../../../src/passes/registry_test.mbt`](../../../../../src/passes/registry_test.mbt)
- [`../../../raw/research/0063-2026-03-24-pass-port-batches-and-registry-map.md`](../../../raw/research/0063-2026-03-24-pass-port-batches-and-registry-map.md)
- [`../../../raw/research/0065-2026-03-24-ir2-execution-plan.md`](../../../raw/research/0065-2026-03-24-ir2-execution-plan.md)
- [`../../../../../agent-todo.md`](../../../../../agent-todo.md)
- [`../../no-dwarf-default-optimize-path.md`](../../no-dwarf-default-optimize-path.md)
- [`../tracker.md`](../tracker.md)
