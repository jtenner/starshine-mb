---
kind: comparison
status: supported
last_reviewed: 2026-04-09
sources:
  - ../../../../0068-2026-03-25-global-struct-inference.md
related:
  - ../../../../../src/passes/global_struct_inference.mbt
  - ../../../../../src/passes/global_struct_inference_test.mbt
  - ../../../../../src/passes/optimize.mbt
---

# `global-struct-inference` Binaryen Parity

## Durable Conclusions

- Binaryen's `GlobalStructInference` is a closed-world GC rewrite, not a broad struct-fact analysis.
- The useful oracle surface is immutable globals initialized with top-level `struct.new*` expressions and later consumed by eligible `struct.get*` users.

The first safe Starshine slice is intentionally narrower than full Binaryen parity:

- thread closed-world mode through the pass
- target direct `global.get -> struct.get*` chains first
- preserve null traps with `ref.as_non_null`
- avoid broader type-wide inference until compare evidence says it is needed

## Current In-Tree Status

- The implementation lives in [`../../../../../src/passes/global_struct_inference.mbt`](../../../../../src/passes/global_struct_inference.mbt).
- The focused suite lives in [`../../../../../src/passes/global_struct_inference_test.mbt`](../../../../../src/passes/global_struct_inference_test.mbt).
- The active landed slice rewrites only direct `global.get -> struct.get*` chains backed by immutable top-level `struct.new*` globals.
- The optimize pipeline and registry surfaces include the pass as the early module-level GC precision step after `global-refining`.

## Validation Outcome

- Default-mode `--global-struct-inference` compare runs kept canonical wasm and normalized WAT parity; the pass is effectively gated off without closed-world mode.
- Closed-world `--global-struct-inference` runs also kept canonical and normalized parity, with isolated pass time staying cheap.
- The remaining ordered-prefix wall-time gap is upstream of `global-struct-inference`, not a reason to widen the current slice.

## Practical Rule

- Keep the current direct-global closed-world slice.
- Do not widen to broader type-wide inference until the neighboring module-pass and pipeline costs are better understood.
- Treat remaining performance pressure as earlier-pass or pipeline-overhead work unless new compare evidence points directly at `GSI`.

## Sources

- Numbered research doc: [`../../../../0068-2026-03-25-global-struct-inference.md`](../../../../0068-2026-03-25-global-struct-inference.md)
- Implementation: [`../../../../../src/passes/global_struct_inference.mbt`](../../../../../src/passes/global_struct_inference.mbt)
- Focused tests: [`../../../../../src/passes/global_struct_inference_test.mbt`](../../../../../src/passes/global_struct_inference_test.mbt)
