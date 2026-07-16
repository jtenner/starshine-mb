---
kind: concept
status: supported
last_reviewed: 2026-07-16
sources:
  - ../../../raw/binaryen/2026-07-15-flatten-version-130-internal-output-recursive-ownership-impact.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-conditional-branch-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-loop-break-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-mixed-loop-if-table-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-mixed-loop-block-table-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-legacy-eh-repair-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-terminal-throw-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-loop-conditional-consumer-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-terminal-tail-call-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-tuple-block-producer-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-tuple-if-producer-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-tuple-branch-producer-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-tuple-loop-entry-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-tuple-loop-break-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-tuple-table-producer-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-tuple-conditional-producer-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-tuple-loop-conditional-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-tuple-loop-unary-convert-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-tuple-loop-binary-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-tuple-loop-result-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-tuple-try-tail-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-tuple-try-rich-tail-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-mixed-try-tail-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-try-break-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-try-conditional-break-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-scalar-try-conditional-unary-convert-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-scalar-try-conditional-binary-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-multivalue-try-conditional-break-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-multivalue-try-conditional-unary-convert-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-multivalue-try-conditional-tuple-unary-convert-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-multivalue-try-conditional-tuple-binary-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-multivalue-try-conditional-binary-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-scalar-try-conditional-reversed-binary-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-scalar-try-table-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-scalar-try-block-table-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-scalar-try-two-block-table-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-scalar-try-three-block-table-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-scalar-try-if-table-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-scalar-try-block-if-table-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-scalar-try-two-block-if-table-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-multivalue-try-block-if-table-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-multivalue-try-two-block-if-table-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-multivalue-try-block-if-table-tuple-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-multivalue-try-if-table-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-multivalue-try-if-table-tuple-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-multivalue-try-two-if-table-tuple-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-multivalue-try-block-two-if-table-tuple-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-multivalue-try-two-block-two-if-table-tuple-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-multivalue-try-three-if-table-tuple-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-multivalue-try-block-three-if-table-tuple-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-multivalue-try-two-block-three-if-table-tuple-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-multivalue-try-four-if-table-tuple-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-multivalue-try-block-four-if-table-tuple-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-multivalue-try-two-block-four-if-table-tuple-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-multivalue-try-five-if-table-tuple-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-multivalue-try-block-five-if-table-tuple-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-multivalue-try-two-block-five-if-table-tuple-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-multivalue-try-six-if-table-tuple-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-multivalue-try-block-six-if-table-tuple-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-multivalue-try-two-block-six-if-table-tuple-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-multivalue-try-seven-if-table-tuple-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-multivalue-try-block-seven-if-table-tuple-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-multivalue-try-two-block-seven-if-table-tuple-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-multivalue-try-unbounded-if-table-tuple-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-multivalue-try-two-block-ten-if-table-tuple-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-multivalue-try-block-ten-if-table-tuple-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-multivalue-try-ten-if-table-tuple-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-multivalue-try-two-block-nine-if-table-tuple-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-multivalue-try-block-nine-if-table-tuple-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-multivalue-try-nine-if-table-tuple-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-multivalue-try-eight-if-table-tuple-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-multivalue-try-block-eight-if-table-tuple-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-multivalue-try-two-block-eight-if-table-tuple-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-multivalue-try-block-table-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-multivalue-try-two-block-table-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-multivalue-try-three-block-table-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-multivalue-try-block-table-tuple-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-multivalue-try-two-block-table-tuple-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-multivalue-try-three-block-table-tuple-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-multivalue-try-table-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-multivalue-try-break-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-unsupported-policy-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-loop-conditional-unary-convert-refresh.md
  - ../../../raw/binaryen/2026-07-11-flatten-current-main-and-local-status-recheck.md
  - ../../../raw/binaryen/2026-04-27-flatten-port-readiness-primary-sources.md
  - ../../../raw/research/0422-2026-04-27-flatten-port-readiness.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/cli/cli_test.mbt
  - ../../../raw/research/0065-2026-03-24-ir2-execution-plan.md
  - ../../../raw/research/0063-2026-03-24-pass-port-batches-and-registry-map.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./flat-ir-contract-and-preludes.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../simplify-locals-notee-nostructure/index.md
  - ../local-cse/index.md
  - ../rereloop/index.md
  - ../i64-to-i32-lowering/index.md
---

# Starshine `flatten` port readiness and validation

Use this page after reading the overview in [`./index.md`](./index.md), the upstream strategy in [`./binaryen-strategy.md`](./binaryen-strategy.md), the concrete shape catalog in [`./wat-shapes.md`](./wat-shapes.md), and the current local status map in [`./starshine-strategy.md`](./starshine-strategy.md).

This page answers a narrower question: **what should the first Starshine implementation slices prove before `flatten` stops being a removed-name placeholder?**

## Current hold point

Starshine now has the first internal implementation slices, but does not yet expose `flatten` as a public runnable pass.

The exact current local surfaces are:

