# 0816 - Code-pushing local-copy multi-set movement

Date: 2026-06-20

## Scope

This slice widens `[O4Z-AUDIT-CP]` by one bounded Binaryen-backed family: adjacent SFA `local.set` roots whose values are direct `local.get` copies can move as an ordered multi-set after the same existing push-point set as the prior ordered pure-value slices:

- ordinary void `if`;
- dropped value `if`;
- narrow no-branch-value `br_if` to a void block label.

The slice is still not final `code-pushing` closeout.

## Binaryen oracle probes

Local oracle: `wasm-opt version 130 (version_130)`.

Positive probes showed Binaryen moving two adjacent local-copy sets after each supported push point while preserving source order:

- `.tmp/cp-local-copy-if-probe.wat` -> `local.set $3 (local.get $1)` and then `local.set $4 (local.get $2)` after the void `if`.
- `.tmp/cp-local-copy-dropped-if-probe.wat` -> the same ordered sets after the dropped value `if` wrapper.
- `.tmp/cp-local-copy-br-if-probe.wat` -> the same ordered sets after the void-block-target `br_if`.

A source-write probe `.tmp/cp-local-copy-source-write-probe.wat` showed Binaryen keeping the source-sensitive `$3 = local.get $1` before an `if` arm that writes `$1`, while still moving the independent `$4 = local.get $2` copy after the `if`.

## Starshine implementation

Changed `src/passes/code_pushing.mbt` so the ordered multi-set helper admits direct `local.get` values in addition to local-independent pure values, with these boundaries:

- the copied source local must not equal the destination local;
- the copied source local must not be any moved destination local in the same adjacent window;
- the push point must not write the copied source local;
- for `if` / dropped-`if`, source writes inside either arm block the grouped movement;
- if a grouped local-copy movement is blocked by one source write, the existing single local-copy sink can still move later independent copies after the source-sensitive copy remains in place;
- branch values, loop targets, `br_on_*`, switch/`br_table`, non-adjacent windows, local-copy dependency chains, and broader effect/trap/GC/EH boundaries remain out of scope.

The scanner now tries ordered multi-set movement before the pre-existing single local-copy sink, preventing repeated single-set movement from reversing adjacent local-copy sets.

## Tests and profile growth

Focused tests added to `src/passes/code_pushing_test.mbt`:

- ordered local-copy multi-set movement after ordinary void `if`;
- ordered local-copy multi-set movement after dropped value `if`;
- ordered local-copy multi-set movement after narrow void-block-target `br_if`;
- source-write boundary: keep the source-sensitive copy before the `if` while moving an independent later copy.

GenValid profile growth:

- added `CodePushingMultiSetLocalCopyProfile` / `code-pushing-multi-set-local-copy`;
- included it in the `code-pushing-all` aggregate;
- added generator tests for profile resolution, aggregate membership/sampling, validation, and candidate-shape detection;
- updated `src/validate/pkg.generated.mbti` for the public enum variant.

## Validation

Commands run:

- `wasm-opt --version` -> `wasm-opt version 130 (version_130)`.
- Red-first focused test: `moon test --target native src/passes/code_pushing_test.mbt --filter '*local-copy*'` failed before implementation. Failures showed reversed local-copy movement for the ordinary `if` case, no movement for dropped-`if` / `br_if`, and an unsafe source-write movement expectation gap.
- After implementation: `moon test --target native src/passes/code_pushing_test.mbt --filter '*local-copy*'` passed `4/4`.
- `moon test --target native src/validate/gen_valid_tests.mbt --filter '*code-pushing*'` passed `3/3`.
- `moon fmt` passed.
- `moon info` passed with pre-existing warnings in `src/validate/gen_valid.mbt` and `src/validate/gen_valid_ssa.mbt`.
- `moon test --target native src/passes/code_pushing_test.mbt --filter '*code-pushing*'` passed `33/33`.
- `moon test src/passes` passed `2736/2736`.
- `moon test src/validate` passed `1627/1627`.
- `moon test` passed `6066/6066`.
- `moon build --target native --release src/cmd` passed with pre-existing unused-function warnings in `src/passes/pass_manager.mbt`, producing `_build/native/release/build/cmd/cmd.exe`.
- Bounded dedicated lane:

```sh
bun scripts/pass-fuzz-compare.ts --count 800 --seed 0x5eed --pass code-pushing --gen-valid-profile code-pushing-all --normalize local-cleanup-debris --out-dir .tmp/pass-fuzz-code-pushing-local-copy-profile-800 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 50 --keep-going-after-command-failures
```

Result: compared `800/800`; normalized matches `400`; cleanup-normalized matches `400`; raw mismatches `0`; validation failures `0`; generator failures `0`; property failures `0`; command failures `0`; cache `wasm-smith 0 hits/0 misses`, `Binaryen 798 hits/2 misses`, `Binaryen failures 0 hits/0 misses`; selected profiles were exactly `100` each for `code-pushing-if-arm`, `code-pushing-after-if`, `code-pushing-dropped-if`, `code-pushing-br-if`, `code-pushing-multi-set`, `code-pushing-multi-set-dropped-if`, `code-pushing-multi-set-br-if`, and `code-pushing-multi-set-local-copy`.

## Remaining gaps

`[O4Z-AUDIT-CP]` remains active. Remaining likely slices include switch/`br_table` mutation, broader conditional branch mutation (`br_on_*`, loop targets, branch values), non-adjacent windows, local-copy dependency chains, atomics/GC/EH/trap-option boundaries, precise Binaryen `orderedBefore` parity, full direct compare refresh, the pass-specific `10000` dedicated lane, and the final four-lane closeout matrix.

## Reopening criteria

Reopen this specific slice if a reduced local-copy multi-set example shows reversed set order, source-local writes being crossed unsafely, Starshine validation failure, a true semantic mismatch in the supported ordinary-`if` / dropped-`if` / narrow-`br_if` family, or a dedicated `code-pushing-multi-set-local-copy` / `code-pushing-all` profile regression.
