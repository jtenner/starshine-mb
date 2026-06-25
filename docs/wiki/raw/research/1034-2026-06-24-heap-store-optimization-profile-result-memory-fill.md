# HSO profile result-typed memory.fill barrier root

## Summary

Extended `src/validate/gen_valid.mbt` so the dedicated `heap-store-optimization` GenValid profile emits a deterministic `memory.size`-seeded `struct.new` followed by a result-typed `try_table` that performs `memory.fill`, drops its i32 result, and then reaches a later same-local `struct.set`.

This adds generated coverage for a result-wrapper same-resource memory barrier. It complements the existing void `try_table` / `memory.fill` root and the focused `0986` result-typed same-effect boundary, while keeping catchable calls, throws, typed-function-reference calls, and broader control/store variants as separate open families.

## TDD and validation

Red-first artifact test:

- `moon test --package jtenner/starshine/fuzz --file main_wbtest.mbt` failed after requiring at least two `try_table I32 []` roots; the generated artifact only had the descriptor set-value result wrapper from `1032`.

After the generator update:

- `moon fmt` passed.
- `moon test --package jtenner/starshine/fuzz --file main_wbtest.mbt` passed, `92/92`.
- `moon build --target-dir target --target native --release src/cmd` passed with the existing `src/passes/pass_manager.mbt` unused-function warnings and refreshed `target/native/release/build/cmd/cmd.exe`.
- `bun scripts/pass-fuzz-compare.ts --count 20 --seed 0x5eed --pass heap-store-optimization --gen-valid-profile heap-store-optimization --normalize local-cleanup-debris --out-dir .tmp/pass-fuzz-heap-store-optimization-profile-result-memory-fill-20 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe --max-failures 20 --keep-going-after-command-failures` compared `20/20`; normalized matches `0`; compare-normalized matches `20`; validation, property, generator, command failures, and mismatches `0`; Binaryen cache `0` hits / `20` misses.
- `bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass heap-store-optimization --out-dir .tmp/pass-fuzz-heap-store-optimization-result-memory-fill-direct-1000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe --max-failures 200 --keep-going-after-command-failures` compared `1000/1000`; normalized matches `1000`; compare-normalized matches `0`; validation, property, generator, command failures, and mismatches `0`; Binaryen cache `1000` hits / `0` misses.

## Remaining work

This closes only one generated result-typed same-resource `memory.fill` root. Catchable result wrappers, descriptor result-wrapper old-field variants, branch-result / `br_on_non_null` descriptor surfaces, broader control/store barrier variants, HSO-I performance, O4z slot/neighborhood replay, and final HSO closeout remain open.