| Surface | Location | Meaning |
| --- | --- | --- |
| Removed-name registry | `src/passes/optimize.mbt:143-151` | `flatten` is known and intentionally tracked, but not runnable. |
| CLI pass-token preservation | `src/cli/cli_test.mbt:305-309` | `--flatten` survives trap-mode filtering. |
| CLI plus `-O` preservation | `src/cli/cli_test.mbt:340-342` | explicit `--flatten` survives beside an optimization-level flag. |
| Internal owner | `src/passes/flatten.mbt` | Flat IR classification, scalar body-result materialization, reachable/unreachable tee lowering across function roots, structured-region roots, and ordinary operand positions, ordered scalar operand preludes, branch-free defaultable scalar block/if routing, branch-free defaultable independently produced multivalue block/if, one exact exclusive tuple-made multivalue block tail, if-arm tail, plain block/if-targeting `br` payload, repeated-target `br_table` payload, or exact block/if-targeting `br_if` flow, and zero-input loop routing across payloadless backedges through exclusive consumer spans, branch-targeted independently scalar multivalue if arms with plain exits, scalar and exact independently scalar or tuple-made multivalue legacy try do/catch routing with plain carried try-label `br` exits and exact scalar try-label `br_if` direct-drop/unary/conversion/same-typed-binary false flow in either operand position and exact multivalue direct-drop, unary/conversion, or independently scalar / exclusively tuple-made same-typed-binary false flow plus exact scalar try-label `br_table` fanout through any complete strict direct-enclosure chain of matching block/if controls in structural order without a hardcoded count cap, and independently scalar multivalue fanout through the same arbitrary direct mixed order, including try-inside-if-inside-block, with exclusively tuple-made fanout admitted through the same arbitrary strict direct block/if order after separate exclusive-ownership, component, one-evaluation, and safe-deletion preflight without a hardcoded count cap, or one repeated try target behind an explicit catch-payload/exceptional-transfer prerequisite classifier, defaultable scalar branch-targeted if routing, zero-input and independently scalar or one exact tuple-made-entry inputful scalar-result loop routing with payloadless or independently scalar one- and multi-parameter `br`/`br_if` backedges, and plain scalar or independently scalar multivalue block-targeting `br`, scalar `br_if` routing including rich ordinary payload origins and the two-temp target/flow mismatch, same-vector multivalue block/if-targeting `br_if` routing across exact exclusive false-path spans, plus independently scalar `br_table` rich-origin and unique-target fanout for defaultable scalar block/if targets, exact repeated-label and nested multi-block multivalue targets, one- or multi-parameter loop entry channels, exact inputful multivalue loop plain branches and `br_if` channels with immediate direct-drop, same-typed binary with a simple opposite operand, one exact one-use rich right operand when the payload is left, or one exact pre-branch rich left paired with lane zero when the payload is right and the legacy-try or inputful-loop payload vector contains only individually supported rich origins, unary, or conversion false flow from independently scalar or tuple-made payloads, one exact exclusive tuple-made loop result tail, per-arm independently scalar or exact separately owned tuple-made legacy-try tails with supported scalar component origins, and exact loop-plus-block and loop-plus-if table channels, and owner-local terminal placeholders for nested `br`/`br_table`/`return`/`return_call`/`return_call_indirect`/`return_call_ref`/`throw`/`throw_ref` are implemented. Branch-free multivalue blocks and ifs plus zero-input multivalue loops with payloadless backedges and independently scalar defaultable tails route through ordered typed locals when all repeated HOT result uses form one exclusive consumer span. Unsupported root value-controls are kept out of scalar body-result materialization. Same-vector multivalue `br_if` payloads write independently scalar origins once into the shared target vector, replace one contiguous ordered false-path tail with matching reads, preserve the condition, and clear the payload children. Mismatched/shared multivalue `br_if` plus mixed if/loop or nonexclusive multivalue `br_table` payloads remain whole-function fail-closed; branch-targeted ifs now preflight every use and share one result temp across fallthrough plus carried `br`/`br_if` flow, while nondefaultable payloads also fail closed before mutation. Inputful loops now capture each independently scalar defaultable entry once in source order, redirect body uses through typed locals, and clear the loop parameter prefix. Scalar result routing remains separate; admitted plain-branch, exact immediate direct-drop or scalar-binary false-flow conditional, and table-backed multivalue-result families use a distinct ordered result vector. Payloadless zero-input and independently scalar defaultable one- or multi-parameter `br`/`br_if` backedges reuse typed entry locals, preserve payload order and one evaluation before conditional tests, preserve false-path flow, and clear their carried arity. One- or multi-parameter loop-targeting tables stage every independently scalar payload once in source order and copy each vector into unique target entry locals. Exact inputful multivalue loop-plus-block fanout additionally routes independently scalar or one exact exclusive tuple-made fallthrough result tail through separate locals; nondefaultable and multivalue single-producer table backedges fail closed before mutation. Plain multivalue block branches now write each independently scalar defaultable payload into the shared typed target vector in source order, while mixed blocks route independently scalar fallthrough tails through that same vector; nested plain exits are admitted after complete label-use preflight. Branch/control arity is cleared and an exclusive repeated consumer span remains required. Scalar legacy tries route exact do/catch tails through one typed local and admit plain carried `br` exits to the try label when every use is preflighted, each payload exactly matches the defaultable result type, and each other arm has an independently scalar matching fallthrough. Exact scalar try-label `br_if` also admits one immediate direct-drop, unary, conversion, or same-typed binary false-flow consumer with a simple opposite operand in the same arm; the exact multivalue family admits direct drops, independently scalar or exclusively owned repeated `TupleMake` unary/conversion lanes, and independently scalar same-typed binary lanes with simple opposite operands or exact one-use rich right operands when the payload is left in one reversed span. Payload work stays before condition work and both paths share the typed result channel. Multivalue payloads are independently scalar or one exclusively owned repeated `TupleMake`, whose components are scalarized once in source order. Exact terminal scalar table families admit one repeated try label, that try plus a strict direct-enclosure chain of matching defaultable blocks without a hardcoded length cap, or that try plus zero or more such blocks followed by one or more directly enclosing matching value `if`s, with all ifs outermost and no hardcoded count cap. Exact multivalue families admit one repeated try label; independently scalar payloads may target that try plus a strict direct-enclosure chain of matching blocks or zero or more such blocks followed by one or more directly enclosing matching value `if`s, with all ifs outermost and no hardcoded count cap; one exclusively owned repeated-`TupleMake` payload may target the unbounded strict block chain, or any strict directly enclosing matching block chain (including zero blocks) followed by one or more directly enclosing matching value `if`s with any such block chain and no hardcoded count cap. Payload stages copy into distinct per-label typed channels before selector work, and multivalue try fallthrough uses one exclusive repeated region-tail span. Multivalue legacy tries route per-arm exact independently scalar tails or separately owned exact tuple-made tails with supported scalar component origins through one shared typed vector when one exclusive repeated consumer span owns the results; exact plain try-label `br` payloads may independently provide scalar lanes or one exclusively owned repeated `TupleMake`. `flatten_eh_repair_requirement(...)` now classifies missing catch-payload tracking separately from exceptional-transfer repair before mutation. One exact scalar `Catch` first-descendant family and one ordered same-tag two-lane direct-block-chain family now repair through entry locals; unsupported `Catch`/`CatchAll` populations, partial/mixed-tag/third-lane payloads, non-first-descendant or repeated uses, broader lane paths, nested catches, loops/multiple execution, sharing/outside ownership, `rethrow`, and `delegate` remain whole-function fail-closed. Remaining richer tuple-made loop conditional consumers and mixed table loop backedges, mismatched or ambiguously shared multivalue `br_if`, mixed if/loop or nonexclusive multivalue `br_table`, nested or nonexclusive conditional multivalue loop controls, `rethrow`/`delegate` repair, conditional/table, shared/mixed tuple branch-targeted, and broader legacy-try/EH shapes, and other control work remain open. |
| Old IR2 batch plan | `../../../raw/research/0065-2026-03-24-ir2-execution-plan.md:69-70` | `flatten` remains first in an older Batch 2 order. |
| Old registry-map plan | `../../../raw/research/0063-2026-03-24-pass-port-batches-and-registry-map.md:107-108` | `flatten` remains removed until implemented. |
| Active backlog | `agent-todo.md` `[O4Z-FLAT]001` | records the remaining implementation, wiring, fuzzing, timing, and scheduler work. |

