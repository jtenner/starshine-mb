---
kind: comparison
status: working
last_reviewed: 2026-06-19
sources:
  - ../../../raw/binaryen/2026-06-18-remove-unused-brs-version-130-source-refresh.md
  - ../../../raw/research/0721-2026-06-09-remove-unused-brs-merge-blocks-audit.md
  - ../../../raw/research/0548-2026-05-07-remove-unused-brs-mixed-rerun-and-local-normalization-classification.md
  - ../../../raw/binaryen/2026-05-06-remove-unused-brs-current-main-recheck.md
  - ../../../raw/research/0505-2026-05-06-remove-unused-brs-current-main-recheck.md
  - ../../../raw/research/0070-2026-03-27-remove-unused-brs-binaryen-comparison.md
  - ../../../raw/research/0093-2026-04-18-generated-o4z-pass-audit-summary.md
  - ../../../raw/research/0094-2026-04-18-generated-o4z-rub-slot14-missing-i32-result.md
  - ../../../raw/research/0101-2026-04-18-generated-o4z-rub-slot14-native-source-divergence.md
  - ../../../raw/research/0102-2026-04-18-generated-o4z-rub-slot14-if-br-large-condition-guard.md
  - ../../../raw/research/0099-2026-04-18-generated-o4z-rub-slot40-block-stack-leak.md
  - ../../../raw/research/0108-2026-04-18-generated-o4z-rub-slot40-retired-by-tail-value-if-rewrite-guard.md
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
  - ./starshine-strategy.md
  - ./starshine-hot-ir-strategy.md
  - ./returned-ladder-hot-shapes.md
  - ./visit-order-and-bailouts.md
---

# `remove-unused-brs` Binaryen Parity

## Durable Conclusions

- Binaryen's `RemoveUnusedBrs` is phase-driven and Starshine now mirrors a meaningful subset of that structure.
- The current tree already covers much more than dead tail stripping:
  - tail `br` / `return` elimination
  - constant `br_if` folding, including carried payloads as of the 2026-06-09 audit
  - one-armed `if` to `br_if`
  - two-armed branch-exit cleanup
  - block-local chain flattening
  - value-`if` to `select`
  - local-set arm cleanup
  - branch-payload `if` cleanup
  - carried-guard/result-block cleanup
  - dense no-payload equality `br_if` ladders to `br_table`, including `i32.eqz`, distinct branch targets, unique constants, min-offset selectors, and Binaryen's dense-run thresholds
  - JumpThreader safe subsets: branch-to-trap rewriting for simple branches to void blocks followed by `unreachable`, no-payload `br_if` retargeting through one-child named block shells, and no-payload `br_if` retargeting to a following simple jump
  - Binaryen-style `sinkBlocks(...)` safe subset for void block/loop rotation and void block/single-if sinking into the unique multi-root label-using arm, with condition-label-use and both-arm-use negatives
  - caught-`throw` to branch cleanup for safe `try_table` exact-catch and `catch_all`-without-ref forms, including payload/drop-child preservation and exnref-transport negatives
  - GC `br_on_*` cleanup for the safe single-ref-child subset: definitely taken/not-taken `br_on_null` and `br_on_non_null`, definitely successful `br_on_cast`, and definitely not-taken `br_on_cast_fail`, with explicit fail-closed boundaries for payload children, nullable-cast splitting, descriptor variants, broader fallthrough/cast insertion, and unreachable-input dropped-child construction
  - Binaryen-style loop cleanup for simple loop backedges, including adjacent `br_if` condition flipping and single-use block-exit suffix movement
  - shrink-mode adjacent same-target `br_if` merging for the no-payload safe subset, using `i32.or` when the later condition is locally safe to speculate
  - safe early `br_table`/switch cleanup for trailing defaults and leading-default offsets on no-payload and value-carrying tables, plus no-payload default-only, two-option, and large mostly-default nested stack-style lowerings
