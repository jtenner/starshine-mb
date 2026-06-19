# Optimize-instructions OI-G memory.copy boundary slice

## Question

Which `memory.copy` shapes should Starshine keep fail-closed after the size-`1`/`2`/`4`/`8` exact load/store lowering slices, and what evidence keeps those boundaries explicit?

## Classification

This is the seventh narrow `[O4Z-AUDIT-OI-G]` sub-slice. It is a boundary/test slice, not a new positive transform.

The current implementation in `src/passes/optimize_instructions.mbt` lowers only constant-size `memory.copy` sizes `1`, `2`, `4`, and `8` to one full-width load followed by one matching store. This slice locks the remaining nearby `memory.copy` cases as intentional fail-closed behavior:

- size `0` stays `memory.copy` because Starshine has no local Binaryen ignore-traps / TNH / IIT-equivalent mode support for trap-relaxed zero-size cleanup;
- size `16` stays `memory.copy` because no multi-load/multi-store overlap proof has been implemented;
- nonconstant size stays `memory.copy` because the size expression may carry effects or traps and because the lowering only proves the tiny exact-size cases.

This does not close `[O4Z-AUDIT-OI-G]`; it narrows the open work by documenting that these `memory.copy` shapes are not accidental omissions.

## Tests

Changed `src/passes/optimize_instructions_test.mbt`:

- added `optimize-instructions keeps memory.copy outside exact tiny lowering boundary`.

The test fixture contains one function with:

- zero-size `memory.copy`;
- constant-size-16 `memory.copy`;
- nonconstant-size `memory.copy`.

It asserts that `memory.copy` remains and that the byte load/store spelling from the positive tiny-copy lowering does not appear. This is intentionally a fail-closed boundary test, so no red failing implementation step was expected or required.

## Focused evidence

- Boundary test after adding it: `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*memory.copy*'`
  - `Total tests: 3, passed: 3, failed: 0.`
- Focused memory filter: `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*memory*'`
  - `Total tests: 12, passed: 12, failed: 0.`
- Focused optimize-instructions filter: `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*optimize-instructions*'`
  - `Total tests: 113, passed: 113, failed: 0.`

## Broader validation

- `moon fmt`
  - passed.
- `moon test src/passes`
  - `Total tests: 2625, passed: 2625, failed: 0.`
- `moon build --target native --release src/cmd`
  - passed; no work was needed.
- `moon info`
  - passed with the existing warnings in `src/validate/gen_valid.mbt` and `src/validate/gen_valid_ssa.mbt`.

## Direct compare evidence

Command:

```sh
bun scripts/pass-fuzz-compare.ts --pass optimize-instructions --count 10000 --seed 0x5eed --out-dir .tmp/pass-fuzz-optimize-instructions-oi-g-memory-copy-boundaries-10000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe
```

Result:

- requested: `10000`
- compared: `54/10000`
- normalized matches: `27`
- cleanup-normalized matches: `0`
- raw mismatches: `27`
- validation failures: `0`
- property failures: `0`
- generator failures: `0`
- command failures: `1`
- jobs: `16`
- cache: wasm-smith `28` hits / `0` misses; Binaryen `54` hits / `0` misses; Binaryen failures `1` hit / `0` misses

Agent classifications:

- command failure: known **tool/Binaryen failure** class `binaryen-rec-group-zero`.
- raw mismatches: known **Starshine-win** constant-if and redundant-sign-extension output-shape families from earlier OI-E/OI-F work, not new memory-copy semantic failures.

A grep over the failure artifacts found no `memory.copy` or `memory.fill` occurrences. Sample canonical wasm sizes stayed smaller for Starshine:

- `case-000002-gen-valid`: Binaryen `4161` bytes, Starshine `4120` bytes;
- `case-000004-gen-valid`: Binaryen `5539` bytes, Starshine `5481` bytes;
- `case-000006-gen-valid`: Binaryen `5559` bytes, Starshine `5496` bytes.

## Remaining OI-G boundaries

Remaining `[O4Z-AUDIT-OI-G]` work after this slice:

- memory64-focused fixtures beyond accepting constant `i64` size operands in the helper;
- general load/store canonicalization;
- effect/trap negatives for additional fill/copy/load/store cases where useful;
- decision on whether any memory/load/call shapes should escape the current `load-call-optimize-instructions-noop` raw gate.

Zero-size `memory.copy` and `memory.fill` cleanup should not be implemented unless Starshine grows explicit local ignore-traps / TNH / IIT-equivalent mode support or the user accepts a different trap-mode policy with focused tests.
