---
kind: entity
status: working
last_reviewed: 2026-07-11
sources:
  - ../../../raw/binaryen/2026-07-11-inlining-current-main-toolchain-inline-hints-recheck.md
  - ../../../raw/research/1551-2026-07-05-inlining-optimizing-o4z-audit.md
  - ../../../raw/binaryen/2026-04-25-inlining-optimizing-current-main-implementation-test-map.md
  - ../../../raw/binaryen/2026-06-02-binaryen-v125-current-trunk-release-horizon.md
  - ../../../raw/binaryen/2026-04-23-inlining-optimizing-primary-sources.md
  - ../../../raw/binaryen/2026-04-23-inlining-primary-sources.md
  - ../../../raw/research/0725-2026-06-15-inlining-optimizing-cache-followup.md
  - ../../../raw/research/0724-2026-06-15-inlining-optimizing-wall-time-root-cause.md
  - ../../../raw/research/0723-2026-06-15-inlining-optimizing-behavior-inventory.md
  - ../../../raw/research/0557-2026-05-12-inlining-wiki-overhaul.md
  - ../../../raw/research/0361-2026-04-25-inlining-optimizing-current-main-and-test-map.md
  - ../../../raw/research/0121-2026-04-20-inlining-optimizing-binaryen-research.md
  - ../../../raw/research/0271-2026-04-23-inlining-optimizing-primary-sources-and-starshine-followup.md
  - ../../../../../src/passes/inlining.mbt
  - ../../../../../src/passes/inlining_test.mbt
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../agent-todo.md
related:
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./planning-partial-inlining-and-reruns.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
  - ../inlining/index.md
  - ../dae-optimizing/index.md
  - ../duplicate-function-elimination/index.md
  - ../precompute-propagate/index.md
---

# `inlining-optimizing`

## Role

`inlining-optimizing` is Binaryen's late whole-module inliner with immediate post-inline cleanup. It uses the same upstream `src/passes/Inlining.cpp` engine as plain [`../inlining/index.md`](../inlining/index.md), then enables the optimizing suffix: `precompute-propagate` plus the default function optimization pipeline on changed functions.

Current Starshine status: **completed for the v0.1.0 audit scope, implemented as a partial active module pass**. It is not boundary-only anymore; the current supported direct-call surfaces are accepted under former `[INL]001` and plain `[INL]007`, and `[INL]002` is accepted as representation/factoring drift rather than exact artifact parity. The shared owner is [`src/passes/inlining.mbt`](../../../../../src/passes/inlining.mbt); remaining direct-inliner breadth is v0.2.0-only under `[INL]005` and residual `[INL]006`, while `[INL]003` is accepted for current heuristic/action-filtering parity in [`agent-todo.md`](../../../../../agent-todo.md).

## Why it matters

- This is the inlining variant on the canonical no-DWARF late optimize path, after `dae-optimizing` and before `duplicate-function-elimination`.
- The saved generated-artifact `-O4z` audit recorded it as top-level slot `49`.
- The saved Binaryen debug log shows nested cleanup under this single top-level pass: repeated `precompute-propagate`, `ssa-nomerge`, `code-folding`, `local-cse`, and `merge-blocks` before Binaryen moves to `duplicate-function-elimination`.
- Current Starshine has accepted direct-call and nested-scheduler subsets for the current supported surface, but future agents still need a clear distinction between accepted representation drift and deferred unsupported Binaryen obligations such as partial splitting, broader tail-call repair, multi-result typing, and full name/annotation repair.

## Beginner summary

A safe mental model:

1. Run the whole-module inliner: summarize functions, classify callees, plan direct callsites, rewrite copied bodies, repair locals/control/types, delete dead private helpers.
2. Record exactly which functions changed.
3. Run the useful cleanup sequence on those touched functions only.
4. Continue into the late function-graph cleanup tail.

That is much closer to reality than “more aggressive inlining.”

## Current durable takeaways

