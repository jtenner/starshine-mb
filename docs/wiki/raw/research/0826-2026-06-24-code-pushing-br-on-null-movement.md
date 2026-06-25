---
kind: raw-source
status: supported
last_reviewed: 2026-06-24
source_type: implementation-slice
pass: code-pushing
slice: O4Z-AUDIT-CP-U
sources:
  - https://github.com/WebAssembly/binaryen/blob/version_130/src/passes/CodePushing.cpp
  - ../../binaryen/2026-06-20-code-pushing-version-130-source-lit-refresh.md
  - ../../../binaryen/passes/code-pushing/index.md
  - ../../../../../src/passes/code_pushing.mbt
  - ../../../../../src/passes/code_pushing_test.mbt
  - ../../../../../src/validate/gen_valid.mbt
  - ../../../../../src/validate/gen_valid_tests.mbt
---

# Code-pushing `br_on_null` movement slice

_Date:_ 2026-06-24

_Audit id:_ `[O4Z-AUDIT-CP-U]`

## Question

Can Starshine safely widen the current conditional-branch segment movement beyond `br_if` to the narrow `br_on_null` shape, using Binaryen `version_130` evidence and red-first tests?

## Binaryen source and probe evidence

The local oracle reports:

```sh
wasm-opt --version
# wasm-opt version 130 (version_130)
```

The official `version_130` `CodePushing.cpp` `Pusher::isPushPoint(...)` looks through `drop`, accepts `if` and `switch`, and accepts `Break` nodes with a condition. That source-backed conditional-branch category includes locally representable `br_on_null` forms after HOT lifting, but Starshine still needs shape-specific proof because `br_on_null` has a fallthrough reference result that is commonly dropped.

Positive single-set probe:

```wat
(module
  (func (param $r externref) (local $tmp i32)
    (block $exit
      (local.set $tmp (i32.const 7))
      (local.get $r)
      (br_on_null $exit)
      drop
      (drop (local.get $tmp)))))
```

Binaryen `wasm-opt --all-features --code-pushing -S` rewrites this so the dropped `br_on_null` stays before the pushed set:

```wat
(block $exit
  (drop
    (br_on_null $exit
      (local.get $r)))
  (local.set $tmp
    (i32.const 7))
  (drop
    (local.get $tmp)))
```

Positive adjacent multi-set probe:

```wat
(module
  (func (param $r externref) (local $a i32) (local $b i32)
    (block $exit
      (local.set $a (i32.const 2))
      (local.set $b (i32.const 3))
      (local.get $r)
      (br_on_null $exit)
      drop
      (drop (local.get $a))
      (drop (local.get $b)))))
```

Binaryen moves both local-independent sets after the dropped `br_on_null` and preserves `$a` before `$b`.

Negative operand-read probe:

```wat
(module
  (func (local $tmp externref)
    (block $exit
      (local.set $tmp (ref.null extern))
      (local.get $tmp)
      (br_on_null $exit)
      drop
      (drop (local.get $tmp)))))
```

Binaryen keeps the local set before the branch when the `br_on_null` operand reads the moved local. This slice therefore admits only dropped void-label `br_on_null` where the branch guard does not read any moved local.

## Starshine change

Starshine widened the existing single-set and ordered multi-set conditional-branch push-point gate to accept a narrow dropped `br_on_null` shape:

- branch op is `BrOnNull`;
- target label kind is block or loop;
- target branch arity is zero;
- branch child count is one guard operand;
- existing whole-root local accounting rejects guard reads/writes of moved locals;
- existing suffix accounting requires every moved-local read to appear after the dropped branch in the same region.

Focused HOT tests were used because the local WAT parser does not accept `br_on_null` syntax yet. The tests build the HOT shape directly and verify:

- one pure SFA `local.set` moves after dropped `br_on_null`;
- two adjacent local-independent SFA sets move after dropped `br_on_null` in source order;
- a set stays before dropped `br_on_null` when the guard operand reads it.

The GenValid profile gained aggregate-safe leaf `code-pushing-br-on-null`, and `code-pushing-all` now samples fourteen aggregate-safe leaves. The pre-existing targeted-only `code-pushing-br-if-value` leaf remains excluded from `code-pushing-all` because of the separate value-`br_if` lowering representation/size gap.

## Validation

Commands run in this slice:

```sh
wasm-opt --version
wasm-opt --all-features --code-pushing -S .tmp/cp-probes/br_on_null.wat -o -
wasm-opt --all-features --code-pushing -S .tmp/cp-probes/br_on_null_multiset.wat -o -
wasm-opt --all-features --code-pushing -S .tmp/cp-probes/br_on_null_operand_read.wat -o -
moon test src/passes/code_pushing_test.mbt --target native -f '*br_on_null*'
moon test src/validate/gen_valid_tests.mbt --target native -f '*code-pushing*'
moon fmt
moon info --target native
moon test src/passes/code_pushing_test.mbt --target native
moon build --target native --release src/cmd
bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass code-pushing --gen-valid-profile code-pushing-all --normalize local-cleanup-debris --out-dir .tmp/pass-fuzz-code-pushing-br-on-null-aggregate-1000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 50 --keep-going-after-command-failures
```

Focused test status:

- Red-first `moon test src/passes/code_pushing_test.mbt --target native -f '*br_on_null*'` failed before implementation with root-count mismatches (`3 != 4` and `5 != 7`), proving the positive movement did not yet happen.
- After implementation, `moon test src/passes/code_pushing_test.mbt --target native -f '*br_on_null*'` passed `3/3`.
- `moon test src/validate/gen_valid_tests.mbt --target native -f '*code-pushing*'` passed `3/3`.
- `moon fmt` passed/up to date.
- `moon info --target native` passed with pre-existing warnings and `0` errors.
- Full focused file `moon test src/passes/code_pushing_test.mbt --target native` passed `62/62`.
- `moon build --target native --release src/cmd` passed with pre-existing warnings.

Aggregate-safe compare result:

- Out dir: `.tmp/pass-fuzz-code-pushing-br-on-null-aggregate-1000`
- Compared: `1000/1000`
- Normalized matches: `424`
- Cleanup-normalized matches: `576`
- Raw mismatches: `0`
- Validation failures: `0`
- Generator failures: `0`
- Property failures: `0`
- Command failures: `0`
- Cache: `wasm-smith 0 hits/0 misses`; Binaryen `998 hits/2 misses`; Binaryen failures `0 hits/0 misses`
- Selected subprofiles included `code-pushing-br-on-null: 74` plus every other aggregate-safe leaf.

## Status and remaining gaps

`[O4Z-AUDIT-CP-U]` is complete for the narrow dropped void-label `br_on_null` single-/adjacent-multi-set movement family.

Still open for later slices:

- broader `br_on_*` forms, especially `br_on_non_null`, `br_on_cast`, and branch-value/reference-payload forms;
- non-adjacent `br_on_null` windows beyond current safe separators;
- value-label `br_on_null` or branch-payload variants;
- exact WAT-surface coverage once Starshine's parser accepts these forms;
- targeted value-`br_if` lowering normalization/fix before aggregating `code-pushing-br-if-value`;
- general `Effects::orderedBefore` parity, broader atomics/GC/EH/trap-option boundaries, and final CP closeout matrix.
