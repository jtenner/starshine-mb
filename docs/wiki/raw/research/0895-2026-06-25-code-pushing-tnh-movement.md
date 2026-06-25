# 0895 - code-pushing traps-never-happen movement

Date: 2026-06-25

## Question

Can Starshine close `[CP-BINREP-002]` by matching the Binaryen v130 `--traps-never-happen` behavior that sinks an otherwise trapping integer division value into the sole using `if` arm?

## Answer

Yes. Starshine now carries the pipeline `traps_never_happen` option into `HotPassContext`, and `code-pushing` uses that explicit context flag to relax only the exact integer div/rem trap gate for movable values. Default `code-pushing` still keeps `i32.div_s` before the `if`; `traps_never_happen=true` now sinks the set into the only arm that reads the temporary, matching the reduced Binaryen v130 probe.

This is a narrow trap-policy widening. It does not claim the full `code-pushing_ignore-implicit-traps.wast` surface, which remains tracked separately as `[CP-BINREP-003]`.

## Source-backed shape

The replacement follow-up came from `.tmp/cp-gap-research/trapping-div-into-if.wat`:

```wat
(local.set $x (i32.div_s (local.get $a) (local.get $b)))
(if (local.get $cond)
  (then
    (drop (local.get $x))))
```

Local Binaryen v130 keeps the division before the `if` by default, but `wasm-opt --traps-never-happen --code-pushing` sinks the division-backed `local.set` into the only consuming arm. Before this slice, Starshine kept it before the `if` even when the public pipeline option was enabled because hot passes did not receive the trap policy.

## Implementation

Changed `src/passes/pass_manager.mbt` and `src/passes/pkg.generated.mbti`:

- added public `HotPassContext.traps_never_happen : Bool`;
- added an optional `traps_never_happen?` constructor parameter defaulting to `false`, preserving existing test call sites;
- wired both hot-pass execution paths from `HotPipelineOptions.traps_never_happen` into `HotPassContext`.

Changed `src/passes/code_pushing.mbt`:

- threaded the trap policy through mutating code-pushing movable-value checks that have a `HotPassContext`;
- kept default behavior unchanged for exact trapping integer div/rem instructions;
- when `ctx.traps_never_happen` is true, treats exact integer div/rem nodes as movable if the surrounding local-use/effect proof otherwise succeeds.

Added focused tests in `src/passes/code_pushing_test.mbt`:

- `code-pushing keeps trapping div before if by default` protects the default trap-timing boundary;
- `code-pushing sinks trapping div into sole using if arm when traps never happen` protects the trap-relaxed positive.

The positive test failed before implementation: the output still kept `i32.div_s` before the `if`.

## Validation

- Red confirmation: `moon test --target native src/passes/code_pushing_test.mbt` failed before implementation only in `code-pushing sinks trapping div into sole using if arm when traps never happen`; `124/125` passed.
- Focused after implementation: `moon test --target native src/passes/code_pushing_test.mbt` passed `125/125` with pre-existing warnings.
- `moon fmt`: passed / no work to do.
- `moon info`: passed with pre-existing warnings in `src/validate/gen_valid.mbt` and `src/validate/gen_valid_ssa.mbt`; regenerated `src/passes/pkg.generated.mbti` shows the public `HotPassContext` API addition.
- `moon test src/passes`: passed `2834/2834`.
- `moon build --target native --release src/cmd`: passed with pre-existing warnings.
- Bounded dedicated compare smoke with the existing local-cleanup normalizer:

```sh
bun scripts/pass-fuzz-compare.ts \
  --count 1000 \
  --seed 0x5eed \
  --pass code-pushing \
  --gen-valid-profile code-pushing-all \
  --normalize local-cleanup-debris \
  --out-dir .tmp/pass-fuzz-code-pushing-all-1000-20260625-binrep002-tnh \
  --jobs auto \
  --starshine-bin _build/native/release/build/cmd/cmd.exe \
  --max-failures 200 \
  --keep-going-after-command-failures
```

Result: `1000/1000` compared, `466` normalized, `534` cleanup-normalized, raw mismatches `0`, validation/generator/property/command failures `0`, Binaryen cache `1000 hits/0 misses`.

## Remaining follow-up

`[CP-BINREP-002]` is implemented for the reduced `--traps-never-happen` integer div/rem into-if family and the shared hot-pass context plumbing is now available for future trap-option-aware hot passes. `[CP-BINREP-003]` remains active for the broader `code-pushing_ignore-implicit-traps.wast` audit, and should not be closed by this TNH slice alone.
