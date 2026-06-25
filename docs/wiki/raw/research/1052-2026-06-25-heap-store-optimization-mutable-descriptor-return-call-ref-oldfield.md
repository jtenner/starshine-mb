---
kind: research
status: supported
created: 2026-06-25
sources:
  - ./1014-2026-06-23-heap-store-optimization-mutable-descriptor-return-call-ref.md
  - ./1049-2026-06-25-heap-store-optimization-mutable-descriptor-oldfield-callrefs.md
  - ./1051-2026-06-25-heap-store-optimization-mutable-descriptor-tail-oldfield-call.md
  - ../../../src/passes/heap_store_optimization_test.mbt
---

# HSO mutable descriptor `return_call_ref` old-field coverage

Question: do focused HSO tests cover the typed-function-reference tail-call sibling of mutable descriptor result-wrapper old-field variants?

## Answer

Now yes. A focused HSO test covers:

- mutable descriptor `global.get` + `struct.new_desc`;
- overwritten old field produced by `call_ref`;
- catchable result-typed `try_table` / `return_call_ref` wrapper; and
- later same-field `struct.set`.

The optimized output is required to keep `struct.new_desc`, `global.get`, `try_table`, `return_call_ref`, and `struct.set`. This complements `1051`'s direct/indirect tail-call wrappers and `1049`'s non-tail `call_ref` old-field coverage.

## Validation

```sh
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt
```

Result: `413/413` passed.

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
  --out-dir .tmp/pass-fuzz-heap-store-optimization-mutable-desc-return-call-ref-oldfield-direct-1000 \
  --jobs auto \
  --starshine-bin target/native/release/build/cmd/cmd.exe \
  --max-failures 2000 \
  --keep-going-after-command-failures
```

Result: compared `1000/1000`, normalized matches `1000`, compare-normalized matches `0`, validation failures `0`, property failures `0`, generator failures `0`, command failures `0`, mismatches `0`, Binaryen cache `1000` hits / `0` misses.

## Remaining coverage

Focused mutable descriptor result-wrapper old-field coverage now includes direct, indirect, `call_ref`, `return_call`, `return_call_indirect`, and `return_call_ref` wrapper siblings. This still does not create generated true call-result old-field profile coverage; the profile blocker from `1047` remains open. Exact descriptor `ref.cast` also remains blocked by `1048`.
