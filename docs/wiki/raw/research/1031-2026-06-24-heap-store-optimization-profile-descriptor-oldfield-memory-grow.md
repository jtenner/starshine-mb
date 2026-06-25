# Heap Store Optimization Profile Descriptor Old-Field Memory.Grow Coverage

## Question

Can the dedicated `heap-store-optimization` GenValid profile exercise descriptor-bearing old-field side-effect preservation, so generated cases cover more than pure descriptor constructor folds?

## Change

Extended `src/validate/gen_valid.mbt` so the HSO profile emits a deterministic `struct.new_desc` whose overwritten field value is `memory.grow`. A later same-field `struct.set` can only be folded if the old field's `memory.grow` side effect is preserved in order.

This adds generated old-field side-effect coverage to the descriptor constructor profile roots. It is intentionally narrow: it does not close mutable descriptor result-wrapper old-field variants, call-valued old fields, result-typed `try_table` old fields, or broader descriptor barrier combinations.

## TDD and validation

- Red-first: strengthened `src/fuzz/main_wbtest.mbt` to require `memory.grow` in the HSO profile artifact. Before the generator change, `moon test --package jtenner/starshine/fuzz --file main_wbtest.mbt` failed in the HSO artifact test because the generated profile had `memory.size` and `memory.fill` but no `memory.grow` root.
- Implemented the descriptor old-field `memory.grow` root in `gen_valid_append_heap_store_optimization_body_slice`.
- `moon fmt` passed.
- `moon test --package jtenner/starshine/fuzz --file main_wbtest.mbt` passed: `92/92`.
- `moon build --target-dir target --target native --release src/cmd` passed with the existing `src/passes/pass_manager.mbt` unused-function warnings and refreshed `target/native/release/build/cmd/cmd.exe`.
- `bun scripts/pass-fuzz-compare.ts --count 20 --seed 0x5eed --pass heap-store-optimization --gen-valid-profile heap-store-optimization --normalize local-cleanup-debris --out-dir .tmp/pass-fuzz-heap-store-optimization-profile-desc-oldfield-memory-grow-20 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe --max-failures 20 --keep-going-after-command-failures` compared `20/20`, with `0` normalized matches, `20` compare-normalized matches, and `0` validation, property, generator, command, or remaining mismatch failures.
- `bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass heap-store-optimization --out-dir .tmp/pass-fuzz-heap-store-optimization-desc-oldfield-memory-grow-direct-1000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe --max-failures 200 --keep-going-after-command-failures` compared `1000/1000`, with `1000` normalized matches and `0` validation, property, generator, command, or mismatch failures.

## Remaining work

This closes only one generated descriptor old-field side-effect root. Mutable descriptor result-wrapper old-field variants, catchable descriptor wrappers beyond the generated roots, branch-result descriptor surfaces, broader control/store barriers, HSO-I performance, and final HSO closeout remain open.
