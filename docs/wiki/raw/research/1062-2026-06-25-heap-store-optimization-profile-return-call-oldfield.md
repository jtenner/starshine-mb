---
kind: research
status: supported
created: 2026-06-25
sources:
  - ./1001-2026-06-21-heap-store-optimization-result-try-table-return-call-old-field-boundary.md
  - ./1054-2026-06-25-heap-store-optimization-profile-direct-call-result-oldfield.md
  - ../../../src/validate/gen_valid.mbt
  - ../../../src/fuzz/main_wbtest.mbt
  - ../../binaryen/passes/heap-store-optimization/fuzzing.md
---

# HSO generated direct `return_call` old-field wrapper floor

## Question

Can the dedicated HSO GenValid profile cover the source-backed result-typed `try_table` / direct `return_call` old-field boundary from `1001`, without conflating it with the bottom tail-call-as-constructor-field boundary from `1053`?

## Answer

Yes. The profile now emits a plain `struct.new` root whose overwritten field is a true no-param `(result i32)` helper call, followed by a result-typed `try_table` wrapper whose body exits through direct `return_call`, then a later same-local same-field `struct.set` marker `i32.const I32(147)`.

This is deliberately not a tail call used as the constructor field value. The constructor old field is completed by the helper `call`; the tail-call opcode is in the later result wrapper that Binaryen `version_130` keeps as a no-fold boundary for this old-field family.

## Red/green profile floor

The focused profile floor first added assertions for `return_call` and marker `147` in `src/fuzz/main_wbtest.mbt`. The red run failed because the generated HSO artifact lacked both the tail-call wrapper and marker. After updating `src/validate/gen_valid.mbt`, the focused run passed.

## Validation

```sh
moon test --package jtenner/starshine/fuzz --file main_wbtest.mbt -p 'heap-store-optimization profile records GC store opportunities'
```

Red result: failed at the new `return_call` / `i32.const I32(147)` floor.

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
  --out-dir .tmp/pass-fuzz-heap-store-optimization-return-call-oldfield-profile-20 \
  --jobs auto \
  --starshine-bin target/native/release/build/cmd/cmd.exe \
  --max-failures 2000 \
  --keep-going-after-command-failures
```

Result: compared `20/20`, normalized `0`, compare-normalized `20`, validation/property/generator/command failures `0`, mismatches `0`, Binaryen cache `0` hits / `20` misses.

```sh
bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed \
  --pass heap-store-optimization \
  --out-dir .tmp/pass-fuzz-heap-store-optimization-return-call-oldfield-direct-1000 \
  --jobs auto \
  --starshine-bin target/native/release/build/cmd/cmd.exe \
  --max-failures 2000 \
  --keep-going-after-command-failures
```

Result: compared `1000/1000`, normalized `1000`, compare-normalized `0`, validation/property/generator/command failures `0`, mismatches `0`, Binaryen cache `1000` hits / `0` misses.

## Classification and remaining work

Classification: generated-profile coverage expansion for a source-backed Binaryen behavior boundary. This adds direct `return_call` result-wrapper old-field coverage to the dedicated profile; it is not an output-shape deferral and not a broad claim that HSO is closed.

Generated `return_call_indirect` and `return_call_ref` old-field result-wrapper siblings remain open after this slice, along with exact descriptor `ref.cast`, broader HSO-D/E/F/G/I/J closeout work, performance refresh, O4z slot/neighborhood replay, and the final required compare matrix.
