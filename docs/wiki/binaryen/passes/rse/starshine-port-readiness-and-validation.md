---
kind: concept
status: supported
last_reviewed: 2026-05-10
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

Starshine now has an **active direct `redundant-set-elimination` port**. The current slice covers more of Binaryen's local value model but still is not the complete fixed-point CFG port.

The implemented surface:

- registers `redundant-set-elimination` as an active hot pass and CLI flag;
- keeps Binaryen `--rse` aliasing in the compare harnesses;
- removes same-value `local.set` shells as `drop(value)` and same-value `local.tee` shells as the original value;
- tracks simple value identities through constants, local copies, selected integer operations, structured `if` agreement, branch-disagreement merge sentinels for self-set folding, default body-local values, and fallthrough facts after one-armed terminating `if`s;
- retargets raw lowered `local.get` reads to an equivalent local with a strict subtype, covered by a reduced `anyref` / `eqref` fixture;
- uses a raw fast path for lowered functions plus a HOT fallback for direct hot-pass tests;
- relies on paired vacuum cleanup for pure `drop` / `nop` debris exposed by redundant set removal;
- keeps the direct compare-pass lane semantic-green.

Remaining full-parity work is still real:

- complete Binaryen-style fixed-point CFG merge values through arbitrary blocks and loops;
- broaden strict-subtype equivalent-local `local.get` retargeting to the official `rse-gc.wast` families and any required refinalization/writeback repair;
- classify or fix the `rse -> vacuum` cleanup-slot replay before scheduling the late no-DWARF slot.

## Exact local status

| Surface | Current state | Future action |
| --- | --- | --- |
| Registry | `src/passes/optimize.mbt:253-256` now has an active `"redundant-set-elimination"` hot-pass entry. | Keep it direct-only until the late preset slot is proven. |
| Dispatcher | `src/passes/pass_manager.mbt` dispatches `"redundant-set-elimination"`, builds a validation environment for raw subtype checks, and has a raw fast path before hot lift. | Extend the raw/HOT implementations as official GC fixtures and loop fixed-point support land. |
| Owner file | `src/passes/rse.mbt` owns descriptor, summary, raw value identities, branch merge sentinels, body-local default identities, and strict-subtype raw get retargeting. | Keep new behavior beside this owner with focused tests. |
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
- [x] Direct Binaryen `--rse` compare-pass lane: refreshed 2026-05-10 lane `.tmp/pass-fuzz-rse-rse002-next` (`6759/10000` compared, `6759` normalized matches, `0` mismatches, `20` Binaryen/tool command failures); prior `.tmp/pass-fuzz-rse-rse002`, 2026-05-06 `.tmp/pass-fuzz-redundant-set-elimination`, and older raw lanes remain historical evidence.
- [x] Generated-artifact direct replay: `.tmp/self-opt-rse-native-20260426b` has normalized WAT equality via fallback and canonical function equality.
- [x] 2026-05-05 current-main recheck stayed aligned with the same CFG/value-flow and refined-get split.
- [x] Branch-join same-value/self-set coverage for structured HOT and raw paths, including disagreement represented as a merge identity for self-set folding.
- [ ] Branch-join different-value negative beyond the focused local tests.
- [ ] Loop convergence or conservative loop skip behavior documented and tested.
- [x] Reduced refined local-get retargeting with a strict-subtype local (`anyref` read retargeted to equivalent `eqref`).
- [x] One-armed terminating `if` fallthrough facts preserve default-local identities before later loop conditions.
- [x] Paired vacuum removes nested pure `drop` / `nop` debris exposed by RSE in small value-expression control regions.
- [x] No changes to globals, memory stores, struct stores, or array stores.
- [ ] Late `--rse --vacuum` lane: 2026-05-10 replay at `.tmp/rse002-rse-vacuum-next2` remains red but moved to `defined=29 abs=46`; the former `defined=0 abs=17` nested `drop(...)` / `nop` debris is fixed, and the remaining visible delta is empty-then / double-`eqz` control-shape representation drift.

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
