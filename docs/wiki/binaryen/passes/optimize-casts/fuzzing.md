---
kind: workflow
status: working
last_reviewed: 2026-07-03
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

Current multi-root source-block later-reuse slice evidence from 2026-07-02:

- Focused `src/passes/optimize_casts_test.mbt` now passes `50/50` after adding the pure-prefix multi-root source-block positive and a source-block branch negative.
- `moon fmt` passed; `moon test src/passes` passed `3865/3865`; `moon info` and `moon build --target native --release src/cmd` passed with pre-existing warnings.
- Regular non-profile smoke `.tmp/pass-fuzz-optimize-casts-multiroot-source-smoke-100`: compared/normalized `100/100`, zero validation/generator/property/command failures, zero mismatches, Binaryen cache `100/0`.
- Dedicated aggregate smoke `.tmp/pass-fuzz-optimize-casts-genvalid-all-after-multiroot-source-smoke-20`: compared `20/20`, normalized `2`, mismatches `18`, zero validation/generator/property/command failures, Binaryen cache `20/0`. Selected leaves were `best-cast=6`, `early-motion=5`, `barriers=3`, `later-reuse=3`, `static-folds=2`, and `neighborhood=1`. Agent classification: still expected open generated parity surface, not a signoff failure.


Current nested ref.as/cast early-motion slice evidence from 2026-07-02:

- Focused `src/passes/optimize_casts_test.mbt` now passes `52/52` after adding the nested `ref.as_non_null(ref.cast nullable local.get)` early-motion positive plus the unsupported outer-ref.cast-over-ref.as negative.
- `moon fmt` passed; `moon test src/passes` passed `3867/3867`; `moon info` and native `src/cmd` build passed with pre-existing warnings.
- Regular non-profile smoke `.tmp/pass-fuzz-optimize-casts-nested-ref-as-smoke-100`: compared/normalized `100/100`, zero validation/generator/property/command failures, zero mismatches, Binaryen cache `100/0`.
- Dedicated aggregate smoke `.tmp/pass-fuzz-optimize-casts-genvalid-all-after-nested-ref-as-smoke-20`: compared `20/20`, normalized `2`, mismatches `18`, zero validation/generator/property/command failures, Binaryen cache `20/0`. Selected leaves were `best-cast=6`, `early-motion=5`, `barriers=3`, `later-reuse=3`, `static-folds=2`, and `neighborhood=1`. Agent classification: still expected open generated parity surface, not a signoff failure.


Current separate-root ref.as/cast early-motion slice evidence from 2026-07-02:

- Focused `src/passes/optimize_casts_test.mbt` now passes `54/54` after adding the separate nullable `ref.cast` plus `ref.as_non_null` root-pair positive and a same-local `local.tee` boundary negative.
- `moon fmt` passed; `moon test src/passes` passed `3869/3869`; `moon info` and native `src/cmd` build passed with pre-existing warnings.
- Regular non-profile smoke `.tmp/pass-fuzz-optimize-casts-separate-ref-as-cast-smoke-100`: compared/normalized `100/100`, zero validation/generator/property/command failures, zero mismatches, Binaryen cache `100/0`.
- Dedicated aggregate smoke `.tmp/pass-fuzz-optimize-casts-genvalid-all-after-separate-ref-as-cast-smoke-20`: compared `20/20`, normalized `2`, mismatches `18`, zero validation/generator/property/command failures, Binaryen cache `20/0`. Selected leaves were `best-cast=6`, `early-motion=5`, `barriers=3`, `later-reuse=3`, `static-folds=2`, and `neighborhood=1`. Agent classification: still expected open generated parity surface, not a signoff failure.

Current narrower-cast source early-motion slice evidence from 2026-07-02:

- Focused `src/passes/optimize_casts_test.mbt` now passes `55/55` after adding the Binaryen `move-cast-*`-style positive where a later narrower `ref.cast` is duplicated into the direct source of an earlier broader `ref.cast`.
- `moon fmt` passed; `moon test src/passes` passed `3870/3870`; `moon info` and native `src/cmd` build passed with pre-existing warnings.
- Regular non-profile smoke `.tmp/pass-fuzz-optimize-casts-narrower-cast-source-smoke-100`: compared/normalized `100/100`, zero validation/generator/property/command failures, zero mismatches, and Binaryen cache `100/0`.
- Dedicated aggregate smoke `.tmp/pass-fuzz-optimize-casts-genvalid-all-after-narrower-cast-source-smoke-20`: compared `20/20`, normalized `2`, mismatches `18`, zero validation/generator/property/command failures, Binaryen cache `20/0`. Selected leaves were `best-cast=6`, `early-motion=5`, `barriers=3`, `later-reuse=3`, `static-folds=2`, and `neighborhood=1`. Agent classification: still expected open generated parity surface, not a signoff failure.

Current source-cast refinalization slice evidence from 2026-07-02:

- Focused `src/passes/optimize_casts_test.mbt` now passes `55/55` after tightening the direct narrower-cast-source fixture so the earlier broader outer cast is removed/refinalized after a later narrower cast is duplicated into its source.
- `moon fmt` passed; `moon test src/passes` passed `3870/3870`; `moon info` and native `src/cmd` build passed with pre-existing warnings.
- Regular non-profile smoke `.tmp/pass-fuzz-optimize-casts-source-cast-refinalize-smoke-100`: compared/normalized `100/100`, zero validation/generator/property/command failures, zero mismatches, and Binaryen cache `100/0`.
- Dedicated aggregate smoke `.tmp/pass-fuzz-optimize-casts-genvalid-all-after-source-cast-refinalize-smoke-20`: compared `20/20`, normalized `2`, mismatches `18`, zero validation/generator/property/command failures, and Binaryen cache `20/0`. Selected leaves were `best-cast=6`, `early-motion=5`, `barriers=3`, `later-reuse=3`, `static-folds=2`, and `neighborhood=1`. Agent classification: still expected open generated parity surface, not a signoff failure.

Current best early-cast selection slice evidence from 2026-07-02:

- Focused `src/passes/optimize_casts_test.mbt` now passes `56/56` after adding a move-cast-3-style fixture where the earliest dropped get receives the later narrower cast instead of the first broader cast in the window.
- `moon fmt` passed; `moon test src/passes` passed `3871/3871`; `moon info` and native `src/cmd` build passed with pre-existing warnings.
- Regular non-profile smoke `.tmp/pass-fuzz-optimize-casts-best-early-selection-smoke-100`: compared/normalized `100/100`, zero validation/generator/property/command failures, zero mismatches, and Binaryen cache `100/0`.
- Dedicated aggregate smoke `.tmp/pass-fuzz-optimize-casts-genvalid-all-after-best-early-selection-smoke-20`: compared `20/20`, normalized `2`, mismatches `18`, zero validation/generator/property/command failures, and Binaryen cache `20/0`. Selected leaves were `best-cast=6`, `early-motion=5`, `barriers=3`, `later-reuse=3`, `static-folds=2`, and `neighborhood=1`. Agent classification: still expected open generated parity surface, not a signoff failure.

Current move-cast-4 broader-source refinalization slice evidence from 2026-07-02:

- Focused `src/passes/optimize_casts_test.mbt` now passes `57/57` after adding a move-cast-4-style fixture where the earlier narrower cast is kept as the best cast and the later broader cast is refinalized away.
- `moon fmt` passed; `moon test src/passes` passed `3872/3872`; `moon info` and native `src/cmd` build passed with pre-existing warnings.
- Regular non-profile smoke `.tmp/pass-fuzz-optimize-casts-move-cast-4-smoke-100`: compared/normalized `100/100`, zero validation/generator/property/command failures, zero mismatches, and Binaryen cache `100/0`.
- Dedicated aggregate smoke `.tmp/pass-fuzz-optimize-casts-genvalid-all-after-move-cast-4-smoke-20`: compared `20/20`, normalized `2`, mismatches `18`, zero validation/generator/property/command failures, and Binaryen cache `20/0`. Selected leaves were `best-cast=6`, `early-motion=5`, `barriers=3`, `later-reuse=3`, `static-folds=2`, and `neighborhood=1`. Agent classification: still expected open generated parity surface, not a signoff failure.

