---
title: Code-pushing br_on_cast movement
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

# Code-pushing `br_on_cast` movement

## Slice

`[O4Z-AUDIT-CP-W]` continues the `code-pushing` release-gating audit by adding a bounded Binaryen v130-positive `br_on_cast` push-point family.

The implemented subset is deliberately narrow:

- `br_on_cast` must target a block label with branch arity `1`;
- the HOT branch node must have exactly one guard child and no explicit prefix payload children;
- the branch is currently reached through the existing dropped conditional-branch push-point path;
- whole-root local accounting must prove the guard does not read any moved local;
- movement is limited to the existing single-set and adjacent local-independent ordered multi-set windows.

Broader `br_on_cast` forms, prefix payloads, loop targets, `br_on_cast_fail`, and mixed dependency windows remain open.

## Binaryen v130 probes

Local oracle:

```sh
wasm-opt --version
# wasm-opt version 130 (version_130)
```

Reduced positive probe:

```wat
(module
  (func $br_on (local $x (ref null func))
    (drop
      (block $out (result (ref func))
        (local.set $x (ref.func $br_on))
        (drop
          (br_on_cast $out funcref (ref func)
            (ref.null nofunc)))
        (drop (local.get $x))
        (ref.func $br_on)))))
```

`wasm-opt --code-pushing -all -S` moved the `local.set` after the dropped `br_on_cast`; the relevant optimized order was `br_on_cast`, then `local.set`, then `local.get`.

Adjacent ordered multi-set probe:

```wat
(module
  (func $br_on_multi (local $a (ref null func)) (local $b (ref null func))
    (drop
      (block $out (result (ref func))
        (local.set $a (ref.func $br_on_multi))
        (local.set $b (ref.func $br_on_multi))
        (drop
          (br_on_cast $out funcref (ref func)
            (ref.null nofunc)))
        (drop (local.get $a))
        (drop (local.get $b))
        (ref.func $br_on_multi)))))
```

Binaryen moved both sets after the dropped `br_on_cast` and preserved source order.

Guard-read boundary probe:

```wat
(module
  (func $br_on_guard (local $x (ref null func))
    (drop
      (block $out (result (ref func))
        (local.set $x (ref.func $br_on_guard))
        (drop
          (br_on_cast $out funcref (ref func)
            (local.get $x)))
        (drop (local.get $x))
        (ref.func $br_on_guard)))))
```

Binaryen kept the `local.set` before `br_on_cast` when the cast operand read the moved local.

The outside-use boundary probe kept the set before `br_on_cast` when the local was read after the enclosing block rather than in the same block suffix.

## Red-first result

Focused HOT tests were added first because the local WAT/parser surface is not reliable for these `br_on_*` pass fixtures. The initial run failed before implementation:

```sh
moon test src/passes/code_pushing_test.mbt --target native -f '*br_on_cast*'
```

Failure:

```text
expected code-pushing hot pass success, got verify before code-pushing: InvalidBranchArity(4, 0, 0, 1)
```

This showed the same implicit-branch-payload verification issue as `br_on_non_null`: successful `br_on_cast` carries the tested reference as the final taken-edge branch payload.

## Implementation

- `src/ir/hot_verify.mbt` now counts `BrOnCast`'s guard child as the final taken-edge branch payload when checking label arity.
- `src/passes/code_pushing.mbt` admits only `BrOnCast` targeting a block label with branch arity `1` and exactly one guard child.
- `src/passes/code_pushing_test.mbt` adds focused HOT coverage for:
  - single pure SFA set movement after dropped `br_on_cast`;
  - two adjacent local-independent SFA sets moving after `br_on_cast` in source order;
  - guard-read boundary remaining stationary.
- `src/validate/gen_valid.mbt` adds aggregate-safe `code-pushing-br-on-cast`; `code-pushing-all` now has `16` aggregate leaves.
- `src/validate/pkg.generated.mbti` was reviewed for the public enum delta (`CodePushingBrOnCastProfile`).

## Evidence

Commands run after implementation:

```sh
moon test src/passes/code_pushing_test.mbt --target native -f '*br_on_cast*'
# passed 3/3

moon test src/validate/gen_valid_tests.mbt --target native -f '*code-pushing*'
# passed 3/3

moon fmt
moon info --target native
moon test src/passes/code_pushing_test.mbt --target native
moon build --target native --release src/cmd
```

The focused full `code_pushing_test.mbt` run passed `68/68`. `moon info`, `moon fmt`, and the native `src/cmd` build passed with pre-existing warnings.

Aggregate profile refresh:

```sh
bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass code-pushing --gen-valid-profile code-pushing-all --normalize local-cleanup-debris --out-dir .tmp/pass-fuzz-code-pushing-br-on-cast-aggregate-1000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 50 --keep-going-after-command-failures
```

Result:

- compared `1000/1000`;
- normalized matches `502`;
- cleanup-normalized matches `498`;
- raw mismatches `0`;
- validation/generator/property/command failures `0`;
- cache: wasm-smith `0` hits / `0` misses; Binaryen `999` hits / `1` miss; Binaryen failures `0` hits / `0` misses;
- selected `code-pushing-br-on-cast: 62` plus every other aggregate-safe leaf.

## Remaining work

`[O4Z-AUDIT-CP]` remains active. Immediate follow-ups include `br_on_cast_fail`, loop-label/prefix-payload `br_on_*` forms, broader `br_on_non_null` variants, targeted value-`br_if` lowering normalization before aggregating `code-pushing-br-if-value`, broader switch behavior, precise `orderedBefore` coverage, broader GC/EH/trap-option surfaces, full direct compare refresh, and final closeout matrix.
