# Code-pushing drop-local-get window multi-set movement

Date: 2026-06-21

## Question

Can Starshine safely close another bounded `code-pushing` segment-window parity slice by allowing ordered local-independent SFA multi-set movement when a harmless `drop (local.get ...)` root separates the moved sets before an already-supported push point?

## Source/oracle evidence

Local oracle: `wasm-opt version 130 (version_130)`.

Binaryen positive probes moved two SFA sets separated by `drop (local.get $param)` after each already-supported push point family while preserving source order and leaving the dropped local read before the push point:

- ordinary void `if`: `.tmp/cp-drop-local-separator-probe.wat` -> `.tmp/cp-drop-local-separator-probe.opt.wat`;
- dropped value `if`: `.tmp/cp-local-get-sep-dropped-if-probe.wat` -> `.tmp/cp-local-get-sep-dropped-if-probe.opt.wat`;
- no-branch-value `br_if` to a void block label: `.tmp/cp-local-get-sep-br-if-probe.wat` -> `.tmp/cp-local-get-sep-br-if-probe.opt.wat`;
- no-branch-value `br_if` to a void loop label: `.tmp/cp-local-get-sep-loop-br-if-probe.wat` -> `.tmp/cp-local-get-sep-loop-br-if-probe.opt.wat`.

This is a narrow extension of the [`0817`](./0817-2026-06-20-code-pushing-nop-window-multi-set-movement.md) and [`0819`](./0819-2026-06-21-code-pushing-drop-window-multi-set-movement.md) separator slices. It does not imply arbitrary non-set or effectful separators are safe.

## Implementation

`src/passes/code_pushing.mbt` now adds `code_pushing_node_is_drop_local_get_window_separator(...)` and admits zero-result `drop` roots with exactly one live `local.get` child as ordered multi-set window separators. The combined `code_pushing_node_is_safe_drop_window_separator(...)` currently accepts only `drop(const)` and `drop(local.get)` separator roots.

The ordered window helper still requires at least one preceding set in the window. It leaves the separator before the push point, clones the moved sets after the push point in source order, and replaces the original set roots with `nop`.

Existing push-point boundaries remain unchanged:

- ordinary void `if`;
- dropped value `if` wrapper;
- no-branch-value `br_if` to a void block label;
- no-branch-value `br_if` to a void loop label.

Existing moved-value boundaries remain unchanged:

- local-independent pure values or direct local copies already admitted by the ordered helper;
- no local-copy dependency chains;
- copied source locals must not be moved destinations and must not be written by the crossed push point;
- no switch/`br_table`, `br_on_*`, branch-value, atomics/GC/EH, or trap-option widening.

## Tests

Focused pass tests added in `src/passes/code_pushing_test.mbt`:

- `code-pushing preserves order through local-get-separated multi-set window after if`;
- `code-pushing preserves order through local-get-separated multi-set window after dropped value if`;
- `code-pushing preserves order through local-get-separated multi-set window after loop-target br_if`;
- `code-pushing preserves order through local-get-separated multi-set window after br_if`.

Red-first result before implementation:

```sh
moon test --target native src/passes/code_pushing_test.mbt --filter '*local-get-separated*'
```

failed `4/4`; Starshine moved only the later set first through the older single-set path, producing reversed moved-local order evidence (`3 != 2`).

After implementation the same focused lane passed `4/4`, and the focused full code-pushing lane passed `47/47`.

## GenValid profile

`src/validate/gen_valid.mbt` adds `CodePushingMultiSetLocalGetWindowProfile` named `code-pushing-multi-set-local-get-window` and includes it in the `code-pushing-all` composite. The generated module has two local-independent SFA sets separated by `drop (local.get 0)` before an ordinary void `if` controlled by a separate parameter, followed by suffix reads in source order.

`src/validate/gen_valid_tests.mbt` checks profile naming, aggregate membership/sampling, validation, and candidate-shape detection. The focused `*code-pushing*` GenValid test lane passed `3/3`.

## Validation

Commands run after implementation:

```sh
moon test --target native src/passes/code_pushing_test.mbt --filter '*local-get-separated*'
moon test --target native src/validate/gen_valid_tests.mbt --filter '*code-pushing*'
moon test --target native src/passes/code_pushing_test.mbt --filter '*code-pushing*'
moon test --target native src/validate/gen_valid_tests.mbt --filter '*code-pushing*'
moon fmt
moon info
moon test src/passes
moon test src/validate
moon test
moon build --target native --release src/cmd
bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass code-pushing --gen-valid-profile code-pushing-all --normalize local-cleanup-debris --out-dir .tmp/pass-fuzz-code-pushing-local-get-window-profile-1000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 50 --keep-going-after-command-failures
```

Results:

- Focused local-get separator pass tests: `4/4` passed after implementation.
- Focused code-pushing GenValid tests: `3/3` passed.
- Focused full code-pushing pass tests: `47/47` passed with pre-existing unused-function warnings in pass-manager files.
- `moon fmt`: passed.
- `moon info`: passed with pre-existing warnings in `src/validate/gen_valid.mbt` and `src/validate/gen_valid_ssa.mbt`.
- `moon test src/passes`: `2750/2750` passed.
- `moon test src/validate`: `1627/1627` passed.
- `moon test`: `6080/6080` passed.
- Native release build: passed with pre-existing unused-function warnings in `src/passes/pass_manager.mbt`; binary path `_build/native/release/build/cmd/cmd.exe`.
- Bounded native dedicated lane: compared `1000/1000`, normalized matches `412`, cleanup-normalized matches `588`, raw mismatches `0`, validation/generator/property/command failures `0`, cache `wasm-smith 0 hits/0 misses`, `Binaryen 998 hits/2 misses`, `Binaryen failures 0 hits/0 misses`.
- Selected subprofiles: `code-pushing-multi-set-nop-window: 81`, `code-pushing-multi-set-local-get-window: 86`, `code-pushing-multi-set-br-if: 81`, `code-pushing-multi-set-dropped-if: 89`, `code-pushing-multi-set-local-copy: 83`, `code-pushing-multi-set-drop-window: 87`, `code-pushing-loop-br-if: 79`, `code-pushing-multi-set: 91`, `code-pushing-dropped-if: 82`, `code-pushing-after-if: 82`, `code-pushing-br-if: 81`, `code-pushing-if-arm: 78`.

## Boundaries and reopening criteria

This slice is not final `[O4Z-AUDIT-CP]` closeout.

Still out of scope:

- switch/`br_table` mutation;
- broader conditional branches such as `br_on_*`;
- branch-value `br_if` / `br_table` / `br_on_*` movement;
- arbitrary non-adjacent windows beyond the now-supported `nop`, `drop(const)`, and `drop(local.get)` separators;
- local-copy dependency chains;
- full Binaryen `LocalAnalyzer` / `EffectAnalyzer::orderedBefore(...)` parity;
- atomics/GC/EH/trap-option widening;
- full `10000` pass-specific profile lane and the final four-lane pass signoff matrix.

Reopen this specific separator slice if Binaryen probes show `drop(local.get)` can be unsafe under a source/destination-local interaction not caught by the suffix/local counters, if Starshine's separator starts changing validation or order, or if direct compare artifacts expose a raw mismatch not explained by the bounded local-cleanup normalizer.