Current move-cast-6 materialized-reuse slice evidence from 2026-07-02:

- Focused `src/passes/optimize_casts_test.mbt` now passes `58/58` after adding a move-cast-6-style fixture where the first root is already the best cast, a later plain read materializes its fresh local, and a following broader/refinalized cast source also reuses that materialized local.
- `moon fmt` passed; `moon test src/passes` passed `3873/3873`; `moon info` and native `src/cmd` build passed with pre-existing warnings.
- Regular non-profile smoke `.tmp/pass-fuzz-optimize-casts-move-cast-6-smoke-100`: compared/normalized `100/100`, zero validation/generator/property/command failures, zero mismatches, and Binaryen cache `100/0`.
- Dedicated aggregate smoke `.tmp/pass-fuzz-optimize-casts-genvalid-all-after-move-cast-6-smoke-20`: compared `20/20`, normalized `2`, mismatches `18`, zero validation/generator/property/command failures, and Binaryen cache `20/0`. Selected leaves were `best-cast=6`, `early-motion=5`, `barriers=3`, `later-reuse=3`, `static-folds=2`, and `neighborhood=1`. Agent classification: still expected open generated parity surface, not a signoff failure.

Current move-cast-5 refinalized-source reuse slice evidence from 2026-07-02:

- Focused `src/passes/optimize_casts_test.mbt` now passes `59/59` after adding a move-cast-5-style fixture where the first root is already the best cast, a later broader/refinalized cast source must materialize and read that best cast through a fresh local, and a final plain read reuses the same fresh local.
- `moon fmt` passed; `moon test src/passes` passed `3874/3874`; `moon info` and native `src/cmd` build passed with pre-existing warnings.
- Regular non-profile smoke `.tmp/pass-fuzz-optimize-casts-move-cast-5-smoke-100`: compared/normalized `100/100`, zero validation/generator/property/command failures, zero mismatches, and Binaryen cache `100/0`.
- Dedicated aggregate smoke `.tmp/pass-fuzz-optimize-casts-genvalid-all-after-move-cast-5-smoke-20`: compared `20/20`, normalized `2`, mismatches `18`, zero validation/generator/property/command failures, and Binaryen cache `20/0`. Selected leaves were `best-cast=6`, `early-motion=5`, `barriers=3`, `later-reuse=3`, `static-folds=2`, and `neighborhood=1`. Agent classification: still expected open generated parity surface, not a signoff failure.


Current local.tee early-motion slice evidence from 2026-07-03:

- Focused `src/passes/optimize_casts_test.mbt` now passes `61/61` after adding the separate-local `ref.cast(local.tee y (local.get x))` early-motion positive and the same-local self-tee write-barrier negative.
- `moon fmt` passed; `moon test src/passes` passed `3876/3876`; `moon info` and native `src/cmd` build passed with pre-existing warnings.
- Regular non-profile smoke `.tmp/pass-fuzz-optimize-casts-tee-motion-smoke-100`: compared/normalized `100/100`, zero validation/generator/property/command failures, zero mismatches, and Binaryen cache `100/0`.
- Dedicated aggregate smoke `.tmp/pass-fuzz-optimize-casts-genvalid-all-after-tee-motion-smoke-20`: compared `20/20`, normalized `2`, mismatches `18`, zero validation/generator/property/command failures, and Binaryen cache `20/0`. Selected leaves were `best-cast=6`, `early-motion=5`, `barriers=3`, `later-reuse=3`, `static-folds=2`, and `neighborhood=1`. Agent classification: still expected open generated parity surface, not a signoff failure.

Current mixed local.tee pair slice evidence from 2026-07-03:

