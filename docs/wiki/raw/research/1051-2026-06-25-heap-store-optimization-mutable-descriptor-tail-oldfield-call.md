---
kind: research
status: supported
created: 2026-06-25
sources:
  - ./1013-2026-06-23-heap-store-optimization-mutable-descriptor-tail-calls.md
  - ./1050-2026-06-25-heap-store-optimization-mutable-descriptor-direct-oldfield-call.md
  - ../../../src/passes/heap_store_optimization_test.mbt
---

# HSO mutable descriptor tail-call old-field coverage

Question: do focused HSO tests cover mutable descriptor result-wrapper old-field variants when the catchable result wrapper contains tail calls?

## Answer

Now yes for the direct and indirect tail-call wrappers where the overwritten constructor field is a result-producing direct helper call:

- mutable descriptor `global.get` + `struct.new_desc`, overwritten old field from a direct helper `call`, catchable result-typed `try_table` / `return_call`, later same-field `struct.set`;
- mutable descriptor `global.get` + `struct.new_desc`, overwritten old field from a direct helper `call`, catchable result-typed `try_table` / `return_call_indirect`, later same-field `struct.set`.

Both tests assert that Starshine keeps `struct.new_desc`, `global.get`, `try_table`, the tail-call opcode, and the later `struct.set`. This matches the conservative mutable-descriptor result-wrapper behavior from `1013`: the descriptor read must remain before locally catchable tail-call wrappers, and the later store is not folded through that boundary.

## Validation

```sh
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt
```

Result: `412/412` passed.

```sh
moon fmt
```

Result: passed.

```sh
moon build --target-dir target --target native --release src/cmd
```

Result: passed with the existing `src/passes/pass_manager.mbt` unused-function warnings.

```sh
bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed \
  --pass heap-store-optimization \
  --out-dir .tmp/pass-fuzz-heap-store-optimization-mutable-desc-tail-oldfield-direct-1000 \
  --jobs auto \
  --starshine-bin target/native/release/build/cmd/cmd.exe \
  --max-failures 2000 \
  --keep-going-after-command-failures
```

Result: compared `1000/1000`, normalized matches `1000`, compare-normalized matches `0`, validation failures `0`, property failures `0`, generator failures `0`, command failures `0`, mismatches `0`, Binaryen cache `1000` hits / `0` misses.

## Notes and remaining coverage

An exploratory attempt to make the overwritten old field itself a `return_call_indirect` exposed an invalid transformed output and was not kept as source-backed coverage in this slice. The retained tests cover the source-backed family where the old field has a result-producing call and the later result wrapper is the tail-call boundary.

Typed-function-reference `return_call_ref` mutable descriptor old-field coverage remains a useful adjacent focused slice. Generated true call-result old-field coverage remains blocked by `1047`, and exact descriptor `ref.cast` remains blocked by `1048`.
