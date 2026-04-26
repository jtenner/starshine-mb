---
kind: concept
status: supported
last_reviewed: 2026-04-26
sources:
  - ../../../raw/binaryen/2026-04-26-rse-cfg-source-correction.md
  - ../../../raw/research/0382-2026-04-26-rse-cfg-source-correction-and-port-readiness.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/ir/use_def.mbt
  - ../../../../../src/ir/hot_module_context.mbt
  - ../../../../../src/ir/ssa_local.mbt
  - ../../../../../agent-todo.md
  - ../../no-dwarf-default-optimize-path.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./cfg-and-value-tracking.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../local-cse/index.md
  - ../vacuum/index.md
---

# Starshine `rse` Port Readiness And Validation

This page turns the corrected Binaryen source read into a future implementation checklist.
It should be read after [`./binaryen-strategy.md`](./binaryen-strategy.md) and [`./cfg-and-value-tracking.md`](./cfg-and-value-tracking.md).

## Current readiness verdict

Starshine is **not ready to flip `redundant-set-elimination` on by wiring alone**.
The registry and dispatcher gaps are simple, but a faithful port also needs a pass-local CFG/value-number flow or an equivalent HOT substrate.

The minimum implementation is still small compared with `local-cse` or a full dataflow optimizer, but it is larger than a straight-line peephole:

- collect local get/set/tee sites by block;
- compute block start/end local value identities;
- converge through loops and diamonds;
- remove same-value set/tee shells;
- retarget subtype-safe equivalent local gets;
- refinalize or otherwise validate type-sensitive rewrites.

## Exact local status

| Surface | Current state | Future action |
| --- | --- | --- |
| Registry | [`src/passes/optimize.mbt:144-152`](../../../../../src/passes/optimize.mbt) lists `"redundant-set-elimination"` in `pass_registry_removed_names()`. | Move it to an active hot-pass entry once tests exist. Decide whether `rse` is accepted as an alias. |
| Dispatcher | [`src/passes/pass_manager.mbt:8685-8705`](../../../../../src/passes/pass_manager.mbt) has no `rse` arm. | Add a pass-manager arm after the owner file lands. |
| Owner file | No `src/passes/rse.mbt` or `src/passes/redundant_set_elimination.mbt`. | Add a dedicated owner rather than hiding the pass in `pass_manager.mbt`. |
| HOT local surfaces | [`src/ir/use_def.mbt:1-120`](../../../../../src/ir/use_def.mbt) records local reads/writes, but no value-number CFG flow. | Reuse only the collection pieces that fit; add explicit value identity and merge logic. |
| Type context | [`src/ir/hot_module_context.mbt:1-58`](../../../../../src/ir/hot_module_context.mbt) and later helpers expose module subtype/function type context. | Use this for strict-subtype retargeting checks. |
| Backlog | [`agent-todo.md:481-491`](../../../../../agent-todo.md) tracks `RSE`. | Keep the backlog aligned with this CFG-aware contract. |

## First viable slice

The first green slice should be intentionally limited:

1. Add reduced tests for same-block repeated `local.set` and `local.tee`.
2. Build a tiny value identity table for straight-line blocks.
3. Preserve RHS evaluation by replacing removed plain sets with drop-compatible RHS shapes.
4. Wire registry and dispatcher only after those tests fail for the right reason.
5. Compare direct output with Binaryen `--rse` on those reduced cases.

This first slice is allowed to conservatively skip branch/loop facts, as long as the docs and tests mark that as a temporary subset.
Do not claim full Binaryen parity until the CFG merge behavior below is covered.

## Full parity slices

### Slice 2: CFG value flow

Add block start/end facts and a convergence loop that can model:

- one-predecessor fact copying;
- multi-predecessor agreement;
- multi-predecessor disagreement through merge identities;
- loop-carried convergence or conservative loop skip behavior with explicit tests.

Positive and negative tests should include the branch-join examples in [`./wat-shapes.md`](./wat-shapes.md).

### Slice 3: refined `local.get` retargeting

Add same-value local maps and strict-subtype checks for reference locals.
Use Binaryen `rse-gc.wast` as the oracle family.
The rewritten operation should be a local-index retarget, not expression cloning.

### Slice 4: final cleanup and scheduling proof

Compare:

- direct `--rse`;
- `--rse --vacuum`;
- the historical no-DWARF late tail around slot `46`.

Only then should the pass enter public preset scheduling.

## Validation checklist

- [ ] Same-block repeated `local.set` positive.
- [ ] Same-block repeated `local.tee` positive.
- [ ] Different overwritten value negative.
- [ ] RHS trap/effect preservation positive.
- [ ] Branch-join same-value positive.
- [ ] Branch-join different-value negative.
- [ ] Loop convergence or conservative loop skip behavior documented and tested.
- [ ] Refined local-get retargeting with a strict-subtype local.
- [ ] No changes to globals, memory stores, struct stores, or array stores.
- [ ] Direct Binaryen `--rse` compare-pass lane.
- [ ] Late `--rse --vacuum` lane.
- [ ] Generated-artifact no-DWARF slot replay.

## Open design questions

- Should the public CLI accept both `redundant-set-elimination` and `rse`, or only the long upstream spelling already tracked locally?
- Should value identity be pass-local and structural, or should it be a shared HOT utility for later passes?
- How should merge identities be represented so loops converge without conflating genuinely different values?
- What is the smallest safe refinalization/writeback repair after refined local-get retargeting?

## Non-goals for the first port

- Liveness dead-store elimination.
- `LocalGraph` parity.
- Memory/global/heap-field store deletion.
- Generic expression substitution for local gets.
- Preset scheduling before direct pass parity.
