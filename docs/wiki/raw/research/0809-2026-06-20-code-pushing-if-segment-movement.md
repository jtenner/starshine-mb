# 0809-2026-06-20 code-pushing if segment movement

## Question

Can Starshine consume the new `code-pushing` segment-window diagnostic in one smallest source-backed mutating family without widening value effects?

This is a bounded `[O4Z-AUDIT-CP]` slice. It is not final pass closeout and does not claim full Binaryen `optimizeSegment(...)` parity.

## Source basis

Binaryen `version_130` `CodePushing.cpp` keeps the `LocalAnalyzer` + `Pusher` model: SFA `local.set` roots may move toward push points when the set's value effects are not ordered before intervening effects. For ordinary `if` push points, `optimizeSegment(...)` can move a pushable set after a void `if` when the local is not read by the `if` and the remaining reads are later in the same block segment.

Local oracle probe:

```sh
wasm-opt --version
# wasm-opt version 130 (version_130)

wasm-opt --all-features --code-pushing -S .tmp/code-pushing-segment-slice/segment-after-if.wat \
  -o .tmp/code-pushing-segment-slice/segment-after-if.opt.wat
```

Input shape:

```wat
(module
  (func (param i32) (local i32)
    i32.const 7
    local.set 1
    local.get 0
    if
      nop
    end
    local.get 1
    drop))
```

Binaryen output places the `local.set` after the `if` and before the later use.

## Change

Added `code_pushing_try_sink_set_after_if_push_point(...)` in `src/passes/code_pushing.mbt`.

The new mutating slice:

- starts by requiring `code_pushing_segment_window_diagnostic(...) == "candidate:if"`, so the previous inventory gates the mutation;
- only accepts an ordinary void `if` push point;
- requires a single local write and at least one later read;
- rejects if either `if` arm reads the local, leaving one-consuming-arm sinking to the existing `optimizeIntoIf`-style helper;
- requires all local reads to be same-region suffix reads after the `if`;
- keeps the existing strict movable-value gate and segment-window effect crossing checks;
- inserts a cloned `local.set` immediately after the `if` and replaces the original root with `nop`.

This intentionally does not implement dropped wrappers, conditional branches, switch/br_table, ordered multi-set movement, atomics/GC/EH widening, or full Binaryen `EffectAnalyzer::orderedBefore(...)` semantics.

## Tests

Updated `src/passes/code_pushing_test.mbt` with focused public-pipeline/HOT coverage:

- positive: `code-pushing moves pure SFA set after harmless if before later use`;
- negative: `code-pushing keeps SFA set before if when the local is used before the if`;
- negative: `code-pushing keeps SFA set before if across an ordered-before barrier`;
- updated the nested-later-use fixture to expect the new Binaryen-backed after-`if` movement.

## Red-first note

The positive test was added before implementation and failed as intended:

```sh
moon test --target native src/passes/code_pushing_test.mbt --filter '*pure SFA set after harmless if*'
# failed: expected 4 HOT roots, got 3
```

After implementing the helper, the same focused test passed.

## Validation

Commands run after implementation:

```sh
moon test --target native src/passes/code_pushing_test.mbt --filter '*pure SFA set after harmless if*'
# 1/1 passed

moon test --target native src/passes/code_pushing_test.mbt --filter '*code-pushing*'
# 22/22 passed

moon test --target native src/passes/code_pushing_wbtest.mbt --filter '*segment inventory*'
# 5/5 passed

moon fmt
# passed

moon info
# passed with pre-existing warnings in src/validate/gen_valid*.mbt

moon test src/passes
# 2725/2725 passed

moon test
# 6052/6052 passed

moon build --target native --release src/cmd
# passed with pre-existing unused-function warnings, but this checkout did not materialize target/native/release/build/cmd/cmd.exe

bun scripts/pass-fuzz-compare.ts --count 100 --seed 0x5eed --pass code-pushing \
  --out-dir .tmp/pass-fuzz-code-pushing-if-segment-100 --jobs 1 \
  --max-failures 50 --keep-going-after-command-failures
# compared 100/100, normalized 100, mismatches 0, validation/generator/property/command failures 0
```

Attempted the repo-standard native parallel smoke first:

```sh
bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass code-pushing \
  --out-dir .tmp/pass-fuzz-code-pushing-if-segment-1000 --jobs auto \
  --starshine-bin target/native/release/build/cmd/cmd.exe \
  --max-failures 100 --keep-going-after-command-failures
```

That run produced `1000` Starshine command failures because `target/native/release/build/cmd/cmd.exe` was absent after `moon build --target native --release src/cmd` in this checkout. It is classified as a local native-artifact path/tooling failure, not code-pushing behavior evidence.

## Boundaries

- This is a single-set, ordinary-void-`if` segment movement slice.
- It moves sets after the `if` only when all reads are later suffix reads, not into an arm.
- It does not widen beyond current strict movable-value/effect gates.
- It does not prove full `optimizeSegment(...)`, multi-set ordering, switch/br_table, dropped wrappers, conditional branch push points, atomics/GC/EH, or trap-option parity.
- The full required final pass signoff matrix was not run; `[O4Z-AUDIT-CP]` remains active.

## Reopening / next evidence

Reopen this slice if a reduced case shows the after-`if` movement crossing a represented effect boundary, changing trap/exception/atomic/GC observability, or moving a set whose local is read before or inside the push point.

The next useful slice is either a dedicated pass-specific GenValid profile for this family or the next smallest Binaryen-backed push-point mutation family, preferably dropped ordinary `if` or switch/br_table only after focused oracle probes and negative barriers.
