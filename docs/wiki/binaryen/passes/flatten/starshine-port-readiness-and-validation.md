---
kind: concept
status: supported
last_reviewed: 2026-07-17
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
  - ../../../raw/research/1569-2026-07-17-flatten-public-parity-closeout.md
  - ../../../raw/research/1570-2026-07-17-flatten-preset-scheduling-and-performance.md
  - ../../../raw/binaryen/2026-04-25-flatten-current-main-implementation-test-map.md
  - ../../../raw/binaryen/2026-04-23-flatten-primary-sources.md
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

This page preserves the staged proof history for the question: **what did the first Starshine implementation slices need to prove before `flatten` stopped being a removed-name placeholder?**

## Current status

The pre-admission hold point below is superseded. `flatten` is now public, compared, and scheduled in both top-level presets as `flatten -> simplify-locals-notee-nostructure -> local-cse`. Behavior closeout is in [`1569-2026-07-17-flatten-public-parity-closeout.md`](../../../raw/research/1569-2026-07-17-flatten-public-parity-closeout.md); scheduling and current `4.00x` Binaryen performance qualification are in [`1570-2026-07-17-flatten-preset-scheduling-and-performance.md`](../../../raw/research/1570-2026-07-17-flatten-preset-scheduling-and-performance.md). Performance remains the open gate.

## Historical pre-admission hold point (superseded)

At the 2026-07-16 hold point, Starshine had internal implementation slices but did not yet expose `flatten` as a public runnable pass.

The exact historical local surfaces were:

| Surface | Location | Meaning |
| --- | --- | --- |
| Removed-name registry | `src/passes/optimize.mbt:143-151` | `flatten` is known and intentionally tracked, but not runnable. |
| CLI pass-token preservation | `src/cli/cli_test.mbt:305-309` | `--flatten` survives trap-mode filtering. |
| CLI plus `-O` preservation | `src/cli/cli_test.mbt:340-342` | explicit `--flatten` survives beside an optimization-level flag. |
| Internal owner | `src/passes/flatten.mbt` | Flat IR classification, scalar body-result materialization, reachable/unreachable tee lowering across function roots, structured-region roots, and ordinary operand positions, ordered scalar operand preludes, branch-free defaultable scalar block/if routing, branch-free defaultable independently produced multivalue block/if, one exact exclusive tuple-made multivalue block tail, if-arm tail, plain block/if-targeting `br` payload, repeated-target `br_table` payload, or exact block/if-targeting `br_if` flow, and zero-input loop routing across payloadless backedges through exclusive consumer spans, branch-targeted independently scalar multivalue if arms with plain exits, scalar and exact independently scalar or tuple-made multivalue legacy try do/catch routing with plain carried try-label `br` exits and exact scalar try-label `br_if` direct-drop/unary/conversion/same-typed-binary false flow in either operand position and exact multivalue direct-drop, unary/conversion, or independently scalar / exclusively tuple-made same-typed-binary false flow plus exact scalar try-label `br_table` fanout through any complete strict direct-enclosure chain of matching block/if controls in structural order without a hardcoded count cap, and independently scalar multivalue fanout through the same arbitrary direct mixed order, including try-inside-if-inside-block, with exclusively tuple-made fanout admitted through the same arbitrary strict direct block/if order after separate exclusive-ownership, component, one-evaluation, and safe-deletion preflight without a hardcoded count cap, or one repeated try target behind an explicit catch-payload/exceptional-transfer prerequisite classifier, defaultable scalar branch-targeted if routing, zero-input and independently scalar or one exact tuple-made-entry inputful scalar-result loop routing with payloadless or independently scalar one- and multi-parameter `br`/`br_if` backedges, and plain scalar or independently scalar multivalue block-targeting `br`, scalar `br_if` routing including rich ordinary payload origins and the two-temp target/flow mismatch, same-vector multivalue block/if-targeting `br_if` routing across exact exclusive false-path spans, plus independently scalar `br_table` rich-origin and unique-target fanout for defaultable scalar block/if targets, exact repeated-label and nested multi-block multivalue targets, one- or multi-parameter loop entry channels, exact inputful multivalue loop plain branches and `br_if` channels with immediate direct-drop, same-typed binary with a simple opposite operand, one exact one-use rich right operand when the payload is left, or one exact pre-branch rich left paired with lane zero when the payload is right and the legacy-try or inputful-loop payload vector contains only individually supported rich origins, unary, or conversion false flow from independently scalar or tuple-made payloads, one exact exclusive tuple-made loop result tail, per-arm independently scalar or exact separately owned tuple-made legacy-try tails with supported scalar component origins, and exact loop-plus-block and loop-plus-if table channels, and owner-local terminal placeholders for nested `br`/`br_table`/`return`/`return_call`/`return_call_indirect`/`return_call_ref`/`throw`/`throw_ref` are implemented. Branch-free multivalue blocks and ifs plus zero-input multivalue loops with payloadless backedges and independently scalar defaultable tails route through ordered typed locals when all repeated HOT result uses form one exclusive consumer span. Unsupported root value-controls are kept out of scalar body-result materialization. Same-vector multivalue `br_if` payloads write independently scalar origins once into the shared target vector, replace one contiguous ordered false-path tail with matching reads, preserve the condition, and clear the payload children. Mismatched/shared multivalue `br_if` plus mixed if/loop or nonexclusive multivalue `br_table` payloads remain whole-function fail-closed; branch-targeted ifs now preflight every use and share one result temp across fallthrough plus carried `br`/`br_if` flow, while nondefaultable payloads also fail closed before mutation. Inputful loops now capture each independently scalar defaultable entry once in source order, redirect body uses through typed locals, and clear the loop parameter prefix. Scalar result routing remains separate; admitted plain-branch, exact immediate direct-drop or scalar-binary false-flow conditional, and table-backed multivalue-result families use a distinct ordered result vector. Payloadless zero-input and independently scalar defaultable one- or multi-parameter `br`/`br_if` backedges reuse typed entry locals, preserve payload order and one evaluation before conditional tests, preserve false-path flow, and clear their carried arity. One- or multi-parameter loop-targeting tables stage every independently scalar payload once in source order and copy each vector into unique target entry locals. Exact inputful multivalue loop-plus-block fanout additionally routes independently scalar or one exact exclusive tuple-made fallthrough result tail through separate locals; nondefaultable and multivalue single-producer table backedges fail closed before mutation. Plain multivalue block branches now write each independently scalar defaultable payload into the shared typed target vector in source order, while mixed blocks route independently scalar fallthrough tails through that same vector; nested plain exits are admitted after complete label-use preflight. Branch/control arity is cleared and an exclusive repeated consumer span remains required. Scalar legacy tries route exact do/catch tails through one typed local and admit plain carried `br` exits to the try label when every use is preflighted, each payload exactly matches the defaultable result type, and each other arm has an independently scalar matching fallthrough. Exact scalar try-label `br_if` also admits one immediate direct-drop, unary, conversion, or same-typed binary false-flow consumer with a simple opposite operand in the same arm; the exact multivalue family admits direct drops, independently scalar or exclusively owned repeated `TupleMake` unary/conversion lanes, and independently scalar same-typed binary lanes with simple opposite operands or exact one-use rich right operands when the payload is left in one reversed span. Payload work stays before condition work and both paths share the typed result channel. Multivalue payloads are independently scalar or one exclusively owned repeated `TupleMake`, whose components are scalarized once in source order. Exact terminal scalar table families admit one repeated try label, that try plus a strict direct-enclosure chain of matching defaultable blocks without a hardcoded length cap, or that try plus zero or more such blocks followed by one or more directly enclosing matching value `if`s, with all ifs outermost and no hardcoded count cap. Exact multivalue families admit one repeated try label; independently scalar payloads may target that try plus a strict direct-enclosure chain of matching blocks or zero or more such blocks followed by one or more directly enclosing matching value `if`s, with all ifs outermost and no hardcoded count cap; one exclusively owned repeated-`TupleMake` payload may target the unbounded strict block chain, or any strict directly enclosing matching block chain (including zero blocks) followed by one or more directly enclosing matching value `if`s with any such block chain and no hardcoded count cap. Payload stages copy into distinct per-label typed channels before selector work, and multivalue try fallthrough uses one exclusive repeated region-tail span. Multivalue legacy tries route per-arm exact independently scalar tails or separately owned exact tuple-made tails with supported scalar component origins through one shared typed vector when one exclusive repeated consumer span owns the results; exact plain try-label `br` payloads may independently provide scalar lanes or one exclusively owned repeated `TupleMake`. `flatten_eh_repair_requirement(...)` now classifies missing catch-payload tracking separately from exceptional-transfer repair before mutation. One scalar `Catch` first-descendant family through direct blocks or an `if` condition and arbitrary positive ordered same-tag direct-block-chain lane vectors now repair through entry locals; unsupported `Catch`/`CatchAll` populations, partial/mixed-tag vectors, then/else paths, other non-first-descendant or repeated uses, broader lane paths, nested catches, loops/multiple execution, and sharing/outside ownership remain whole-function fail-closed. Any positive depth-zero catch-all rethrow population through arbitrary strict direct resultless untargeted block/if ancestry and one resultless outer-target delegate whose sole catch representation is direct or a strict direct resultless single-root unused-label block chain are admitted; every broader exceptional-transfer population remains fail-closed. Remaining richer tuple-made loop conditional consumers and mixed table loop backedges, mismatched or ambiguously shared multivalue `br_if`, mixed if/loop or nonexclusive multivalue `br_table`, nested or nonexclusive conditional multivalue loop controls, broader rethrow/delegate ancestry and composition, conditional/table, shared/mixed tuple branch-targeted, broader legacy-try/EH shapes, and other control work remain open. |
| Old IR2 batch plan | `../../../raw/research/0065-2026-03-24-ir2-execution-plan.md:69-70` | `flatten` remains first in an older Batch 2 order. |
| Old registry-map plan | `../../../raw/research/0063-2026-03-24-pass-port-batches-and-registry-map.md:107-108` | `flatten` remains removed until implemented. |
| Active backlog | `agent-todo.md` `[O4Z-FLAT]001` | records the remaining implementation, wiring, fuzzing, timing, and scheduler work. |

