---
kind: entity
status: stub
last_reviewed: 2026-04-18
sources:
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/passes/trace_golden_test.mbt
  - ../../../../../src/validate/typecheck.mbt
  - ../../../../../src/validate/validate.mbt
  - ../../../raw/research/0093-2026-04-18-generated-o4z-pass-audit-summary.md
  - ../../../raw/research/0097-2026-04-18-generated-o4z-vacuum-slot23-func652-stack-underflow.md
  - ../../../raw/research/0098-2026-04-18-generated-o4z-vacuum-slot33-func1818-stack-underflow.md
  - ../../../raw/research/0103-2026-04-18-generated-o4z-optimize-instructions-slot16-func652-carrier-guard.md
  - ../../../raw/research/0106-2026-04-18-generated-o4z-vacuum-slot23-retired-by-carrier-wrapper-guard.md
  - ../../../raw/research/0107-2026-04-18-generated-o4z-vacuum-slot33-retired-by-validator-escape-fix.md
related:
  - ../../no-dwarf-default-optimize-path.md
  - ../late-pipeline-dispatch.md
---

# `vacuum`

- Active hot pass in the Starshine registry.
- Current summary: Remove `nop` roots and region entries through hot IR cleanup.
- Newer upstream activity is behavioral, not terminological: the Chromium-hosted Binaryen mirror shows a 2026-02-27 `Vacuum` change that stopped rewriting explicit `unreachable` to `nop`, with the stated goal of letting unreachability propagate outward. Treat this repo's older `version_129`-backed vacuum notes as a tagged oracle rather than a claim about current trunk internals.
- Current 2026-04-18 ordered generated-artifact follow-up: no hard corruption slots remain active for this pass.
- Slot `23` is retired by [0106](../../../raw/research/0106-2026-04-18-generated-o4z-vacuum-slot23-retired-by-carrier-wrapper-guard.md): the saved tuple-opt predecessor now replays cleanly, the extracted `Func 652` replay also validates, and the Binaryen compare reports `Normalized WAT equal: yes` plus `Canonical function compare equal: yes`.
- Durable ordered-audit takeaway after [0106](../../../raw/research/0106-2026-04-18-generated-o4z-vacuum-slot23-retired-by-carrier-wrapper-guard.md): slot `23` only looked like a `vacuum` corruption because `vacuum` was the replay boundary when final lowering happened. The retired `Func 652` failure is better understood as fallout from the earlier HOT-lower carrier-wrapper bug fixed in [0103](../../../raw/research/0103-2026-04-18-generated-o4z-optimize-instructions-slot16-func652-carrier-guard.md), not as a pass-local `vacuum` rewrite bug.
- Slot `33` is now also retired by [0107](../../../raw/research/0107-2026-04-18-generated-o4z-vacuum-slot33-retired-by-validator-escape-fix.md): the saved simplify-locals predecessor now replays to a `wasm-tools`-valid module, the extracted `Func 4142` witness is green in-tree, and the Binaryen compare reports `Normalized WAT equal: yes` plus `Canonical function compare equal: yes`.
- Durable ordered-audit takeaway after [0107](../../../raw/research/0107-2026-04-18-generated-o4z-vacuum-slot33-retired-by-validator-escape-fix.md): the slot-33 corruption was exposed by `vacuum`, but the fix was not a new pass-local cleanup rewrite. The lasting repair was a validator/typechecker escape-normalization correction plus a guarded `vacuum` writeback boundary that now keeps invalid rewrites from escaping into the final module.
- Use [`../late-pipeline-dispatch.md`](../late-pipeline-dispatch.md) for the current tail roster until dedicated strategy and parity pages land.

## Sources

- [`../late-pipeline-dispatch.md`](../late-pipeline-dispatch.md)
- [`../../../raw/research/0103-2026-04-18-generated-o4z-optimize-instructions-slot16-func652-carrier-guard.md`](../../../raw/research/0103-2026-04-18-generated-o4z-optimize-instructions-slot16-func652-carrier-guard.md)
- [`../../../raw/research/0104-2026-04-18-generated-o4z-optimize-instructions-slot16-func1818-parent-exit-payload-guard.md`](../../../raw/research/0104-2026-04-18-generated-o4z-optimize-instructions-slot16-func1818-parent-exit-payload-guard.md)
- [`../../../raw/research/0106-2026-04-18-generated-o4z-vacuum-slot23-retired-by-carrier-wrapper-guard.md`](../../../raw/research/0106-2026-04-18-generated-o4z-vacuum-slot23-retired-by-carrier-wrapper-guard.md)
- [`../../../raw/research/0107-2026-04-18-generated-o4z-vacuum-slot33-retired-by-validator-escape-fix.md`](../../../raw/research/0107-2026-04-18-generated-o4z-vacuum-slot33-retired-by-validator-escape-fix.md)
- Binaryen `Vacuum.cpp` (`version_129`): <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/Vacuum.cpp>
- Binaryen Chromium mirror commit `9ee4a25ee15ab53e796cb0b3f320cafa2622c407` (`2026-02-27`): <https://chromium.googlesource.com/external/github.com/WebAssembly/binaryen/+/9ee4a25ee15ab53e796cb0b3f320cafa2622c407%5E%21/>
