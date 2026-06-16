---
kind: workflow
status: working
last_reviewed: 2026-06-16
sources:
  - ../../../tooling/pass-fuzz-compare.md
  - ../../../../../scripts/lib/pass-fuzz-compare-task.ts
  - ../../../../../src/validate/gen_valid.mbt
  - ../../../../../src/validate/gen_valid_tests.mbt
---

# `dead-code-elimination` Fuzzing Profile

Recommended general lane: run the ordinary mixed-generator compare-pass lane for this pass:

```sh
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass dead-code-elimination --out-dir .tmp/pass-fuzz-dead-code-elimination --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe
```

Dedicated GenValid profile: use `--gen-valid-profile dce` for DCE-positive unreachable-shape modules:

```sh
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x551a --pass dead-code-elimination --gen-valid-profile dce --out-dir .tmp/pass-fuzz-dead-code-elimination-genvalid-dce-10000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe
```

The profile intentionally emits Binaryen v130 `DeadCodeElimination.cpp` shape families that the generic mixed lane may hit sparsely:

- `dce-non-control-unreachable-child`: a non-control numeric expression where the first unreachable operand makes later operands dead while earlier operands must be preserved as drops.
- `dce-drop-unreachable`: `drop` around `unreachable`.
- `dce-block-dead-suffix`: block suffixes after `br`, `br_table`, or literal `unreachable`.
- `dce-block-has-break-guard`: a concrete-result block whose dead tail follows a break targeting that block, covering Binaryen's `TypeUpdater::hasBreaks` guard.
- `dce-if-unreachable-condition`: `if` with an unreachable condition.
- `dce-if-both-arms-unreachable`: result `if` with both arms literally unreachable.
- `dce-loop-literal-unreachable-body`: loop whose body is literally `unreachable`.
- `dce-try-table-unreachable`: `try_table` whose body is literally `unreachable`.

Legacy `try` and stack-switching handler-label liveness remain fixture-only coverage for now; GenValid currently emits `try_table` but does not have a dedicated legacy-try or stack-switching template in this DCE profile.

For targeted batch generation outside compare-pass, the same labels can be used with `--require-feature`, for example `--require-feature dce-block-has-break-guard`.