- The 2026-06-09 merge-blocks/RUB result-fallback audit is covered by [`../../../raw/research/0721-2026-06-09-remove-unused-brs-merge-blocks-audit.md`](../../../raw/research/0721-2026-06-09-remove-unused-brs-merge-blocks-audit.md):
  - `remove_unused_brs_try_fold_constant_br_if(...)` now preserves branch payload children while folding constant `br_if` roots
  - `merge-blocks -> remove-unused-brs` has a focused guard proving the result-block fallback remains live when the prefix guard can fall through to the block end
  - focused RUB tests pass `113/113`, `moon test src/passes` passes `2044/2044`, direct normalized 1000-case RUB compare has `0` mismatches, and ordered `merge-blocks -> remove-unused-brs` normalized 1000-case compare has `0` mismatches
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
- `[O4Z-AUDIT-RUB-M]` branch-to-trap parity is now implemented for the local `version_130` release-oracle family covered by `remove-unused-brs_trap.wast`: simple childless `br` instructions targeting a void block followed by `unreachable` become direct `unreachable`, while conditional `br_if` and `br_table` targets are preserved.
- `[O4Z-AUDIT-RUB-C]` loop cleanup parity is now implemented for the local `version_130` `optimizeLoop(...)` family: named loop bodies ending in simple childless `br $loop` now handle pre-existing `if` suffix movement, adjacent exit-driving `br_if` flipping, single-use block-exit `br_if` suffix movement into an else/fallthrough arm, and conservative negatives for multi-use block labels, intervening control transfer, and nested value-control hazards.
- `[O4Z-AUDIT-RUB-E]` EH caught-throw parity is now implemented for the local `version_130` `visitThrow(...)` safe `try_table` subset: exact tag catches rewrite `throw` to payload-carrying `br`, `catch_all` without ref rewrites payload children to `drop`s followed by `br`, and tag mismatch / `catch_ref` / `catch_all_ref` / earlier catch-ref-before-catch-all cases remain explicit fail-closed exnref-transport boundaries. Legacy old-`try` mixed-control stays a local representation blocker because the public WAT path lowers legacy `try` away before HOT.
- `[O4Z-AUDIT-RUB-H]` adjacent `br_if` merge parity is now implemented for the shrink-mode no-payload safe subset: child-form and stack-form adjacent `br_if`s to the same target merge into one `br_if` whose condition is `i32.or(cond1, cond2)`, guarded by a local proof that speculating the later condition is side-effect/trap-safe. The O4z raw no-op gate now admits simple stack-condition candidates so this behavior is observable under `-O4z`-style options. Payload/value branches, broad Binaryen cost/effect modeling, adjacent `br_if` + unconditional `br` cleanup, branch-hint `applyOrTo`, and `never-unconditionalize` remain open under `[O4Z-AUDIT-RUB-N]` or later final-optimizer slices.
- `[O4Z-AUDIT-RUB-I]` tablify parity is now implemented for Binaryen's no-payload dense equality-ladder family: `i32.eqz` is treated as constant zero, later selectors must safely share the first local/local.tee value, branch targets may differ, constants must be unique and within Binaryen's nonnegative `int32_t` range, and the table uses the upstream `MIN_NUM=3`, `MAX_RANGE=1024`, and `range <= arms * 3` thresholds plus min-offset selector subtraction. Duplicate constants, sparse ranges, selector mismatches, and payload/value branch ladders remain conservative boundaries.
- The early ordered generated-artifact slot-14 corruption is now fixed too:
  - the slot-13 predecessor replay no longer emits the invalid `func 1354` raw output
  - the extracted `Func 1354` replay is now locked by an external `wasm-tools validate` cmd wbtest instead of only the in-tree decode path
  - Starshine now keeps the plain-`br` `if -> br_if` cleanup disabled when a large lifted function (`hot_node_count >= 256`) would need to reorder a non-reorder-safe condition
  - that guard is deliberately conservative: Binaryen already keeps a valid block-plus-branch shape on the extracted slot-14 oracle input, and the old Starshine rewrite was emitting invalid wasm there
- The later ordered generated-artifact slot-40 corruption is now retired too:
  - the slot-37 predecessor replay now emits wasm-tools-valid raw output again
  - the extracted `Func 3863` replay is now locked by an external `wasm-tools validate` cmd wbtest
  - the current tree retires `rewrite-tail-value-if-simple-payload-arm` conservatively because the slot-40 family still leaked carried values after later lowering/restructuring composition
  - the saved slot-40 compare lane now returns `normalizedWatEqual=true` and `canonicalFuncPrettyEqual=true` on the predecessor replay
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
- Local release-oracle watch:
  Binaryen `version_130` includes the 2026-02-27 branch-to-trap behavior and the relaxed JumpThreader one-child block retargeting behavior. Fresh `version_130` versus `main` source review on 2026-06-18 found no `RemoveUnusedBrs.cpp` / requested-helper C++ drift; the only observed current-main difference was multivalue lit expectation text (`local.tee` expected as `local.set` in a few CHECK lines).

## What Is Already In Good Shape

