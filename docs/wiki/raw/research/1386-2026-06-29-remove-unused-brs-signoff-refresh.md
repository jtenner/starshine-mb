# remove-unused-brs signoff refresh

Date: 2026-06-29

Slice: `[O4Z-AUDIT-RUB-Q]` recursive complete-family audit.

## Scope

This slice attempted to move from the bounded `1384` validation refresh toward final closeout. No transform behavior changed. The required final closeout remains incomplete because the regular `100000` GenValid lane did not finish within the local command timeout and this pass still has no documented pass-specific GenValid profile.

The current `docs/wiki/binaryen/passes/remove-unused-brs/fuzzing.md` says: `Dedicated GenValid profile: none documented for this pass yet.` Therefore the pass-specific final-closeout lane cannot currently be run without adding a new RUB-owned profile or getting explicit approval to substitute a smaller/non-dedicated lane.

All direct compare lanes below used the accepted RUB cleanup normalizers `--normalize drop-consts --normalize unreachable-control-debris`, matching the current `1384` bounded refresh and classifying cleanup debris separately from raw mismatches.

## Commands and results

### Attempted regular GenValid 100000

- `bun scripts/pass-fuzz-compare.ts --count 100000 --seed 0x5eed --pass remove-unused-brs --normalize drop-consts --normalize unreachable-control-debris --out-dir .tmp/pass-fuzz-remove-unused-brs-rub-q-regular-100000-normalized --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures`
  - Timed out after the local `1200s` command timeout before `result.json` / `summary.json` were emitted.
  - Partial artifact path: `.tmp/pass-fuzz-remove-unused-brs-rub-q-regular-100000-normalized`.
  - Partial `cases.jsonl` line count: `66920`.
  - Agent-side partial summary from `cases.jsonl`: `66920` cases, all `match`, selected profile `binaryen-oracle-portable=66920`, no command-failure classes recorded in completed lines.
  - This partial result is useful evidence but does not satisfy the required regular `100000` final-closeout lane.

### Bounded regular GenValid 10000 replacement/progress lane

- `bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass remove-unused-brs --normalize drop-consts --normalize unreachable-control-debris --out-dir .tmp/pass-fuzz-remove-unused-brs-rub-q-regular-10000-normalized --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures`
  - Passed.
  - Compared `10000/10000`.
  - `normalizedMatchCount=1520`.
  - `cleanupNormalizedMatchCount=8480`.
  - `mismatchCount=0`.
  - `validationFailureCount=0`, `propertyFailureCount=0`, `generatorFailureCount=0`, `commandFailureCount=0`.
  - `commandFailureClasses={}`.
  - Cache: wasm-smith `0/0`; Binaryen `10000` hits / `0` misses; Binaryen failures `0/0`.
  - Selected profile counts: `binaryen-oracle-portable=10000`.

### Explicit wasm-smith 10000

- `bun scripts/pass-fuzz-compare.ts --wasm-smith --count 10000 --seed 0x5eed --pass remove-unused-brs --normalize drop-consts --normalize unreachable-control-debris --out-dir .tmp/pass-fuzz-remove-unused-brs-rub-q-wasm-smith-10000-normalized --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures`
  - Passed for compared cases.
  - Compared `9956/10000`.
  - `normalizedMatchCount=9954`.
  - `cleanupNormalizedMatchCount=2`.
  - `mismatchCount=0`.
  - `validationFailureCount=0`, `propertyFailureCount=0`, `generatorFailureCount=0`.
  - `commandFailureCount=44`, all classified as Binaryen/oracle tool classes: `binaryen-rec-group-zero=39`, `binaryen-bad-section-size=3`, `binaryen-invalid-tag-index=1`, `binaryen-table-index-out-of-range=1`.
  - Cache: wasm-smith `10000` hits / `0` misses; Binaryen `106` hits / `9850` misses; Binaryen failures `0` hits / `44` misses.

### Broad named GenValid profile 10000

- `bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5555 --pass remove-unused-brs --gen-valid-profile pass-fuzz-stress --normalize drop-consts --normalize unreachable-control-debris --out-dir .tmp/pass-fuzz-remove-unused-brs-rub-q-pass-fuzz-stress-10000-normalized --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures`
  - Passed.
  - Compared `10000/10000`.
  - `normalizedMatchCount=1397`.
  - `cleanupNormalizedMatchCount=8603`.
  - `mismatchCount=0`.
  - `validationFailureCount=0`, `propertyFailureCount=0`, `generatorFailureCount=0`, `commandFailureCount=0`.
  - `commandFailureClasses={}`.
  - Cache: wasm-smith `0/0`; Binaryen `42` hits / `9958` misses; Binaryen failures `0/0`.
  - Selected profile counts: `pass-fuzz-stress=10000`.

## Agent classification

No Starshine raw mismatches, Starshine validation failures, property failures, or generator failures were observed in the completed lanes. The explicit wasm-smith residual command failures are Binaryen/oracle tool classes, not Starshine pass-output behavior.

The final closeout is still incomplete for two reasons:

1. The required regular `100000` GenValid lane was attempted but timed out at the local command timeout after `66920` completed matching cases, before a final summary was emitted.
2. There is no current RUB-specific GenValid profile, so the pass-specific `10000` lane required by the modern final-closeout matrix cannot be run as specified.

## Recommended reopening/closeout actions

- Add and document a `remove-unused-brs` dedicated aggregate GenValid profile, or get explicit user approval to substitute the current normalized regular/broad profile lanes for RUB-Q closeout.
- Rerun the regular `100000` lane with a longer timeout or a harness-resume strategy, and record the completed `result.json`.
- If no transform behavior changes, rerun only the missing final lanes plus `git diff --check`; if behavior or public tests change, rerun the focused/full Moon validation matrix.
