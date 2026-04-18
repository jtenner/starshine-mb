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
- Newer upstream activity is behavioral, not terminological: the Chromium-hosted Binaryen mirror shows a 2025-08-27 `Precompute` rewrite that reworked child-retention logic and removed the older dual-cache split, a 2026-03-23 fix that keeps GC writes like `ArrayStore` in the effects model instead of precomputing through them, a 2026-03-25 fix that stopped folding GC `struct` / `array` atomic RMW and `cmpxchg` ops because those instructions both read and write heap state, and a 2026-03-26 multibyte-array-access follow-up that deliberately treats `array.load` as `NONCONSTANT_FLOW` for now instead of folding it like an ordinary constant read. Treat this repo's older `version_129`-backed `precompute` notes as a tagged oracle rather than a claim about current trunk internals.
- Current 2026-04-18 ordered generated-artifact follow-up: the early generated `cmd.wasm` slot at Binaryen slot `19` (`precompute-propagate`) emits invalid raw wasm (`func 108` missing its required `i32` result), while the later slot `43` still completes with meaningful equality.
- Use [`../late-pipeline-dispatch.md`](../late-pipeline-dispatch.md) for the current tail roster until dedicated strategy and parity pages land.

## Sources

- [`../late-pipeline-dispatch.md`](../late-pipeline-dispatch.md)
- Binaryen Chromium mirror commit `9de4aca15b3125d54aabaf2913a0988ff500bdba` (`2025-08-27`): <https://chromium.googlesource.com/external/github.com/WebAssembly/binaryen/+/9de4aca15b3125d54aabaf2913a0988ff500bdba>
- Binaryen Chromium mirror commit `8f85446ee05b32726979a38284a48b1c3719208a` (`2026-03-23`): <https://chromium.googlesource.com/external/github.com/WebAssembly/binaryen/+/8f85446ee05b32726979a38284a48b1c3719208a>
- Binaryen Chromium mirror commit `10c876d4d246a2e697a166879bcb6df0d7b7bbca` (`2026-03-25`): <https://chromium.googlesource.com/external/github.com/WebAssembly/binaryen/+/10c876d4d246a2e697a166879bcb6df0d7b7bbca%5E%21/>
- Binaryen Chromium mirror commit `86f0d65bcf87c2491698b7cfd526f2f0614a75dd` (`2026-03-26`): <https://chromium.googlesource.com/external/github.com/WebAssembly/binaryen/+/86f0d65bcf87c2491698b7cfd526f2f0614a75dd%5E%21/>
