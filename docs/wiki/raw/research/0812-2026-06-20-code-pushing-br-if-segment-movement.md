---
kind: research-note
status: supported
last_reviewed: 2026-06-20
sources:
  - ../binaryen/2026-06-20-code-pushing-version-130-source-lit-refresh.md
  - ../../binaryen/passes/code-pushing/index.md
  - ../../../../src/passes/code_pushing.mbt
  - ../../../../src/passes/code_pushing_test.mbt
  - ../../../../src/validate/gen_valid.mbt
  - ../../../../src/validate/gen_valid_tests.mbt
---

# Code-pushing br_if segment movement

## Question

Can Starshine safely consume the already-discovered `candidate:conditional-branch` segment-window family for a narrow Binaryen-backed `br_if` push point?

## Oracle probe

Local oracle: `wasm-opt version 130 (version_130)`.

Probe input:

```wat
(module
  (func (param $cond i32) (local $tmp i32)
    (block $exit
      i32.const 7
      local.set $tmp
      local.get $cond
      br_if $exit
      local.get $tmp
      drop)))
```

Command:

```sh
wasm-opt --all-features --code-pushing -S .tmp/cp-brif-probe.wat -o .tmp/cp-brif-probe.opt.wat
```

Binaryen moved the `local.set` after the `br_if` inside the block, before the later same-block use.

Boundary probe:

```wat
(module
  (func (local $tmp i32)
    (block $exit
      i32.const 7
      local.set $tmp
      local.get $tmp
      br_if $exit
      local.get $tmp
      drop)))
```

Binaryen kept the `local.set` before the `br_if` because the branch condition reads the local before the destination.

## Implemented Starshine slice

`src/passes/code_pushing.mbt` now lets `code_pushing_try_sink_set_after_if_push_point(...)` consume `candidate:conditional-branch` only for a narrow supported branch shape:

- the push point is `BrIf`;
- it has exactly one child, the condition, and no branch values;
- the target label is a void `BlockLabel`;
- whole-root accounting proves the `br_if` itself does not read the moved local;
- every read of the moved local is in the same-region suffix after the `br_if`;
- the value still passes the existing strict movable-value gate.

The implementation deliberately leaves `br_on_*`, loop-target `br_if`, branch-value `br_if`, switch/`br_table`, multi-set movement, and broader effect/ordered-before widening for later slices.

## Tests and profile growth

Focused pass tests added:

- positive: `code-pushing moves pure SFA set after br_if before later same-block use`;
- boundary: `code-pushing keeps SFA set before br_if when the br_if reads it`.

GenValid growth:

- new leaf profile `code-pushing-br-if`;
- `code-pushing-all` now samples `code-pushing-if-arm`, `code-pushing-after-if`, `code-pushing-dropped-if`, and `code-pushing-br-if` evenly;
- generator tests cover profile resolution, aggregate sampling, module validation, and the pass-owned `br_if` candidate shape.

## Validation

Red-first evidence:

```sh
moon test --target native src/passes/code_pushing_test.mbt --filter '*br_if*'
```

Before implementation, the positive test failed with root-count drift (`3 != 4`).

Final commands:

```sh
moon test --target native src/passes/code_pushing_test.mbt --filter '*br_if*'
moon test --target native src/validate/gen_valid_tests.mbt --filter '*code-pushing*'
moon test --target native src/passes/code_pushing_test.mbt --filter '*code-pushing*'
moon fmt
moon info
moon test src/passes
moon test src/validate
moon test
moon build --target native --release src/cmd
bun scripts/pass-fuzz-compare.ts --count 400 --seed 0x5eed --pass code-pushing --gen-valid-profile code-pushing-all --normalize local-cleanup-debris --out-dir .tmp/pass-fuzz-code-pushing-br-if-profile-400 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 50 --keep-going-after-command-failures
```

Results:

- focused `*br_if*`: `2/2` passed after implementation;
- focused `*code-pushing*` pass tests: `26/26` passed;
- focused code-pushing GenValid tests: `3/3` passed;
- `moon fmt`: passed;
- `moon info`: passed with pre-existing warnings in `src/validate/gen_valid.mbt` and `src/validate/gen_valid_ssa.mbt`;
- `moon test src/passes`: `2729/2729` passed;
- `moon test src/validate`: `1627/1627` passed;
- `moon test`: `6059/6059` passed;
- native build: passed with pre-existing unused-function warnings in `src/passes/pass_manager.mbt`, producing `_build/native/release/build/cmd/cmd.exe`;
- bounded dedicated lane: compared `400/400`, normalized `200`, cleanup-normalized `200`, raw mismatches `0`, validation/generator/property/command failures `0`, selected profiles `code-pushing-if-arm: 100`, `code-pushing-br-if: 100`, `code-pushing-dropped-if: 100`, `code-pushing-after-if: 100`, cache `wasm-smith 0 hits/0 misses`, `Binaryen 396 hits/4 misses`, `Binaryen failures 0 hits/0 misses`.

## Classification

This slice is a bounded behavior-parity improvement for one locally representable conditional branch push point. It is not final `[O4Z-AUDIT-CP]` closeout because switch/`br_table`, branch-value and loop-target conditional branches, ordered multi-set movement, precise ordered-before/atomics/GC/EH/trap-option boundaries, full direct compare refresh, and the full current pass signoff matrix remain open.

## Reopening criteria

Reopen this slice if a `code-pushing-br-if` generated case produces a Starshine validation failure, a true semantic mismatch, or a branch-target/branch-value family proves that the current void-block-only guard is too broad or too narrow.
