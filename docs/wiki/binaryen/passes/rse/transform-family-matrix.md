---
kind: concept
status: supported
last_reviewed: 2026-07-05
sources:
  - ./index.md
  - ./binaryen-strategy.md
  - ./cfg-and-value-tracking.md
  - ./fuzzing.md
  - ../../../raw/binaryen/2026-07-11-rse-current-main-recheck.md
  - ../../../../../src/passes/rse.mbt
  - ../../../../../src/passes/rse_test.mbt
  - ../../../raw/research/0538-2026-05-06-rse-direct-revalidation.md
related:
  - ./index.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
  - ../vacuum/index.md
---

# `rse` Transform-Family Matrix

This matrix is the live audit ledger for Starshine `redundant-set-elimination` (`rse`) against Binaryen's current source/test surface. It should be read with [`./binaryen-strategy.md`](./binaryen-strategy.md), [`./cfg-and-value-tracking.md`](./cfg-and-value-tracking.md), and [`./fuzzing.md`](./fuzzing.md).

## Fresh primary-source/probe snapshot

2026-07-11 upstream source reread:

- Rechecked official Binaryen `main` `RedundantSetElimination.cpp`, `pass.cpp`, `rse_all-features.wast` / expected output, and `rse-gc.wast`; see [`../../../raw/binaryen/2026-07-11-rse-current-main-recheck.md`](../../../raw/binaryen/2026-07-11-rse-current-main-recheck.md).
- The prior 2026-07-04 local source snapshot remains accurate: the pass is still CFG/value-flow-based same-value local shell removal plus strict-subtype equivalent-local get retargeting, with no behavior-bearing owner/test drift. The version-to-main source comparison only changes a comment spelling (`vaccum` → `vacuum`).
- This was an upstream freshness check, not a replacement for the 2026-07-05 Starshine all-features replay, direct compare matrix, or pass-local timing evidence below.

2026-07-05 loop/fixed-point closure:

- Added focused Starshine regressions for the official loop residuals: untouched default locals across loop backedges, stable loop-entry/post-loop same-value writes, and one-arm copy sets after merged locals are explicitly made equal.
- Starshine raw RSE now preserves loop-entry facts when a one-pass backedge probe shows all loop backedges carry the entry value, preserves post-loop facts for locals not written by the loop or whose fallthrough/backedge sources agree with the entry value, and materializes an identity for unknown `local.get` reads so a later local copy can prove both locals equal without deleting any RHS/effectful work.
- Rebuilt `_build/native/release/build/cmd/cmd.exe` and replayed the official all-features probe. `diff -u .tmp/rse-audit-binaryen/binaryen-rse-all-features.opt.wat .tmp/rse-audit-binaryen/starshine-rse-all-features.binaryenprint.wat` is now empty (`0` lines).
- Focused/full validation for this closure: red-first `moon test --target native src/passes/rse_test.mbt --filter '*untouched default*'` failed before implementation, then focused one-arm and full `moon test --target native src/passes/rse_test.mbt` passed `38/38`; `moon fmt`, `moon info`, full `moon test` (`7627/7627`), native `src/cmd` release build, and dedicated direct RSE GenValid profile `.tmp/pass-fuzz-rse-profile-20260705-loop-fix` passed `10000/10000` with zero mismatches/failures.



2026-07-05 final closeout refresh after the performance follow-up:

- Focused/full validation passed `moon info`, `moon fmt`, `moon test --target native src/passes/rse_test.mbt` (`39/39`), `moon test src/passes` (`4199/4199`), `moon test` (`7628/7628`), and `moon build --target native --release src/cmd`.
- Full compare matrix passed with no true RSE-owned semantic mismatches: regular GenValid 100000 green, dedicated `rse` profile 10000 green, random-all-profiles 10000 green, and the external wasm-smith lane had one raw generic unreachable-control-debris mismatch that normalized away under `--normalize unreachable-control-debris`.

