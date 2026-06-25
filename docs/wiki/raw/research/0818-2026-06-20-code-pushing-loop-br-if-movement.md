---
kind: research
status: supported
created: 2026-06-20
sources:
  - ../binaryen/2026-06-20-code-pushing-version-130-source-lit-refresh.md
  - ../../binaryen/passes/code-pushing/index.md
  - ../../binaryen/passes/code-pushing/starshine-strategy.md
  - ../../binaryen/passes/code-pushing/fuzzing.md
  - ../../../../../src/passes/code_pushing.mbt
  - ../../../../../src/passes/code_pushing_test.mbt
  - ../../../../../src/validate/gen_valid.mbt
  - ../../../../../src/validate/gen_valid_tests.mbt
---

# Code-pushing loop-target `br_if` movement

## Summary

This thirteenth `[O4Z-AUDIT-CP]` slice widens the existing narrow no-branch-value `br_if` movement proof from void block labels to void loop labels.

Starshine now treats a `br_if` to a void loop label as a supported push point for the already-implemented:

- single SFA `local.set` movement after `br_if`;
- ordered adjacent local-independent multi-set movement after `br_if`;
- ordered adjacent direct local-copy multi-set movement after `br_if` when copied source locals are stable.

The slice intentionally does not add branch values, `br_on_*`, switch/`br_table`, arbitrary non-`nop` separators, local-copy dependency chains, or broader `orderedBefore` / atomics / GC / EH / trap-option movement.

## Binaryen oracle probes

Local oracle:

```sh
wasm-opt --version
# wasm-opt version 130 (version_130)
```

Single-set loop-target probe:

```wat
(module
  (func (param i32) (local i32)
    (loop $top
      (i32.const 7)
      (local.set 1)
      (local.get 0)
      (br_if $top)
      (local.get 1)
      (drop))))
```

`wasm-opt --all-features --code-pushing -S` moved the set after the `br_if` in the loop body.

Ordered multi-set loop-target probe:

```wat
(module
  (func (param i32) (local i32 i32)
    (loop $top
      (i32.const 7)
      (local.set 1)
      (i32.const 9)
      (local.set 2)
      (local.get 0)
      (br_if $top)
      (local.get 1)
      (drop)
      (local.get 2)
      (drop))))
```

Binaryen moved both sets after the `br_if`, preserving source order.

Direct local-copy loop-target probe:

```wat
(module
  (func (param i32 i32 i32) (local i32 i32)
    (loop $top
      (local.get 1)
      (local.set 3)
      (local.get 2)
      (local.set 4)
      (local.get 0)
      (br_if $top)
      (local.get 3)
      (drop)
      (local.get 4)
      (drop))))
```

Binaryen moved both direct local-copy sets after the loop-target `br_if`, preserving source order.

## Implementation

`src/passes/code_pushing.mbt` changes only the narrow branch push-point predicate:

- `code_pushing_br_if_push_point_supported(...)` still requires `HotOp::BrIf`;
- the root still must have exactly one child, so branch values remain out of scope;
- the target label must be a `BlockLabel` or `LoopLabel`;
- the target branch arity must be zero.

The existing movement helpers keep the same safety checks for moved locals, push-point reads/writes, source-local writes, same-region / same-loop-body suffix reads, and source-order preservation.

## Tests

Focused pass tests added to `src/passes/code_pushing_test.mbt`:

- `code-pushing moves pure SFA set after loop-target br_if before later same-loop use`;
- `code-pushing preserves order when moving multiple SFA sets after loop-target br_if`;
- `code-pushing preserves order when moving multiple local-copy SFA sets after loop-target br_if`.

The first two tests were run red-first before implementation:

```sh
moon test --target native src/passes/code_pushing_test.mbt --filter '*loop-target br_if*'
# failed: expected moved-set/nop-expanded loop bodies, got pre-existing unmoved shapes
```

Profile tests in `src/validate/gen_valid_tests.mbt` now cover the new public leaf `CodePushingLoopBrIfProfile`, aggregate membership/sampling, and the validating loop-body candidate shape.

## Validation

Commands run after implementation:

```sh
moon fmt
moon info
moon test --target native src/passes/code_pushing_test.mbt --filter '*code-pushing*'
moon test --target native src/validate/gen_valid_tests.mbt --filter '*code-pushing*'
moon test src/passes
moon test src/validate
moon test
moon build --target native --release src/cmd
```

Results:

- `moon fmt` passed.
- `moon info` passed with pre-existing warnings in `src/validate/gen_valid.mbt` and `src/validate/gen_valid_ssa.mbt`.
- Focused code-pushing tests passed `39/39`.
- Focused GenValid code-pushing tests passed `3/3`.
- `moon test src/passes` passed `2742/2742`.
- `moon test src/validate` passed `1627/1627`.
- Full `moon test` passed `6072/6072`.
- Native build passed with pre-existing unused-function warnings in `src/passes/pass_manager.mbt`, producing `_build/native/release/build/cmd/cmd.exe`.

Bounded dedicated profile lane:

```sh
bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass code-pushing --gen-valid-profile code-pushing-all --normalize local-cleanup-debris --out-dir .tmp/pass-fuzz-code-pushing-loop-br-if-profile-1000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 50 --keep-going-after-command-failures
```

Result:

- compared `1000/1000`;
- normalized matches `516`;
- cleanup-normalized matches `484`;
- raw mismatches `0`;
- validation failures `0`;
- generator failures `0`;
- property failures `0`;
- command failures `0`;
- cache: `wasm-smith 0 hits/0 misses`, `Binaryen 998 hits/2 misses`, `Binaryen failures 0 hits/0 misses`;
- selected profiles: `code-pushing-multi-set-br-if: 110`, `code-pushing-loop-br-if: 98`, `code-pushing-if-arm: 108`, `code-pushing-multi-set-local-copy: 103`, `code-pushing-dropped-if: 102`, `code-pushing-multi-set-dropped-if: 103`, `code-pushing-after-if: 93`, `code-pushing-multi-set: 79`, `code-pushing-br-if: 103`, `code-pushing-multi-set-nop-window: 101`.

This is bounded slice evidence, not final pass closeout. The lane still uses `--normalize local-cleanup-debris` for the documented Starshine `nop` / empty-else cleanup drift.

## Remaining gaps and reopening criteria

`[O4Z-AUDIT-CP]` remains active. Reopen this specific slice if any future oracle probe, focused test, pass-fuzz failure, or artifact replay shows that void loop-target `br_if` movement changes local availability, validates incorrectly, mishandles source-local writes for direct local-copy values, or loses order among moved sets.

Still-open broader code-pushing gaps include switch/`br_table` mutation, `br_on_*`, branch values, arbitrary non-adjacent windows beyond `nop`, local-copy dependency chains, precise `orderedBefore` modeling, atomics/GC/EH/trap-option families, a full direct compare refresh, the pass-specific `10000` dedicated lane, and the final four-lane closeout matrix.
