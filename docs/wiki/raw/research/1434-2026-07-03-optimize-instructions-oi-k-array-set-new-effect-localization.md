# Optimize-instructions OI-K array.set / array.new effect localization

Date: 2026-07-03

## Scope

This slice continues the narrowed OI-K effect-localization work after `1432` and the first selected-operand localization implementation slice.

Implemented in this slice:

- effectful `array.set` value localization for direct one-use fresh arrays whose allocation is locally proven non-trapping;
- effectful `array.new_fixed` constructor sibling localization for the same `array.set` removal/trap surfaces;
- effectful `array.new` repeated-value localization for the already-covered `array.len(array.new(...))` and `array.get(array.new(...), i32.const index)` surfaces.

Still out of scope:

- OI-J descriptor/exactness/TNH/IIT behavior;
- OI-L shared/atomic/RMW/cmpxchg behavior;
- dynamic indexes and dynamic, negative, or huge lengths;
- multi-use aggregate producers;
- control-shaped and multi-result operands;
- packed fixed-array selected-sibling localization not already covered by existing packed helpers;
- effectful repeated-value `array.set` over `array.new`, which remains fail-closed pending a dedicated source probe or explicit boundary acceptance.

## Source/probe-backed behavior

This slice uses the earlier OI-K source/probe notes plus the focused 2026-07-03 probe as the contract:

- `0833` records O4z-style Binaryen evidence for `array.set(array.new_fixed/default(...), const-index, effectful-value)` preserving the set value as `drop(call)` before `nop` or `unreachable` when allocation and bounds are proven;
- `0833` also records effect-boundary evidence for constructor siblings and set values being preserved before the out-of-bounds trap;
- `0832` records `array.new` repeated-value `array.get` forwarding and an effectful out-of-bounds repeated-value boundary;
- `0831` records that Binaryen kept effectful `array.len(array.new(...))`, so the Starshine len-localization arm is a bounded Starshine cleanup extension over the already-covered small constant-length surface rather than a current Binaryen-output parity claim;
- `1432` narrowed the remaining OI-K work to effect localization rather than broad GC aggregate expansion.

The implementation treats most probes as O4z-style OI audit evidence where the earlier notes did; it does not claim broader direct `--optimize-instructions` parity for shapes that the earlier notes explicitly classified as direct-pass no-rewrite or O4z-style only. The `array.len(array.new(call, small_const))` rewrite is documented separately because the refreshed Binaryen probe still keeps that exact effectful length shape.

## Starshine change

`src/passes/optimize_instructions.mbt` now has a small ordered-effect materialization helper, and `src/passes/pass_manager.mbt` extends the existing narrow GC raw-gate escape to the exact flat stack shapes covered here so call-bearing probes reach the HOT pass instead of the stack-carried-effect skip. The helper walks operands in source evaluation order, skips pure operands, emits effectful single-result operands as `drop(operand)`, emits effectful zero-result operands directly, and fails closed for control-shaped or multi-result operands.

The helper is used to:

1. remove in-bounds `array.set` on fresh `array.new_fixed`, `array.new_default`, and pure-repeated `array.new` arrays while preserving effectful constructor siblings and/or effectful set values before the resulting `nop`/empty block;
2. fold out-of-bounds `array.set` on those non-trapping fresh arrays to ordered dropped effects followed by `unreachable`;
3. fold `array.len(array.new(effectful_value, small_const_len))` to `drop(effectful_value); i32.const len`;
4. fold out-of-bounds `array.get(array.new(effectful_value, small_const_len), const_oob)` to `drop(effectful_value); unreachable`.

The existing selected-operand forwarding helper was tightened so non-selected operands fail closed for control-shaped or multi-result values even when they appear pure under the coarse effect mask.

## Focused tests

`src/passes/optimize_instructions_test.mbt` was updated with red-first expectations for:

- in-bounds `array.set(array.new_fixed(...), const, call $effect)` preserving the call exactly once as a drop and removing both `array.set` and `array.new_fixed`;
- out-of-bounds `array.set(array.new_fixed(...), const_oob, call $effect)` preserving the call before `unreachable`;
- out-of-bounds `array.set(array.new_default(...), const_oob, call $effect)` preserving the call before `unreachable`;
- effectful `array.new_fixed` constructor sibling plus pure set value preserving the constructor effect as a drop;
- effectful constructor sibling plus effectful set value preserving both calls as drops in source order;
- effectful set value on pure-repeated `array.new` preserving the set value as a drop;
- `array.len(array.new(call $effect, small_len))` preserving the repeated value exactly once as a drop before the folded length;
- `array.get(array.new(call $effect, small_len), const in-bounds)` continuing to forward the repeated value exactly once;
- `array.get(array.new(call $effect, small_len), const out-of-bounds)` preserving the repeated value exactly once as a drop before `unreachable`.

