---
kind: entity
status: supported
last_reviewed: 2026-07-18
sources:
  - https://github.com/WebAssembly/binaryen/blob/main/src/passes/RedundantSetElimination.cpp
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
  - ./transform-family-matrix.md
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
- A 2026-07-11 current-main reread supersedes the 2026-05-05 freshness claim and remains aligned with the corrected CFG/value-flow contract on the reviewed owner, registration, all-features, and GC/refinement surfaces.
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
- **Starshine status:** Starshine exposes `"redundant-set-elimination"` as an active direct hot pass with a raw fast path and HOT fallback. A 2026-07-21 parity repair adds a conservative post-rewrite unread-set cleanup: after value retargeting, newly unread body-local `local.set` shells become `drop` only for structured result producers or validator-approved strict concrete-reference copies from another body local. The RHS is preserved, parameter-source copies and all broader dead-store shapes remain unchanged, and `local.tee` result semantics are not widened. Reduced Binaryen-v131 cases 112 and 246 now replay exactly. The landed surface covers same-value `local.set` / `local.tee` shell removal, default body-local identities, structured branch agreement plus disagreement merge identities for self-set folding, raw structured block/if label-exit merge tracking with unreachable-tail skipping, GC conditional branch-exit tracking for `br_on_null` / `br_on_non_null` / `br_on_cast` / `br_on_cast_fail`, HOT block/if label-exit merge tracking with reachable fallthrough sources, branch-free loop fallthrough facts, conservative loop-backedge / outer-exit regressions, terminating one-armed `if` fallthrough facts, RHS preservation, raw strict-subtype equivalent-local `local.get` retargeting, identity-preserving refinement wrappers for `ref.as_non_null` / `ref.cast` / `ref.cast_desc_eq`, and raw `struct.get` / `struct.atomic.get` / `array.get` retargeting after redundant tee removal for `rse-gc.wast`-style refinalization families, plus raw `string.const` and `any.convert_extern` identities, conservative raw `try_table` fact barriers, loop untouched-local preservation, stable-entry backedge probes, post-loop source agreement, and unknown `local.get` identity materialization for local-copy equality. The 2026-07-05 official all-features replay closes the reopened `$loop`, `$merge`, `$many-merges`, and `$fuzz-nan` residuals with an empty Binaryen-vs-Starshine diff. CLI/registry/harness wiring, paired vacuum cleanup for nested pure debris, vacuum empty-then/live-else inversion, and direct pass-fuzz parity are also landed. On 2026-07-20, the public optimize/shrink registry and runtime rosters added the canonical late `heap-store-optimization -> redundant-set-elimination -> vacuum` tail immediately before one-based DAEO slot `48`; focused slot and execution tests are green. Broader official `rse-gc.wast` breadth remains future work; the latest `rse -> vacuum` residual is classified as an inherited direct-`vacuum` representation frontier rather than an RSE-specific blocker. The separate large-function pure-debris size gap exposed in `defined=518` was fixed in `vacuum` on 2026-05-11 without reopening RSE.

## Performance status

The 2026-07-05 timing probe in research note 1463 found that the official all-features fixture is too small/noisy for timing claims, so it generated larger RSE-heavy fixtures under `.tmp/rse-timing/`. The first post-audit run missed the direct pass-local target by 3.53x/4.12x on the 1000-function straight/loop-heavy fixtures and 7.00x/6.42x on the 3000-function probes.

The follow-up performance slices are complete for the user-requested 1x Binaryen target on those established fixtures. After integer value ids, numeric env elision, aggregated RSE trace output, combined loop summaries, and an i32-only raw fast path, `.tmp/rse-timing/rse-i32coded-final-1000-summary.json` records Starshine/Binaryen traced pass-local medians of 11.88/12.77 ms on `rse-straight-heavy-1000f.wasm` (0.93x) and 18.93/19.84 ms on `rse-loop-heavy-1000f.wasm` (0.95x). The 3000-function probe in `.tmp/rse-timing/rse-i32coded-3000-summary.json` also stays under Binaryen at 34.38/38.67 ms straight-heavy (0.89x) and 58.61/64.67 ms loop-heavy (0.91x). Decode, final validation, and encode remain separate `[WALL]001` owners unless a pass-local cause is demonstrated.

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
- [`./starshine-strategy.md`](./starshine-strategy.md) - current active direct-pass status, exact Starshine code-map anchors, and accepted direct-pass scope.
- [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md) - landed evidence, exact local registry/dispatcher/test anchors, accepted direct-pass scope, and validation ladder.
- [`./transform-family-matrix.md`](./transform-family-matrix.md) - live family-by-family audit ledger and current Binaryen/Starshine classification.

## Sources

- research note 1463
- research note 0538
- Binaryen current-main owner: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/RedundantSetElimination.cpp>
- research note 0463
- research note 0382
- Binaryen `version_129` pass source: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/RedundantSetElimination.cpp>
- Binaryen current-main pass source: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/RedundantSetElimination.cpp>
- Binaryen `version_129` pass tests: <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/rse_all-features.wast>
- Binaryen `version_129` GC tests: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/rse-gc.wast>
