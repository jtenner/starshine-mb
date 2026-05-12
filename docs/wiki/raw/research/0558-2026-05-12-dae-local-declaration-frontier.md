# DAE local-declaration frontier after case-000690

Date: 2026-05-12

## Question

After the `case-000690` escaped self-call operand fix, do the remaining direct `--dae-optimizing` mismatches in `.tmp/pass-fuzz-dae-690-final2-1000` contain another semantic or signature candidate, or are they only local-declaration shape drift?

## Evidence

- Baseline probe: `.tmp/pass-fuzz-dae-690-final2-1000` from `1f81bbc7 Preserve DAE escaped self-call operand params`.
- Probe result: `998/1000` compared, `985` normalized matches, `13` mismatches, and `2` Binaryen/tool command failures.
- Command failures are unchanged Binaryen/parser tool failures from zero-sized recursion groups:
  - `case-000029-wasm-smith`
  - `case-000573-wasm-smith`
- For each of the 13 `gen-valid` mismatches, `diff -u binaryen.wat starshine.wat` has exactly one hunk, and that hunk is limited to local declarations at the start of one function body. No instructions, function signatures, type declarations, exports, imports, element/table data, or custom-section contents differ.
- `case-000690-gen-valid` is absent from this failure set.

## Mismatch classification

| Case | Classification | Binaryen-only local declaration shape | Starshine-only local declaration shape |
| --- | --- | --- | --- |
| `case-000086-gen-valid` | local declarations only | `(local $5 i64)`, `(local $6 i32)` | `(local $5 i32)` |
| `case-000250-gen-valid` | local declarations only | `(local $3 f32)` | none |
| `case-000360-gen-valid` | local declarations only | `(local $3 i32)`, `(local $4 f64)` | `(local $3 f64)` |
| `case-000494-gen-valid` | local declarations only | `(local $5 f64)`, `(local $6 i32)`, `(local $7 f32)` | `(local $5 i32)`, `(local $6 f32)` |
| `case-000626-gen-valid` | local declarations only | `(local $6 i32)` | none |
| `case-000654-gen-valid` | local declarations only | `(local $3 i64)` | none |
| `case-000766-gen-valid` | local declarations only | `(local $4 f32)`, `(local $6 f64)`, `(local $7 i32)` | `(local $4 f64)`, `(local $6 i32)` |
| `case-000844-gen-valid` | local declarations only | `(local $3 i64)`, `(local $4 f64)`, `(local $5 f32)`, `(local $6 i32)` | `(local $3 f64)`, `(local $4 f32)`, `(local $5 i32)` |
| `case-000854-gen-valid` | local declarations only | `(local $2 f64)` | none |
| `case-000862-gen-valid` | local declarations only | `(local $2 f64)` | none |
| `case-000890-gen-valid` | local declarations only | `(local $2 f64)` | none |
| `case-000956-gen-valid` | local declarations only | `(local $2 i64)` | none |
| `case-000960-gen-valid` | local declarations only | `(local $4 f64)`, `(local $5 i64)`, `(local $6 i32)` | `(local $4 i64)`, `(local $5 i32)` |

## Conclusion

The remaining saved 1000-case frontier after `1f81bbc7` has no known semantic/signature mismatch candidate. The 13 remaining `gen-valid` failures are cosmetic unused-local declaration drift exposed by the normalization harness's byte/text comparison. They should not drive another DAE signature-preservation rule without a new oracle-backed semantic case.

The safest next DAE work is either:

1. broaden the direct fuzz count to look for a new real semantic/signature mismatch beyond this 1000-case seed, or
2. move to the active artifact/touched-scheduler backlog (`[DAE]002`), where the debug artifact is still semantically red at first differing function `defined=11 abs=28`.

Do not implement a broad rule that preserves Binaryen's exact unused local declarations solely to erase these normalized diffs unless that work is explicitly scoped as cosmetic output-shape parity and separately proven not to regress the already fragile result/parameter preservation families.
