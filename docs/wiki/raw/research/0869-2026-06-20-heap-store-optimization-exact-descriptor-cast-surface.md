---
kind: research
status: active
created: 2026-06-20
sources:
  - ./0789-2026-06-20-heap-store-optimization-core-chain-coverage.md
  - ./0776-2026-06-20-heap-store-optimization-v130-source-refresh.md
  - ./0866-2026-06-20-heap-store-optimization-descriptor-br-on-non-null.md
  - ../../binaryen/passes/heap-store-optimization/index.md
  - ../../binaryen/passes/heap-store-optimization/implementation-structure-and-tests.md
  - ../../../src/passes/heap_store_optimization_test.mbt
  - ../../../src/lib/types.mbt
  - ../../../src/binary/decode.mbt
---

# HSO exact descriptor cast surface blocker refresh

Question: can the open exact descriptor `ref.cast` descriptor-operand boundary from `0789` be converted into focused Starshine HSO coverage now that the local instruction surface exposes `ref_cast_desc_eq`?

## Answer

Not yet. Binaryen `version_130` still preserves the later `struct.set` for the exact descriptor `ref.cast` probe, but Starshine still cannot run the exact Binaryen WAT shape through the direct HSO pipeline.

The exact Binaryen probe remains a real HSO-D/H surface blocker, not an accepted HSO semantic non-goal:

- descriptor operand: `(ref.cast (ref (exact $desc)) (global.get $descg))`;
- constructor: `struct.new_desc` for `$pair`;
- later store value: imported helper `call`;
- Binaryen keeps `struct.set`, preserving the descriptor-cast trap before the helper call.

## Local attempts

### Binary/CLI replay of the exact WAT

The checked probe file still decodes in Binaryen, but current Starshine native CLI decode rejects it before HSO can run:

```sh
target/native/release/build/cmd/cmd.exe \
  --heap-store-optimization \
  --dump .tmp/hso-probe-desc-ref-cast-call.star.wat \
  .tmp/hso-probe-desc-ref-cast-call.wat \
  -o .tmp/hso-probe-desc-ref-cast-call.star.wasm
```

Observed result:

```text
sh: 1: wat2wasm: not found
error: decode failed for .tmp/hso-probe-desc-ref-cast-call.wat: DecodeAt(InvalidS33Range, 71, 34)
```

The decode failure matches the earlier `0789` finding. The missing `wat2wasm` shell line is incidental to this command path; the actionable blocker is still Starshine decode of the exact descriptor cast encoding.

### Direct AST attempt using `ref_cast_desc_eq`

A focused HSO test was attempted with `Instruction::ref_cast_desc_eq(false, HeapType::new(TypeIdx::new(0)))` and also with `TypeIdx::new(1)` in the descriptor operand before `struct.new_desc`. Both variants failed fixture validation before the pass could run, so the attempted test was removed to keep the HSO suite green.

This confirms that the local `ref_cast_desc_eq` constructor is not a drop-in representation of Binaryen's exact descriptor `ref.cast` probe for this HSO descriptor-operand shape. It may be a separate typed descriptor-cast surface, but it does not close the exact `ref.cast (ref (exact $desc))` blocker.

## Validation

```sh
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt
```

Result after removing the unsupported attempted fixture: `226/226` passed.

No implementation behavior or committed executable test expectations changed, so no native rebuild or direct compare was required for this surface-classification slice.

## Reopening / closure criteria

Reopen this boundary when one of the following becomes true:

- Starshine binary decode accepts the exact descriptor `ref.cast (ref (exact $desc))` probe;
- the WAT/direct instruction surface can express that exact cast and validate it before HSO;
- HSO gains a binary replay path that can run over the exact probe without going through the blocked local surface.

Do not mark this as an HSO non-goal. Once the surface is available, add a focused HSO negative proving Starshine preserves `struct.set` like Binaryen for the exact descriptor cast trap-order family, or fix HSO if it folds unsafely.