- Scheduler parity:
  `optimize` and `shrink` both replay RUB in three top-level slots, and that is covered by focused preset tests.
- Gen-valid compare-pass evidence:
  the current backlog records clean `100`, `1000`, and `10000` case `gen-valid` lanes with zero mismatches.
- Mixed-generator compare evidence:
  older saved runs stayed clean on compared cases and stopped mainly on Binaryen-side command failures rather than Starshine semantic mismatches, while the fresh 2026-05-07 rerun reopens a narrower local-declaration shaping drift family.
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
  - branch-to-trap rewriting for simple direct branches, including the official br_table-dispatch trap fixture while preserving the table target itself
  - caught-`throw` cleanup for exact `try_table` catches and non-ref `catch_all`, with explicit exnref-transport negatives
  - raw skipping of large result `br_table` dispatch ladders with no HOT-only surface
- Older mixed-generator evidence stayed clean on compared cases:
  - `.tmp/pass-fuzz-rub-20260410-final-500` completed `499/499` compared matches
  - `0` mismatches, `0` validation failures, `0` generator failures
  - the only failure was the known Binaryen-side `binaryen-rec-group-zero` parser class
- Fresh current-head mixed-generator evidence from `.tmp/pass-fuzz-remove-unused-brs-20260507` reopened a normalized local-declaration shaping family, not a body-rewrite family:
  - compared `163/10000`, normalized matches `143`, mismatches `20`, validation failures `0`, generator failures `0`, command failures `1`
  - the lone command failure stayed the known Binaryen-side `binaryen-rec-group-zero` parser class
  - inspected mismatch dirs (`case-000006`, `000018`, `000022`, `000024`, `000026`, `000052`, and the rest of the first saved gen-valid set) showed no non-local diff hunks, only local declaration count/type/order drift
- The follow-up `[RUB]003` fix is now landed:
  - Starshine prunes dead suffix roots after unreferenced nonfallthrough block sentinels and unwraps single-root `block { unreachable }` suffix sentinels to the inner `unreachable`, avoiding the Binaryen canonicalization scratch locals that caused the declaration drift
  - focused coverage lives in `test "remove-unused-brs prunes suffix after br-table then unreachable block"`
  - `.tmp/pass-fuzz-remove-unused-brs` attempted the 10k mixed-generator direct lane and stopped at the configured `20` command failures after `6759` compared cases; all `6759` compared outputs matched with `0` mismatches, `0` validation failures, and `0` generator failures
  - command failures were tool/Binaryen-side classes: `17` `binaryen-rec-group-zero`, `1` `binaryen-bad-section-size`, `1` `binaryen-table-index-out-of-range`, and `1` `binaryen-invalid-tag-index`
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

- The generated `_build/wasm/debug/build/cmd/cmd.wasm` ordered `-O4z` audit from `2026-04-18` no longer leaves an open hard corruption slot for RUB on Binaryen-produced predecessor states:
  - slot `14` is retired by [`0102`](../../../raw/research/0102-2026-04-18-generated-o4z-rub-slot14-if-br-large-condition-guard.md)
  - slot `40` is retired by [`0108`](../../../raw/research/0108-2026-04-18-generated-o4z-rub-slot40-retired-by-tail-value-if-rewrite-guard.md)
- So the remaining work is no longer a generated-artifact corruption blocker; it is parity reduction, canonicalization-noise separation, and runtime work inside already-valid replays.
- The newest direct mismatch family is narrower than the older backlog wording too:
  - the 2026-05-07 mixed rerun no longer points first at a shared dead branch-wrapper cleanup bug
  - the first saved mismatches reduce to local declaration shaping / normalization drift with no inspected instruction-body diffs yet
  - keep that queue under focused backlog slice `[RUB]003` unless a later reduced repro proves a real mutation-backed RUB body delta

- `[O4Z-AUDIT-RUB-B]` landed the safe early switch subset from Binaryen `optimizeSwitch(...)`:
  - trailing explicit defaults are trimmed from `br_table` targets
  - leading explicit defaults are removed by rewriting the selector as `selector - offset`
  - value-carrying target-list cleanup preserves payload children and branch arity, then stops before Binaryen's condition-reordering switch-to-branch bailout for switches with values
  - no-payload default-only tables lower to selector-drop plus branch
  - no-payload one-explicit-target/two-option tables lower to branch-if structure
  - no-payload large mostly-default nested stack-style tables lower to Binaryen-style nested `if` form by narrowly bypassing the O4z raw no-op gate only for strict selector-plus-`br_table` block chains
  - value-carrying default-only and two-option tables deliberately remain `br_table` forms, matching Binaryen's value-sensitive bailout boundary
  - child-less local stack-payload value switch shapes remain conservative because ordinary lifted value switches carry payloads as `br_table` children
