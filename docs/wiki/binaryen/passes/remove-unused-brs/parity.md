---
kind: comparison
status: working
last_reviewed: 2026-04-18
sources:
  - ../../../raw/research/0070-2026-03-27-remove-unused-brs-binaryen-comparison.md
  - ../../../raw/research/0093-2026-04-18-generated-o4z-pass-audit-summary.md
  - ../../../raw/research/0094-2026-04-18-generated-o4z-rub-slot14-missing-i32-result.md
  - ../../../raw/research/0101-2026-04-18-generated-o4z-rub-slot14-native-source-divergence.md
  - ../../../raw/research/0102-2026-04-18-generated-o4z-rub-slot14-if-br-large-condition-guard.md
  - ../../../raw/research/0099-2026-04-18-generated-o4z-rub-slot40-block-stack-leak.md
  - ../../../raw/research/0071-2026-03-28-remove-unused-brs-hot-lift-shapes.md
  - ../../../raw/research/0076-2026-04-10-remove-unused-brs-br-table-carried-wrapper-parity.md
  - ../../../raw/research/0077-2026-04-10-remove-unused-brs-large-result-br-table-noop-skip.md
  - ../../../raw/research/0078-2026-04-10-remove-unused-brs-false-prefix-guard-raw-skip.md
  - ../../../raw/research/0079-2026-04-10-remove-unused-brs-mid-unique-tee-floor.md
  - ../../../raw/research/0079-2026-04-11-pass-fuzz-health-round-two.md
  - ../../../raw/research/0080-2026-04-10-remove-unused-brs-large-brtable-hot-skip.md
  - ../../../raw/research/0081-2026-04-10-remove-unused-brs-large-value-if-branch-raw-skip.md
  - ../../../raw/research/0082-2026-04-10-remove-unused-brs-large-tagged-result-prefix-hot-skip.md
  - ../../../raw/research/0083-2026-04-10-remove-unused-brs-large-typed-brtable-encoder-raw-skip.md
  - ../../../raw/research/0084-2026-04-10-remove-unused-brs-brtable-one-arm-payload-parity.md
  - ../../../raw/research/0085-2026-04-10-remove-unused-brs-drop-heavy-local-set-floor.md
  - ../../../raw/research/0086-2026-04-13-remove-unused-brs-medium-branchy-hot-skip.md
  - ../../../raw/research/0087-2026-04-13-remove-unused-brs-call-heavy-mixed-if-mesh-hot-skip.md
  - ../../../raw/research/0088-2026-04-13-remove-unused-brs-localset-heavy-value-if-mesh-hot-skip.md
  - ../../../../../src/ir/hot_core.mbt
  - ../../../../../src/ir/hot_mutate.mbt
  - ../../../../../src/passes/remove_unused_brs.mbt
  - ../../../../../src/passes/remove_unused_brs_test.mbt
  - ../../../../../src/passes/perf_test.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/passes/optimize_test.mbt
  - ../../../../../src/cmd/cmd_wbtest.mbt
  - ../../../../../agent-todo.md
related:
  - ./pattern-catalog.md
  - ./binaryen-strategy.md
  - ./starshine-hot-ir-strategy.md
  - ./returned-ladder-hot-shapes.md
  - ./visit-order-and-bailouts.md
---

# `remove-unused-brs` Binaryen Parity

## Durable Conclusions

- Binaryen's `RemoveUnusedBrs` is phase-driven and Starshine now mirrors a meaningful subset of that structure.
- The current tree already covers much more than dead tail stripping:
  - tail `br` / `return` elimination
  - one-armed `if` to `br_if`
  - two-armed branch-exit cleanup
  - block-local chain flattening
  - value-`if` to `select`
  - local-set arm cleanup
  - branch-payload `if` cleanup
  - carried-guard/result-block cleanup
  - repeated-constant `br_if` ladders to `br_table`
