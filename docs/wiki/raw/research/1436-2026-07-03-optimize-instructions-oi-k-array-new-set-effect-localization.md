# Optimize-instructions OI-K array.new repeated-value set effect localization

Date: 2026-07-03

## Scope

This slice implements the final known OI-K behavior residual named by `1435`:

- `array.set(array.new(repeated_value, const_len), const_index, set_value)`;
- direct one-use fresh `array.new` producer with matching `array.set` type;
- small non-negative constant length accepted by the existing local non-trapping allocation guard;
- constant index;
- single-result, non-control repeated and set operands that can be materialized as ordered dropped effects.

Still out of scope:

- descriptor arrays and descriptor fields;
- OI-J exactness/TNH/IIT behavior;
- OI-L shared/atomic/RMW/cmpxchg behavior;
- dynamic index or dynamic length speculation;
- negative or huge length folding;
- multi-use aggregate producer scalarization;
- broad `array.fill` / `array.copy` rewrites;
- control-shaped or multi-result repeated/set operands.

## Binaryen probe classification

Focused probe: `.tmp/oi-k-array-new-set-effectful-repeated-value-probe.wat`.

The probe covers six shapes:

1. in-bounds effectful repeated value;
2. in-bounds effectful set value;
3. in-bounds both effectful;
4. out-of-bounds effectful repeated value;
5. out-of-bounds effectful set value;
6. out-of-bounds both effectful.

Observed local Binaryen behavior remains the same as `1435`:

- direct `wasm-opt --enable-gc --enable-reference-types --optimize-instructions` keeps all six `array.new` / `array.set` shapes;
- `wasm-opt --enable-gc --enable-reference-types -O4 -Oz` removes all six fresh arrays and sets, preserving effectful operands as `drop(call)` in source order and ending out-of-bounds cases with `unreachable`.

Therefore this Starshine rewrite is an O4z-surface cleanup/implementation choice for the OI-K audit, not direct Binaryen `--optimize-instructions` output parity. The already-documented `array.len(array.new(effectful,const))` rewrite remains a bounded Starshine cleanup extension and is not changed by this slice.

## Starshine change

`src/passes/optimize_instructions.mbt` extends `optimize_instructions_try_remove_array_set_fresh_array` for the `ArrayNew` producer arm. The arm now reuses the ordered-effect materialization helper instead of fail-closing when the repeated value has effects.

The rewrite requires:

- `array.set` with exactly three operands;
- direct one-use `array.new` producer;
- matching `array.new` / `array.set` type;
- `i32.const` set index;
- `i32.const` length accepted by `optimize_instructions_array_new_len_is_known_non_trapping`;
- repeated value, length, index, and set value all accepted by `optimize_instructions_append_ordered_effects`.

Effects are materialized in source order: repeated value, length, index, set value. Pure operands are skipped. Single-result effectful operands become `drop(operand)`. Zero-result effectful operands are emitted directly. Control-shaped and multi-result operands fail closed.

For in-bounds indexes the replacement is ordered effects followed by `nop` / a void block. For out-of-bounds indexes the replacement is ordered effects followed by `unreachable`. This preserves the allocation-trap boundary because the rewrite only runs for locally non-trapping constant lengths.

`src/passes/pass_manager.mbt` also widens the existing narrow GC effect-localization raw-gate escape for flat `array.set(array.new(...))` stack shapes. The escape now admits a no-param one-result call as the repeated value as well as the set value, while still requiring the exact flat `array.new`, constant length, constant index, matching `array.set` shape.

## Focused tests

`src/passes/optimize_instructions_test.mbt` updates the repeated-value `array.new` fresh-set test and adds boundary coverage:

Positive coverage:

- in-bounds pure `array.set(array.new(7, 2), 1, 9)` remains `nop`/empty;
- pure out-of-bounds remains `unreachable`;
- in-bounds effectful set value is dropped exactly once;
- in-bounds effectful repeated value is dropped exactly once;
- in-bounds repeated value and set value are dropped in source order;
- out-of-bounds effectful repeated value is dropped before `unreachable`;
- out-of-bounds effectful set value is dropped before `unreachable`;
- out-of-bounds repeated value and set value are dropped in source order before `unreachable`.

Fail-closed coverage:

- dynamic length;
- negative length;
- huge non-negative length;
- dynamic index;
- multi-use producer;
- control-shaped repeated value;
- control-shaped set value;
- multi-result repeated value;
- multi-result set value.

Descriptor and shared/atomic surfaces remain quarantined by type/syntax ownership rather than widened in this slice.

## Classification

After this change, the exact OI-K behavior residual named by `1435` is implemented. OI-K can move out of active `mismatch` classification into an accepted closeout / intentional-boundary state, with one remaining tooling follow-up: a dedicated `pass-oi-gc-aggregate` generator profile if generator-backed aggregate coverage is needed.

Covered OI-K surfaces now include:

- pure/default constructor/get/set subsets;
- effectful selected and non-selected struct/array get forwarding in the implemented plain/single-result subsets;
- effectful fresh `array.set` localization for `array.new_fixed`, `array.new_default`, pure-repeated `array.new`, and now effectful repeated-value `array.new` producers;
- effectful repeated-value `array.new` len/get cleanup extension surfaces already documented by `1434` / `1435`.

Accepted boundaries remain:

- direct Binaryen `--optimize-instructions` vs `-O4 -Oz` nuance for these array.set shapes;
- `array.len(array.new(effectful,const))` as a bounded Starshine cleanup extension, not direct Binaryen output parity;
- `array.fill` / `array.copy` as Binaryen no-rewrite boundaries;
- dynamic/negative/huge length and dynamic-index fail-closed cases;
- control-shaped, multi-result, and multi-use producer fail-closed cases;
- OI-J descriptor/exactness/TNH/IIT quarantine;
- OI-L shared/atomic/RMW/cmpxchg quarantine.

