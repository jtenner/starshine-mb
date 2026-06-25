---
kind: research
status: supported
created: 2026-06-25
sources:
  - ./1011-2026-06-23-heap-store-optimization-mutable-descriptor-result-wrapper.md
  - ./1045-2026-06-25-heap-store-optimization-profile-mutable-descriptor-old-field.md
  - ./1049-2026-06-25-heap-store-optimization-mutable-descriptor-oldfield-callrefs.md
  - ../../../src/passes/heap_store_optimization_test.mbt
---

# HSO mutable descriptor direct-call old-field coverage

Question: do focused HSO tests cover the direct-call sibling of the mutable descriptor result-wrapper old-field family?

## Answer

Now yes. A focused HSO test covers a mutable descriptor `global.get` feeding `struct.new_desc` where the overwritten field is a result-producing direct helper `call`, followed by a catchable result-typed `try_table` / direct-call wrapper and a later same-field `struct.set`.

The optimized output is required to keep:

- `struct.new_desc`, because the mutable descriptor boundary remains visible;
- `global.get`, preserving the mutable descriptor read;
- `try_table` and `call`, preserving the catchable result wrapper; and
- `struct.set`, matching the conservative Binaryen result-wrapper old-field family rather than folding the later store through the mutable descriptor operand.

This complements `1049`, which added the `call_indirect` and `call_ref` focused siblings.

## Validation

```sh
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt
```

Result: `410/410` passed. The first attempted fixture was invalid because it left an extra `i32.const` before the helper call; after correcting the field stack shape, the focused suite passed.

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
  --out-dir .tmp/pass-fuzz-heap-store-optimization-mutable-desc-direct-oldfield-direct-1000 \
  --jobs auto \
  --starshine-bin target/native/release/build/cmd/cmd.exe \
  --max-failures 2000 \
  --keep-going-after-command-failures
```

Result: compared `1000/1000`, normalized matches `1000`, compare-normalized matches `0`, validation failures `0`, property failures `0`, generator failures `0`, command failures `0`, mismatches `0`, Binaryen cache `1000` hits / `0` misses.

## Remaining coverage

This narrows focused mutable descriptor old-field call coverage to direct, indirect, and typed-function-reference non-tail calls. It does not add generated true call-result old-field coverage; that remains blocked by the dedicated profile's no-param/no-result callable contract from `1047`. Tail-call generated/profile siblings and exact descriptor `ref.cast` also remain open.
