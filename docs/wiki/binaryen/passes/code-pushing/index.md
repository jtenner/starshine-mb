---
kind: entity
status: supported
last_reviewed: 2026-06-21
sources:
  - ../../../raw/research/0821-2026-06-21-code-pushing-global-get-window-multi-set-movement.md
  - ../../../raw/research/0820-2026-06-21-code-pushing-local-get-window-multi-set-movement.md
  - ../../../raw/research/0819-2026-06-21-code-pushing-drop-window-multi-set-movement.md
  - ../../../raw/research/0818-2026-06-20-code-pushing-loop-br-if-movement.md
  - ../../../raw/binaryen/2026-06-20-code-pushing-version-130-source-lit-refresh.md
  - ../../../raw/research/0816-2026-06-20-code-pushing-local-copy-multi-set-movement.md
  - ../../../raw/research/0815-2026-06-20-code-pushing-br-if-multi-set-movement.md
  - ../../../raw/research/0814-2026-06-20-code-pushing-dropped-if-multi-set-movement.md
  - ../../../raw/research/0813-2026-06-20-code-pushing-ordered-multi-set-movement.md
  - ../../../raw/research/0812-2026-06-20-code-pushing-br-if-segment-movement.md
  - ../../../raw/research/0811-2026-06-20-code-pushing-dropped-if-segment-movement.md
  - ../../../raw/research/0810-2026-06-20-code-pushing-dedicated-genvalid-profile.md
  - ../../../raw/research/0809-2026-06-20-code-pushing-if-segment-movement.md
  - ../../../raw/research/0808-2026-06-20-code-pushing-segment-inventory.md
  - ../../../raw/research/0807-2026-06-20-code-pushing-version-130-source-lit-refresh.md
  - ../../../raw/research/0806-2026-06-20-code-pushing-unreachable-arm-post-use.md
  - ../../../raw/research/0527-2026-05-06-code-pushing-direct-revalidation.md
  - ../../../raw/binaryen/2026-05-05-code-pushing-current-main-recheck.md
  - ../../../raw/research/0454-2026-05-05-code-pushing-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-26-code-pushing-current-main-port-readiness.md
  - ../../../raw/research/0413-2026-04-26-code-pushing-current-main-port-readiness.md
  - ../../../raw/binaryen/2026-04-25-code-pushing-source-correction-and-local-status.md
  - ../../../raw/binaryen/2026-04-22-code-pushing-primary-sources.md
  - ../../../raw/research/0345-2026-04-25-code-pushing-source-correction-and-local-status.md
  - ../../../raw/research/0258-2026-04-22-code-pushing-primary-sources-and-starshine-followup.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/code_pushing.mbt
  - ../../../../../src/passes/code_pushing_test.mbt
  - ../../../../../src/validate/gen_valid.mbt
  - ../../../../../src/validate/gen_valid_tests.mbt
  - ../../../../../src/passes/registry_test.mbt
  - ../../../../../src/cmd/cmd_wbtest.mbt
  - ../../no-dwarf-default-optimize-path.md
  - ../tracker.md
related:
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./segment-selection-and-barriers.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
  - ../late-pipeline-dispatch.md
  - ../../no-dwarf-default-optimize-path.md
  - ../tracker.md
supersedes:
  - ../../../raw/research/0345-2026-04-25-code-pushing-source-correction-and-local-status.md
---

# `code-pushing`

## Role

`code-pushing` is an upstream Binaryen function pass and an active explicit HOT pass in Starshine.

Its purpose is to move single-assignment local writes later when doing so preserves behavior and makes the write execute closer to the control-flow path that consumes it.

The current source-backed Binaryen mental model is:

- analyze locals for single-first-assignment (SFA) behavior;
- scan structured block root segments with `Pusher`;
- admit only pushable `local.set` roots whose value effects are safe;
- push toward `if`, `switch`, conditional `br`, or dropped push-point wrappers;
- sink into the one `if` arm that reads the local, with an important unreachable-arm post-use allowance;
- rely on later optimizer cycles for deeper recursive opportunities.

The current Starshine implementation is an accepted direct-pass subset under Starshine's pass-wide completion criteria:

