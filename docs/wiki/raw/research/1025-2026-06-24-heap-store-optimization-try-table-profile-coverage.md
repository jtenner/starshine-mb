# 1025 - Heap Store Optimization TryTable Profile Coverage

Date: 2026-06-24

## Question

Can the dedicated `heap-store-optimization` GenValid profile safely include the generated void `try_table` / `table.set` family that was deferred in research note `1024`?

## Changes

- Added focused HSO tests for mixed `(field (mut i32)) (field eqref)` structs crossing a non-throwing void `try_table` / `table.set` wrapper.
- Added variants with an unused final store, a preceding i32 local so the struct local is not local 0, and a late type-index/module-shape fixture matching the generated profile style.
- Extended `src/validate/gen_valid.mbt`'s `heap-store-optimization` profile to emit a deterministic `memory.size` constructor followed by a void `try_table` / `table.set` wrapper and a later same-local `struct.set`.
- Strengthened the HSO profile artifact test to require `try_table` and `table.set` in addition to `struct.new_default`.

## Red-first evidence

- After the profile assertion was strengthened, `moon test --package jtenner/starshine/fuzz --file main_wbtest.mbt` failed because the emitted artifact did not yet contain `try_table` / `table.set`.
- A first 20-case dedicated-profile compare using the stale `target/native/release/build/cmd/cmd.exe` reproduced the `1024`-style mismatch, but rerunning with a freshly rebuilt explicit binary showed this was stale-binary evidence, not a current implementation gap. The required rebuild command in this workspace was:

```sh
moon build --target-dir target --target native --release src/cmd
```

The plain `moon build --target native --release src/cmd` used the default `_build` target dir and did not refresh `target/native/release/build/cmd/cmd.exe`.

## Validation

Commands run after the profile expansion:

```sh
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt
moon test --package jtenner/starshine/fuzz --file main_wbtest.mbt
moon build --target-dir target --target native --release src/cmd
bun scripts/pass-fuzz-compare.ts --count 20 --seed 0x5eed --pass heap-store-optimization --gen-valid-profile heap-store-optimization --normalize local-cleanup-debris --out-dir .tmp/pass-fuzz-heap-store-optimization-profile-try-table-expanded-rebuilt-20 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe --max-failures 20 --keep-going-after-command-failures
bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass heap-store-optimization --out-dir .tmp/pass-fuzz-heap-store-optimization-try-table-profile-direct-1000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe --max-failures 200 --keep-going-after-command-failures
```

Results:

- Focused HSO pass tests: `406/406` passed.
- Focused fuzz tests: `92/92` passed.
- Native `src/cmd` build passed with existing `src/passes/pass_manager.mbt` unused-function warnings.
- Dedicated HSO profile smoke compared `20/20`; compare-normalized matches `20`; mismatches, validation failures, property failures, generator failures, and command failures all `0`. Binaryen cache: `20` hits / `0` misses.
- Regular direct smoke compared `1000/1000`; normalized matches `1000`; mismatches, validation failures, property failures, generator failures, and command failures all `0`. Binaryen cache: `1000` hits / `0` misses.

## Interpretation

The generated void `try_table` / `table.set` profile family from `1024` is now covered by focused tests and a dedicated-profile smoke lane. The earlier residual immutable/ref-field generated mismatch should be treated as fixed/replayed after the fresh explicit native binary rebuild, not as accepted drift.

This does not close HSO-G or final HSO parity. Descriptor/control-flow/store-barrier variants are still absent from the dedicated profile, and HSO still needs the full final closeout matrix before the pass can be declared complete.