- A 2026-06-15 wall-time investigation found and fixed the severe self-optimization spin: `inl_original_reachable_private_cycle_funcs(...)` repeatedly ran recursive graph reachability with fresh `seen` arrays across thousands of functions. An iteration-local transitive reachability table first reduced the traced debug-CLI artifact `pass:inlining-optimizing` timer from `690.716s` to `41.091s` (`~16.8x`). A same-day follow-up cached same-signature/dead-suffix preservation facts, deferred original-reachability prediction until after changed-callsite detection, and cached per-helper function signature keys; `.tmp/self-opt-inlining-final-perf.stderr` reduced the same pass timer to `3.528s`, with no remaining traced inlining subphase in the 10s range. Nested cleanup was confirmed skipped by the `>80` defined-function guard on the artifact.
- A 2026-06-15 behavior inventory refreshed the comparison against local `wasm-opt version 130 (version_130)` and upstream Binaryen `version_130` sources. The basic direct-call eligibility thresholds still line up with Binaryen's defaults; the largest differences are Starshine's broader `try_table` conservatism, no partial-inlining splitter, partial tail-call/name/nondefaultable-local repair, hand-expanded optimizing suffix, large-module suffix guard, and Starshine-only unreachable-cycle prediction/trim scaffolding.
- The core inliner is module-level boundary work, not HOT-local peepholing.
- Reviewed `version_129` chosen inline actions are direct `call` / `return_call` based; `ref.func` and ref/indirect calls remain relevant to survival and repair. The 2026-07-11 current-main reread adds a shared-engine full-inline policy input: after the `try_delegate` bailout, a function-level toolchain `NeverInline` rejects and `AlwaysInline` accepts full inlining before ordinary profitability thresholds. This does not establish Starshine support or a generic `@metadata.code.inline` producer; see [`../inlining/compilation-hints-vs-no-inline-flags-and-clone-survival.md`](../inlining/compilation-hints-vs-no-inline-flags-and-clone-survival.md).
- The optimizing suffix is part of the public contract, not optional polish.
- Starshine's current cleanup suffix is an approximation: trace marker plus private touched-only `precompute-propagate-prefix`, followed by a touched-function filtered Starshine cleanup lane that now drops the former extra pre-default `precompute`, gates the option-controlled cleanup slots to their Binaryen optimize/shrink thresholds, and includes the early second `remove-unused-names`, option-gated `merge-locals`, local `reorder-locals`, late local cleanup cluster, `code-folding`, option-gated `redundant-set-elimination`, and final `vacuum` slots, not exact Binaryen filtered public `precompute-propagate` + option-specific default function pipeline. It is skipped for modules above the local large-module threshold (`80` defined functions), so the current self-optimization wall-time cliff is more suspicious in the pre/surrounding module-level graph, prediction, scan, rewrite, and iteration phases than in the generic nested suffix alone.
- `[INL]003` is accepted for the current shared heuristic/action-filtering surface: shrinking-trivial parameter-passthrough wrappers, direct-call wrappers, memory/table/SIMD/GC operation wrappers, O3/no-shrink no-direct-call/no-loop flexible inlining, direct-call-only `hasCalls`, combined-size filtering, same-wave guards, and the five-iteration repeated-work cap are all covered.
- Latest `[INL]003` optimizing closeout evidence is `.tmp/pass-fuzz-inlining-optimizing-inl003-after-repeated-cap-10000`: `9975/10000` compared, `9975` matches, `0` mismatches, `0` validation failures, and `25` ignored Binaryen/tool command failures.
- Latest `[INL]002` closeout evidence is `.tmp/pass-fuzz-inlining-optimizing-inl002-closeout-10000-keep`: `9975/10000` compared, `9975` matches, `0` mismatches, `0` validation failures, and `25` ignored Binaryen/tool command failures. Debug-artifact direct replay no longer aborts and validates in `.tmp/inl002-puresuffix-only-20260516-002821`; the remaining artifact mismatch is accepted representation/factoring drift, with Starshine currently smaller by raw wasm/code-section/WAT/static node metrics. Do not reopen `[INL]002` for cosmetic canonical drift alone.
- The 2026-07-05 O4z audit kept `[INL]005` partial splitting and residual `[INL]006` name/annotation repair deferred. Its main evidence-tooling outcome is the new focused `inlining-optimizing-all` GenValid aggregate, not a shallow mix of existing broad `pass-inlining`/cleanup/precompute profiles. The aggregate samples `direct-wrapper`, `param-spill`, `return-call`, and `cleanup-payoff` leaves; emit-batch smoke generated 8 validating inputs with non-null manifest profile-case labels, focused compare lanes reached `20/20` and `1000/1000` normalized matches with zero failures/mismatches, and the required pass-specific lane `.tmp/pass-fuzz-inlining-optimizing-all-focused-10000` reached `10000/10000` normalized matches with zero failures/mismatches. The explicit wasm-smith closeout lane `.tmp/pass-fuzz-inlining-optimizing-wasm-smith-10000` compared `9956/10000` with `9953` normalized matches, `3` raw mismatches, no Starshine/generator/validation/property failures, and `44` Binaryen/oracle command failures; the three raw mismatches are classified as Starshine-win / accepted cleanup drift because they are no-call/no-effect local/const/nop/dead-local cleanup cases that validate, shrink, and converge to identical 8-byte downstream `-Oz --strip-debug --all-features` wasm. The existing `pass-inlining` GenValid profile remains narrowed to scalar direct-call smoke inputs so generated cases pass the compare harness' wasm-tools validation gate; ref/GC survival coverage still belongs in future focused leaves. The first seed-`0x1e11e` scalar-profile mismatch is classified as Starshine-win / accepted cleanup drift: Starshine removes pure dropped-expression and unreachable-tail debris after all direct calls disappear, runtime replay equal-traps, downstream `-Oz` converges both outputs to identical `59`-byte wasm, and this does not reopen `[INL]005` or `[INL]006`. A small ordinary default GenValid lane `.tmp/pass-fuzz-inlining-optimizing-ordinary-20-20260705-triage` completed `20/20` with `20` sampled no-call `binaryen-oracle-portable` cleanup-only mismatches; those sampled cases are likewise classified as Starshine-win / accepted cleanup drift based on no-call/no-side-effect facts, validation, case-1 runtime equal-trap replay, sampled size wins, and downstream `-Oz` convergence. Random-all is now accepted for the current v0.1.0 scope after exhaustive downstream convergence and runtime spot checks; the 2026-07-05 triage also found and fixed one real robustness bug. The original `random-all-profiles` attempts timed out without summaries because broad other-profile cleanup-debris mismatches triggered expensive GenValid reduction for every case. After adding compare-pass `--no-reduce-mismatches`, a 1000-case normalized random-all triage lane completed and exposed four `coverage-forced-portable` Starshine aborts in final `reorder-locals` cleanup. `reorder-locals` now fails closed on stale/out-of-range local accesses so inlining's validate-or-fallback path can discard invalid cleanup candidates; the four saved cases replay with exit `0` and valid output. The refreshed lane `.tmp/pass-fuzz-inlining-optimizing-random-all-profiles-1000-noreduce-allnorm-fixed1-20260705` completed `1000/1000` with `7` normalized matches, `105` cleanup-normalized matches, `888` raw mismatches, and zero generator/validation/property/command failures. Follow-up sampling inspected the first raw mismatch from each remaining raw-mismatch profile (`coverage-forced-portable`, `ssa-nomerge-*`, `pass-fuzz-stress`, `binaryen-oracle-portable`, `local-subtyping-*`, `heap2local-struct`, and `coalesce-locals-*`). All 11 sampled Binaryen/Starshine raw and canonical outputs validate; visible diffs are pure dropped-expression/control preludes, dead local declarations, no-effect local copy/drop chains, GC temp elision around dropped allocation, heap2local self-copy/dead-local cleanup, and local renumbering; Starshine is smaller in every sampled raw/canonical pair; and shared downstream `wasm-opt --all-features -Oz --strip-debug` converges all 11 pairs to identical wasm. Node runtime replay is partial only (`case-000002` and `case-000003` all-equal, `case-000001` runtime-unsupported, and `case-000004` timed out before evidence), so agent classification for these samples is Starshine-win / accepted cleanup drift but not profile-wide closeout. A later compare-normalizer tightening for pure float/signed-conversion debris plus standalone empty const-if debris made ordinary GenValid actionable: `.tmp/pass-fuzz-inlining-optimizing-ordinary-10000-allnorm-purefloat-20260705` compared `10000/10000` with `10000` cleanup-normalized matches and zero mismatches/failures. The current regular GenValid final lane `.tmp/pass-fuzz-inlining-optimizing-ordinary-100000-allnorm-tailguard-20260705` now completes `100000/100000` with `100000` cleanup-normalized matches, `0` mismatches, and zero failures. The first full random-all 10000 all-normalizer attempt exposed one true validation failure (`coverage-forced-portable case-004369`, stale `return_call` local remap: expected `f32`, found `i64`); Starshine now fails closed by skipping nested/final local cleanup on tail-call modules until that interaction has a narrower type-aware repair, and the saved case replays green. Current random-all `.tmp/pass-fuzz-inlining-optimizing-random-all-profiles-10000-allnorm-tailguard-20260705` completes `10000/10000` with `1250` normalized, `3490` cleanup-normalized, `5260` raw local-allocation/renumbering mismatches, and zero failures; remaining raw profiles are `ssa-nomerge-*`, `coalesce-locals-*`, `local-subtyping-*`, and `heap2local-struct`. The broad local families are accepted as cleanup/representation drift for the current v0.1.0 scope after exhaustive downstream convergence and runtime spot checks; use `_build/native/release/build/cmd/cmd.exe` for refreshed native compare lanes.
- A 2026-07-05 performance follow-up corrected the closeout bar to the user's stricter `1x` Binaryen requirement and fixed a synthetic IO nested-cleanup scaling cliff. The durable timing fixture `.tmp/io-perf-20260705/measure_io_perf.py` compares Starshine `--tracing pass --inlining-optimizing` pass-local time with Binaryen `BINARYEN_PASS_DEBUG=1 wasm-opt --all-features --inlining-optimizing` on inline-heavy helper chains. Before repair, `20` helpers took Starshine ~`82ms` vs Binaryen ~`0.93ms`, and `50` helpers timed out after `>20s`; trace attribution pointed to nested `optimize-instructions` sign-extension local-write scanning after `simplify-locals-nostructure` made nested block chains. Starshine now uses linear seen-set marking in `optimize-instructions`, a raw `simplify-locals` accumulator-chain peephole, and an early inlining-optimizing touched-function fast path for the pure i32 accumulator shape. Post-fix medians in `.tmp/io-perf-20260705/measurements/summary.json` meet `Starshine <= Binaryen` for `1`, `5`, `10`, `20`, `50`, and `100` helpers (`0.443x`, `0.735x`, `0.797x`, `0.970x`, `0.535x`, `0.246x` respectively). Focused tests, full `moon test`, pass-specific `10000/10000` normalized compare, and ordinary all-normalizer `10000/10000` compare are green; reopen on fixture median regression above `1x` or a new nested-cleanup scaling cliff.
- A later 2026-07-05 follow-up reran the explicit wasm-smith lane after the tail-call guard: `.tmp/pass-fuzz-inlining-optimizing-wasm-smith-10000-tailguard-20260705` still compares `9956/10000` with `9953` normalized matches, `3` raw cleanup-drift mismatches, no Starshine/generator/validation/property failures, and the same `44` Binaryen/oracle command failures, all from cache. Downstream `wasm-opt --all-features -Oz --strip-debug` reconverged the three raw wasm-smith mismatches to identical 8-byte wasm. The same follow-up broadened random-all classification with `.tmp/io-random-all-tailguard-downstream-oz-sample50-20260705`: first `50` raw mismatches from each of the eight remaining local-allocation/renumbering profiles (`400` total) all converged to identical downstream `-Oz --strip-debug` wasm; local-subtyping `case-000229` also replayed under Node as `all-equal`. The exhaustive follow-up `.tmp/io-random-all-tailguard-downstream-oz-all-20260705` then checked all `5260` remaining raw random-all mismatches and all `5260/5260` converged to identical downstream wasm. Per-profile convergence was complete across `ssa-nomerge-parity`, `ssa-nomerge-smoke`, `local-subtyping-straight-line`, `coalesce-locals-straight-line`, `heap2local-struct`, `local-subtyping-structured`, `coalesce-locals-structured`, and `coalesce-locals-loop-copy-through`. Downstream output sizes were stable at `35` bytes for `ssa-nomerge-*` and `34` bytes for the other six profiles; `207` local-subtyping cases are raw-size-losing before downstream cleanup, so the classification is not a size win. Six size-losing local-subtyping replays (`case-000085`, `000101`, `000205`, `000229`, `000237`, and `000253`) ran under Node as `all-equal`. Agent classification: accepted cleanup/representation drift, with reopening criteria for any validation failure, downstream-convergence failure, runtime semantic mismatch, unexplained size loss without downstream convergence/measured win, new side effects in the residual family, or a reduced concrete inlining/touched-cleanup transform gap.

