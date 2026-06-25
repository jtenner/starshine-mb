# 1024 - Heap Store Optimization Default Profile And Void TryTable Table Stores

Date: 2026-06-24

## Question

Continue the HSO recursive audit by widening generated coverage beyond the initial fresh `struct.new` / `local.tee` / repeated-store profile, and reduce one `trySwap(...)` gap exposed while attempting to add try-table roots to that profile.

## Changes

- Extended `src/validate/gen_valid.mbt`'s `heap-store-optimization` profile body slice with a deterministic `struct.new_default` local-set followed by same-local `struct.set` and `struct.get` use. This exercises HSO's default-constructor materialization path in the dedicated GenValid lane while keeping artifacts externally valid.
- Updated `src/fuzz/main_wbtest.mbt` so the HSO profile test decodes the first emitted artifact and asserts the profile now contains `struct.new_default` in addition to GC constructors/accessors.
- Added focused HSO coverage for a void `try_table` / `table.set` wrapper between a `memory.size`-seeded fresh struct and a later same-local `struct.set`.
- Generalized the HSO wrapped-try-table swap helper so non-throwing void `try_table` block wrappers can use the same safety gate as the existing dropped-result `try_table` wrappers.

## Red-first evidence

- The expanded profile test initially failed because the emitted HSO artifact did not contain `struct.new_default`.
- The focused void `try_table` / `table.set` pass test initially failed with the `struct.set` still present after HSO.

## Validation

Commands run after the fixes:

```sh
moon test --package jtenner/starshine/fuzz --file main_wbtest.mbt
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt
moon build --target native --release src/cmd
bun scripts/pass-fuzz-compare.ts --count 20 --seed 0x5eed --pass heap-store-optimization --gen-valid-profile heap-store-optimization --normalize local-cleanup-debris --out-dir .tmp/pass-fuzz-heap-store-optimization-profile-default-fixed-20 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe --max-failures 20 --keep-going-after-command-failures
bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass heap-store-optimization --out-dir .tmp/pass-fuzz-heap-store-optimization-void-try-table-1000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe --max-failures 200 --keep-going-after-command-failures
```

Results:

- Focused fuzz test: `92/92` passed.
- Focused HSO pass test: `402/402` passed.
- Native `src/cmd` build passed with the existing `src/passes/pass_manager.mbt` unused-function warnings.
- Dedicated HSO profile smoke compared `20/20`; compare-normalized matches `20`; mismatches, validation failures, property failures, generator failures, and command failures all `0`. Binaryen cache: `0` hits / `20` misses.
- Regular direct smoke compared `1000/1000`; normalized matches `1000`; mismatches, validation failures, property failures, generator failures, and command failures all `0`. Binaryen cache: `1000` hits / `0` misses.

## Deferred generated try-table variant

A temporary attempt to include a generated void `try_table` / `table.set` profile case exposed a remaining generated-shape parity gap and was not kept in the profile. The generated case used the HSO profile's two-field struct shape `(field (mut i32)) (field eqref)`, a `memory.size` constructor operand, a `try_table` wrapper around `table.set`, and a later same-field `struct.set`.

Observed on temporary out dirs such as `.tmp/pass-fuzz-heap-store-optimization-profile-expanded-fixed3-20`: Binaryen folded the later store into the constructor and left only its usual `nop` debris, while Starshine preserved the constructor, wrapper, and later `struct.set`. Both outputs validated, but this is not classified as an accepted Starshine win; it remains a narrow HSO-G parity gap because no measured benefit justifies the output-shape difference.

Reopening / next-action criteria:

- Add a focused regression matching the generated struct shape with an immutable/ref later field, not only the all-i32 helper shape.
- Fix or classify the generated void `try_table` / `table.set` fold before adding try-table roots to the dedicated HSO profile.
- Re-run the dedicated profile lane with `--normalize local-cleanup-debris` after re-enabling that generated variant.

## Interpretation

This slice improves generated HSO coverage for default materialization and closes one source-backed void try-table/table-store fold family, but it does not close HSO-G. The dedicated profile still intentionally covers default/core fresh-struct opportunities only; descriptor, target-local, broader try-table/control-flow, old-field, and swap-barrier variants remain open for future profile expansion.