Read this table and the iteration diary below as historical pre-admission evidence, not as the current public status.

The internal bridge can lower Starshine's existing **resultless synthetic catch-all** `Try` representation and removes the bridge entirely when the body is proven nonthrowing, retaining only a void block when branches target the try label. HOT now represents ordered typed catch-entry payloads explicitly and lowers one scalar lane or any positive same-tag lane vector through scalar/result-only multivalue `try_table` handlers. Internal flatten repairs scalar first-descendant paths through direct blocks or an `if` condition plus arbitrary ordered direct-block-chain lane vectors. It admits any positive depth-zero catch-all rethrow population through arbitrary strict direct resultless untargeted block/if ancestry and one resultless outer-target delegate whose sole catch representation is direct or a strict direct resultless single-root unused-label block chain; broader payload relocation and exceptional-transfer populations retain exact pre-mutation deferred outcomes. Immutable label-use and exact terminal-table support facts are cached once per rewrite state, payload-bearing branch rewrites avoid duplicate generic routing, lightweight reachable node-use counts preserve exact suffix ownership without full use-site allocation, and exact detached suffix forests tombstone with one revision invalidation after region detachment. Direct `i32.shl`, `i32.shr_s`, plus `i32.shr_u` resultless-call roots use the same complete distinct one-use proof as the prior audited binaries. The refreshed three-probe matrix remains a narrow measured size win (`212` Starshine cleanup bytes versus `236` Binaryen), but the current 120-function pass-local median is `970.5 us`, or `3.65x` Binaryen, and no GenValid/four-lane public matrix exists. EH representation, richer/shared/nested behavior, performance, and signoff are still hard public-readiness blockers; exact block/if/loop roots can now share one atomic vector with exactly recognized ordinary roots, but that does not close those broader gates; see the [current impact note](../../../raw/binaryen/2026-07-15-flatten-version-130-nonthrowing-bridge-suffix-cache-impact.md).

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

At that iteration, typed catch payload/pop repair, exceptional transfer, verified structured control-plus-owned-label deletion, broader shared/nested/mixed control flow, the flatten aggregate, four-lane signoff, ordered neighborhood, and public admission were still blocked. The later catch-repair, structured-deletion, and direct exceptional-transfer sections below supersede those specific family-status claims; aggregate/signoff/neighborhood/public gates remain open.

The rich-right feature iteration narrows the remaining opposite-operand gap. Commits `5c4a664dd` and `a4055b7a9` allow payload-left independently scalar and exclusively tuple-made lanes to retain one exact one-use rich right operand. The ordinary prelude walker materializes that operand after payload-free `br_if`; pinned-v130 legacy-try and inputful-loop probes confirm calls stay on the not-taken path. Red-first focused counts move `247/248 -> 248/248` and `248/249 -> 249/249`; private flatten remains `186/186`, passes reach `5,765/5,765`, and full reaches `9,226/9,226`.