- The old early artifact-backed carried-wrapper gap is now fixed:
  - Starshine retargets `br_table` continuation-wrapper arms directly to the outer exit
  - the dead forwarding tails now lower to `unreachable` like Binaryen
- The direct one-arm payload branch rewrite now has a hard parity boundary too:
  - if a function contains any `br_table`, Starshine leaves that direct one-arm payload `if` intact
  - the reduced `Func 3771` family proves Binaryen keeps that shape conservative instead of lowering it to `drop(br_if ...)`
- The next large artifact no-op family is now retired too:
  - the raw layer skips very large one-result `br_table` dispatch ladders before lift
  - the retired hotspot pair `Func 1219` / `Func 1220` now both report `skip-raw reason=large-result-br-table-dispatch-ladder-noop`
- The raw structured-return skip is now narrower too:
  - false prefix-guard candidates no longer cancel the raw skip when the inner prefix already contains a separate void root before the later `br_if`
  - the new perf regression proves that the reduced false-positive family now skips raw instead of lifting and mutating in HOT
- The unique loop/select raw skip is now slightly wider too:
  - the tee floor now accepts mid-band sixteen-tee ladders instead of requiring twenty tees
  - the artifact follow-up shows that this reclassifies `Func 1171`, not the live `Func 1150` hotspot
- The hot layer now has its own later no-op retirement:
  - lifted large `br_table` / return ladders with no `br_if` now report `skip-hot reason=large-br-table-return-ladder-noop`
  - the traced unchanged hotspot pair `Func 1058` / `Func 1150` is now retired, and the same family also catches `Func 71`
- The raw layer now has a later tiny-local retirement too:
  - deep value-`if` / bare-`br` ladders with nearly one-for-one `if` / `br` traffic now report `skip-raw reason=large-value-if-branch-ladder-noop`
  - the traced unchanged artifact hotspot `Func 828` / `hot__lift__impl__exact__family` is now retired before lift
- The hot layer now has a later tagged result-prefix retirement too:
  - lifted large carried result-prefix ladders with many non-`Block` prefix roots now report `skip-hot reason=large-tagged-result-prefix-ladder-noop`
  - the traced unchanged artifact hotspot `Func 356` / `dfe__try__rewrite__instruction__type__idxs` is now retired after lift
- The raw layer now has a later typed `br_table` encoder retirement too:
  - deep mixed value/void block shells around a single `br_table` encoder ladder now report `skip-raw reason=large-typed-br-table-encoder-ladder-noop`
  - the traced unchanged lift-heavy artifact hotspot `Func 1482` is now retired before lift
- The raw layer now has a later drop-heavy branch retirement too:
  - large-local no-`select` / no-`br_if` / no-`br_table` branch ladders now report `skip-raw reason=large-drop-heavy-branch-ladder-noop`
  - the traced unchanged artifact hotspot `Func 145` is now retired before lift after calibrating the classifier to the real `local_set=201` body instead of the first reduced-only floor
- The later hot layer now has another lifted no-op retirement too:
  - the later call-heavy mixed-if mesh family now reports `skip-hot reason=call-heavy-mixed-if-mesh-noop`
  - the traced unchanged artifact cluster `Func 408`, `Func 413`, `Func 739`, `Func 832`, `Func 902`, `Func 1022`, `Func 1448`, and `Func 1815` is now retired after lift
- The next hot layer follow-up now has one more lifted no-op retirement too:
  - the later localset-heavy value-if mesh family now reports `skip-hot reason=localset-heavy-value-if-mesh-noop`
  - the traced unchanged artifact cluster `Func 837`, `Func 3021`, `Func 3120`, `Func 3130`, and `Func 3134` is now retired after lift
