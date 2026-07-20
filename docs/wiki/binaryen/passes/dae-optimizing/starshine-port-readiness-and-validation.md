---
kind: concept
status: supported
last_reviewed: 2026-07-20
sources:
  - ../../../raw/research/1602-2026-07-14-daeo-payoff-local-order-final-matrix.md
  - ../../../raw/research/1601-2026-07-14-daeo-payoff-local-order-single-scan.md
  - ../../../raw/research/1600-2026-07-14-daeo-payoff-type-stable-local-order.md
  - ../../../raw/research/1599-2026-07-14-daeo-adjacent-local-order-final-matrix.md
  - ../../../raw/research/1598-2026-07-14-daeo-adjacent-local-order-prefilter.md
  - ../../../raw/research/1597-2026-07-14-daeo-adjacent-type-stable-local-order.md
  - ../../../raw/research/1596-2026-07-13-daeo-func41-local-compaction-final-matrix.md
  - ../../../raw/research/1595-2026-07-13-daeo-removed-param-direct-prefilter.md
  - ../../../raw/research/1594-2026-07-13-daeo-broad-removed-param-local-compaction.md
  - ../../../raw/research/1593-2026-07-13-daeo-adjacent-chain-final-matrix.md
  - ../../../raw/research/1592-2026-07-13-daeo-adjacent-candidate-prefilter.md
  - ../../../raw/research/1591-2026-07-13-daeo-adjacent-constructor-chain-cleanup.md
  - ../../../raw/research/1590-2026-07-13-daeo-two-chain-final-matrix.md
  - ../../../raw/research/1589-2026-07-13-daeo-converged-chain-cleanup.md
  - ../../../raw/research/1588-2026-07-13-daeo-two-chain-bounded-closeout.md
  - ../../../raw/research/1587-2026-07-13-daeo-post-payoff-matrix-and-scheduled-refresh.md
  - ../../../raw/research/1586-2026-07-13-daeo-payoff-ranked-result-chain.md
  - ../../../raw/research/1585-2026-07-13-daeo-bounded-structured-copy-cleanup.md
  - ../../../raw/research/1584-2026-07-13-daeo-scheduled-mode-specific-blockers.md
  - ../../../raw/research/1583-2026-07-13-daeo-post-param-chain-gap-attribution.md
  - ../../../raw/research/1582-2026-07-13-daeo-scheduled-validation-and-timeout.md
  - ../../../raw/research/1581-2026-07-13-daeo-post-param-chain-direct-matrix.md
  - ../../../raw/research/1580-2026-07-13-daeo-exact-param-chain-closure.md
  - ../../../raw/research/1579-2026-07-13-daeo-exact-param-chain-blocker.md
  - ../../../raw/research/1578-2026-07-13-daeo-null-default-body-cleanup.md
  - ../../../raw/research/1577-2026-07-13-daeo-terminal-result-dependencies.md
  - ../../../raw/research/1576-2026-07-13-daeo-low-result-caller-closure.md
  - ../../../raw/research/1575-2026-07-13-daeo-wide-null-default-worklist.md
  - ../../../raw/research/1574-2026-07-13-daeo-artifact-gap-attribution.md
  - ../../../raw/research/1573-2026-07-13-daeo-flattened-rec-group-type-repair.md
  - ../../../raw/research/1567-2026-07-13-dae-block-fallthrough-propagation-and-imported-tag-type-gap.md
  - ../../../raw/research/1566-2026-07-13-dae-generic-immutable-global-inter-argument-defaults.md
  - ../../../raw/research/1565-2026-07-13-dae-generic-constant-condition-inter-argument-defaults.md
  - ../../../raw/research/1564-2026-07-12-dae-generic-folded-multivalue-suffix-defaults.md
  - ../../../raw/research/1563-2026-07-12-dae-func3737-merge-blocks-drop-carrier.md
  - ../../../raw/research/1562-2026-07-12-dae-large-module-nested-cleanup-guard-relaxation.md
  - ../../../raw/research/0687-2026-05-27-dae004-closeout-evidence.md
  - ../../../raw/research/0673-2026-05-26-dae-control-debris-normalizer.md
  - ../../../raw/research/0661-2026-05-26-dae003-closeout-evidence.md
  - ../../../raw/research/0603-2026-05-26-dae013-preset-boundary-closure.md
  - ../../../raw/research/0591-2026-05-26-dae-func509-lowering-boundary-closure.md
  - ../../../raw/research/0590-2026-05-26-dae-func509-inmemory-block-suffix-boundary.md
  - ../../../raw/research/0586-2026-05-26-dae-func509-dead-return-suffix-frontier.md
  - ../../../raw/research/0576-2026-05-25-dae-func505-frontier-classification.md
  - ../../../raw/research/0567-2026-05-14-dae002-reverse-exact-literal-frontier-still-misses-4558.md
  - ../../../raw/research/0566-2026-05-14-dae002-func42-forwarding-wrapper-chain.md
  - ../../../raw/research/0565-2026-05-14-dae002-check-range-frontier-moved-to-func42.md
  - ../../../raw/research/0564-2026-05-14-dae002-check-range-rewrite-and-nested-skip.md
  - ../../../raw/research/0563-2026-05-14-dae002-later-candidate-starvation.md
  - ../../../raw/research/0562-2026-05-13-dae002-typeidx-block-carriers.md
  - ../../../raw/research/0487-2026-05-05-dae-optimizing-current-main-recheck.md
  - ../../../raw/research/0366-2026-04-25-dae-optimizing-current-main-and-test-map.md
  - ../../../raw/research/0285-2026-04-24-dae-optimizing-primary-sources-and-starshine-followup.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./signature-updates-and-nested-reruns.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../dead-argument-elimination/starshine-port-readiness-and-validation.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/dead_argument_elimination.mbt
  - ../../../../../src/passes/dead_argument_elimination_wbtest.mbt
  - ../../../../../src/passes/dae_optimizing_test.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/cmd/cmd.mbt
  - ../../../../../src/lib/types.mbt
  - ../../../../../src/validate/typecheck.mbt
  - ../../../../../src/validate/validate.mbt
  - ../../../../../src/wast/lower_to_lib.mbt
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./signature-updates-and-nested-reruns.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../../../tooling/pass-fuzz-compare.md
  - ../dead-argument-elimination/index.md
  - ../dae2/index.md
  - ../precompute-propagate/index.md
