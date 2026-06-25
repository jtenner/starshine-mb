# 0817 - Code-pushing nop-window multi-set movement

Date: 2026-06-20

## Scope

This slice widens `[O4Z-AUDIT-CP]` by one bounded Binaryen-backed segment-window family: ordered multi-set movement across `nop` separators. Starshine now recognizes two or more SFA `local.set` roots in the same block segment even when harmless `nop` roots appear between them, and moves the sets after the current supported push-point set while preserving source order:

- ordinary void `if`;
- dropped value `if`;
- narrow no-branch-value `br_if` to a void block label.

The slice is not final `code-pushing` closeout. It intentionally does not implement arbitrary non-adjacent windows with effectful roots or local reads/writes between moved sets.

## Binaryen source and oracle evidence

The local oracle is `wasm-opt version 130 (version_130)`. Binaryen's `CodePushing.cpp` `Pusher::optimizeSegment(...)` scans the segment from a push point back to the first pushable root, accumulates effects for non-pushed roots, and then rewrites by compacting non-pushed roots before reinserting pushed sets in source order. That source behavior predicts that `nop` separators can remain before the push point while local sets move after it.

Focused oracle probes confirmed the bounded shape:

- `.tmp/cp-nonadjacent-if-probe.wat` moved `$a` and `$b` after an ordinary void `if`, while the separator `nop` remained before the `if`.
- `.tmp/cp-nonadjacent-dropped-if-probe.wat` moved `$a` and `$b` after a dropped value `if`, while the separator `nop` remained before the dropped wrapper.
- `.tmp/cp-nonadjacent-br-if-probe.wat` moved `$a` and `$b` after the narrow void-block-target `br_if`, while the separator `nop` remained before the branch.

All probes preserved local-set order (`$a` before `$b`).

## Starshine implementation

Changed `src/passes/code_pushing.mbt` so `code_pushing_try_sink_ordered_sets_after_push_point(...)` permits `nop` roots between collected ordered sets before a supported push point. The implementation keeps the previous safety boundaries:

- at least two movable SFA `local.set` roots are required;
- moved values remain restricted to local-independent pure values or direct stable local-copy values;
- destination locals must remain SFA and all reads must be later suffix reads after the push point;
- copied source locals must not be written by the crossed push point;
- only `nop` is admitted as the non-set separator in this slice.

Other non-set roots still bail out until there is source-backed `orderedBefore` / effect evidence for that exact family.

## Tests and profile growth

Focused tests added to `src/passes/code_pushing_test.mbt`:

- `code-pushing preserves order through nop-separated multi-set window after if`;
- `code-pushing preserves order through nop-separated multi-set window after dropped value if`;
- `code-pushing preserves order through nop-separated multi-set window after br_if`.

The tests were red-first: before implementation, all three failed because repeated single-set movement reversed the moved local order (`2 != 1`).

GenValid profile growth:

- added `CodePushingMultiSetNopWindowProfile` / `code-pushing-multi-set-nop-window`;
- included it in the `code-pushing-all` aggregate;
- added generator tests for profile resolution, aggregate membership/sampling, validation, and candidate-shape detection;
- updated `src/validate/pkg.generated.mbti` for the public enum variant.

## Validation

Commands run:

- `wasm-opt --version` -> `wasm-opt version 130 (version_130)`.
- Binaryen oracle probes listed above with `wasm-opt --all-features --code-pushing -S`.
- Red-first focused test: `moon test --target native src/passes/code_pushing_test.mbt --filter '*nop-separated*'` failed before implementation (`0/3`) with reversed moved-local order.
- After implementation: `moon test --target native src/passes/code_pushing_test.mbt --filter '*nop-separated*'` passed `3/3`.
- Red-first generator test: `moon test --target native src/validate/gen_valid_tests.mbt --filter '*code-pushing*'` failed before profile implementation because `CodePushingMultiSetNopWindowProfile` and its candidate detector were unbound.
- After profile implementation: `moon test --target native src/validate/gen_valid_tests.mbt --filter '*code-pushing*'` passed `3/3`.
- `moon fmt` passed.
- `moon info` passed with pre-existing warnings in `src/validate/gen_valid.mbt` and `src/validate/gen_valid_ssa.mbt`.
- `moon test --target native src/passes/code_pushing_test.mbt --filter '*code-pushing*'` passed `36/36`.
- `moon test src/passes` passed `2739/2739`.
- `moon test src/validate` passed `1627/1627`.
- `moon test` passed `6069/6069`.
- `moon build --target native --release src/cmd` passed with pre-existing unused-function warnings in `src/passes/pass_manager.mbt`, producing `_build/native/release/build/cmd/cmd.exe`.
- Bounded dedicated lane:

```sh
bun scripts/pass-fuzz-compare.ts --count 900 --seed 0x5eed --pass code-pushing --gen-valid-profile code-pushing-all --normalize local-cleanup-debris --out-dir .tmp/pass-fuzz-code-pushing-nop-window-profile-900 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 50 --keep-going-after-command-failures
```

Result: compared `900/900`; normalized matches `402`; cleanup-normalized matches `498`; raw mismatches `0`; validation failures `0`; generator failures `0`; property failures `0`; command failures `0`; cache `wasm-smith 0 hits/0 misses`, `Binaryen 899 hits/1 misses`, `Binaryen failures 0 hits/0 misses`; selected subprofiles: `code-pushing-after-if: 122`, `code-pushing-multi-set-dropped-if: 113`, `code-pushing-dropped-if: 103`, `code-pushing-multi-set: 102`, `code-pushing-if-arm: 97`, `code-pushing-br-if: 94`, `code-pushing-multi-set-br-if: 92`, `code-pushing-multi-set-nop-window: 92`, `code-pushing-multi-set-local-copy: 85`.

## Remaining gaps

`[O4Z-AUDIT-CP]` remains active. Remaining likely slices include switch/`br_table` mutation, broader conditional branch mutation (`br_on_*`, loop targets, branch values), arbitrary non-adjacent windows beyond `nop` separators, local-copy dependency chains, atomics/GC/EH/trap-option boundaries, precise Binaryen `orderedBefore` parity, full direct compare refresh, the pass-specific `10000` dedicated lane, and the final four-lane closeout matrix.

## Reopening criteria

Reopen this specific slice if a reduced `nop`-separated multi-set example reverses set order, moves across a non-`nop` root under this slice's claim, crosses a local read/write or effect barrier unsafely, causes Starshine validation failure, produces a true semantic mismatch in the supported ordinary-`if` / dropped-`if` / narrow-`br_if` family, or regresses the `code-pushing-multi-set-nop-window` / `code-pushing-all` profiles.

## Sources

- Binaryen `version_130` `CodePushing.cpp`: <https://github.com/WebAssembly/binaryen/blob/version_130/src/passes/CodePushing.cpp>
- `src/passes/code_pushing.mbt`
- `src/passes/code_pushing_test.mbt`
- `src/validate/gen_valid.mbt`
- `src/validate/gen_valid_tests.mbt`
- `docs/wiki/raw/binaryen/2026-06-20-code-pushing-version-130-source-lit-refresh.md`