2026-07-04 local audit inputs:

- Downloaded Binaryen current `main` primary files into `.tmp/rse-audit-binaryen/`: `RedundantSetElimination.cpp`, `rse_all-features.wast`, `rse_all-features.txt`, and `rse-gc.wast`.
- Local Binaryen tool: `wasm-opt version 130 (version_130)`.
- Current source still matches the known contract: a `CFGWalker` pass collects `LocalGet` and `LocalSet`, flows per-local value numbers to fixed point, removes same-value `local.set`/`local.tee` shells, retargets strict-subtype equivalent `local.get`s, and optionally runs `ReFinalize` after type-sensitive rewrites.
- Official all-features probe:
  - `wasm-opt .tmp/rse-audit-binaryen/rse_all-features.wast --all-features -o .tmp/rse-audit-binaryen/rse_all-features.binaryen.wasm`
  - `_build/native/release/build/cmd/cmd.exe --redundant-set-elimination --stdout .tmp/rse-audit-binaryen/rse_all-features.binaryen.wasm > .tmp/rse-audit-binaryen/starshine-rse-all-features.wasm`
  - `wasm-opt .tmp/rse-audit-binaryen/rse_all-features.binaryen.wasm --all-features --rse -S -o .tmp/rse-audit-binaryen/binaryen-rse-all-features.opt.wat`
  - `wasm-opt .tmp/rse-audit-binaryen/starshine-rse-all-features.wasm --all-features -S -o .tmp/rse-audit-binaryen/starshine-rse-all-features.binaryenprint.wat`
  - Historical result before the 2026-07-05 closure: validating Starshine output, but raw WAT diff exposed Binaryen-owned optimization gaps in official loop/default/fixed-point families: `$loop` left `local.set $b (i32.const 0)`, `$merge` left a loop-entry `local.set $x (i32.const 2)` and post-loop `local.set $x (i32.const 2)`, and `$many-merges` / `$fuzz-nan` left one-arm `local.set $1 (local.get $0)` shells that Binaryen drops. The 2026-07-05 replay now has an empty diff.
- Struct atomic accessor probe:
  - `.tmp/rse-audit-binaryen/struct-atomic-rse-probe.wat` parsed with `wasm-tools parse`, then `wasm-opt ... --rse -S`.
  - Binaryen rewrites `struct.atomic.get` from base type `0` to subtype `1` after removing a redundant tee, matching the same refinalization/retargeting family as `rse-gc.wast` `needs-refinalize`.
  - Starshine focused test `rse retargets struct.atomic.get after redundant tee removal` now covers this family.

## Classification labels

- **Implemented**: Starshine has source/tests and current fuzz/probe evidence for the Binaryen-owned behavior.
- **Intentionally fail-closed / unsupported**: Starshine deliberately preserves behavior without attempting a risky rewrite; this must be narrow and documented.
- **Inherited downstream cleanup boundary**: RSE produces source-consistent debris and a later pass owns exact cleanup.
- **Starshine-win with evidence**: Starshine diverges only with measured/inspected benefit and no semantic risk.
- **Behavior gap**: Binaryen-owned optimization is missing or thinner in Starshine. This is not a semantic miscompile by itself, but it remains an RSE audit gap until fixed or explicitly reclassified.

## Matrix