The hold point is still unchanged. Typed EH, exceptional transfer, structured label-owner deletion, broader mixed/shared/nested flow, the flatten aggregate, four-lane signoff, ordered neighborhood, performance requalification, and public admission remain blocked.

The rich-left feature iteration closes one exact evaluation-order subset. Commits `e5c2a91ea` and `d0a53acf9` allow independently scalar and exclusively tuple-made legacy-try payload-right binaries to retain one one-use rich left when the complete payload vector is simple. Source stack order permits that left value only before the whole payload vector, so it pairs with lane zero after higher lanes are consumed. Rewrite stages it before payload locals and `br_if`; pinned-v130 probes confirm the call remains taken-path-observable while the binary remains not-taken-only. Red-first focused counts move `249/250 -> 250/250` and `250/251 -> 251/251`; private flatten remains `186/186`, passes reach `5,767/5,767`, and full reaches `9,228/9,228`.

The hold point remains unchanged. Multiple or non-lane-zero rich lefts, rich payload origins combined with pre-branch left work, typed EH, exceptional transfer, structured label-owner deletion, broader mixed/shared/nested flow, the flatten aggregate, four-lane signoff, ordered neighborhood, performance requalification, and public admission remain blocked.

The inputful-loop rich-left iteration closes the exact loop counterpart without changing that hold point. Commits `843614438` and `35ac3740a` stage one one-use rich left before a complete simple independently scalar or exclusively tuple-made payload vector, restrict it to lane zero's final reversed consumer, and preserve the binary after a not-taken `br_if`. The red-first focused sequence is `251/252 -> 252/252 -> 252/253 -> 253/253`; private flatten is `186/186`, passes `5,769/5,769`, full `9,230/9,230`, and `moon info` is green. Public registry, dispatcher, CLI execution, compare/API, GenValid, preset, and exact-neighborhood readiness remain unchanged.

The inputful-loop rich-payload follow-up narrows the composition gap further without changing the public hold point. Commits `3cb5577ad` and `c5a0a738a` allow at most one supported rich payload origin alongside the existing pre-branch rich left, for independently scalar and exclusively tuple-made ownership. The tuple slice first exposed a payload-before-left ordering regression after admission; inserting the left store before child-generated payload preludes restores the pinned-v130 order. Red-first focused counts move `253/254 -> 254/254 -> 254/255 -> 255/255`; private flatten is `186/186`, passes `5,771/5,771`, full `9,232/9,232`, and `moon info` is green. The one-rich boundary is superseded by the later multiple-rich iteration; typed EH, structured owner deletion, broader flow, aggregate/signoff, neighborhood, performance, and public admission remain blocked.

The legacy-try rich-payload follow-up closes the exact counterpart without changing the public hold point. Commits `61055698d` and `d9aa4cd94` admit at most one supported rich payload origin alongside one pre-branch rich left for independently scalar lanes and one exclusively owned repeated `TupleMake`. The rewrite inserts the rich-left store before child-generated payload preludes; the tuple route still requires complete branch-plus-consumer ownership and deletes the shell only after exact replacement. Red-first focused counts move `255/256 -> 256/256 -> 256/257 -> 257/257`; private flatten is `186/186`, passes `5,773/5,773`, full `9,234/9,234`, and `moon info` is green. Public registry, dispatcher, CLI execution, compare/API, GenValid, preset, neighborhood, and performance readiness remain unchanged.

The multiple-rich-payload follow-up removes that temporary cap without changing the public hold point. Commit `6e4229bae` admits every independently scalar rich payload origin for the exact legacy-try and inputful-loop rich-left family; commit `f223f14d6` admits the same vector for one exclusively owned repeated `TupleMake`. Every origin remains individually supported, scalar lanes retain exact branch-plus-consumer ownership, tuple flow retains complete branch-slot/consumer coverage and delayed shell deletion, and the rich left remains lane-zero-only. One red-first test per commit covers both controls. Focused flatten moves `257/258 -> 258/258 -> 258/259 -> 259/259`; private flatten is `186/186`, passes `5,775/5,775`, full `9,236/9,236`, and `moon info` is green. Four pinned-v130 probes preserve left, all payload calls in vector order, condition, payload-free branch, and false-path binary order.

The structured-subtree iteration resolves the mutation prerequisite and one exact suffix family without changing the public hold point. Commit `62c330a12` adds atomic detached control-plus-owned-label deletion with complete preflight and one revision advance. Commit `f7829507b` admits one void `block { drop(const) }` after an unconditional scalar legacy-try `br_table`; the pass proves one owner for every node, no target users for the block label, and exact current structure before any rewrite. The red-first flatten test moves `259/260 -> 260/260`; IR is `319/319`, private flatten `186/186`, passes `5,776/5,776`, full `9,238/9,238`, and `moon info` is green. Binaryen v130 retains the block under direct flatten, while `--vacuum --dce` reduces the probe from `76` to `63` encoded bytes, so Starshine's direct deletion is an evidence-backed cleanup win rather than unclassified shape drift.

At that structured-subtree iteration, public registry, dispatcher, CLI execution, compare/API, GenValid, preset, neighborhood, and performance readiness remained unchanged, while typed catch repair and exceptional transfer were still open. Later sections supersede those two family-status claims with bounded repairs and direct transfer subsets; broader structured/mixed/shared/nested flow, aggregate/four-lane/neighborhood evidence, performance requalification, and public admission remain blocked.

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
- branch-free scalar and independently produced multivalue legacy `try` now route exact do/catch results through shared typed locals; multivalue ownership requires one exclusive repeated consumer or region-tail span. Scalar first-descendant `Catch` use through direct blocks or an `if` condition and arbitrary ordered same-tag direct-block-chain lane vectors repair through entry locals, while every unsupported catch population selects `DeferredCatchPayloadRepair` before ordinary mutation;
- the catch repair transaction remains whole-function fail-closed for partial/mixed-tag vectors, then/else ownership, other non-first-descendant or repeated uses, broader independent lane paths, nested catches, loops/multiple execution, sharing/outside ownership, and catch-all payload extraction; every admitted inserted-catch-block shape must validate after lowering;
- placeholder `unreachable` now preserves nested terminal `br`/`br_table`/`return`/`return_call`/`return_call_indirect`/`return_call_ref`/`throw`/`throw_ref` effects in their owner region without duplicating effects that HOT already exposes as an earlier root; branch payload, tail-call operand, and throw-argument work remains before the terminal in source order and later sibling preludes remain later. Exceptional-transfer admission separately covers only depth-zero direct catch-all rethrow and direct outer-target resultless delegate, while every broader population selects `DeferredExceptionalTransferRepair`;
- `BrOn*` and `TryTable` have an explicit documented policy.

