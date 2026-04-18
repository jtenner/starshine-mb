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
- Current 2026-04-18 ordered generated-artifact follow-up: the saved `cmd.wasm` audit found two hard corruption slots for this pass, both failing in final module validation (`Func 652` at Binaryen slot `23`, `Func 1818` at slot `33`).
- Durable ordered-audit takeaway: each `vacuum` failure mirrors a nearby `optimize-instructions` failure on the same offending function, so treat the current blockers as shared ordered-prefix fragility around `Func 652` and `Func 1818` until reduced evidence proves one pass is solely responsible.
- Use [`../late-pipeline-dispatch.md`](../late-pipeline-dispatch.md) for the current tail roster until dedicated strategy and parity pages land.

## Sources

- [`../late-pipeline-dispatch.md`](../late-pipeline-dispatch.md)
- Binaryen Chromium mirror commit `9ee4a25ee15ab53e796cb0b3f320cafa2622c407` (`2026-02-27`): <https://chromium.googlesource.com/external/github.com/WebAssembly/binaryen/+/9ee4a25ee15ab53e796cb0b3f320cafa2622c407%5E%21/>
