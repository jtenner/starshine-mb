---
kind: comparison
status: working
last_reviewed: 2026-06-20
sources:
  - ../../../raw/research/0784-2026-06-20-pick-load-signs-modern-signoff-refresh.md
  - ../../../raw/research/0702-2026-06-03-pick-load-signs-o4z-audit.md
  - ../../../raw/research/0532-2026-05-06-pick-load-signs-direct-revalidation.md
  - ../../../raw/binaryen/2026-05-05-pick-load-signs-current-main-recheck.md
  - ../../../raw/research/0455-2026-05-05-pick-load-signs-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-22-pick-load-signs-primary-sources.md
  - ../../../raw/research/0136-2026-04-20-pick-load-signs-binaryen-research.md
  - ../../../raw/research/0228-2026-04-21-pick-load-signs-implementation-followup.md
  - ../../../raw/research/0244-2026-04-22-pick-load-signs-primary-sources-and-code-map-followup.md
  - ../../../raw/research/0069-2026-03-26-pick-load-signs.md
  - ../../../raw/research/0079-2026-04-11-pass-fuzz-health-round-two.md
  - ../../../../../src/passes/pick_load_signs.mbt
  - ../../../../../src/passes/pick_load_signs_test.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/cmd/cmd_wbtest.mbt
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/PickLoadSigns.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/properties.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/pick-load-signs_sign-ext.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/optimize-instructions-sign_ext.wast
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ./starshine-hot-ir-strategy.md
---

# `pick-load-signs` Binaryen parity

## Durable conclusions

- `pick-load-signs` is an early function-phase Binaryen pass on the no-DWARF path for optimize level `>= 2` or shrink level `>= 2`.
- The living dossier now also has a dedicated implementation/test-map page, so the tiny owner split across `PickLoadSigns.cpp`, `properties.h`, `pass.cpp`, `opt-utils.h`, and the dedicated-vs-neighboring lit tests no longer has to be reconstructed from the strategy page alone.
- The official Binaryen `version_129` pass is smaller than the old local port note made it sound:
  - exact non-tee `local.set(load ...)` producers only
  - exact recognized sign/zero-extension use shapes only
  - any unknown use blocks the rewrite
  - atomic loads are skipped
  - the real upstream helper surface here is effectively **i32-only**
- The current in-tree Starshine implementation is broader than upstream in one visible way:
  - it recognizes i64 extend / mask / shift-pair families too
- Current local artifact and focused fuzz evidence are still green despite that broader local surface.
- The 2026-06-03 O4z audit refreshed direct signoff for `pick-load-signs` with `9975 / 10000` compared cases, `9975` normalized matches, 0 semantic mismatches, and 25 Binaryen/tool command failures.
- Focused local tests now isolate the broader i64 positive rewrite surface and use a real imported-memory fixture, so the former i64-test caveat is closed while the local-vs-upstream scope divergence remains explicit.
- The 2026-06-20 refresh found no new semantic behavior gap, but reopened `[O4Z-AUDIT-PLS]` as a release-gating evidence/profile slice: the older closeout predates the current four-lane final pass signoff matrix and `fuzzing.md` still has no pass-specific GenValid profile.

## Current in-tree status

- The implementation lives in [`../../../../../src/passes/pick_load_signs.mbt`](../../../../../src/passes/pick_load_signs.mbt).
- The focused suite lives in [`../../../../../src/passes/pick_load_signs_test.mbt`](../../../../../src/passes/pick_load_signs_test.mbt).
- CLI and debug-artifact coverage lives in [`../../../../../src/cmd/cmd_wbtest.mbt`](../../../../../src/cmd/cmd_wbtest.mbt).
- The pass is active in the optimize and shrink pipelines after `heap-store-optimization` and before `precompute`.
- The pass manager includes a module-memory fast skip and raw candidate screening so functions without plausible candidate surface can avoid hot lift.

## Signoff status

Current status under the modern repo standard: not fully reclosed yet. The pass remains behavior-closed on existing inspected evidence, but modern final closeout still needs a PLS-specific GenValid profile plus the four-lane matrix from [`./fuzzing.md`](./fuzzing.md).

- The `2026-03-29` debug-artifact signoff recorded canonical wasm parity and normalized WAT parity.
- The same signoff recorded Starshine wall time at about `2067.184 ms` versus Binaryen at `1408.509 ms`.
- The `2026-03-29` `gen-valid` pass-fuzz run recorded `10000 / 10000` compared cases, `10000` normalized matches, and `0` mismatches or failures.
- The `2026-04-11` focused health rerun confirmed clean direct smoke behavior:
  - mixed: `199 / 199` compared, `199` normalized matches, `0` mismatches, `1` command failure (`binaryen-rec-group-zero`)
  - gen-valid: `200 / 200` compared, `200` normalized matches, `0` mismatches, `0` failures
