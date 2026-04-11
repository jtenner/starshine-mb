---
kind: comparison
status: working
last_reviewed: 2026-04-11
sources:
  - ../../../raw/research/0070-2026-03-27-remove-unused-brs-binaryen-comparison.md
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
  - ../../../../../src/passes/remove_unused_brs.mbt
  - ../../../../../src/passes/remove_unused_brs_test.mbt
  - ../../../../../src/passes/perf_test.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/passes/optimize_test.mbt
  - ../../../../../src/cmd/cmd_test.mbt
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
- The remaining artifact work is not a generic "RUB still weak on branches" statement.
- The remaining work is now concentrated in later shape families where:
  - the explicit compare still contains early type-order noise that may not be RUB logic at all
  - later loop/block-order or body-order differences still need mutation-backed reduction
  - the latest traced runtime split is now `Func 96` / `Func 788` / `Func 1068` on the pass-heavy side and `Func 1382` on the lift-heavy side
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
  [`../../../../../src/cmd/cmd_test.mbt`](../../../../../src/cmd/cmd_test.mbt)

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
  - `.tmp/self-opt-rub-20260410-drop-heavy-f145` improves Starshine pass time from `610.426 ms` to `573.182 ms`, but canonical wasm and normalized WAT are still red

## Current Open Gap

The active backlog now says the next work should be reduced in this order:

- The remaining parity families are not just tail-branch-removal gaps.
- The real missing area includes Binaryen's later final-shape cleanup, especially the `restructureIf` family that only becomes cheap after earlier simplification.
- Earlier MoonBit attempts tried to find those shapes by scanning more nested regions during the main walk, which hit real oracle cases but reopened the performance cliff.
- Separate explicit-pass type-order noise from real RUB body diffs in the current artifact compare.
- Treat first inspected remaining hunks like `func $384` as non-RUB noise until the trace proves the pass actually mutated the function.
- Reduce the unchanged pass-heavy self-opt families `Func 96`, `Func 788`, and `Func 1068`, while keeping the older lift-heavy `Func 1382` trace separate from true pass-walk hotspots.
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
- The next runtime work now has to keep pass-walk and lift cost separate; the fresh self-opt replay is still materially over Binaryen's pass time budget (`573.182 ms` vs `91.702 ms`), and its next pure pass-heavy candidates differ from the older lift-heavy `Func 1382` trace.

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
