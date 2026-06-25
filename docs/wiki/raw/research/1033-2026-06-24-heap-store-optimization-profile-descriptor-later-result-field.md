# HSO profile descriptor later-field result-typed try_table root

## Summary

Extended `src/validate/gen_valid.mbt` so the dedicated `heap-store-optimization` GenValid profile emits a deterministic descriptor-bearing `struct.new_desc` whose second constructor field is produced by a result-typed `try_table`, followed by a same-local `struct.set` to field 0.

This adds generated coverage for the descriptor later-field result-wrapper fold surface. It is intentionally call-free and narrow: focused Binaryen `version_130` notes still own direct-call, indirect-call, typed-function-reference, tail-call, old-field, mutable descriptor, and catchable result-wrapper boundaries.

## TDD and validation

Red-first artifact test:

- `moon test --package jtenner/starshine/fuzz --file main_wbtest.mbt` failed after requiring a descriptor later-field result-typed `try_table`; the generated artifact only had the i32 set-value result wrapper from `1032` plus void wrappers.

After the generator update:

- `moon fmt` passed.
- `moon test --package jtenner/starshine/fuzz --file main_wbtest.mbt` passed, `92/92`.
- `moon build --target-dir target --target native --release src/cmd` passed with the existing `src/passes/pass_manager.mbt` unused-function warnings and refreshed `target/native/release/build/cmd/cmd.exe`.
- `bun scripts/pass-fuzz-compare.ts --count 20 --seed 0x5eed --pass heap-store-optimization --gen-valid-profile heap-store-optimization --normalize local-cleanup-debris --out-dir .tmp/pass-fuzz-heap-store-optimization-profile-desc-later-result-field-20 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe --max-failures 20 --keep-going-after-command-failures` compared `20/20`; normalized matches `0`; compare-normalized matches `20`; validation, property, generator, command failures, and mismatches `0`; Binaryen cache `0` hits / `20` misses.
- `bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass heap-store-optimization --out-dir .tmp/pass-fuzz-heap-store-optimization-desc-later-result-field-direct-1000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe --max-failures 200 --keep-going-after-command-failures` compared `1000/1000`; normalized matches `1000`; compare-normalized matches `0`; validation, property, generator, command failures, and mismatches `0`; Binaryen cache `1000` hits / `0` misses.

## Remaining work

This closes only one generated descriptor later-field result-wrapper root. Call-valued result-wrapper splits, tail-call no-fold variants, mutable descriptor result-wrapper old-field variants, catchable descriptor wrappers, branch-result / `br_on_non_null` descriptor surfaces, broader control/store barriers, HSO-I performance, O4z slot/neighborhood replay, and final HSO closeout remain open.
