---
kind: workflow
status: working
last_reviewed: 2026-07-02
sources:
  - ../../../tooling/pass-fuzz-compare.md
  - ../../../../../scripts/lib/pass-fuzz-compare-task.ts
  - ../../../raw/research/1403-2026-07-02-optimize-casts-recursive-audit-kickoff.md
  - ../../../../../src/validate/gen_valid.mbt
  - ../../../../../src/validate/gen_valid_tests.mbt
---

# `optimize-casts` Fuzzing Profile

Regular direct lane:

```sh
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass optimize-casts --out-dir .tmp/pass-fuzz-optimize-casts --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures
```

Dedicated GenValid aggregate: `optimize-casts-all`.

```sh
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass optimize-casts --gen-valid-profile optimize-casts-all --out-dir .tmp/pass-fuzz-optimize-casts-genvalid-all-10000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures
```

Aliases accepted by GenValid profile lookup: `optimize-casts`, `optimize-casts-closeout`, `optimize-casts-all-profiles`, `oc`, and `oc-closeout`.

## Profile leaves

- `optimize-casts-later-reuse`: already-computed `ref.cast(local.get x)` followed by later same-local reads.
- `optimize-casts-early-motion`: earlier same-local reads followed by a later cast candidate, intentionally exposing the still-open strict motion family.
- `optimize-casts-barriers`: same-local write barriers between a remembered cast and later local traffic.
- `optimize-casts-best-cast`: multiple related `ref.cast` roots so best-cast/subtype selection and later source retargeting are sampled.
- `optimize-casts-ref-as`: nullable cast plus later `ref.as_non_null` traffic.
- `optimize-casts-static-folds`: the current Starshine static fold surface such as `ref.test` and branch-cast forms.
- `optimize-casts-neighborhood`: local.tee-shaped cast traffic intended for the `heap2local -> optimize-casts -> local-subtyping -> coalesce-locals -> local-cse` cleanup neighborhood.

The aggregate samples all leaves and records the selected leaf through the composite-profile manifest `selected_profile` field. Use that field when triaging generated mismatches so early-motion, later-reuse, barrier, best-cast, ref.as_non_null, static-fold, and neighborhood families stay separate.

## Current status

The first profile slice added registration and generator tests plus tiny aggregate smokes. Focused validation passes, but the aggregate is **not** a green signoff lane yet: it deliberately includes `optimize-casts-early-motion`, and Starshine currently implements only a strict empty/`nop`/dropped nontrapping i32 pure-tree plus dropped-local-read and nontrapping pure separate-index `local.set` subset of Binaryen's earlier cast/as_non_null motion phase.

Current profile-smoke evidence from 2026-07-02:

- Regular non-profile smoke `.tmp/pass-fuzz-optimize-casts-genprofile-slice-regular-smoke-100`: compared/normalized `100/100`, zero validation/generator/property/command failures, zero mismatches, Binaryen cache `100/0`.
- Dedicated aggregate smoke `.tmp/pass-fuzz-optimize-casts-genvalid-all-profile-smoke-20`: compared `20/20`, normalized `2`, mismatches `18`, zero validation/generator/property/command failures, Binaryen cache `4/16`. Selected leaves were `best-cast=6`, `early-motion=5`, `barriers=3`, `later-reuse=3`, `static-folds=2`, and `neighborhood=1`; `ref-as` was not selected in this tiny sample. Agent classification: expected open generated parity surface, not a signoff failure, because the aggregate intentionally samples unimplemented or only-partially-implemented OC families.

Current early-adjacent slice evidence from 2026-07-02:

- Focused `src/passes/optimize_casts_test.mbt` now passes `26/26` after adding the adjacent early-motion positive and same-local write negative.
- Regular non-profile smoke `.tmp/pass-fuzz-optimize-casts-early-adjacent-smoke-100`: compared/normalized `100/100`, zero validation/generator/property/command failures, zero mismatches, Binaryen cache `100/0`.
- Dedicated aggregate smoke `.tmp/pass-fuzz-optimize-casts-genvalid-all-after-early-adjacent-smoke-20`: compared `20/20`, normalized `2`, mismatches `18`, zero validation/generator/property/command failures, Binaryen cache `20/0`. Selected leaves were `best-cast=6`, `early-motion=5`, `barriers=3`, `later-reuse=3`, `static-folds=2`, and `neighborhood=1`. Agent classification: still expected open generated parity surface, not a signoff failure.

