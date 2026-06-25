# Optimize-instructions OI-D maxBits signed-to-unsigned spelling

Date: 2026-06-25

## Question

Does Binaryen `version_130` only fold signed relational compares when a nonnegative `maxBits` proof puts the constant outside the possible range, or does it also canonicalize in-range signed relational comparisons to unsigned spellings?

## Binaryen oracle

Probe: `.tmp/oi-d-maxbits-signed-spelling-probe.wat`.

Command:

```sh
wasm-opt --all-features -S --optimize-instructions .tmp/oi-d-maxbits-signed-spelling-probe.wat -o -
```

Result: Binaryen rewrites nonnegative bounded signed relational compares to unsigned relational spellings when the right-hand constant is in the nonnegative range instead of folding them:

- `i32.lt_s((x & 255), 128)` becomes `i32.lt_u((x & 255), 128)`.
- `i64.ge_s((x >>> 8), 42)` becomes `i64.ge_u((x >>> 8), 42)`.
- `i32.lt_s(i32.load8_u(ptr), 128)` becomes `i32.lt_u(i32.load8_u(ptr), 128)`, preserving the trapping load.

This complements `0898`, which covers out-of-range signed relational constants that fold to an `i32.const` while preserving effects/traps.

## Starshine change

Added red-first focused coverage in `src/passes/optimize_instructions_test.mbt` (`optimize-instructions rewrites unsigned maxBits signed compare spelling`). Before implementation, the test failed because Starshine kept `i32.lt_s` / `i64.ge_s` over proven nonnegative bounded operands.

Implemented narrow signed-to-unsigned relational compare spelling in `src/passes/optimize_instructions.mbt` for the existing direct nonnegative `maxBits` proof surface:

- i32: `lt_s` / `le_s` / `gt_s` / `ge_s` become `lt_u` / `le_u` / `gt_u` / `ge_u` when the lhs has a direct unsigned max fact and the constant rhs is nonnegative but not outside the fold range.
- i64: same mapping for `i64` relational compares.

The implementation deliberately reuses the existing direct unsigned max fact producers: nonnegative `and` masks, constant positive `shr_u`, nested direct `and`/`shr_u`, and unsigned loads. It does not add LocalScanner facts, select/phi facts, dynamic/zero shift facts, or signed-range facts.

## Evidence

- Binaryen oracle command above passed.
- Red-first focused test failed before implementation with `i32.lt_s` kept.
- After implementation, `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*unsigned maxBits signed compare spelling*'` passed `1/1`.

## Remaining work

The `maxBits` parity surface remains incomplete: full Binaryen LocalScanner behavior, CFG/phi/select facts, dynamic/zero shifts, broader producer families, and signed range proofs beyond the direct nonnegative subset remain open.
