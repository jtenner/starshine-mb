# SGO003F loop self-guard boundary study

Date: 2026-05-25

## Slice

`[SGO]003F - Loop Self-Guard Breadth Beyond Current Symmetry`

## Goal

Probe whether loop-wrapped read-only-to-write guard conditions should broaden beyond Starshine's current non-branching direct/simple-pure value-loop subset.

This slice is research plus guardrail tests. It does not change optimizer behavior. `[SGO]003` remains active/partial.

## Binaryen probes

Fixtures live under `.tmp/sgo003f-probes/`.

### Current positive baseline

`loop-direct-baseline.wat` yields only `global.get $g` from a `loop (result i32)` into the final no-else same-global `global.set`. Binaryen removes the fake traffic and makes `$g` immutable. Starshine already has local coverage for this family.

### Independent effect prefix positive

`loop-effect-prefix.wat` prefixes the yielded candidate read with an independent write to a different global:

```wat
loop (result i32)
  i32.const 7
  global.set $h
  global.get $g
end
if
  i32.const 1
  global.set $g
end
```

Binaryen removes `$g` fake traffic while preserving the independent `$h` write. Starshine currently keeps `$g` mutable here. A naive one-line implementation attempt that enabled the full FlowScanner for loop bodies made this fixture pass but regressed existing nested-if/loop coverage and changed the emitted loop/cleanup shape, so it was reverted. Future implementation needs a narrower loop-specific scanner or a cleanup/frontier fix, not a blanket reuse of the block FlowScanner.

### Branch/backedge boundary

`loop-br-if.wat` includes `br_if 0` in the value loop. Binaryen preserves the mutable global and guard traffic. Starshine now has a local guardrail for this boundary.

### Trapping candidate consumer boundary

`loop-load-consumer.wat` feeds the candidate `global.get` to `i32.load` inside the value loop. Binaryen preserves the mutable global and guard traffic. Starshine already had a local trapping-load guardrail; this probe reconfirms it for the current slice.

## Starshine tests

Added focused tests in `src/passes/simplify_globals_optimizing_test.mbt`:

- `keeps loop-wrapped independent effect prefixes conservative` records the current Starshine/Binaryen gap for the independent wrong-global `global.set` prefix and prevents accidental partial broadening without a complete loop-specific proof;
- `preserves branchy loop-wrapped self guards` pins the `br_if`/backedge boundary.

Existing tests continue to cover direct loop positives, simple pure loop positives, and trapping candidate-consuming load negatives.

## Decision

Do not broaden loop matching in this slice. The exact independent-effect prefix is a Binaryen-positive future candidate, but the quick implementation route is too broad. Keep `[SGO]003F` completed as a boundary study and leave any behavior work to a future narrow loop FlowScanner slice or `[SGO]003N`/cleanup-frontier work if nested cleanup remains the blocker.

## Validation

- `moon test src/passes` passed (`1596/1596`).
- Full quick gate and any direct SGO fuzz evidence are recorded in the commit validation report for this slice.