- Newer upstream evidence now matters explicitly too: the Chromium-hosted Binaryen mirror shows a 2026-02-27 `RemoveUnusedBrs` change that rewrites branches-to-traps directly to traps. That behavior is newer than this repo's older `version_129` Binaryen oracle, so treat it as trunk drift to reconcile deliberately instead of assuming the current Starshine parity target already includes it.
- The early ordered generated-artifact slot-14 corruption is now fixed too:
  - the slot-13 predecessor replay no longer emits the invalid `func 1354` raw output
  - the extracted `Func 1354` replay is now locked by an external `wasm-tools validate` cmd wbtest instead of only the in-tree decode path
  - Starshine now keeps the plain-`br` `if -> br_if` cleanup disabled when a large lifted function (`hot_node_count >= 256`) would need to reorder a non-reorder-safe condition
  - that guard is deliberately conservative: Binaryen already keeps a valid block-plus-branch shape on the extracted slot-14 oracle input, and the old Starshine rewrite was emitting invalid wasm there
- The remaining artifact work is not a generic "RUB still weak on branches" statement.
- The remaining work is now concentrated in later shape families where:
  - the explicit compare still contains early type-order noise that may not be RUB logic at all
  - later loop/block-order or body-order differences still need mutation-backed reduction
  - the latest traced runtime split is now led by `Func 497`, `Func 1168`, `Func 229`, `Func 990`, `Func 883`, and `Func 1213` on the unchanged pass-heavy side while `Func 1382` remains the older lift-heavy outlier
  - some remaining normalized-WAT differences may still be lift/lower round-trip noise if the trace still reports `changed=false`

## Current Coverage Surface

- Focused correctness coverage:
  [`../../../../../src/passes/remove_unused_brs_test.mbt`](../../../../../src/passes/remove_unused_brs_test.mbt)
- Perf and bailout coverage:
  [`../../../../../src/passes/perf_test.mbt`](../../../../../src/passes/perf_test.mbt)
- Raw pre-lift behavior:
  [`../../../../../src/passes/pass_manager.mbt`](../../../../../src/passes/pass_manager.mbt)
- Preset replay coverage for the three modeled RUB slots:
  [`../../../../../src/passes/optimize_test.mbt`](../../../../../src/passes/optimize_test.mbt)
- CLI and artifact replay coverage:
  [`../../../../../src/cmd/cmd_wbtest.mbt`](../../../../../src/cmd/cmd_wbtest.mbt)
- New upstream drift watch:
  Binaryen Chromium mirror commit `42f1f12ad89d0329f70d5c4ae5ecb7f7889034c0` (`2026-02-27`) rewrites branches-to-traps directly to traps, but this repo has not yet re-baselined the living RUB parity target around that newer behavior.

## What Is Already In Good Shape

- Scheduler parity:
  `optimize` and `shrink` both replay RUB in three top-level slots, and that is covered by focused preset tests.
- Gen-valid compare-pass evidence:
  the current backlog records clean `100`, `1000`, and `10000` case `gen-valid` lanes with zero mismatches.
- Mixed-generator compare evidence:
  the current saved runs are still clean on compared cases and stop mainly on Binaryen-side command failures rather than Starshine semantic mismatches.
- Artifact validation:
  the native `cmd` replay for `--remove-unused-brs` now validates the checked-in debug artifact in-memory.
- Specific fixed families called out by the backlog:
  - explicit `nop` body preservation in trivial `if` arms
  - lone explicit root `nop` preservation
  - non-trailing root `nop` preservation during RUB writeback
  - dead `local.tee` + `drop` root preservation during RUB writeback
  - dropped then-arm carried-result wrapper cleanup
  - prefixed one-arm payload branch suffix cleanup
  - direct one-arm payload branch preservation inside `br_table` functions
  - carried-suffix wrapper recognition through Binaryen's parser path
  - self-target if-arm block-branch sinking
  - raw structured-return-ladder false-positive skipping
  - raw false-prefix guard cancellation inside structured-return ladders
  - `br_table` continuation-wrapper retargeting to the outer exit
  - raw skipping of large result `br_table` dispatch ladders with no HOT-only surface