- The saved generated-artifact `-O4z` audit also records a successful ordered replay at Binaryen slot `18` / audit row `15`: exact wasm equality, meaningful equality, valid Starshine/Binaryen outputs, `7.492 ms` Starshine pass-local time, and `24.574 ms` Binaryen pass-local time.
- The `2026-06-03` O4z audit direct closeout recorded `9975 / 10000` compared cases, `9975` normalized matches, `0` semantic mismatches, and `25` Binaryen/tool command failures in `.tmp/pass-fuzz-pick-load-signs-audit-10000`.
- The `2026-06-20` refresh command `bun scripts/pass-fuzz-compare.ts --list-passes | grep pick-load-signs` still printed `pick-load-signs`. No new compare lane was run in that docs/backlog slice because `target/native/release/build/cmd/cmd.exe` was missing and no executable behavior changed.

## Important honesty note

A fresh `2026-04-20` official-source review corrected one part of the older local understanding:

- the archived local note `0069` treated i64 extension evidence as part of upstream `pick-load-signs`
- the official Binaryen `version_129` source for this pass does not support that reading
- the broader i64 logic exists in Starshine today, but it should be treated as a local scope expansion, not silently described as if it were official Binaryen behavior here

Current practical reading:

- the local implementation is still green on today's evidence,
- focused tests now directly lock representative i64 signed and unsigned positives,
- but the i64 surface should remain an explicit parity watchpoint if strict upstream equivalence becomes important.

## Modern closeout gap

The current final pass closeout standard requires:

1. regular GenValid `100000` cases at seed `0x5eed`
2. explicit wasm-smith `10000` cases at seed `0x5eed`
3. pass-specific GenValid profile `10000` cases at seed `0x5eed`
4. broad named all-profiles-style GenValid lane `10000` cases at seed `0x5555`

PLS has not yet run that matrix and has no dedicated pass-specific GenValid profile. Track that gap in `[O4Z-AUDIT-PLS]` rather than treating the 2026-06-03 closure as sufficient for current release-gating standards.

## Freshness note

A narrow 2026-05-05 current-main recheck found no visible drift here:

- `PickLoadSigns.cpp` is identical on Binaryen `version_129` and current `main`
- `pick-load-signs_sign-ext.wast` is also identical
- the new raw manifest records the refreshed 2026-05-05 bridge explicitly

So there is no post-`version_129` trunk-drift caveat to maintain for this pass right now.

## Sources

- [`../../../raw/research/0784-2026-06-20-pick-load-signs-modern-signoff-refresh.md`](../../../raw/research/0784-2026-06-20-pick-load-signs-modern-signoff-refresh.md)
- [`../../../raw/research/0702-2026-06-03-pick-load-signs-o4z-audit.md`](../../../raw/research/0702-2026-06-03-pick-load-signs-o4z-audit.md)
- [`../../../raw/research/0532-2026-05-06-pick-load-signs-direct-revalidation.md`](../../../raw/research/0532-2026-05-06-pick-load-signs-direct-revalidation.md)
- [`../../../raw/research/0136-2026-04-20-pick-load-signs-binaryen-research.md`](../../../raw/research/0136-2026-04-20-pick-load-signs-binaryen-research.md)
- [`../../../raw/research/0069-2026-03-26-pick-load-signs.md`](../../../raw/research/0069-2026-03-26-pick-load-signs.md)
- [`../../../raw/research/0079-2026-04-11-pass-fuzz-health-round-two.md`](../../../raw/research/0079-2026-04-11-pass-fuzz-health-round-two.md)
- [`../../../../../src/passes/pick_load_signs.mbt`](../../../../../src/passes/pick_load_signs.mbt)
- [`../../../../../src/passes/pick_load_signs_test.mbt`](../../../../../src/passes/pick_load_signs_test.mbt)
- [`../../../../../src/passes/pass_manager.mbt`](../../../../../src/passes/pass_manager.mbt)
- [`../../../../../src/cmd/cmd_wbtest.mbt`](../../../../../src/cmd/cmd_wbtest.mbt)
- Binaryen `version_129` sources:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/PickLoadSigns.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/properties.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/pick-load-signs_sign-ext.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/optimize-instructions-sign_ext.wast>
