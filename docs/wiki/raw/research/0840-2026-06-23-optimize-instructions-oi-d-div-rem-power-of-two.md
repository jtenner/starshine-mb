# 0840 - optimize-instructions OI-D unsigned div/rem power-of-two lowering

## Scope

Reopen the OI-D scalar algebra surface for the natural complement to multiply-by-power-of-two → `shl`: unsigned divide/remainder by a constant power of two.

This slice covers, for constant right operands only:

- `i32.div_u` / `i64.div_u` by a positive power of two → `shr_u` with `log2(C)`;
- `i32.rem_u` / `i64.rem_u` by a positive power of two → `and` with `C-1`.

Signed `div_s` / `rem_s`, non-power-of-two divisors, and leading-constant `div_u` shapes are unchanged.

## Binaryen oracle

Probe file: `.tmp/oi-d-div-rem-power-of-two-probe.wat`.

```sh
wasm-opt .tmp/oi-d-div-rem-power-of-two-probe.wat -S --optimize-instructions -o -
```

Observed Binaryen `version_130` behavior:

- `div_u(x, 8)` → `shr_u(x, 3)`;
- `rem_u(x, 8)` → `and(x, 7)`;
- `div_u(4, x)` stays `div_u`;
- `div_u(x, 6)` stays `div_u`;
- `div_s(x, 8)` / `rem_s(x, 8)` stay signed ops;
- `i64` analogues match (`16` → shift `4`, mask `15`).

## Starshine change

`src/passes/optimize_instructions.mbt` adds `optimize_instructions_try_rewrite_div_rem_power_of_two`, reusing `optimize_instructions_i32_power_of_two_shift` / `optimize_instructions_i64_power_of_two_shift` from the existing mul→shl path. The helper is wired after `try_rewrite_mul_shift` in both binary rewrite passes (initial and post-commutative canonicalization).

Interaction with identity folding:

- `div_u(x, 1)` is still handled by the existing identity folder (`div` by `1` → `x`);
- `rem_u(x, 1)` with a side-effect-free lhs is still folded to `0` by identity folding;
- `rem_u(x, 1)` with an effectful lhs can fall through to `and(x, 0)`, preserving lhs evaluation.

## Tests and validation

Red-first evidence:

```sh
moon test --target native src/passes/optimize_instructions_test.mbt --filter '*unsigned div and rem by a power of two*'
```

Final validation for this slice:

- Binaryen oracle command above matched every probed rewrite and boundary.
- `*unsigned div and rem by a power of two*` passed `1/1`.
- `*optimize-instructions*` passed `227/227`.
- `moon fmt` passed.
- `moon test src/passes` passed `2757/2757`.

## Boundaries

- Unsigned power-of-two divisors only; signed and arbitrary divisors remain open.
- Nested shift/rotate cleanup, `or(x, -1) → -1` absorbing, and float zero/one families remain later OI-D candidates except where covered by `0841` (nested constant combine, `or(-1)`, float negation spellings).
- This extends the OI-D scalar surface; it does not reopen OI-D as a release blocker.
