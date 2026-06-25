---
kind: research
status: supported
created: 2026-06-25
sources:
  - ./1052-2026-06-25-heap-store-optimization-mutable-descriptor-return-call-ref-oldfield.md
  - ./1067-2026-06-25-heap-store-optimization-profile-descriptor-return-call-ref-oldfield.md
  - ./1068-2026-06-25-heap-store-optimization-profile-mutable-descriptor-return-call-oldfield.md
  - ./1069-2026-06-25-heap-store-optimization-profile-mutable-descriptor-return-call-indirect-oldfield.md
  - ../../../src/validate/gen_valid.mbt
  - ../../../src/fuzz/main_wbtest.mbt
  - ../../binaryen/passes/heap-store-optimization/fuzzing.md
---

# HSO generated mutable-descriptor `return_call_ref` old-field wrapper floor

## Question

Can the dedicated HSO GenValid profile complete the mutable-descriptor tail-call old-field generated trio with a `return_call_ref` result-wrapper sibling?

## Answer

Yes. The profile now emits a mutable-descriptor `struct.new_desc` root whose overwritten field is a true no-param `(result i32)` helper call. The descriptor operand is a mutable exact-descriptor `global.get`, the constructor is assigned to the exact described local, then a result-typed `try_table` builds `ref.func` for the current no-param/no-result function and exits through `return_call_ref` before a later same-local same-field `struct.set` marker `i32.const I32(155)`.

This is the generated mutable-descriptor sibling of the pure-descriptor typed-function-reference tail-call profile floor from `1067` and of the focused source-backed mutable descriptor `return_call_ref` family from `1052`. With `1068` and `1069`, it completes the generated mutable-descriptor tail-call result-wrapper old-field trio.

## Red/green profile floor

The focused profile floor first added an assertion for marker `155` in `src/fuzz/main_wbtest.mbt`. The red run failed because marker `155` was absent. After updating `src/validate/gen_valid.mbt`, the focused run passed.

## Validation

```sh
moon test --package jtenner/starshine/fuzz --file main_wbtest.mbt -p 'heap-store-optimization profile records GC store opportunities'
```

Red result: failed at the new `i32.const I32(155)` floor.

Green result: `92/92` passed.

```sh
moon fmt
moon build --target-dir target --target native --release src/cmd
```

Result: both passed; native build reported the existing `src/passes/pass_manager.mbt` unused-function warnings.

```sh
bun scripts/pass-fuzz-compare.ts --count 20 --seed 0x5eed \
  --pass heap-store-optimization \
  --gen-valid-profile heap-store-optimization \
  --normalize local-cleanup-debris \
  --out-dir .tmp/pass-fuzz-heap-store-optimization-mutable-descriptor-return-call-ref-oldfield-profile-20 \
  --jobs auto \
  --starshine-bin target/native/release/build/cmd/cmd.exe \
  --max-failures 2000 \
  --keep-going-after-command-failures
```

Result: compared `20/20`, normalized `0`, compare-normalized `20`, validation/property/generator/command failures `0`, mismatches `0`, Binaryen cache `0` hits / `20` misses.

```sh
bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed \
  --pass heap-store-optimization \
  --out-dir .tmp/pass-fuzz-heap-store-optimization-mutable-descriptor-return-call-ref-oldfield-direct-1000 \
  --jobs auto \
  --starshine-bin target/native/release/build/cmd/cmd.exe \
  --max-failures 2000 \
  --keep-going-after-command-failures
```

Result: compared `1000/1000`, normalized `1000`, compare-normalized `0`, validation/property/generator/command failures `0`, mismatches `0`, Binaryen cache `1000` hits / `0` misses.

## Classification and remaining work

Classification: generated-profile coverage expansion for a source-backed Binaryen behavior boundary. This adds the mutable-descriptor `return_call_ref` result-wrapper old-field sibling to the dedicated profile; it is not an output-shape deferral and not a broad claim that HSO is closed.

Generated tail-call result-wrapper old-field coverage now includes the plain, pure-descriptor, and mutable-descriptor direct, indirect, and typed-function-reference spellings. Exact descriptor `ref.cast`, broader HSO-D/E/F/G/I/J closeout work, performance refresh, O4z slot/neighborhood replay, and the final required compare matrix remain open.
