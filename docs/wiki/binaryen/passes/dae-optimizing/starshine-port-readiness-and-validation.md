---
kind: concept
status: supported
last_reviewed: 2026-07-18
sources:
  - ./index.md
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
It is not a full-parity or preset-integration claim: Starshine now exposes the exact upstream spelling `dae-optimizing` plus the descriptive alias `dead-argument-elimination-optimizing`, but the implementation is still a guarded partial direct-pass port rather than Binaryen's complete optimizing sibling or part of public `optimize` / `shrink` presets.

Use it when extending the current port or when reviewing whether a plain DAE change accidentally imported the optimizing sibling's nested rerun behavior.

## Current hold point

This page supersedes older pre-port wording that treated `dae-optimizing` as a future boundary-only slice. The current hold point is not registry honesty or first mutation; it is maintaining the already active partial module pass while keeping the now-closed `[DAE]003` and `[DAE]004` breadth slices ready to reopen only if a new semantic, validation, or timing regression appears.

Starshine currently has:

- public pass names `dae-optimizing` and `dead-argument-elimination-optimizing` in [`src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt);
- a live module-pass dispatcher path in [`src/passes/pass_manager.mbt`](../../../../../src/passes/pass_manager.mbt) that runs the shared DAE boundary rewrite plus a guarded touched-function nested cleanup slice;
- focused regressions for touched-only nested cleanup order, size-skip tracing, large-module small-touched-set cleanup, the folded-multivalue Func3737 nested-cleanup lane, optimizing-only `tuple-optimization` cleanup of all-dead multivalue spills with effect/trap-prefix preservation, including constant-zero integer division after signed-to-unsigned canonicalization, and a plain-DAE negative guard, touched-only `optimize-casts` / `coalesce-locals` / `reorder-locals` behavior, a narrow every-direct-caller-same-literal constant-actual family, the low-definition folded-multivalue forwarded-default guard, direct-literal and immutable-defined-global condition/dead-zero-if inter-argument default families, chosen-arm effect preservation, mutable-global rejection, and a small-module fact-discovered dropped-result candidate outside the artifact selected-def list in [`src/passes/dae_optimizing_test.mbt`](../../../../../src/passes/dae_optimizing_test.mbt);
- the shared public touched-only `precompute-propagate` pass, which adds agreeing reaching-set consensus, default-init, tee/block fallthrough, bounded evaluation, and the maintained result-`if`/large-lowered safety guards before the remaining nested cleanup lane;
- a narrow constant-actual materialization slice for exact literals on read-only params, now including scalar memory-load sibling carriers, typed single-result `TypeIdxBlockType` wrappers, a guarded folded-multivalue suffix-only path, and guarded direct-literal or immutable-defined-`i32`-global result-if conditions across a dead-zero-if inter-argument bridge. The shared exact-literal machinery now covers the Func323 default-parameter family generically; only its already-seven-parameter dropped folded-block artifact cleanup remains selected. Arbitrary inter-argument statements, other nonliteral constant-condition facts, GC refinement, and result-refinement families remain open;
- a usefully shrinking raw-cleanup slice in [`src/passes/dead_argument_elimination_wbtest.mbt`](../../../../../src/passes/dead_argument_elimination_wbtest.mbt) that strips live integer identities (`+0`, `-0`, `|0`, `^0`, `<<0`, `>>0`, `rotl0`, `rotr0`, `*1`, and `& -1`) on DAE-touched functions, including guarded left-constant forms when the constant producer is a stack-neutral value leaf, but still deliberately stops short of Binaryen's full optimizing replay;
- no full default-function-pipeline replay on all touched functions, remaining `large-touched-set` / `large-touched-function` nested-cleanup guards, and no green debug-artifact compare yet; the propagating prefix itself is now the real shared public pass;
- the former imported-tag type-liveness blocker is closed: simple function-type pruning marks imported tag payload `TypeIdx` references live, rewrites them through compaction, validates the focused imported-tag-only module, and produced zero Starshine mismatches or failures in the recorded post-fix wasm-smith lane;
- `moon test src/passes` is signable after note `1563` fixed the shared zero-param multivalue drop-carrier `merge-blocks` abort, notes `1564` through `1566` genericized the folded/direct-literal/immutable-global default families, and note `1567` added effect-preserving block-fallthrough propagation; the high-defined-function DAE fixtures assert durable post-cleanup semantics instead of pre-cleanup body shapes;
- a closed `[DAE]005` default-raw frontier policy: the `defined=336 abs=353` type-section/type-index first diff is a documented diagnostic boundary for the raw helper, while body work should use both-canonical diagnostics unless the byte-reference contract changes;
- a closed `[DAE]006` both-canonical Func509 diagnostic investigation: [`0591`](./index.md) documents the current `defined=509 abs=526` frontier as a lowerer/diagnostic boundary rather than a safe DAE final-hook matcher miss.

That is closer to upstream Binaryen than the earlier boundary-only hold point, but it is still intentionally narrower than the full optimizing sibling. The current preset tables supersede the older `[DAE]013` direct-pass-only decision: `dae-optimizing` is present in both public `optimize` and `shrink`, and the registry/runtime order regression locks its late placement. Research note [`1570`](../../../raw/research/1570-2026-07-13-daeo-scheduled-replay-localization-safety.md) proves public `optimize`, public `shrink`, and synthesized `-O4z` execute that slot exactly once and match Binaryen's valid 38-byte O4z output on the dedicated profile. It also fixes an artifact-discovered native local-map crash and transient scratch-local collision. The stripped wasm-gc artifact met the pass-local ratio target but remained blocked at that point by structured nondefaultable GC body-local initialization; fresh behavior evidence remained required after that fix. The 2026-05-13 `moonbit.check_range` follow-up in [research note 0561](./index.md) showed that fixing scalar-load sibling carriers alone does not move the live debug-artifact first diff at `defined=11 abs=28`, and the later typed-block follow-up in [research note 0562](./index.md) showed the same for typed single-result `TypeIdxBlockType` wrappers. A 2026-05-14 reduced repro in [research note 0563](./index.md) then showed that the current fixed `8`-iteration DAE core can starve a later exact-literal candidate behind `9` earlier productive rewrites, and the added `pass[dae-optimizing]:core iter=... primary_def=...` trace now locks that reduced frontier directly as `primary_def=0..7`. A later 2026-05-14 follow-up in [research note 0564](./index.md) then fixed two real caller-rewrite blockers for the original artifact path: ambient typed-loop entry-value slices and same-caller multi-call undercount. That made the live artifact frontier start at `primary_def=11` and rewrote Func 28 down to 2 params. A final same-day follow-up in [research note 0565](./index.md) added a tiny touched-only control simplifier for negated compare guard forms, which closed the remaining Func 28 body mismatch and moved the live artifact frontier forward to `defined=25 abs=42`. A subsequent characterization in [research note 0566](./index.md) showed the next blocker is a forwarding-wrapper chain rather than another direct mechanical miss: Func 42 is still fed by non-literal `local.get 1` through Func 4559, Func 4558 is already directly rewritable, and Func 42 only becomes exact-literal-rewritable after rewriting 4558 and then 4559. A final same-day follow-up in [research note 0567](./index.md) then showed that even the reverse exact-literal frontier is crowded above the chain root: `4559` and `4558` do not appear until reverse iterations `14` and `15`. The next 2026-05-14 follow-up in [research note 0568](./index.md) added narrow forwarded-const analysis through wrapper-local `local.get` chains plus a low-prefix exact-literal revisit over the first `64` defined functions. That moves the original-artifact core frontier to `11, 25, 227, 233, ...`, so Func 42 is now the second productive core rewrite, but the full artifact compare still differs first at `defined=25 abs=42`. The 2026-05-15 follow-up in [research note 0569](./index.md) then fixed the direct Func 42 add-zero / const-order drift and added a low-callee core revisit over high callees selected from the first `64` defined callers. That moves the full artifact compare forward again to `defined=64 abs=81`, but it also leaves the pass-local runtime far above Binaryen (`120946.581ms` vs `939.053ms`), and the rejected `128`-caller experiment shows the next step cannot be another naive prefix widening. So the next candidate is now the remaining low-wrapper/high-callee family just beyond the current `64`-caller boundary.

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
  - future preset-spelling and documentation sync point if the partial/full split changes.
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

- post-fix regular GenValid, explicit wasm-smith, and random-all refresh plus current large-artifact validation/performance evidence;
- a real `precompute-propagate` sibling or equivalent nested prefix replay;
- a performant default-function-pipeline replay for touched functions without the current `large-touched-set` / `large-touched-function` guards;
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

- [research note 0487](./index.md)
- [research note 0366](./index.md)
- [research note 0285](./index.md)
- [`./binaryen-strategy.md`](./binaryen-strategy.md)
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md)
- [`./signature-updates-and-nested-reruns.md`](./signature-updates-and-nested-reruns.md)
- [`./wat-shapes.md`](./wat-shapes.md)
- [`./starshine-strategy.md`](./starshine-strategy.md)
- [`../dead-argument-elimination/starshine-port-readiness-and-validation.md`](../dead-argument-elimination/starshine-port-readiness-and-validation.md)
