---
kind: entity
status: supported
last_reviewed: 2026-04-25
sources:
  - ../../../raw/binaryen/2026-04-25-rse-source-correction.md
  - ../../../raw/research/0348-2026-04-25-rse-source-correction-and-starshine-followup.md
  - ../../../raw/binaryen/2026-04-22-rse-primary-sources.md
  - ../../../raw/research/0259-2026-04-22-rse-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0114-2026-04-20-rse-binaryen-research.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../agent-todo.md
  - ../../no-dwarf-default-optimize-path.md
related:
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./cfg-and-value-tracking.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../late-pipeline-dispatch.md
  - ../../no-dwarf-default-optimize-path.md
---

# `rse`

## Role

`rse` is Binaryen's public `redundant-set-elimination` pass.
In the reviewed `version_129` source it is a small **local-value-number cleanup** pass:

- remember the last value number known for each local;
- when a later `local.set` or `local.tee` writes the same value number to the same local, remove only the redundant set/tee shell;
- when a `local.get` sees a remembered expression whose type is more precise but still assignable, let value numbering reuse that more precise type;
- clear remembered facts conservatively at control-flow, local-state, and effect boundaries.

It is **not** a generic dead-store pass and it is not a LocalGraph/liveness pass in `version_129`.

## Why it matters

- The canonical Binaryen no-DWARF function pipeline runs `rse` very late, just before the final `vacuum` cluster.
- The saved generated-artifact `-O4z` audit records it as a real skipped upstream slot: top-level slot `46`.
- The pass matters even though it is small because repeated same-value locals appear after `simplify-locals`, `local-cse`, `merge-blocks`, and other late cleanups.
- The final `vacuum` pass is part of the payoff: Binaryen may turn a redundant plain `local.set` into `drop(value)`, and `vacuum` can later erase pure drops.

## Beginner summary

A safe beginner mental model is:

1. Binaryen keeps one “what value number does this local hold?” note per local.
2. If the next write to that local writes the same value number again, the write is redundant.
3. For `local.set`, Binaryen keeps the RHS evaluation and drops the set shell.
4. For `local.tee`, Binaryen keeps the produced value and drops only the tee shell.
5. When control flow or effects make the remembered note unsafe, Binaryen forgets it.

Do **not** read `rse` as “delete every overwritten write.”
A write of `1` followed by a write of `2` is not removed by this pass merely because it is overwritten.

## Inputs and outputs

### Inputs

- Binaryen function IR after earlier local, heap-store, and structural cleanup passes.
- `LocalGet` and `LocalSet` / `local.tee` expressions.
- Value-numbering support that can identify equivalent expression values and record refined expression types.

### Outputs

- Redundant same-value `local.set` shells replaced with their value expression, wrapped in `drop` when needed to preserve type/evaluation.
- Redundant same-value `local.tee` shells replaced by the tee value.
- Some `local.get` value-numbering facts refined to a more precise current expression type.
- No module-element, global, memory, table, struct-field, or array-field removals.

## Correctness constraints

- Preserve RHS evaluation and traps for removed set/tee shells.
- Do not reuse remembered local facts across barriers that can change local state, branch out of the current linear context, call unknown code, or otherwise invalidate the straight-line fact.
- Do not substitute a remembered expression for a `local.get` unless the expression type is a subtype of the get's static type.
- Refinalize after the pass so type changes caused by refined value-numbering facts remain valid.
- Rely on later `vacuum` for debris cleanup; `rse` itself should stay focused.

## Notable edge cases

- **Plain set vs tee:** `local.set` has no result, so Binaryen uses a `drop` wrapper when replacing a value-typed RHS; `local.tee` already has the RHS result.
- **Calls:** ordinary calls clear all remembered local facts because of possible local-state/global side effects, but Binaryen preserves a fact for a tail-call result under the narrow local-set case described in the source.
- **Loops and diamonds:** the pass does not compute predecessor joins; it forgets facts instead of inventing loop or merge precision.
- **GC/ref types:** the dedicated GC lit surface is about refined local-get typing, not field-store deletion.
- **Unimplemented Starshine status:** the local registry still tracks only `redundant-set-elimination` as a removed name; there is no active `rse` implementation yet.

## Validation guidance

A future Starshine port should validate in this order:

1. direct same-value `local.set` and `local.tee` reductions against Binaryen `--rse`;
2. RHS trap/effect preservation for removed set shells;
3. control/effect barrier negatives where facts must be cleared;
4. GC/refinement cases from Binaryen's `rse-gc.wast` surface;
5. late-cluster comparisons for `--rse --vacuum` or the no-DWARF tail where final debris cleanup matters.

## Supersession note

The 2026-04-25 source correction supersedes older local wiki claims that `version_129` `rse` used `LocalGraph`, liveness, copied-local inheritance, same-block read rewriting, CFG predecessor merges, or broad overwritten-write deletion.
Those older notes remain useful provenance, but the source-backed contract is now the smaller value-numbered same-value cleanup described here.

## Page map

- [`./binaryen-strategy.md`](./binaryen-strategy.md) - corrected upstream strategy and algorithm boundaries.
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md) - owner files, registration, helpers, and official test surfaces.
- [`./cfg-and-value-tracking.md`](./cfg-and-value-tracking.md) - why the pass is straight-line value-number tracking plus conservative invalidation, not predecessor dataflow.
- [`./wat-shapes.md`](./wat-shapes.md) - beginner-friendly before/after and bailout shapes.
- [`./starshine-strategy.md`](./starshine-strategy.md) - current local removed-name status and faithful future port map.

## Sources

- [`../../../raw/binaryen/2026-04-25-rse-source-correction.md`](../../../raw/binaryen/2026-04-25-rse-source-correction.md)
- [`../../../raw/research/0348-2026-04-25-rse-source-correction-and-starshine-followup.md`](../../../raw/research/0348-2026-04-25-rse-source-correction-and-starshine-followup.md)
- Binaryen `version_129` pass source: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/RedundantSetElimination.cpp>
- Binaryen `version_129` pass registry/scheduler: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- Binaryen `version_129` GC tests: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/rse-gc.wast>
- Binaryen `version_129` pass tests: <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/rse_all-features.wast>
