---
kind: workflow
status: planned
last_reviewed: 2026-07-16
sources:
  - ../../../raw/binaryen/2026-07-15-flatten-version-130-internal-output-recursive-ownership-impact.md
  - ../../../raw/binaryen/2026-07-15-flatten-version-130-nested-call-argument-impact.md
  - ../../../raw/binaryen/2026-07-11-flatten-current-main-and-local-status-recheck.md
  - ../../../tooling/pass-fuzz-compare.md
  - ../../../../../scripts/lib/pass-fuzz-compare-task.ts
  - ../../../../../src/passes/optimize.mbt
related:
  - ./index.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
  - ../../../tooling/pass-fuzz-compare.md
---

# `flatten` Fuzzing Status

## Current state: planned, not runnable

Do **not** treat `bun fuzz compare-pass --pass flatten ...` as a current smoke lane.

- The harness allowlist in [`scripts/lib/pass-fuzz-compare-task.ts`](../../../../../scripts/lib/pass-fuzz-compare-task.ts) does **not** include `flatten`, so it rejects the command before generation or either optimizer runs.
- [`src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt) retains `flatten` as **Removed**, not as an active pass with a descriptor or dispatcher route. Private `pass_manager.mbt` helpers whose names contain `flatten` belong to other transforms and do not alter that admission result.
- Parser rejection, removed-pass rejection, or zero compared cases is only current-status evidence. It is not evidence about the upstream `flatten` transform or Starshine parity.

Safe inspection only:

```text
bun fuzz compare-pass --list-passes
```

## Internal impact evidence is not public fuzz signoff

The latest 2026-07-15 internal matrix adds actual Starshine lowering, encoding, validation, execution, and cleanup evidence for three synthetic resultless catch-all probes. It still does not expose `flatten`, add a GenValid profile, or run any of the four public compare lanes. Nonthrowing synthetic-try elision makes the narrow matrix a measured cleanup-size win (`212` Starshine bytes versus `236` Binaryen). Exact terminal-table caching, duplicate-router removal, lightweight reachable ownership counts, and batched detached suffix deletion leave candidate-dense pass-local time at `3.65x` Binaryen. Typed catch/pop repair now covers scalar direct-block/if-condition first descendants and arbitrary ordered same-tag direct-block lane vectors; broader payload ownership remains open. Exact block/if/loop control-plus-label deletion exists singly, in control-only vectors, and in vectors mixed with exactly recognized ordinary roots, while richer/shared/nested structured breadth remains open. Direct `i32.shl`, `i32.shr_s`, and `i32.shr_u` roots are focused behavior evidence, not a substitute for a pass-specific generator or public compare matrix. Performance and public signoff remain gated. See [`../../../raw/binaryen/2026-07-15-flatten-version-130-nonthrowing-bridge-suffix-cache-impact.md`](../../../raw/binaryen/2026-07-15-flatten-version-130-nonthrowing-bridge-suffix-cache-impact.md).

The latest branch-index, in-place-tail, suffix-truncation, scalar/multivalue/legacy-try rewrite-proof, table-target-vector, lightweight ownership, tuple-branch count, conditional-site, scalar parent-population, sparse proof-cache, postorder-dispatch, shared-root, single-target staging, inputful-loop support-cache, constant-time branch append, shared admission-roster, EH-prerequisite, flatness-classification, and sparse binary-lookup commits remain internal work only. Commits `80e6a652b` and `efb8fdfa2` complete sorted sparse binary lookup for tuple-made and distinct non-tuple multivalue `br_if` flow proofs. They preserve explicit negative admission results, first-proof authority, exact current parent/slot checks, and post-boundary missing-entry rejection. They add no GenValid profile, harness allowlist entry, public pass descriptor, dispatcher, CLI execution, or compare/API exposure. Focused flatten is `245/245`, private flatten is `175/175`, passes are `5,750/5,750`, and the full suite is `9,211/9,211`. Exact cached-lookup reconstruction improves tuple flow `47.34%` and distinct flow `66.89%` at 512 candidates, but no representative run was requalified and the original public gate harness remains unrecovered. The durable representative checkpoint therefore remains `3.65x` Binaryen. Typed EH remains absent, broader structured/mixed flow remains open, the flatten aggregate does not exist, and no public compare lane is authorized yet.

The table-target/terminal-payload iteration remains internal as well. Commits `bdad9efaf` and `902848fca` replace measured linear target deduplication and payload-root membership with exact mark-set and sorted sparse lookup. Private flatten is `177/177`, focused flatten `245/245`, passes `5,752/5,752`, and the full suite `9,213/9,213`; no generator, allowlist, descriptor, dispatcher, CLI execution, or compare surface was added. The owner-specific 512-candidate improvements (`437,000 -> 16,000 us` for target extraction and `110,000 -> 20,000 us` for payload membership) do not requalify the unrecovered representative gate.

The immutable-index/reusable-scratch follow-up is internal as well. It adds no generator, allowlist, descriptor, dispatcher, CLI execution, or compare surface. Private flatten is `182/182`, focused flatten `245/245`, passes `5,757/5,757`, and the full suite `9,218/9,218`. Targeted native-release measurements improve cached ancestry, table-target, type-result, target-local, and prelude-heavy owners, and the reconstructed representative is nonregressing, but none of this creates a public parity lane or requalifies the durable `3.65x` Binaryen checkpoint.

The sequenced-root/multivalue-payload lookup follow-up remains internal too. Commits `4a03de7f3` and `aa295d38b` sort exact shared-root holder/node pairs for binary membership and mark exact multivalue `br_if` payload ids for duplicate/root checks. Private flatten is `184/184`, focused flatten `245/245`, passes `5,759/5,759`, and the full suite `9,220/9,220`; no generator, allowlist, descriptor, dispatcher, CLI execution, compare/API, or preset surface was added. The 512-candidate lookup reductions (`91.56%` and `95.73%`) are owner-specific and do not authorize a public compare lane or replace the durable `970.5 us` / `3.65x` gate.

The multivalue flow-index follow-up remains internal as well. Commits `f1dc57565` and `24b909b2d` replace the remaining nested distinct-payload edge scan and tuple flow-slot duplicate scan with exact query-local indexes. Private flatten is `186/186`, focused flatten `245/245`, passes `5,761/5,761`, and the full suite `9,222/9,222`; no generator, allowlist, descriptor, dispatcher, CLI execution, compare/API, or preset surface was added. The 512-candidate owner reductions (`1,878 -> 39 us` and `59,644 -> 1,368 us`) do not authorize a public compare lane or replace the durable `970.5 us` / `3.65x` gate.

The reversed multivalue binary-flow iteration remains internal too. Commits `2ae0a6adb` and `d64535310` add independently scalar and exclusively tuple-made simple-left/payload-right false-path consumers. Focused flatten is `247/247`, private flatten `186/186`, passes `5,763/5,763`, and the full suite `9,224/9,224`. Fresh pinned-v130 source/probe evidence preserves payload-before-condition order and binary execution only after a not-taken branch. No profile, allowlist, descriptor, dispatcher, CLI execution, compare/API, or preset surface was added. This is behavior-breadth progress, not public fuzz signoff.

The rich-right binary-flow iteration remains internal as well. Commits `5c4a664dd` and `a4055b7a9` admit exact one-use rich right operands for payload-left independently scalar and exclusively tuple-made lanes; the shared consumer proof also applies to exact inputful-loop flow. Pinned-v130 legacy-try and loop probes place each rich call after payload-free `br_if` and before the binary. Focused flatten is `249/249`, private flatten `186/186`, passes `5,765/5,765`, and full suite `9,226/9,226`. No aggregate, generator test, allowlist, descriptor, dispatcher, CLI execution, compare/API, or preset surface was added, so no public compare lane is authorized.

The rich-left binary-flow iteration remains internal too. Commits `e5c2a91ea` and `d0a53acf9` admit one exact one-use pre-branch rich left for independently scalar and exclusively tuple-made legacy-try lanes when the complete payload vector is simple and the binary consumes lane zero after higher lanes. Pinned-v130 probes place the rich left call before payload calls and `br_if`, with the binary remaining after the not-taken branch. Focused flatten is `251/251`, private flatten `186/186`, passes `5,767/5,767`, and full suite `9,228/9,228`. No aggregate, generator test, allowlist, descriptor, dispatcher, CLI execution, compare/API, or preset surface was added, so no public compare lane is authorized.

The inputful-loop rich-left iteration remains internal too. Commits `843614438` and `35ac3740a` admit the exact independently scalar and exclusively tuple-made loop counterparts when one rich left precedes a complete simple payload vector and feeds lane zero's immediate false-path binary. Focused flatten is `253/253`, private flatten `186/186`, passes `5,769/5,769`, and full suite `9,230/9,230`. The pinned-v130 loop probe confirms pre-branch left placement and post-branch binary execution. No aggregate, generator test, allowlist, descriptor, dispatcher, CLI execution, compare/API, or preset surface was added.

The inputful-loop rich-payload iteration remains internal too. Commits `3cb5577ad` and `c5a0a738a` admit at most one supported rich payload origin alongside the existing pre-branch rich left, first for independently scalar lanes and then for one exclusively owned repeated `TupleMake`. The tuple route corrects prelude order so left work precedes child-generated payload work. Focused flatten is `255/255`, private flatten `186/186`, passes `5,771/5,771`, and full suite `9,232/9,232`. The pinned-v130 probe confirms left, rich payload, remaining payload, condition, branch, and false-path binary order. No aggregate, generator test, allowlist, descriptor, dispatcher, CLI execution, compare/API, or preset surface was added.

The legacy-try rich-payload iteration remains internal too. Commits `61055698d` and `d9aa4cd94` admit the exact independently scalar and exclusively tuple-made counterparts with at most one supported rich payload origin alongside the pre-branch rich left. Focused flatten is `257/257`, private flatten `186/186`, passes `5,773/5,773`, and full suite `9,234/9,234`. Fresh pinned-v130 probes preserve left, payload vector, condition, payload-free `br_if`, and false-path binary order. No aggregate, generator test, allowlist, descriptor, dispatcher, CLI execution, compare/API, or preset surface was added, so no public compare lane is authorized.

The multiple-rich-payload iteration remains internal too. Commits `6e4229bae` and `f223f14d6` remove the temporary one-rich cap for independently scalar and exclusively tuple-made legacy-try and inputful-loop vectors while preserving exact ownership, lane-zero rich-left use, vector order, and tuple deletion proof. Focused flatten is `259/259`, private flatten `186/186`, passes `5,775/5,775`, and full suite `9,236/9,236`. Four pinned-v130 probes preserve left, every payload call in vector order, condition, payload-free `br_if`, and false-path binary order.

The structured-subtree iteration remains internal too. Commits `62c330a12` and `f7829507b` add an atomic HOT control-plus-owned-label deletion API and admit one exact `block { drop(const) }` suffix after unconditional scalar legacy-try `br_table`. Focused flatten is `260/260`, private flatten `186/186`, IR `319/319`, passes `5,776/5,776`, and full suite `9,238/9,238`. The pinned v130 direct output retains the block; matched `--vacuum --dce` shrinks encoded output `76 -> 63` bytes. No aggregate, generator test, allowlist, descriptor, dispatcher, CLI execution, compare/API, or preset surface was added, so no public compare lane is authorized. Broader structured roots and mixed suffix vectors remain outside the admitted family.

The structured-if/loop suffix iteration remains internal too. Commits `51d080e09` and `cbb1a2395` admit one exact constant-condition void if with direct drop-constant arms and one exact zero-input/no-backedge void loop with a direct drop-constant body. Focused flatten is `262/262`, private flatten `186/186`, passes `5,778/5,778`, and full `9,240/9,240`. Pinned v130 direct flatten retains both controls; matched cleanup reduces each probe `76 -> 63` bytes. No aggregate, generator test, allowlist, descriptor, dispatcher, CLI execution, compare/API, or preset surface was added, so no public compare lane is authorized.

The structured-forest suffix iteration is internal too. Commit `8b69a8e4c` adds generic failure-atomic detached control-forest deletion and commit `f524b8bcb` admits an ordered block + if + loop suffix only after every tree passes the existing exact shape, ownership, and label-use proof. HOT mutation is `12/12`, IR `320/320`, focused flatten `263/263`, private flatten `186/186`, passes `5,779/5,779`, and full `9,242/9,242`. Fresh pinned v130 direct flatten retains the three-root suffix at `76` bytes; matched cleanup removes it at `63` bytes.

The mixed-forest suffix iteration remains internal too. Commit `04cc07657` adds `hot_delete_detached_forest(...)` for ordinary or control roots with the same full failure-atomic descendant/label checks; commit `ca159e6d0` admits positive scalar/control-mixed vectors only from existing exact root recognizers. HOT mutation is `13/13`, IR `321/321`, focused flatten `263/263`, private flatten `186/186`, passes `5,779/5,779`, and full `9,243/9,243`. Fresh pinned v130 direct flatten retains `drop(const) + block + if + loop + unreachable` at `76` bytes; matched cleanup removes it at `63` bytes. The `.mbti` adds only the generic IR mutation API. No flatten profile, generator test, allowlist, descriptor, dispatcher, CLI execution, compare/API, preset, or public pass surface was added, so no compare lane is authorized.

## Ordered two-lane catch repair remains outside public fuzzing

Commits `43ea95972` and `49079c0dc` extend the whole-function scalar transaction to one exact ordered two-lane same-tag family and admit it internally. Preflight requires one exclusive direct block chain, ordered final-region unary lane uses, exact entry-plus-old-position ownership, and no partial/mixed-tag/third lane, loop, nested exceptional control, sharing, outside use, or catch-all marker. Lane locals retain source order; entry captures consume the handler stack in reverse order; flatten rebuilds its proof state before ordinary rewrites. Final validation is HOT mutation `16/16`, IR `326/326`, focused flatten `263/263`, whitebox flatten `188/188`, passes `5,781/5,781`, and full `9,250/9,250`.

This is still not a public fuzz lane. No flatten aggregate, generator test, allowlist, descriptor, dispatcher, CLI execution, compare/API, preset, or public pass surface was added. A future EH profile must still cover non-first-descendant/repeated use, broader independent lane paths, three-or-more lanes, nested catches, loop/multiple-execution rejection, sharing/outside ownership, and catch-all payload boundaries.

## Arbitrary ordered lanes and if-condition repair remain outside public fuzzing

Commits `82c4c260c` and `95f71db1e` supersede the earlier future-profile requirement for three-or-more lanes and the blanket if-control boundary. Any positive same-tag ordered lane vector may now repair under the exact direct-block and ownership proof, and the scalar first-descendant walk may follow an `if` condition but not an arm. Red-first whitebox counts moved `190/191 -> 191/191` and `191/192 -> 192/192`; final focused flatten is `263/263`, passes `5,785/5,785`, and full `9,254/9,254`.

This still creates no public lane. A future EH aggregate must generate arbitrary lane counts, admitted condition paths, and rejected partial/mixed-tag vectors, selected-arm paths, repeated/sharing/outside use, nested catches, loops/multiple execution, catch-all extraction, and broader exceptional transfers. No profile, generator test, allowlist, registry, dispatcher, CLI execution, compare/API, preset, or scheduler surface changed.

## Direct rethrow and delegate subsets remain outside public fuzzing

Commits `d76a91b3f` and `7bfb10372` admit one depth-zero direct catch-all rethrow and one direct outer-target resultless delegate. The rethrow lowers through `catch_all_ref`, a captured exception-reference local, and `throw_ref`. The delegate keeps its exact target label through flatten and lowers as transparent propagation only while the outer target is active and the inner label is unused. Red-first whitebox counts move `188/189 -> 189/189` and `189/190 -> 190/190`; final validation includes HOT lower `89/89`, whitebox flatten `190/190`, focused flatten `263/263`, passes `5,783/5,783`, and full `9,252/9,252`.

A future flatten EH aggregate must generate both admitted shapes and rejected nonzero/non-direct/nested/typed-mixed exceptional transfers. No compare lane is authorized while broader EH/control families remain deferred and public pass execution remains removed.

## Multiple and nested-if rethrow breadth remains outside public fuzzing

Commits `3c819922c` and `41533e603` superseded the earlier one-rethrow and direct-block-only limits. One active catch could lower any positive admitted depth-zero rethrow population through one `catch_all_ref` capture and repeated `throw_ref` uses. At that checkpoint, one path could cross at most one resultless, untargeted if arm; lowering scanned then/else regions but excluded conditions, loops, and nested tries. Red-first whitebox counts moved `192/193 -> 193/193` and `193/194 -> 194/194`; HOT lower was `89/89`, focused flatten `263/263`, passes `5,787/5,787`, and full `9,256/9,256`.

## Strict rethrow and delegate ancestry remains outside public fuzzing

Commits `9c237165d` and `88197c97e` supersede the single-if rethrow ceiling and the direct-catch-root delegate boundary. Depth-zero rethrows may now cross arbitrary strict direct chains of resultless untargeted if arms and blocks. A resultless delegated try may have a sole catch root formed by a strict direct chain of resultless single-root unused-label blocks ending in the delegate. Red-first whitebox counts moved `194/195 -> 195/195` and `195/196 -> 196/196`; final HOT lower is `89/89`, focused flatten `263/263`, passes `5,789/5,789`, and full `9,258/9,258`.

This still creates no public fuzz lane. A future flatten EH aggregate must generate positive rethrow populations and arbitrary direct block/if chains, direct and catch-block-chain delegates, plus rejected nonzero, typed-composed, loop, nested-catch/nested-try, value-carrying-if, targeted-if, if/loop/mixed catch ancestry, value-carrying delegate, and used-label populations. No profile, generator test, allowlist, registry, dispatcher, CLI execution, compare/API, preset, or scheduler surface changed.

## Strict outer delegates and first-child catch lanes remain outside public fuzzing

Commits `0800efc79` and `57013d100` supersede the direct-outer delegate boundary and ordered-unary catch-lane blocker. The delegate fixture combines a strict catch-block chain with a strict resultless untargeted outer block/if chain to the exact active target. The catch-lane fixture uses two ordered same-tag payloads as the first children of binary expressions and proves the later operands remain unchanged. Red-first whitebox counts move `196/197 -> 197/197` and `197/198 -> 198/198`; final validation is HOT mutation `16/16`, HOT lower `89/89`, IR `326/326`, focused flatten `263/263`, passes `5,791/5,791`, and full `9,260/9,260`.

This still creates no aggregate or public compare lane. A future EH profile must include admitted ordered first-child expression paths and strict catch/outer delegate chains, plus rejected non-first-descendant/repeated/shared/outside/mixed-tag/partial payloads; loop, nested-catch, nested-try, value-carrying, targeted, used-label, mixed-catch, non-active-target, nonzero, and typed-composed exceptional transfers. No profile, generator test, allowlist, registry, dispatcher, CLI execution, compare/API, preset, or scheduler surface changed.

## Independent direct catch roots and scalar value-if rethrows remain outside public fuzzing

Commits `fb9d071e8` and `52fc64b49` admit two further internal-only families. Ordered same-tag payload markers may feed the first ordered direct catch-region roots independently, including a binary first-child lane beside an if-condition lane with later roots preserved. One direct depth-zero rethrow may also terminate a defaultable scalar value-if arm when the opposite arm is one matching simple value and the unused if remains directly owned by the active catch.

Red-first whitebox counts move `198/199 -> 199/199` and `199/200 -> 200/200`; final validation is HOT mutation `16/16`, HOT lower `89/89`, IR `326/326`, focused flatten `263/263`, passes `5,793/5,793`, and full `9,262/9,262`. No profile, generator test, allowlist, descriptor, dispatcher, CLI execution, compare/API, preset, scheduler, or public pass surface was added.

A future EH aggregate must now generate both admitted common-block and first-N direct-root lane layouts, independent first-child path kinds, later-root preservation, and the direct scalar value-if rethrow. At that checkpoint it also needed to reject all nonzero/nested rethrows; the next section supersedes that blanket requirement for the exact direct markerless resultless catch-all chain. Partial/mixed tags, non-leading/non-first/repeated/shared/outside uses, selected-arm payloads, nested typed catches, loops/multiple execution, catch-all extraction, typed/loop/targeted/multivalue or broader value-control rethrows, and broader delegates remain negative families. No compare lane is authorized yet.

## Direct nested catch rethrow depths remain outside public fuzzing

Commits `1ac52d9fa` and `23f9ba164` add internal lowering and admission for any positive rethrow depth through an exact direct chain of markerless resultless catch-all owners. HOT lower moves `89/90 -> 90/90`; whitebox flatten moves `200/201 -> 201/201`; final IR is `327/327`, passes `5,794/5,794`, and full `9,264/9,264`.

At that checkpoint this still created no aggregate or public compare lane. The blanket block/if-wrapper negative is superseded by the next section; typed markers, loops, value results, nested try-body rethrows, mixed transfers, and broader nested ownership remain negative families.

## Strict nested-catch block/if wrappers remain outside public fuzzing

Commits `70280e159` and `1fc7c6077` admit positive nonzero rethrow depth through strict resultless unused-label single-root block ancestry and then through arbitrary strict mixed block/selected-if ancestry between markerless resultless catch-all owners. Whitebox moves `201/202 -> 202/202 -> 202/203 -> 203/203`; final passes are `5,796/5,796` and full is `9,266/9,266`.

This still creates no aggregate or public compare lane. A future EH profile must generate direct and strict wrapped catch-all depth chains separately, including then- and else-selected if paths and mixed control sequences, while rejecting typed markers, targeted/value-carrying/multi-root wrappers, loops, nested try-body rethrows, mixed transfers, and broader nested ownership. No profile, generator test, allowlist, descriptor, dispatcher, CLI execution, compare/API, preset, scheduler, or public pass surface was added.

## Exact targeted catch-if exits remain outside public fuzzing

Commits `c90bed031` and `8529deb42` admit strict nonzero-rethrow ancestry through one targeted resultless catch-if subset. Both arms have exactly one root; one selected arm owns the current rethrow or nested try; the sole opposite-arm root is also the label's only indexed user. The target user may be one payloadless `br`, or one payloadless `br_if` whose sole condition is already-simple scalar `i32`. Target, condition, rethrow depth, and exact target-catch lowering slot remain unchanged.

Red-first whitebox moved `203/204 -> 204/204` and `204/205 -> 205/205`; final validation is HOT mutation `16/16`, HOT lower `90/90`, IR `327/327`, focused flatten `263/263`, passes `5,798/5,798`, and full `9,268/9,268`. No profile, generator test, allowlist, descriptor, dispatcher, CLI execution, compare/API, preset, scheduler, or public pass surface was added.

A future EH aggregate should generate both then- and else-selected forms, the plain and simple-conditional opposite exits, and strict mixes with existing untargeted blocks/ifs at every catch depth. It must also reject multiple/outside label users, payload-carrying exits, same-arm targeting, multi-root/value-carrying/multivalue wrappers, loops, typed composition, nested try-body rethrows, and broader targeted ownership. The blanket rich-condition negative is superseded only by the exact one-use supported scalar `i32` family below. No compare lane is authorized yet.

## Rich targeted conditions and interleaved catch roots remain outside public fuzzing

Commits `61fb9919b` and `1fb8f64ec` add two more internal-only positive families. The targeted-if profile surface now needs a payloadless opposite-arm `br_if` with one one-use supported rich scalar `i32` condition, while retaining negatives for shared, control, tee, non-`i32`, payload-bearing, outside-user, and broader targeted forms. The catch profile surface now needs ordered same-tag independently owned direct-root lanes with unrelated roots before or between lane roots, while retaining reverse/ambiguous order, partial/mixed lanes, non-first-descendant/repeated/shared/outside use, selected-arm, loop, nested-catch, and catch-all negatives.

Red-first whitebox moved `205/206 -> 206/206` and `206/207 -> 207/207`; final validation is HOT mutation `16/16`, HOT lower `90/90`, IR `327/327`, focused flatten `263/263`, passes `5,800/5,800`, and full `9,270/9,270`. No aggregate, generator test, allowlist, descriptor, dispatcher, CLI execution, compare/API, preset, scheduler, or public pass surface was added. The durable performance checkpoint remains unrequalified at `970.5 us` / `3.65x` Binaryen v130.

## Block-wrapped targeted exits and scalar typed rethrows remain outside public fuzzing

Commits `404252e63` and `a24539c99` add two internal-only positive families. A future EH aggregate now needs targeted catch-if opposite exits under one exact resultless unused-label single-root block, including arm-local rich scalar `i32` conditions. It also needs one scalar typed catch whose repaired payload and direct `Rethrow(0)` lower through `catch_ref`, payload-plus-exnref handler results, and `throw_ref`.

Red-first whitebox moved `207/208 -> 208/208` and `208/209 -> 209/209`; final validation is HOT mutation `16/16`, HOT lower `90/90`, IR `327/327`, focused flatten `263/263`, passes `5,802/5,802`, and full `9,272/9,272`. No aggregate, generator test, allowlist, descriptor, dispatcher, CLI execution, compare/API, preset, scheduler, or public pass surface was added. The durable performance checkpoint remains unrequalified at `970.5 us` / `3.65x` Binaryen v130.

The future negative corpus must retain multi-root/targeted/value-carrying block wrappers, multiple or outside label users, broader targeted ancestry, multiple payload lanes or typed rethrows, non-direct/nonzero/wrapped/nested/loop typed transfers, missing payload-plus-exnref handler types, and all broader catch/control ownership failures.

## Typed payload vectors and strict targeted block chains remain outside public fuzzing

Commits `740dfa2b5` and `374040a26` add two more internal-only positive families. A future EH aggregate now needs same-tag scalar typed payload vectors with one direct `Rethrow(0)`, including handler result vectors ending in `exnref`, reverse stack capture, and source-order locals. It also needs targeted catch-if exits under arbitrary positive strict resultless unused-label single-root block chains, with rich conditions remaining innermost.

Red-first whitebox moved `209/210 -> 210/210` and `210/211 -> 211/211`; final validation is HOT mutation `16/16`, HOT lower `90/90`, IR `327/327`, focused flatten `263/263`, passes `5,804/5,804`, and full `9,274/9,274`. No aggregate, generator test, allowlist, descriptor, dispatcher, CLI execution, compare/API, preset, scheduler, or public pass surface was added. Performance remains unrequalified at `970.5 us` / `3.65x` Binaryen v130.

The future negative corpus must retain mixed tags, multiple typed rethrows, non-direct/nonzero/wrapped/nested/loop typed transfers, missing payload-vector-plus-exnref handler types, and multi-root/used-label/targeted/value-carrying/loop/try-like or otherwise non-strict targeted wrappers.

## Typed block-chain rethrows and selected catch-if delegates remain outside public fuzzing

Commits `b7b85a8bf` and `3595d6563` add two internal-only positive families. A future EH aggregate now needs repaired same-tag scalar payload vectors whose sole `Rethrow(0)` sits under arbitrary positive strict resultless unused-label single-root block chains. It also needs direct, strict catch-block-chain, and exact constant-selected catch-if delegate representations, including then- and else-selected chains with a childless opposite `nop` and the exact active target.

Red-first whitebox moved `211/212 -> 212/212` and `212/213 -> 213/213`; final validation is IR `327/327`, focused flatten `263/263`, passes `5,806/5,806`, and full `9,276/9,276`. No aggregate, generator test, allowlist, descriptor, dispatcher, CLI execution, compare/API, preset, scheduler, or public pass surface was added. Performance remains unrequalified at `970.5 us` / `3.65x` Binaryen v130.

The future negative corpus must retain value-carrying, targeted, used-label, multi-root, if/loop/try-like, or otherwise non-strict typed wrappers; multiple/nonzero/nested typed rethrows; and delegate catch-if shapes with nonconstant or rich/effectful selectors, missing else arms, richer opposite roots, targeted/used labels, value results, loops, nested tries, mixed catches, or non-active targets.

## Selected typed rethrows and empty delegate arms remain outside public fuzzing

Commits `de138eb24` and `dc3cdb597` add two internal-only positive families. A future EH aggregate now needs repaired same-tag scalar payload vectors whose sole `Rethrow(0)` follows exact constant-selected resultless unused-label if chains, including empty or childless-`nop` unselected regions. It also needs delegate catch-if chains with the same empty-or-`nop` representation and exact active target.

Red-first whitebox moved `213/214 -> 214/214` and `214/215 -> 215/215`; final validation is HOT lower `90/90`, IR `327/327`, focused flatten `263/263`, passes `5,808/5,808`, and full `9,278/9,278`. No aggregate, generator test, allowlist, descriptor, dispatcher, CLI execution, compare/API, preset, scheduler, or public pass surface was added. Performance remains unrequalified at `970.5 us` / `3.65x` Binaryen v130.

The future negative corpus must retain mixed tags, multiple/nonzero/nested typed rethrows, nonconstant/effectful selectors, missing else regions, executable opposite roots other than the admitted childless `nop`, targeted/used labels, value results, loops, nested tries, mixed catches, non-active targets, and all broader catch/control ownership failures.

## Grouped catch roots and no-work delegate blocks remain outside public fuzzing

Commits `62992d7c5` and `9ee7b710e` add two internal-only positive families. A future EH aggregate now needs ordered same-tag vectors that combine positive lane groups under nested block chains with later direct/interleaved lane roots. It also needs constant-selected delegate catch-if chains whose unselected regions are empty, childless `nop`, or strict resultless unused-label single-root block chains ending in either representation.

Red-first whitebox moved `215/216 -> 216/216` and `216/217 -> 217/217`; final validation is HOT query `11/11`, HOT lower `90/90`, focused flatten `263/263`, passes `5,810/5,810`, and full `9,280/9,280`. No aggregate, generator test, allowlist, descriptor, dispatcher, CLI execution, compare/API, preset, scheduler, or public flatten surface was added. The `.mbti` addition is a generic HOT query only. Performance remains unrequalified at `970.5 us` / `3.65x` Binaryen v130.

The future negative corpus must retain reverse/ambiguous/partial/mixed-tag grouped payloads, repeated/shared/outside uses, selected-arm lanes, nested typed catches, loops/multiple execution, catch-all extraction, and delegate opposites containing executable work, used labels, value results, multiple roots, loops, nested tries, missing else regions, nonconstant/effectful selectors, mixed catches, or non-active targets.

## Interleaved grouped lanes and no-work forests remain outside public fuzzing

Commits `41b16db02` and `4c6a1de9b` add two more internal-only positive families. A future EH aggregate now needs grouped payload lanes with unrelated roots between exact final-region lane roots, followed by later direct/interleaved lanes. It also needs constant-selected delegate catch-if opposites containing multiple independent childless-`nop` or strict no-work block-chain roots.

Red-first whitebox moved `217/218 -> 218/218` and `218/219 -> 219/219`; final HOT query is `12/12`, HOT lower `90/90`, focused flatten `263/263`, passes `5,812/5,812`, and full `9,283/9,283`. No aggregate, generator test, allowlist, descriptor, dispatcher, CLI execution, compare/API, preset, scheduler, or public pass surface was added.

The future negative corpus must retain reverse/ambiguous/partial/mixed grouped lanes, repeated/shared/outside uses, selected-arm lanes, nested typed catches, loops/multiple execution, catch-all extraction, and delegate forests containing executable roots, used labels, value results, multi-root blocks, loops, nested tries, missing else regions, nonconstant/effectful selectors, mixed catches, or non-active targets.

## Future executable lane

Enable a lane only after Starshine has an active flatten implementation, the harness admits and maps the spelling to Binaryen `--flatten`, and fixtures/profile generation demonstrate Flat-IR-relevant shapes with a meaningful `--min-compared` threshold. The future corpus must separately cover evaluation order, local/tee introduction, control and exception boundaries, multivalue carriers, and output flatness; generic valid modules do not prove those properties.

```text
moon build --target native --release src/cmd
bun fuzz compare-pass --pass flatten --count 10000 --seed 0x5eed \
  --gen-valid-profile <flatten-aware-profile> \
  --out-dir .tmp/pass-fuzz-flatten --jobs auto \
  --starshine-bin _build/native/release/build/cmd/cmd.exe \
  --min-compared <meaningful-threshold>
```

This is a future template, not a command to run against the current removed implementation.