## Current Starshine evidence

Current v0.1.0 INL audit status: complete/accepted. Reopen only for a new validation failure, downstream-convergence failure, runtime semantic mismatch, unexplained size loss without downstream convergence or measured win, new side effects in the residual random-all family, a reduced concrete inlining/touched-cleanup transform gap, or regression of the documented 1x Binaryen timing fixture.

Standard seed lane, `.tmp/pass-fuzz-inlining-seed-0x5eed-after-four-func-frontier`:

- seed `0x5eed`;
- `9975 / 10000` compared;
- `9975` normalized matches;
- `0` normalized mismatches;
- `0` validation failures;
- `0` generator failures;
- `25` ignored Binaryen/tool parse/canonicalization command failures:
  - `22` `binaryen-rec-group-zero`;
  - `1` `binaryen-bad-section-size`;
  - `1` `binaryen-table-index-out-of-range`;
  - `1` `binaryen-invalid-tag-index`.

Broadened closure lane, `.tmp/pass-fuzz-inlining-seed-0x1eed-after-four-func-frontier2`:

- seed `0x1eed`;
- `9978 / 10000` compared;
- `9978` normalized matches;
- `0` normalized mismatches;
- `0` validation failures;
- `0` generator failures;
- `22` ignored Binaryen/tool `binaryen-rec-group-zero` parse failures;
- `0` Starshine command failures; `case-008100-gen-valid` replays green in `.tmp/pass-fuzz-inlining-seed-0x1eed-replay-case008100-narrow-hotunsafe`.