Existing fail-closed tests continue to cover dynamic indexes, dynamic/negative/huge lengths, multi-use fixed-array producers, effectful fixed-array out-of-bounds gets, array.fill/copy no-rewrite boundaries, and descriptor/shared/atomic quarantine by omission from these rewrites.

## Validation status

Validation run on 2026-07-03:

```sh
moon fmt
python3 -m json.tool docs/wiki/binaryen/passes/optimize-instructions/parity-matrix.json >/tmp/parity-matrix.json.check
moon info
moon test
moon build --target native --release src/cmd
git diff --check
bun scripts/pass-fuzz-compare.ts --pass optimize-instructions --count 10000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe --out-dir .tmp/pass-fuzz-optimize-instructions-oi-k-1434-10000
wasm-tools parse .tmp/oi-k-array-set-new-effect-localization-probes.wat -o .tmp/oi-k-array-set-new-effect-localization/input.wasm
wasm-tools validate --features gc,reference-types .tmp/oi-k-array-set-new-effect-localization/input.wasm
wasm-opt .tmp/oi-k-array-set-new-effect-localization/input.wasm --enable-reference-types --enable-gc --optimize-instructions -S -o .tmp/oi-k-array-set-new-effect-localization/binaryen.wat
wasm-opt .tmp/oi-k-array-set-new-effect-localization/input.wasm --enable-reference-types --enable-gc --optimize-instructions -o .tmp/oi-k-array-set-new-effect-localization/binaryen.wasm
wasm-tools validate --features gc,reference-types .tmp/oi-k-array-set-new-effect-localization/binaryen.wasm
wasm-opt .tmp/oi-k-array-set-new-effect-localization/input.wasm --enable-reference-types --enable-gc -O4 -Oz -S -o .tmp/oi-k-array-set-new-effect-localization/binaryen-O4z.wat
target/native/release/build/cmd/cmd.exe --optimize-instructions -o .tmp/oi-k-array-set-new-effect-localization/starshine.wasm .tmp/oi-k-array-set-new-effect-localization/input.wasm
wasm-tools print .tmp/oi-k-array-set-new-effect-localization/starshine.wasm > .tmp/oi-k-array-set-new-effect-localization/starshine.wat
wasm-tools validate --features gc,reference-types .tmp/oi-k-array-set-new-effect-localization/starshine.wasm
```

Results:

- `moon info`, `moon test`, native build, JSON validation, and `git diff --check` passed. `moon info` and native build reported existing unused/unreachable-code warnings.
- Direct `optimize-instructions` compare-pass `.tmp/pass-fuzz-optimize-instructions-oi-k-1434-10000` compared 10000/10000 with 10000 normalized matches, zero validation/property/generator/command failures, zero mismatches, and Binaryen cache 97 hits / 9903 misses.
- Direct Binaryen `--optimize-instructions` kept the six exported probe shapes unchanged.
- Binaryen `-O4 -Oz` localized the three `array.set` probes, in-bounds `array.get(array.new(...))`, and out-of-bounds `array.get(array.new(...))`; it still kept `array.len(array.new(call, i32.const 3))` unchanged.
- Starshine `--optimize-instructions` localized all six requested shapes, and the resulting wasm validated. The len case is therefore the only refreshed probe where Starshine intentionally goes beyond current Binaryen output; it is bounded to one-use `array.new`, small non-negative constant length, non-control single-result repeated value, exact once-only effect preservation as `drop(value)`, and the existing non-trapping length guard.

## Classification

OI-K remains active, but narrowed further. The source-backed effect-localization surfaces implemented here remove the primary local behavior gaps for fresh `array.set` values/siblings and `array.new` repeated-value get folds. The effectful `array.len(array.new(...))` fold is explicitly classified as a bounded Starshine cleanup extension, because refreshed Binaryen `-O4 -Oz` evidence still keeps that shape.

The row should not be marked fully closed until:

- effectful repeated-value `array.set` over `array.new` is source-backed and implemented, or explicitly recorded as a fail-closed/no-rewrite boundary with reopening criteria;
- the effectful `array.len(array.new(...))` cleanup extension is either accepted with measured Starshine-win rationale or realigned to Binaryen output;
- OI-K has a dedicated aggregate profile, or closure is explicitly documented as source/test-based rather than generator-backed.

OI-J and OI-L are unchanged and not closed by this slice.
