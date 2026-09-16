---
kind: concept
status: supported
last_reviewed: 2026-09-16
sources:
  - ../dead-argument-elimination/index.md
  - ../merge-blocks/index.md
  - ../rse/index.md
  - index.md
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

> **Comparison baseline — September 10, 2026:** new comparisons use [Binaryen 132](../../release-horizon-and-oracles.md). This supersedes older current/latest-baseline wording below. Recorded v131 sources, commands, artifacts and results retain their historical version and do not establish v132 signoff.

This page records the implementation-readiness and validation contract for `dae-optimizing`.
As of 2026-07-21, DAE-owned behavior is locally release-complete: Starshine exposes the exact upstream spelling `dae-optimizing` plus `dead-argument-elimination-optimizing`, schedules the canonical pass once in public optimize/shrink/O4z, and has recorded Binaryen-v131 behavior, artifact, performance, and repository-gate evidence. Retained guards omit only optional expensive nested cleanup; the remaining canonical artifact gap is assigned to shared neighboring local-cleanup passes rather than hidden as a DAE win.

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
- a closed `[DAE]006` both-canonical Func509 diagnostic investigation: [`0591`](../dead-argument-elimination/index.md) documents the current `defined=509 abs=526` frontier as a lowerer/diagnostic boundary rather than a safe DAE final-hook matcher miss.

The 2026-07-21 closure preserves deterministic totals `253/253`, `347/347`, `6217/6217`, and `9696/9696`; `moon info`, wasm-gc check/test, README API sync, native release build, and `bun validate full --profile ci --target wasm-gc --seed 0x5eed` pass. Native SHA-256 `100397722893a76c76a3d3eed486e38c60df932b4b73da36574d35d17112520f` drives the final explicit Binaryen-v131 four-lane renewals.

Plain DAE's mixed-type removed-slot fail-closed repair makes the retained artifact valid and byte-idempotent at `2,991,169` bytes, with `85.329s` productive and `64.277s` idempotent medians; canonical output is `9,670` bytes smaller than Binaryen. DAEO remains byte-identical at `2,991,168` bytes and improves to `25.440s` / `21.475s` productive/idempotent medians. Its canonical output is `4,318` bytes larger than Binaryen despite a `70,900`-byte raw win; the renewed local/body/type ledger assigns the gap to shared nested simplify/coalesce/local-ordering implementations.