Binaryen v130 hard-fails on all four `BrOn*` variants, and a direct `TryTable` probe aborts in the earlier unhandled control-structure arm. Internal Starshine now classifies all five through `FlattenRunAdmission::UpstreamHardUnsupported` before mutation and leaves the function byte-for-byte structurally untouched at HOT level. This is a safe internal gate, not public behavior parity: public registry/CLI/harness admission remains blocked until a tested Binaryen-compatible rejection path replaces or wraps the internal unchanged result. Source: [`../../../raw/binaryen/2026-07-13-flatten-version-130-unsupported-policy-refresh.md`](../../../raw/binaryen/2026-07-13-flatten-version-130-unsupported-policy-refresh.md).

## Latest structured suffix breadth

Commits `51d080e09` and `cbb1a2395` extend atomic control-plus-owned-label deletion to one exact void `if` and one exact zero-input/no-backedge void `loop`. Commits `8b69a8e4c` and `f524b8bcb` add control-forest deletion and admit control-only vectors. Commit `04cc07657` then adds generic `hot_delete_detached_forest(...)` for ordinary or control roots while preserving complete descendant/label preflight; commit `ca159e6d0` admits scalar/control-mixed vectors only when every root already passes an exact recognizer and both root kinds occur. The wrappers retain control-only validation.

The generic API red-first test failed on the unbound symbol and then passes HOT mutation `13/13` plus IR `321/321`. The mixed `drop(const) + block + if + loop + unreachable` fixture failed unchanged at `262/263`, then passes `263/263`; private flatten is `186/186`, passes `5,779/5,779`, full `9,243/9,243`, and `moon info` is green with 11 existing warnings. Fresh pinned Binaryen v130 retains the complete mixed suffix under direct flatten at `76` bytes, while matched `--vacuum --dce` removes it at `63` bytes. Nonconstant/effectful conditions, partial/richer arms, inputful/value loops, backedges, try-like roots, sharing, outside label users, typed EH, exceptional transfer, broader mixed/shared/nested flow, signoff, and performance remain fail-closed or incomplete.

## Latest ordered two-lane catch repair and unchanged public hold point

The first scalar Binaryen v130 nested-pop family is now joined by one exact ordered two-lane subset. Generic HOT preflight accepts two childless same-tag scalar markers only when the catch has one subsequent exclusive direct block chain and the final region's first two roots contain exact unary lane-zero/lane-one use paths. Locals are allocated in source order, handler-stack captures are inserted in reverse lane order, and the old positions become matching local reads. Any partial second lane, mixed tag, third lane, sharing/outside use, loop, nested exceptional control, catch-all marker, or alternate ancestry rejects before mutation.

Flatten admits that plan only after all other whole-function gates pass, applies it before ordinary rewriting, rebuilds every immutable analysis/proof snapshot, and then continues. HOT lowering accepts at most two lanes and requires an existing result-only multivalue handler block type for the pair. The whitebox fixture uses an `(i32, f32)` payload beneath two nested blocks followed by a branch to the enclosing block; HOT verification, lowering, and final module validation are green.

The red-first sequence was: unbound ordered repair APIs; then ordered catch admission remained deferred. Final validation for that slice is HOT mutation `16/16`, IR `326/326`, focused flatten `263/263`, whitebox flatten `188/188`, passes `5,781/5,781`, full `9,250/9,250`, `moon fmt`, and `moon info` with 11 existing warnings. Non-first-descendant/repeated payload use, broader independent lane paths, nested catches, loops/multiple execution, and catch-all payload extraction remain open.

## Latest ordered catch breadth and unchanged public hold point

Commits `82c4c260c` and `95f71db1e` supersede the temporary two-lane and if-control blockers recorded above. Ordered repair now handles any positive same-tag lane vector under the same leading-marker, exclusive direct-block-chain, ordered unary-use, exact ownership, source-order local, and reverse capture rules. Scalar repair may also descend through an `if` condition, exactly as pinned Binaryen v130 `getFirstPop(...)` permits, but never into then or else.

The red-first fixtures failed on three-lane admission at `190/191` and nested-if admission at `191/192`. Final validation is IR `326/326`, focused flatten `263/263`, whitebox flatten `192/192`, passes `5,785/5,785`, full `9,254/9,254`, `moon fmt`, and `moon info` with 11 existing warnings. No `.mbti`, profile, compare lane, registry, dispatcher, CLI execution, preset, scheduler, or performance result changed. Partial/mixed-tag vectors, other lane paths, repeated/sharing/outside use, selected arms, nested catches, loops/multiple execution, and catch-all extraction remain blocked.

## Latest direct exceptional-transfer admission and unchanged public hold point

Pinned Binaryen v130 source proves that `Flatten.cpp` does not transform `rethrow` or `delegate`, `EHUtils::handleBlockNestedPops(...)` only repairs legacy payload `Pop`, and delegation is a `Try::delegateTarget` property. Internal Starshine now admits one exact subset of each without weakening the remaining whole-function gate.

- At that checkpoint, depth-zero catch-all rethrow could appear under a strict direct block ancestry owned by the active catch. Lowering used `catch_all_ref`, captured the exception reference once, and emitted `throw_ref`; the later nested-depth and strict-wrapper sections supersede the blanket nonzero/nested/non-direct rejection while typed composition and broader ownership remain open.
- A resultless delegated try may contain exactly one delegate catch root targeting its directly enclosing outer try through a strict block ancestry. Its own label must be unused, and the outer target must remain active during lowering. The inner legacy shell becomes transparent propagation; non-direct targets, value results, mixed catch/delegate bodies, inner-label users, and broader nesting reject.

The red-first whitebox fixtures moved `188/189 -> 189/189` and `189/190 -> 190/190`. Final validation is HOT lower `89/89`, IR `326/326`, focused flatten `263/263`, whitebox flatten `190/190`, passes `5,783/5,783`, full `9,252/9,252`, `moon fmt`, and green `moon info` with 11 existing warnings. No `.mbti` changed. The flatten aggregate, four-lane matrix, ordered neighborhood, performance requalification, broader EH/control closure, and public admission remain blocked; the durable representative remains `970.5 us` / `3.65x` Binaryen and was not remeasured.

## Latest multiple and nested-if rethrow breadth

Commits `3c819922c` and `41533e603` supersede the earlier single-rethrow and strict block-only statements above. One active catch may own any positive number of admitted depth-zero rethrows; lowering allocates one nullable `exnref` scratch local, captures the handler exception once through `catch_all_ref`, and reuses that local for every `throw_ref`. Admission still proves each rethrow separately against the same active catch.

