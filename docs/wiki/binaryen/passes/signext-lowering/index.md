---
kind: pass
status: supported
last_reviewed: 2026-04-25
sources:
  - ../../../raw/binaryen/2026-04-25-signext-lowering-primary-sources.md
  - ../../../raw/research/0349-2026-04-25-signext-lowering-source-dossier.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/wast/types.mbt
  - ../../../../../src/validate/typecheck.mbt
related:
  - ./binaryen-strategy.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../optimize-instructions/index.md
  - ../pick-load-signs/index.md
---

# `signext-lowering`

`signext-lowering` is Binaryen's feature-lowering pass for WebAssembly sign-extension instructions.

The pass takes the five sign-extension opcodes:

- `i32.extend8_s`
- `i32.extend16_s`
- `i64.extend8_s`
- `i64.extend16_s`
- `i64.extend32_s`

and rewrites them to older same-width shift pairs. After that rewrite, Binaryen clears its `SignExt` feature bit for the module. The goal is not to make code smaller or faster. The goal is to make a module that uses sign-extension opcodes representable on targets that do not support the sign-extension feature directly. See the raw source capture in [`../../../raw/binaryen/2026-04-25-signext-lowering-primary-sources.md`](../../../raw/binaryen/2026-04-25-signext-lowering-primary-sources.md).

## Current Starshine status

Starshine does **not** currently expose `signext-lowering` as a public pass name.

- It is not active, boundary-only, removed, or a preset in [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt).
- It has no dispatcher or owner file in [`../../../../../src/passes/pass_manager.mbt`](../../../../../src/passes/pass_manager.mbt).
- Starshine does have prerequisite sign-extension instruction support in WAT parsing, library IR, validation, binary encoding, HOT lifting, and neighboring optimization logic. The exact local code map is in [`starshine-strategy.md`](starshine-strategy.md).

That means this folder is a source-backed upstream-only dossier plus a future-port map, not a claim that Starshine already implements the pass.

## Invariants

A faithful `signext-lowering` implementation must preserve these invariants:

1. **Value semantics:** every input value must produce the same sign-extended result as the original opcode.
2. **Operand effects:** the child expression must still execute exactly once and in the same relative place.
3. **Type preservation:** i32 opcodes remain `i32 -> i32`; i64 opcodes remain `i64 -> i64`.
4. **No neighboring rewrites:** the pass should not absorb `optimize-instructions` sign-extension cleanup or `pick-load-signs` load-sign selection.
5. **Feature lowering:** Binaryen also disables `FeatureSet::SignExt`; a Starshine port needs an explicit decision about target-feature metadata because local feature modeling is not currently Binaryen-identical.

## Inputs and outputs

Input: a module whose function bodies may contain sign-extension unary instructions.

Output: a module with those instructions replaced by shift pairs:

```wat
(i32.extend8_s X)
```

becomes:

```wat
(i32.shr_s
  (i32.shl X (i32.const 24))
  (i32.const 24))
```

The other four opcodes use the matching sign-bit shift count. [`wat-shapes.md`](wat-shapes.md) lists the full shape catalog.

## Correctness constraints

The rewrite relies on the standard two-shift sign-extension identity:

1. left-shift the low-width signed field until its sign bit reaches the high bit of the storage type;
2. arithmetic-right-shift by the same amount to fill high bits with that sign bit.

The child expression is not duplicated; it is moved under the new left shift. That avoids double execution for loads, calls, traps, or other effectful children.

The pass also must not use logical right shift. Logical right shift would zero-fill high bits and therefore implement a zero-extension-like result for negative low-width values.

## Edge cases

- `i64.extend32_s` is a same-width `i64` operation, not `i64.extend_i32_s`. Lowering uses `i64.shl` / `i64.shr_s` with shift count `32`.
- An effectful child remains effectful exactly once. The lowering is safe because it nests the original child, not because the child is pure.
- The pass should still lower already-optimized or redundant sign-extension opcodes. Dead-code or redundancy cleanup belongs to later passes.
- Starshine's current custom-section handling does not provide a direct Binaryen `FeatureSet::SignExt` equivalent. Feature metadata is therefore the main local design caveat.

## Validation guidance

For a future Starshine port:

1. Add focused tests for all five opcode families.
2. Include effectful-child tests such as a load or call underneath the sign-extension opcode to ensure the child is not duplicated.
3. Validate the output WAT/binary after the pass.
4. Compare against Binaryen with `wasm-opt --signext-lowering` when the pass becomes public locally.
5. Check whether any target-feature custom section or feature model remains stale after instruction rewriting.

## Related pages

- [`binaryen-strategy.md`](binaryen-strategy.md) - upstream implementation and test strategy.
- [`wat-shapes.md`](wat-shapes.md) - concrete before/after instruction shapes.
- [`starshine-strategy.md`](starshine-strategy.md) - exact local code-location map and future port notes.
- [`../optimize-instructions/index.md`](../optimize-instructions/index.md) - neighboring optimization pass that reasons about sign-extension patterns.
- [`../pick-load-signs/index.md`](../pick-load-signs/index.md) - neighboring pass that may choose signed loads based on sign-extension uses.