---

# Starshine `dae-optimizing` port readiness and validation

This page turns the `dae-optimizing` dossier into an implementation-readiness and validation checklist.
It is not a full-parity claim: Starshine exposes the exact upstream spelling `dae-optimizing` plus the descriptive alias `dead-argument-elimination-optimizing`, and the recovered current preset tables schedule the canonical pass in both public `optimize` and `shrink`; the implementation is still a guarded partial port rather than Binaryen's complete optimizing sibling.

Use it when extending the current port or when reviewing whether a plain DAE change accidentally imported the optimizing sibling's nested rerun behavior.

## Current hold point

This page supersedes older pre-port wording that treated `dae-optimizing` as a future boundary-only slice. The current hold point is not registry honesty or first mutation; it is maintaining the already active partial module pass while keeping the now-closed `[DAE]003` and `[DAE]004` breadth slices ready to reopen only if a new semantic, validation, or timing regression appears.

Starshine currently has:

- public pass names `dae-optimizing` and `dead-argument-elimination-optimizing` in [`src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt), with `dae-optimizing` scheduled exactly once in both `optimize` and `shrink` after `heap-store-optimization` and before `inlining-optimizing`;
- a live module-pass dispatcher path in [`src/passes/pass_manager.mbt`](../../../../../src/passes/pass_manager.mbt) that runs the shared DAE boundary rewrite plus Binaryen-v131's required touched-function `precompute-propagate -> default O4z function pipeline`, using the same roster as `inlining-optimizing` while retaining explicit touched/module-size guards;
- focused regressions for touched-only nested cleanup order, size-skip tracing, large-module small-touched-set cleanup, the folded-multivalue Func3737 nested-cleanup lane, optimizing-only `tuple-optimization` cleanup of pure all-dead multivalue spills with effect/trap-prefix preservation (including constant-zero integer division after signed-to-unsigned canonicalization) and a plain-DAE negative guard, touched-only `optimize-casts` / `coalesce-locals` / `reorder-locals` behavior, a narrow every-direct-caller-same-literal constant-actual family, the low-definition folded-multivalue forwarded-default guard, direct-literal and immutable-defined-global condition/dead-zero-if inter-argument default families, chosen-arm effect preservation, mutable-global rejection, and a small-module fact-discovered dropped-result candidate outside the artifact selected-def list in [`src/passes/dae_optimizing_test.mbt`](../../../../../src/passes/dae_optimizing_test.mbt);
- the public touched-only `precompute-propagate` descriptor as the exact optimizing prefix, followed by `inlining_nested_function_pipeline_passes(4, 4)`; DAE-specific final cleanup validates root-terminal-return removal and preserves effect/trap prefixes when projecting dropped multivalue results;
- a narrow constant-actual materialization slice for exact literals on read-only params, now including scalar memory-load sibling carriers, typed single-result `TypeIdxBlockType` wrappers, a guarded folded-multivalue suffix-only path, and guarded direct-literal or immutable-defined-`i32`-global result-if conditions across a dead-zero-if inter-argument bridge. The shared exact-literal machinery now covers the Func323 default-parameter family generically; only its already-seven-parameter dropped folded-block artifact cleanup remains selected. Arbitrary inter-argument statements, other nonliteral constant-condition facts, GC refinement, and result-refinement families remain open;
- a usefully shrinking raw-cleanup slice in [`src/passes/dead_argument_elimination_wbtest.mbt`](../../../../../src/passes/dead_argument_elimination_wbtest.mbt) that strips live integer identities (`+0`, `-0`, `|0`, `^0`, `<<0`, `>>0`, `rotl0`, `rotr0`, `*1`, and `& -1`) on DAE-touched functions, including guarded left-constant forms when the constant producer is a stack-neutral value leaf, but still deliberately stops short of Binaryen's full optimizing replay;
- a complete shared default-function roster on admitted touched functions, with remaining `large-touched-set` / `large-touched-function` and large-module guards still requiring removal or measured justification; full public slot-48 artifact replay and renewed gross-positive/remap evidence remain open;
- the former imported-tag type-liveness blocker is closed in the recovered implementation: simple function-type pruning marks imported tag payload `TypeIdx` references live, rewrites them through compaction, validates the focused imported-tag-only module, and produced zero Starshine mismatches/failures in the recorded post-fix wasm-smith lane;
- `moon test src/passes` is signable after note `1563` fixed the shared zero-param multivalue drop-carrier `merge-blocks` abort, notes `1564` through `1566` genericized the folded/direct-literal/immutable-global default families, and note `1567` added effect-preserving block-fallthrough propagation; the high-defined-function DAE fixtures assert durable post-cleanup semantics instead of pre-cleanup body shapes;
- a closed `[DAE]005` default-raw frontier policy: the `defined=336 abs=353` type-section/type-index first diff is a documented diagnostic boundary for the raw helper, while body work should use both-canonical diagnostics unless the byte-reference contract changes;
- a closed `[DAE]006` both-canonical Func509 diagnostic investigation: [`0591`](../../../raw/research/0591-2026-05-26-dae-func509-lowering-boundary-closure.md) documents the current `defined=509 abs=526` frontier as a lowerer/diagnostic boundary rather than a safe DAE final-hook matcher miss.

The 2026-07-20 shared-roster slice preserves deterministic totals `252/252`, `346/346`, `6215/6215`, and `9693/9693`. Native SHA-256 `931e6ea8b0160316aff4200cfcc4fdb46d672b9145a36873103e489231757fc2` reproduces the frozen Binaryen-v131 random-all smoke (`93` exact + `1` cleanup-normalized + `6` classified residuals, zero failures) and keeps the retained artifact byte-identical at `2,991,168` bytes in `47.956s` productive and `44.490s` idempotent runs.

That is closer to upstream Binaryen than the earlier boundary-only hold point, but it is still intentionally narrower than the full optimizing sibling. The recovered current preset tables supersede the older `[DAE]013` direct-pass-only decision: `dae-optimizing` is present in both public `optimize` and `shrink`, and the registry/runtime order regression locks its late placement. Research note [`1570`](../../../raw/research/1570-2026-07-13-daeo-scheduled-replay-localization-safety.md) now proves public `optimize`, public `shrink`, and synthesized `-O4z` execute that slot exactly once and match Binaryen's valid 38-byte O4z output on the dedicated profile. It also fixes an artifact-discovered native local-map crash and transient scratch-local collision. Research note [`1573`](../../../raw/research/1573-2026-07-13-daeo-flattened-rec-group-type-repair.md) proves that the current artifact failure was DAEO-owned flattened rec-group type lookup/append corruption rather than a nondefaultable-local validator limitation. Red-first grouped-type tests now guard flattened lookup, append indexing, safe simple-type reuse, result preservation, caller repair, and validation. The stripped wasm-gc artifact emits valid output, Starshine pass-local time is `3327.318ms` versus Binaryen `8083.49ms`, and the full direct matrix is current. The remaining artifact blocker is a measured size-losing/canonical parity gap (`+24159` raw / `+16350` canonical / `+333815` WAT bytes); it is not an accepted win. Research note [`1574`](../../../raw/research/1574-2026-07-13-daeo-artifact-gap-attribution.md) corrects the final touched count to `22` and proves the skip itself is only a minor owner: a valid guarded nested-replay probe closes `21` canonical bytes but adds `6` raw bytes. The larger inspected gap is low-candidate and exact-reference convergence through Funcs `164`, `39`, `37`, `38`, and `41`. Naively raising the fixed core cap to `64` takes `72787.434ms`; enabling a `16`-candidate low revisit on the large artifact takes `18322.992ms`. Both add raw bytes and miss the pass-local target, so neither was retained. Research note [`1575`](../../../raw/research/1575-2026-07-13-daeo-wide-null-default-worklist.md) measures the replacement broad-module worklist. The reusable machinery discovers candidates once from one current caller-fact snapshot and revalidates each candidate against the evolving module; the active artifact-safe policy requires at least eight all-nullable-reference params in the first `4096` definitions. It selects only Func `164`, removes all ten null/default params, validates, improves committed Starshine by `20` raw / `55` canonical / `675` current-tool WAT bytes, and runs in `3646.647ms` versus Binaryen `8083.49ms`. The remaining direct gap is `+24139` raw / `+16295` canonical / `+346973` current-tool WAT bytes. Research note [`1576`](../../../raw/research/1576-2026-07-13-daeo-low-result-caller-closure.md) introduced the bounded result-only caller closure. Notes [`1577`](../../../raw/research/1577-2026-07-13-daeo-terminal-result-dependencies.md) and [`1578`](../../../raw/research/1578-2026-07-13-daeo-null-default-body-cleanup.md) make it productive on the current artifact by refining terminal direct-call dependencies first, recognizing exact `struct.new` results, and applying only the proven productive-candidate null-test/default plus terminal-local cleanup. Func `164` now has zero params/locals, exact result `$731`, and Binaryen-shaped effectful default producers; the valid retained output improves note `1576` by `199` raw / `240` canonical / `2832` regenerated canonical-WAT bytes and runs in `3980.121ms` versus Binaryen `8083.49ms`. Note [`1579`](../../../raw/research/1579-2026-07-13-daeo-exact-param-chain-blocker.md) records the rejected partial downstream probes. Note [`1580`](../../../raw/research/1580-2026-07-13-daeo-exact-param-chain-closure.md) closes that blocker: Funcs `37`, `38`, and `41` now have two parameters with exact second `$731`; immutable Global `501` is materialized only into Func `37`; a filtered `precompute-propagate-prefix` plus current-fact exact/default and unread replay removes the downstream nullable arguments; selected cleanup is limited to Funcs `37`/`38`, never oversized Func `41`; and plain DAE preserves the original carrier. The retained valid artifact is raw `3201367` / canonical `3278451` / canonical-WAT `179304975`, a measured `+6` raw but `-60` canonical / `-616` WAT movement versus note `1578`, with pass-local `5645.054ms` versus Binaryen `8083.49ms`. Research note [`1581`](../../../raw/research/1581-2026-07-13-daeo-post-param-chain-direct-matrix.md) refreshes the full required direct matrix: dedicated `10000/10000` normalized, regular `100000/100000` normalized, wasm-smith `9955` normalized plus `1` cleanup-normalized with only `44` Binaryen/oracle failures, and random-all `9633` normalized plus the same `367` byte-identical measured/source-backed Starshine cleanup wins. No unknown/risky, size-losing generated, Starshine validation, or true-semantic residual remains in the current direct matrix. Research note [`1582`](../../../raw/research/1582-2026-07-13-daeo-scheduled-validation-and-timeout.md) also refreshes exact-once ordered public scheduling, dedicated scheduled output/timing, the full release gate, and `.mbti` review. The large current-artifact public optimize lane is concretely blocked before DAEO: traced and no-trace attempts timed out after `7200s` and `3600s`, and note `1584` reproduces the owner with a direct `vacuum` timeout. Note `1584` also supersedes the earlier shared-blocker assumption: large O4z bypasses that raw vacuum route but stalls earlier in `ssa-nomerge`; large shrink remains unattributed. The 2026-05-13 `moonbit.check_range` follow-up in [`../../../raw/research/0561-2026-05-13-dae002-check-range-load-shape-attribution.md`](../../../raw/research/0561-2026-05-13-dae002-check-range-load-shape-attribution.md) showed that fixing scalar-load sibling carriers alone does not move the live debug-artifact first diff at `defined=11 abs=28`, and the later typed-block follow-up in [`../../../raw/research/0562-2026-05-13-dae002-typeidx-block-carriers.md`](../../../raw/research/0562-2026-05-13-dae002-typeidx-block-carriers.md) showed the same for typed single-result `TypeIdxBlockType` wrappers. A 2026-05-14 reduced repro in [`../../../raw/research/0563-2026-05-14-dae002-later-candidate-starvation.md`](../../../raw/research/0563-2026-05-14-dae002-later-candidate-starvation.md) then showed that the current fixed `8`-iteration DAE core can starve a later exact-literal candidate behind `9` earlier productive rewrites, and the added `pass[dae-optimizing]:core iter=... primary_def=...` trace now locks that reduced frontier directly as `primary_def=0..7`. A later 2026-05-14 follow-up in [`../../../raw/research/0564-2026-05-14-dae002-check-range-rewrite-and-nested-skip.md`](../../../raw/research/0564-2026-05-14-dae002-check-range-rewrite-and-nested-skip.md) then fixed two real caller-rewrite blockers for the original artifact path: ambient typed-loop entry-value slices and same-caller multi-call undercount. That made the live artifact frontier start at `primary_def=11` and rewrote Func 28 down to 2 params. A final same-day follow-up in [`../../../raw/research/0565-2026-05-14-dae002-check-range-frontier-moved-to-func42.md`](../../../raw/research/0565-2026-05-14-dae002-check-range-frontier-moved-to-func42.md) added a tiny touched-only control simplifier for negated compare guard forms, which closed the remaining Func 28 body mismatch and moved the live artifact frontier forward to `defined=25 abs=42`. A subsequent characterization in [`../../../raw/research/0566-2026-05-14-dae002-func42-forwarding-wrapper-chain.md`](../../../raw/research/0566-2026-05-14-dae002-func42-forwarding-wrapper-chain.md) showed the next blocker is a forwarding-wrapper chain rather than another direct mechanical miss: Func 42 is still fed by non-literal `local.get 1` through Func 4559, Func 4558 is already directly rewritable, and Func 42 only becomes exact-literal-rewritable after rewriting 4558 and then 4559. A final same-day follow-up in [`../../../raw/research/0567-2026-05-14-dae002-reverse-exact-literal-frontier-still-misses-4558.md`](../../../raw/research/0567-2026-05-14-dae002-reverse-exact-literal-frontier-still-misses-4558.md) then showed that even the reverse exact-literal frontier is crowded above the chain root: `4559` and `4558` do not appear until reverse iterations `14` and `15`. The next 2026-05-14 follow-up in [`../../../raw/research/0568-2026-05-14-dae002-forwarded-const-low-prefix-revisit.md`](../../../raw/research/0568-2026-05-14-dae002-forwarded-const-low-prefix-revisit.md) added narrow forwarded-const analysis through wrapper-local `local.get` chains plus a low-prefix exact-literal revisit over the first `64` defined functions. That moves the original-artifact core frontier to `11, 25, 227, 233, ...`, so Func 42 is now the second productive core rewrite, but the full artifact compare still differs first at `defined=25 abs=42`. The 2026-05-15 follow-up in [`../../../raw/research/0569-2026-05-15-dae002-func42-shape-fix-and-low-callee-prefix.md`](../../../raw/research/0569-2026-05-15-dae002-func42-shape-fix-and-low-callee-prefix.md) then fixed the direct Func 42 add-zero / const-order drift and added a low-callee core revisit over high callees selected from the first `64` defined callers. That moves the full artifact compare forward again to `defined=64 abs=81`, but it also leaves the pass-local runtime far above Binaryen (`120946.581ms` vs `939.053ms`), and the rejected `128`-caller experiment shows the next step cannot be another naive prefix widening. So the next candidate is now the remaining low-wrapper/high-callee family just beyond the current `64`-caller boundary.

Research notes [`1585`](../../../raw/research/1585-2026-07-13-daeo-bounded-structured-copy-cleanup.md) and [`1586`](../../../raw/research/1586-2026-07-13-daeo-payoff-ranked-result-chain.md) supersede note `1583`'s implementation blocker. The structured-copy shortcut is bounded, and a generic broad-module selector ranks dropped wrappers by downstream local-copy payoff, removes selected wrapper `12293` before terminal callee `8429`, refreshes call facts, and applies bounded cleanup only to the selected callee. Plain DAE is unchanged. The retained valid artifact improves the previous endpoint by `1308` raw / `1149` canonical / `4190560` current-tool WAT bytes at `6814.078ms` versus Binaryen `8083.49ms`. Func `9347` is now the largest body owner; the remaining direct gap is `+14846` canonical bytes.

Research note [`1587`](../../../raw/research/1587-2026-07-13-daeo-post-payoff-matrix-and-scheduled-refresh.md) refreshes current readiness evidence with explicit native SHA-256 `2e69c9602f2fa252f8e7ef13f40659b8cc8e6ef763fb12ab1a3041fd4e1d3905`. Dedicated `10000/10000` and regular `100000/100000` normalize with zero failures; wasm-smith has `9955` normalized plus `1` cleanup-normalized match and only the unchanged `44` Binaryen/oracle failures. Random-all timed out after `1800s` with `307/10000` records; its `12` observed residual directories are byte-identical to the prior complete known cleanup families, but the partial lane is not closeout evidence. Dedicated optimize/shrink/O4z still execute DAEO exactly once immediately before `inlining-optimizing`. Large shrink is now directly blocked in early `ssa-nomerge`, matching O4z's owner family, while optimize remains blocked in vacuum. Full release validation and `.mbti` review pass, but final readiness remains open on the incomplete random-all lane, the `+14846` canonical gap, and all three pre-DAEO large scheduled blockers.

Notes [`1588`](../../../raw/research/1588-2026-07-13-daeo-two-chain-bounded-closeout.md) and [`1589`](../../../raw/research/1589-2026-07-13-daeo-converged-chain-cleanup.md) supersede the single-payoff hold point. DAEO now completes the two currently attributed broad payoff chains in one bounded invocation and includes productive Func `41` in the exact-parameter selected cleanup set. Note [`1590`](../../../raw/research/1590-2026-07-13-daeo-two-chain-final-matrix.md) records that intermediate deterministic endpoint and complete matrix.

Notes [`1591`](../../../raw/research/1591-2026-07-13-daeo-adjacent-constructor-chain-cleanup.md) through [`1593`](../../../raw/research/1593-2026-07-13-daeo-adjacent-chain-final-matrix.md) add and sign off a generic optimizing-only adjacent-constructor-chain family. A broad exact-literal aggregate root selects a nearby same-signature high-local caller/callee pair without artifact-index hardcoding; bounded `simplify-locals`/`vacuum` cleanup advances the retained valid artifact to raw `3198310` / canonical `3275701`, `+13245` canonical versus Binaryen, at `11088.465ms` versus `8083.49ms` (`1.37x`). A pair-first prefilter preserves output while reducing selector cost.

Notes [`1594`](../../../raw/research/1594-2026-07-13-daeo-broad-removed-param-local-compaction.md) through [`1596`](../../../raw/research/1596-2026-07-13-daeo-func41-local-compaction-final-matrix.md) close a generic optimizing-only removed-parameter local family. The broad selector checks only already-touched high-local definitions whose parameter count fell, ranks removable unreferenced locals, and rewrites one best candidate; a direct-reference prefilter avoids exact lowered cleanup when current facts suffice. Func `41` loses `168` locals without artifact-index hardcoding, advancing the valid artifact to raw `3197559` / canonical `3275027`, `+12571` canonical versus Binaryen, at `12763.150ms` versus `8083.49ms` (`1.58x`). Plain DAE remains unchanged.

Notes [`1597`](../../../raw/research/1597-2026-07-14-daeo-adjacent-type-stable-local-order.md) through [`1599`](../../../raw/research/1599-2026-07-14-daeo-adjacent-local-order-final-matrix.md) add and sign off generic type-stable local ordering for the already selected broad adjacent pair. Notes [`1600`](../../../raw/research/1600-2026-07-14-daeo-payoff-type-stable-local-order.md) through [`1602`](../../../raw/research/1602-2026-07-14-daeo-payoff-local-order-final-matrix.md) reuse that same rewrite only for the terminal callees already selected by the generic payoff-chain lane, then fold local-index validation into the existing count/first-use traversal. The final valid artifact is raw `3197420` / canonical `3274877`, `+12421` canonical versus Binaryen, at `13234.748ms` versus a fresh Binaryen debug `8538.02ms` (`1.55x`). Fresh Binaryen-v130 explicit-native dedicated `10000`, regular `100000`, wasm-smith `10000`, and random-all `10000` lanes preserve the complete classified matrix; full tests `8809/8809`, pinned-seed CI-profile validation, exact-once optimize/shrink/O4z scheduling, and `.mbti` review are green. Plain DAE remains unchanged. Two generic reachability-only Func `7007..7010` probes were rejected because they missed the cycle transaction and worsened size; readiness remains open on a transactional parameter-position SCC proof or re-attribution of the next owner. Funcs `7008`, `7007`, `8429`, `41`, and `9347` remain positive direct parity owners, and large optimize/shrink/O4z still stop before DAEO in vacuum or ssa-nomerge.

## Why this must be a module pass

`dae-optimizing` changes a function boundary and every owned caller together.
A HOT peephole cannot see enough of the module to do that correctly.

The minimum faithful local implementation needs all of these module facts before it mutates anything:

- function signatures and type-section users;
- imports and exports;
- direct `call` and `return_call` sites;
- function references and call-reference / indirect-call escape surfaces;
- tail-call relationships;
- all direct operands at each parameter position;
- whether each result is dropped by all owned callers;
- whether removed operands have effects that must remain evaluated;
- which touched functions need nested cleanup replay after the boundary rewrite.

## First safe slice: no-rewrite analyzer

Before deleting any parameter, add an analyzer-only pass or test helper that reports candidates without changing the module.

It should classify each defined function as one of:

- **closed direct-call boundary**: all relevant calls are owned direct calls and the signature may be considered;
- **visible boundary**: import/export/public/reference exposure means the signature must not change;
- **tail-call constrained**: dropped-result changes are blocked or limited by tail-call compatibility;
- **operand-localization needed**: a candidate exists, but call operands must first be localized or preserved explicitly.

Validation for this slice:

- assert no binary/text output changes;
- compare candidate classification against small Binaryen `--dae-optimizing` fixtures from [`./wat-shapes.md`](./wat-shapes.md);
- add tests for exports, imports, `ref.func`, `call_ref`, `call_indirect`, `return_call`, and dropped-result families even if the first mutating slice ignores most of them.

## First mutating slice: scalar dead-param deletion

The smallest useful mutating slice is narrower than Binaryen's full pass:

1. Only private defined functions.
2. Only direct `call` sites, not `call_ref` or `call_indirect` rewrites.
3. Only scalar parameters that are not read in the callee body.
4. Preserve removed actual operands as side-effecting statements in the caller when they are not trivially removable.
5. Repair the callee signature and every direct call in the same module rewrite.
6. Refuse recursive and multi-function cycles until the candidate graph is explicit enough to prove them.

This slice should already be a module pass because it changes declarations and callsites together.
It should not be implemented by locally deleting `local.get` or by editing only function bodies.

## Follow-up slices

After the scalar slice is green, port the remaining Binaryen families one at a time:

- **broader constant actual materialization**: extend the new exact-literal read-only slice toward Binaryen's fuller every-owned-caller-same-constant behavior, including nontrivial constant shapes and the callee-local insertion cases Starshine still misses;
- **recursive and forwarding cycles**: remove parameters forwarded through direct-call cycles only when the entry value is never otherwise observed;
- **GC parameter refinement**: keep live parameters but narrow their reference type from call-operand least-upper-bound evidence;
- **result refinement**: narrow result types from returned-value evidence and repair call expression types;
- **dropped-result removal**: remove results only when all owned callers drop them and tail-call constraints allow it; the current small-module queue now discovers such private direct candidates from current call facts, while the large-artifact selected list remains intentionally separate until it can be batched without regressing pass-local runtime;
- **uninhabited-result preservation**: emit the needed `call; unreachable`-style repair when deleting an uninhabited result would otherwise lose control-flow knowledge;
- **operand localization and retry**: localize hard operands first, then rerun the boundary core when the localized form exposes a legal deletion;
- **unprofitable-chain throttle**: preserve Binaryen's one-caller chain throttle rather than making Starshine an unbounded signature-churn pass;
- **nested cleanup replay**: on productive changes, rerun the targeted function-cleanup suffix rather than treating the boundary rewrite as the end of the pass.

## Plain-vs-optimizing guardrail

Plain [`../dead-argument-elimination/index.md`](../dead-argument-elimination/index.md) must stop after the shared boundary rewrite core.
It must not run the nested cleanup replay documented here.

Practical test rule:

- `--pass dead-argument-elimination` may leave callee-local setup or other cleanup debris that remains valid;
- the optimizing sibling may clean that debris only when `dae-optimizing` or `dead-argument-elimination-optimizing` is requested.

If a future plain pass starts matching every optimizing golden, check whether it accidentally imported the sibling scheduler.

## Exact local code surfaces

Current reusable code surfaces:

- [`src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
  - the registry already exposes both `dae-optimizing` and `dead-argument-elimination-optimizing` with the same summary;
  - the canonical `optimize` / `shrink` late-slot spelling and registry/runtime schedule source.
- [`src/passes/pass_manager.mbt`](../../../../../src/passes/pass_manager.mbt)
  - current module-pass dispatcher surface, shared DAE boundary core, touched-function tracking, and guarded nested cleanup scheduler;
  - current home of the function-filtered `local-cse`, `coalesce-locals`, and `reorder-locals` adapters, nested-pass trace lines, and size-skip guards.
- [`src/cmd/cmd.mbt`](../../../../../src/cmd/cmd.mbt)
  - CLI/config plumbing for pass selection, tracing, and `closed_world` behavior.
- [`src/lib/types.mbt`](../../../../../src/lib/types.mbt)
  - function types and direct / indirect / reference call instruction shapes.
- [`src/validate/typecheck.mbt`](../../../../../src/validate/typecheck.mbt)
  - type rules for `call`, `call_indirect`, `call_ref`, `return_call`, and `return_call_ref`.
- [`src/validate/validate.mbt`](../../../../../src/validate/validate.mbt)
  - module-level reference validation.
- [`src/wast/lower_to_lib.mbt`](../../../../../src/wast/lower_to_lib.mbt)
  - text-fixture lowering for call and tail-call families.

Missing code surfaces for a faithful port:

- closure of the valid current artifact's remaining `+12421` canonical-byte size-losing gap after notes `1600`-`1602` narrowed the payoff callees through type-stable local ordering; Func `7008 +1781`, Func `7007 +1470`, Func `8429 +1448`, Func `41 +1286`, and Func `9347 +1281` are the leading body gaps. The next cycle slice must use a generic transactional parameter-position SCC proof for Funcs `7007..7010`, or re-attribute the next owner rather than retain reachability-only unrelated rewrites;
- a real `precompute-propagate` sibling or equivalent nested prefix replay;
- a safe, performant default-function-pipeline replay for touched functions that preserves the current large-function and nondefaultable-local hazard boundaries;
- broader function-filtered adapters or safe batching for still-module-shaped cleanup passes that Binaryen reruns after productive DAE changes;
- final debug-artifact output parity and pass-local runtime attribution closure;
- Binaryen-oracle focused test coverage for any newly enabled cleanup families beyond the current guarded slice.

## Validation ladder

Use this ladder when extending the active partial port. The old pre-port registry-honesty step is complete: both `dae-optimizing` and `dead-argument-elimination-optimizing` are active names and should remain covered by registry/dispatcher tests.

1. **Candidate-analysis and guard tests**
   - Keep candidate classifications for private direct calls, exports, imports, `ref.func`, call-reference escape, indirect calls, tail calls, and escaped-result operand preservation.
   - Add no-output analyzer coverage when a new family is only being classified.
2. **Minimal scalar rewrite regression tests**
   - One unused param, one private callee, one direct caller.
   - Multi-caller direct boundary.
   - Removed actual with side effect preserved.
   - Export/import/reference negatives.
3. **Binaryen oracle comparison**
   - Run focused `wasm-opt --dae-optimizing -S` comparisons for each supported slice.
   - For mixed-generator `pass-fuzz-compare` / `bun fuzz compare-pass` lanes, use `--normalize drop-consts --normalize unreachable-control-debris`; this classifies known generated dropped-constant debris and the inspected unreachable/control debris cleanup as `cleanupNormalizedMatchCount` instead of ordinary mismatches. See the harness contract in [`../../../tooling/pass-fuzz-compare.md`](../../../tooling/pass-fuzz-compare.md).
   - Normalize only documented semantic-noop noise; do not normalize away missing side effects, signature differences, trapping behavior, or unclassified output drift.
4. **GC/refinement tests**
   - Port the `dae-gc*` families only after local type-section and validator behavior are stable.
5. **Dropped-result tests**
   - Cover all-results-dropped positives, tail-call negatives, and uninhabited-result repair.
6. **Nested cleanup replay tests**
   - Keep a fixture where the boundary rewrite changes a function and the optimizing replay is required to reach the final shape.
7. **Sibling split tests**
   - Keep a fixture where plain DAE leaves valid cleanup debris that the optimizing sibling would remove.

## Beginner checklist

If you are unsure whether a future local rewrite belongs in `dae-optimizing`, ask:

- Does it change a function boundary?
- Can every caller that observes that boundary be found and repaired?
- Are removed operands still evaluated when needed?
- Are tail-call and uninhabited-result rules preserved?
- Is the result still valid before running any cleanup pass?
- Would the expected cleanup only happen under `dae-optimizing` in Binaryen?

If the answer to the last question is yes, keep it out of plain DAE and into the optimizing sibling.

## Sources

- [`../../../raw/research/0487-2026-05-05-dae-optimizing-current-main-recheck.md`](../../../raw/research/0487-2026-05-05-dae-optimizing-current-main-recheck.md)
- [`../../../raw/research/0366-2026-04-25-dae-optimizing-current-main-and-test-map.md`](../../../raw/research/0366-2026-04-25-dae-optimizing-current-main-and-test-map.md)
- [`../../../raw/research/0285-2026-04-24-dae-optimizing-primary-sources-and-starshine-followup.md`](../../../raw/research/0285-2026-04-24-dae-optimizing-primary-sources-and-starshine-followup.md)
- [`./binaryen-strategy.md`](./binaryen-strategy.md)
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md)
- [`./signature-updates-and-nested-reruns.md`](./signature-updates-and-nested-reruns.md)
- [`./wat-shapes.md`](./wat-shapes.md)
- [`./starshine-strategy.md`](./starshine-strategy.md)
- [`../dead-argument-elimination/starshine-port-readiness-and-validation.md`](../dead-argument-elimination/starshine-port-readiness-and-validation.md)
