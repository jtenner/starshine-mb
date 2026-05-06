---
kind: entity
status: supported
last_reviewed: 2026-05-06
sources:
  - ../../../raw/research/0538-2026-05-06-rse-direct-revalidation.md
  - ../../../raw/binaryen/2026-05-05-rse-current-main-recheck.md
  - ../../../raw/research/0463-2026-05-05-rse-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-26-rse-cfg-source-correction.md
  - ../../../raw/research/0382-2026-04-26-rse-cfg-source-correction-and-port-readiness.md
  - ../../../raw/binaryen/2026-04-25-rse-source-correction.md
  - ../../../raw/research/0348-2026-04-25-rse-source-correction-and-starshine-followup.md
  - ../../../raw/binaryen/2026-04-22-rse-primary-sources.md
  - ../../../raw/research/0259-2026-04-22-rse-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0114-2026-04-20-rse-binaryen-research.md
  - ../../../../../src/passes/rse.mbt
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/ir/use_def.mbt
  - ../../../../../src/ir/hot_module_context.mbt
  - ../../../../../agent-todo.md
  - ../../no-dwarf-default-optimize-path.md
related:
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./cfg-and-value-tracking.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
  - ../late-pipeline-dispatch.md
  - ../../no-dwarf-default-optimize-path.md
---

# `rse`

## Role

`rse` is Binaryen's public shorthand for `redundant-set-elimination`.
In the reviewed `version_129` source it is a **CFG-aware local value cleanup** pass:

- collect each basic block's `local.get`, `local.set`, and `local.tee` sites;
- flow one value-number fact per local through the function CFG;
- merge predecessor facts at block entries with block-specific merge value numbers;
- remove only same-value `local.set` / `local.tee` writes;
- retarget some `local.get`s to a more precise local that carries the same value number and a subtype-compatible reference type.

It is **not** a generic dead-store pass.
It does not delete memory stores, global stores, `struct.set`, `array.set`, or arbitrary overwritten local writes.
It also does not use Binaryen `LocalGraph` or liveness in `version_129`; the dataflow is the pass's own CFG/value-number flow.

## Why it matters

- The canonical Binaryen no-DWARF function pipeline runs `rse` very late, just before the final cleanup cluster.
- The saved generated-artifact `-O4z` audit records it as a real skipped upstream slot: top-level slot `46`.
- A 2026-05-05 current-main recheck stayed aligned with the corrected CFG/value-flow contract on the reviewed surfaces.
- A 2026-05-06 direct revalidation under the refreshed pass-fuzz harness reached 6759 comparable cases with 6759 normalized matches, 0 semantic mismatches, and 20 Binaryen empty-recursion-group command failures.
- Earlier local and structural cleanup passes can expose repeated same-value writes and equivalent local values; `rse` is the late pass that removes the redundant write shell.
- The following `vacuum` pass is part of the payoff because removed plain `local.set`s may become `drop(value)` debris.

## Beginner summary

A safe beginner mental model is:

1. Binaryen computes a small control-flow graph for the function.
2. At the start of each block, it knows which value number each local may hold, or that the value is unknown/merged.
3. Inside a block, if a `local.set` or `local.tee` writes a value number that the target local already has, the write shell is redundant.
4. The RHS still runs, so traps and side effects are preserved.
5. If two locals hold the same value number and one has a more precise reference type, a `local.get` can be retargeted to the refined local.

Do **not** read `rse` as “delete every overwritten write.”
A write of `1` followed by a write of `2` is not removed by this pass merely because it is overwritten.

## Inputs and outputs

### Inputs

- Binaryen function IR after earlier local, heap-store, and structural cleanup passes.
- A CFG view of the function's basic blocks and predecessor/successor edges.
- `LocalGet` and `LocalSet` / `local.tee` expressions collected per block.
- `ValueNumbering` support for expression identity and block merge values.
- `Properties::getFallthrough(...)` support for normalizing set RHS values that are wrapped in fallthrough-producing shapes.

### Outputs

- Redundant same-value `local.set` shells replaced with their RHS evaluation, usually as `drop(value)` when the RHS has a result.
- Redundant same-value `local.tee` shells replaced by the tee value.
- Some `local.get` indexes changed to a refined local with an equal value number and a stricter subtype.
- Conditional function refinalization when type-sensitive retargeting or tee replacement needs type repair.
- No module-element, global, memory, table, struct-field, or array-field removals.

## Correctness constraints