That is closer to upstream Binaryen than the earlier boundary-only hold point, but it is still intentionally narrower than the full optimizing sibling. The recovered current preset tables supersede the older `[DAE]013` direct-pass-only decision: `dae-optimizing` is present in both public `optimize` and `shrink`, and the registry/runtime order regression locks its late placement. The July 13 scheduled replay proves public `optimize`, public `shrink`, and synthesized `-O4z` execute that slot exactly once and match Binaryen's valid 38-byte O4z output on the then-current dedicated profile. It also fixes an artifact-discovered native local-map crash and transient scratch-local collision. The July 13 flattened rec-group repair proves that the then-current artifact failure was DAEO-owned flattened rec-group type lookup/append corruption rather than a nondefaultable-local validator limitation. Red-first grouped-type tests now guard flattened lookup, append indexing, safe simple-type reuse, result preservation, caller repair, and validation. The stripped wasm-gc artifact emitted valid output, Starshine pass-local time was `3327.318ms` versus Binaryen `8083.49ms`, and the full direct matrix was current for that historical v130 behavior. The remaining artifact blocker was a measured size-losing/canonical parity gap (`+24159` raw / `+16350` canonical / `+333815` WAT bytes); it was not an accepted win. The July 13 artifact-gap attribution corrected the final touched count to `22` and proved the skip itself was only a minor owner: a valid guarded nested-replay probe closed `21` canonical bytes but added `6` raw bytes. The larger inspected gap was low-candidate and exact-reference convergence through Funcs `164`, `39`, `37`, `38`, and `41`. Naively raising the fixed core cap to `64` took `72787.434ms`; enabling a `16`-candidate low revisit on the large artifact took `18322.992ms`. Both added raw bytes and missed the pass-local target, so neither was retained. The July 13 broad-module worklist measured the replacement. The reusable machinery discovers candidates once from one current caller-fact snapshot and revalidates each candidate against the evolving module; the active artifact-safe policy requires at least eight all-nullable-reference params in the first `4096` definitions. It selects only Func `164`, removes all ten null/default params, validates, improves committed Starshine by `20` raw / `55` canonical / `675` current-tool WAT bytes, and runs in `3646.647ms` versus Binaryen `8083.49ms`. The remaining direct gap is `+24139` raw / `+16295` canonical / `+346973` current-tool WAT bytes. The bounded result-only caller closure introduced the next step. The terminal-result and null-default body repairs make it productive on the current artifact by refining terminal direct-call dependencies first, recognizing exact `struct.new` results, and applying only the proven productive-candidate null-test/default plus terminal-local cleanup. Func `164` now has zero params/locals, exact result `$731`, and Binaryen-shaped effectful default producers; the valid retained output improves the prior endpoint by `199` raw / `240` canonical / `2832` regenerated canonical-WAT bytes and runs in `3980.121ms` versus Binaryen `8083.49ms`. The exact-parameter blocker records rejected partial downstream probes. The exact-parameter closure makes that blocker productive: Funcs `37`, `38`, and `41` now have two parameters with exact second `$731`; immutable Global `501` is materialized only into Func `37`; a filtered `precompute-propagate-prefix` plus current-fact exact/default and unread replay removes the downstream nullable arguments; selected cleanup is limited to Funcs `37`/`38`, never oversized Func `41`; and plain DAE preserves the original carrier. The retained valid artifact is raw `3201367` / canonical `3278451` / canonical-WAT `179304975`, a measured `+6` raw but `-60` canonical / `-616` WAT movement versus the prior endpoint, with pass-local `5645.054ms` versus Binaryen `8083.49ms`. The post-param-chain direct matrix refreshes the historical required matrix: dedicated `10000/10000` normalized, regular `100000/100000` normalized, wasm-smith `9955` normalized plus `1` cleanup-normalized with only `44` Binaryen/oracle failures, and random-all `9633` normalized plus the same `367` byte-identical measured/source-backed Starshine cleanup wins. No unknown/risky, size-losing generated, Starshine validation, or true-semantic residual remains in that historical direct matrix. The scheduled validation note also refreshes exact-once ordered public scheduling, dedicated scheduled output/timing, the full release gate, and `.mbti` review. The large current-artifact public optimize lane is concretely blocked before DAEO: traced and no-trace attempts timed out after `7200s` and `3600s`, and the mode-specific attribution reproduces the owner with a direct `vacuum` timeout. That attribution also supersedes the earlier shared-blocker assumption: large O4z bypasses that raw vacuum route but stalls earlier in `ssa-nomerge`; large shrink remains unattributed. The 2026-05-13 and later artifact follow-ups in the neighboring DAE dossier remain historical support for the earlier frontier sequence. New comparison signoff uses Binaryen 132.

Research notes [`1585`](./index.md) and [`1586`](./index.md) supersede note `1583`'s implementation blocker. The structured-copy shortcut is bounded, and a generic broad-module selector ranks dropped wrappers by downstream local-copy payoff, removes selected wrapper `12293` before terminal callee `8429`, refreshes call facts, and applies bounded cleanup only to the selected callee. Plain DAE is unchanged. The retained valid artifact improves the previous endpoint by `1308` raw / `1149` canonical / `4190560` current-tool WAT bytes at `6814.078ms` versus Binaryen `8083.49ms`. Func `9347` is now the largest body owner; the remaining direct gap is `+14846` canonical bytes.