- safe movable-value `local.set` sinking into the single `if` arm that contains all reads of that local;
- a first ordinary-void-`if` segment movement slice that moves one SFA set after the `if` when all reads are same-region suffix reads;
- a dropped value-`if` segment movement slice that moves one SFA set after the dropped wrapper when all reads are same-region suffix reads;
- a narrow `br_if` segment movement slice that moves one SFA set after a void-block-target or void-loop-target `br_if` when the branch does not read the local and all reads are same-block / same-loop-body suffix reads;
- ordered multi-set movement slices that move adjacent local-independent SFA sets after an ordinary void `if`, dropped value-`if`, or narrow void-block-target / void-loop-target `br_if` while preserving source order;
- an ordered direct local-copy multi-set slice that preserves source order across the same three push-point families when copied source locals are not rewritten by the crossed push point;
- ordered separator-window multi-set slices that preserve source order across the same three push-point families when only `nop`, `drop(const)`, or `drop(local.get)` roots separate local-independent SFA sets, plus a bounded `drop(global.get)` separator slice for ordinary void `if` and dropped value-`if` push points only;
- a dedicated `code-pushing-all` GenValid profile covering the currently implemented `if`-arm, after-`if`, dropped-`if`, `br_if`, ordinary-`if` multi-set, dropped-`if` multi-set, `br_if` multi-set, local-copy multi-set, `nop`-window multi-set, loop-target `br_if`, `drop(const)`-window multi-set, `drop(local.get)`-window multi-set, and `drop(global.get)`-window ordinary-/dropped-`if` positive families;
- guarded movement of selected `global.get` and local-copy setup shapes across safe intervening roots;
- one Starshine-local typed/dead-block flattening helper near unreachable context.

Acceptance does **not** require raw wasm/text or transform-for-transform parity. The direct pass is complete when it preserves Binaryen semantics, produces valid wasm, and stays at least 50% as fast as Binaryen on comparable pass-local measurements.

## 2026-04-26 correction

This folder previously contained a 2026-04-25 correction that removed `Pusher`, segment selection, and local profitability-style movement from the upstream teaching. That correction was itself stale/wrong after a fresh official-source recheck.

The preferred source manifest is now:

- [`../../../raw/binaryen/2026-06-20-code-pushing-version-130-source-lit-refresh.md`](../../../raw/binaryen/2026-06-20-code-pushing-version-130-source-lit-refresh.md)
- [`../../../raw/research/0807-2026-06-20-code-pushing-version-130-source-lit-refresh.md`](../../../raw/research/0807-2026-06-20-code-pushing-version-130-source-lit-refresh.md)
- [`../../../raw/binaryen/2026-05-05-code-pushing-current-main-recheck.md`](../../../raw/binaryen/2026-05-05-code-pushing-current-main-recheck.md)
- [`../../../raw/research/0454-2026-05-05-code-pushing-current-main-recheck.md`](../../../raw/research/0454-2026-05-05-code-pushing-current-main-recheck.md)

The 2026-06-20 `version_130` refresh is the current local-oracle source bridge. It keeps the same owner and scheduler surfaces, adds `code-pushing-atomics.wast` as an audit-relevant lit family, and records the `version_130` effect-ordering drift from `invalidates(...)` to `effects.orderedBefore(cumulativeEffects)`. Keep the useful part of the 2026-04-25 warning: do not teach arbitrary two-live-arm duplication as the baseline. But restore the correct upstream owner concepts: `LocalAnalyzer`, `Pusher`, segment windows, `isPushable`, `isPushPoint`, and `optimizeSegment`.

## Why it matters

- Binaryen schedules `code-pushing` in the canonical no-DWARF function pipeline between `precompute` and the tuple/local-cleanup neighborhood.
- The saved generated-artifact `-O4z` audit recorded it as top-level skipped slot `20` before Starshine grew the current direct subset.
- Starshine's `tuple-optimization` exact-slot story still depends on this pass and the now-active `simplify-locals-nostructure` neighbor being represented honestly in the scheduler and preset replay.
- The pass is easy to over-broaden. Correctness depends on SFA local proofs, effect ordering/invalidation, trap policy, GC/reference behavior, atomics, EH, and post-if read rules.

## Inputs and outputs

### Upstream Binaryen input shape