Read this as a deliberately internal partial implementation, not as public pass availability or parity evidence.

The internal bridge can lower Starshine's existing **resultless synthetic catch-all** `Try` representation and removes the bridge entirely when the body is proven nonthrowing, retaining only a void block when branches target the try label. HOT now represents ordered typed catch-entry payloads explicitly and lowers one scalar lane or exactly two same-tag lanes through scalar/result-only multivalue `try_table` handlers. Internal flatten repairs the scalar first-descendant family plus one exact ordered two-lane direct-block-chain family; broader payload relocation, `rethrow`, and `delegate` retain exact pre-mutation deferred outcomes. Immutable label-use and exact terminal-table support facts are cached once per rewrite state, payload-bearing branch rewrites avoid duplicate generic routing, lightweight reachable node-use counts preserve exact suffix ownership without full use-site allocation, and exact detached suffix forests tombstone with one revision invalidation after region detachment. Direct `i32.shl`, `i32.shr_s`, plus `i32.shr_u` resultless-call roots use the same complete distinct one-use proof as the prior audited binaries. The refreshed three-probe matrix remains a narrow measured size win (`212` Starshine cleanup bytes versus `236` Binaryen), but the current 120-function pass-local median is `970.5 us`, or `3.65x` Binaryen, and no GenValid/four-lane public matrix exists. EH representation, richer/shared/nested behavior, performance, and signoff are still hard public-readiness blockers; exact block/if/loop roots can now share one atomic vector with exactly recognized ordinary roots, but that does not close those broader gates; see the [current impact note](../../../raw/binaryen/2026-07-15-flatten-version-130-nonthrowing-bridge-suffix-cache-impact.md).

The latest internal performance/proof-boundary follow-up keeps those readiness conclusions unchanged. Exact branch users remain indexed once per label before mutation; one-for-one control-result tails use exact root replacement; admitted terminal-table dead suffixes now truncate the existing holder span before batch deletion; and scalar mutation-time target checks consume the pre-mutation branch index rather than rebuilding a post-mutation live-node view. The new red-first invariants pass at focused region editing `4/4` and private flatten `147/147`, with focused flatten `245/245`, passes `5,722/5,722`, and the full suite `9,183/9,183`. The reconstructed candidate median improved `1,116.5 -> 1,053.5 us` in code 1; code 2 did not produce a measurable timing win. The prior stable `970.5 us` checkpoint remains `3.65x` Binaryen.

The following multivalue proof/local-vector iteration also leaves readiness unchanged. Multivalue block/if target support now uses the immutable pre-mutation branch population during admission and rewrite, including recursive table-target proof. Admitted tables resolve every complete typed target-local vector once only after all semantic support checks pass; the resolver preflights all targets before allocating missing vectors. Private flatten reaches `149/149`, passes `5,724/5,724`, and the full suite `9,185/9,185`. One multivalue branch fixture improved `5,581.5 -> 5,099 us` (`8.64%`), but table-vector timings were order-sensitive and do not establish a win. No public pass surface changed, and performance remains a hard gate alongside typed EH, structured label-owner deletion, broader parity, the flatten-specific GenValid aggregate, and the four required signoff lanes.

The latest legacy-try branch/ownership iteration keeps that hold point unchanged. Multivalue legacy-try support now uses the exact pre-mutation label branch population, while legacy-try and loop conditional ownership use lightweight reachable counts instead of full use-def structures. Private flatten reaches `151/151`, passes `5,726/5,726`, and the full suite `9,187/9,187`. The targeted legacy-try `br_if` fixture improves `16,524.5 -> 6,724.5 us` (`59.31%`), but the stable representative checkpoint remains `3.65x` Binaryen. Public registry, dispatcher, CLI execution, compare/API, preset wiring, the flatten aggregate, four-lane signoff, ordered-neighborhood proof, typed EH, and structured label-owner deletion therefore remain blocked.

The region-tail/loop-branch iteration also leaves the hold point unchanged. Exact `TupleMake` tails now prove one-owner status from the pre-mutation reachable count plus the already-known region root/slot, and inputful-loop multivalue conditional/backedge proof uses the immutable label branch population and the same count snapshot throughout admission and rewrite. Private flatten reaches `153/153`, passes `5,728/5,728`, and the full suite `9,189/9,189`. Targeted fixtures improve `36.91%` and `17.67%`, but the representative fixture does not improve reliably and the stable result remains `3.65x` Binaryen. No semantic family, EH capability, mutation API, generator, signoff lane, or public surface is admitted.

The loop-entry/scalar-try ownership iteration keeps the same hold point. Exact tuple-made inputful-loop entries and exact scalar legacy-try `br_if` false flow now consume the frozen reachable counts behind explicit rewrite-only helpers; post-snapshot extra uses fail uncached without widening mutation-time proof. Private flatten reaches `155/155`, passes `5,730/5,730`, and the full suite `9,191/9,191`. Targeted fixtures improve `58.64%` and `52.47%`, but the stable representative remains `3.65x` Binaryen. Public registry, dispatcher, CLI execution, compare/API, preset wiring, the aggregate, four-lane signoff, ordered-neighborhood proof, typed EH, and structured label-owner deletion remain blocked.

The tuple branch/conditional-flow iteration also keeps the hold point unchanged. Tuple-made plain branch/table payload proof now uses frozen reachable counts, while generic tuple-made block/if `br_if` flow uses a bounded reachable locator whose exact positive or negative site result is cached before mutation and required by rewrite. Private flatten reaches `157/157`, passes `5,732/5,732`, and the full suite `9,193/9,193`. Targeted fixtures improve `61.76%` and `56.30%`, and the last full node-use/use-site builder is gone from flatten, but the durable representative remains an unrequalified `3.65x` Binaryen.