- `[O4Z-AUDIT-RUB-C]` landed Binaryen-style loop cleanup beyond the older block/loop rotation:
  - adjacent `br_if $exit; br $loop` forms flip the condition with `i32.eqz`, retarget the conditional to the loop label, and retarget the simple backedge to the exit label
  - single-use block-exit `br_if` forms move the void suffix plus simple loop backedge into the fallthrough/else arm
  - the one-arm `eqz` backedge-if shape exposed by earlier cleanup is normalized to Binaryen's `if cond then empty-exit else suffix/backedge` form
  - multi-use block-exit targets, intervening control transfer, value roots in the moved suffix, and nested value-control hazards stay conservative
- `[O4Z-AUDIT-RUB-M]` landed the branch-to-trap subset of Binaryen JumpThreader:
  - simple no-payload `br` nodes targeting a void block whose next sibling is `unreachable` become `unreachable`
  - conditional `br_if` and `br_table` target rewrites stay outside this slice, matching the official trap lit boundary
  - the implementation is local to HOT region traversal and does not widen the raw O4z gates or the broad nested scan surface
- `[O4Z-AUDIT-RUB-G]` landed the conditional no-payload JumpThreader safe subset:
  - `br_if` branches to a child named block retarget through one-child named block shells to the outer label
  - `br_if` branches to a child block followed by a simple jump retarget to the following jump destination
  - direct unconditional `br` retargeting, `br_table` retargeting, payload sent-type preservation, and full `replacePossibleTarget` parity remain explicit reopening criteria
  - evidence: focused RUB tests passed `150/150`, `moon test src/passes` passed `2575/2575`, full `moon test` passed `5886/5886`, native `src/cmd` build passed with pre-existing pass-manager unused-function warnings, and direct compare `.tmp/pass-fuzz-remove-unused-brs-rub-g-jumpthreader-10000` compared `9977/10000` with `0` mismatches, `5702` normalized matches, `4275` cleanup-normalized matches, and `23` Binaryen/tool command failures (`22` rec-group-zero, `1` bad-section-size).
- `[O4Z-AUDIT-RUB-D]` landed the `sinkBlocks(...)` safe subset:
  - existing loop-wrapper rotation covers named void blocks whose sole child is a loop when the loop body stays in the void-control subset
  - new single-if sinking moves a named void block into the one multi-root arm that uses the block label when the condition and opposite arm do not target it
  - condition-label-use and both-arm-label-use cases remain preserved, while single-root branch-tail arms stay owned by existing one-arm/self-branch cleanup
  - remaining boundaries: result-typed block/if sinks, direct unreachable-condition sink assertions when ordinary DCE erases the shape first, and exact Binaryen branch-hint/refinalization metadata behavior
  - evidence: focused RUB tests passed `148/148`, `moon test src/passes` passed `2573/2573`, full `moon test` passed `5884/5884`, native `src/cmd` build passed with pre-existing pass-manager unused-function warnings, and direct compare `.tmp/pass-fuzz-remove-unused-brs-rub-d-sinkblocks-10000` compared `9977/10000` with `0` mismatches, `5702` normalized matches, `4275` cleanup-normalized matches, and `23` Binaryen/tool command failures (`22` rec-group-zero, `1` bad-section-size).
- `[O4Z-AUDIT-RUB-E]` landed the EH caught-throw subset of Binaryen `visitThrow(...)`:
  - exact `catch` arms that match the thrown tag become branches carrying the original throw payload children
  - `catch_all` arms without refs become payload drops followed by a branch to the catch destination
  - `catch_ref`, `catch_all_ref`, earlier exnref-transport catches, and tag mismatches remain untouched
  - the raw layer only lifts `try_table` bodies that contain `throw` for this HOT-local rewrite; it does not add a broad nested RUB traversal or widen unrelated O4z raw skip exceptions