- Preserve RHS evaluation and traps for removed set/tee shells.
- Make CFG value flow converge through loops and diamonds; predecessor disagreement must become a merge value or unknown, not an unsound single predecessor fact.
- Do not remove a different-value overwritten write unless another pass proves it dead.
- Do not retarget a `local.get` unless the chosen local's static type is a strict subtype of the original local's static type and the value numbers agree.
- Refinalize when a rewritten expression may have a more specific type than its original use site.
- Keep the pass locals-only; global/memory/heap-field cleanup belongs elsewhere.

## Notable edge cases

- **Branch joins:** if both predecessor paths agree on a value number, later same-value sets can fold after the join. If real predecessors differ, Binaryen uses a merge value number rather than pretending one side wins.
- **Plain set vs tee:** `local.set` has no result, so Binaryen keeps the RHS evaluation through a `drop`-style replacement; `local.tee` already has the RHS result.
- **Copied locals:** a `local.set $b (local.get $a)` can cause `$a` and `$b` to carry the same value number; later gets may prefer the more precise typed local.
- **GC/ref types:** the dedicated GC test surface is about refined local-get retargeting and type safety, not field-store deletion.
- **Starshine status:** Starshine now exposes `"redundant-set-elimination"` as an active direct hot pass with a raw fast path and HOT fallback. The landed surface covers same-value `local.set` / `local.tee` shell removal, branch-local agreement for simple structured `if` cases, RHS preservation, CLI/registry/harness wiring, direct pass-fuzz parity, and debug-artifact canonical function parity. Refined strict-subtype `local.get` retargeting and preset scheduling remain follow-up work.

## Validation guidance

A future Starshine port should validate in this order:

1. direct same-block same-value `local.set` and `local.tee` reductions against Binaryen `--rse`;
2. branch/loop value-flow positives and negatives, including predecessor disagreement;
3. RHS trap/effect preservation for removed set shells;
4. GC/refined-local retargeting cases from Binaryen's `rse-gc.wast` surface;
5. direct `--rse` comparisons through the pass-fuzz harness;
6. late-cluster comparisons for `--rse --vacuum` or the no-DWARF tail where final debris cleanup matters.

## Supersession note

The 2026-04-26 source correction supersedes the 2026-04-25 overcorrection that described Binaryen `version_129` `rse` as a straight-line `PostWalker` with no CFG predecessor merge.
The current durable claim is:

> Binaryen `rse` is CFG-aware same-value local-set elimination plus refined local-get retargeting; it is not a `LocalGraph` / liveness / broad dead-store eliminator.

## Page map

- [`./binaryen-strategy.md`](./binaryen-strategy.md) - upstream CFG/value-flow strategy and algorithm boundaries.
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md) - owner files, registration, helpers, and official test surfaces.
- [`./cfg-and-value-tracking.md`](./cfg-and-value-tracking.md) - how block start/end values, merge values, and local retargeting work.
- [`./wat-shapes.md`](./wat-shapes.md) - beginner-friendly before/after and bailout shapes.
- [`./starshine-strategy.md`](./starshine-strategy.md) - current active direct-pass status, exact Starshine code-map anchors, and remaining faithful port map.
- [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md) - landed first-slice evidence, exact local registry/dispatcher/test anchors, remaining CFG/refined-get work, and validation ladder.

## Sources

- [`../../../raw/research/0538-2026-05-06-rse-direct-revalidation.md`](../../../raw/research/0538-2026-05-06-rse-direct-revalidation.md)
- [`../../../raw/binaryen/2026-05-05-rse-current-main-recheck.md`](../../../raw/binaryen/2026-05-05-rse-current-main-recheck.md)
- [`../../../raw/research/0463-2026-05-05-rse-current-main-recheck.md`](../../../raw/research/0463-2026-05-05-rse-current-main-recheck.md)
- [`../../../raw/binaryen/2026-04-26-rse-cfg-source-correction.md`](../../../raw/binaryen/2026-04-26-rse-cfg-source-correction.md)
- [`../../../raw/research/0382-2026-04-26-rse-cfg-source-correction-and-port-readiness.md`](../../../raw/research/0382-2026-04-26-rse-cfg-source-correction-and-port-readiness.md)
- Binaryen `version_129` pass source: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/RedundantSetElimination.cpp>
- Binaryen current-main pass source: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/RedundantSetElimination.cpp>
- Binaryen `version_129` pass tests: <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/rse_all-features.wast>
- Binaryen `version_129` GC tests: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/rse-gc.wast>