- Function-local structured expression trees.
- Block root lists containing `local.set` temporaries and later push points.
- Local get/set information and effect properties.
- Optimization options that affect implicit traps and traps-never-happen behavior.

### Upstream Binaryen output shape

- Some pushable `local.set` roots move later within the same block segment, including after supported `if`, dropped-`if`, and narrow `br_if` push points.
- Some sets move into the only `if` arm that reads their local.
- Moved sets keep order and should execute on the same or fewer paths as allowed by the proof.
- Unproven shapes stay unchanged.

### Current Starshine input shape

- HOT functions lifted into `HotFunc`.
- Region roots containing local writes, structured `if`s, blocks, and unreachable roots.

### Current Starshine output shape

- Narrow single-consuming-arm local-set sinks become `nop` at the original root plus a cloned `local.set` inside the target arm.
- The first segment movement slices can replace original SFA sets with `nop` and insert cloned sets immediately after an ordinary void `if`, after a dropped value-`if` wrapper, or after a narrow void-block-target / void-loop-target `br_if` when all uses are later suffix reads. Multi-set movement is currently limited to adjacent local-independent sets before ordinary void `if`, dropped value-`if`, and narrow void-block-target / void-loop-target `br_if` push points, plus direct local-copy, `nop`-separated, `drop(const)`-separated, `drop(local.get)`-separated, and bounded ordinary-/dropped-`if` `drop(global.get)`-separated subcases with explicit source-local/order boundaries.
- Some typed/dead block roots near unreachable context are spliced into the parent region.
- Unmatched shapes stay unchanged.

## Invariants and correctness constraints

- Do not move non-SFA locals without a stronger local-use proof.
- Do not move values across effects that can invalidate or must be ordered after the delayed computation.
- Do not change trap timing unless the active trap policy explicitly permits that behavior.
- Do not strand post-if uses unless the non-consuming arm cannot fall through or another proof preserves the value.
- Do not treat two-live-arm duplication as a default `code-pushing` behavior.
- Preserve order among multiple pushed sets.
- Preserve function validity after structural mutation.
- Keep Starshine-local dead-block flattening documented separately from upstream Binaryen behavior.
- Do not claim public preset parity until the exact scheduler neighborhood is implemented and validated.
- Do not treat raw wasm/text drift as a blocker when normalized/canonical semantic comparison is green.

## Notable edge cases

- One `if` arm consumes the local and the other does not.
- Post-if reads where the non-consuming arm is unreachable.
- `switch` and conditional `br` push points.
- Trap-capable expressions under default, ignore-implicit-traps, and TNH options.
- GC/reference operations such as `ref.func`, casts, null checks, and the `version_130` atomics/GC ordering family.
- EH control where movement can change exceptional observability.
- Starshine dead-block flattening, which is local cleanup rather than upstream `CodePushing.cpp` behavior.

## Validation

The older direct `--pass code-pushing` lane was accepted under the previous v0.1.0 direct-pass standard, but `[O4Z-AUDIT-CP]` has reopened broader behavior-parity audit work. The 2026-05-09 evidence remains useful for the then-current subset:

- `moon info`, `moon fmt`, and `moon test` green;
- `.tmp/pass-fuzz-code-pushing` compared 6759/10000 cases with 6759 normalized matches, 0 semantic mismatches, and 20 Binaryen empty-recursion-group parser/canonicalization command failures;
- direct debug-artifact replay at `/tmp/starshine-self-optimize-compare-starshine-debug-wasi-1687067` reported `Normalized WAT equal: yes` and `Canonical function compare equal: yes`;
- pass-local timing was about 1658ms for Starshine versus about 1311ms for Binaryen, which is above the required 50%-of-Binaryen speed floor.

Raw canonical wasm/text still differs, but that is accepted representation drift rather than active `code-pushing` work.

For docs maintenance:

- prefer the 2026-06-20 `version_130` source/lit refresh over the older 2026-05-05, 2026-04-26, and 2026-04-25 corrections;
- search for stale “no `Pusher`,” “no segment selection,” or “no local profitability” wording in this folder;
- keep the no-two-live-arm-duplication warning, but do not erase Binaryen's real `Pusher` model.

