---
kind: research
status: supported
created: 2026-06-21
sources:
  - ../../../binaryen/passes/code-pushing/index.md
  - ../../../../src/passes/code_pushing.mbt
  - ../../../../src/passes/code_pushing_test.mbt
  - ../../../../src/validate/gen_valid.mbt
  - ../../../../src/validate/gen_valid_tests.mbt
---

# Code Pushing `drop(global.get)` Window Multi-Set Movement

## Question

Can Starshine safely grow its ordered `code-pushing` segment-window movement from `nop`, `drop(const)`, and `drop(local.get)` separators to a bounded `drop(global.get)` separator family while preserving Binaryen v130 behavior?

## Binaryen probes

Local oracle: `wasm-opt version 130 (version_130)`.

Positive probes:

- `.tmp/cp-drop-global-separator-probe.wat` with two SFA `local.set` roots separated by `drop (global.get $g)` before an ordinary void `if`: Binaryen moved both sets after the `if`, preserved source order, and left the dropped global read before the `if`.
- `.tmp/cp-drop-global-sep-dropped-if-probe.wat` with the same separator before a dropped value `if`: Binaryen moved both sets after the dropped wrapper, preserved source order, and left the dropped global read before the wrapper.

Boundary probes:

- `.tmp/cp-drop-global-sep-br-if-probe.wat` with the same separator before a no-branch-value `br_if` to a void block label: Binaryen did **not** move either set.
- `.tmp/cp-drop-global-sep-loop-br-if-probe.wat` with the same separator before a no-branch-value `br_if` to a void loop label: Binaryen did **not** move either set.

This slice therefore treats `drop(global.get)` as a source-backed separator only for ordinary void `if` and dropped value-`if` push points. The `br_if` global-get separator shape is a focused boundary, not a future-free deferral.

## Implementation

`src/passes/code_pushing.mbt` now recognizes zero-result `Drop` roots with exactly one live `GlobalGet` child as a bounded ordered-window separator.

The mutating ordered multi-set helper:

- admits the separator only after at least one preceding SFA set is already in the window;
- leaves the `drop(global.get)` root before the push point;
- inserts cloned moved sets after the push point in original source order;
- permits this separator for ordinary void `if` and dropped value-`if` push points;
- rejects the same separator when the discovered push point is the current narrow `br_if` family.

The single-set `br_if` movement helper also rejects this bounded boundary so it does not peel later sets out of the same Binaryen-stationary global-get window.

## Tests

Focused pass tests added in `src/passes/code_pushing_test.mbt`:

- `code-pushing preserves order through global-get-separated multi-set window after if`;
- `code-pushing preserves order through global-get-separated multi-set window after dropped value if`;
- `code-pushing keeps global-get-separated multi-set window before br_if boundary`.

The red-first run `moon test --target native src/passes/code_pushing_test.mbt --filter '*global-get-separated*'` failed before the final implementation because Starshine moved the `br_if` boundary window (`expected local.set`). After implementation the same command passed `3/3`.

## GenValid profile

`src/validate/gen_valid.mbt` adds `CodePushingMultiSetGlobalGetWindowProfile` with public name `code-pushing-multi-set-global-get-window` and includes it in the `code-pushing-all` composite. The deterministic module has one immutable i32 global, two local-independent SFA sets separated by `drop (global.get 0)`, an ordinary void `if`, and suffix reads in source order.

`src/validate/gen_valid_tests.mbt` covers profile naming, aggregate membership/sampling, validation, global presence, and candidate-shape detection.

## Validation

Commands run for this slice:

- `moon test --target native src/passes/code_pushing_test.mbt --filter '*global-get-separated*'` before final implementation: failed as intended on the `br_if` boundary.
- `moon test --target native src/passes/code_pushing_test.mbt --filter '*global-get-separated*'`: passed `3/3`.
- `moon test --target native src/validate/gen_valid_tests.mbt --filter '*code-pushing*'`: passed `3/3`.
- `moon test --target native src/passes/code_pushing_test.mbt --filter '*code-pushing*'`: passed `50/50`.
- `moon info`: passed with pre-existing warnings in `src/validate/gen_valid.mbt` and `src/validate/gen_valid_ssa.mbt`.
- `moon fmt`: passed.
- `moon test src/passes`: passed `2753/2753`.
- `moon test src/validate`: passed `1627/1627`.
- `moon test`: passed `6083/6083`.
- `moon build --target native --release src/cmd`: passed with pre-existing warnings in `src/passes/pass_manager.mbt`; native binary path is `_build/native/release/build/cmd/cmd.exe`.
- `bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass code-pushing --gen-valid-profile code-pushing-all --normalize local-cleanup-debris --out-dir .tmp/pass-fuzz-code-pushing-global-get-window-profile-1000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 50 --keep-going-after-command-failures`: compared `1000/1000`; normalized `375`; cleanup-normalized `625`; raw mismatches `0`; validation/generator/property/command failures `0`; selected subprofiles `code-pushing-after-if: 82`, `code-pushing-br-if: 83`, `code-pushing-dropped-if: 83`, `code-pushing-if-arm: 90`, `code-pushing-loop-br-if: 76`, `code-pushing-multi-set: 77`, `code-pushing-multi-set-br-if: 69`, `code-pushing-multi-set-drop-window: 73`, `code-pushing-multi-set-dropped-if: 64`, `code-pushing-multi-set-global-get-window: 67`, `code-pushing-multi-set-local-copy: 75`, `code-pushing-multi-set-local-get-window: 89`, `code-pushing-multi-set-nop-window: 72`; cache `wasm-smith 0 hits/0 misses`, `Binaryen 999 hits/1 misses`, `Binaryen failures 0 hits/0 misses`.

## Boundaries

Still out of scope:

- switch/`br_table` mutation;
- `br_on_*`, branch-value conditional branches, and `drop(global.get)` movement across narrow `br_if` push points;
- arbitrary non-adjacent windows beyond `nop`, `drop(const)`, `drop(local.get)`, and this bounded ordinary-/dropped-`if` `drop(global.get)` family;
- local-copy dependency chains;
- atomics/GC/EH/trap-option widening;
- full `orderedBefore(...)` parity.

## Reopening criteria

Reopen this slice if a Starshine output for this family fails validation, a focused `drop(global.get)` window test regresses, a Binaryen source/lit refresh shows the `br_if` boundary should now move, or direct compare exposes a non-cleanup-normalized semantic mismatch attributable to this separator handling.