The old seed-`0x5eed` exact-`unreachable` helper frontier and the broadened seed-`0x1eed` four-function frontier are retired. `[INL]001` is accepted for the current supported optimizing direct surface, `[INL]002` is accepted for v0.1.0 as representation/factoring drift, `[INL]007` is accepted for the current supported plain direct surface, and `[INL]003` is closed for the current supported heuristic/action-filtering surface. Deferred unsupported direct-inliner breadth belongs to the v0.2.0 backlog under `[INL]005` and residual `[INL]006`; do not treat those as active v0.1.0 blockers.

## Page map

- [`./deferred-inl005-inl006-work.md`](./deferred-inl005-inl006-work.md) - durable record of partial-splitting work not done under `[INL]005` and residual local/label-name repair not done under `[INL]006`.
- [`./binaryen-strategy.md`](./binaryen-strategy.md) - upstream strategy with the optimizing suffix centered.
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md) - Binaryen owner/helper/test map and current Starshine code/test map.
- [`./planning-partial-inlining-and-reruns.md`](./planning-partial-inlining-and-reruns.md) - focused planner/root/partial/rerun explainer.
- [`./wat-shapes.md`](./wat-shapes.md) - WAT shape catalog including cleanup payoff and current gaps.
- [`./starshine-strategy.md`](./starshine-strategy.md) - active partial implementation status.
- [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md) - evidence ledger, remaining slices, and acceptance criteria.

## Maintenance rule

Update this folder whenever the shared inliner changes. Current v0.1.0 signoff accepts the implemented core and nested cleanup approximation with documented representation/factoring drift; future universal Binaryen inliner parity work must remain explicit v0.2.0+ backlog unless new correctness evidence appears. Binaryen/tool parse/canonicalization failures must stay classified separately from Starshine semantic mismatches.