- Focused `src/passes/optimize_casts_test.mbt` now passes `63/63` after adding the adjacent mixed nullable-cast/`ref.as_non_null` positive whose cast source is `local.tee y (local.get x)` and the paired self-tee barrier negative.
- `moon fmt` passed; `moon test src/passes` passed `3878/3878`; `moon info` and native `src/cmd` build passed with pre-existing warnings.
- Regular non-profile smoke `.tmp/pass-fuzz-optimize-casts-mixed-tee-pair-smoke-100`: compared/normalized `100/100`, zero validation/generator/property/command failures, zero mismatches, and Binaryen cache `100/0`.
- Dedicated aggregate smoke `.tmp/pass-fuzz-optimize-casts-genvalid-all-after-mixed-tee-pair-smoke-20`: compared `20/20`, normalized `2`, mismatches `18`, zero validation/generator/property/command failures, and Binaryen cache `20/0`. Selected leaves were `best-cast=6`, `early-motion=5`, `barriers=3`, `later-reuse=3`, `static-folds=2`, and `neighborhood=1`. Agent classification: still expected open generated parity surface, not a signoff failure.

Current best-cast source-feed slice evidence from 2026-07-03:

- Focused `src/passes/optimize_casts_test.mbt` now passes `64/64` after adding the Binaryen `best`-style fixture where an already-materialized broader cast feeds the source of a later narrower cast across intervening `global.set` roots while the existing unrelated-cast negative stays conservative.
- `moon fmt` passed; `moon test src/passes` passed `3879/3879`; `moon info` and native `src/cmd` build passed with pre-existing warnings.
- Regular non-profile smoke `.tmp/pass-fuzz-optimize-casts-best-source-feed-smoke-100`: compared/normalized `100/100`, zero validation/generator/property/command failures, zero mismatches, and Binaryen cache `100/0`.
- Dedicated aggregate smoke `.tmp/pass-fuzz-optimize-casts-genvalid-all-after-best-source-feed-smoke-20`: compared `20/20`, normalized `2`, mismatches `18`, zero validation/generator/property/command failures, and Binaryen cache `20/0`. Selected leaves were `best-cast=6`, `early-motion=5`, `barriers=3`, `later-reuse=3`, `static-folds=2`, and `neighborhood=1`. Agent classification: still expected open generated parity surface, not a signoff failure.

Current nested-region early-motion slice evidence from 2026-07-03:

- Focused `src/passes/optimize_casts_test.mbt` now passes `65/65` after adding the Binaryen `no-move-past-non-linear` branch-local block positive where early motion happens inside a block nested under an `if` arm while facts still do not cross the enclosing nonlinear control.
- `moon fmt` passed; `moon test src/passes` passed `3880/3880`; `moon info` and native `src/cmd` build passed with pre-existing warnings.
- Regular non-profile smoke `.tmp/pass-fuzz-optimize-casts-nested-region-smoke-100`: compared/normalized `100/100`, zero validation/generator/property/command failures, zero mismatches, and Binaryen cache `100/0`.
- Dedicated aggregate smoke `.tmp/pass-fuzz-optimize-casts-genvalid-all-after-nested-region-smoke-20`: compared `20/20`, normalized `2`, mismatches `18`, zero validation/generator/property/command failures, and Binaryen cache `20/0`. Selected leaves were `best-cast=6`, `early-motion=5`, `barriers=3`, `later-reuse=3`, `static-folds=2`, and `neighborhood=1`. Agent classification: still expected open generated parity surface, not a signoff failure.

Current tee-alias later-reuse slice evidence from 2026-07-03:

- Focused `src/passes/optimize_casts_test.mbt` now passes `66/66` after adding the Binaryen `local-tee` later-reuse positive where a cast computed through `local.tee y (local.get x)` feeds later reads of both `x` and `y` through one shared fresh carrier local.
- `moon fmt` passed; `moon test src/passes` passed `3881/3881`; `moon info` and native `src/cmd` build passed with pre-existing warnings.
- Regular non-profile smoke `.tmp/pass-fuzz-optimize-casts-tee-alias-smoke-100`: compared/normalized `100/100`, zero validation/generator/property/command failures, zero mismatches, and Binaryen cache `100/0`.
- Dedicated aggregate smoke `.tmp/pass-fuzz-optimize-casts-genvalid-all-after-tee-alias-smoke-20`: compared `20/20`, normalized `2`, mismatches `18`, zero validation/generator/property/command failures, and Binaryen cache `20/0`. Selected leaves were `best-cast=6`, `early-motion=5`, `barriers=3`, `later-reuse=3`, `static-folds=2`, and `neighborhood=1`. Agent classification: still expected open generated parity surface, not a signoff failure.


