# 0838 - optimize-instructions OI-D identity binary operand folding

## Scope

Extend the completed `[O4Z-AUDIT-OI-D]` default-scalar surface with identity binary-operand folding: when a constant operand makes a binary op a no-op, replace the op with the other operand. This was surfaced while probing OI-G store-value shapes (`i32.store(0, i32.or(x, 0))`), but the fold itself is general scalar algebra and applies everywhere, so it extends OI-D rather than OI-G.

This slice covers, for both `i32` and `i64`:

- `or` with `0` -> other operand;
- `and` with `-1` (all ones) -> other operand;
- `xor` with `0` -> other operand;
- `mul` with `1` -> other operand;
- `shl` / `shr_u` / `shr_s` with `0` -> other operand;
- `add` with `0` -> other operand;
- `sub` with a `0` right operand -> left operand.

The identity constant may appear on either side for the symmetric cases (`or`/`and`/`xor`/`mul`/`shl`/`shr`/`add`). `sub` is asymmetric: `sub(0, x)` is `-x` and is intentionally kept.

`div`/`rem`/`rotl`/`rotr` identities and float identities are not covered here.

## Binaryen oracle

Probe files: `.tmp/oi-g-identity-binary-probe.wat` and `.tmp/oi-g-add-sub-xor-probe.wat`.

Commands:

```sh
wasm-opt .tmp/oi-g-identity-binary-probe.wat -S --optimize-instructions -o -
wasm-opt .tmp/oi-g-add-sub-xor-probe.wat -S --optimize-instructions -o -
```

Observed Binaryen `version_130` behavior: the direct `--optimize-instructions` lane folds every probed standalone identity (`or(x,0)`, `and(x,-1)`, `xor(x,0)`, `mul(x,1)`, `shl(x,0)`, `shr_u(x,0)`, `shr_s(x,0)`, `add(x,0)`, `sub(x,0)`, and the `i64` analogues) to just the operand, and keeps `sub(0, x)` verbatim. This is OI-owned (the direct lane performs it).

## Starshine change

`src/passes/optimize_instructions.mbt` adds:

- `optimize_instructions_i32_identity_operand` / `optimize_instructions_i64_identity_operand`, which return the non-identity operand id when one side is the given identity constant;
- `optimize_instructions_try_fold_identity_binary`, which maps each covered instruction to its identity constant (symmetric cases check both sides; `sub` checks only the right operand) and replaces the binary node with the kept operand.

The helper is wired as the first check in the `Binary` visitor arm, ahead of `canonicalize_signed_const_unsigned`, `fold_exact_const_binary`, and the add/sub/mul/shift rewriters, so an identity fold wins over e.g. the `mul(x, 1) -> shl(x, 0)` strength-reduction path (which previously left a `shl(x, 0)` that nothing folded).

## Tests and validation

Red-first evidence:

```sh
moon test --target native src/passes/optimize_instructions_test.mbt --filter '*folds identity binary operands*'
```

Before implementation this failed because the optimized `i32.or` (and every other covered op) was still present. After implementation the focused filter passed `1/1`, including the `sub(0, x)` boundary that must be kept.

A diagnostic before implementation also showed `i32.mul(x, 1)` being rewritten to `i32.shl(x, 0)` and then left unfolded; the new identity folder resolves that cascade directly.

Final validation for this slice:

- Binaryen oracle commands above folded every standalone identity and kept `sub(0, x)`.
- `*folds identity binary operands*' failed before implementation and passed `1/1` after.
- `*optimize-instructions*' passed `224/224`.
- `moon fmt` passed.
- `moon test src/passes` passed `2754/2754`.
- `moon build --target native --release src/cmd` passed with existing unused-function warnings.
- `moon info` passed with existing warnings in `src/validate/gen_valid.mbt` and `src/validate/gen_valid_ssa.mbt`.
- `git diff --check && git diff --cached --check` passed.
- Direct compare smoke `bun scripts/pass-fuzz-compare.ts --pass optimize-instructions --count 1 --seed 0x5eed --out-dir .tmp/pass-fuzz-optimize-instructions-oi-g-identity-1 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe` compared `1/1`, with normalized matches `0`, compare-normalized matches `0`, raw mismatches `1`, validation/property/generator/command failures `0`, cache counters wasm-smith `0` hits / `0` misses, Binaryen `1` hit / `0` misses, Binaryen failures `0` hits / `0` misses. Agent classification: the single raw mismatch was the known scalar output-shape family and was unrelated to this slice. The wasm-smith input contained 48 of the covered binops; both Starshine and Binaryen outputs reduced that to the same 33, confirming identity-fold parity on the case (no identity op remained unfolded on either side).

## Boundaries

- This is not general algebraic simplification. It covers only the listed no-op identity operands.
- `sub(0, x)` is kept (it is `-x`).
- `div`/`rem`/`rotl`/`rotr` identities, float identities, and broader strength-reduction remain open.
- This extends the completed `[O4Z-AUDIT-OI-D]` default-scalar surface; it does not reopen OI-D as a release blocker.