Current pure-root early-motion slice evidence from 2026-07-02:

- Focused `src/passes/optimize_casts_test.mbt` now passes `28/28` after adding the dropped-const early-motion positive and call-barrier negative.
- Regular non-profile smoke `.tmp/pass-fuzz-optimize-casts-early-pure-root-smoke-100`: compared/normalized `100/100`, zero validation/generator/property/command failures, zero mismatches, Binaryen cache `100/0`.
- Dedicated aggregate smoke `.tmp/pass-fuzz-optimize-casts-genvalid-all-after-early-pure-root-smoke-20`: compared `20/20`, normalized `2`, mismatches `18`, zero validation/generator/property/command failures, Binaryen cache `20/0`. Selected leaves were `best-cast=6`, `early-motion=5`, `barriers=3`, `later-reuse=3`, `static-folds=2`, and `neighborhood=1`. Agent classification: still expected open generated parity surface, not a signoff failure.


Current unary pure-root early-motion slice evidence from 2026-07-02:

- Focused `src/passes/optimize_casts_test.mbt` now passes `30/30` after adding the `i32.const; i32.eqz; drop` early-motion positive and trapping `i32.div_s` barrier negative.
- Regular non-profile smoke `.tmp/pass-fuzz-optimize-casts-early-unary-smoke-100`: compared/normalized `100/100`, zero validation/generator/property/command failures, zero mismatches, Binaryen cache `100/0`.
- Dedicated aggregate smoke `.tmp/pass-fuzz-optimize-casts-genvalid-all-after-early-unary-smoke-20`: compared `20/20`, normalized `2`, mismatches `18`, zero validation/generator/property/command failures, Binaryen cache `20/0`. Selected leaves were `best-cast=6`, `early-motion=5`, `barriers=3`, `later-reuse=3`, `static-folds=2`, and `neighborhood=1`. Agent classification: still expected open generated parity surface, not a signoff failure.


Current binary pure-root early-motion slice evidence from 2026-07-02:

- Focused `src/passes/optimize_casts_test.mbt` now passes `32/32` after adding the `i32.const; i32.const; i32.add; drop` early-motion positive and same-local `local.tee` write barrier negative.
- Regular non-profile smoke `.tmp/pass-fuzz-optimize-casts-early-binary-smoke-100`: compared/normalized `100/100`, zero validation/generator/property/command failures, zero mismatches, Binaryen cache `100/0`.
- Dedicated aggregate smoke `.tmp/pass-fuzz-optimize-casts-genvalid-all-after-early-binary-smoke-20`: compared `20/20`, normalized `2`, mismatches `18`, zero validation/generator/property/command failures, Binaryen cache `20/0`. Selected leaves were `best-cast=6`, `early-motion=5`, `barriers=3`, `later-reuse=3`, `static-folds=2`, and `neighborhood=1`. Agent classification: still expected open generated parity surface, not a signoff failure.

Current multiplication pure-root early-motion slice evidence from 2026-07-02:

- Focused `src/passes/optimize_casts_test.mbt` now passes `34/34` after adding the `i32.const; i32.const; i32.mul; drop` early-motion positive and same-local `local.set` write barrier negative.
- Regular non-profile smoke `.tmp/pass-fuzz-optimize-casts-early-mul-smoke-100`: compared/normalized `100/100`, zero validation/generator/property/command failures, zero mismatches, Binaryen cache `100/0`.
- Dedicated aggregate smoke `.tmp/pass-fuzz-optimize-casts-genvalid-all-after-early-mul-smoke-20`: compared `20/20`, normalized `2`, mismatches `18`, zero validation/generator/property/command failures, Binaryen cache `20/0`. Selected leaves were `best-cast=6`, `early-motion=5`, `barriers=3`, `later-reuse=3`, `static-folds=2`, and `neighborhood=1`. Agent classification: still expected open generated parity surface, not a signoff failure.

