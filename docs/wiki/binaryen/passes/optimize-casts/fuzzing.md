---
kind: workflow
status: working
last_reviewed: 2026-07-18
sources:
  - ../../../tooling/pass-fuzz-compare.md
  - ../../../../../scripts/lib/pass-fuzz-compare-task.ts
  - ./index.md
  - ../../../../../src/validate/gen_valid.mbt
  - ../../../../../src/validate/gen_valid_tests.mbt
---

# `optimize-casts` Fuzzing Profile

Regular direct lane:

```sh
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass optimize-casts --out-dir .tmp/pass-fuzz-optimize-casts --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures
```

Dedicated GenValid aggregate: `optimize-casts-all`.

```sh
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass optimize-casts --gen-valid-profile optimize-casts-all --out-dir .tmp/pass-fuzz-optimize-casts-genvalid-all-10000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures
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

The first profile slice added registration and generator tests plus tiny aggregate smokes. Focused validation passes. After the initialized non-defaultable-local fix, the bounded aggregate smoke is green, but the aggregate is **not** a closeout signoff lane yet: it still needs scaled direct/dedicated/broad/wasm-smith evidence, O4z neighborhood evidence, pass-local timing, and source review. Starshine also still implements only a strict empty/`nop`/dropped nontrapping i32 pure-tree plus dropped-local-read, nontrapping pure separate-index `local.set`, dropped separate-local `local.tee`, and current moved-cast/refinalization subsets of Binaryen's earlier cast/as_non_null motion phase.

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


Current three-level best-cast refinalization slice evidence from 2026-07-03:

- Focused `src/passes/optimize_casts_test.mbt` now passes `70/70` after adding a three-level base/mid/leaf best-cast fixture where the deepest leaf cast is moved to the earliest get and the intermediate broader cast target is refinalized to the current best target when it reads the moved carrier.
- `moon fmt` passed; `moon test src/passes` passed `3885/3885`; `moon info` and native `src/cmd` build passed with pre-existing warnings.
- Regular non-profile smoke `.tmp/pass-fuzz-optimize-casts-three-level-best-smoke-100`: compared/normalized `100/100`, zero validation/generator/property/command failures, zero mismatches, and Binaryen cache `100/0`.
- Dedicated aggregate smoke `.tmp/pass-fuzz-optimize-casts-genvalid-all-after-three-level-best-smoke-20`: compared `20/20`, normalized `2`, mismatches `18`, zero validation/generator/property/command failures, and Binaryen cache `20/0`. Selected leaves were `best-cast=6`, `early-motion=5`, `barriers=3`, `later-reuse=3`, `static-folds=2`, and `neighborhood=1`. Agent classification: still expected open generated parity surface, not a signoff failure.


Current separate-local tee early-motion slice evidence from 2026-07-03:

- Focused `src/passes/optimize_casts_test.mbt` now passes `71/71` after adding a source-backed dropped `local.tee` positive where `ref.as_non_null` moves across a tee that writes a separate local while reading the pending source local.
- `moon fmt` passed; `moon test src/passes` passed `3886/3886`; `moon info` and native `src/cmd` build passed with pre-existing warnings.
- Regular non-profile smoke `.tmp/pass-fuzz-optimize-casts-separate-tee-smoke-100`: compared/normalized `100/100`, zero validation/generator/property/command failures, zero mismatches, and Binaryen cache `100/0`.
- Dedicated aggregate smoke `.tmp/pass-fuzz-optimize-casts-genvalid-all-after-separate-tee-smoke-20`: compared `20/20`, normalized `2`, mismatches `18`, zero validation/generator/property/command failures, and Binaryen cache `20/0`. Selected leaves were `best-cast=6`, `early-motion=5`, `barriers=3`, `later-reuse=3`, `static-folds=2`, and `neighborhood=1`. Agent classification: still expected open generated parity surface, not a signoff failure.

Current exact fresh-local blocker slice evidence from 2026-07-03:

- Focused validation now passes after adding initialized non-defaultable-local support: `validate.mbt` `173/173`, focused OC `72/72`, `moon test src/validate` `1657/1657`, and `moon test src/passes` `3887/3887` with pre-existing warnings.
- Regular non-profile smoke `.tmp/pass-fuzz-optimize-casts-exact-local-smoke-100`: compared/normalized `100/100`, zero validation/generator/property/command failures, zero mismatches, Binaryen cache `100/0`.
- Dedicated aggregate smoke `.tmp/pass-fuzz-optimize-casts-genvalid-all-after-exact-local-smoke-100`: compared/normalized `100/100`, zero validation/generator/property/command failures, zero mismatches, Binaryen cache `98/2`. Selected leaves were `barriers=20`, `early-motion=18`, `best-cast=17`, `later-reuse=17`, `ref-as=12`, `static-folds=8`, and `neighborhood=8`.
- Agent classification: the previous tiny aggregate residual family was dominated by Starshine's nullable fresh-local workaround. That blocker is fixed for the current initialized-carrier shape, but this is still bounded smoke evidence rather than closeout.

Current dedicated aggregate scale-up evidence from 2026-07-03:

- Probe `.tmp/pass-fuzz-optimize-casts-genvalid-all-after-exact-local-1000`: requested/compared `1000/1000`, normalized `1000`, cleanup-normalized `0`, mismatches `0`, validation/generator/property/command failures `0`, Binaryen cache `1000/0`. Selected leaves were `later-reuse=255`, `early-motion=160`, `ref-as=149`, `best-cast=147`, `barriers=133`, `static-folds=89`, and `neighborhood=67`.
- Closeout-sized pass-specific lane `.tmp/pass-fuzz-optimize-casts-genvalid-all-after-exact-local-10000`: requested/compared `10000/10000`, normalized `10000`, cleanup-normalized `0`, mismatches `0`, validation/generator/property/command failures `0`, Binaryen cache `10000/0`. Selected leaves were `later-reuse=2323`, `early-motion=1560`, `best-cast=1518`, `barriers=1535`, `ref-as=1509`, `neighborhood=793`, and `static-folds=762`.
- Agent classification: the dedicated profile inventory and aggregate are now strong enough for the pass-specific GenValid closeout lane, with no residuals left to reduce in `optimize-casts-all` at `10000` cases.

Current non-dedicated lane refresh from 2026-07-03:

- Direct regular GenValid `.tmp/pass-fuzz-optimize-casts-after-exact-local-genvalid-10000`: requested/compared `10000/10000`, normalized `10000`, cleanup-normalized `0`, mismatches `0`, validation/generator/property/command failures `0`, Binaryen cache `102/9898`, selected profile `binaryen-oracle-portable=10000`.
- Explicit wasm-smith `.tmp/pass-fuzz-optimize-casts-wasm-smith-after-exact-local-1000`: requested `1000`, compared/normalized `997`, cleanup-normalized `0`, mismatches `0`, validation/generator/property failures `0`, command failures `3` classified as Binaryen/oracle tool failures (`binaryen-rec-group-zero=2`, `binaryen-invalid-tag-index=1`), wasm-smith cache `1000/0`, Binaryen cache `5/992`, Binaryen-failure cache `0/3`.
- Broad random profile `.tmp/pass-fuzz-optimize-casts-random-all-profiles-after-exact-local-1000`: requested/compared `1000/1000`, normalized `957`, mismatches `43`, validation/generator/property/command failures `0`, Binaryen cache `165/835`. All `43` raw mismatches came from `heap2local-ref` selected-profile cases.
- Agent classification for the broad residual: Starshine folds `drop(ref.test (ref (exact $0)) (struct.new_default $0))` to `drop(i32.const 1)` while Binaryen leaves the test. This is a source-backed Starshine static-fold win guarded by focused `ref.test` tests, not a behavior-parity gap; inspected failures were each `5` normalized-wasm bytes smaller for Starshine.


Current direct regular closeout from 2026-07-03:

- Direct regular GenValid `.tmp/pass-fuzz-optimize-casts-after-exact-local-genvalid-100000`: requested/compared `100000/100000`, normalized `100000`, cleanup-normalized `0`, mismatches `0`, validation/generator/property/command failures `0`, Binaryen cache `10329/89671`, no wasm-smith cache activity.
- Agent classification: the direct regular GenValid lane is now green at the required closeout scale.

Current broad random scale-up from 2026-07-03:

- Broad random profile `.tmp/pass-fuzz-optimize-casts-random-all-profiles-after-exact-local-10000`: requested/compared `10000/10000`, normalized `9580`, cleanup-normalized `0`, mismatches `420`, validation/generator/property/command failures `0`, Binaryen cache `2982/7018`. Selected profiles were `binaryen-oracle-portable=1703`, `ssa-nomerge-smoke=1699`, `pass-fuzz-stress=1691`, `ssa-nomerge-parity=1644`, `coverage-forced-portable=1610`, `heap2local-struct=715`, `heap2local-ref=484`, and `heap2local-array=454`.
- All `420` mismatches were from `heap2local-ref` and sampled failures matched the same guaranteed-true fresh exact-struct `ref.test` fold. A normalized-size sweep over all failure dirs with `wasm-opt --all-features --strip-debug` found Starshine exactly `5` bytes smaller in every mismatch.
- Agent classification: no new broad residual family appeared at `10000`; the broad residual is accepted for OC closeout as a source-backed, focused-test-guarded, measured Starshine static-fold win. No harness normalizer is added because that could hide unrelated future `ref.test` drift. Reopen broad closeout for any residual outside this exact fresh exact-struct `heap2local-ref` fold or for a non-winning size direction.

Current wasm-smith scale-up from 2026-07-03:

- Raw explicit wasm-smith lane `.tmp/pass-fuzz-optimize-casts-wasm-smith-after-exact-local-10000`: requested `10000`, compared `9956`, normalized `9955`, cleanup-normalized `0`, mismatches `1`, validation/generator/property failures `0`, command failures `44` classified as Binaryen/oracle tool failures (`binaryen-rec-group-zero=39`, `binaryen-bad-section-size=3`, `binaryen-invalid-tag-index=1`, `binaryen-table-index-out-of-range=1`), cache `wasm-smith 10000/0`, Binaryen `1098/8858`, Binaryen-failure `3/41`.
- Single raw mismatch: `case-009332-wasm-smith`, where Starshine leaves `drop(unreachable)` immediately before an `unreachable` and Binaryen removes it. Agent classification: cleanup debris, not an OC cast/refinement semantic mismatch.
- Supplementary replay `.tmp/pass-fuzz-optimize-casts-wasm-smith-after-exact-local-10000-unreachable-normalized` with `--normalize unreachable-control-debris`: requested `10000`, compared `9956`, normalized `9955`, cleanup-normalized `1`, mismatches `0`, validation/generator/property failures `0`, command failures `44` with the same Binaryen/oracle classes.
- Decision: accept the explicit wasm-smith lane with `--normalize unreachable-control-debris`; the normalizer is already covered by harness tests for adjacent `drop(unreachable)` before `unreachable`, and the residual is not OC cast/refinement behavior. Reopen for any residual after the normalizer, any OC-owned cast/refinement mismatch, any Starshine validation/generator/property failure, or a Starshine command-failure class.

Use the aggregate to guard future OC changes. The direct `100000`, dedicated `optimize-casts-all`, broad `random-all-profiles` with accepted static-fold win, and explicit wasm-smith with accepted unreachable-control-debris normalizer lanes are closeout-sized. The 2026-07-03 final source/docs review found no additional implementation-required `version_130` local-flow family for the v0.1.0 OC audit; remaining broader ideas are documented non-goals with reopening criteria.

Current timing and neighborhood evidence from 2026-07-03:

- Direct timing probe `.tmp/self-compare-optimize-casts-o4z-repro-after-exact-local` on `tests/repros/o4z-debug-startup-map-init-repro.wasm` with `--optimize-casts --timing-only`: canonical wasm equal; Starshine pass runtime `10.076ms`; Binaryen pass runtime `7.932ms`; Starshine is about `1.27x` Binaryen pass-local time, satisfying the pass-local `<= 2x` target.
- GC/local neighborhood probe `.tmp/self-compare-optimize-casts-o4z-neighborhood-after-exact-local` on the same repro with `--heap2local --optimize-casts --local-subtyping --coalesce-locals --local-cse --timing-only`: Starshine pass runtime `17.643ms`; Binaryen pass runtime `18.038ms`; both outputs validate; canonical wasm is not equal and Starshine's normalized wasm is `191380` bytes versus Binaryen `191059` bytes.
- Ordered prefix owner probe from the follow-up iteration: `--heap2local`, `--heap2local --optimize-casts`, and `--heap2local --optimize-casts --local-subtyping` were canonical-equal with zero size delta (`192893` / `192893` each). The first canonical/size drift appeared when adding `--coalesce-locals`: `.tmp/self-compare-oc-neighborhood-prefix-04-h2l-oc-ls-cl` had Starshine `191381` bytes versus Binaryen `191062` (`+319`), and the full `+ --local-cse` prefix `.tmp/self-compare-oc-neighborhood-prefix-05-h2l-oc-ls-cl-lcse` had Starshine `191380` versus Binaryen `191059` (`+321`). Both drifted prefixes validate on both sides.
- Agent classification: timing is acceptable and the checked-in O4z neighborhood drift is localized to the neighboring `coalesce-locals` slot, not to direct `optimize-casts` or the `heap2local -> optimize-casts -> local-subtyping` prefix. Track the remaining size/shape owner under neighboring GC/local cleanup work unless a reduction shows OC seeded the later coalescing difference.

## Closeout status

As of 2026-07-03, the OC fuzz inventory is complete enough for the v0.1.0 direct-pass audit. Refresh the full matrix after any OC behavior change, and reopen closeout only for:

- any direct or dedicated `optimize-casts-all` mismatch;
- a broad/random residual outside the guaranteed-true fresh exact-struct `heap2local-ref` `ref.test` fold, or the same family becoming size-neutral/size-losing for Starshine;
- an explicit wasm-smith residual after `--normalize unreachable-control-debris`, any cast/refinement-owned wasm-smith mismatch, or a Starshine-specific command failure;
- source/lit drift that adds a reasonable Binaryen local-flow family not represented by the current leaves.
