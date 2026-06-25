---
kind: research
status: working
date: 2026-06-20
sources:
  - ../../binaryen/2026-06-20-code-pushing-version-130-source-lit-refresh.md
  - ../../../binaryen/passes/code-pushing/index.md
  - ../../../../../src/passes/code_pushing.mbt
  - ../../../../../src/passes/code_pushing_test.mbt
  - ../../../../../src/validate/gen_valid.mbt
  - ../../../../../src/validate/gen_valid_tests.mbt
---

# Code-pushing `br_if` ordered multi-set movement

## Question

Can Starshine safely extend its bounded ordered multi-set `code-pushing` movement from ordinary void `if` / dropped value-`if` push points to the already-supported narrow `br_if` push point, matching local Binaryen `version_130` behavior while preserving source order?

## Binaryen oracle probe

Local oracle:

```sh
wasm-opt --version
# wasm-opt version 130 (version_130)
```

Reduced probe:

```wat
(module
  (func (param i32) (local i32 i32)
    (block $exit
      i32.const 7
      local.set 1
      i32.const 9
      local.set 2
      local.get 0
      br_if $exit
      local.get 1
      drop
      local.get 2
      drop)))
```

Command:

```sh
wasm-opt --all-features --code-pushing -S .tmp/cp-multiset-br-if-probe.wat -o .tmp/cp-multiset-br-if-probe.opt.wat
```

Observed result: Binaryen moves both sets after the `br_if` in source order, `local.set $1` then `local.set $2`, before the suffix reads.

## Starshine change

`src/passes/code_pushing.mbt` generalizes the ordered helper to `code_pushing_try_sink_ordered_sets_after_push_point(...)` and admits the existing narrow conditional-branch push point:

- only `BrIf`;
- no branch value children beyond the condition;
- target must be a void block label;
- moved values must be local-independent movable values;
- moved locals must be unique SFA locals;
- the branch root must not read or write any moved local;
- all reads must be same-block suffix reads after the `br_if`;
- cloned `local.set`s are inserted immediately after the branch in source order;
- original set roots are replaced with `nop`.

The slice intentionally does not cover `br_if` branch values, loop-target branches, `br_on_*`, switch/`br_table`, non-adjacent windows, local-read-dependent moved values, atomics/GC/EH, or trap-option widening.

## Tests

Red-first focused test:

```sh
moon test --target native src/passes/code_pushing_test.mbt --filter '*multiple SFA sets after br_if*'
```

Before implementation this failed with reversed moved-local order (`2 != 1`), because the previous single-set path moved the second set before the first in a later fixed-point round.

Final focused tests:

```sh
moon test --target native src/passes/code_pushing_test.mbt --filter '*multiple SFA sets after br_if*'
moon test --target native src/validate/gen_valid_tests.mbt --filter '*code-pushing*'
moon test --target native src/passes/code_pushing_test.mbt --filter '*code-pushing*'
```

Results: focused `br_if` test passed `1/1`; generator code-pushing tests passed `3/3`; focused code-pushing tests passed `29/29`.

## Dedicated GenValid profile

Added `CodePushingMultiSetBrIfProfile` / `code-pushing-multi-set-br-if`, wired it into `code-pushing-all`, and added generator-shape tests. The profile emits a block with two adjacent SFA sets, a no-branch-value `br_if` to the block label, and suffix reads in source order.

Bounded dedicated lane:

```sh
bun scripts/pass-fuzz-compare.ts --count 700 --seed 0x5eed --pass code-pushing --gen-valid-profile code-pushing-all --normalize local-cleanup-debris --out-dir .tmp/pass-fuzz-code-pushing-multi-set-br-if-profile-700 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 50 --keep-going-after-command-failures
```

Result: compared `700/700`; normalized matches `403`; cleanup-normalized matches `297`; raw mismatches `0`; validation failures `0`; generator failures `0`; property failures `0`; command failures `0`; selected subprofiles `code-pushing-dropped-if: 91`, `code-pushing-multi-set: 97`, `code-pushing-after-if: 95`, `code-pushing-multi-set-br-if: 111`, `code-pushing-if-arm: 105`, `code-pushing-multi-set-dropped-if: 101`, `code-pushing-br-if: 100`; cache `wasm-smith 0 hits/0 misses`, `Binaryen 697 hits/3 misses`, `Binaryen failures 0 hits/0 misses`.

As in prior slices, `--normalize local-cleanup-debris` is bounded evidence for Starshine's known `nop` / empty-else cleanup drift. It is not raw output parity or final pass closeout.

## Broader validation

Commands run:

```sh
moon fmt
moon info
moon test src/passes
moon test src/validate
moon test
moon build --target native --release src/cmd
```

Results: `moon fmt`, `moon info`, `moon test src/passes` (`2732/2732`), `moon test src/validate` (`1627/1627`), full `moon test` (`6062/6062`), and native `src/cmd` build passed. Warnings were pre-existing unused-value warnings in `src/validate/gen_valid.mbt`, `src/validate/gen_valid_ssa.mbt`, and `src/passes/pass_manager.mbt`.

## Current boundary

This is `[O4Z-AUDIT-CP-J]`, not final `[O4Z-AUDIT-CP]` closeout. Remaining work includes switch/`br_table` mutation, broader conditional branches (`br_on_*`, loop targets, branch values), broader ordered multi-set movement outside adjacent local-independent subcases, precise `orderedBefore` / atomics / GC / EH / trap-option boundaries, a pass-specific `10000` profile lane, and the full modern four-lane closeout matrix.

## Reopening criteria

Reopen this slice if:

- a `code-pushing-multi-set-br-if` generated case mismatches without being explained by bounded local-cleanup normalization;
- a branch-root read/write of a moved local is found to move incorrectly;
- a branch-value or loop-target case is accidentally admitted;
- Starshine emits invalid wasm for this family;
- future Binaryen source/lit evidence changes the safe `br_if` movement contract.