Current bitwise pure-root early-motion slice evidence from 2026-07-02:

- Focused `src/passes/optimize_casts_test.mbt` now passes `36/36` after adding the `i32.const; i32.const; i32.and; drop` plus `i32.const; i32.const; i32.or; drop` early-motion positive and same-local `local.set` write barrier negative.
- Regular non-profile smoke `.tmp/pass-fuzz-optimize-casts-early-bitwise-smoke-100`: compared/normalized `100/100`, zero validation/generator/property/command failures, zero mismatches, Binaryen cache `100/0`.
- Dedicated aggregate smoke `.tmp/pass-fuzz-optimize-casts-genvalid-all-after-early-bitwise-smoke-20`: compared `20/20`, normalized `2`, mismatches `18`, zero validation/generator/property/command failures, Binaryen cache `20/0`. Selected leaves were `best-cast=6`, `early-motion=5`, `barriers=3`, `later-reuse=3`, `static-folds=2`, and `neighborhood=1`. Agent classification: still expected open generated parity surface, not a signoff failure.

Current xor/shift pure-root early-motion slice evidence from 2026-07-02:

- Focused `src/passes/optimize_casts_test.mbt` now passes `38/38` after adding the `i32.const; i32.const; i32.xor; drop` plus `i32.const; i32.const; i32.shl; drop` early-motion positive and memory-load barrier negative.
- Regular non-profile smoke `.tmp/pass-fuzz-optimize-casts-early-xor-shift-smoke-100`: compared/normalized `100/100`, zero validation/generator/property/command failures, zero mismatches, Binaryen cache `100/0`.
- Dedicated aggregate smoke `.tmp/pass-fuzz-optimize-casts-genvalid-all-after-early-xor-shift-smoke-20`: compared `20/20`, normalized `2`, mismatches `18`, zero validation/generator/property/command failures, Binaryen cache `20/0`. Selected leaves were `best-cast=6`, `early-motion=5`, `barriers=3`, `later-reuse=3`, `static-folds=2`, and `neighborhood=1`. Agent classification: still expected open generated parity surface, not a signoff failure.

Current sub/shift/rotate pure-root early-motion slice evidence from 2026-07-02:

- Focused `src/passes/optimize_casts_test.mbt` now passes `40/40` after adding the `i32.const; i32.const; i32.sub; drop`, `i32.const; i32.const; i32.shr_u; drop`, `i32.const; i32.const; i32.shr_s; drop`, `i32.const; i32.const; i32.rotl; drop`, and `i32.const; i32.const; i32.rotr; drop` early-motion positive plus same-local write barrier negative.
- Regular non-profile smoke `.tmp/pass-fuzz-optimize-casts-early-sub-shift-rotate-smoke-100`: compared/normalized `100/100`, zero validation/generator/property/command failures, zero mismatches, Binaryen cache `100/0`.
- Dedicated aggregate smoke `.tmp/pass-fuzz-optimize-casts-genvalid-all-after-early-sub-shift-rotate-smoke-20`: compared `20/20`, normalized `2`, mismatches `18`, zero validation/generator/property/command failures, Binaryen cache `20/0`. Selected leaves were `best-cast=6`, `early-motion=5`, `barriers=3`, `later-reuse=3`, `static-folds=2`, and `neighborhood=1`. Agent classification: still expected open generated parity surface, not a signoff failure.

Current separate-index local early-motion slice evidence from 2026-07-02:

- Focused `src/passes/optimize_casts_test.mbt` now passes `42/42` after adding the `ref.as_non_null` early-motion positive across `i32.const; local.set` to a separate local plus a same-local write barrier negative.
- Regular non-profile smoke `.tmp/pass-fuzz-optimize-casts-early-separate-index-smoke-100`: compared/normalized `100/100`, zero validation/generator/property/command failures, zero mismatches, Binaryen cache `100/0`.
- Dedicated aggregate smoke `.tmp/pass-fuzz-optimize-casts-genvalid-all-after-early-separate-index-smoke-20`: compared `20/20`, normalized `2`, mismatches `18`, zero validation/generator/property/command failures, Binaryen cache `20/0`. Selected leaves were `best-cast=6`, `early-motion=5`, `barriers=3`, `later-reuse=3`, `static-folds=2`, and `neighborhood=1`. Agent classification: still expected open generated parity surface, not a signoff failure.

