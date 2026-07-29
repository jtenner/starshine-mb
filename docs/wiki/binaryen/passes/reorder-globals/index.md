---
kind: entity
status: supported
last_reviewed: 2026-07-29
sources:
  - ../../../../../src/passes/reorder_globals.mbt
  - ../../../../../src/passes/reorder_globals_test.mbt
  - ../../../../../src/passes/reorder_globals_wbtest.mbt
  - ../../../../../src/validate/gen_valid_reorder_globals.mbt
  - ./fuzzing.md
  - ../../../../../src/passes/optimize.mbt
  - ../../no-dwarf-default-optimize-path.md
  - ../../../../../agent-todo.md
  - ../late-pipeline-dispatch.md
  - ../tracker.md
related:
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./size-model-and-dependency-order.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ./fuzzing.md
  - ../string-gathering/index.md
  - ../reorder-globals-always/index.md
  - ../directize/index.md
  - ../../no-dwarf-default-optimize-path.md
  - ../tracker.md
---

# `reorder-globals`

## Role

- `reorder-globals` is an upstream Binaryen late module / boundary-shaped global-layout pass.
- It now has an active direct Starshine module-pass port; `reorder-globals-always` remains boundary-only.
- The current source oracle is official Binaryen `version_131`, tag commit `1f903c14babf829745b421b92ff0f286e93e4209`.
- In Binaryen `version_131`, it runs near the very end of the no-DWARF optimize pipeline.
- Its job is to reorder the complete imported-plus-defined global vector so that more index-sensitive globals get smaller indices, while keeping all imports before definitions and preserving global-initializer dependency order.

## Why it matters

- The canonical Binaryen no-DWARF `-O` / `-Os` post-pass phase runs `reorder-globals` after:
  - `duplicate-import-elimination`
  - `simplify-globals-optimizing`
  - `remove-unused-module-elements`
  - `string-gathering` when strings are enabled
- and before:
  - `directize`
- The saved generated-artifact `-O4z` audit records one real skipped top-level upstream slot:
  - slot `55`
- The saved Binaryen debug log shows it is tiny but real in that captured run:
  - `0.000166174` seconds
- The direct Binaryen-v131 behavior audit and renewed four-lane matrix closed on 2026-07-29; only independently owned preset/neighborhood work remains in the active backlog.
- The pass also matters as the explicit handoff target from `string-gathering`: Binaryen’s own scheduler comment says gathering happens right before `reorder-globals`, which then sorts the globals properly.
- The folder now also has a v131 source anchor, a dedicated implementation/test map, a seven-leaf fuzzing contract, and a Starshine status page, so readers can move directly from upstream owner/test surfaces to the active numeric-`GlobalIdx` implementation, final matrix, and remaining `always` sibling boundary.

## Beginner summary

A safe beginner mental model is:

- Binaryen looks at how often each global is used,
- keeps imports and initializer dependencies honest,
- tries a few dependency-safe candidate orders,
- estimates which order makes encoded global indices cheapest,
- and then keeps the cheapest one.

That is much closer to the real pass than either:

- “sort globals by raw use count”, or
- “repair the order after string-gathering”, or
- “always reorder globals for size”.

## Current durable takeaways

- `reorder-globals` is a **module-wide declaration-layout pass**, not a function-local rewrite pass.
- In `version_131`, the implementation lives in `src/passes/ReorderGlobals.cpp`.
- The public pass skips all work when there are fewer than `128` globals.
- The internal / test `reorder-globals-always` variant removes that cutoff and uses a smoothed synthetic cost model instead.
- Binaryen counts both `global.get` and `global.set` uses.
- It counts those uses in functions **and** in module-level code.
- Dependency constraints come from `GlobalGet` inside non-imported global initializers.
- Imported globals are always kept before defined globals, but imported globals may reorder among themselves; this distinction exposed and fixed the 2026-07-29 Starshine parity gap.
- The pass tries four candidate strategies:
  - original-ish dependency-only order
  - raw-count greedy order
  - summed-dependent-count order
  - exponentially weighted dependent-count order
- Candidate orders are scored with the **true** observed use counts, not the synthetic search counts.
- Binaryen IR tracks globals by `Name`, so the pass reorders `module->globals` and refreshes maps instead of patching every use site manually.
- `string-gathering` and `reorder-globals` are intentionally different passes:
  - `string-gathering` does a narrow validity-first reorder
  - `reorder-globals` does the stronger late size/layout reorder

## Current repo caveat

- The current Starshine pass registry now splits the family explicitly:
  - `reorder-globals` is an active direct module pass implemented in `src/passes/reorder_globals.mbt`
  - `reorder-globals-always` remains a boundary-only tracked name