| Family | Binaryen source/test evidence | Starshine evidence | Classification | Notes / next action |
| --- | --- | --- | --- | --- |
| Same-value `local.set` shell removal | `RedundantSetElimination.cpp` compares RHS value number with current target-local value and converts non-tee sets to `drop(value)`. `rse_all-features.wast` `$basic`, `$later-param-use`, `$diff-value`. | `src/passes/rse.mbt` HOT and raw paths replace redundant sets with drops; focused tests `rse replaces same-value local.set shell with drop`, default-local tests, and 2026-07-04 `rse` GenValid lanes. | Implemented | Must preserve RHS evaluation; do not widen to overwritten different-value deletion. |
| Same-value `local.tee` shell removal | Binaryen removes tee shell and keeps the tee value expression; `rse_all-features.wast` `$if2`, copied/self cases, and `rse-gc.wast` `needs-refinalize`. | HOT/raw paths remove redundant tees while leaving value on stack; tests cover same-value tee, unknown-value self-tee, loop default tee boundary, struct/array refinalize-style tee removal. | Implemented | Refinalization-sensitive tee removal remains covered for ordinary and aggregate accessors. |
| RHS/effect/trap preservation | Binaryen `remove()` keeps the RHS: set becomes `drop(value)`, tee becomes `value`. | RSE never deletes effectful RHS work for same-value shells; hazard profiles include memory/table/global boundaries. | Implemented | Continue rejecting generic DSE. Add focused trap/effect probes if a new RHS expression family is optimized. |
| Default body-local facts | Binaryen initializes zeroable/defaultable locals with `Literal::makeZeros(type)` and params/nonzeroable locals as unique values. Official `$basic` and `$loop` exercise this. | Starshine raw default identities cover numeric and nullable refs, including canonical nullable extern/function defaults. The 2026-07-05 test `rse raw path preserves untouched default locals across loop backedges` covers the official `$loop` residual. | Implemented | Starshine now preserves facts for locals the loop body does not write, so the post-loop default write is dropped like Binaryen while still keeping written-loop-local reset negatives. |
| Local-copy identities | Binaryen gives `local.set $dst (local.get $src)` the current value number of `$src`; `rse_all-features.wast` `$copy`, `$param-unique`, `$set-unique`, `$identical_complex`, `$many-merges`, and `$fuzz-nan`. | Raw/HOT copy facts, unknown-value self-set/tee shell fixes, strict-subtype copied get retargeting, and the 2026-07-05 `rse raw path folds one-arm copy after merged locals are made equal` regression. | Implemented | Raw `local.get` now materializes an identity for an otherwise unknown local value, so `local.set $dst (local.get $src)` can make the locals equal and fold a later same-value copy shell without generic DSE. |
| Self-set identities | Binaryen removes `local.set $x (local.get $x)` when current value is known, including merge-value self identities. | Focused tests cover branch disagreement as merge value for self sets and raw unknown-value self set/tee shell removal. | Implemented | Keep scoped to true self-shells; no generic liveness deletion. |
| CFG block/if branch-exit merge facts | Binaryen block starts merge predecessor facts, using block-specific merge values on disagreement. `rse_all-features.wast` `$if`, `$if2`, `$if3`, `$copy`, `$one-arm`, `$one-arm2`. | Starshine tracks block/if label exits in raw and HOT paths; tests cover branch agreement, disagreement, `br`, `br_if`, `br_table`, and GC branch exits. | Implemented for covered structured block/if/branch exits | The official one-arm copy residuals are currently classified under loop/fixed-point because the missing proof depends on prior loop/merge state, not merely local one-arm syntax. |
| Loop entry/backedge/fixed-point behavior | Binaryen uses a deferred work queue and convergence proof over CFG block end values; official `$loop`, `$merge`, `$many-merges`, `$fuzz`, `$fuzz2`, `$fuzz-nan`. | Starshine implements branch-free loop fallthrough facts, safe default/same-write subsets, loop untouched-local preservation, stable-entry backedge probes, post-loop source agreement, and unknown `local.get` value materialization. Focused tests now cover the official `$loop`, `$merge`, `$many-merges`, and `$fuzz-nan` residual families. | Implemented for the audited official/source-backed families | The 2026-07-05 all-features replay has an empty Binaryen-vs-Starshine WAT diff. This is still not generic fixed-point DSE: locals written by a loop remain conservative unless entry/backedge/fallthrough sources prove the same value. |
| Strict-subtype equivalent-local `local.get` retargeting | Binaryen maps value numbers to locals and retargets gets to a strict subtype local; `rse-gc.wast` `pick-refined*`, `avoid-unrefined`, `different-choices`. | Raw retargeting uses validation `Match`; tests cover anyref/eqref, concrete heap wrappers, branch merges, strict-subtype negative. | Implemented | Continue using local-index retargeting only; no expression cloning. |
| Refinement wrappers: `ref.as_non_null`, `ref.cast`, `ref.cast_desc_eq` | `rse-gc.wast` uses `ref.cast`; current source relies on value-numbered expressions plus `ReFinalize`. | Starshine raw path treats these wrappers as identity-preserving for value identity; tests cover all three. | Implemented | Parser gaps for some text forms are covered by programmatic fixtures. |
| GC aggregate accessor refinalization: `struct.get*`, `struct.atomic.get*`, `array.get*` | `rse-gc.wast` `needs-refinalize` proves struct accessor refinalization after tee removal; 2026-07-04 local struct-atomic probe confirms Binaryen refinalizes `struct.atomic.get` immediates. | Tests cover `struct.get`, `array.get`, and now `struct.atomic.get` after redundant tee removal. Raw source also implements signed/unsigned struct gets, signed/unsigned struct atomic gets, and signed/unsigned array gets. | Implemented for represented accessors; coverage broadened this slice | Additional focused tests for `struct.get_s/u`, `struct.atomic.get_s/u`, and `array.get_s/u` are useful but not currently behavior gaps because the shared helper path is inspected. |
| Exception / `try_table` boundaries | Binaryen CFG sees exception/control edges through CFG traversal; official source does not delete stores or heap effects. | Starshine visits nested `try_table` bodies but clears post-`try_table` local facts; focused test covers conservative unmodeled `try_table` body writes. | Intentionally fail-closed / unsupported for post-EH facts | This is a documented precision loss, not a semantic bug. Reopen if Binaryen official tests add EH positives or generated direct compare finds an RSE-owned EH mismatch. |
| Memory/table/global/heap-field hazard boundaries | Binaryen RSE is locals-only; it does not remove global/memory/table/struct/array stores. | RSE only rewrites local.set/local.tee shells and local.get/accessor immediates; GenValid hazard profile covers boundaries. | Implemented as non-goal / fail-closed | Do not implement generic DSE or effect-store deletion in RSE. |
| Unreachable / terminating control | Binaryen ignores unreachable tail items via CFG reachability but still optimizes reachable block facts. Official `$unreach`, `$fuzz`, `$fuzz2`. | Starshine marks `br`, `br_table`, `return`, `unreachable`, `throw` as terminating and stops trusting following facts. | Implemented for safety; possible precision interaction with loop gap | Official all-features diff did not show an unreachable-tail safety problem; remaining misses are precision gaps. |
| Paired `rse -> vacuum` cleanup | Binaryen comments expect a final `vacuum` because RSE leaves drops. | Direct RSE `rse-vacuum-tail` profile is green. Direct `rse -> vacuum` profile still mismatches on live local-set debris matching known direct `vacuum` representation boundary. | Inherited downstream cleanup boundary | Do not add generic DSE to RSE. Recheck when vacuum cleanup frontier moves. |

## Current audit conclusion

The requested RSE transform-family matrix is classified with no unclassified RSE-owned behavior gaps in the audited source/test surface. The prior loop/default/fixed-point gap is closed for the official Binaryen `rse_all-features.wast` residuals: Starshine now matches Binaryen on `$loop`, `$merge`, `$many-merges`, and `$fuzz-nan` in the replayed all-features diff, while preserving the RSE contract of same-value shell removal, strict-subtype get retargeting, RHS/effect/trap preservation, and no generic dead-store elimination. The paired `rse -> vacuum` exact-output boundary remains classified as inherited downstream cleanup behavior rather than RSE-owned work.
