---
kind: research
status: supported
created: 2026-06-25
sources:
  - ./1003-2026-06-21-heap-store-optimization-result-try-table-return-call-ref-old-field-boundary.md
  - ./1062-2026-06-25-heap-store-optimization-profile-return-call-oldfield.md
  - ./1063-2026-06-25-heap-store-optimization-profile-return-call-indirect-oldfield.md
  - ../../../src/validate/gen_valid.mbt
  - ../../../src/fuzz/main_wbtest.mbt
  - ../../binaryen/passes/heap-store-optimization/fuzzing.md
---

# HSO generated `return_call_ref` old-field wrapper floor

## Question

Can the dedicated HSO GenValid profile cover the source-backed result-typed `try_table` / `return_call_ref` old-field sibling from `1003`?

## Answer

Yes. The profile now emits a plain `struct.new` root whose overwritten field is a true no-param `(result i32)` helper call, followed by a result-typed `try_table` wrapper whose body builds a typed function reference with `ref.func` and exits through `return_call_ref`, then a later same-local same-field `struct.set` marker `i32.const I32(149)`.

This completes the generated plain tail-call result-wrapper old-field trio (`1062`, `1063`, `1064`). These roots cover the source-backed boundary where the tail call is in a later result wrapper; they do not reclassify bottom-typed tail calls used directly as constructor field operands.

## Red/green profile floor

The focused profile floor first added assertions for `return_call_ref` and marker `149` in `src/fuzz/main_wbtest.mbt`. The red run failed because the HSO profile had the direct and indirect tail-call markers from `1062`/`1063` but no typed-function-reference tail-call sibling. After updating `src/validate/gen_valid.mbt`, the focused run passed.

## Validation

```sh
moon test --package jtenner/starshine/fuzz --file main_wbtest.mbt -p 'heap-store-optimization profile records GC store opportunities'
```

Red result: failed at the new `return_call_ref` / `i32.const I32(149)` floor.

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
  --out-dir .tmp/pass-fuzz-heap-store-optimization-return-call-ref-oldfield-profile-20 \
  --jobs auto \
  --starshine-bin target/native/release/build/cmd/cmd.exe \
  --max-failures 2000 \
  --keep-going-after-command-failures
```

Result: compared `20/20`, normalized `0`, compare-normalized `20`, validation/property/generator/command failures `0`, mismatches `0`, Binaryen cache `0` hits / `20` misses.

```sh
bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed \
  --pass heap-store-optimization \
  --out-dir .tmp/pass-fuzz-heap-store-optimization-return-call-ref-oldfield-direct-1000 \
  --jobs auto \
  --starshine-bin target/native/release/build/cmd/cmd.exe \
  --max-failures 2000 \
  --keep-going-after-command-failures
```

Result: compared `1000/1000`, normalized `1000`, compare-normalized `0`, validation/property/generator/command failures `0`, mismatches `0`, Binaryen cache `1000` hits / `0` misses.

## Classification and remaining work

Classification: generated-profile coverage expansion for a source-backed Binaryen behavior boundary. This adds the typed-function-reference tail-call result-wrapper old-field sibling to the dedicated profile; it is not an output-shape deferral and not a broad claim that HSO is closed.

Generated plain tail-call result-wrapper old-field coverage is now present for direct, indirect, and typed-function-reference spellings. Exact descriptor `ref.cast`, broader HSO-D/E/F/G/I/J closeout work, performance refresh, O4z slot/neighborhood replay, and the final required compare matrix remain open.
