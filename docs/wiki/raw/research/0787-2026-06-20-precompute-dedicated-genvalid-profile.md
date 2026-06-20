# Precompute dedicated GenValid profile

## Question

Close the missing dedicated GenValid profile blocker for canonical pass `precompute` so the modern pass closeout matrix can include a pass-specific lane.

## Files reviewed

- `docs/README.md` — repo docs/wiki schema, pass signoff, validation, and commit policy.
- `.pi/skills/recursive-handoff/SKILL.md` — bounded recursive continuation rules.
- `.pi/skills/starshine-pass-implementation/SKILL.md` — pass-specific GenValid profile and closeout requirements.
- `.pi/skills/commit/SKILL.md` — commit policy.
- `agent-todo.md` — active `[O4Z-AUDIT-PC]` state and remaining O4z/final-closeout blockers.
- `docs/wiki/binaryen/passes/precompute/` — current precompute dossier, especially `index.md`, `fuzzing.md`, and `starshine-port-readiness-and-validation.md`.
- `docs/wiki/raw/research/0785-2026-06-20-precompute-modern-signoff-refresh.md` — status refresh that identified the missing profile blocker.
- `docs/wiki/raw/research/0786-2026-06-20-precompute-descriptor-split-audit.md` — prior descriptor split slice.
- `docs/wiki/ir2/pass-porting-checklist.md` — pass metadata and helper contract.
- `src/validate/gen_valid.mbt` — named profiles, composite profile sampling, custom profile modules, feature facts, and batch manifest selected-profile handling.
- `src/validate/gen_valid_tests.mbt` — focused generator/profile coverage.

## TDD notes

Added focused generator tests first in `src/validate/gen_valid_tests.mbt`. The initial red run failed at compile time because `PrecomputeScalarProfile`, `PrecomputeAllProfile`, and the other planned profile constructors did not yet exist. That confirmed the new profile surface was not already present.

After implementing the profiles, one test initially failed because the effect-boundary profile deliberately emits a helper function before the main boundary function; the assertion inspected only the first defined function. The test helper was corrected to scan all defined functions for boundary op coverage.

## Implementation

Added `precompute-all` as a deterministic composite GenValid profile with these singleton leaves:

- `precompute-scalar` — exact i32/i64 arithmetic, comparison, `eqz`, and shift folds.
- `precompute-control` — constant `if` and result/block cleanup shapes.
- `precompute-global` — immutable defined-global `i32`, `i64`, and `ref.null externref` constants used by `global.get`.
- `precompute-drop-cleanup` — pure drop cleanup, typed `select`, and dropped result-block cleanup inputs.
- `precompute-effect-boundary` — deliberate non-fold/trap/effect boundaries for integer division, mutable `global.set`, `i32.load`, and `call`.
- `precompute-gc-atomic-boundary` — GC/array boundary module with `struct.atomic.get_s` and mutable `array.get` traffic.
- `precompute-direct-prefix-watch` — local set/get/tee chain that watches the direct public `precompute` surface without claiming public `precompute-propagate` parity.

Aliases now resolve `precompute`, `precompute-closeout`, and `precompute-all-profiles` to `precompute-all`. Composite batch manifests record deterministic leaf labels through the existing `selected_profile` mechanism.

## Focused tests added

- `precompute gen-valid profiles resolve and expose replayable aggregate`
  - proves stable names, aliases, composite membership, and replayable leaf selection.
- `precompute aggregate profile samples every current precompute family`
  - proves the `0x5eed` aggregate samples every current leaf within a bounded case window.
- `precompute scalar control global and cleanup gen-valid profiles emit pass-owned shapes`
  - proves validating modules cover scalar fold opcodes, control facts, defined globals/global.get, and typed-select cleanup.
- `precompute boundary gen-valid profiles emit trap effect gc atomic and direct-prefix watchpoints`
  - proves validating modules cover call/memory/effect/trap boundaries, struct atomic get, mutable array get, and local tee watchpoint traffic.