For current `[O4Z-AUDIT-CP]` widening:

1. add focused tests in `src/passes/code_pushing_test.mbt` before mutating behavior and whitebox tests in `src/passes/code_pushing_wbtest.mbt` for analyzer-only surfaces;
2. build on the analyzer/segment-discovery slice from [`../../../raw/research/0808-2026-06-20-code-pushing-segment-inventory.md`](../../../raw/research/0808-2026-06-20-code-pushing-segment-inventory.md), the ordinary-`if` movement slice from [`../../../raw/research/0809-2026-06-20-code-pushing-if-segment-movement.md`](../../../raw/research/0809-2026-06-20-code-pushing-if-segment-movement.md), the dropped-`if` movement slice from [`../../../raw/research/0811-2026-06-20-code-pushing-dropped-if-segment-movement.md`](../../../raw/research/0811-2026-06-20-code-pushing-dropped-if-segment-movement.md), the narrow `br_if` movement slice from [`../../../raw/research/0812-2026-06-20-code-pushing-br-if-segment-movement.md`](../../../raw/research/0812-2026-06-20-code-pushing-br-if-segment-movement.md), the ordinary-`if` ordered multi-set slice from [`../../../raw/research/0813-2026-06-20-code-pushing-ordered-multi-set-movement.md`](../../../raw/research/0813-2026-06-20-code-pushing-ordered-multi-set-movement.md), the dropped-`if` ordered multi-set slice from [`../../../raw/research/0814-2026-06-20-code-pushing-dropped-if-multi-set-movement.md`](../../../raw/research/0814-2026-06-20-code-pushing-dropped-if-multi-set-movement.md), and the `br_if` ordered multi-set slice from [`../../../raw/research/0815-2026-06-20-code-pushing-br-if-multi-set-movement.md`](../../../raw/research/0815-2026-06-20-code-pushing-br-if-multi-set-movement.md), before broad mutation;
3. include the loop-target `br_if` widening slice from [`../../../raw/research/0818-2026-06-20-code-pushing-loop-br-if-movement.md`](../../../raw/research/0818-2026-06-20-code-pushing-loop-br-if-movement.md) when reasoning about conditional-branch movement, and the `drop(const)` window slice from [`../../../raw/research/0819-2026-06-21-code-pushing-drop-window-multi-set-movement.md`](../../../raw/research/0819-2026-06-21-code-pushing-drop-window-multi-set-movement.md) plus `drop(local.get)` window slice from [`../../../raw/research/0820-2026-06-21-code-pushing-local-get-window-multi-set-movement.md`](../../../raw/research/0820-2026-06-21-code-pushing-local-get-window-multi-set-movement.md) when reasoning about non-set separators;
4. validate direct pass execution through registry and command surfaces;
5. compare reduced WAT against Binaryen `wasm-opt --code-pushing` for each widened family;
6. include the dedicated `code-pushing-all` GenValid lane, currently with `--normalize local-cleanup-debris` for bounded Starshine `nop`/empty-else cleanup drift;
7. then run pass-fuzz / artifact comparisons under the standard pass signoff criteria;
8. only after ordered-neighborhood proof revisit public preset placement.

## Page map

- [`./binaryen-strategy.md`](./binaryen-strategy.md)
  - Current source-backed Binaryen strategy: `LocalAnalyzer`, `Pusher`, segment scanning, push points, effects, and `if` arm sinking.
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md)
  - Upstream owner-file and lit-test map for the corrected strategy.
- [`./segment-selection-and-barriers.md`](./segment-selection-and-barriers.md)
  - Movement-safety guide centered on SFA locals, effect barriers, push points, `if` arm rules, and Starshine-local dead-block flattening.
- [`./wat-shapes.md`](./wat-shapes.md)
  - Beginner-friendly before/after and bailout shape catalog, including current Starshine positive and negative families.
- [`./starshine-strategy.md`](./starshine-strategy.md)
  - Exact local code map and current subset.
- [`./fuzzing.md`](./fuzzing.md)
  - Dedicated `code-pushing-all` GenValid profile and compare lanes.
- [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md)
  - First-slice and validation plan for future broader parity work.

## Sources