At that checkpoint, one ancestry path could additionally cross at most one resultless `if` arm whose label had no users, with direct blocks on either side. Lowering visited then/else regions but not the condition and did not enter loops or nested try/catch regions. Red-first whitebox results were `192/193` and `193/194`; validation reached whitebox `194/194`, HOT lower `89/89`, focused flatten `263/263`, IR `326/326`, passes `5,787/5,787`, and full `9,256/9,256`. No public surface or `.mbti` changed, and the durable `970.5 us` / `3.65x` performance checkpoint remained unrequalified.

## Latest strict exceptional ancestry breadth

Commit `9c237165d` supersedes the temporary single-if blocker. Every depth-zero rethrow path may now contain an arbitrary strict direct chain of resultless untargeted if arms and direct blocks. Exact owning-catch ancestry is still proven per rethrow; conditions, loops, nested tries/catches, value-carrying ifs, and used labels reject before mutation. The red-first two-if/interleaved-block fixture moved whitebox `194/195 -> 195/195`.

Commit `88197c97e` supersedes only the direct-catch-root delegate blocker. A resultless delegated try may have a sole catch root that is a strict direct chain of resultless single-root blocks ending in the delegate. Every block label and the inner try label must be unused; the target must remain the exact active outer try. Ifs, loops, mixed catch roots, value-carrying controls, used labels, and broader nesting still reject. The red-first two-block catch-chain fixture moved whitebox `195/196 -> 196/196`.

Final validation is HOT lower `89/89`, IR `326/326`, focused flatten `263/263`, whitebox flatten `196/196`, passes `5,789/5,789`, full `9,258/9,258`, `moon fmt`, and green `moon info` with 11 existing warnings. No `.mbti`, profile, compare lane, registry, dispatcher, CLI execution, preset, scheduler, or neighborhood-ready result changed. Performance was not remeasured; `970.5 us` / `3.65x` Binaryen remains the durable checkpoint. Broader catch repair, nonzero/typed/loop/nested-try-or-catch rethrow, value-carrying/targeted-if rethrow, broader delegate populations, rich/mixed/shared control closure, aggregate/four-lane/neighborhood evidence, performance requalification, and public admission remain blocked.

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

## Latest readiness movement: outer delegate chains and first-child lane composition

The current internal admission now preserves a delegated inner try through any strict direct outer sequence of resultless untargeted single-root blocks and if arms to the exact active target. The catch side remains either direct or the already admitted strict resultless unused-label block chain. Separately, ordered same-tag catch payload lanes follow Binaryen v130's first-child rule through non-control expressions with additional later children; the old ordered-unary restriction is superseded.

The two red-first whitebox cases moved `196/197 -> 197/197` and `197/198 -> 198/198`. Final validation is HOT mutation `16/16`, HOT lower `89/89`, IR `326/326`, focused flatten `263/263`, passes `5,791/5,791`, full `9,260/9,260`, `moon fmt`, and green `moon info` with 11 existing warnings. No `.mbti`, registry, dispatcher, CLI execution, compare/API, profile, preset, scheduler, or neighborhood-ready surface changed.

That checkpoint's blanket independent-lane and value-carrying-if blockers are partially superseded by the next iteration; the other listed gates remain.

## Latest readiness movement: independent direct roots and one scalar value-if rethrow

Commit `fb9d071e8` admits an ordered same-tag vector whose first lane uses are separate direct catch-region roots after the leading markers. Each root independently follows Binaryen v130's first-child line, so one lane may traverse a binary while another traverses an `if` condition; later roots retain identity. The existing common direct-block-chain representation remains admitted. Partial/mixed tags, non-first children, repeated/shared/outside ownership, selected arms, nested catches, loops/multiple execution, catch-all extraction, and other direct-root arrangements still reject atomically.

Commit `52fc64b49` admits one direct depth-zero rethrow as the terminal arm of a defaultable scalar value `if`. The opposite arm must end in one matching Flat-IR-simple scalar value, the if label must be unused, and the if must remain directly rooted in the active catch. Existing scalar if and legacy-try local channels erase both control results before lowering. This does not admit nonzero or typed-composed rethrow, nested try/catch ownership, loops, targeted ifs, non-simple opposite arms, multivalue value controls, or value-carrying ancestry through additional wrappers.

Red-first whitebox moved `198/199 -> 199/199 -> 199/200 -> 200/200`. Final evidence is HOT mutation `16/16`, HOT lower `89/89`, IR `326/326`, focused flatten `263/263`, passes `5,793/5,793`, full `9,262/9,262`, `moon fmt`, and `moon info` with 11 existing warnings. No `.mbti`, profile, compare lane, registry, dispatcher, CLI execution, preset, scheduler, or neighborhood-ready result changed.

That checkpoint's blanket nonzero and nested-catch rethrow blockers are superseded only by the direct markerless resultless catch-all chain below. Its other blockers remain.

## Latest readiness movement: direct nested catch rethrow depths

Commit `1ac52d9fa` changes lowering from a compressed list of captured catches to one optional slot per active legacy catch. A catch allocates and receives an exception-reference local when any rethrow in its nested catch subtree targets that catch; `Rethrow(depth)` selects the exact slot from the innermost active catch. This preserves depth identity even when intervening catches do not need their own captured local.

Commit `23f9ba164` admits any positive nonzero depth only through an exact direct chain of markerless resultless catch-all `Try` owners. The rethrow must be a direct catch root, every intermediate try must be a direct root of the next enclosing catch, and no typed payload marker, block/if wrapper, value result, loop, try-body rethrow, or mixed transfer population is admitted. The HOT depth immediate remains unchanged through flatten.

Red-first evidence moved HOT lower `89/90 -> 90/90` and whitebox flatten `200/201 -> 201/201`. Final evidence is HOT mutation `16/16`, HOT lower `90/90`, IR `327/327`, focused flatten `263/263`, passes `5,794/5,794`, full `9,264/9,264`, `moon fmt`, and green `moon info` with 11 existing warnings. No `.mbti`, profile, compare lane, registry, dispatcher, CLI execution, preset, scheduler, or neighborhood-ready result changed. Performance was not remeasured; `970.5 us` / `3.65x` Binaryen remains the durable checkpoint.

At that checkpoint, readiness still listed nonzero rethrows with wrappers between catch owners. The next iteration supersedes that blanket wrapper blocker only for strict resultless unused-label single-root block/selected-if ancestry; all other listed gates remain.

## Latest readiness movement: strict nested-catch block/if ancestry

Commit `70280e159` admits strict block wrappers between every pair of markerless resultless catch-all owners. Each block must be resultless, have an unused label, and own the current rethrow or nested try as its sole body root. The fixture was red at whitebox `201/202`, then green at `202/202`.