Current local-fed pure-root early-motion slice evidence from 2026-07-02:

- Focused `src/passes/optimize_casts_test.mbt` now passes `44/44` after adding the `local.get 1; i32.const 7; i32.add; drop` early-motion positive and local-fed `i32.div_s` trap barrier negative.
- Regular non-profile smoke `.tmp/pass-fuzz-optimize-casts-early-local-fed-pure-smoke-100`: compared/normalized `100/100`, zero validation/generator/property/command failures, zero mismatches, Binaryen cache `100/0`.
- Dedicated aggregate smoke `.tmp/pass-fuzz-optimize-casts-genvalid-all-after-early-local-fed-pure-smoke-20`: compared `20/20`, normalized `2`, mismatches `18`, zero validation/generator/property/command failures, Binaryen cache `20/0`. Selected leaves were `best-cast=6`, `early-motion=5`, `barriers=3`, `later-reuse=3`, `static-folds=2`, and `neighborhood=1`. Agent classification: still expected open generated parity surface, not a signoff failure.

Current pure local-set early-motion slice evidence from 2026-07-02:

- Focused `src/passes/optimize_casts_test.mbt` now passes `46/46` after adding the `local.get 1; i32.const 7; i32.add; local.set 2` separate-index local-write positive and a trapping `i32.div_s; local.set 2` barrier negative.
- `moon test src/passes` passed `3861/3861`; `moon info` and `moon build --target native --release src/cmd` passed with pre-existing warnings.
- Regular non-profile smoke `.tmp/pass-fuzz-optimize-casts-early-pure-local-set-smoke-100`: compared/normalized `100/100`, zero validation/generator/property/command failures, zero mismatches, Binaryen cache `100/0`.
- Dedicated aggregate smoke `.tmp/pass-fuzz-optimize-casts-genvalid-all-after-early-pure-local-set-smoke-20`: compared `20/20`, normalized `2`, mismatches `18`, zero validation/generator/property/command failures, Binaryen cache `20/0`. Selected leaves were `best-cast=6`, `early-motion=5`, `barriers=3`, `later-reuse=3`, `static-folds=2`, and `neighborhood=1`. Agent classification: still expected open generated parity surface, not a signoff failure.

Current fallthrough-source / nonlinear-barrier later-reuse slice evidence from 2026-07-02:

- Focused `src/passes/optimize_casts_test.mbt` now passes `48/48` after adding the branch-free value-block source positive and the nonlinear `if (return)` basic-block barrier negative.
- `moon fmt` passed; `moon test src/passes` passed `3863/3863`; `moon info` and `moon build --target native --release src/cmd` passed with pre-existing warnings.
- Regular non-profile smoke `.tmp/pass-fuzz-optimize-casts-fallthrough-source-smoke-100`: compared/normalized `100/100`, zero validation/generator/property/command failures, zero mismatches, Binaryen cache `100/0`.
- Dedicated aggregate smoke `.tmp/pass-fuzz-optimize-casts-genvalid-all-after-fallthrough-source-smoke-20`: compared `20/20`, normalized `2`, mismatches `18`, zero validation/generator/property/command failures, Binaryen cache `20/0`. Selected leaves were `best-cast=6`, `early-motion=5`, `barriers=3`, `later-reuse=3`, `static-folds=2`, and `neighborhood=1`. Agent classification: still expected open generated parity surface, not a signoff failure.

Use the aggregate now to expose and classify remaining OC gaps. Do not report OC closeout until the required four-lane matrix, including `--gen-valid-profile optimize-casts-all`, is refreshed after the remaining transform families are either implemented or narrowly documented with reopening criteria.
