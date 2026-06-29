# remove-unused-brs boundary-closeout validation refresh

Date: 2026-06-29

Slice: `[O4Z-AUDIT-RUB-Q]` recursive complete-family audit.

## Scope

This validation slice followed the final-optimizer coverage and accepted-boundary consolidation notes `1382` and `1383`. The only test change in this iteration was focused coverage for the already-implemented constant equality arm of the redundant self-target `br_if` value cleanup; no `remove-unused-brs` transform implementation behavior changed.

## Commands and results

- `moon fmt && moon test --package jtenner/starshine/passes --file remove_unused_brs_test.mbt && moon test src/passes && moon info && moon build --target native --release src/cmd && git diff --check`
  - Passed.
  - Focused RUB tests: `212/212`.
  - `moon test src/passes`: `3618/3618`.
  - `moon info`: passed with the six known pre-existing warnings: `decode_maybe_exact_heap_type`, `encode_exact_heap_type`, `hot_verify.mbt:116` unreachable code, unused derived `Eq`/`Debug` in `gen_valid.mbt`, and `gen_valid_ssa_instr_is_forbidden_control`.
  - Native `src/cmd` build: no work to do.
  - `git diff --check`: no output.

- `bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass remove-unused-brs --normalize drop-consts --normalize unreachable-control-debris --out-dir .tmp/pass-fuzz-remove-unused-brs-rub-q-boundary-closeout-1000-normalized --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe --max-failures 200 --keep-going-after-command-failures`
  - Passed.
  - Compared `1000/1000`.
  - `normalizedMatchCount=142`.
  - `cleanupNormalizedMatchCount=858` (CLI label: compare-normalized matches).
  - `mismatchCount=0`.
  - `validationFailureCount=0`, `propertyFailureCount=0`, `generatorFailureCount=0`, `commandFailureCount=0`.
  - `commandFailureClasses={}`.
  - Cache: wasm-smith `0` hits / `0` misses; Binaryen `1000` hits / `0` misses; Binaryen failure cache `0` hits / `0` misses.
  - Selected GenValid profile counts: `binaryen-oracle-portable=1000`.
  - Artifact path: `.tmp/pass-fuzz-remove-unused-brs-rub-q-boundary-closeout-1000-normalized`.

## Agent classification

No mismatches were produced in the refreshed 1000-case normalized GenValid lane, so there are no raw mismatch families to classify in this slice. There were also no tool/Binaryen command failures to separate.

Pass-local timing was not available from this compare harness output.

## Remaining closeout gap

This is a bounded validation refresh, not the final required closeout matrix. `[O4Z-AUDIT-RUB-Q]` remains open for raw-gate/performance accountability and the stronger final signoff matrix or a user-approved smaller replacement.
