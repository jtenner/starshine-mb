---
kind: research
status: current
last_reviewed: 2026-05-08
sources:
  - ../../binaryen/passes/reorder-globals/index.md
  - ../../binaryen/passes/reorder-globals/starshine-strategy.md
  - ../../binaryen/passes/directize/index.md
  - ../../binaryen/passes/directize/starshine-strategy.md
  - ../../../../src/passes/reorder_globals_test.mbt
  - ../../../../agent-todo.md
related:
  - ../../binaryen/passes/reorder-globals/index.md
  - ../../binaryen/passes/reorder-globals/starshine-strategy.md
  - ../../binaryen/passes/directize/index.md
  - ../../binaryen/passes/directize/starshine-strategy.md
  - ./0525-2026-05-06-reorder-globals-direct-revalidation.md
  - ./0521-2026-05-06-directize-direct-revalidation.md
---

# Late-tail triple replay for `reorder-globals` and `directize`

## Question

Now that `string-gathering`, `reorder-globals`, and `directize` are all active local module passes, can the late-tail triple `string-gathering -> reorder-globals -> directize` be replayed together and removed as the remaining `RG` / `DIR` blocker?

## Evidence

### New ordered-neighborhood regression

Added `test "string-gathering reorder-globals directize preserve late-tail order"` to `src/passes/reorder_globals_test.mbt`.

The fixture deliberately combines:

- `129` mutable integer globals so public `reorder-globals` must really run,
- one exported hot global at raw index `128`,
- one direct `string.const` use so `string-gathering` inserts a new global first,
- one constant-table `call_indirect` so `directize` must rewrite the tail.

The regression proves the intended order indirectly but robustly:

- after the full triple, the exported hot global ends at index `0`, which can only happen if `reorder-globals` ran after `string-gathering` inserted and remapped globals;
- the final function body contains no `string.const`;
- the final function body contains a direct `call (Func 0)` and no `call_indirect`.

### Current-head artifact replay

Ran on 2026-05-08:

- `moon test src/passes`
- `bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --out-dir .tmp/self-opt-string-reorder-directize-20260508 --string-gathering --reorder-globals --directize`

The artifact replay reported:

- canonical wasm equal: `yes`
- normalized WAT equal: `yes`
- Starshine runtime: `906.297 ms`
- Binaryen runtime: `505.274 ms`
- Starshine pass runtime: `108.410 ms`
- Binaryen pass runtime: `46.845 ms`

This replay uses the checked-in debug WASI artifact. `string-gathering` is effectively a no-op on that input, but the full triple still compares green and proves the active CLI/module-pass lane can replay the exact local late-tail neighborhood together.

## Conclusion

The local `string-gathering -> reorder-globals -> directize` triple is now replayable and regression-covered. That closes the remaining `RG` / `DIR` late-tail triple blocker.

What remains open is broader preset scheduling under `[SG]002`: Starshine still lacks the earlier scheduled neighbors (`simplify-globals-optimizing` and the full `remove-unused-module-elements`-fed late tail), so public `optimize` / `shrink` should stay unchanged for now.
