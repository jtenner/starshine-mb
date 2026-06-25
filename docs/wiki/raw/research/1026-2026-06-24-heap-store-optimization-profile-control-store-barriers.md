# Heap-store-optimization profile control/store-barrier coverage

Date: 2026-06-24

## Summary

Extended the dedicated `heap-store-optimization` GenValid profile beyond the existing fresh-struct local-set/tee/repeated-store/default/void-`try_table` table-store families. The profile now also emits:

- a same-resource `memory.size` constructor followed by a wrapped non-throwing `try_table` / `memory.fill` root and later same-local `struct.set`, covering the HSO-G store-barrier/no-fold side of `trySwap(...)`; and
- a contained-control `br_if` inside a wrapped non-throwing `try_table` / `table.set` root, covering a generated control-flow wrapper positive that should not escape the root or touch the target local.

This is profile-surface work only; it does not close descriptor generation or the broader HSO-D/E/F/G families.

## TDD loop

Red first:

```sh
moon test --package jtenner/starshine/fuzz --file main_wbtest.mbt
```

After strengthening the profile artifact test to require `memory.fill` and `br_if`, the HSO profile test failed because the emitted artifact only contained the existing `struct.new_default`, `try_table`, and `table.set` slice.

Implementation:

- `src/validate/gen_valid.mbt`: added deterministic HSO profile slices for wrapped `try_table` / `memory.fill` and contained-control wrapped `try_table` / `table.set`.
- `src/fuzz/main_wbtest.mbt`: requires `memory.fill` and `br_if` in the emitted HSO profile artifact, in addition to the existing GC/default/try-table/table-store checks.

## Validation

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

Result: passed and refreshed `target/native/release/build/cmd/cmd.exe`; existing unused-function warnings in `src/passes/pass_manager.mbt` remain.

```sh
bun scripts/pass-fuzz-compare.ts --count 20 --seed 0x5eed --pass heap-store-optimization --gen-valid-profile heap-store-optimization --normalize local-cleanup-debris --out-dir .tmp/pass-fuzz-heap-store-optimization-profile-control-store-barrier-20 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe --max-failures 20 --keep-going-after-command-failures
```

Result: compared `20/20`; normalized matches `0`; compare-normalized matches `20`; validation/property/generator/command failures `0`; mismatches `0`; Binaryen cache `0` hits / `20` misses.

```sh
bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass heap-store-optimization --out-dir .tmp/pass-fuzz-heap-store-optimization-control-store-profile-direct-1000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe --max-failures 200 --keep-going-after-command-failures
```

Result: compared `1000/1000`; normalized matches `1000`; compare-normalized matches `0`; validation/property/generator/command failures `0`; mismatches `0`; Binaryen cache `1000` hits / `0` misses.

## Remaining work

Descriptor/control-flow/store-barrier generated coverage is still incomplete. This note only moves the dedicated HSO profile forward for same-resource store barriers and contained branch wrappers. Descriptor constructor/default/descriptor variants, skip-local-set hazards, catch/throw variants, and broader wrapper families remain open in `agent-todo.md`.
