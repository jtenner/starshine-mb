# Optimize-instructions OI-K terminalization

Date: 2026-07-03

## Supersession

Implementation note `1436-2026-07-03-optimize-instructions-oi-k-array-new-set-effect-localization.md` implements the exact effectful repeated-value `array.set(array.new(...))` residual identified here. This note remains the source/probe terminalization record for the residual and the direct Binaryen vs `-O4 -Oz` nuance, but its active-residual classification is superseded by `1436`: OI-K can now move to accepted closeout / intentional-boundary status with only dedicated aggregate-profile coverage as tooling follow-up.

## Question

After `77f559f8e62f70f62265005eadfe41f5eca0a0b9` (`fix: localize OI-K array effects`) and `20045380115ebec32158c502a74ba5a8561605bb` (`docs: record OI-K effect localization evidence`), can OI-K move out of active mismatch/full-parity work, or does a precisely named residual remain?

## Inputs reviewed

- `docs/wiki/raw/research/1432-2026-07-03-optimize-instructions-oi-k-closeout.md`
- `docs/wiki/raw/research/1434-2026-07-03-optimize-instructions-oi-k-array-set-new-effect-localization.md`
- `docs/wiki/binaryen/passes/optimize-instructions/parity-matrix.json`
- `docs/wiki/binaryen/passes/optimize-instructions/index.md`
- `agent-todo.md`
- `src/passes/optimize_instructions.mbt`
- `src/passes/optimize_instructions_test.mbt`
- `src/passes/pass_manager.mbt`

## Current OI-K row before this terminalization

Before this update, `OI-K-gc-constructors-fields-arrays` was:

- `starshineStatus`: `mismatch`
- `priority`: `P2`
- `closeoutState`: `active-narrowed-tooling-and-boundary-review`
- `remainingCloseoutWork`: decide the effectful repeated-value `array.set(array.new(...))` residual, add a dedicated `pass-oi-gc-aggregate` profile if aggregate generator-backed closure is needed, and decide whether the effectful `array.len(array.new(...))` Starshine cleanup extension needs realignment or acceptance.
- `reopenCriteria`: validation/runtime failure, residual aggregate opcodes outside covered/bounded/quarantined buckets, effect/trap/order loss, signedness drift, dropped allocation traps, dynamic index speculation, size loss without documented win, and OI-J descriptor/exactness/TNH/IIT evidence.

That row still correctly said `77f559f8` implemented ordered-effect materialization for fresh `array.set` values/siblings and `array.new` repeated-value len/get surfaces. Its stale part was the implication that the len cleanup still needed an unresolved decision, and the lack of a local source probe for effectful repeated-value `array.set` over `array.new`.

## Source and implementation classification

`src/passes/optimize_instructions.mbt` confirms that `77f559f8` did **not** implement effectful repeated-value `array.set` over `array.new`: `optimize_instructions_try_remove_array_set_fresh_array` still returns `false` for `ArrayNew` when the repeated value is not effect-pure. `src/passes/optimize_instructions_test.mbt` locks that boundary in `optimize-instructions removes array.set to fresh pure array.new repeated-value arrays with constant indexes`: the `set_new_effect_value` case still expects `array.set`, `array.new`, and the effectful call to remain.

A fresh local probe in `.tmp/oi-k-terminalization-array-new-set-probe.wat` checked five shapes:

- in-bounds `array.set(array.new(call $effect, i32.const 2), i32.const 1, i32.const 9)`;
- out-of-bounds `array.set(array.new(call $effect, i32.const 2), i32.const 2, i32.const 9)`;
- `array.len(array.new(call $effect, i32.const 3))`;
- in-bounds `array.get(array.new(call $effect, i32.const 3), i32.const 1)`;
- out-of-bounds `array.get(array.new(call $effect, i32.const 3), i32.const 3)`.

Observed Binaryen behavior:

- direct `wasm-opt --all-features --optimize-instructions -S` keeps all five shapes unchanged;
- `wasm-opt --all-features -O4 -Oz -S` localizes both effectful repeated-value `array.set(array.new(...))` probes to a dropped effect, then either empty/nop-equivalent output for the in-bounds write or `unreachable` for the out-of-bounds write;
- `-O4 -Oz` still keeps `array.len(array.new(call, i32.const 3))` unchanged;
- `-O4 -Oz` localizes the in-bounds and out-of-bounds `array.get(array.new(call, const), const)` probes.

Therefore:

1. A true OI-K behavior residual remains, but it is a single exact residual: **effectful repeated-value `array.set` over a one-use `array.new(value, const-len)` with a constant index and locally non-trapping small non-negative length**. It should preserve the repeated value exactly once before `nop` or `unreachable`, preserve the set value after index evaluation, and fail closed for dynamic/negative/huge lengths, dynamic indexes, multi-use producers, control-shaped operands, multi-result operands, descriptor/exactness/TNH/IIT, and shared/atomic surfaces.
2. The old broader wording about effectful fresh `array.set` values/siblings is stale: `77f559f8` implemented those for `array.new_fixed`, `array.new_default`, and pure-repeated `array.new` producers.
3. `array.len(array.new(effectful, const))` is intentionally documented as a bounded Starshine cleanup extension, not direct Binaryen `--optimize-instructions` output parity and not Binaryen `-O4 -Oz` output parity. The extension is bounded to one-use `array.new`, small non-negative constant length, single-result non-control repeated value, exactly once effect preservation as `drop(value)`, and the existing allocation-trap length guard. Reopen on validation/runtime failure, effect loss/reorder, duplicated repeated value, dropped allocation trap, or size/performance evidence showing the cleanup is not a win.
4. The lack of a dedicated `pass-oi-gc-aggregate` generator is a tooling/coverage follow-up, not a behavior blocker by itself. The non-dedicated `pass-oi-ref-gc` evidence from `1432` remains only a cross-family quarantine/tooling limitation check and must not be used as OI-K aggregate coverage.
5. OI-K cannot move to `covered` or `intentional-boundary` yet without explicit acceptance of the exact effectful repeated-value `array.set` residual. It should remain `mismatch`/P2 with `closeoutState` narrowed to a single active residual plus tooling follow-up.