Commit `1fc7c6077` extends the same walk through resultless unused-label `if` wrappers. Exactly one selected arm must own the current root as its sole root; the opposite arm may not share it. The fixture combines block and if wrappers at both catch depths, was red at `202/203`, and is green at `203/203`. The depth immediate and exact target-catch lowering slot remain unchanged.

Final evidence is HOT mutation `16/16`, HOT lower `90/90`, IR `327/327`, focused flatten `263/263`, whitebox flatten `203/203`, passes `5,796/5,796`, full `9,266/9,266`, `moon fmt`, and green `moon info` with 11 existing warnings. No `.mbti`, profile, compare lane, registry, dispatcher, CLI execution, preset, scheduler, or neighborhood-ready result changed. Performance was not remeasured; `970.5 us` / `3.65x` Binaryen remains the durable checkpoint.

Readiness remains blocked by broader partial/mixed/non-first/repeated/shared/nested/loop/catch-all payload populations; broader independent lane composition beyond the exact common-block and first-N direct-root layouts; typed-composed rethrows, loop or nested-try-body rethrows, targeted/multivalue/broader value-control rethrows, value-carrying/targeted/multi-root wrapper ancestry, and broader nested exceptional ownership; non-strict, loop, nested-try, mixed/value-carrying/used-label/non-active delegate populations; richer mixed/shared/nested structured and EH closure; a flatten-specific aggregate and explicit prebuilt-native 10,000-case evidence; the required four-lane and ordered-neighborhood signoff; performance requalification; docs closeout; and only then public admission.

## Latest readiness movement: exact opposite-arm targeted catch-if exits

Commits `c90bed031` and `8529deb42` admit two bounded positive nonzero-rethrow ancestry families without weakening the existing strict owner walk. A resultless targeted `if` must have exactly one root in each arm, own the current rethrow or nested try in exactly one selected arm, and have exactly one indexed label user that is the sole root of the opposite arm. Code 1 admits only a payloadless plain `br` to the if's own label. Code 2 admits only a payloadless `br_if` to that label whose one condition is already Flat-IR-simple and exactly scalar `i32`. The target branch and optional condition remain unchanged; no label arity, rethrow depth, catch slot, or wrapper result changes.

Red-first whitebox moved `203/204 -> 204/204` for the plain branch and `204/205 -> 205/205` for the conditional branch. Final evidence is HOT mutation `16/16`, HOT lower `90/90`, IR `327/327`, focused flatten `263/263`, passes `5,798/5,798`, full `9,268/9,268`, `moon fmt`, and green `moon info` with 11 existing warnings. No `.mbti`, profile, compare lane, registry, dispatcher, CLI execution, preset, scheduler, or neighborhood-ready result changed. Performance was not remeasured; `970.5 us` / `3.65x` Binaryen remains the durable checkpoint.

The blanket targeted-if blocker in earlier sections is superseded only for these exact opposite-arm payloadless exits. Multiple or outside label users, payload-carrying branches, same-arm target users, missing or multi-root opposite arms, value-carrying/multivalue wrappers, loops, typed composition, nested try-body rethrows, and broader targeted ownership remain open. The blanket rich-condition blocker is superseded only by the exact one-use supported scalar `i32` condition below; shared, control, tee, non-`i32`, or otherwise unsupported conditions remain open. Every other readiness gate remains unchanged.

## Latest readiness movement: rich targeted conditions and interleaved catch roots

Commit `61fb9919b` admits a payloadless opposite-arm `br_if` condition when it is exactly scalar `i32`, one-use in the immutable ownership snapshot, non-control, non-tee, and otherwise supported by ordinary scalar operand flattening. The rich condition is not hoisted out of the arm: flatten inserts its local-set prelude immediately before the branch in the same opposite region and replaces only the branch child with the matching local read. The if target, selected rethrow/nested-try arm, rethrow immediate, and exact outer catch slot remain unchanged.

Commit `1fb8f64ec` supersedes the blanket "first-N direct roots only" catch-lane blocker for one ordered interleaving family. After the leading same-tag payload markers, each lane may own a later direct catch root while unrelated roots appear before or between lane roots. The planner searches only forward in source order, and every selected lane still proves exact entry plus nested-use ownership through the existing first-child walk. Unrelated and later roots retain identity; reverse/ambiguous lane order, missing lanes, repeated/shared/outside uses, loops, nested catches, mixed tags, and catch-all extraction still reject the whole function before mutation.

Red-first whitebox moved `205/206 -> 206/206` and `206/207 -> 207/207`. Final evidence is HOT mutation `16/16`, HOT lower `90/90`, IR `327/327`, focused flatten `263/263`, passes `5,800/5,800`, full `9,270/9,270`, `moon fmt`, and green `moon info` with 11 existing warnings. No `.mbti`, profile, compare lane, registry, dispatcher, CLI execution, preset, scheduler, or neighborhood-ready result changed. Performance was not remeasured; `970.5 us` / `3.65x` Binaryen remains the durable checkpoint.

Readiness remains blocked by partial/mixed tags, non-leading/non-first-descendant or repeated payload use, broader independent/nested/selected-arm/loop-safe catch composition, sharing/outside ownership, catch-all extraction, typed-composed rethrows, targeted wrappers beyond the exact payloadless opposite-arm families, loops, nested try-body transfers, value-carrying/multivalue/multi-root ancestry, broader delegates and structured/EH closure, a flatten-specific aggregate and explicit native 10,000-case evidence, the required four-lane and ordered-neighborhood signoff, performance requalification, docs closeout, and only then public admission.

## Latest readiness movement: block-wrapped targeted exits and scalar typed rethrows

Commit `404252e63` extends only the exact opposite-arm targeted-if exit proof. The opposite arm may own one resultless unused-label block whose body has exactly one root: the existing payloadless `br` or `br_if` to the if label. The block label must have no users, the if label still has exactly one indexed user, both if arms still have one root, and the selected arm still exclusively owns the current rethrow or nested try. Rich scalar `i32` condition materialization remains immediately before the branch inside that block.

Commit `a24539c99` admits one scalar typed-composed direct rethrow. Whole-function catch-payload repair must already succeed; the owning catch must have exactly one leading childless scalar `Catch` marker, no additional catch marker, and exactly one direct `Rethrow(0)` root. Lowering requires an existing result-only handler type for `[payload, exnref]`, emits `catch_ref`, consumes `exnref` before the repaired payload capture, and validates the final module. This supersedes the blanket typed-composition blocker only for that exact scalar/direct/single-rethrow subset.

