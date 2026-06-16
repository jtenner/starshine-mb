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

Legacy `try` and stack-switching handler-label liveness remain limited/tooling-boundary coverage for now. GenValid currently emits `try_table` but does not have a dedicated legacy-try or stack-switching template in this DCE profile. Starshine's WAST lowering represents legacy `try` as a synthetic sequential check block rather than a real `Try` node, so focused local tests cover only the two observed DCE reachability cases and keep a conservative raw skip for reachable synthetic arms. Starshine still does not represent stack-switching `cont` / `resume` handler labels, so that surface remains an unsupported input with reopening criteria.

For targeted batch generation outside compare-pass, the same labels can be used with `--require-feature`, for example `--require-feature dce-block-has-break-guard`.

## Latest slice evidence

2026-06-16 residual no-candidate and EH/tooling boundary classification:

- Focused tests in `src/passes/dead_code_elimination_test.mbt` now lock a true straight-line `no-dce-candidates` raw skip (`(func nop)`) separately from the literal-unreachable block case that must not skip. The same file adds legacy-try coverage for the current local lowering surface: when a lowered legacy synthetic try has a reachable arm, DCE skips the raw function with `legacy-synthetic-try-reachable-arm-dce-noop` so following roots stay reachable; when the lowered legacy try body and all catches are unreachable, DCE still trims the following root. The stack-switching `cont` / `resume` handler-label fixture remains rejected by the current WAST/lib type surface.
- Binaryen v130 comparison probes under `.tmp/dce-legacy-stack-boundary/` confirmed the oracle behavior to reopen against: `wasm-opt version 130 (version_130)` with `wasm-opt --all-features --dce -S` keeps code after a legacy `try` when either the body or catch can finish, removes the following root when the legacy `try` body and all catches are unreachable, and keeps stack-switching handler block result types live under a surrounding `drop` in `dce-stack-switching.wast`. These are not audit-close evidence; they narrow the remaining blockers to missing local real-`Try`/stack-switching representation and document the conservative synthetic-try guard.
- Direct mixed lane: `bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass dead-code-elimination --out-dir .tmp/pass-fuzz-dce-legacy-boundary-10000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 100 --keep-going-after-command-failures` compared `9977/10000`, with `9977` normalized matches, `0` cleanup-normalized matches, `0` mismatches, `0` validation failures, `0` property failures, `0` generator failures, and `23` Binaryen/tool command failures (`binaryen-rec-group-zero` 22, `binaryen-bad-section-size` 1). Cache: `.tmp/pass-fuzz-cache`, wasm-smith `5000` hits / `0` misses, Binaryen `9977` hits / `0` misses, Binaryen failures `23` hits / `0` misses.
- Dedicated DCE GenValid lane: `bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x551a --pass dead-code-elimination --gen-valid-profile dce --out-dir .tmp/pass-fuzz-dce-legacy-boundary-genvalid-dce-10000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 100 --keep-going-after-command-failures` compared `9977/10000`, with `9977` normalized matches, `0` cleanup-normalized matches, `0` mismatches, `0` validation failures, `0` property failures, `0` generator failures, and `23` Binaryen/tool command failures (`binaryen-rec-group-zero` 20, `binaryen-invalid-tag-index` 1, `binaryen-table-index-out-of-range` 1, `binaryen-bad-section-size` 1). Cache: `.tmp/pass-fuzz-cache`, wasm-smith `5000` hits / `0` misses, Binaryen `9977` hits / `0` misses, Binaryen failures `23` hits / `0` misses.

2026-06-16 guarded and no-candidate raw-skip narrowing for explicit dead suffixes:

