# Optimize-instructions OI-J exact ref.cast boundary

_Date:_ 2026-06-20
_Status:_ completed implementation/boundary sub-slice for `[O4Z-AUDIT-OI-J]`

## Question

Does Binaryen `version_130` `optimize-instructions` remove `ref.cast (ref (exact $foo))` when the operand static type is the inexact same heap, such as `(ref $foo)` or `(ref null $foo)`?

This belongs to `[O4Z-AUDIT-OI-J]` rather than the earlier `[O4Z-AUDIT-OI-I]` basics because exact casts are descriptor/type-information-sensitive. An inexact heap-typed local can hold subtype instances at runtime, so removing an exact cast may drop a required exactness check and can produce an inexact value where an exact result type is required.

## Binaryen oracle

Probe: `.tmp/oi-j-exact-cast-probe.wat`

Command:

```sh
wasm-opt .tmp/oi-j-exact-cast-probe.wat --enable-gc --enable-reference-types --enable-custom-descriptors -S -O --optimize-instructions -o -
```

Result: Binaryen `version_130` kept both exact casts:

- non-null `(ref $foo)` to `(ref (exact $foo))` stayed as `ref.cast (ref (exact $foo))`;
- nullable `(ref null $foo)` to non-null `(ref (exact $foo))` also stayed as `ref.cast (ref (exact $foo))`.

A probe without `--enable-custom-descriptors` failed validation because exact `ref.cast` requires custom descriptors in the local Binaryen oracle.

## Starshine change

Before this slice, Starshine's `ref.cast` simplifier ignored the exact bit in `Instruction::RefCast(nullable, exact, target)`. It therefore treated an inexact same-heap local as a known match for an exact target, removed the `ref.cast`, and produced an invalid module for an exact result type.

This slice adds an exactness guard to `optimize_instructions_try_fold_ref_cast_null(...)`:

- ordinary non-exact casts keep the existing same-heap and supertype simplifications;
- exact target casts may be removed or converted to `ref.as_non_null` only when the operand result type is itself exact on the same heap;
- known-null exact casts still use the existing null/unreachable behavior because null success/trap does not depend on a subtype descriptor.

The new public-pipeline/direct-core test `optimize-instructions intentionally keeps exact ref.cast on inexact locals` locks the Binaryen boundary and the validity bug fix.

## Evidence

- Red-first focused test: `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*exact ref.cast*'` failed before implementation because the optimized module validation reported `function body result type mismatch: expected ... Exact ... actual ... inexact` after the cast was removed.
- After implementation, `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*exact ref.cast*'` passed `1/1`.
- `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*ref.cast*'` passed `31/31`.
- `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*ref*'` passed `67/67`.
- `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*optimize-instructions*'` passed `200/200`.
- `moon fmt` passed.
- `moon test src/passes` passed `2730/2730`.
- `moon build --target native --release src/cmd` passed with existing unused-function warnings in `src/passes/pass_manager.mbt`.
- `moon info` passed with existing warnings in `src/validate/gen_valid.mbt` and `src/validate/gen_valid_ssa.mbt`.
- Direct compare smoke:
  - `rm -rf .tmp/pass-fuzz-optimize-instructions-oi-j-exact-cast-boundary-1 && bun scripts/pass-fuzz-compare.ts --pass optimize-instructions --count 1 --seed 0x5eed --out-dir .tmp/pass-fuzz-optimize-instructions-oi-j-exact-cast-boundary-1 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe`
  - requested `1`, compared `1/1`, normalized matches `0`, compare-normalized matches `0`, raw mismatches `1`, validation/property/generator/command failures `0`.
  - cache: wasm-smith `0` hits / `0` misses; Binaryen `1` hit / `0` misses; Binaryen failures `0` hits / `0` misses.
  - Agent classification: known scalar/default output-shape raw mismatch family from earlier OI slices. Grepping the failure artifacts found no `ref.cast`, `ref.test`, `ref.eq`, `ref.is_null`, `ref.as_non_null`, `call_ref`, or `return_call_ref`, so the smoke did not exercise this exact-cast boundary.

## Remaining work

This closes only the first `[O4Z-AUDIT-OI-J]` exactness sub-slice. Descriptor casts, exact casts with already-exact operands, TNH/IIT-only removals, success-only-if-null/non-null cases, useful-type-info preservation, and custom-descriptor mode boundaries remain open. The broader `[O4Z-AUDIT-OI-G]`, `[O4Z-AUDIT-OI-H]`, `[O4Z-AUDIT-OI-I]`, `[O4Z-AUDIT-OI-J]`, and later slices are not complete.
