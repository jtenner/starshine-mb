---
title: Code-pushing br_on_cast_fail movement
status: implemented
date: 2026-06-24
tags:
  - binaryen
  - code-pushing
  - O4Z-AUDIT-CP
sources:
  - ../../binaryen/2026-06-20-code-pushing-version-130-source-lit-refresh.md
  - ../../../../src/ir/hot_verify.mbt
  - ../../../../src/passes/code_pushing.mbt
  - ../../../../src/passes/code_pushing_test.mbt
  - ../../../../src/validate/gen_valid.mbt
  - ../../../../src/validate/gen_valid_tests.mbt
  - ../../../../src/validate/pkg.generated.mbti
---

# Code-pushing `br_on_cast_fail` movement

## Slice

`[O4Z-AUDIT-CP-X]` adds the matching bounded Binaryen v130-positive `br_on_cast_fail` push-point family after `[O4Z-AUDIT-CP-W]` added `br_on_cast`.

The implemented subset is deliberately narrow:

- `br_on_cast_fail` must target a block label with branch arity `1`;
- the HOT branch node must have exactly one guard child and no explicit prefix payload children;
- movement runs through the existing dropped conditional-branch push-point path;
- whole-root local accounting must prove the guard does not read any moved local;
- movement is limited to the existing single-set and adjacent local-independent ordered multi-set windows.

Loop targets, prefix payloads, and broader `br_on_*` forms remain open.

## Binaryen v130 probes

Local oracle:

```sh
wasm-opt --version
# wasm-opt version 130 (version_130)
```

Reduced positive and adjacent ordered multi-set probes under `.tmp/o4z-audit-cp-x/` show Binaryen moving pure SFA sets after a dropped `br_on_cast_fail` to a one-result block while preserving source order. A guard-read probe keeps the set before the branch when the cast operand reads the moved local.

The key valid shape is:

```wat
(module
  (func $br_on_fail (param anyref) (local $x i32)
    (drop
      (block $out (result anyref)
        (local.set $x (i32.const 7))
        (drop
          (br_on_cast_fail $out anyref (ref i31)
            (local.get 0)))
        (drop (local.get $x))
        (ref.null any)))))
```

`wasm-opt --code-pushing -all -S` moved `local.set $x` after the dropped `br_on_cast_fail`. The adjacent two-set probe moved both sets in source order; the guard-read probe remained stationary.

## Red-first result

Focused HOT tests were added first. The initial run failed before implementation:

```sh
moon test src/passes/code_pushing_test.mbt --target native -f '*br_on_cast_fail*'
```

Failure:

```text
expected code-pushing hot pass success, got verify before code-pushing: InvalidBranchArity(4, 0, 0, 1)
```

As with `br_on_non_null` and `br_on_cast`, the branch guard accounts for the final taken-edge branch payload.

## Implementation

- `src/ir/hot_verify.mbt` now counts `BrOnCastFail`'s guard child as the final taken-edge branch payload.
- `src/passes/code_pushing.mbt` admits only `BrOnCastFail` targeting a block label with branch arity `1` and exactly one guard child.
- `src/passes/code_pushing_test.mbt` adds focused HOT tests for single-set movement, adjacent ordered multi-set movement, and guard-read boundary.
- `src/validate/gen_valid.mbt` adds aggregate-safe `code-pushing-br-on-cast-fail`; `code-pushing-all` now has `17` aggregate leaves.
- `src/validate/pkg.generated.mbti` was reviewed for the public enum delta (`CodePushingBrOnCastFailProfile`).

## Evidence

Commands run after implementation:

```sh
moon test src/passes/code_pushing_test.mbt --target native -f '*br_on_cast_fail*'
# passed 3/3

moon test src/validate/gen_valid_tests.mbt --target native -f '*code-pushing*'
# passed 3/3

moon fmt
moon info --target native
moon test src/passes/code_pushing_test.mbt --target native
moon build --target native --release src/cmd
```

The focused full `code_pushing_test.mbt` run passed `71/71`. `moon info`, `moon fmt`, and the native `src/cmd` build passed with pre-existing warnings.

Aggregate profile refresh:

```sh
bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass code-pushing --gen-valid-profile code-pushing-all --normalize local-cleanup-debris --out-dir .tmp/pass-fuzz-code-pushing-br-on-cast-fail-aggregate-1000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 50 --keep-going-after-command-failures
```

Result:

- compared `1000/1000`;
- normalized matches `544`;
- cleanup-normalized matches `456`;
- raw mismatches `0`;
- validation/generator/property/command failures `0`;
- cache: wasm-smith `0` hits / `0` misses; Binaryen `999` hits / `1` miss; Binaryen failures `0` hits / `0` misses;
- selected `code-pushing-br-on-cast-fail: 49` plus every other aggregate-safe leaf.

## Remaining work

`[O4Z-AUDIT-CP]` remains active for loop-label/prefix-payload `br_on_*` forms, broader switch behavior, targeted value-`br_if` lowering normalization before aggregating `code-pushing-br-if-value`, precise `orderedBefore` coverage, broader GC/EH/trap-option surfaces, full direct compare refresh, and final closeout matrix.