Research note [`1587`](./index.md) refreshes current readiness evidence with explicit native SHA-256 `2e69c9602f2fa252f8e7ef13f40659b8cc8e6ef763fb12ab1a3041fd4e1d3905`. Dedicated `10000/10000` and regular `100000/100000` normalize with zero failures; wasm-smith has `9955` normalized plus `1` cleanup-normalized match and only the unchanged `44` Binaryen/oracle failures. Random-all timed out after `1800s` with `307/10000` records; its `12` observed residual directories are byte-identical to the prior complete known cleanup families, but the partial lane is not closeout evidence. Dedicated optimize/shrink/O4z still execute DAEO exactly once immediately before `inlining-optimizing`. Large shrink is now directly blocked in early `ssa-nomerge`, matching O4z's owner family, while optimize remains blocked in vacuum. Full release validation and `.mbti` review pass, but final readiness remains open on the incomplete random-all lane, the `+14846` canonical gap, and all three pre-DAEO large scheduled blockers.

Notes [`1588`](./index.md) and [`1589`](./index.md) supersede the single-payoff hold point. DAEO now completes the two currently attributed broad payoff chains in one bounded invocation and includes productive Func `41` in the exact-parameter selected cleanup set. Note [`1590`](./index.md) records that intermediate deterministic endpoint and complete matrix.

Notes [`1591`](./index.md) through [`1593`](./index.md) add and sign off a generic optimizing-only adjacent-constructor-chain family. A broad exact-literal aggregate root selects a nearby same-signature high-local caller/callee pair without artifact-index hardcoding; bounded `simplify-locals`/`vacuum` cleanup advances the retained valid artifact to raw `3198310` / canonical `3275701`, `+13245` canonical versus Binaryen, at `11088.465ms` versus `8083.49ms` (`1.37x`). A pair-first prefilter preserves output while reducing selector cost.

Notes [`1594`](./index.md) through [`1596`](./index.md) close a generic optimizing-only removed-parameter local family. The broad selector checks only already-touched high-local definitions whose parameter count fell, ranks removable unreferenced locals, and rewrites one best candidate; a direct-reference prefilter avoids exact lowered cleanup when current facts suffice. Func `41` loses `168` locals without artifact-index hardcoding, advancing the valid artifact to raw `3197559` / canonical `3275027`, `+12571` canonical versus Binaryen, at `12763.150ms` versus `8083.49ms` (`1.58x`). Plain DAE remains unchanged.

Notes [`1597`](./index.md) through [`1599`](./index.md) add and sign off generic type-stable local ordering for the already selected broad adjacent pair. Notes [`1600`](./index.md) through [`1602`](./index.md) reuse that same rewrite only for the terminal callees already selected by the generic payoff-chain lane, then fold local-index validation into the existing count/first-use traversal. The final valid artifact is raw `3197420` / canonical `3274877`, `+12421` canonical versus Binaryen, at `13234.748ms` versus a fresh Binaryen debug `8538.02ms` (`1.55x`). Fresh Binaryen-v130 explicit-native dedicated `10000`, regular `100000`, wasm-smith `10000`, and random-all `10000` lanes preserve the complete classified matrix; full tests `8809/8809`, pinned-seed CI-profile validation, exact-once optimize/shrink/O4z scheduling, and `.mbti` review are green. Plain DAE remains unchanged. Two generic reachability-only Func `7007..7010` probes were rejected because they missed the cycle transaction and worsened size; readiness remains open on a transactional parameter-position SCC proof or re-attribution of the next owner. Funcs `7008`, `7007`, `8429`, `41`, and `9347` remain positive direct parity owners, and large optimize/shrink/O4z still stop before DAEO in vacuum or ssa-nomerge.

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

- [`index.md` (absorbed)](index.md)
- [`index.md` (absorbed)](index.md)
- [`index.md` (absorbed)](index.md)
- [`./binaryen-strategy.md`](./binaryen-strategy.md)
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md)
- [`./signature-updates-and-nested-reruns.md`](./signature-updates-and-nested-reruns.md)
- [`./wat-shapes.md`](./wat-shapes.md)
- [`./starshine-strategy.md`](./starshine-strategy.md)
- [`../dead-argument-elimination/starshine-port-readiness-and-validation.md`](../dead-argument-elimination/starshine-port-readiness-and-validation.md)