- New mixed-generator evidence is still clean on compared cases:
  - `.tmp/pass-fuzz-rub-20260410-final-500` completed `499/499` compared matches
  - `0` mismatches, `0` validation failures, `0` generator failures
  - the only failure was the known Binaryen-side `binaryen-rec-group-zero` parser class
- New post-skip parity evidence is also clean:
  - `.tmp/pass-fuzz-rub-genvalid-20260410-large-brtable-skip-10000` completed `10000/10000` compared matches with `0` mismatches and no validation, generator, or command failures
  - `.tmp/pass-fuzz-rub-genvalid-20260410-false-prefix-guard-10000` also completed `10000/10000` compared matches with `0` mismatches and no validation, generator, or command failures
  - `.tmp/pass-fuzz-rub-genvalid-20260410-unique-tee16-10000` also completed `10000/10000` compared matches with `0` mismatches and no validation, generator, or command failures
  - `.tmp/pass-fuzz-rub-20260410-large-brtable-skip-cheapguard-10000` stayed clean on all `1398/1398` compared mixed-generator cases before the usual Binaryen-side command failures
- New explicit artifact replay evidence is faster but still not exact:
  - `.tmp/self-opt-rub-20260410-large-brtable-skip-cheapguard-idle` measured `651.284 ms` Starshine pass time versus `91.882 ms` Binaryen
  - canonical wasm and normalized WAT still differ
- The later noop-writeback parity cleanup is also green on fresh focused lanes:
  - `.tmp/pass-fuzz-rub-codex-genvalid-100-after-noop-fix` completed `100/100` compared matches with `0` mismatches, `0` validation failures, `0` generator failures, and `0` command failures
  - `.tmp/pass-fuzz-rub-codex-120-after-root-nop-fix` stayed clean on all `119/119` compared mixed-generator cases before the known Binaryen-side `binaryen-rec-group-zero` parser failure
- New trace-only evidence after the false-prefix fix is directionally better:
  - `.tmp/rub-trace-false-prefix-guard-idle.stderr` drops traced RUB pass total from `671669 us` to `668850 us`
  - traced lift total drops from `931152 us` to `878726 us`
  - `Func 1058` improves, but `Func 1150` remains the current top traced pass hotspot
- The follow-on tee-floor trace is narrower than it first looked:
  - `.tmp/rub-trace-mid-unique-tee16-idle.stderr` shows `Func 1171` moving from `structured-return-ladder-noop` to `unique-loop-select-return-ladder-noop`
  - `Func 1150` still lifts as `wt__lower__module` and only reports `rub-result-prefix reject=inner-op block=2923 op=LocalSet`
  - `Func 1058` still lifts and reports the same result-prefix reject pair
  - the total trace is not a clean win (`682234 us` pass, `963261 us` lift), so this slice should be treated as classifier coverage, not hotspot retirement
- The new large-`br_table` hot skip is both parity-clean and artifact-positive:
  - `.tmp/pass-fuzz-rub-genvalid-20260410-large-brtable-hotskip-10000-serial` completed `10000/10000` compared matches with `0` mismatches, `0` validation failures, `0` generator failures, and `0` command failures
  - `.tmp/pass-fuzz-rub-both-20260410-large-brtable-hotskip-2000` stayed clean on all `848/848` compared mixed-generator cases before `5` Binaryen-side command failures
  - `.tmp/rub-trace-large-brtable-hotskip-v2-idle.stderr` drops traced RUB pass total from `682234 us` to `654407 us`
  - the same trace drops traced lift total from `963261 us` to `917148 us`
  - `Func 1058` now reports `skip-hot reason=large-br-table-return-ladder-noop` with `pass=450 / lift=6387`
  - `Func 1150` now reports the same reason with `pass=1054 / lift=16635`
