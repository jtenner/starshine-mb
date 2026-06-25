# Heap-store-optimization profile descriptor constructors

Date: 2026-06-24

## Summary

This profile-only slice extends the dedicated `heap-store-optimization` GenValid profile so generated HSO artifacts contain descriptor-bearing constructor folds, not just ordinary `struct.new` / `struct.new_default` shapes.

The profile now forces enough type budget for a descriptor group, gives the described descriptor-bearing struct the same HSO-friendly mutable `i32` field plus defaultable `eqref` field shape, ensures an exact described-struct local exists, and emits deterministic:

- `struct.new_default_desc` followed by a later same-local `struct.set`; and
- `struct.new_desc` followed by a later same-local `struct.set` and readback.

This does not change the HSO pass implementation. It makes the dedicated profile cover descriptor constructor/default materialization families that were previously absent from generated HSO profile artifacts.

## Files changed

- `src/fuzz/main_wbtest.mbt`
  - Strengthened the HSO profile artifact test red-first to require `struct.new_desc` and `struct.new_default_desc` in addition to the existing ordinary constructor, `try_table`, `table.set`, `memory.fill`, and `br_if` features.
- `src/validate/gen_valid.mbt`
  - Raised the HSO profile type budget so descriptor groups survive the coverage-forced GC type roster.
  - Made descriptor-bearing described structs HSO-friendly only when `allow_heap_store_optimization_body_generator` is active.
  - Ensured an exact descriptor described-struct local exists for HSO profile bodies.
  - Appended deterministic descriptor constructor/default fold opportunities to the HSO profile body slice.

## TDD evidence

Red-first command:

```sh
moon test --package jtenner/starshine/fuzz --file main_wbtest.mbt
```

Result before implementation: failed in `emit gen-valid heap-store-optimization profile records GC store opportunities` because the generated artifact lacked `struct.new_desc` / `struct.new_default_desc`.

Green command after implementation:

```sh
moon test --package jtenner/starshine/fuzz --file main_wbtest.mbt
```

Result: `92/92` passed.

## Compare evidence

Native compare binary was refreshed with the workspace-specific command:

```sh
moon build --target-dir target --target native --release src/cmd
```

Result: passed with existing `src/passes/pass_manager.mbt` unused-function warnings; refreshed `target/native/release/build/cmd/cmd.exe`.

Dedicated profile smoke:

```sh
bun scripts/pass-fuzz-compare.ts --count 20 --seed 0x5eed --pass heap-store-optimization --gen-valid-profile heap-store-optimization --normalize local-cleanup-debris --out-dir .tmp/pass-fuzz-heap-store-optimization-profile-descriptor-20 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe --max-failures 20 --keep-going-after-command-failures
```

Result: compared `20/20`; normalized matches `0`; compare-normalized matches `20`; validation failures `0`; property failures `0`; generator failures `0`; command failures `0`; mismatches `0`; Binaryen cache `0` hits / `20` misses.

Direct smoke:

```sh
bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass heap-store-optimization --out-dir .tmp/pass-fuzz-heap-store-optimization-descriptor-profile-direct-1000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe --max-failures 200 --keep-going-after-command-failures
```

Result: compared `1000/1000`; normalized matches `1000`; compare-normalized matches `0`; validation failures `0`; property failures `0`; generator failures `0`; command failures `0`; mismatches `0`; Binaryen cache `1000` hits / `0` misses.

Additional command:

```sh
moon fmt
```

Result: passed.

## Classification

The only intentional output-shape normalizer remains the existing `local-cleanup-debris` profile normalizer from research note `1023`: Binaryen retains HSO `nop` placeholders while Starshine emits smaller nop-free validated output. This slice did not add or classify any new pass output-shape difference.

## Remaining work

This is not an HSO-D/G/J closeout. The dedicated profile now covers descriptor constructors/defaults, but broader generated descriptor barriers, mutable descriptor result-wrapper old-field variants, catch/throw skip-local-set families, broader control-flow/store barriers, performance, O4z neighborhood replay, and the final full signoff matrix remain open.