## Next implementation prompt if OI-K is reopened for behavior

Implement only this residual red-first:

> In `optimize_instructions_try_remove_array_set_fresh_array`, allow `ArrayNew` repeated values with effects when the producer is one-use, the length is a small non-negative constant accepted by `optimize_instructions_array_new_len_is_known_non_trapping`, and the set index is constant. Replace in-bounds writes with ordered dropped effects then `nop`/empty block, and out-of-bounds writes with ordered dropped effects then `unreachable`. Operand order is repeated value, length, index, set value. Preserve effectful repeated value and set value exactly once; skip pure operands; fail closed for control-shaped or multi-result operands, dynamic/negative/huge lengths, dynamic indexes, multi-use producers, OI-J descriptor/exactness/TNH/IIT, and OI-L shared/atomic surfaces.

## Dedicated generator follow-up

A future `pass-oi-gc-aggregate` profile would improve coverage but should not block this terminalization. It should sample pure/default `struct.get(struct.new/default(...))`, effectful non-selected `struct.new` fields, pure/effectful `array.get(array.new_fixed(...))`, pure/effectful fresh `array.set`, repeated-value `array.new` len/get/set surfaces, and dynamic/negative/huge length fail-closed cases. Descriptor and shared/atomic surfaces should only appear as quarantined/no-claim labels unless OI-J/OI-L explicitly own them.

## Reopening criteria

Keep or reopen OI-K only for:

- validation failure or runtime semantic mismatch;
- lost or reordered effectful aggregate operands;
- duplicated repeated values;
- dropped allocation or bounds traps;
- packed signedness or masking drift;
- dynamic index or dynamic/negative/huge length speculation;
- a new dedicated aggregate-profile `struct.*` / `array.*` residual outside the covered, bounded, or quarantined buckets;
- descriptor/exactness/TNH/IIT evidence, which belongs to OI-J;
- shared/atomic evidence, which belongs to OI-L.

## Validation status

Commands run in this terminalization slice:

```sh
wasm-tools parse .tmp/oi-k-terminalization-array-new-set-probe.wat -o .tmp/oi-k-terminalization-array-new-set-probe/input.wasm
wasm-tools validate --features all .tmp/oi-k-terminalization-array-new-set-probe/input.wasm
wasm-opt .tmp/oi-k-terminalization-array-new-set-probe/input.wasm --all-features --optimize-instructions -S -o .tmp/oi-k-terminalization-array-new-set-probe/binaryen-direct.wat
wasm-opt .tmp/oi-k-terminalization-array-new-set-probe/input.wasm --all-features -O4 -Oz -S -o .tmp/oi-k-terminalization-array-new-set-probe/binaryen-O4z.wat
target/native/release/build/cmd/cmd.exe --optimize-instructions -o .tmp/oi-k-terminalization-array-new-set-probe/starshine.wasm .tmp/oi-k-terminalization-array-new-set-probe/input.wasm
wasm-tools validate --features all .tmp/oi-k-terminalization-array-new-set-probe/starshine.wasm
wasm-tools print .tmp/oi-k-terminalization-array-new-set-probe/starshine.wasm > .tmp/oi-k-terminalization-array-new-set-probe/starshine.wat
moon fmt
python3 -m json.tool docs/wiki/binaryen/passes/optimize-instructions/parity-matrix.json >/tmp/parity-matrix.json.check
moon info
moon test --package jtenner/starshine/passes --file optimize_instructions_test.mbt --filter '*array.set*'
moon test --package jtenner/starshine/passes --file optimize_instructions_test.mbt --filter '*array.new*'
moon test --package jtenner/starshine/passes --file optimize_instructions_test.mbt --filter '*array.get*'
moon test --package jtenner/starshine/passes --file optimize_instructions_test.mbt --filter '*struct*'
moon test --package jtenner/starshine/passes --file optimize_instructions_test.mbt --filter '*optimize-instructions*'
moon test
moon build --target native --release src/cmd
git diff --check
git diff --cached --check
bun scripts/pass-fuzz-compare.ts --pass optimize-instructions --count 10000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe --out-dir .tmp/pass-fuzz-optimize-instructions-oi-k-terminal-10000
```

Results:

- probe input and Starshine output validated with `wasm-tools validate --features all`;
- direct Binaryen kept the effectful repeated-value `array.set`, len, and get shapes unchanged;
- Binaryen `-O4 -Oz` localized both effectful repeated-value `array.set` probes and both get probes, while keeping effectful len;
- Starshine localized effectful len/get but kept both effectful repeated-value `array.set` probes fail-closed;
- `moon fmt`, JSON validation, focused OI-K filters, full `moon test`, native build, and diff checks passed;
- `moon info` passed with existing warnings;
- direct `pass-fuzz-compare` terminal lane compared `10000/10000`, with `10000` normalized matches, zero validation/property/generator/command failures, zero mismatches, Binaryen cache `10000/0`, and wasm-smith cache `0/0`.

No optimizer behavior changed in this terminalization slice.
