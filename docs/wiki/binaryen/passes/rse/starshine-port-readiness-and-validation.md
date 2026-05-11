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

Starshine now has an **accepted active direct `redundant-set-elimination` port** for v0.1.0. The direct slice covers the known CFG/value-flow and refined-get parity surface without becoming a full general fixed-point CFG implementation.

The implemented surface:

- registers `redundant-set-elimination` as an active hot pass and CLI flag;
- keeps Binaryen `--rse` aliasing in the compare harnesses;
- removes same-value `local.set` shells as `drop(value)` and same-value `local.tee` shells as the original value;
- tracks simple value identities through constants including raw `string.const`, `any.convert_extern`, local copies, selected integer operations, structured `if` agreement, branch-disagreement merge sentinels for self-set folding, raw block/if label-exit merges, HOT block/if label-exit merges, branch-free loop fallthrough facts, a safe loop-invariant default-write subset for loops with backedges, default body-local values, fallthrough facts after one-armed terminating `if`s, and identity-preserving refinement wrappers such as `ref.as_non_null` / `ref.cast` / `ref.cast_desc_eq`;
- retargets raw lowered `local.get` reads to an equivalent local with a strict subtype, now covered by a reduced `anyref` / `eqref` fixture, concrete-heap `ref.as_non_null` straight-line / branch-merge fixtures, programmatic `ref.cast` / `ref.cast_desc_eq` wrapper fixtures for parser-gap-free coverage, and `needs-refinalize`-style `struct.get` / `array.get` receiver retargeting fixtures;
- uses a raw fast path for lowered functions plus a HOT fallback for direct hot-pass tests;
- relies on paired vacuum cleanup for pure `drop` / `nop` debris exposed by redundant set removal;
- keeps the direct compare-pass lane semantic-green and keeps the `rse -> vacuum` exact replay on the already-classified inherited direct-`vacuum` frontier.

Future non-blocking parity work remains:

- implement broader Binaryen-style loop fixed-point CFG merge values only if a new direct semantic/parity case needs more than the landed safe loop-invariant default-write subset;
- broaden strict-subtype equivalent-local `local.get` retargeting if additional official `rse-gc.wast` families become locally representable beyond the landed reduced abs-heap, concrete-heap `ref.as_non_null` / `ref.cast` / `ref.cast_desc_eq` wrapper fixtures, and aggregate-accessor refinalization-style fixtures;
- keep the classified `rse -> vacuum` cleanup-slot replay from regressing before scheduling the late no-DWARF slot.

## Exact local status