The distinct/scalar conditional-site iteration keeps the same hold point. Distinct non-tuple block/if `br_if` flow now caches its exact contiguous parent/start during admission. Scalar flow snapshots exact parent populations, permits only expected in-parent slot shifts, and cannot discover a post-snapshot parent during rewrite. Private flatten reaches `159/159`, passes `5,734/5,734`, and the full suite `9,195/9,195`. The distinct fixture moves `30 -> 28 ms`, while scalar moves `22 -> 23 ms` and is correctness-only. Public registry, dispatcher, CLI execution, compare/API, preset wiring, the aggregate, four-lane signoff, ordered-neighborhood proof, typed EH, structured label-owner deletion, and representative performance remain blocked.

The sparse proof-cache iteration also leaves the hold point unchanged. `e165fde1c` stores conditional flow and chained replacement proof only for admitted branches/values; `476848f9d` stores suffix, terminal-table, and scalar-try proof only for inspected owners. Exact negative flow decisions, parent populations, region identity, target labels, payload arity, mixed-target policy, and support results remain frozen before mutation, and missing entries still fail closed after the boundary. Private flatten reaches `161/161`, passes `5,736/5,736`, and the full suite `9,197/9,197`. Coarse reconstructed timing is directional, flat, or slightly slower depending on the slice and does not replace the `970.5 us` / `3.65x` gate. Public registry, dispatcher, CLI execution, compare/API, preset wiring, the aggregate, four-lane signoff, ordered-neighborhood proof, typed EH, and structured label-owner deletion remain blocked.

The postorder-routing/shared-root iteration also leaves the hold point unchanged. `7801166ac` dispatches the generic late branch router only for carried plain `br`; `18101a947` stores sequence-root identity only for exact pre-mutation shared nodes and rejects rewrite-created ids beyond the frozen count population. The latter's first implementation produced five focused failures before the snapshot node limit restored failure-atomic lookup. Private flatten reaches `163/163`, passes `5,738/5,738`, and the full suite `9,199/9,199`. A repeatable native-release pass-only path now exists through temporary `passes_perf_long` sources saved under `.tmp`, but its reconstructed `1,171.5 us` representative is not the lost original gate harness and cannot replace the durable `970.5 us` / `3.65x` result. Public registry, dispatcher, CLI execution, compare/API, preset wiring, the aggregate, four-lane signoff, ordered-neighborhood proof, typed EH, structured label-owner deletion, and representative performance remain blocked.

The single-target staging/inputful-loop support iteration also leaves the hold point unchanged. `81cfb9619` writes one-unique-target table payloads directly into the resolved target vector and removes the otherwise redundant staging local plus copy per lane; multi-target fanout remains unchanged. The focused encoded probe shrinks `51 -> 47` bytes, while representative timings overlap the pre-iteration baseline. `dda2bdfe3` freezes each inspected inputful-loop support result and makes an absent post-mutation entry fail closed. Private flatten reaches `165/165`, passes `5,740/5,740`, and the full suite `9,201/9,201`; the loop fixture is timing-flat at `2,589 -> 2,584 us`. Public registry, dispatcher, CLI execution, compare/API, preset wiring, the aggregate, four-lane signoff, ordered-neighborhood proof, typed EH, structured label-owner deletion, and representative performance remain blocked.

The branch-append/admission-roster iteration also leaves the hold point unchanged. `6a74918d6` preserves exact per-label branch order while deduplicating only repeated targets from the current node without scanning prior users. `1acb9bc14` makes the same pre-mutation scan record exact loop, legacy-try, and payload-bearing branch admission rosters, eliminating three whole-function discovery scans without relaxing any family proof. Private flatten reaches `167/167`, passes `5,742/5,742`, and the full suite `9,203/9,203`. Targeted reconstructed fixtures improve `13.72%` and `6.45%`, with directional representative movement, but the durable `970.5 us` / `3.65x` checkpoint remains the public gate. Public registry, dispatcher, CLI execution, compare/API, preset wiring, the aggregate, four-lane signoff, ordered-neighborhood proof, typed EH, and structured label-owner deletion remain blocked.

The EH/flatness scan-sharing iteration also leaves the hold point unchanged. `7706110c1` records exact typed-catch-payload and exceptional-transfer prerequisites in the immutable pre-mutation index and makes rewrite state reuse them; `2c5a54ac3` records the complete Flat IR violation report in that scan and makes `flatten_run` consume it while retaining the standalone classifier on shared helpers. Their red-first invariants cover 256 unrelated roots and exact equality with prior analysis results. Private flatten reaches `169/169`, passes `5,744/5,744`, and the full suite `9,205/9,205`. Code 1 improves the reconstructed representative `6.28%`; code 2 has no stable speed win. The durable `970.5 us` / `3.65x` checkpoint remains the public gate. Public registry, dispatcher, CLI execution, compare/API, preset wiring, the aggregate, four-lane signoff, ordered-neighborhood proof, typed EH repair, and structured label-owner deletion remain blocked.

The sparse proof lookup iteration also leaves the hold point unchanged. `c420a9950` sorts scalar legacy-try entries and uses binary lookup; `9b5c4170a` does the same for dead-suffix and terminal-table entries. Both retain sparse allocation, exact pre-mutation identities, first-proof authority, and missing-entry failure after rewriting starts. Their red-first invariants queried owners out of order and failed on append order before the sorted path landed. Private flatten reaches `171/171`, passes `5,746/5,746`, and the full suite `9,207/9,207`.

The targeted scalar density fixture improves `5.99%`, and the terminal density fixture improves `58.49%`; the reconstructed representative is order-sensitive and overlapping, so the durable `970.5 us` / `3.65x` checkpoint remains the public gate. Public registry, dispatcher, CLI execution, compare/API, preset wiring, the aggregate, four-lane signoff, ordered-neighborhood proof, typed EH repair, structured label-owner deletion, broader behavior, and representative performance remain blocked.

