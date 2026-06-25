# HSO profile descriptor result-typed try_table set-value root

## Summary

Extended `src/validate/gen_valid.mbt` so the dedicated `heap-store-optimization` GenValid profile emits a deterministic descriptor-bearing `struct.new_desc` followed by a same-local `struct.set` whose moved value is produced by a result-typed `try_table`.

This adds generated coverage for the descriptor result-wrapper set-value surface without enabling the broader call-valued result-wrapper space. It complements the focused Binaryen `version_130` result-wrapper notes around `1005`-`1008` and keeps old-field, mutable-descriptor, tail-call, and catchable call variants as separate open families.

## TDD and validation

Red-first artifact test:

- `moon test --package jtenner/starshine/fuzz --file main_wbtest.mbt` failed after requiring a result-typed HSO `try_table`; the generated artifact only had void `try_table` roots.

After the generator update:

- `moon fmt` passed.
- `moon test --package jtenner/starshine/fuzz --file main_wbtest.mbt` passed, `92/92`.
- `moon build --target-dir target --target native --release src/cmd` passed with the existing `src/passes/pass_manager.mbt` unused-function warnings and refreshed `target/native/release/build/cmd/cmd.exe`.
- `bun scripts/pass-fuzz-compare.ts --count 20 --seed 0x5eed --pass heap-store-optimization --gen-valid-profile heap-store-optimization --normalize local-cleanup-debris --out-dir .tmp/pass-fuzz-heap-store-optimization-profile-desc-result-try-value-20 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe --max-failures 20 --keep-going-after-command-failures` compared `20/20`; normalized matches `0`; compare-normalized matches `20`; validation, property, generator, command failures, and mismatches `0`; Binaryen cache `0` hits / `20` misses.
- `bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass heap-store-optimization --out-dir .tmp/pass-fuzz-heap-store-optimization-desc-result-try-value-direct-1000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe --max-failures 200 --keep-going-after-command-failures` compared `1000/1000`; normalized matches `1000`; compare-normalized matches `0`; validation, property, generator, command failures, and mismatches `0`; Binaryen cache `1000` hits / `0` misses.

## Remaining work

This closes only one generated descriptor result-typed set-value root. Mutable descriptor result-wrapper variants, call-valued/generated result-wrapper old-field variants, catchable descriptor wrappers beyond the generated roots, branch-result / `br_on_non_null` descriptor surfaces, broader control/store barriers, HSO-I performance, O4z slot/neighborhood replay, and final HSO closeout remain open.