Current repeated equal moved-cast slice evidence from 2026-07-03:

- Focused `src/passes/optimize_casts_test.mbt` now passes `67/67` after adding the Binaryen `move-identical-repeated-casts`-style positive where one equal cast is duplicated to the earliest dropped get and both later equal casts reuse the same fresh carrier.
- `moon fmt` passed; `moon test src/passes` passed `3882/3882`; `moon info` and native `src/cmd` build passed with pre-existing warnings.
- Regular non-profile smoke `.tmp/pass-fuzz-optimize-casts-repeated-equal-smoke-100`: compared/normalized `100/100`, zero validation/generator/property/command failures, zero mismatches, and Binaryen cache `100/0`.
- Dedicated aggregate smoke `.tmp/pass-fuzz-optimize-casts-genvalid-all-after-repeated-equal-smoke-20`: compared `20/20`, normalized `2`, mismatches `18`, zero validation/generator/property/command failures, and Binaryen cache `20/0`. Selected leaves were `best-cast=6`, `early-motion=5`, `barriers=3`, `later-reuse=3`, `static-folds=2`, and `neighborhood=1`. Agent classification: still expected open generated parity surface, not a signoff failure.


Current mixed moved ref.as/cast refinalization slice evidence from 2026-07-03:

- Focused `src/passes/optimize_casts_test.mbt` now passes `68/68` after adding the Binaryen `move-ref.as-and-ref.cast-3`-style positive where a mixed moved `ref.as_non_null` / nullable-`ref.cast` pair reuses one carrier and the later reused cast is refinalized to a non-null `ref.cast`.
- `moon fmt` passed; `moon test src/passes` passed `3883/3883`; `moon info` and native `src/cmd` build passed with pre-existing warnings.
- Regular non-profile smoke `.tmp/pass-fuzz-optimize-casts-mixed-ref-as-refinalize-smoke-100`: compared/normalized `100/100`, zero validation/generator/property/command failures, zero mismatches, and Binaryen cache `100/0`.
- Dedicated aggregate smoke `.tmp/pass-fuzz-optimize-casts-genvalid-all-after-mixed-ref-as-refinalize-smoke-20`: compared `20/20`, normalized `2`, mismatches `18`, zero validation/generator/property/command failures, and Binaryen cache `20/0`. Selected leaves were `best-cast=6`, `early-motion=5`, `barriers=3`, `later-reuse=3`, `static-folds=2`, and `neighborhood=1`. Agent classification: still expected open generated parity surface, not a signoff failure.

Current move-cast-2 broad-then-narrow moved-carrier slice evidence from 2026-07-03:

- Focused `src/passes/optimize_casts_test.mbt` now passes `69/69` after adding a Binaryen `move-cast-2`-style broad-then-narrow fixture where strict early motion refinalizes the earlier broad cast away and later reuse makes both the intervening narrower cast and the following plain read use the same moved carrier.
- `moon fmt` passed; `moon test src/passes` passed `3884/3884`; `moon info` and native `src/cmd` build passed with pre-existing warnings.
- Regular non-profile smoke `.tmp/pass-fuzz-optimize-casts-move-cast-2-reuse-smoke-100`: compared/normalized `100/100`, zero validation/generator/property/command failures, zero mismatches, and Binaryen cache `100/0`.
- Dedicated aggregate smoke `.tmp/pass-fuzz-optimize-casts-genvalid-all-after-move-cast-2-reuse-smoke-20`: compared `20/20`, normalized `2`, mismatches `18`, zero validation/generator/property/command failures, and Binaryen cache `20/0`. Selected leaves were `best-cast=6`, `early-motion=5`, `barriers=3`, `later-reuse=3`, `static-folds=2`, and `neighborhood=1`. Agent classification: still expected open generated parity surface, not a signoff failure.

Use the aggregate now to expose and classify remaining OC gaps. Do not report OC closeout until the required four-lane matrix, including `--gen-valid-profile optimize-casts-all`, is refreshed after the remaining transform families are either implemented or narrowly documented with reopening criteria.