- The active pass implements the public production policy, including the `<128` total-global no-op, absolute imported-plus-defined dependency ordering, all four candidate families, true ULEB-size scoring, imported-global reordering within a fixed import prefix, preservation of non-global import positions, and numeric `GlobalIdx` remapping across module/code/name surfaces.
- The 2026-07-29 performance-final native SHA-256 `d09b0100360cb83d87545fb1ca92e98f01780882d1649acf2aa96293d364aadc` is exact against explicit official Binaryen v131 for regular `100000/100000` and dedicated `reorder-globals-all` `10000/10000`. Random-all retains only 625 pass-independent `-8`-byte multivalue codec wins, and wasm-smith matches all 9956 comparable cases after the established unreachable-debris normalization, with 44 Binaryen/tool failures and zero Starshine failures. The ready-heap follow-up reduces the 2,000-import median from `70.079 ms` to `0.742 ms`, about `2.27x` faster than Binaryen; the 2,000-global dependency chain is about `1.96x` faster. See [`./fuzzing.md`](./fuzzing.md).
- The public optimize/shrink presets now schedule the accepted late-tail suffix. The inner `string-gathering -> reorder-globals -> directize` triple has explicit regression coverage plus a current-head debug-artifact replay at research note 0549. The broader `simplify-globals-optimizing -> remove-unused-module-elements -> string-gathering -> reorder-globals -> directize` neighborhood is directly oracle-proven with standard 10k ordered-neighborhood fuzz and same-input RUME isolation; the remaining artifact frontier is inherited SGO representation/function-layout drift, not a late string/reorder/directize mismatch. See [research note 0571](../late-pipeline-dispatch.md) and [research note 0572](../late-pipeline-dispatch.md).

Keep preserving the distinction between the public pass and the `always` helper instead of collapsing them accidentally.

## Page map

- [`./binaryen-strategy.md`](./binaryen-strategy.md)
  Deep dive into the actual Binaryen `version_131` implementation: scheduler placement, phase breakdown, helper dependencies, candidate-search structure, and the real “what this is not” facts.
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md)
  Source-confirmed owner/helper/lit-test map plus the active Starshine numeric-`GlobalIdx` implementation, direct evidence, and remaining late-tail gap.
- [`./size-model-and-dependency-order.md`](./size-model-and-dependency-order.md)
  Focused guide to the use-count model, the dependency DAG, the under-`128` production cutoff, the `reorder-globals-always` variant, and the important internal use from `GlobalStructInference`.
- [`./wat-shapes.md`](./wat-shapes.md)
  Beginner-friendly before/after WAT and module-shape catalog for the main positive, negative, bailout, and interaction families.
- [`./starshine-strategy.md`](./starshine-strategy.md)
  Exact current Starshine status plus the local code/doc map for the active module pass, recorded direct evidence, the proven `string-gathering -> reorder-globals -> directize` triple replay, and the explicit split from `reorder-globals-always`.
- [`./fuzzing.md`](./fuzzing.md)
  Seven-leaf GenValid contract, explicit-v131 four-lane matrix, residual classifications, performance evidence, and reopening criteria.

## Current maintenance rule

- Treat this folder as the canonical home for future `reorder-globals` research and port planning.
- Keep it marked as an active direct Starshine module pass, while keeping `reorder-globals-always` boundary-only. The direct v131 audit and late-tail neighborhood have standard signoff; future changes should add fresh evidence rather than reopening accepted behavior without a source, validity, size, performance, or semantic reason.
- Keep the strategy page, implementation/test-map page, size/dependency page, and Starshine strategy page in sync whenever new evidence changes the answer to either:
  - “what does the pass actually optimize for?”
  - “when does Binaryen deliberately do nothing?”
  - “what exact local remap and late-tail landing story would a future Starshine port need to preserve?”

## Sources

- research note 0689
- research note 0525
- research note 0367
- research note 0125
- research note 0270
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../../no-dwarf-default-optimize-path.md`](../../no-dwarf-default-optimize-path.md)
- [`../../../../../agent-todo.md`](../../../../../agent-todo.md)
- [research note 0093](../late-pipeline-dispatch.md) preserves the saved generated-artifact `-O4z` skipped-slot, summary, and Binaryen debug-log facts; older `.artifacts` paths are replay identifiers, not durable wiki source links.
- [`../tracker.md`](../tracker.md)
- Binaryen `version_131` implementation and test sources:
  - <https://github.com/WebAssembly/binaryen/blob/version_131/src/passes/ReorderGlobals.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_131/src/passes/pass.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_131/src/passes/passes.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_131/src/pass.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_131/src/wasm-traversal.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_131/src/support/topological_sort.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_131/src/wasm.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_131/src/passes/GlobalStructInference.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_131/test/lit/passes/reorder-globals.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_131/test/lit/passes/reorder-globals-real.wast>
