---
kind: research
status: supported
created: 2026-06-25
sources:
  - ./1047-2026-06-25-heap-store-optimization-profile-call-result-old-field-blocker.md
  - ../../binaryen/passes/heap-store-optimization/fuzzing.md
  - ../../../src/validate/gen_valid.mbt
  - ../../../src/fuzz/main_wbtest.mbt
---

# HSO profile direct call-result old-field root

Question: can the dedicated `heap-store-optimization` GenValid profile distinguish a true call-result old field from the `1046` call-containing value-block approximation?

## Answer

Now yes for the direct-call sibling.

This slice adds an HSO-only no-param `(result i32)` helper type/function to the dedicated profile and emits a deterministic old-field root where the overwritten constructor field value is produced directly by `call` to that helper. The later same-field `struct.set` still writes `i32.const 140`, so HSO must preserve the old call side effect/result production while considering the later store fold.

This closes only the direct-call-result generated floor from `1047`. It does not cover generated `call_indirect`, `call_ref`, descriptor/mutable-descriptor, or tail-call old-field variants.

## Implementation notes

- `gen_valid_heap_store_optimization_profile_config()` still keeps the ordinary random body/call generators disabled and imports disabled.
- The HSO profile now forces at least two function types when the type budget allows it.
- Function type slot `1` is `[] -> [i32]` and defined function slot `1` is a simple helper returning `i32.const 139`.
- The HSO body slice finds that no-param i32-result helper and emits `call`, `ref.null`, `struct.new`, `local.set`, then the later same-field `struct.set` of `i32.const 140`.
- Focused profile coverage now checks both the i32-result function type and the `i32.const I32(140)` marker so the feature floor is not satisfied by the older value-block `call` / `i32.const 137` approximation.

## Validation

Red feature-floor test before implementation:

```sh
moon test --package jtenner/starshine/fuzz --file main_wbtest.mbt \
  -p 'heap-store-optimization profile records GC store opportunities'
```

Result before implementation: failed because the profile had no no-param i32-result function type and no `i32.const I32(140)` true call-result old-field marker.

After implementation:

```sh
moon test --package jtenner/starshine/fuzz --file main_wbtest.mbt \
  -p 'heap-store-optimization profile records GC store opportunities'
```

Result: passed (`92/92` package-file test count).

```sh
moon test --package jtenner/starshine/fuzz --file main_wbtest.mbt
```

Result: `92/92` passed.

```sh
moon fmt
```

Result: passed.

```sh
moon build --target-dir target --target native --release src/cmd
```

Result: passed with existing `src/passes/pass_manager.mbt` unused-function warnings.

```sh
bun scripts/pass-fuzz-compare.ts --count 20 --seed 0x5eed \
  --pass heap-store-optimization \
  --gen-valid-profile heap-store-optimization \
  --normalize local-cleanup-debris \
  --out-dir .tmp/pass-fuzz-heap-store-optimization-call-result-oldfield-profile-20 \
  --jobs auto \
  --starshine-bin target/native/release/build/cmd/cmd.exe \
  --max-failures 2000 \
  --keep-going-after-command-failures
```

Result: compared `20/20`, normalized matches `0`, compare-normalized matches `20`, validation failures `0`, property failures `0`, generator failures `0`, command failures `0`, mismatches `0`, Binaryen cache `0` hits / `20` misses.

```sh
bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed \
  --pass heap-store-optimization \
  --out-dir .tmp/pass-fuzz-heap-store-optimization-call-result-oldfield-direct-1000 \
  --jobs auto \
  --starshine-bin target/native/release/build/cmd/cmd.exe \
  --max-failures 2000 \
  --keep-going-after-command-failures
```

Result: compared `1000/1000`, normalized matches `1000`, compare-normalized matches `0`, validation failures `0`, property failures `0`, generator failures `0`, command failures `0`, mismatches `0`, Binaryen cache `1000` hits / `0` misses.

## Remaining generated old-field coverage

Still open from `1047`:

- true generated `call_indirect` result old fields;
- true generated `call_ref` result old fields;
- descriptor and mutable-descriptor true call-result old fields beyond the focused tests;
- tail-call generated old-field variants.

Reopen if the direct-call marker disappears from the dedicated HSO profile, if the added helper destabilizes profile validation or compare lanes, or when adding the indirect/ref/tail/descriptor generated siblings.
