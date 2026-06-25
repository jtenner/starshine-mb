---
kind: research
status: active
created: 2026-06-25
sources:
  - ./0869-2026-06-20-heap-store-optimization-exact-descriptor-cast-surface.md
  - ./0776-2026-06-20-heap-store-optimization-v130-source-refresh.md
  - ../../binaryen/passes/heap-store-optimization/index.md
  - ../../../src/passes/heap_store_optimization_test.mbt
  - ../../../src/binary/decode.mbt
---

# HSO exact descriptor `ref.cast` blocker recheck

Question: did the exact descriptor `ref.cast` surface from `0869` become runnable after the latest HSO descriptor branch-result and profile work?

## Answer

No. The blocker is unchanged with the refreshed native compare binary and local Binaryen `version_130` oracle.

Binaryen still accepts the exact probe and preserves the later `struct.set`, proving this remains a real HSO descriptor-operand negative to cover once Starshine can decode or locally express the shape. Starshine still fails before HSO can run, during binary decode of the exact descriptor cast encoding.

## Probe shape

The checked local probe uses:

```wat
(ref.cast (ref (exact $desc))
  (global.get $descg))
```

as the descriptor operand to `struct.new_desc`. The later same-field `struct.set` value is a helper call. Binaryen preserves the constructor, the exact descriptor cast, and the later store so the descriptor-cast trap order remains before the helper call.

## Commands and observed results

The explicit compare binary was refreshed first:

```sh
moon build --target-dir target --target native --release src/cmd
```

The exact WAT probe was converted with `wasm-tools` and run through Binaryen:

```sh
wasm-tools parse .tmp/hso-probe-desc-ref-cast-call.wat \
  -o .tmp/hso-probe-desc-ref-cast-call.current.wasm
wasm-opt --all-features --heap-store-optimization \
  .tmp/hso-probe-desc-ref-cast-call.current.wasm \
  -S -o .tmp/hso-probe-desc-ref-cast-call.binaryen-current.wat
```

The Binaryen output still contains `struct.new_desc`, the exact `ref.cast`, the later `struct.set`, and the helper `call`. This matches `0869` and keeps the expected Binaryen behavior narrow: preserve the store, do not fold across the exact descriptor-cast trap.

Starshine still fails before pass execution:

```sh
target/native/release/build/cmd/cmd.exe \
  --heap-store-optimization \
  --dump .tmp/hso-probe-desc-ref-cast-call.star-current.wat \
  .tmp/hso-probe-desc-ref-cast-call.current.wasm \
  -o .tmp/hso-probe-desc-ref-cast-call.star-current.wasm
```

Observed result:

```text
error: decode failed for .tmp/hso-probe-desc-ref-cast-call.current.wasm: DecodeAt(InvalidS33Range, 71, 34)
```

## Classification

This remains a Starshine binary/local surface blocker, not an HSO semantic non-goal and not an accepted drift family. The current descriptor `br_on_non_null` coverage from `1041` exercises another exact descriptor branch-result path, but it does not cover exact descriptor `ref.cast`.

## Reopening / closure criteria

Keep HSO-D/H open for this exact surface until one of these happens:

- Starshine binary decode accepts the exact descriptor-cast probe;
- the local instruction/test surface can express the exact `ref.cast (ref (exact $desc))` operand and validate it before HSO; or
- a binary replay path can run HSO over the exact probe without using the blocked local surface.

Then add a focused HSO negative proving Starshine preserves `struct.set` like Binaryen for this trap-order family, or fix HSO if it folds unsafely.