## Commands and results

- `moon test --package jtenner/starshine/validate --file gen_valid_tests.mbt`
  - Red-first result before implementation: compile failed because the new precompute profile constructors were absent.
- `moon test --package jtenner/starshine/validate --file gen_valid_tests.mbt`
  - After implementation and test-helper correction: passed `84/84`.

- `moon fmt && moon test --package jtenner/starshine/validate --file gen_valid_tests.mbt && moon test src/validate && git diff --check`
  - Result: formatting completed; focused generator tests passed `84/84`; validate package tests passed `1620/1620`; diff check passed.
- `moon info`
  - Result: passed with three pre-existing warnings in `src/validate/gen_valid.mbt` and `src/validate/gen_valid_ssa.mbt`.
- `moon test`
  - Result: passed `6011/6011`.
- `moon build --target native --release src/cmd`
  - Result: command completed with pre-existing unused-function warnings in `src/passes/pass_manager.mbt`, but no `target/native/release/build/cmd/cmd.exe` appeared in this checkout.
- `bun scripts/pass-fuzz-compare.ts --count 100 --seed 0x5eed --pass precompute --gen-valid-profile precompute-all --out-dir .tmp/pass-fuzz-precompute-genvalid-precompute-all-smoke-100 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures`
  - Result: infrastructure failure, not a semantic result. Compared `0/100`; command failures `100`, all `starshine-command-failed`, because the explicit native `cmd.exe` path was absent.
- `bun scripts/pass-fuzz-compare.ts --count 50 --seed 0x5eed --pass precompute --gen-valid-profile precompute-all --normalize drop-consts --normalize local-cleanup-debris --normalize unreachable-control-debris --out-dir .tmp/pass-fuzz-precompute-genvalid-precompute-all-smoke-50-norm2 --jobs 1 --max-failures 2000 --keep-going-after-command-failures`
  - Result: compared `50/50`; normalized `25`; cleanup-normalized `25`; mismatches `0`; validation/generator/property/command failures `0`; Binaryen cache `49` hits / `1` miss; selected profiles: `precompute-drop-cleanup=8`, `precompute-control=10`, `precompute-gc-atomic-boundary=4`, `precompute-direct-prefix-watch=4`, `precompute-global=11`, `precompute-scalar=6`, `precompute-effect-boundary=7`.
- `bun scripts/pass-fuzz-compare.ts --count 50 --seed 0x5eed --pass precompute --gen-valid-profile precompute-all --out-dir .tmp/pass-fuzz-precompute-genvalid-precompute-all-smoke-50-raw --jobs 1 --max-failures 2000 --keep-going-after-command-failures`
  - Result: compared `50/50`; normalized `25`; mismatches `25`; validation/generator/property/command failures `0`. Agent classification: the raw mismatches are the known cleanup-debris family for this pass-profile surface; rerunning with the documented PC normalizers classified them as cleanup-normalized matches with zero remaining mismatches.

## Classification

- Dedicated profile blocker: closed for `[O4Z-AUDIT-PC]`.
- Direct pass behavior: unchanged. This slice adds generator/profile coverage only and does not change `src/passes/precompute.mbt` or pass-manager execution.
- `[O4Z-AUDIT-PC]`: remains open. The current O4z `o4z-precompute-noop` gate is undecided, and the modern final closeout lanes still need to be run with current code: regular GenValid `100000`, explicit wasm-smith `10000`, dedicated `precompute-all` `10000`, and broad named `pass-fuzz-stress` `10000`.

## Commands not run yet

- No final closeout compare lane was run; the `50`-case smoke is only profile plumbing evidence and does not replace the required `10000` dedicated-profile lane.
- No successful explicit-native parallel compare lane was run because `target/native/release/build/cmd/cmd.exe` was absent even after `moon build --target native --release src/cmd` completed.
- No O4z slot/neighborhood replay has been run in this profile slice; the O4z no-op gate remains a separate blocker.