- `[O4Z-AUDIT-RUB-F]` landed the GC BrOn safe subset of Binaryen `optimizeGC(...)`:
  - the raw candidate gate now lifts `br_on_null`, `br_on_non_null`, `br_on_cast`, and `br_on_cast_fail`, and HOT lifting now represents `br_on_non_null`
  - single-ref-child `br_on_null` and `br_on_non_null` roots are removed or rewritten when nullability or `ref.null` proves the edge definitely taken or not taken
  - single-ref-child `br_on_cast` becomes a direct branch when the operand type already matches the target, and `br_on_cast_fail` is removed when the same proof makes the fail edge definitely not taken
  - payload/prefix children, nullable-cast success-only-if-non-null splitting, descriptor variants, broader fallthrough-type/local.tee cast insertion, and unreachable-input dropped-child rewrites remain explicit fail-closed boundaries rather than hidden no-ops
  - evidence: focused RUB tests passed `145/145`, `moon test src/passes` passed `2570/2570`, full `moon test` passed `5881/5881`, native `src/cmd` build passed with pre-existing pass-manager unused-function warnings, and direct compare `.tmp/pass-fuzz-remove-unused-brs-rub-f-gc-10000` compared `9977/10000` with `0` mismatches, `5702` normalized matches, `4275` cleanup-normalized matches, and `23` Binaryen/tool command failures (`22` rec-group-zero, `1` bad-section-size).
- `[O4Z-AUDIT-RUB-J]` landed the locally representable Binaryen `FinalOptimizer::restructureIf(...)` family:
  - named block prefixes whose only self-target use is the leading `br_if` now rebuild to an outer `if`/`select` instead of leaving the self-exit branch in place
  - void forms use `i32.eqz` and a one-arm `if`, dropped value forms use a result `if` when the value is locally reorder-safe, and side-effectful value forms use `select` only when the remaining fallthrough block is pure/order-safe
  - extra target uses and effectful fallthrough arms remain preserved; branch-hint metadata and `never-unconditionalize` stay under `[O4Z-AUDIT-RUB-N]`
- `[O4Z-AUDIT-RUB-L]` landed the locally representable Binaryen `FinalOptimizer::optimizeSetIf(...)` family:
  - copy-arm removal now handles `local.set` and `local.tee` when either arm is `local.get` of the target local; tee forms rebuild as result blocks containing a one-armed setter plus trailing `local.get`
  - branch-arm extraction now handles then-arm and else-arm simple branches, flips else-arm conditions with `i32.eqz`, preserves surviving `local.tee` results, and relies on region re-entry for recursive nested set-if cleanup
  - branch-hint metadata transfer and public `never-unconditionalize` behavior remain explicit `[O4Z-AUDIT-RUB-N]` boundaries
- `[O4Z-AUDIT-RUB-N]` is now documented as a local metadata/pass-option boundary rather than an implementable RUB rewrite slice:
  - Starshine does not currently represent expression-level `metadata.code.branch_hint`, so Binaryen `BranchHints::copyTo`, `copyFlippedTo`, `applyAndTo`, `applyOrTo`, `flip`, and `clear` have no local metadata target to preserve or remap
  - Starshine also has no public `--pass-arg` / pass-option equivalent for Binaryen `remove-unused-brs-never-unconditionalize`; existing condition-combining, selectifying, and restructuring rewrites therefore remain ordinary direct-pass behavior until such an option exists
  - reopening requires a code-metadata representation/parser/lowerer/binary or opaque-section policy plus remap tests and per-rewrite pass-option tests
- `[O4Z-AUDIT-RUB-K]` is now implemented for the direct value-`if` `selectify` family: Starshine keeps the existing one-result, scalar select-emission, reorder/effect, and local-read-safety gates, and direct selectification now mirrors Binaryen's shrink-level cost threshold for costly integer div/rem and trapping int-convert arms. Focused coverage locks the speed-mode preservation and shrink-mode selectification of a one-costly-arm `i32.rem_s` case. Branch-hint metadata and public `never-unconditionalize` remain the `[O4Z-AUDIT-RUB-N]` unsupported boundary.
- `[O4Z-AUDIT-RUB-O]` final signoff was probed on 2026-06-19 but is not closed:
  - direct 1000 compared `998/1000` with `0` mismatches
  - direct final 100000 compared `99751/100000` with `2` raw mismatches; agent classification: Starshine-win pure dropped-expression removals before unconditional trap/branch (`case-027803-wasm-smith`, `case-048903-wasm-smith`), with smaller canonical output and no side effects removed
  - command failures were Binaryen/tool failures (`249` at 100000; mostly rec-group-zero)
  - generated O4z slot14/slot40 full and extracted direct replays validate with `wasm-tools`
  - closeout remains blocked because source/docs still list late `FinalOptimizer::visitSwitch(...)` one-target switch collapse as unimplemented; that follow-up is now `[O4Z-AUDIT-RUB-P]`.
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