Red-first whitebox moved `207/208 -> 208/208` and `208/209 -> 209/209`. Final evidence is HOT mutation `16/16`, HOT lower `90/90`, IR `327/327`, focused flatten `263/263`, passes `5,802/5,802`, full `9,272/9,272`, `moon fmt`, and green `moon info` with 11 existing warnings. No `.mbti`, profile, compare lane, registry, dispatcher, CLI execution, preset, scheduler, or neighborhood-ready result changed. Performance remains unrequalified at `970.5 us` / `3.65x` Binaryen.

Readiness remains blocked by broader payload layouts and policies; multiple-lane, multiple-rethrow, non-direct, nonzero, wrapped, nested, loop, value-carrying, multivalue, or otherwise broader typed exceptional composition; targeted wrappers beyond the exact direct-or-one-block opposite-arm exit subset; broader delegate/control/EH closure; a flatten aggregate and explicit native 10,000-case evidence; the four required lanes and ordered neighborhood; performance requalification; docs closeout; and only then public admission.

## Latest readiness movement: two-lane typed rethrows and strict targeted block chains

Commit `740dfa2b5` supersedes the scalar-only typed-composition ceiling for one exact vector family. The catch must begin with a positive same-tag vector of childless scalar payload markers, the existing whole-function repair transaction must own every lane, and exactly one direct `Rethrow(0)` may occur. Lowering requires an existing result-only handler type `[lane0, ..., laneN, exnref]`, stores the top exception reference first, then executes reverse stack-order payload captures into source-order locals before `throw_ref`. Multiple typed rethrows, non-direct/nonzero rethrows, wrappers, nesting, loops, mixed tags, or missing handler types remain deferred.

Commit `374040a26` supersedes the one-block targeted-exit ceiling with an arbitrary positive strict block chain. Each wrapper is resultless, single-root, directly owned, and has an unused label. The final payloadless `br`/`br_if` remains the targeted if label's only indexed user, and rich scalar condition work stays in the innermost block immediately before the branch. Multi-root, used-label, targeted, value-carrying, loop, try-like, or otherwise non-strict wrappers remain excluded.

Red-first whitebox moved `209/210 -> 210/210` and `210/211 -> 211/211`. Final evidence is HOT mutation `16/16`, HOT lower `90/90`, IR `327/327`, focused flatten `263/263`, passes `5,804/5,804`, full `9,274/9,274`, `moon fmt`, and green `moon info` with 11 existing warnings. No `.mbti`, profile, compare lane, registry, dispatcher, CLI execution, preset, scheduler, or neighborhood-ready result changed. Performance remains unrequalified at `970.5 us` / `3.65x` Binaryen.

Readiness remains blocked by broader catch-payload policy/repair and typed composition; broader exceptional transfer, delegate, structured-control, mixed/shared/nested EH closure; a flatten-specific aggregate and explicit native 10,000-case evidence; the required four-lane and ordered optimizer-neighborhood signoff; performance requalification; docs/readiness closeout; and only then public admission.

## Latest readiness movement: typed rethrow block chains and selected catch-if delegates

Commit `b7b85a8bf` supersedes the direct-only typed-rethrow ancestry ceiling for one strict wrapper subset. After complete whole-function repair of a positive same-tag scalar payload vector, the catch may own exactly one `Rethrow(0)` through any positive chain of resultless unused-label single-root blocks. Every child is directly owned, every wrapper label is unused, and the rethrow immediate remains zero. The validating two-lane fixture retains source-order `i32`/`f32` locals, reverse payload captures after the top exception-reference capture, the complete block shell, and `catch_ref`/`throw_ref` lowering.

Commit `3595d6563` supersedes the catch-side block-only delegate representation boundary for one exact selected-if subset. Each catch-side if is resultless, has an unused label and exactly one root per arm, selects its delegate-containing arm with an exact `i32.const`, and contains a childless `nop` as the opposite root. Admission and HOT lowering share this proof and may follow any positive then/else-selected chain before transparent propagation to the exact active outer target. Nonconstant or effectful conditions, targeted/used labels, missing else arms, multi-root/value-carrying controls, non-nop opposite arms, loops, nested tries, mixed catch populations, and non-active targets remain deferred.

Red-first whitebox moved `211/212 -> 212/212` and `212/213 -> 213/213`. Final evidence is IR `327/327`, focused flatten `263/263`, whitebox flatten `213/213`, passes `5,806/5,806`, full `9,276/9,276`, `moon fmt`, and green `moon info` with 11 existing warnings. No `.mbti`, profile, compare lane, registry, dispatcher, CLI execution, preset, scheduler, or neighborhood-ready result changed. Performance remains unrequalified at `970.5 us` / `3.65x` Binaryen.

Readiness remains blocked by broader payload policy and repair; typed exceptional composition outside the exact positive payload-vector/one-depth-zero-rethrow/direct-or-strict-unused-block-chain subset; broader rethrow ancestry and value/control ownership; delegate populations outside direct, strict catch-block, exact constant-selected catch-if, and strict outer block/if chains; richer mixed/shared/nested control and EH closure; a flatten-specific aggregate and explicit native 10,000-case evidence; the required four-lane and ordered-neighborhood signoff; performance requalification; docs closeout; and only then public admission.

## Latest readiness movement: selected typed rethrows and empty delegate arms

Commit `de138eb24` reuses the exact constant-selected catch-if proof for the typed depth-zero rethrow family. A repaired positive same-tag scalar payload vector may own its sole `Rethrow(0)` through any positive selected-if chain, including strict block/if mixes. Every if remains resultless, unused as a label, exactly selected by `i32.const`, and directly owned; the unselected region is either empty or contains one childless `nop`. Handler stack order, source-order locals, the rethrow immediate, `catch_ref`, and `throw_ref` remain unchanged. The new two-lane fixture was red at whitebox `213/214` with `DeferredExceptionalTransferRepair`, then green at `214/214` and validating.

Commit `dc3cdb597` admits the empty unselected-region representation for catch-side delegate ifs. A present but empty arm is treated as the same no-work representation as the previously admitted childless `nop`; admission and lowering share the exact empty-or-`nop` proof and do not discard executable work. The two-level then/else-selected fixture was red at `214/215`, then green at `215/215`, retained the target and empty HOT regions, lowered transparently, and validated.

Final evidence is HOT lower `90/90`, IR `327/327`, focused flatten `263/263`, whitebox flatten `215/215`, passes `5,808/5,808`, full `9,278/9,278`, `moon fmt`, and `moon info` with 11 existing warnings. No `.mbti`, registry, dispatcher, CLI execution, compare/API, profile, preset, scheduler, or neighborhood-ready surface changed. Performance was not remeasured; `970.5 us` / `3.65x` Binaryen remains the durable checkpoint.