The inputful-loop/scalar-flow proof-lookup iteration also leaves the hold point unchanged. `e32819f5b` sorts sparse inputful-loop support by exact loop id and uses binary lookup. `fc5c89bff` sorts scalar `br_if` flow sites by branch id and same-state replacements by original value id, preserving first admission proof plus replacement-update semantics. Their red-first invariants fail on mixed query order before implementation and private flatten reaches `173/173` afterwards. Fixed-total density fixtures improve inputful loops `9.57%` and scalar flow `3.34%` at 128 candidates per function. Focused flatten is `245/245`, passes are `5,748/5,748`, the full suite is `9,209/9,209`, and `moon info` is green with 11 existing warnings.

No public-readiness predicate changed. Public registry, dispatcher, CLI execution, compare/API, preset wiring, the flatten aggregate, four-lane signoff, ordered-neighborhood proof, typed EH repair, structured label-owner deletion, broader behavior, and the unrequalified `970.5 us` / `3.65x` performance gate remain blocked.

The tuple/distinct conditional-flow proof-lookup iteration also leaves the hold point unchanged. `80e6a652b` sorts tuple-made multivalue `br_if` flow entries by exact branch id; `efb8fdfa2` applies the same helper to distinct non-tuple flow and removes the final linear conditional-flow lookup. Both preserve explicit negative admission results, first-proof authority, current cached parent/slot checks, and absent-entry failure after mutation begins. Their mixed-order red-first invariants move private flatten to `175/175`; focused flatten is `245/245`, passes are `5,750/5,750`, the full suite is `9,211/9,211`, and `moon info` is green with 11 existing warnings.

Exact cached-lookup reconstruction improves tuple flow `47.34%` and distinct flow `66.89%` at 512 candidates, but it is owner-specific telemetry rather than representative gate requalification. Public registry, dispatcher, CLI execution, compare/API, preset wiring, the flatten aggregate, four-lane signoff, ordered-neighborhood proof, typed EH repair, structured label-owner deletion, broader behavior, and the unrequalified `970.5 us` / `3.65x` performance gate remain blocked.

The table-target/terminal-payload lookup iteration also leaves the hold point unchanged. `bdad9efaf` marks each valid table label once while preserving first source order and a previously unseen default target last. `902848fca` keeps terminal payload roots sparse, sorted by exact node id, and binary-searchable; duplicate records are rejected and absent roots remain absent. Their red-first invariants move private flatten to `177/177`; focused flatten is `245/245`, passes are `5,752/5,752`, the full suite is `9,213/9,213`, and `moon info` is green with 11 existing warnings.

Dense owner-specific reconstruction improves target extraction `437,000 -> 16,000 us` and terminal payload membership `110,000 -> 20,000 us` at 512 candidates. These results do not recover the original representative contract or change any readiness predicate. Public registry, dispatcher, CLI execution, compare/API, preset wiring, the flatten aggregate, four-lane signoff, ordered-neighborhood proof, typed EH repair, structured label-owner deletion, broader behavior, and the unrequalified `970.5 us` / `3.65x` performance gate remain blocked.

The immutable-index/reusable-scratch iteration also leaves the hold point unchanged. Unique table targets, lazily built structural parents, reusable node marks, depth-indexed prelude buffers, dense type-result caching, and direct per-label target-local retrieval remove repeated allocation and scanning without admitting a new shape. Every candidate still enters through frozen pre-mutation identities; missing table or parent facts after mutation begins reject, and family helpers still own type, label, EH, effect, trap, flow, ownership, and deletion proof.

Private flatten is `182/182`, focused flatten `245/245`, passes `5,757/5,757`, the full suite `9,218/9,218`, and `moon info` is green with 11 existing warnings. The reconstructed representative is nonregressing (`1,001.5 -> 989.5 us`, overlapping), while owner microbenchmarks improve `9.68%` to `96.88%`. No readiness predicate changed: public registry, dispatcher, CLI execution, compare/API, preset wiring, the flatten aggregate, four-lane signoff, ordered-neighborhood proof, typed EH repair, structured label-owner deletion, broader behavior, and the unrequalified `970.5 us` / `3.65x` gate remain blocked.

The sequenced-root/multivalue-payload lookup iteration also leaves the hold point unchanged. `4a03de7f3` keeps sparse exact `(holder, node)` identities sorted and binary-searchable while preserving the pre-mutation shared-root and rewrite-created-id boundaries. `aa295d38b` marks exact multivalue `br_if` payload ids once for duplicate rejection and root exclusion while retaining source order plus the cached false-flow parent/start proof. Their red-first invariants move private flatten to `184/184`; focused flatten is `245/245`, passes are `5,759/5,759`, the full suite is `9,220/9,220`, and `moon info` is green with 11 existing warnings.

The targeted 512-candidate medians improve sequenced-root lookup `91.56%` and payload distinctness `95.73%`, but no representative measurement or public contract was requalified. Public registry, dispatcher, CLI execution, compare/API, preset wiring, the flatten aggregate, four-lane signoff, ordered-neighborhood proof, typed EH repair, structured label-owner deletion, broader behavior, and the durable `970.5 us` / `3.65x` gate remain blocked.

The multivalue flow-index iteration also leaves the hold point unchanged. `f1dc57565` indexes distinct non-tuple payload ids by exact source slot during reachable false-flow discovery; `24b909b2d` marks tuple false-flow child slots for exact duplicate rejection. Both retain complete counts, branch-slot coverage/exclusion, one non-branch parent, contiguous order, cached parent/start/current-slot validation, and missing-proof rejection after mutation begins. Their red-first invariants move private flatten to `186/186`; focused flatten is `245/245`, passes are `5,761/5,761`, the full suite is `9,222/9,222`, and `moon info` is green.

The targeted 512-candidate medians improve `97.92%` and `97.71%`, but no representative measurement or public contract was requalified. Public registry, dispatcher, CLI execution, compare/API, preset wiring, the flatten aggregate, four-lane signoff, ordered-neighborhood proof, typed EH repair, structured label-owner deletion, broader behavior, and the durable `970.5 us` / `3.65x` gate remain blocked.

The reversed-binary feature iteration narrows one documented control-flow gap. Independently scalar and exclusively tuple-made multivalue `br_if` false flow now accepts the restored payload as the right operand of an immediate same-typed binary when the left operand is simple. Commits `2ae0a6adb` and `d64535310` preserve one evaluation before the condition, direct false-path placement, exact one-use or tuple-complete ownership, opcode/type checks, and slot-local replacement. Focused flatten reaches `247/247`; passes reach `5,763/5,763`; full reaches `9,224/9,224`.

