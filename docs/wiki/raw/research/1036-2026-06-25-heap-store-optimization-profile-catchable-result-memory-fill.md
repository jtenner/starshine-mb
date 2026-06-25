# HSO profile catchable result-typed memory.fill root

## Summary

Extended `src/validate/gen_valid.mbt` so the dedicated `heap-store-optimization` GenValid profile emits a deterministic `memory.size`-seeded `struct.new` followed by a catchable result-typed `try_table` wrapper. The wrapper performs `memory.fill`, can branch to a local catch via `throw`, drops its i32 result on the non-catch path, and then reaches a later same-local `struct.set`.

This adds generated coverage for a catchable result-wrapper same-resource memory barrier. It complements the non-catchable result-typed `memory.fill` root from `1034` and the source-backed caught-throw/catchable-call same-effect result-wrapper boundaries in `0991`-`0994`.

## TDD and validation

Red-first artifact test:

- `moon test --package jtenner/starshine/fuzz --file main_wbtest.mbt` failed after requiring at least four `try_table I32` roots; the generated artifact only had the three existing result-typed wrappers from `1032`, `1034`, and `1035`.

After the generator update:

- `moon fmt` passed.
- `moon test --package jtenner/starshine/fuzz --file main_wbtest.mbt` passed, `92/92`.
- `moon build --target-dir target --target native --release src/cmd` passed with the existing `src/passes/pass_manager.mbt` unused-function warnings and refreshed `target/native/release/build/cmd/cmd.exe`.
- `bun scripts/pass-fuzz-compare.ts --count 20 --seed 0x5eed --pass heap-store-optimization --gen-valid-profile heap-store-optimization --normalize local-cleanup-debris --out-dir .tmp/pass-fuzz-heap-store-optimization-profile-catchable-result-memory-fill-20 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe --max-failures 20 --keep-going-after-command-failures` compared `20/20`; normalized matches `0`; compare-normalized matches `20`; validation, property, generator, command failures, and mismatches `0`; Binaryen cache `0` hits / `20` misses.
- `bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass heap-store-optimization --out-dir .tmp/pass-fuzz-heap-store-optimization-catchable-result-memory-fill-direct-1000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe --max-failures 200 --keep-going-after-command-failures` compared `1000/1000`; normalized matches `1000`; compare-normalized matches `0`; validation, property, generator, command failures, and mismatches `0`; Binaryen cache `1000` hits / `0` misses.

## Remaining work

This closes only one generated catchable result-typed same-resource `memory.fill` root. Catchable result-wrapper call/ref-call variants remain source-tested but not broadly generated, and table-side result-typed `table.fill`, result-typed cross-family growth roots, descriptor result-wrapper old-field variants, branch-result / `br_on_non_null` descriptor surfaces, broader control/store barrier variants, HSO-I performance, O4z slot/neighborhood replay, and final HSO closeout remain open.