- The later raw value-`if` / branch skip is also parity-clean and artifact-positive:
  - `.tmp/pass-fuzz-rub-genvalid-20260410-large-value-if-branch-10000` completed `10000/10000` compared matches with `0` mismatches, `0` validation failures, `0` generator failures, and `0` command failures
  - `.tmp/pass-fuzz-rub-both-20260410-large-value-if-branch-2000` stayed clean on all `846/846` compared mixed-generator cases before `5` Binaryen-side command failures
  - the mixed-generator failure classes were still Binaryen-side only: `1` `binaryen-command-failed` plus `4` `binaryen-rec-group-zero`
  - `.tmp/rub-trace-large-value-if-branch-ladder-idle.stderr` drops traced RUB pass total from `654407 us` to `601957 us`
  - the same trace drops traced lift total from `917148 us` to `794557 us`
  - `Func 828` now reports `skip-raw reason=large-value-if-branch-ladder-noop`
  - the next visible pass-heavy target after that slice was `Func 356` at `pass=8317 / lift=4956`
- The later tagged result-prefix hot skip is parity-clean and retires that next hotspot:
  - `.tmp/pass-fuzz-rub-genvalid-20260410-large-tagged-prefix-10000` completed `10000/10000` compared matches with `0` mismatches, `0` validation failures, `0` generator failures, and `0` command failures
  - `.tmp/pass-fuzz-rub-both-20260410-large-tagged-prefix-2000` stayed clean on all `844/844` compared mixed-generator cases before `5` Binaryen-side command failures
  - the mixed-generator failure classes stayed Binaryen-side only: `1` `binaryen-command-failed` plus `4` `binaryen-rec-group-zero`
  - `.tmp/rub-trace-large-tagged-prefix-fastguard-idle.stderr` shows `Func 356` reporting `skip-hot reason=large-tagged-result-prefix-ladder-noop`
  - `Func 356` improves to `pass=683 / lift=6135`
  - the fastguard follow-up reduces the first tagged-prefix draft from `712041 us` to `692911 us` traced RUB pass time
  - the same follow-up is still not a clean aggregate win over the earlier raw value-`if` checkpoint, so this slice is recorded as a retired hotspot plus a detector-cost lesson rather than final runtime signoff
- The later typed `br_table` encoder raw skip is also parity-clean and retires the next lift-heavy hotspot:
  - `.tmp/pass-fuzz-rub-genvalid-20260410-typed-brtable-encoder-v4-10000` completed `10000/10000` compared matches with `0` mismatches, `0` validation failures, `0` generator failures, and `0` command failures
  - `.tmp/pass-fuzz-rub-both-20260410-typed-brtable-encoder-v4-2000` stayed clean on all `840/840` compared mixed-generator cases before `5` Binaryen-side command failures
  - `.tmp/rub-trace-typed-brtable-encoder-idle-v4.stderr` drops traced RUB pass total from `692911 us` to `653494 us`
  - the same trace drops traced lift total from `994979 us` to `730704 us`
  - `Func 1482` now reports `skip-raw reason=large-typed-br-table-encoder-ladder-noop`
  - `Func 1382` remains visible at `pass=6716 / lift=65291`
- The later `br_table` / one-arm payload parity guard is also green:
  - `.tmp/pass-fuzz-rub-genvalid-20260410-brtable-onearm-guard-10000` completed `10000/10000` compared matches with `0` mismatches, `0` validation failures, `0` generator failures, and `0` command failures
  - `.tmp/pass-fuzz-rub-both-20260410-brtable-onearm-guard-2000` stayed clean on all `834/834` compared mixed-generator cases before `5` Binaryen-side command failures
  - replay of `.tmp/self-opt-rub-20260410-compare-next/binaryen.nop20.wasm` now validates after the reduced `Func 3771` fix
  - the first guard draft regressed explicit self-opt replay, but piggybacking `has_br_table` onto the branch-payload scan recovered Starshine pass time from `680.151 ms` to `610.426 ms`
  - `.tmp/self-opt-rub-20260410-brtable-onearm-guard-piggyback` is still canonically and normalized red, and the first checked remaining hunk `func $384` still traces as `changed=false`
