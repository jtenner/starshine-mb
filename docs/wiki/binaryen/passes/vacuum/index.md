---
kind: entity
status: stub
last_reviewed: 2026-04-18
sources:
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/passes/trace_golden_test.mbt
  - ../../../raw/research/0093-2026-04-18-generated-o4z-pass-audit-summary.md
  - ../../../raw/research/0097-2026-04-18-generated-o4z-vacuum-slot23-func652-stack-underflow.md
  - ../../../raw/research/0098-2026-04-18-generated-o4z-vacuum-slot33-func1818-stack-underflow.md
related:
  - ../../no-dwarf-default-optimize-path.md
  - ../late-pipeline-dispatch.md
---

# `vacuum`

- Active hot pass in the Starshine registry.
- Current summary: Remove `nop` roots and region entries through hot IR cleanup.
- Newer upstream activity is behavioral, not terminological: the Chromium-hosted Binaryen mirror shows a 2026-02-27 `Vacuum` change that stopped rewriting explicit `unreachable` to `nop`, with the stated goal of letting unreachability propagate outward. Treat this repo's older `version_129`-backed vacuum notes as a tagged oracle rather than a claim about current trunk internals.
- Current 2026-04-18 ordered generated-artifact follow-up: the saved `cmd.wasm` audit still leaves two hard corruption slots for this pass, both failing in final module validation, but they should be tracked as two distinct ordered-prefix states instead of one vague `vacuum` bucket: slot `23` dies on `Func 652`, while slot `33` dies later on `Func 1818`.
- Durable ordered-audit takeaway after [0104](../../../raw/research/0104-2026-04-18-generated-o4z-optimize-instructions-slot16-func1818-parent-exit-payload-guard.md): the old slot-16 `optimize-instructions` pairings are no longer a good umbrella explanation for `vacuum`. Slot `23` (`Func 652`) and slot `33` (`Func 1818`) remain active `vacuum` blockers, but the early slot-16 `optimize-instructions` corruption was retired as separate HOT-lower carrier/packing bugs rather than left as shared ordered-prefix fragility.
- The current evidence split is therefore:
  - slot `23` still shares the older `Func 652` symptom family with `0095` / `0097`, but not the now-retired slot-16 root cause
  - slot `33` remains the immediate predecessor-state pair for the still-open later `optimize-instructions` slot `44` on `Func 1818`
- Use [`../late-pipeline-dispatch.md`](../late-pipeline-dispatch.md) for the current tail roster until dedicated strategy and parity pages land.

## Sources

- [`../late-pipeline-dispatch.md`](../late-pipeline-dispatch.md)
- [`../../../raw/research/0104-2026-04-18-generated-o4z-optimize-instructions-slot16-func1818-parent-exit-payload-guard.md`](../../../raw/research/0104-2026-04-18-generated-o4z-optimize-instructions-slot16-func1818-parent-exit-payload-guard.md)
- Binaryen Chromium mirror commit `9ee4a25ee15ab53e796cb0b3f320cafa2622c407` (`2026-02-27`): <https://chromium.googlesource.com/external/github.com/WebAssembly/binaryen/+/9ee4a25ee15ab53e796cb0b3f320cafa2622c407%5E%21/>
