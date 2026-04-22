---
kind: comparison
status: supported
last_reviewed: 2026-04-22
sources:
  - ../../../raw/research/0136-2026-04-20-pick-load-signs-binaryen-research.md
  - ../../../raw/research/0228-2026-04-21-pick-load-signs-implementation-followup.md
  - ../../../raw/research/0244-2026-04-22-pick-load-signs-primary-sources-and-code-map-followup.md
  - ../../../raw/binaryen/2026-04-22-pick-load-signs-primary-sources.md
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
- The local documentation now also keeps one narrower honesty note explicit: focused local pass tests do not yet isolate dedicated i64 positive rewrite cases, so the i64 divergence is source-confirmed in code and only indirectly exercised by broader replay/fuzz evidence today.

## Current in-tree status

- The implementation lives in [`../../../../../src/passes/pick_load_signs.mbt`](../../../../../src/passes/pick_load_signs.mbt).
- The focused suite lives in [`../../../../../src/passes/pick_load_signs_test.mbt`](../../../../../src/passes/pick_load_signs_test.mbt).
- CLI and debug-artifact coverage lives in [`../../../../../src/cmd/cmd_wbtest.mbt`](../../../../../src/cmd/cmd_wbtest.mbt).
- The pass is active in the optimize and shrink pipelines after `heap-store-optimization` and before `precompute`.
- The pass manager includes a module-memory fast skip and raw candidate screening so functions without plausible candidate surface can avoid hot lift.

## Signoff status

- The `2026-03-29` debug-artifact signoff recorded canonical wasm parity and normalized WAT parity.
- The same signoff recorded Starshine wall time at about `2067.184 ms` versus Binaryen at `1408.509 ms`.
- The `2026-03-29` `gen-valid` pass-fuzz run recorded `10000 / 10000` compared cases, `10000` normalized matches, and `0` mismatches or failures.
- The `2026-04-11` focused health rerun confirmed clean direct smoke behavior:
  - mixed: `199 / 199` compared, `199` normalized matches, `0` mismatches, `1` command failure (`binaryen-rec-group-zero`)
  - gen-valid: `200 / 200` compared, `200` normalized matches, `0` mismatches, `0` failures
- The saved generated-artifact `-O4z` audit also records a successful ordered replay at Binaryen slot `18` / audit row `15`.

## Important honesty note

A fresh `2026-04-20` official-source review corrected one part of the older local understanding:

- the archived local note `0069` treated i64 extension evidence as part of upstream `pick-load-signs`
- the official Binaryen `version_129` source for this pass does not support that reading
- the broader i64 logic exists in Starshine today, but it should be treated as a local scope expansion, not silently described as if it were official Binaryen behavior here

Current practical reading:

- the local implementation is still green on today's evidence,
- but the i64 surface should remain an explicit parity watchpoint if strict upstream equivalence becomes important.

## Freshness note

A narrow 2026-04-22 direct comparison found no visible drift here:

- `PickLoadSigns.cpp` is identical on Binaryen `version_129` and current `main`
- `pick-load-signs_sign-ext.wast` is also identical

So there is no post-`version_129` trunk-drift caveat to maintain for this pass right now.

## Sources

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