## Validation status

Commands run before this note was written:

```sh
moon test --package jtenner/starshine/passes --file optimize_instructions_test.mbt --filter '*array.set*'
moon test --package jtenner/starshine/passes --file optimize_instructions_test.mbt --filter '*array.new*'
wasm-tools parse .tmp/oi-k-array-new-set-effectful-repeated-value-probe.wat -o .tmp/oi-k-array-new-set-effectful-repeated-value-probe/input.wasm
wasm-tools validate --features gc,reference-types .tmp/oi-k-array-new-set-effectful-repeated-value-probe/input.wasm
wasm-opt .tmp/oi-k-array-new-set-effectful-repeated-value-probe/input.wasm --enable-gc --enable-reference-types --optimize-instructions -S -o .tmp/oi-k-array-new-set-effectful-repeated-value-probe/binaryen-direct.wat
wasm-opt .tmp/oi-k-array-new-set-effectful-repeated-value-probe/input.wasm --enable-gc --enable-reference-types --optimize-instructions -o .tmp/oi-k-array-new-set-effectful-repeated-value-probe/binaryen-direct.wasm
wasm-tools validate --features gc,reference-types .tmp/oi-k-array-new-set-effectful-repeated-value-probe/binaryen-direct.wasm
wasm-opt .tmp/oi-k-array-new-set-effectful-repeated-value-probe/input.wasm --enable-gc --enable-reference-types -O4 -Oz -S -o .tmp/oi-k-array-new-set-effectful-repeated-value-probe/binaryen-O4z.wat
wasm-opt .tmp/oi-k-array-new-set-effectful-repeated-value-probe/input.wasm --enable-gc --enable-reference-types -O4 -Oz -o .tmp/oi-k-array-new-set-effectful-repeated-value-probe/binaryen-O4z.wasm
wasm-tools validate --features gc,reference-types .tmp/oi-k-array-new-set-effectful-repeated-value-probe/binaryen-O4z.wasm
moon build --target native --release src/cmd
target/native/release/build/cmd/cmd.exe --optimize-instructions -o .tmp/oi-k-array-new-set-effectful-repeated-value-probe/starshine.wasm .tmp/oi-k-array-new-set-effectful-repeated-value-probe/input.wasm
wasm-tools validate --features gc,reference-types .tmp/oi-k-array-new-set-effectful-repeated-value-probe/starshine.wasm
wasm-tools print .tmp/oi-k-array-new-set-effectful-repeated-value-probe/starshine.wasm > .tmp/oi-k-array-new-set-effectful-repeated-value-probe/starshine.wat
```

Results so far:

- focused `*array.set*` passed `3/3`;
- focused `*array.new*` passed `11/11`;
- probe input, Binaryen direct wasm, Binaryen `-O4 -Oz` wasm, and Starshine wasm validate with `wasm-tools validate --features gc,reference-types`;
- direct Binaryen output has six `array.set` and six `array.new` occurrences;
- Binaryen `-O4 -Oz` output has zero `array.set` and zero `array.new` occurrences;
- Starshine output has zero `array.set` and zero `array.new` occurrences and preserves the same dropped-call / `unreachable` order as the O4z probe.

Full requested signoff completed after implementation:

```sh
moon fmt
python3 -m json.tool docs/wiki/binaryen/passes/optimize-instructions/parity-matrix.json >/tmp/parity-matrix.json.check
moon info
moon test --package jtenner/starshine/passes --file optimize_instructions_test.mbt --filter '*array.set*'
moon test --package jtenner/starshine/passes --file optimize_instructions_test.mbt --filter '*array.new*'
moon test --package jtenner/starshine/passes --file optimize_instructions_test.mbt --filter '*optimize-instructions*'
moon test src/passes
moon test
moon build --target native --release src/cmd
git diff --check
git diff --cached --check
bun scripts/pass-fuzz-compare.ts --pass optimize-instructions --count 10000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe --out-dir .tmp/pass-fuzz-optimize-instructions-oi-k-array-new-set-effectful-10000
wasm-tools validate --features gc,reference-types .tmp/oi-k-array-new-set-effectful-repeated-value-probe/input.wasm
wasm-tools validate --features gc,reference-types .tmp/oi-k-array-new-set-effectful-repeated-value-probe/binaryen-direct.wasm
wasm-tools validate --features gc,reference-types .tmp/oi-k-array-new-set-effectful-repeated-value-probe/binaryen-O4z.wasm
wasm-tools validate --features gc,reference-types .tmp/oi-k-array-new-set-effectful-repeated-value-probe/starshine.wasm
```

Final results:

- `moon fmt`, JSON validation, `moon info`, focused tests, full pass tests, full `moon test`, native build, and diff checks passed. `moon info` / native build reported existing warnings.
- Focused test counts: `*array.set*` passed `3/3`; `*array.new*` passed `11/11`; `*optimize-instructions*` passed `656/656`; `moon test src/passes` passed `3924/3924`; full `moon test` passed `7327/7327`.
- Direct compare lane `.tmp/pass-fuzz-optimize-instructions-oi-k-array-new-set-effectful-10000` compared `10000/10000`, with `10000` normalized matches, `0` cleanup-normalized matches, `0` raw mismatches, `0` validation failures, `0` property failures, `0` generator failures, and `0` command failures. Cache counters: wasm-smith `0/0`, Binaryen `10000/0`, Binaryen failures `0/0`.
- Probe input, direct Binaryen output wasm, Binaryen `-O4 -Oz` output wasm, and Starshine output wasm all validate with `wasm-tools validate --features gc,reference-types`.