- The later drop-heavy raw skip calibration is also parity-clean and artifact-positive:
  - `.tmp/pass-fuzz-rub-genvalid-20260410-drop-heavy-f145-10000` completed `10000/10000` compared matches with `0` mismatches, `0` validation failures, `0` generator failures, and `0` command failures
  - `.tmp/pass-fuzz-rub-both-20260410-drop-heavy-f145-2000` stayed clean on all `842/842` compared mixed-generator cases before `5` Binaryen-side command failures
  - `.tmp/rub-trace-drop-heavy-final-idle.stderr` shows `Func 145` reporting `skip-raw reason=large-drop-heavy-branch-ladder-noop`
  - the same trace leaves the visible pass-heavy side at `Func 96` (`6251 / 4230`), `Func 788` (`5998 / 5027`), and `Func 1068` (`5996 / 4479`), while `Func 1382` remains the lift-heavy leader at `6406 / 76692`
- The later `2026-04-13` perf audit is also directionally positive without reopening the parity surface:
  - HOT liveness now uses a hybrid `deleted_nodes` fast path for large free lists instead of always rescanning `free_nodes`
  - the six lifted ladder-skip classifiers now share one precomputed summary, and each fixpoint cycle computes `label_refs`, `branch_payload_children`, and `has_br_table` in one scan
  - visitation now threads root-site and single-arm-`nop` context instead of re-finding those facts with extra whole-function walks, and detached cleanup / hot rewrite assembly both allocate less transient structure
  - the follow-on Binaryen-shaped candidate-filter slice now adds two more raw cost filters: a very large void-`if` / return family and a medium-size unchanged control-ladder family with heavy local traffic
  - the later lifted follow-up now also adds `medium-branchy-block-ladder-noop` for the canonical extracted cluster `Func 144`, `Func 301`, `Func 353`, `Func 1512`, `Func 1547`, `Func 1859`, and `Func 1867`
  - the next lifted follow-up now also adds `call-heavy-mixed-if-mesh-noop` for the canonical extracted cluster `Func 408`, `Func 413`, `Func 739`, `Func 832`, `Func 902`, `Func 1022`, `Func 1448`, and `Func 1815`
  - the latest lifted follow-up now also adds `localset-heavy-value-if-mesh-noop` for the canonical extracted cluster `Func 837`, `Func 3021`, `Func 3120`, `Func 3130`, and `Func 3134`
  - fresh focused oracle evidence stays green at `.tmp/pass-fuzz-rub-genvalid-200-after-binaryen-filtering` (`200/200`, `0` mismatches, `0` command failures), `.tmp/pass-fuzz-rub-mixed-120-after-binaryen-filtering` (`119/119` compared before the usual Binaryen-side parser failure), `.tmp/pass-fuzz-rub-genvalid-200-after-medium-branchy-hot-skip` (`200/200`, `0` mismatches, `0` command failures), `.tmp/pass-fuzz-rub-mixed-120-after-medium-branchy-hot-skip` (`119/119` compared before the usual Binaryen-side parser failure), `.tmp/pass-fuzz-rub-genvalid-200-after-call-heavy-mixed-if-mesh` (`200/200`, `0` mismatches, `0` command failures), `.tmp/pass-fuzz-rub-mixed-120-after-call-heavy-mixed-if-mesh` (`119/119` compared before the usual Binaryen-side parser failure), `.tmp/pass-fuzz-rub-genvalid-200-after-localset-heavy-value-if-mesh` (`200/200`, `0` mismatches, `0` command failures), and `.tmp/pass-fuzz-rub-mixed-120-after-localset-heavy-value-if-mesh` (`119/119` compared before the usual Binaryen-side parser failure)
  - the latest interleaved three-pair self-opt replay now averages `402.0653 ms` on the current tree versus `431.7387 ms` for the immediate pre-slice baseline, while canonical wasm and normalized WAT are still red