This does not change the hold point. Typed catch payload/pop repair, `rethrow`/`delegate`, verified structured control-plus-owned-label deletion, broader shared/nested/mixed control flow, the flatten aggregate, four-lane signoff, ordered neighborhood, and public admission remain blocked. Future iterations should continue closing behavior families before revisiting small pass-local timing owners.

The rich-right feature iteration narrows the remaining opposite-operand gap. Commits `5c4a664dd` and `a4055b7a9` allow payload-left independently scalar and exclusively tuple-made lanes to retain one exact one-use rich right operand. The ordinary prelude walker materializes that operand after payload-free `br_if`; pinned-v130 legacy-try and inputful-loop probes confirm calls stay on the not-taken path. Red-first focused counts move `247/248 -> 248/248` and `248/249 -> 249/249`; private flatten remains `186/186`, passes reach `5,765/5,765`, and full reaches `9,226/9,226`.

The hold point is still unchanged. Typed EH, exceptional transfer, structured label-owner deletion, broader mixed/shared/nested flow, the flatten aggregate, four-lane signoff, ordered neighborhood, performance requalification, and public admission remain blocked.

The rich-left feature iteration closes one exact evaluation-order subset. Commits `e5c2a91ea` and `d0a53acf9` allow independently scalar and exclusively tuple-made legacy-try payload-right binaries to retain one one-use rich left when the complete payload vector is simple. Source stack order permits that left value only before the whole payload vector, so it pairs with lane zero after higher lanes are consumed. Rewrite stages it before payload locals and `br_if`; pinned-v130 probes confirm the call remains taken-path-observable while the binary remains not-taken-only. Red-first focused counts move `249/250 -> 250/250` and `250/251 -> 251/251`; private flatten remains `186/186`, passes reach `5,767/5,767`, and full reaches `9,228/9,228`.

The hold point remains unchanged. Multiple or non-lane-zero rich lefts, rich payload origins combined with pre-branch left work, typed EH, exceptional transfer, structured label-owner deletion, broader mixed/shared/nested flow, the flatten aggregate, four-lane signoff, ordered neighborhood, performance requalification, and public admission remain blocked.

The inputful-loop rich-left iteration closes the exact loop counterpart without changing that hold point. Commits `843614438` and `35ac3740a` stage one one-use rich left before a complete simple independently scalar or exclusively tuple-made payload vector, restrict it to lane zero's final reversed consumer, and preserve the binary after a not-taken `br_if`. The red-first focused sequence is `251/252 -> 252/252 -> 252/253 -> 253/253`; private flatten is `186/186`, passes `5,769/5,769`, full `9,230/9,230`, and `moon info` is green. Public registry, dispatcher, CLI execution, compare/API, GenValid, preset, and exact-neighborhood readiness remain unchanged.

The inputful-loop rich-payload follow-up narrows the composition gap further without changing the public hold point. Commits `3cb5577ad` and `c5a0a738a` allow at most one supported rich payload origin alongside the existing pre-branch rich left, for independently scalar and exclusively tuple-made ownership. The tuple slice first exposed a payload-before-left ordering regression after admission; inserting the left store before child-generated payload preludes restores the pinned-v130 order. Red-first focused counts move `253/254 -> 254/254 -> 254/255 -> 255/255`; private flatten is `186/186`, passes `5,771/5,771`, full `9,232/9,232`, and `moon info` is green. The one-rich boundary is superseded by the later multiple-rich iteration; typed EH, structured owner deletion, broader flow, aggregate/signoff, neighborhood, performance, and public admission remain blocked.

The legacy-try rich-payload follow-up closes the exact counterpart without changing the public hold point. Commits `61055698d` and `d9aa4cd94` admit at most one supported rich payload origin alongside one pre-branch rich left for independently scalar lanes and one exclusively owned repeated `TupleMake`. The rewrite inserts the rich-left store before child-generated payload preludes; the tuple route still requires complete branch-plus-consumer ownership and deletes the shell only after exact replacement. Red-first focused counts move `255/256 -> 256/256 -> 256/257 -> 257/257`; private flatten is `186/186`, passes `5,773/5,773`, full `9,234/9,234`, and `moon info` is green. Public registry, dispatcher, CLI execution, compare/API, GenValid, preset, neighborhood, and performance readiness remain unchanged.

The multiple-rich-payload follow-up removes that temporary cap without changing the public hold point. Commit `6e4229bae` admits every independently scalar rich payload origin for the exact legacy-try and inputful-loop rich-left family; commit `f223f14d6` admits the same vector for one exclusively owned repeated `TupleMake`. Every origin remains individually supported, scalar lanes retain exact branch-plus-consumer ownership, tuple flow retains complete branch-slot/consumer coverage and delayed shell deletion, and the rich left remains lane-zero-only. One red-first test per commit covers both controls. Focused flatten moves `257/258 -> 258/258 -> 258/259 -> 259/259`; private flatten is `186/186`, passes `5,775/5,775`, full `9,236/9,236`, and `moon info` is green. Four pinned-v130 probes preserve left, all payload calls in vector order, condition, payload-free branch, and false-path binary order.

The structured-subtree iteration resolves the mutation prerequisite and one exact suffix family without changing the public hold point. Commit `62c330a12` adds atomic detached control-plus-owned-label deletion with complete preflight and one revision advance. Commit `f7829507b` admits one void `block { drop(const) }` after an unconditional scalar legacy-try `br_table`; the pass proves one owner for every node, no target users for the block label, and exact current structure before any rewrite. The red-first flatten test moves `259/260 -> 260/260`; IR is `319/319`, private flatten `186/186`, passes `5,776/5,776`, full `9,238/9,238`, and `moon info` is green. Binaryen v130 retains the block under direct flatten, while `--vacuum --dce` reduces the probe from `76` to `63` encoded bytes, so Starshine's direct deletion is an evidence-backed cleanup win rather than unclassified shape drift.

Public registry, dispatcher, CLI execution, compare/API, GenValid, preset, neighborhood, and performance readiness remain unchanged. Typed catch payload/pop repair, `rethrow`/`delegate`, broader structured roots and mixed suffixes, mixed/shared/nested flow, multiple/non-lane-zero rich lefts, the flatten aggregate, four-lane signoff, ordered neighborhood, performance requalification, and public admission remain blocked.

## First decision: local Flat IR contract

