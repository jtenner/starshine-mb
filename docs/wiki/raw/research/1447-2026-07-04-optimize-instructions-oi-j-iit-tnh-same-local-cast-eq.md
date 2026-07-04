# OI-J IIT/TNH same-local nullable `ref.cast` equality slice

Date: 2026-07-04

## Scope

This slice covers one finite OI-J trap-mode gap from roadmap probe 12:

```wat
(func (param $x eqref) (result i32)
  (ref.eq
    (local.get $x)
    (ref.cast (ref null $a) (local.get $x))))
```

Binaryen `version_130` behavior:

- default `--optimize-instructions`: preserves `ref.cast` and `ref.eq` because the cast can trap;
- `--ignore-implicit-traps --optimize-instructions`: folds to `i32.const 1`;
- `--traps-never-happen --optimize-instructions`: folds to `i32.const 1`.

This is limited to the same-local `ref.eq` observation point. It does not claim general ordinary `ref.cast` erasure in arbitrary result contexts.

## Probe evidence

Probe directory: `.tmp/oi-j-tnh-ordinary-cast-20260704/`.

Commands used:

- `wasm-opt --all-features --optimize-instructions -S .tmp/oi-j-roadmap-probes-20260703/inputs/12-tnh-only-cast-skip.wat`
- `wasm-opt --all-features --ignore-implicit-traps --optimize-instructions -S ...`
- `wasm-opt --all-features --traps-never-happen --optimize-instructions -S ...`
- `target/native/release/build/cmd/cmd.exe` in the same three modes on `.tmp/oi-j-roadmap-probes-20260703/inputs/12-tnh-only-cast-skip.input.wasm`
- `wasm-tools validate --features all` on Starshine outputs.

Before implementation, Starshine preserved `local.get; local.get; ref.cast; ref.eq` in default, IIT, and TNH modes. Binaryen preserved it only in default mode and emitted `i32.const 1` in IIT/TNH.

## Implementation

`src/passes/optimize_instructions.mbt` now threads `HotPassContext` into the same-local `ref.eq` helper. For nullable `RefCast` over a direct `LocalGet`, the helper keeps the old heap-compatibility proof in default mode, but in `ctx.ignore_implicit_traps` or `ctx.traps_never_happen` it may treat the cast operand as the same local even if the local heap is broader than the cast target. The existing `ref.eq` fold then replaces the equality with `i32.const 1`.

The default-mode behavior remains unchanged.

## Tests and validation

Added red-first test:

- `src/passes/optimize_instructions_test.mbt::optimize-instructions folds same-local nullable ref.cast equality under trap-ignoring modes`

Red result before implementation:

```text
moon test --package jtenner/starshine/passes --file optimize_instructions_test.mbt --target native --filter 'optimize-instructions folds same-local nullable ref.cast equality under trap-ignoring modes'
... failed: [LocalGet, LocalGet, RefCast, RefEq] != [I32Const(1)]
```

Green results after implementation:

```text
moon test --package jtenner/starshine/passes --file optimize_instructions_test.mbt --target native --filter 'optimize-instructions folds same-local nullable ref.cast equality under trap-ignoring modes'
Total tests: 1, passed: 1, failed: 0.

moon test
Total tests: 7424, passed: 7424, failed: 0.
```

Native `src/cmd` build passed with pre-existing warnings. Manual Starshine replays of roadmap probe 12 in default/IIT/TNH modes validated with `wasm-tools --features all`; default retained the `ref.cast`/`ref.eq`, while IIT/TNH each printed one `i32.const 1`. Descriptor-profile IIT and TNH compare smokes also remained clean:

```text
bun scripts/pass-fuzz-compare.ts --pass optimize-instructions --ignore-implicit-traps --gen-valid-profile pass-oi-descriptor-gc --count 12 --seed 0x5eed --out-dir .tmp/oi-j-descriptor-iit-compare-count12-20260704-same-local-cast --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures
Compared cases: 12/12; Normalized matches: 12; Mismatches: 0; failures: 0.

bun scripts/pass-fuzz-compare.ts --pass optimize-instructions --traps-never-happen --gen-valid-profile pass-oi-descriptor-gc --count 12 --seed 0x5eed --out-dir .tmp/oi-j-descriptor-tnh-compare-count12-20260704-same-local-cast --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures
Compared cases: 12/12; Normalized matches: 12; Mismatches: 0; failures: 0.
```

## Remaining OI-J work

OI-J remains `blocked-surface` after this slice. Active residuals include `ref.test_desc` representation/tooling, broader descriptor-cast behavior, broader useful-type-info and exactness breadth, TNH/IIT cases beyond the local-write and same-local equality trap-mode slices plus existing descriptor-profile lanes, and generalized descriptor effect/control localization.