## Current Open Gap

The active backlog now says the next work should be reduced in this order:

- The generated `_build/wasm/debug/build/cmd/cmd.wasm` ordered `-O4z` audit from `2026-04-18` still leaves one top-priority RUB corruption slot on Binaryen-produced predecessor states:
  - later slot `40` emits invalid raw wasm; `wasm-tools validate` fails at `func 1979` with `values remaining on stack at end of block`, while Binaryen's validator also flags an `if-else` true-arm type issue in function `1958`
- Slot `14` is retired by `0102`:
  - the exact mutator was the direct plain-`br` branch cleanup in `remove_unused_brs_try_rewrite_if_br(...)`
  - the fix keeps that rewrite disabled for large lifted functions when the condition is not reorder-safe
  - the saved predecessor replay and the extracted `Func 1354` replay now both validate again
- So the remaining blocker is no longer “slot 14 native/source divergence”; it is the later slot-40 typed-block stack leak.

- The remaining parity families are not just tail-branch-removal gaps.
- The real missing area includes Binaryen's later final-shape cleanup, especially the `restructureIf` family that only becomes cheap after earlier simplification.
- Earlier MoonBit attempts tried to find those shapes by scanning more nested regions during the main walk, which hit real oracle cases but reopened the performance cliff.
- The latest perf audit already removed the obvious duplicated whole-function scans, and the follow-on Binaryen-shaped raw candidate filters shaved more time off the unchanged-walk and large-void buckets without changing parity evidence.
- Separate explicit-pass type-order noise from real RUB body diffs in the current artifact compare.
- Treat first inspected remaining hunks like `func $384` as non-RUB noise until the trace proves the pass actually mutated the function.
- Reduce the still-leading unchanged pass-heavy self-opt families `Func 497`, `Func 1168`, `Func 229`, `Func 990`, `Func 883`, `Func 1213`, `Func 1061`, `Func 105`, and `Func 1063`, while keeping the older lift-heavy `Func 1382` trace separate from true pass-walk hotspots.
- Audit the later loop/block-order family separately so a canonicalization difference does not get accidentally "fixed" by an unrelated branch rewrite.
- Keep rerunning self-opt compare and mixed-generator compare-pass lanes after each reduction.
- A health rerun on `2026-04-11` shows broader unresolved mismatches for `remove-unused-brs`:
  - mixed (`--generator both`): `199 / 199` compared, `175` normalized matches, `24` mismatches, `1` command failure (`binaryen-rec-group-zero` at `case-000029-wasm-smith`)
  - `--generator gen-valid` with `--max-failures 30`: `114 / 114` compared, `84` normalized matches, `30` mismatches, `maxFailuresHit: true`
- These mismatch cases are currently only labeled as `normalized outputs differed`; they are unresolved pending reduced repro classification.

## Current Risks

