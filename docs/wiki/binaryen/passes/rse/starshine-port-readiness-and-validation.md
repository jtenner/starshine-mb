---
kind: concept
status: supported
last_reviewed: 2026-05-06
sources:
  - ../../../raw/research/0538-2026-05-06-rse-direct-revalidation.md
  - ../../../raw/binaryen/2026-05-05-rse-current-main-recheck.md
  - ../../../raw/research/0463-2026-05-05-rse-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-26-rse-cfg-source-correction.md
  - ../../../raw/research/0382-2026-04-26-rse-cfg-source-correction-and-port-readiness.md
  - ../../../../../src/passes/rse.mbt
  - ../../../../../src/passes/rse_test.mbt
  - ../../../../../src/passes/registry_test.mbt
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/cmd/cmd_wbtest.mbt
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
The 2026-05-05 current-main recheck keeps the same teaching split and only refreshes the provenance.

## Current readiness verdict

Starshine now has an **active direct `redundant-set-elimination` port**. The first landed slice is intentionally scoped to same-value local write shell removal and validation/signoff plumbing rather than the entire Binaryen refined-get surface.

The implemented surface:

- registers `redundant-set-elimination` as an active hot pass and CLI flag;
- keeps Binaryen `--rse` aliasing in the compare harnesses;
- removes same-value `local.set` shells as `drop(value)` and same-value `local.tee` shells as the original value;
- tracks simple value identities through constants, local copies, selected integer operations, and structured `if` agreement;
- uses a raw fast path for lowered functions plus a HOT fallback for direct hot-pass tests;
- keeps the direct `gen-valid` 10000-case lane and debug-artifact canonical function compare green.

Remaining full-parity work is still real:

- complete Binaryen-style fixed-point CFG merge values through loops and arbitrary diamonds;
- add strict-subtype equivalent-local `local.get` retargeting and any required refinalization;
- schedule the late no-DWARF slot only after the refined-get / tail-cleanup surface is proven.

## Exact local status

| Surface | Current state | Future action |
| --- | --- | --- |
| Registry | `src/passes/optimize.mbt:253-256` now has an active `"redundant-set-elimination"` hot-pass entry. | Keep it direct-only until the late preset slot is proven. |
| Dispatcher | `src/passes/pass_manager.mbt:7324-7334` dispatches `"redundant-set-elimination"` and has a raw fast path before hot lift. | Extend the raw/HOT implementations as refined-get and loop fixed-point support lands. |
| Owner file | `src/passes/rse.mbt:2-8`, `src/passes/rse.mbt:12-16`, and `src/passes/rse.mbt:692-700` own descriptor, summary, and raw rewrite helper. | Keep new behavior beside this owner with focused tests. |
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

- [x] Same-block repeated `local.set` positive.
- [x] Same-block repeated `local.tee` positive.
- [x] Different overwritten value negative.
- [x] RHS trap/effect preservation by replacing the shell, not the value expression.
- [x] Direct Binaryen `--rse` compare-pass lane: refreshed 2026-05-06 lane `.tmp/pass-fuzz-redundant-set-elimination` (`6759` comparable matches, `0` mismatches, `20` Binaryen-side empty-recursion-group command failures); older lanes `.tmp/pass-fuzz-rse-genvalid-10000-raw` (`10000/10000`) and `.tmp/pass-fuzz-rse-10000-raw` (`6759` comparable matches, `0` mismatches, `20` Binaryen-side command failures) remain historical evidence.
- [x] Generated-artifact direct replay: `.tmp/self-opt-rse-native-20260426b` has normalized WAT equality via fallback and canonical function equality.
- [x] 2026-05-05 current-main recheck stayed aligned with the same CFG/value-flow and refined-get split.
- [ ] Branch-join same-value positive beyond the simple structured raw/HOT cases.
- [ ] Branch-join different-value negative beyond the focused local tests.
- [ ] Loop convergence or conservative loop skip behavior documented and tested.
- [ ] Refined local-get retargeting with a strict-subtype local.
- [ ] No changes to globals, memory stores, struct stores, or array stores.
- [ ] Late `--rse --vacuum` lane.

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