- Focused tests added in `src/passes/dead_code_elimination_test.mbt` lock Binaryen v130 behavior for explicit dead suffixes before the remaining raw skips: nested dead suffixes in functions that still need Starshine's load/call/set and loop-outer-branch HOT hazard guards, literal-unreachable block/loop collapse before trimming the containing suffix, and a literal-unreachable block that previously took the broader `no-dce-candidates` skip. The fixtures failed red-first by taking the old raw no-op paths and preserving dead code. Local `wasm-opt version 130 (version_130)` with `wasm-opt --all-features --dce -S` removes the same nested suffixes and collapses the no-candidate literal-unreachable block.
- Direct mixed lane: `bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass dead-code-elimination --out-dir .tmp/pass-fuzz-dce-explicit-dead-suffix-no-candidate-10000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 100 --keep-going-after-command-failures` compared `9977/10000`, with `9977` normalized matches, `0` cleanup-normalized matches, `0` mismatches, `0` validation failures, `0` property failures, `0` generator failures, and `23` Binaryen/tool command failures (`binaryen-rec-group-zero` 22, `binaryen-bad-section-size` 1). Cache: `.tmp/pass-fuzz-cache`, wasm-smith `5000` hits / `0` misses, Binaryen `9977` hits / `0` misses, Binaryen failures `23` hits / `0` misses.
- Dedicated DCE GenValid lane: `bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x551a --pass dead-code-elimination --gen-valid-profile dce --out-dir .tmp/pass-fuzz-dce-explicit-dead-suffix-no-candidate-genvalid-dce-10000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 100 --keep-going-after-command-failures` compared `9977/10000`, with `9977` normalized matches, `0` cleanup-normalized matches, `0` mismatches, `0` validation failures, `0` property failures, `0` generator failures, and `23` Binaryen/tool command failures (`binaryen-rec-group-zero` 20, `binaryen-invalid-tag-index` 1, `binaryen-table-index-out-of-range` 1, `binaryen-bad-section-size` 1). Cache: `.tmp/pass-fuzz-cache`, wasm-smith `5000` hits / `0` misses, Binaryen `9977` hits / `0` misses, Binaryen failures `23` hits / `0` misses.

2026-06-16 `try_table` body-fallthrough fix:

- Focused tests added in `src/passes/dead_code_elimination_test.mbt` lock Binaryen v130 modern-EH behavior for `try_table` whose body is unreachable: a void `try_table` makes following roots dead, and a result `try_table` collapses through the following `drop` so later roots are trimmed. The first fixture failed red-first because Starshine treated the `try_table` catch-list region as if it were a normal fallthrough path.
- Direct mixed lane: `bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass dead-code-elimination --out-dir .tmp/pass-fuzz-dce-trytable-fallthrough-10000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 100 --keep-going-after-command-failures` compared `9977/10000`, with `9977` normalized matches, `0` cleanup-normalized matches, `0` mismatches, `0` validation failures, `0` property failures, `0` generator failures, and `23` Binaryen/tool command failures (`binaryen-rec-group-zero` 22, `binaryen-bad-section-size` 1). Cache: `.tmp/pass-fuzz-cache`, wasm-smith `5000` hits / `0` misses, Binaryen `9977` hits / `0` misses, Binaryen failures `23` hits / `0` misses.
- Dedicated DCE GenValid lane: `bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x551a --pass dead-code-elimination --gen-valid-profile dce --out-dir .tmp/pass-fuzz-dce-trytable-fallthrough-genvalid-dce-10000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 100 --keep-going-after-command-failures` compared `9977/10000`, with `9977` normalized matches, `0` cleanup-normalized matches, `0` mismatches, `0` validation failures, `0` property failures, `0` generator failures, and `23` Binaryen/tool command failures (`binaryen-rec-group-zero` 20, `binaryen-invalid-tag-index` 1, `binaryen-table-index-out-of-range` 1, `binaryen-bad-section-size` 1). Cache: `.tmp/pass-fuzz-cache`, wasm-smith `5000` hits / `0` misses, Binaryen `9977` hits / `0` misses, Binaryen failures `23` hits / `0` misses.

2026-06-16 guarded raw-skip narrowing for root dead suffixes:

- Direct mixed lane: `bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass dead-code-elimination --out-dir .tmp/pass-fuzz-dce-guard-root-dead-suffix-10000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 100 --keep-going-after-command-failures` compared `9977/10000`, with `9977` normalized matches, `0` cleanup-normalized matches, `0` mismatches, `0` validation failures, `0` property failures, `0` generator failures, and `23` Binaryen/tool command failures (`binaryen-rec-group-zero` 22, `binaryen-bad-section-size` 1). Cache: `.tmp/pass-fuzz-cache`, wasm-smith `500` hits / `4500` misses, Binaryen `1041` hits / `8936` misses, Binaryen failures `2` hits / `21` misses.
- Dedicated DCE GenValid lane: `bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x551a --pass dead-code-elimination --gen-valid-profile dce --out-dir .tmp/pass-fuzz-dce-guard-root-dead-suffix-genvalid-dce-10000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 100 --keep-going-after-command-failures` compared `9977/10000`, with `9977` normalized matches, `0` cleanup-normalized matches, `0` mismatches, `0` validation failures, `0` property failures, `0` generator failures, and `23` Binaryen/tool command failures (`binaryen-rec-group-zero` 20, `binaryen-invalid-tag-index` 1, `binaryen-table-index-out-of-range` 1, `binaryen-bad-section-size` 1). Cache: `.tmp/pass-fuzz-cache`, wasm-smith `500` hits / `4500` misses, Binaryen `1055` hits / `8922` misses, Binaryen failures `3` hits / `20` misses.
