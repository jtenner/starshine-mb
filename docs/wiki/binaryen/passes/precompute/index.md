---
kind: entity
status: stub
last_reviewed: 2026-04-18
sources:
  - ../../../../../src/passes/precompute.mbt
  - ../../../../../src/passes/precompute_test.mbt
  - ../../../raw/research/0093-2026-04-18-generated-o4z-pass-audit-summary.md
  - ../../../raw/research/0096-2026-04-18-generated-o4z-precompute-slot19-missing-i32-result.md
related:
  - ../../no-dwarf-default-optimize-path.md
  - ../late-pipeline-dispatch.md
---

# `precompute`

- Active hot pass in the Starshine registry.
- Current summary: Fold exact constant integer expressions that are trap-free and stable across the top-level precompute slots.
- Current Binaryen terminology check: upstream-facing sources still expose both `--precompute` and `--precompute-propagate`; this page keeps the repo's `precompute` umbrella label and records the ordered audit's Binaryen slot names explicitly when they differ.
- Newer upstream activity is behavioral, not terminological: the Chromium-hosted Binaryen mirror shows a 2025-08-27 `Precompute` rewrite that reworked child-retention logic and removed the older dual-cache split, plus a later 2026-03-25 fix that stopped folding GC `struct` / `array` atomic RMW and `cmpxchg` ops because those instructions both read and write heap state. Treat this repo's older `version_129`-backed `precompute` notes as a tagged oracle rather than a claim about current trunk internals.
- Current 2026-04-18 ordered generated-artifact follow-up: the early generated `cmd.wasm` slot at Binaryen slot `19` (`precompute-propagate`) emits invalid raw wasm (`func 108` missing its required `i32` result), while the later slot `43` still completes with meaningful equality.
- Use [`../late-pipeline-dispatch.md`](../late-pipeline-dispatch.md) for the current tail roster until dedicated strategy and parity pages land.

## Sources

- [`../late-pipeline-dispatch.md`](../late-pipeline-dispatch.md)
- Binaryen Chromium mirror commit `9de4aca15b3125d54aabaf2913a0988ff500bdba` (`2025-08-27`): <https://chromium.googlesource.com/external/github.com/WebAssembly/binaryen/+/9de4aca15b3125d54aabaf2913a0988ff500bdba>
- Binaryen Chromium mirror commit `10c876d4d246a2e697a166879bcb6df0d7b7bbca` (`2026-03-25`): <https://chromium.googlesource.com/external/github.com/WebAssembly/binaryen/+/10c876d4d246a2e697a166879bcb6df0d7b7bbca%5E%21/>
