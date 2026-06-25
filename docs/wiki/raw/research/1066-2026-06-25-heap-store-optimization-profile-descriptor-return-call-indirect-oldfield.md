---
kind: research
status: supported
created: 2026-06-25
sources:
  - ./1002-2026-06-21-heap-store-optimization-result-try-table-return-call-indirect-old-field.md
  - ./1009-2026-06-21-heap-store-optimization-descriptor-call-indirect-old-field-boundary.md
  - ./1063-2026-06-25-heap-store-optimization-profile-return-call-indirect-oldfield.md
  - ./1065-2026-06-25-heap-store-optimization-profile-descriptor-return-call-oldfield.md
  - ../../../src/validate/gen_valid.mbt
  - ../../../src/fuzz/main_wbtest.mbt
  - ../../binaryen/passes/heap-store-optimization/fuzzing.md
---

# HSO generated descriptor `return_call_indirect` old-field wrapper floor

## Question

Can the dedicated HSO GenValid profile cover the pure-descriptor result-typed `try_table` / `return_call_indirect` old-field sibling after adding the direct descriptor tail-call floor in `1065`?

## Answer

Yes. The profile now emits a descriptor-bearing `struct.new_desc` root whose overwritten field is a true no-param `(result i32)` helper call. The descriptor operand is pure (`struct.new_default` of the descriptor type), the constructor is assigned to the exact described local, then a result-typed `try_table` exits through `i32.const 0; return_call_indirect` using table slot zero before a later same-local same-field `struct.set` marker `i32.const I32(151)`.

This extends pure-descriptor generated tail-call old-field coverage to the indirect spelling. It relies on the same deterministic table slot that already backs the plain `return_call_indirect` profile floor from `1063`.

## Red/green profile floor

The focused profile floor first added an assertion for marker `151` in `src/fuzz/main_wbtest.mbt`. The red run failed because the profile had descriptor direct-tail-call marker `150` but no descriptor indirect-tail-call sibling. After updating `src/validate/gen_valid.mbt`, the focused run passed.

## Validation

```sh
moon test --package jtenner/starshine/fuzz --file main_wbtest.mbt -p 'heap-store-optimization profile records GC store opportunities'
```

Red result: failed at the new `i32.const I32(151)` floor.

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
  --out-dir .tmp/pass-fuzz-heap-store-optimization-descriptor-return-call-indirect-oldfield-profile-20 \
  --jobs auto \
  --starshine-bin target/native/release/build/cmd/cmd.exe \
  --max-failures 2000 \
  --keep-going-after-command-failures
```

Result: compared `20/20`, normalized `0`, compare-normalized `20`, validation/property/generator/command failures `0`, mismatches `0`, Binaryen cache `0` hits / `20` misses.

```sh
bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed \
  --pass heap-store-optimization \
  --out-dir .tmp/pass-fuzz-heap-store-optimization-descriptor-return-call-indirect-oldfield-direct-1000 \
  --jobs auto \
  --starshine-bin target/native/release/build/cmd/cmd.exe \
  --max-failures 2000 \
  --keep-going-after-command-failures
```

Result: compared `1000/1000`, normalized `1000`, compare-normalized `0`, validation/property/generator/command failures `0`, mismatches `0`, Binaryen cache `1000` hits / `0` misses.

## Classification and remaining work

Classification: generated-profile coverage expansion for a source-backed Binaryen behavior boundary. This adds the pure-descriptor indirect-tail-call result-wrapper old-field sibling to the dedicated profile; it is not an output-shape deferral and not a broad claim that HSO is closed.

Pure-descriptor generated tail-call result-wrapper old-field coverage now has direct `return_call` and `return_call_indirect` spellings. Pure-descriptor typed-function-reference tail-call coverage, mutable-descriptor generated tail-call siblings, exact descriptor `ref.cast`, broader HSO-D/E/F/G/I/J closeout work, performance refresh, O4z slot/neighborhood replay, and the final required compare matrix remain open.
