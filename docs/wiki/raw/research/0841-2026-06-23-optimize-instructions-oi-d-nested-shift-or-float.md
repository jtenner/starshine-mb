# 0841 - optimize-instructions OI-D nested shifts, or(-1), and float negation spellings

## Scope

Continue the OI-D scalar HOT algebra slice after unsigned div/rem power-of-two lowering (`0840`):

1. nested constant shift/rotate cleanup;
2. `or(x, -1) → -1` absorbing (oracle-first);
3. safe float negation / divide-by-one spelling rewrites without fast-math.

Explicit non-goals for this slice: signed `div_s`/`rem_s` power-of-two, `maxBits` proofs, boolean shells, memory/GC/ref work, float `add`/`mul` identity folding with `0`/`1`, and power-of-two float divide → multiply-by-inverse.

## Binaryen oracle

Probe files:

- `.tmp/oi-d-nested-shift-probe.wat`
- `.tmp/oi-d-or-absorb-probe.wat`
- `.tmp/oi-d-float-identity-probe.wat`

```sh
wasm-opt -S --optimize-instructions .tmp/oi-d-nested-shift-probe.wat -o -
wasm-opt -S --optimize-instructions .tmp/oi-d-or-absorb-probe.wat -o -
wasm-opt -S --optimize-instructions .tmp/oi-d-float-identity-probe.wat -o -
```

Observed Binaryen `version_130` behavior:

- same-op nested constant `shl`/`shr_u`/`shr_s`/`rotl` combine amounts with width masking (`(x << 3) << 5` → `x << 8`; `3 + 28` → `31` for i32);
- masked outer amounts such as `5 & 31` combine with inner constant shifts;
- mixed `shl` then `shr_u` stay as two ops (no full cancel in the probe);
- `or(x, -1)` and `or(-1, x)` fold to `i32.const -1` / `i64.const -1`, preserving effectful operands via `drop`;
- float `add`/`mul` with `0`/`1` are kept;
- `f32.sub x 0` becomes `f32.add x (-0)`;
- `f32.mul x -1` / `f32.div x -1` become `f32.sub (-0) x`;
- `f32.div x 1` becomes `f32.mul x 1` (not an identity fold to `x`).

## Starshine change

`src/passes/optimize_instructions.mbt`:

- `optimize_instructions_shift_rhs_i32_amount` / `_i64_amount` extract effective constant shift amounts, including `amount & mask`;
- `optimize_instructions_try_combine_nested_const_shift` combines same-op nested constant shifts/rotates for i32 and i64;
- `optimize_instructions_try_fold_absorbing_neg_one_or_i32` / `_i64` fold `or` with an all-ones constant, using `replace_with_drop_then_const_*` when the other operand is effectful;
- `optimize_instructions_try_rewrite_float_binary` extends the existing float spelling rewrites with mul/div-by-`-1` → `sub (-0, x)` and div-by-`1` → `mul 1`;
- post-commutative canonicalization now re-runs identity/absorbing folds so `or(-1, effect)` folds after operand reordering.

`optimize_instructions_try_rewrite_shift` already handled direct/masked rhs cleanup and effective-zero shifts; this slice adds nested constant combining on top of that surface.

## Tests and validation

Red-first evidence:

```sh
moon test --target native src/passes/optimize_instructions_test.mbt \
  --filter '*combines nested constant shifts*|*or with all-ones*|*canonicalizes default scalar float*'
```

Final validation for this slice:

- Binaryen oracle commands above matched every implemented family and documented the float identity boundaries.
- `optimize-instructions` focused file passed `231/231`.
- `moon fmt` and `moon info` passed.
- native `src/cmd` release build passed.
- direct count-1 compare smoke in `.tmp/pass-fuzz-optimize-instructions-oi-d-nested-shift-smoke` compared `1/1` with `1` raw mismatch (unrelated scalar family; no validation/tool failures).

## Boundaries

- nested combine is limited to same-op constant shift/rotate chains; mixed `shl`/`shr` cancel families remain open;
- float `add`/`sub`/`mul` with `0`/`1` are intentionally not identity-folded to match Binaryen without fast-math;
- signed-zero / fast-math-sensitive float identity work stays deferred;
- power-of-two float divide → multiply-by-inverse remains a separate sub-slice;
- pipeline public-pretty coverage for effectful `or(-1, call)` is on the HOT IR path; commutative reorder + absorbing re-run covers the oracle shape.