- Some artifact differences may still be lift/lower round-trip noise rather than real RUB logic differences.
- The new self-target arm rewrite already proved that broad block-root rewrites can regress older block-local flattening families.
- The new continuation-wrapper fix showed that even a correct narrow parity slice can regress runtime if older no-op matchers pay extra discovery cost.
- The new large-dispatch raw skip proved that even a no-op classifier needs a cheap prefilter before the full shape scan, or ordinary result blocks will pay the extra discovery cost.
- The false-prefix fix proved that the raw HOT-only candidate detector can be a performance bug even when the real HOT matcher is correct; future raw detectors should stay aligned with the actual lifted legality surface instead of using "any later branch" style proxies.
- The tee-floor follow-up proved that trace function indices still need to be cross-checked against the real artifact WAT body before declaring a hotspot family solved; the sixteen-tee loop/select slice belonged to `Func 1171`, not `Func 1150`.
- The later large-`br_table` hot skip proved the same thing on the lifted side: the first working block ceiling had to be calibrated from lifted counts, not copied from the printed WAT shape.
- The tagged result-prefix follow-up proved a new lifted rule too: retiring one unchanged hotspot is not enough if the detector adds another full-function scan. Future lifted no-op skips should reuse existing scans and cheap prefilters whenever possible.
- The typed `br_table` encoder follow-up proved the same thing on the raw side: the first reduced-only single-root detector passed the perf lock but missed the real artifact body, so future raw no-op skips should calibrate their final cheap prefilter against the traced decoded shell, not only the reduced fixture.
- The drop-heavy `Func 145` follow-up proved the same thing on a lighter raw family: the first `local_set >= 210` draft passed the perf lock but still missed the real artifact body at `local_set=201`, so the final floor had to come from the traced artifact counts rather than the reduced-only lock.
- The `Func 3771` fix proved another parity boundary: Binaryen keeps some direct one-arm payload branch `if` families conservative when the surrounding function also contains `br_table`, so that direct cleanup cannot be inferred from the local branch alone.
- The same `Func 3771` follow-up proved the cost rule again: even a correct whole-function negative guard is too expensive if it adds a second HOT walk, so broad parity guards should piggyback on existing per-cycle scans.
- The next runtime work now has to keep pass-walk and lift cost separate; even after the later localset-heavy value-if mesh hot skip the local self-opt lane still sits around `402.0653 ms` versus a `431.7387 ms` immediate pre-slice baseline, while Binaryen remains in roughly the `92-96 ms` band, and the next pure pass-heavy candidates still differ from the older lift-heavy `Func 1382` trace.

## Practical Rule

- Treat the pass as partially signed off on broad correctness, but not on final artifact parity.
- Prefer reductions that prove:
  - the pass actually mutates the function
  - the mutated shape is a genuine Binaryen delta rather than type-order or lift/lower noise
  - the narrowed rewrite does not reopen already-green block-local or returned-ladder families

## Suggested Reading Order

- Start with [`./pattern-catalog.md`](./pattern-catalog.md) for the full surface.
- Read [`./binaryen-strategy.md`](./binaryen-strategy.md) to keep the upstream phase model in mind.
- Read [`./starshine-hot-ir-strategy.md`](./starshine-hot-ir-strategy.md) and [`./visit-order-and-bailouts.md`](./visit-order-and-bailouts.md) before touching performance-sensitive matcher discovery.
- Read [`./returned-ladder-hot-shapes.md`](./returned-ladder-hot-shapes.md) before working on any root-return or carried-wrapper mismatch that still looks "simple" in printed WAT.

- Archived research doc: [`../../../raw/research/0070-2026-03-27-remove-unused-brs-binaryen-comparison.md`](../../../raw/research/0070-2026-03-27-remove-unused-brs-binaryen-comparison.md)
- Carried-wrapper follow-up: [`../../../raw/research/0076-2026-04-10-remove-unused-brs-br-table-carried-wrapper-parity.md`](../../../raw/research/0076-2026-04-10-remove-unused-brs-br-table-carried-wrapper-parity.md)
- Follow-up health rerun: [`../../../raw/research/0079-2026-04-11-pass-fuzz-health-round-two.md`](../../../raw/research/0079-2026-04-11-pass-fuzz-health-round-two.md)
- HOT shape note: [`./returned-ladder-hot-shapes.md`](./returned-ladder-hot-shapes.md)
- Implementation: [`../../../../../src/passes/remove_unused_brs.mbt`](../../../../../src/passes/remove_unused_brs.mbt)
- Focused tests: [`../../../../../src/passes/remove_unused_brs_test.mbt`](../../../../../src/passes/remove_unused_brs_test.mbt)
