# 0905 - code-pushing intrinsic no-effects call implementation

Date: 2026-06-25

## Question

Can Starshine implement Binaryen's `binaryen-intrinsics/call.without.effects` `code-pushing` family now that exact function import identity is visible to HOT passes?

## Answer

Yes, for the exact source-backed into-`if` family. `code-pushing` now treats only calls to an imported function whose module/name are exactly `binaryen-intrinsics` / `call.without.effects` as movable no-effects call values, and only when all call arguments are pure and nontrapping. Ordinary imports and defined calls with the same signature remain call barriers.

This uses the `HotModuleContext` metadata added in [`0904`](0904-2026-06-25-code-pushing-import-identity-metadata.md). It deliberately avoids any type/arity heuristic.

## Behavior implemented

- Positive exact-intrinsic sinking:
  - a local set whose value is `(call $intrinsic ...)` can sink into the sole `if` arm that reads the local;
  - a lit-derived `sink-call-3` style shape with later unrelated roots also sinks.
- Negative boundaries:
  - ordinary imported calls with the same signature stay before the `if`;
  - defined calls with the same signature stay before the `if`;
  - exact intrinsic calls stay before the `if` when the local is also read after a fallthrough `if`;
  - exact intrinsic calls stay before the `if` when an argument has a `local.tee` side effect.

## TDD evidence

Red-first focused positive:

```sh
moon test --target native src/passes/code_pushing_test.mbt -f 'code-pushing sinks exact binaryen no-effects intrinsic call into only using if arm'
```

failed before implementation because the call-backed local set stayed before the `if`.

Final focused validation:

```sh
moon fmt
moon info
moon test --target native src/passes/code_pushing_test.mbt -f 'code-pushing sinks exact binaryen no-effects intrinsic call into only using if arm'
moon test --target native src/passes/code_pushing_test.mbt -f 'code-pushing keeps ordinary imported call before if despite matching signature'
moon test --target native src/passes/code_pushing_test.mbt -f 'code-pushing keeps defined call before if despite matching signature'
moon test --target native src/passes/code_pushing_test.mbt -f 'code-pushing keeps exact no-effects intrinsic before if when local is used after if'
moon test --target native src/passes/code_pushing_test.mbt -f 'code-pushing keeps no-effects intrinsic before if when argument has local tee effect'
moon test --target native src/passes/code_pushing_test.mbt
moon test --target native src/passes
moon build --target native --release src/cmd
bun scripts/pass-fuzz-compare.ts --count 200 --seed 0x5eed --pass code-pushing --gen-valid-profile code-pushing-all --normalize local-cleanup-debris --out-dir .tmp/pass-fuzz-code-pushing-intrinsic-smoke-200 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 100 --keep-going-after-command-failures
```

Results:

- `moon fmt` passed.
- `moon info` passed with pre-existing `src/validate` warnings.
- The five focused intrinsic positive/negative tests passed individually.
- Focused `code_pushing_test.mbt` passed `137/137`.
- `moon test --target native src/passes` did not complete because `tests/node/dist/starshine-debug-wasi.wasm` is missing locally; the failure was in `pass_manager_wbtest.mbt` artifact loading, not in `code-pushing`.
- Native `src/cmd` build passed with pre-existing warnings and produced `_build/native/release/build/cmd/cmd.exe`.
- Bounded dedicated compare smoke `.tmp/pass-fuzz-code-pushing-intrinsic-smoke-200` compared `200/200`: `101` normalized, `99` cleanup-normalized, `0` raw mismatches, `0` validation/generator/property/command failures.

A full four-lane direct-pass matrix was not rerun because this slice is a narrow exact-intrinsic widening with focused lit-derived tests and a bounded `code-pushing-all` smoke. Reopen for broader matrix refresh if generated mismatches appear, call movement is widened beyond the exact intrinsic, or preset scheduling starts depending on this behavior.

## Remaining work

The intrinsic no-effects blocker is closed for the source-backed exact import family. Remaining user-directed `code-pushing` blockers are:

- `ref-into-if` local type weakening/refinalization plus any WAT/HOT fixture support needed to exercise the official GC/shared-GC surfaces;
- public preset/neighborhood scheduling only after direct behavior blockers and ordered-neighborhood proof are complete.