- [`../../../raw/binaryen/2026-06-20-code-pushing-version-130-source-lit-refresh.md`](../../../raw/binaryen/2026-06-20-code-pushing-version-130-source-lit-refresh.md)
- [`../../../raw/research/0820-2026-06-21-code-pushing-local-get-window-multi-set-movement.md`](../../../raw/research/0820-2026-06-21-code-pushing-local-get-window-multi-set-movement.md)
- [`../../../raw/research/0819-2026-06-21-code-pushing-drop-window-multi-set-movement.md`](../../../raw/research/0819-2026-06-21-code-pushing-drop-window-multi-set-movement.md)
- [`../../../raw/research/0816-2026-06-20-code-pushing-local-copy-multi-set-movement.md`](../../../raw/research/0816-2026-06-20-code-pushing-local-copy-multi-set-movement.md)
- [`../../../raw/research/0815-2026-06-20-code-pushing-br-if-multi-set-movement.md`](../../../raw/research/0815-2026-06-20-code-pushing-br-if-multi-set-movement.md)
- [`../../../raw/research/0814-2026-06-20-code-pushing-dropped-if-multi-set-movement.md`](../../../raw/research/0814-2026-06-20-code-pushing-dropped-if-multi-set-movement.md)
- [`../../../raw/research/0813-2026-06-20-code-pushing-ordered-multi-set-movement.md`](../../../raw/research/0813-2026-06-20-code-pushing-ordered-multi-set-movement.md)
- [`../../../raw/research/0812-2026-06-20-code-pushing-br-if-segment-movement.md`](../../../raw/research/0812-2026-06-20-code-pushing-br-if-segment-movement.md)
- [`../../../raw/research/0811-2026-06-20-code-pushing-dropped-if-segment-movement.md`](../../../raw/research/0811-2026-06-20-code-pushing-dropped-if-segment-movement.md)
- [`../../../raw/research/0810-2026-06-20-code-pushing-dedicated-genvalid-profile.md`](../../../raw/research/0810-2026-06-20-code-pushing-dedicated-genvalid-profile.md)
- [`../../../raw/research/0809-2026-06-20-code-pushing-if-segment-movement.md`](../../../raw/research/0809-2026-06-20-code-pushing-if-segment-movement.md)
- [`../../../raw/research/0808-2026-06-20-code-pushing-segment-inventory.md`](../../../raw/research/0808-2026-06-20-code-pushing-segment-inventory.md)
- [`../../../raw/research/0807-2026-06-20-code-pushing-version-130-source-lit-refresh.md`](../../../raw/research/0807-2026-06-20-code-pushing-version-130-source-lit-refresh.md)
- [`../../../raw/research/0806-2026-06-20-code-pushing-unreachable-arm-post-use.md`](../../../raw/research/0806-2026-06-20-code-pushing-unreachable-arm-post-use.md)
- [`../../../raw/research/0527-2026-05-06-code-pushing-direct-revalidation.md`](../../../raw/research/0527-2026-05-06-code-pushing-direct-revalidation.md)
- [`../../../raw/binaryen/2026-05-05-code-pushing-current-main-recheck.md`](../../../raw/binaryen/2026-05-05-code-pushing-current-main-recheck.md)
- [`../../../raw/research/0454-2026-05-05-code-pushing-current-main-recheck.md`](../../../raw/research/0454-2026-05-05-code-pushing-current-main-recheck.md)
- [`../../../raw/binaryen/2026-04-26-code-pushing-current-main-port-readiness.md`](../../../raw/binaryen/2026-04-26-code-pushing-current-main-port-readiness.md)
- [`../../../raw/research/0413-2026-04-26-code-pushing-current-main-port-readiness.md`](../../../raw/research/0413-2026-04-26-code-pushing-current-main-port-readiness.md)
- [`../../../../../src/passes/code_pushing.mbt`](../../../../../src/passes/code_pushing.mbt)
- [`../../../../../src/passes/code_pushing_test.mbt`](../../../../../src/passes/code_pushing_test.mbt)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- Binaryen `version_130` `CodePushing.cpp`: <https://github.com/WebAssembly/binaryen/blob/version_130/src/passes/CodePushing.cpp>
- Binaryen current-main `CodePushing.cpp`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/CodePushing.cpp>
