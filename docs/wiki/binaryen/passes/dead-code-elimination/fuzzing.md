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

## Latest slice evidence

2026-06-16 `try_table` body-fallthrough fix:

- Focused tests added in `src/passes/dead_code_elimination_test.mbt` lock Binaryen v130 modern-EH behavior for `try_table` whose body is unreachable: a void `try_table` makes following roots dead, and a result `try_table` collapses through the following `drop` so later roots are trimmed. The first fixture failed red-first because Starshine treated the `try_table` catch-list region as if it were a normal fallthrough path.
- Direct mixed lane: `bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass dead-code-elimination --out-dir .tmp/pass-fuzz-dce-trytable-fallthrough-10000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 100 --keep-going-after-command-failures` compared `9977/10000`, with `9977` normalized matches, `0` cleanup-normalized matches, `0` mismatches, `0` validation failures, `0` property failures, `0` generator failures, and `23` Binaryen/tool command failures (`binaryen-rec-group-zero` 22, `binaryen-bad-section-size` 1). Cache: `.tmp/pass-fuzz-cache`, wasm-smith `5000` hits / `0` misses, Binaryen `9977` hits / `0` misses, Binaryen failures `23` hits / `0` misses.
- Dedicated DCE GenValid lane: `bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x551a --pass dead-code-elimination --gen-valid-profile dce --out-dir .tmp/pass-fuzz-dce-trytable-fallthrough-genvalid-dce-10000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 100 --keep-going-after-command-failures` compared `9977/10000`, with `9977` normalized matches, `0` cleanup-normalized matches, `0` mismatches, `0` validation failures, `0` property failures, `0` generator failures, and `23` Binaryen/tool command failures (`binaryen-rec-group-zero` 20, `binaryen-invalid-tag-index` 1, `binaryen-table-index-out-of-range` 1, `binaryen-bad-section-size` 1). Cache: `.tmp/pass-fuzz-cache`, wasm-smith `5000` hits / `0` misses, Binaryen `9977` hits / `0` misses, Binaryen failures `23` hits / `0` misses.

2026-06-16 guarded raw-skip narrowing for root dead suffixes:

- Direct mixed lane: `bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass dead-code-elimination --out-dir .tmp/pass-fuzz-dce-guard-root-dead-suffix-10000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 100 --keep-going-after-command-failures` compared `9977/10000`, with `9977` normalized matches, `0` cleanup-normalized matches, `0` mismatches, `0` validation failures, `0` property failures, `0` generator failures, and `23` Binaryen/tool command failures (`binaryen-rec-group-zero` 22, `binaryen-bad-section-size` 1). Cache: `.tmp/pass-fuzz-cache`, wasm-smith `500` hits / `4500` misses, Binaryen `1041` hits / `8936` misses, Binaryen failures `2` hits / `21` misses.
- Dedicated DCE GenValid lane: `bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x551a --pass dead-code-elimination --gen-valid-profile dce --out-dir .tmp/pass-fuzz-dce-guard-root-dead-suffix-genvalid-dce-10000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 100 --keep-going-after-command-failures` compared `9977/10000`, with `9977` normalized matches, `0` cleanup-normalized matches, `0` mismatches, `0` validation failures, `0` property failures, `0` generator failures, and `23` Binaryen/tool command failures (`binaryen-rec-group-zero` 20, `binaryen-invalid-tag-index` 1, `binaryen-table-index-out-of-range` 1, `binaryen-bad-section-size` 1). Cache: `.tmp/pass-fuzz-cache`, wasm-smith `500` hits / `4500` misses, Binaryen `1055` hits / `8922` misses, Binaryen failures `3` hits / `20` misses.
