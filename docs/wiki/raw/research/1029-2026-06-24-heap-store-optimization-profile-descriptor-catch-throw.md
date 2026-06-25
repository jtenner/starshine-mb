# Heap Store Optimization Profile Descriptor Catch/Throw Coverage

## Question

Can the dedicated `heap-store-optimization` GenValid profile exercise a descriptor-bearing constructor-local skip hazard when a catchable `try_table` / `throw` path can bypass the fresh `local.set`?

## Change

Extended `src/validate/gen_valid.mbt` so the HSO profile emits a deterministic descriptor-bearing `struct.new_desc` root inside a catchable `try_table` body. A sibling `throw` can escape to the local catch before the descriptor constructor assignment executes, then a later same-local `struct.set` reads the described local.

This complements the ordinary-struct catch/throw profile root from `1028` and keeps the generated profile closer to the source-backed HSO-F / HSO-G descriptor skip-local-set families. It is still a profile-coverage slice, not a broad closeout for all descriptor catchable wrappers.

## TDD and validation

- Red-first: strengthened `src/fuzz/main_wbtest.mbt` to require at least five `try_table` occurrences in the HSO profile artifact. Before the generator change, `moon test --package jtenner/starshine/fuzz --file main_wbtest.mbt` failed in the HSO artifact test: the generated function had only the four previously-covered `try_table` roots.
- Implemented the descriptor catch/throw root in `gen_valid_append_heap_store_optimization_body_slice`.
- `moon fmt` passed.
- `moon test --package jtenner/starshine/fuzz --file main_wbtest.mbt` passed: `92/92`.
- `moon build --target-dir target --target native --release src/cmd` passed with the existing `src/passes/pass_manager.mbt` unused-function warnings and refreshed `target/native/release/build/cmd/cmd.exe`.
- `bun scripts/pass-fuzz-compare.ts --count 20 --seed 0x5eed --pass heap-store-optimization --gen-valid-profile heap-store-optimization --normalize local-cleanup-debris --out-dir .tmp/pass-fuzz-heap-store-optimization-profile-desc-catch-throw-20 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe --max-failures 20 --keep-going-after-command-failures` compared `20/20`, with `0` normalized matches, `20` compare-normalized matches, and `0` validation, property, generator, command, or remaining mismatch failures.
- `bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass heap-store-optimization --out-dir .tmp/pass-fuzz-heap-store-optimization-desc-catch-throw-direct-1000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe --max-failures 200 --keep-going-after-command-failures` compared `1000/1000`, with `1000` normalized matches and `0` validation, property, generator, command, or mismatch failures.

## Remaining work

Broader generated descriptor branch-skip roots, descriptor result-wrapper old-field variants, and mutable descriptor/global result-wrapper combinations remain open in `agent-todo.md`. This slice only ensures one descriptor catch/throw skip-local-set hazard appears in the dedicated profile.
