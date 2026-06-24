# 0839 - optimize-instructions OI-D absorbing binary operand folding

## Scope

Extend the OI-D binary-operand surface (after `0838` identity folding and the div/rem/rot identity slice) with zero-absorbing folds from Binaryen's `visitBinary` "operations on zero/one" block:

- `mul(pure(x), 0)` and `mul(0, pure(x))` -> `0` (i32 and i64);
- `and(pure(x), 0)` and `and(0, pure(x))` -> `0` (i32 and i64);
- `rem_s(pure(x), -1)` -> `0` (i32 and i64).

Each fold requires the non-constant operand to be side-effect-free (`optimize_instructions_is_side_effect_free_expr`). Folding to a plain constant would drop a non-pure lhs/rhs effect, so effectful forms are kept (`mul(effect, 0)`, `and(effect, 0)`, `rem_s(effect, -1)`).

`rem_s(effect, 1) -> 0` identity folding and `eq(x, 0) -> eqz x` compare rewriting are already covered elsewhere. `eq` is out of scope here.

## Binaryen oracle

Probe file: `.tmp/oi-d-absorbing-binary-probe.wat`.

Command:

```sh
wasm-opt .tmp/oi-d-absorbing-binary-probe.wat -S --optimize-instructions -o -
```

Observed Binaryen `version_130` behavior:

- every probed pure absorbing form in `$folds` becomes `i32.const 0` / `i64.const 0`;
- `mul(effect, 0)` and `rem_s(effect, -1)` are kept verbatim;
- `and(effect, 0)` becomes `(drop (call $effect)) (i32.const 0)` — Binaryen preserves the effect via drop while still absorbing to zero. Starshine keeps the unsimplified `i32.and` when the lhs is effectful (purity-guard parity on the listed pure forms only).

## Starshine change

`src/passes/optimize_instructions.mbt` adds:

- `optimize_instructions_try_fold_absorbing_zero_i32` / `_i64` for symmetric `mul`/`and` with a `0` operand;
- `optimize_instructions_try_fold_absorbing_binary`, wired immediately after `optimize_instructions_try_fold_identity_binary` in the `Binary` visitor.

Pure operands fold to a plain `i32.const 0` / `i64.const 0`. The effectful `and` drop-then-const shape remains an open parity follow-up if we decide to match Binaryen's effect-preserving spelling.

## Tests and validation

Red-first evidence:

```sh
moon test --target native src/passes/optimize_instructions_test.mbt --filter '*folds absorbing binary operands*'
```

Before implementation the focused filter failed because every covered binop remained in `$id`. After implementation it passed `1/1`, including effectful negatives for `mul`, `and`, and `rem_s`.

Final validation for this slice:

- Binaryen oracle command above folded every pure absorbing form and kept `mul(effect, 0)` / `rem_s(effect, -1)`.
- `*folds absorbing binary operands*` failed before implementation and passed `1/1` after.
- `*optimize-instructions*` passed `226/226`.
- `moon fmt` passed.
- `moon test src/passes` passed `2756/2756`.
- `moon build --target native --release src/cmd` passed with existing unused-function warnings.
- Direct compare smoke `bun scripts/pass-fuzz-compare.ts --pass optimize-instructions --count 1 --seed 0x5eed --out-dir .tmp/pass-fuzz-optimize-instructions-oi-d-absorbing-1 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe` compared `1/1`, with normalized matches `0`, compare-normalized matches `0`, raw mismatches `1`, validation/property/generator/command failures `0`, cache counters wasm-smith `0` hits / `0` misses, Binaryen `1` hit / `0` misses, Binaryen failures `0` hits / `0` misses. Agent classification: the single raw mismatch is an unrelated known scalar output-shape family, not introduced by this slice.

## Boundaries

- Only the listed zero-absorbing forms; no general algebraic simplification.
- Effectful `and(x, 0)` drop-then-const spelling is not implemented (Binaryen diverges from the keep-op policy used for effectful `mul`/`rem_s`).
- `rem_u` with `-1`, float absorbing identities, and broader strength-reduction remain open.
- This extends the OI-D surface and does not reopen `[O4Z-AUDIT-OI-D]` as a release blocker.
