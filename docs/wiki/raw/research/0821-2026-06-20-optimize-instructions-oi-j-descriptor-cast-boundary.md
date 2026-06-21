# Optimize-instructions OI-J descriptor cast boundary

_Date:_ 2026-06-20

## Question

Does Binaryen `version_130` `optimize-instructions` remove descriptor equality casts when the operand and target are already the same descriptor-bearing heap type?

This belongs to `[O4Z-AUDIT-OI-J]` because descriptor casts are metadata-sensitive: even when the ordinary heap spelling looks redundant, the explicit descriptor operand participates in the runtime equality check.

## Binaryen oracle

Probe: `.tmp/oi-j-desc-cast-boundary-probe.wat`

Command:

```sh
wasm-opt .tmp/oi-j-desc-cast-boundary-probe.wat --enable-gc --enable-reference-types --enable-custom-descriptors -S -O --optimize-instructions -o -
```

The probe used a descriptor-bearing struct type `$a` with descriptor type `$b`, then exported nullable and non-null functions that apply official two-operand `ref.cast_desc_eq` to `(ref null $a)` / `(ref null $b)` and `(ref $a)` / `(ref $b)` operands. Binaryen kept both `ref.cast_desc_eq` operations unchanged.

## Starshine boundary

Starshine's current HOT lift still treats `RefCastDescEq` as a unary HOT op, matching the older local descriptor-cast surface rather than the official two-operand custom-descriptor binary/text surface. A direct public-pipeline test for the official two-operand shape fails during local HOT lifting after the descriptor operand is not preserved as a child, so this slice does not implement official descriptor-cast optimization.

Instead, the focused boundary test locks the locally representable legacy unary descriptor-cast surface and asserts that `optimize-instructions` keeps `ref.cast_desc_eq` unchanged. This prevents ordinary `ref.cast` same-heap cleanup helpers from accidentally consuming descriptor casts before the HOT representation can model the descriptor operand safely.

## Evidence

- Binaryen oracle: `wasm-opt .tmp/oi-j-desc-cast-boundary-probe.wat --enable-gc --enable-reference-types --enable-custom-descriptors -S -O --optimize-instructions -o -` kept the exported nullable and non-null `ref.cast_desc_eq` operations.
- Boundary-only focused test: `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*legacy descriptor equality casts*'` passed `1/1`. Red-first positive implementation does not apply because this is an intentionally fail-closed descriptor boundary and no Starshine transform was added.
- `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*descriptor*'` passed `1/1`.
- `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*optimize-instructions*'` passed `203/203`.
- `moon fmt` passed.
- `moon test src/passes` passed `2733/2733`.
- `moon build --target native --release src/cmd` passed.
- `moon info` passed with existing warnings in `src/validate/gen_valid.mbt` and `src/validate/gen_valid_ssa.mbt`.
- `git diff --check && git diff --cached --check` passed.
- Direct compare smoke:
  - `rm -rf .tmp/pass-fuzz-optimize-instructions-oi-j-descriptor-cast-boundary-1 && bun scripts/pass-fuzz-compare.ts --pass optimize-instructions --count 1 --seed 0x5eed --out-dir .tmp/pass-fuzz-optimize-instructions-oi-j-descriptor-cast-boundary-1 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe`
  - requested `1`, compared `1/1`, normalized matches `0`, compare-normalized matches `0`, raw mismatches `1`, validation/property/generator/command failures `0`.
  - cache: wasm-smith `0` hits / `0` misses; Binaryen `1` hit / `0` misses; Binaryen failures `0` hits / `0` misses.
  - Agent classification: known scalar/default output-shape raw mismatch family from earlier OI slices. Grepping the failure artifacts found no `ref.cast`, `ref.test`, `ref.eq`, `ref.is_null`, `ref.as_non_null`, `call_ref`, `return_call_ref`, `ref.cast_desc_eq`, or `ref.test_desc`, so the smoke did not exercise this descriptor boundary slice.

## Remaining work

This closes only the narrow descriptor equality cast boundary classification for `[O4Z-AUDIT-OI-J]`. Starshine still needs a safe official two-operand descriptor-cast HOT representation before it can implement or fully test Binaryen descriptor-cast parity. Descriptor tests, TNH/IIT-only removals, useful-type-info preservation, custom-descriptor mode boundaries, and other success-only-if-null/non-null cases remain open. The broader `[O4Z-AUDIT-OI-G]`, `[O4Z-AUDIT-OI-H]`, `[O4Z-AUDIT-OI-I]`, `[O4Z-AUDIT-OI-J]`, and later slices are not complete.
