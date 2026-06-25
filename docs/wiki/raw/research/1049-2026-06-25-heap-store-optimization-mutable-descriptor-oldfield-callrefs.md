---
kind: research
status: supported
created: 2026-06-25
sources:
  - ./1011-2026-06-23-heap-store-optimization-mutable-descriptor-result-wrapper.md
  - ./1012-2026-06-23-heap-store-optimization-mutable-descriptor-call-ref.md
  - ./1045-2026-06-25-heap-store-optimization-profile-mutable-descriptor-old-field.md
  - ../../../src/passes/heap_store_optimization_test.mbt
---

# HSO mutable descriptor result-wrapper old-field call coverage

Question: do focused HSO tests cover mutable descriptor result-wrapper old-field variants for indirect calls and typed-function-reference calls, beyond the generated direct-call/memory.grow root from `1045`?

## Answer

Now yes for two additional source-backed focused surfaces:

- mutable descriptor `global.get` + `struct.new_desc` whose overwritten old field is a result-producing `call_indirect`, followed by a catchable result-typed `try_table` / `call_indirect` wrapper and a later same-field `struct.set`;
- mutable descriptor `global.get` + `struct.new_desc` whose overwritten old field is a result-producing `call_ref`, followed by a catchable result-typed `try_table` / `call_ref` wrapper and a later same-field `struct.set`.

Both tests assert that Starshine keeps `struct.new_desc`, `global.get`, the result wrapper, the call opcode, and the later `struct.set`. This matches the conservative Binaryen family from `1011`-`1012`: mutable descriptor reads and catchable result wrappers keep the later store rather than being folded through the descriptor operand.

## Validation

```sh
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt
```

Result: `409/409` passed.

```sh
moon fmt
```

Result: passed.

```sh
moon build --target-dir target --target native --release src/cmd
```

Result: passed/no work to do.

```sh
bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed \
  --pass heap-store-optimization \
  --out-dir .tmp/pass-fuzz-heap-store-optimization-mutable-desc-oldfield-callref-indirect-direct-1000 \
  --jobs auto \
  --starshine-bin target/native/release/build/cmd/cmd.exe \
  --max-failures 2000 \
  --keep-going-after-command-failures
```

Result: compared `1000/1000`, normalized matches `1000`, compare-normalized matches `0`, validation failures `0`, property failures `0`, generator failures `0`, command failures `0`, mismatches `0`, Binaryen cache `1000` hits / `0` misses.

## Remaining coverage

This narrows HSO-D/E around mutable descriptor result-wrapper old-field call families, but it does not close every generated-profile or behavior variant:

- generated profile coverage still has only the `1045` mutable-descriptor old-field direct-call wrapper with an overwritten `memory.grow`, plus the `1047` no-result callable blocker for true generated call-result old fields;
- tail-call mutable descriptor old-field variants remain focused-test backed from earlier coverage and are not generated-profile backed;
- exact descriptor `ref.cast` remains blocked by Starshine decode/local surface per `1048`.