Binaryen's pass is defined by `src/ir/flat.h`, not by the English phrase “remove nesting.”

A future Starshine port should first decide how to express the same contract locally:

1. a verifier-like analysis that reports non-flat HOT/IR2 shapes;
2. a committed normal-form invariant that downstream passes can rely on; or
3. an explicitly different Starshine invariant with documented Binaryen divergence.

The minimum analyzer should classify these families before rewriting anything:

- ordinary operands that are not constants, `local.get`, `unreachable`, or allowed `ref.as_non_null`;
- value-carrying `block`, `loop`, `if`, and legacy `try`;
- reachable `local.tee`;
- `local.set` whose value is control flow;
- concrete function-body flow that needs `return` wrapping;
- carried `br`, `br_if`, and `br_table` values;
- unsupported `BrOn*` and `TryTable` families;
- legacy EH `catch` / `pop` shapes that require repair after block insertion.

That analyzer-only slice gives reviewers a safe way to compare Starshine's shape classifier against Binaryen before the pass starts manufacturing locals.

## Minimum mutating slice

The first mutating slice should be deliberately small.

Recommended order:

1. simple expression spill;
2. function-body concrete result wrapping;
3. value-carrying `block` rewrite;
4. value-carrying `if` rewrite with arm temp stores;
5. condition-prelude placement before the whole `if` and arm-prelude placement inside each arm.

This order teaches the pass's core mechanism without immediately entangling branch payloads, EH repair, or unsupported feature policy.

The first tests should prove both positives and non-rewrites:

- nested arithmetic or call child becomes temp-local traffic;
- already-simple children stay simple;
- concrete function body becomes explicit `return` / local-read shape;
- branch-free defaultable scalar block results are routed through a temp, while branch-targeted blocks stay deferred until their payload channel can be repaired;
- value-carrying if arms write the same temp;
- condition work stays in the owning prelude while arm work remains inside its selected arm;
- `ref.as_non_null` remains governed by the special flatness rule rather than spilled blindly.

## Second slice: tees and branch payload channels

After basic value routing is green, add the payload-specific cases that make `flatten` more than a simple “spill nested values” pass:

- reachable `local.tee` now lowers to an ordered `local.set` prelude plus `local.get` at function roots, structured-region roots, and ordinary operand positions;
- unreachable `local.tee` now keeps the real unreachable effect in the owner prelude or region root and does not invent a reachable write;
- carried scalar `br` into a defaultable scalar block target now stores into one named-target temp, clears the branch payload, and lets a terminal branch-targeted block erase its result type;
- same-type carried `br_if` now stores once into the named target temp, clears the branch payload, and redirects the peeked false-path flow through one shared `local.get`;
- rich ordinary scalar `br_if` payloads are sequenced before rich conditions, evaluated once, and shared across repeated chained conditionals instead of being reevaluated by generic operand spilling;
- the source-derived `br_if` target-type versus flowing-out-type mismatch uses a second flow-typed temp, one payload evaluation, and a typed copy into the target temp;
- same-vector multivalue `br_if` into defaultable block/if targets now evaluates each supported scalar payload once in source order, writes the target's shared typed local vector, replaces the exact contiguous false-path tail with matching reads, clears only payload children, and preserves the condition; mismatched vectors, unsupported origins, and ambiguous/shared false-path ownership remain fail-closed before mutation;
- scalar `br_table` stores rich ordinary payloads once before rich selectors, copies into every unique target temp, deduplicates repeated labels, clears its payload, and removes the HOT terminal payload-root artifact; exact independently scalar multivalue vectors now cover repeated/nested block targets and exact inputful loop-plus-enclosing-block, loop-plus-repeated-if, and loop-plus-repeated-block families, while broader mixed-control and nonexclusive fanout remain open. Terminal legacy-try table target ancestry is preflighted with one direct structural parent map and outward chain walk rather than repeated candidate scans; ordered, skipped, and reverse-policy private boundaries are locked, and the warm three-block-plus-thirty-two-if focused fixture measured 0.187s.

The two-temp scalar `br_if` family remains a must-have parity test because it is easy to miss and is explicitly motivated by upstream source comments. The v130 concrete-type owner also motivates the same-vector multivalue correspondence, but Starshine keeps stricter ownership gates until broader tuple-flow proof exists.

## Third slice: loops, legacy try, EH, and unsupported features

Only after the simpler families are stable should a port claim broader pass coverage.

Required tests before any parity claim:

- zero-input and independently scalar inputful scalar-result `loop` route body results through a temp and leave a `local.get` outside; admitted inputful loops capture entries once in order and clear their parameter prefix, payloadless and independently scalar one- or multi-parameter `br`/`br_if` backedges reuse entry locals, and independently scalar one- or multi-parameter `br_table` backedges stage ordered vectors into unique target entry locals. Multivalue `br_if` false-path flow admits an immediate reversed span of direct drops, exact single-use same-typed binary expressions with a simple opposite operand or one exact one-use rich right operand when the restored payload is left, or one exact pre-branch rich left paired with lane zero when every rich payload origin is individually supported, or exact single-use unary/conversion expressions; shared, nested, non-immediate, and mismatched consumers remain gated. The inputful multivalue-result table lanes additionally permit exact loop-plus-enclosing-block fanout with independently scalar fallthrough tails, or one repeated exclusive block/if result tail that feeds a distinct loop-result vector; multivalue single-producer table channels remain explicit negatives;
- branch-free scalar and independently produced multivalue legacy `try` now route exact do/catch results through shared typed locals; multivalue ownership requires one exclusive repeated consumer or region-tail span. One scalar first-descendant `Catch` use and one exact ordered same-tag two-lane direct-block-chain family repair through entry locals, while every unsupported catch population selects `DeferredCatchPayloadRepair` and `rethrow`/`delegate` select `DeferredExceptionalTransferRepair` before ordinary mutation;
- the catch repair transaction remains whole-function fail-closed for partial/mixed-tag/third-lane payloads, non-first-descendant or repeated uses, broader independent lane paths, nested catches, loops/multiple execution, sharing/outside ownership, and catch-all payloads; every admitted inserted-catch-block shape must validate after lowering;
- placeholder `unreachable` now preserves nested terminal `br`/`br_table`/`return`/`return_call`/`return_call_indirect`/`return_call_ref`/`throw`/`throw_ref` effects in their owner region without duplicating effects that HOT already exposes as an earlier root; branch payload, tail-call operand, and throw-argument work remains before the terminal in source order and later sibling preludes remain later, while `rethrow`/`delegate` stay gated with EH repair;
- `BrOn*` and `TryTable` have an explicit documented policy.