| Surface | Current state | Future action |
| --- | --- | --- |
| Registry | `src/passes/optimize.mbt:253-256` now has an active `"redundant-set-elimination"` hot-pass entry. | Keep it direct-only until the late preset slot is proven. |
| Dispatcher | `src/passes/pass_manager.mbt` dispatches `"redundant-set-elimination"`, builds a validation environment for raw subtype checks, and has a raw fast path before hot lift. | Extend the raw/HOT implementations only for new semantic/parity cases or future preset scheduling. |
| Owner file | `src/passes/rse.mbt` owns descriptor, summary, raw/HOT value identities, branch merge sentinels, structured label-exit tracking, body-local default identities, and strict-subtype raw get retargeting. | Keep new behavior beside this owner with focused tests. |
| HOT local surfaces | [`src/ir/use_def.mbt:1-120`](../../../../../src/ir/use_def.mbt) records local reads/writes, but no value-number CFG flow. | Reuse only the collection pieces that fit; add explicit value identity and merge logic. |
| Type context | [`src/ir/hot_module_context.mbt:1-58`](../../../../../src/ir/hot_module_context.mbt) and later helpers expose module subtype/function type context. | Use this for strict-subtype retargeting checks. |
| Backlog | [`agent-todo.md`](../../../../../agent-todo.md) tracks `RSE`. | Keep the backlog aligned with this CFG-aware contract. |

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
- [x] Direct Binaryen `--rse` compare-pass lane: final 2026-05-10 signoff lane `.tmp/pass-fuzz-rse-rse002-final-signoff` (`6759/10000` compared, `6759` normalized matches, `0` mismatches, `20` Binaryen/tool command failures); prior `.tmp/pass-fuzz-rse-rse002-array-get-refinalize`, `.tmp/pass-fuzz-rse-rse002-struct-get-refinalize`, `.tmp/pass-fuzz-rse-rse002-branch-free-loops`, `.tmp/pass-fuzz-rse-rse002-hot-label-exits`, `.tmp/pass-fuzz-rse-rse002-hot-block-exits`, `.tmp/pass-fuzz-rse-rse002-gc-branch-exits`, `.tmp/pass-fuzz-rse-rse002-cast-loop-coverage`, `.tmp/pass-fuzz-rse-rse002-gc-refinement`, `.tmp/pass-fuzz-rse-rse002-next-followup`, `.tmp/pass-fuzz-rse-rse002-final`, `.tmp/pass-fuzz-rse-rse002-next`, `.tmp/pass-fuzz-rse-rse002`, 2026-05-06 `.tmp/pass-fuzz-redundant-set-elimination`, and older raw lanes remain historical evidence.
- [x] Generated-artifact direct replay: `.tmp/self-opt-rse-native-20260426b` has normalized WAT equality via fallback and canonical function equality.
- [x] 2026-05-05 current-main recheck stayed aligned with the same CFG/value-flow and refined-get split.
- [x] Branch-join same-value/self-set coverage for structured HOT and raw paths, including disagreement represented as a merge identity for self-set folding.
- [x] Branch-join different-value negative beyond the focused local tests: a raw branch-join fixture keeps the final const set alive when then/else values differ.
- [x] Raw block-exit disagreement negative keeps the final const set after `br_if` exits a block on one path and a later fallthrough path writes the same const.
- [x] Raw GC branch-exit disagreement negative keeps the final const set after `br_on_null` exits a block on one path and a later fallthrough path writes the same const; the implementation now records `br_on_null`, `br_on_non_null`, `br_on_cast`, and `br_on_cast_fail` as conditional label exits while conservatively clearing expression-stack facts on fallthrough.
- [x] HOT block/if label-exit coverage: positives fold post-block/post-if same-value sets when reachable fallthrough and label-exit sources agree, while negatives keep final const sets after `br_if` / `br` exits can bypass the local write.
- [x] Branch-free loop fallthrough facts for raw and HOT paths fold post-loop same-value sets when no loop backedge is seen; loop-backedge / outer-exit behavior remains conservative unless the raw loop writes a local exclusively with its default value, which safely preserves Binaryen-like default tee removal for loop-invariant locals while keeping mutating-backedge tees alive.
- [x] Reduced refined local-get retargeting with a strict-subtype local (`anyref` read retargeted to equivalent `eqref`).
- [x] Concrete-heap refined local-get retargeting through `ref.as_non_null` value-preserving wrappers, including a branch-merge positive and a strict-subtype negative where the nullable local must not replace the non-null source.
- [x] Programmatic concrete-heap refined local-get retargeting through `ref.cast` and `ref.cast_desc_eq` value-preserving wrappers, avoiding current WAT parser gaps while still validating the lowered instruction behavior.
- [x] `rse-gc.wast` `needs-refinalize`-style raw coverage: redundant tee removal can retarget following `struct.get` / `array.get` accessors from a base type to a strict-subtype receiver so the refined field/element type is preserved.
- [x] Raw string and conversion identities: repeated `string.const` local writes and repeated `any.convert_extern` writes from the same `externref` source now fold instead of losing stack facts.
- [x] One-armed terminating `if` fallthrough facts preserve default-local identities before later loop conditions.
- [x] Paired vacuum removes nested pure `drop` / `nop` debris exposed by RSE in small value-expression control regions.
- [x] Vacuum flips empty-then/live-else void `if`s to the Binaryen-style one-armed double-`eqz` form.
- [x] Conservative raw `try_table` barrier: nested body rewrites still run, but post-`try_table` local facts are cleared so unmodeled body writes cannot make later same-value sets fold unsafely.
- [x] No changes to globals, memory stores, struct stores, or array stores.
- [x] Late `--rse --vacuum` lane classified for RSE002: final 2026-05-10 replay at `.tmp/rse002-rse-vacuum-final-signoff3` remains exact-red at `defined=208 abs=225`, but the former `defined=0 abs=17` nested `drop(...)` / `nop` debris and `defined=29 abs=46` empty-then / double-`eqz` drift are fixed. The remaining first diff is inherited from direct `--vacuum`: `.tmp/rse002-vacuum-baseline` has the same first differing function, and the focused Starshine WAT/pretty files are byte-identical with and without RSE.

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
