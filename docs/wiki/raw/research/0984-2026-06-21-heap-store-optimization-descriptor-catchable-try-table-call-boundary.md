# Heap Store Optimization Descriptor Catchable `try_table` Call Boundary

## Summary

Binaryen `version_130` preserves a later same-field `struct.set` when a descriptor fresh-struct local is followed by a `try_table` body that can catch an intervening call. Starshine previously moved that catchable `try_table` before the constructor local assignment and folded the later value into `struct.new_desc`, which overgeneralized the non-throwing `try_table` global-set family from `0927`/`0983`. This slice fixes the parity gap by preventing branch-skip local-set swaps across `try_table` bodies that may escape to their local catch.

## Binaryen oracle

Probe file: `.tmp/hso-desc-try-call-value.wat`.

Command:

```sh
wasm-opt --version && \
wasm-opt --all-features \
  .tmp/hso-desc-try-call-value.wat \
  --heap-store-optimization -S \
  -o .tmp/hso-desc-try-call-value.opt.wat && \
grep -E "struct.set|struct.new_desc|try_table|call|drop|global.get|i32.const" \
  .tmp/hso-desc-try-call-value.opt.wat
```

Result:

- Local oracle: `wasm-opt version 130 (version_130)`.
- Binaryen preserves the descriptor `struct.new_desc`, the catchable `try_table`, the call in the `try_table` body, and the later `struct.set`.
- This differs from the non-throwing unrelated-global-set descriptor shape in `0983`, where Binaryen folds into `struct.new_desc`.

Observed grep excerpt:

```text
(struct.new_desc $pair
  (i32.const 0)
  (i32.const 2)
  (global.get $desc)
(try_table (catch_all $block)
  (drop
    (call $helper
      (i32.const 1)
(struct.set $pair 0
  (i32.const 9)
```

## Starshine gap and fix

Red-first focused test:

- `heap-store-optimization keeps descriptor struct.set across catchable try_table calls`

Initial failure: Starshine output moved the `try_table` before the `struct.new_desc` / `local.set`, folded `i32.const 9` into the constructor, and removed `struct.set`.

Implementation change:

- `src/passes/heap_store_optimization.mbt`
  - Adds a narrow `hso_subtree_has_catchable_try_table_escape(...)` / region helper that detects `try_table` bodies containing call/throw-like escape candidates.
  - Refines the branch-skip local-set swap path so it does not move a fresh-struct constructor assignment after such a catchable `try_table` root.
  - Keeps the non-throwing `try_table` / unrelated-global-set folds from `0927` and `0983` available because they do not contain catchable call/throw escape candidates.

## Classification

This is an HSO-D/F/G behavior-parity fix:

- HSO-D because the constructor is `struct.new_desc` with a descriptor operand.
- HSO-F because the `try_table` can skip the local-set chain through local catch control.
- HSO-G because the bug was an over-permissive swap before the constructor local assignment.

This is not a Starshine win: Binaryen keeps the later store, and no measured or semantic Starshine advantage justified removing it.

## Validation

Focused red/green command after the fix:

```sh
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt \
  -p 'descriptor struct.set across catchable try_table calls'
```

Result:

```text
Total tests: 351, passed: 351, failed: 0.
```

Additional validation:

```sh
moon fmt
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt
moon test src/passes
moon build --target native --release src/cmd
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed \
  --pass heap-store-optimization \
  --out-dir .tmp/pass-fuzz-heap-store-optimization-desc-try-call-10000 \
  --jobs auto \
  --starshine-bin target/native/release/build/cmd/cmd.exe \
  --max-failures 2000 \
  --keep-going-after-command-failures
```

Results:

- `moon fmt` passed.
- Focused HSO tests passed `351/351`.
- `moon test src/passes` passed `2979/2979`.
- Native `src/cmd` build passed with pre-existing unused-function warnings in `src/passes/pass_manager.mbt`.
- Direct 10000-case `heap-store-optimization` compare matched `10000/10000` with `10000` normalized matches, `0` mismatches, `0` validation/property/generator failures, and `0` command failures.

## Reopening criteria

Reopen if Binaryen changes catchable `try_table` movement around descriptor constructors, if Starshine reworks branch-skip local-set chain swapping, or if new `try_table` wrapper forms reveal additional call/throw catchability gaps not covered by this direct descriptor-call boundary.