Binaryen v130 hard-fails on all four `BrOn*` variants, and a direct `TryTable` probe aborts in the earlier unhandled control-structure arm. Internal Starshine now classifies all five through `FlattenRunAdmission::UpstreamHardUnsupported` before mutation and leaves the function byte-for-byte structurally untouched at HOT level. This is a safe internal gate, not public behavior parity: public registry/CLI/harness admission remains blocked until a tested Binaryen-compatible rejection path replaces or wraps the internal unchanged result. Source: [`../../../raw/binaryen/2026-07-13-flatten-version-130-unsupported-policy-refresh.md`](../../../raw/binaryen/2026-07-13-flatten-version-130-unsupported-policy-refresh.md).

## Latest structured suffix breadth

Commits `51d080e09` and `cbb1a2395` extend atomic control-plus-owned-label deletion to one exact void `if` and one exact zero-input/no-backedge void `loop`. Commits `8b69a8e4c` and `f524b8bcb` add control-forest deletion and admit control-only vectors. Commit `04cc07657` then adds generic `hot_delete_detached_forest(...)` for ordinary or control roots while preserving complete descendant/label preflight; commit `ca159e6d0` admits scalar/control-mixed vectors only when every root already passes an exact recognizer and both root kinds occur. The wrappers retain control-only validation.

The generic API red-first test failed on the unbound symbol and then passes HOT mutation `13/13` plus IR `321/321`. The mixed `drop(const) + block + if + loop + unreachable` fixture failed unchanged at `262/263`, then passes `263/263`; private flatten is `186/186`, passes `5,779/5,779`, full `9,243/9,243`, and `moon info` is green with 11 existing warnings. Fresh pinned Binaryen v130 retains the complete mixed suffix under direct flatten at `76` bytes, while matched `--vacuum --dce` removes it at `63` bytes. Nonconstant/effectful conditions, partial/richer arms, inputful/value loops, backedges, try-like roots, sharing, outside label users, typed EH, exceptional transfer, broader mixed/shared/nested flow, signoff, and performance remain fail-closed or incomplete.

## Latest ordered two-lane catch repair and unchanged public hold point

The first scalar Binaryen v130 nested-pop family is now joined by one exact ordered two-lane subset. Generic HOT preflight accepts two childless same-tag scalar markers only when the catch has one subsequent exclusive direct block chain and the final region's first two roots contain exact unary lane-zero/lane-one use paths. Locals are allocated in source order, handler-stack captures are inserted in reverse lane order, and the old positions become matching local reads. Any partial second lane, mixed tag, third lane, sharing/outside use, loop, nested exceptional control, catch-all marker, or alternate ancestry rejects before mutation.

Flatten admits that plan only after all other whole-function gates pass, applies it before ordinary rewriting, rebuilds every immutable analysis/proof snapshot, and then continues. HOT lowering accepts at most two lanes and requires an existing result-only multivalue handler block type for the pair. The whitebox fixture uses an `(i32, f32)` payload beneath two nested blocks followed by a branch to the enclosing block; HOT verification, lowering, and final module validation are green.

The red-first sequence was: unbound ordered repair APIs; then ordered catch admission remained deferred. Final validation is HOT mutation `16/16`, IR `326/326`, focused flatten `263/263`, whitebox flatten `188/188`, passes `5,781/5,781`, full `9,250/9,250`, `moon fmt`, and `moon info` with 11 existing warnings. Non-first-descendant/repeated payload use, broader independent lane paths, nested catches, loops/multiple execution, catch-all payloads, `rethrow`, and `delegate` remain open. Therefore the flatten aggregate, four-lane matrix, ordered neighborhood, performance requalification, and public admission remain blocked; the durable representative remains `970.5 us` / `3.65x` Binaryen and was not remeasured.

## Downstream validation lanes

Once direct reduced tests are green, validate the cluster role that makes `flatten` worth porting:

1. direct `--pass flatten` comparison against Binaryen for supported shapes;
2. `flatten -> simplify-locals-notee-nostructure -> local-cse` reduced lanes;
3. `flatten -> rereloop` reduced lanes;
4. `flatten -> i64-to-i32-lowering` reduced lanes;
5. saved generated-artifact `-O4z` slot replay for slot `9` once the pass is runnable;
6. nested aggressive rerun checks, because the saved Binaryen debug log showed many total `flatten` executions in a full `-O4z` run.

Use `moon build --target native --release src/cmd` followed by `bun fuzz compare-pass ... --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe` or `bun scripts/pass-fuzz-compare.ts ... --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe` only after reduced shape tests make the supported-surface policy clear. The pass has hard unsupported upstream families, so a raw broad fuzz lane without feature filtering can produce misleading failures.

## What should block removing `flatten` from `pass_registry_removed_names()`

Do not move `flatten` out of removed status until all of these are true:

- a real owner file exists;
- the dispatcher has an explicit active case;
- the CLI accepts an explicit `--flatten` request without treating it as removed;
- direct reduced shape tests cover basic spill, value-carrying control, tees, branch payloads, placeholders, and unsupported-family policy;
- the Starshine strategy page links the exact owner, dispatcher, registry, and tests;
- the tracker records whether the port is partial or parity-complete;
- the active backlog has either a completed slice or no stale `flatten` TODOs.

## Open questions

- Should Starshine implement a standalone Flat IR verifier, or should the pass itself own the analyzer/classifier?
- Should unsupported `BrOn*` and `TryTable` match Binaryen's hard failure or become Starshine pass-gates?
- Which local EH helper should own the equivalent of Binaryen `EHUtils::handleBlockNestedPops(...)`?
- Should the first runnable port be HOT-based, IR2-based, or a module/function hybrid that only uses HOT for eligible bodies?

## Bottom line

The safe local sequence is:

1. prove the Flat IR classifier;
2. land narrow value-spill and control-result rewrites;
3. add tee and branch-payload channels;
4. add EH and unsupported-feature policy;
5. only then wire aggressive-cluster and Binaryen-oracle validation.

That keeps `flatten` honest as a structural normalizer and prevents a future port from becoming a vague nesting cleanup with the upstream name.
