---
kind: research
status: supported
date: 2026-06-20
sources:
  - ../../binaryen/2026-06-20-code-pushing-version-130-source-lit-refresh.md
  - ../../../../src/passes/code_pushing.mbt
  - ../../../../src/passes/code_pushing_test.mbt
  - ../../../../src/validate/gen_valid.mbt
  - ../../../../src/validate/gen_valid_tests.mbt
  - ../../../../docs/wiki/binaryen/passes/code-pushing/fuzzing.md
---

# Code-pushing dropped-if ordered multi-set movement

## Question

Can Starshine safely extend the ordered adjacent multi-set movement slice from ordinary void `if` push points to dropped value-`if` push points while preserving Binaryen-observed source order?

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
    i32.const 7
    local.set 1
    i32.const 9
    local.set 2
    local.get 0
    if (result i32)
      i32.const 1
    else
      i32.const 2
    end
    drop
    local.get 1
    drop
    local.get 2
    drop))
```

Command:

```sh
wasm-opt --all-features --code-pushing -S .tmp/cp-multiset-dropped-if-probe.wat -o .tmp/cp-multiset-dropped-if-probe.opt.wat
```

Observed Binaryen `version_130` output moved both `local.set` roots after the dropped value-`if` wrapper, preserving source order: first `local.set $1`, then `local.set $2`.

## Starshine change

`src/passes/code_pushing.mbt` now lets the ordered adjacent multi-set helper treat a `drop` wrapping an `if` as the push point in the same narrow family as ordinary void `if` movement. The guard remains intentionally strict:

- two or more adjacent `local.set` roots;
- each destination local is SFA under the existing whole-function counters;
- moved locals are unique;
- moved values are pure/nontrapping under the existing movable-value predicate;
- moved values contain no local reads;
- the wrapped `if` arms do not read any moved local;
- all reads are same-region suffix reads after the dropped wrapper;
- insertion preserves source order and original roots become `nop`.

The slice deliberately does not cover switch/`br_table`, narrow or broad conditional branches, dropped `br_if`, local-read-dependent value expressions, non-adjacent multi-set windows, atomics/GC/EH/trap-option widening, or full Binaryen `orderedBefore(...)` parity.

## Tests and validation

TDD evidence:

- Red-first `moon test --target native src/passes/code_pushing_test.mbt --filter '*multiple SFA sets after dropped*'` failed before implementation with reversed moved-local order (`2 != 1`).
- After implementation the same focused test passed `1/1`.

Focused and standard evidence after adding the GenValid profile leaf:

- `moon test --target native src/validate/gen_valid_tests.mbt --filter '*code-pushing*'` passed `3/3`.
- `moon test --target native src/passes/code_pushing_test.mbt --filter '*code-pushing*'` passed `28/28`.
- `moon fmt` passed.
- `moon info` passed with pre-existing warnings in `src/validate/gen_valid.mbt` and `src/validate/gen_valid_ssa.mbt`.
- `moon test src/passes` passed `2731/2731`.
- `moon test src/validate` passed `1627/1627`.
- `moon test` passed `6061/6061`.
- `moon build --target native --release src/cmd` passed with pre-existing unused-function warnings and produced `_build/native/release/build/cmd/cmd.exe`.

Bounded dedicated compare lane:

```sh
bun scripts/pass-fuzz-compare.ts --count 600 --seed 0x5eed --pass code-pushing --gen-valid-profile code-pushing-all --normalize local-cleanup-debris --out-dir .tmp/pass-fuzz-code-pushing-multi-set-dropped-if-profile-600 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 50 --keep-going-after-command-failures
```

Result: compared `600/600`, normalized matches `292`, cleanup-normalized matches `308`, raw mismatches `0`, validation/generator/property/command failures `0`, selected profiles `code-pushing-dropped-if: 101`, `code-pushing-multi-set-dropped-if: 103`, `code-pushing-if-arm: 89`, `code-pushing-after-if: 109`, `code-pushing-multi-set: 110`, `code-pushing-br-if: 88`, cache `wasm-smith 0 hits/0 misses`, `Binaryen 597 hits/3 misses`, `Binaryen failures 0 hits/0 misses`.

## Classification

This is a bounded Binaryen-parity improvement for adjacent local-independent ordered multi-set movement after a dropped value-`if` push point. The dedicated lane remains cleanup-normalized because Starshine erases `nop`/empty-else local-cleanup debris that Binaryen leaves; this is not a final raw-output parity or closeout claim.

## Reopening criteria

Reopen this slice if a reduced example shows Starshine reversing moved set order, moving a set whose wrapped `if` arm reads the destination local, moving a value with local-read dependence, crossing an effect/trap/GC/EH boundary outside the current proof, producing invalid wasm, or regressing the `code-pushing-multi-set-dropped-if` GenValid profile.