Readiness remains blocked by broader catch-payload policy/repair; typed composition outside the exact repaired scalar-vector/one-depth-zero-rethrow/direct-or-strict-block-or-exact-selected-if subset; broader rethrow/delegate ownership and structured EH; the flatten aggregate and explicit native 10,000-case evidence; the required four-lane and ordered-neighborhood signoff; performance requalification; docs closeout; and only then public admission.

## Latest readiness movement: grouped catch roots and no-work delegate blocks

Commit `62992d7c5` admits one exact mixed ordered catch-payload layout that was previously deferred. A positive prefix of remaining same-tag lanes may be owned by the first roots of a retained nested block chain, and later lanes may continue in direct or interleaved catch roots. The red-first `i32`/`f32` grouped plus direct `i64` fixture returned `DeferredCatchPayloadRepair` at `215/216`; after implementation it passes `216/216`, retains both block shells and every later root, preserves source-order locals and reverse captures, lowers, and validates. Reverse/ambiguous grouping, partial or mixed-tag populations, repeated/shared/outside uses, selected-arm lanes, loops, nested catches, and catch-all extraction remain deferred.

Commit `9ee7b710e` extends only the no-work side of the existing exact constant-selected catch-if delegate representation. A present unselected region may be empty, contain one childless `nop`, or contain a positive strict chain of resultless unused-label single-root blocks ending in either representation. `hot_region_is_strict_no_work_block_chain(...)` is the shared admission/lowering proof. The red-first fixture returned `DeferredExceptionalTransferRepair` at `216/217`; after implementation it passes `217/217`, retains the HOT shells and target, lowers without representational ifs, and validates. Any executable opposite root, used label, value result, multi-root body, loop, nested try, missing else, nonconstant/effectful selector, mixed catch, or non-active target remains deferred.

Final evidence is HOT query `11/11`, HOT lower `90/90`, focused flatten `263/263`, whitebox flatten `217/217`, passes `5,810/5,810`, full `9,280/9,280`, `moon fmt`, `git diff --check`, and `moon info` with 11 existing warnings. The `.mbti` addition is generic HOT query surface only. No flatten profile, compare lane, registry, dispatcher, CLI execution, preset, scheduler, or neighborhood-ready result changed. Performance was not remeasured; `970.5 us` / `3.65x` Binaryen remains the durable checkpoint.

Readiness remains blocked by partial/mixed/repeated/shared/outside and broader nested catch-payload repair; typed and nonzero exceptional composition outside the admitted exact subsets; delegate populations outside direct, strict catch-block, exact selected-if with proven no-work opposites, and strict outer ancestry; richer mixed/shared/nested control and EH closure; the flatten aggregate and explicit native 10,000-case evidence; the required four-lane and ordered-neighborhood signoff; performance requalification; docs closeout; and only then public admission.

## Latest readiness movement: interleaved grouped lanes and no-work forests

Commit `41b16db02` supersedes the contiguous-final-region requirement for one exact grouped payload subset. The retained nested block group's final region may contain unrelated roots between forward source-ordered lane roots; each selected lane still proves exact entry-plus-old-position ownership and first-child ancestry, skipped roots remain in place, and later direct/interleaved lanes continue under the existing whole-function transaction.

Commit `4c6a1de9b` supersedes the single-root opposite-region requirement for exact constant-selected catch-side delegate ifs. The unselected region may contain any number of independent roots only when each is a childless `nop` or a resultless unused-label single-root block chain ending empty or in `nop`. Admission and HOT lowering share the same generic forest proof. Executable roots, used labels, value results, loops, nested tries, missing else regions, nonconstant/effectful selectors, mixed catches, and non-active targets remain deferred.

Red-first whitebox moved `217/218 -> 218/218` and `218/219 -> 219/219`; final HOT query is `12/12`, HOT lower `90/90`, focused flatten `263/263`, passes `5,812/5,812`, and full `9,283/9,283`. This does not close broader catch/EH/control, aggregate, four-lane, neighborhood, performance, docs-closeout, or public-admission gates.

## Latest readiness movement: multiple typed rethrows and recursive no-work forests

Commit `ec0c8749a` supersedes the one-rethrow ceiling for the exact repaired typed-catch family. Any positive depth-zero rethrow population may share one typed catch when every root independently satisfies the existing direct, strict resultless unused-label block, or exact constant-selected no-work-if ancestry. The handler remains `[lane0, ..., laneN, exnref]`; lowering emits one `catch_ref`, stores one exception reference after the handler transfer, and every rethrow reads that same scratch local before `throw_ref`. The red-first two-lane/two-rethrow fixture moved whitebox `219/220 -> 220/220`; a third unsupported-depth rethrow leaves payload positions, rich operands, roots, and locals unchanged.

Commit `1cac7b3ee` supersedes the flat no-work-block ceiling for one recursive delegate representation. A resultless unused-label block may contain multiple roots when every root recursively proves the same exact childless-`nop`/resultless-unused-label-block grammar. Admission and HOT lowering continue to call `hot_region_is_strict_no_work_forest(...)`, so the representational proof cannot diverge. The red-first nested-forest fixture moved `220/221 -> 221/221`; query coverage additionally rejects nested executable work and retains all previous used-label, value-result, loop, and nested-try negatives.

Final evidence is HOT query `12/12`, HOT lower `90/90`, focused flatten `263/263`, whitebox flatten `221/221`, passes `5,814/5,814`, full `9,285/9,285`, `moon fmt`, `git diff --check`, and `moon info` with 11 existing warnings. No `.mbti`, registry, dispatcher, CLI execution, compare/API, GenValid profile, preset, scheduler, or neighborhood-ready surface changed. Performance remains unrequalified at the durable `970.5 us` / `3.65x` Binaryen checkpoint.

Readiness remains blocked by broader catch-payload policy/repair; typed exceptional composition outside positive repaired same-tag scalar vectors whose depth-zero rethrows each use the exact direct/strict-block/exact-selected-if grammar; nonzero typed rethrows, loops, nested try-body transfers, value-carrying/multivalue/targeted/non-strict typed ancestry, and broader exceptional ownership; delegate representations with nonconstant/effectful selectors, missing else regions, executable or otherwise non-recursive-no-work opposites, used/targeted/value labels, loops, nested tries, mixed catches, or non-active targets; richer mixed/shared/nested structured control and EH; the flatten aggregate, four-lane and ordered-neighborhood evidence, performance requalification, docs closeout, and only then public admission.

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
