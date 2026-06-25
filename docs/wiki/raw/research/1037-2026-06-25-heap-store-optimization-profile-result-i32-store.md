# HSO profile result-typed i32.store cross-family root

## Summary

Extended `src/validate/gen_valid.mbt` so the dedicated `heap-store-optimization` GenValid profile emits a deterministic table-side counterpart to `1035`: a `table.size`-seeded `struct.new` followed by a result-typed `try_table` that performs an unrelated `i32.store`, drops its i32 result, and then reaches a later same-local `struct.set`.

This adds generated coverage for the result-typed cross-family ordinary-store positive where a table resource read can fold across an unrelated memory store. It complements the memory-side result-typed `table.set` root from `1035` and the source-backed `0990` result-typed cross-family ordinary-store split.

## TDD and validation

Red-first artifact test:

- `moon test --package jtenner/starshine/fuzz --file main_wbtest.mbt` failed after requiring at least five `try_table I32` roots; the generated artifact only had the four existing result-typed wrappers from `1032`, `1034`, `1035`, and `1036`.

After the generator update:

- `moon fmt` passed.
- `moon test --package jtenner/starshine/fuzz --file main_wbtest.mbt` passed, `92/92`.
- `moon build --target-dir target --target native --release src/cmd` passed with the existing `src/passes/pass_manager.mbt` unused-function warnings and refreshed `target/native/release/build/cmd/cmd.exe`.
- `bun scripts/pass-fuzz-compare.ts --count 20 --seed 0x5eed --pass heap-store-optimization --gen-valid-profile heap-store-optimization --normalize local-cleanup-debris --out-dir .tmp/pass-fuzz-heap-store-optimization-profile-result-i32-store-20 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe --max-failures 20 --keep-going-after-command-failures` compared `20/20`; normalized matches `0`; compare-normalized matches `20`; validation, property, generator, command failures, and mismatches `0`; Binaryen cache `0` hits / `20` misses.
- `bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass heap-store-optimization --out-dir .tmp/pass-fuzz-heap-store-optimization-result-i32-store-direct-1000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe --max-failures 200 --keep-going-after-command-failures` compared `1000/1000`; normalized matches `1000`; compare-normalized matches `0`; validation, property, generator, command failures, and mismatches `0`; Binaryen cache `1000` hits / `0` misses.

## Remaining work

This closes only one generated table-side result-typed cross-family ordinary-store root. Result-typed cross-family growth roots, table-side same-resource `table.fill` generation, broader catchable result-wrapper call/ref-call generation, descriptor result-wrapper old-field variants, branch-result / `br_on_non_null` descriptor surfaces, broader control/store barrier variants, HSO-I performance, O4z slot/neighborhood replay, and final HSO closeout remain open.
