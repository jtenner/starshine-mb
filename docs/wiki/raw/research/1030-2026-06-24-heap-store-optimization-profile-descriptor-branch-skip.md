# Heap Store Optimization Profile Descriptor Branch Skip Coverage

## Question

Can the dedicated `heap-store-optimization` GenValid profile exercise a descriptor-bearing constructor-local hazard where ordinary branch control, not an exception, can skip the fresh `local.set` before a later same-local `struct.set`?

## Change

Extended `src/validate/gen_valid.mbt` so the HSO profile emits a deterministic descriptor-bearing `struct.new_desc` root inside a block whose leading `br_if` can skip the constructor assignment. A later same-local `struct.set` reads the described local.

This complements the descriptor catch/throw profile root from `1029` and adds generated coverage for a non-exceptional descriptor branch skip-local-set shape. It is intentionally narrow profile coverage; broader descriptor branch-result / `br_on_non_null` surfaces remain open because the local HOT CFG/verifier surface still blocks equivalent focused fixtures.

## TDD and validation

- Red-first: strengthened `src/fuzz/main_wbtest.mbt` to require at least two `br_if` occurrences in the HSO profile artifact. Before the generator change, `moon test --package jtenner/starshine/fuzz --file main_wbtest.mbt` failed in the HSO artifact test because only the existing contained-control `br_if` root was present.
- Implemented the descriptor branch skip-local-set root in `gen_valid_append_heap_store_optimization_body_slice`.
- `moon fmt` passed.
- `moon test --package jtenner/starshine/fuzz --file main_wbtest.mbt` passed: `92/92`.
- `moon build --target-dir target --target native --release src/cmd` passed with the existing `src/passes/pass_manager.mbt` unused-function warnings and refreshed `target/native/release/build/cmd/cmd.exe`.
- `bun scripts/pass-fuzz-compare.ts --count 20 --seed 0x5eed --pass heap-store-optimization --gen-valid-profile heap-store-optimization --normalize local-cleanup-debris --out-dir .tmp/pass-fuzz-heap-store-optimization-profile-desc-branch-skip-20 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe --max-failures 20 --keep-going-after-command-failures` compared `20/20`, with `0` normalized matches, `20` compare-normalized matches, and `0` validation, property, generator, command, or remaining mismatch failures.
- `bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass heap-store-optimization --out-dir .tmp/pass-fuzz-heap-store-optimization-desc-branch-skip-direct-1000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe --max-failures 200 --keep-going-after-command-failures` compared `1000/1000`, with `1000` normalized matches and `0` validation, property, generator, command, or mismatch failures.

## Remaining work

This closes only one generated descriptor branch skip-local-set profile root. Descriptor branch-result shapes, descriptor `br_on_non_null` local-surface blockers, descriptor result-wrapper old-field variants, mutable descriptor/global result-wrapper combinations, and final HSO closeout remain open.
