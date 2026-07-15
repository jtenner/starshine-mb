# Binaryen v130 `flatten`: nonthrowing bridge cleanup and proof-cache performance

## Scope

This note records the bounded internal-only iteration that:

1. proves whether a resultless synthetic catch-all `Try` body may throw before HOT lowering;
2. removes dead handler scaffolding for nonthrowing bodies, retaining only a void block when the try label is targeted;
3. admits direct `i32.mul` and `i32.and` resultless-call argument roots after unconditional legacy-try `br_table` transfer;
4. replaces repeated suffix use-def construction with one run-wide snapshot and admission-time cache of exact owned nodes plus owner region;
5. truncates an admitted terminal-table suffix without rebuilding the region holder's child span;
6. keeps scalar branch-target rewrite checks on the immutable pre-mutation branch index rather than rebuilding a live-node index after rewriting starts;
7. threads that same exact branch population through multivalue block/if target support, recursive table checks, deferred admission, and mutation-time routing;
8. resolves each admitted `br_table` target's complete typed local vector once and reuses it for every payload lane;
9. makes multivalue legacy-try label support consume the immutable pre-mutation branch population instead of rescanning every live node;
10. replaces full use-def construction in multivalue legacy-try and loop conditional ownership proofs with exact lightweight reachable use counts.

The public registry, dispatcher, CLI execution path, preset scheduler, compare allowlist, and flatten API snapshots remain unchanged. Across the iterations recorded here, the only `.mbti` addition is the public HOT mutation `hot_region_truncate_suffix(...)` in `src/ir/pkg.generated.mbti`; the newest multivalue changes add no API. `flatten` is still public-removed.

## Pinned source and commits

- Iteration start: `4c8a02ebc`.
- Code commit 1: `d20ebd21c` (`perf: elide nonthrowing flatten catch bridges`).
- Code commit 2: `e9cb90b84` (`perf: share flatten suffix use-def proofs`).
- Code slice 3: run-wide suffix cache plus direct `i32.and` admission, committed with this note.
- Later label/shift iteration: `de1bc430f`, `64a86a381`, and docs commit `e14935de2`.
- Current proof-cache/routing iteration: `23f779aa8` (`perf: cache flatten terminal table proofs`) and `32da5c798` (`perf: avoid duplicate flatten terminal routing`).
- Current lightweight-analysis/batch-mutation iteration: `b610394b4` (`perf: use lightweight flatten ownership counts`) and `56908b781` (`perf: batch flatten detached suffix deletion`).
- Current branch-index/in-place-tail iteration: `c6181e26d` (`perf: index flatten branch targets once`) and `0a415161f` (`perf: replace flatten value tails in place`).
- Current suffix-truncation/proof-boundary iteration: `13fe7b744` (`perf: truncate flatten dead suffixes in place`) and `9acdac744` (`fix: keep flatten scalar routing on pre-mutation proofs`).
- Current multivalue-index/table-vector iteration: `9aa7499e9` (`perf: index flatten multivalue target branches`) and `710cdc910` (`perf: resolve flatten table target vectors once`).
- Current legacy-try branch/ownership iteration: `e39faf79e` (`perf: index flatten multivalue try branches`) and `e64428dc1` (`perf: reuse flatten conditional ownership counts`).
- Captured owner: `.tmp/binaryen-v130/Flatten.cpp`.
- Owner SHA-256: `5b8836c46490095e98ba8202f866b153cfacc6f9c24ac498b703702adc3455b6`.
- Oracle: `/mise/http-tarballs/78d28b82d329cecc96d14b1872ee2a890d09be4705c634ffb04ebf8c592c1e48/binaryen-version_130/bin/wasm-opt`.
- Direct probe form: `wasm-opt <probe>.wat --all-features --flatten -S`.

Binaryen v130 direct flatten retains the legacy try and unreachable suffix in Flat-IR order. Its matched `--vacuum --dce` neighborhood removes a catch whose body cannot throw. Starshine now performs that nonthrowing proof during lowering, while preserving the bridge for calls or other possibly throwing bodies.

## Red-first tests

Exactly one behavioral test was added for each code slice:

- `hot lower elides a nonthrowing synthetic catch-all bridge` failed on the nested `block` / `try_table` bridge, then passed with direct body emission and module validation; the prior bridge test was changed to contain a possibly throwing call and still proves the bridge path;
- `flatten removes an exclusively owned direct multiply call suffix` failed unchanged at `238/239`, then passed after direct `i32.mul` root admission and per-attempt use-def reuse;
- `flatten removes an exclusively owned direct and call suffix` failed unchanged at `239/240`, then passed after direct `i32.and` admission and run-wide cached ownership.

The whitebox outside-roster boundary moved from newly admitted `i32.mul`, then `i32.and`, through the shift family and now rests at still-gated `i32.rotl`; it remains a fail-closed boundary rather than a second positive slice.

The terminal-proof/routing iteration added exactly one red-first test per commit:

- `flatten terminal table proofs require an exact pre-mutation cache` failed at `142/143` because a suffix-only cache still authorized the broader terminal-table proof after mutation started; exact table id, label, payload arity, mixed-target policy, and support are now cached together, and the test passes at `143/143`;
- `flatten removes an exclusively owned direct unsigned-shift call suffix` failed unchanged at `244/245`, then passed after direct `i32.shr_u` admission under the existing recursive distinct one-use proof. The pinned v130 probe retains `i32.shr_u`, `call $dead`, and unreachable Flat-IR debris.

The current lightweight-analysis/batch-mutation iteration also added exactly one red-first invariant per code commit:

- `flatten lightweight use counts match exact pre-mutation ownership` first failed to compile because the lightweight builder did not exist. The first implementation exposed detached-but-live parent references and failed two existing suffix-sequence tests; changing the builder to traverse only the reachable root graph made its counts agree with full use-def for roots, structured regions, repeated child uses, and every live node in the fixture. Private flatten then passed `144/144`;
- `batched detached node deletion tombstones the whole set with one revision` first failed because `hot_delete_detached_nodes` did not exist. The new exact distinct-set mutation preflights every id before mutation, tombstones the whole detached set, preserves survivor liveness and no-immediate-reuse behavior, and bumps the HOT revision once. Focused HOT mutation passes `10/10`.

The branch-index/in-place-tail follow-up again added exactly one red-first invariant per code commit:

- `flatten label branch cache records each exact targeting node once` failed because `flatten_build_label_branch_nodes` was unbound. The implemented immutable index records each live branch-like node once per targeted label, deduplicates repeated/default `br_table` labels, derives `label_used` from the same scan, and lets scalar target admission inspect only exact target users. Private flatten moved to `145/145`;
- `flatten replaces one region root without rebuilding its siblings` failed because `flatten_set_region_root` was unbound. The helper uses public HOT root replacement for one-for-one value-tail writes, preserves sibling identity and the old value as the new `local.set` child, invalidates pass analyses, and advances the HOT revision exactly once. Scalar and multivalue block, if, loop, and legacy-try result tails now avoid full region child-array reconstruction. Private flatten moved to `146/146`.

The suffix-truncation/proof-boundary follow-up added exactly one red-first invariant per code commit:

- `body region suffix truncation preserves the existing child span` failed because `hot_region_truncate_suffix` was unbound. The new HOT mutation detaches an ordered suffix by reducing the existing holder span, preserves the prefix and child-storage count, returns detached roots in order, and advances the revision once. Flatten uses it before the existing exact distinct-node tombstone. Focused region-edit tests pass `4/4`;
- `flatten rewrite scalar target proof uses the pre-mutation branch index` failed because `flatten_rewrite_target_can_route_scalar_branches` was unbound. The rewrite-only helper consumes `FlattenRewriteState.label_branch_nodes` for scalar `br`, `br_if`, and `br_table` routing, so post-snapshot live nodes cannot widen mutation-time admission. Private flatten moved to `147/147`.

The multivalue-index/table-vector follow-up also added exactly one red-first invariant per code commit:

- `flatten rewrite multivalue target proof uses the pre-mutation branch index` failed because the support function had no `state` parameter and `flatten_rewrite_multivalue_branch_target_is_supported` was unbound. The implemented path uses the immutable label branch population during recursive target support, deferred rich-payload admission, and rewrite-time `br`, `br_if`, and `br_table` checks. A malformed post-snapshot branch can make the uncached proof fail but cannot widen the rewrite proof. Private flatten moved to `148/148`;
- `flatten resolves each br_table target local vector once` failed because `flatten_rewrite_br_table_target_locals` was unbound. The helper preflights every target kind and existing vector type without mutation, requires the rewrite boundary, resolves each unique target vector once, and reuses the exact vectors on repeated calls without adding locals. Private flatten moved to `149/149`.

The legacy-try branch/ownership follow-up added exactly one red-first invariant per code commit:

- `flatten rewrite multivalue try proof uses the pre-mutation branch index` failed at `149/150` because multivalue legacy-try support still scanned every live node after the snapshot. It now consumes `state.label_branch_nodes[label]` during admission and rewrite; an uncached malformed post-snapshot branch fails without widening the mutation-time branch population;
- `flatten rewrite multivalue try flow uses pre-mutation ownership counts` first failed to compile because the exact flow proof had no `state` parameter and the rewrite-only helper was unbound. Legacy-try and loop `br_if` flow proofs now use `HotNodeUseCounts`, and the rewrite helper requires the mutation boundary before consuming the pre-mutation ownership population. Private flatten moved to `151/151`.

## Ownership and mutation safety

`FlattenRewriteState` now owns:

- one lightweight exact reachable node-use-count snapshot built before admission, without full use-site or local-use allocation;
- one optional exact dead-suffix node vector per table node;
- the exact owner region for each cached vector;
- one exact terminal-table support record keyed by table node, try label, payload arity, and mixed-target policy;
- a `rewrites_started` boundary.

Admission computes and caches the complete distinct one-use proof. The lightweight count builder traverses only the reachable root graph, so detached-but-live stale parents cannot inflate ownership counts; focused comparison locks agreement with full use-def. Rewrite consumes only a suffix cache entry whose table id and owner region match and a terminal-table proof whose table, label, payload arity, and mixed-target policy match exactly. After the exact same-region suffix roots are detached, one batch mutation tombstones the complete cached distinct node vector and invalidates the HOT revision once. Suffix detachment now truncates the holder's existing child span instead of allocating a replacement span. Scalar and multivalue mutation-time target checks consume the cached exact branch-node population; they do not discover nodes allocated after the admission snapshot. Recursive multivalue table support receives the same snapshot rather than falling back to a live-node scan.

After every target/type/control family has passed admission, table routing performs one additional nonmutating preflight over all unique targets and any existing label-temp vectors. Only then does it allocate missing block/if/try vectors, while loop vectors must already match exactly. The resulting vector array is reused for every payload lane and on repeated resolution. If mutation has started and any required proof is absent, or any target vector is inconsistent, the corresponding check fails closed. This prevents a stale, partial, or post-snapshot fact from widening ownership, target support, or local-channel construction after structural edits.

Multivalue legacy-try label support now iterates only the exact branch nodes captured for the try label. Conditional flow ownership no longer allocates node-use-site arrays or CFG/local-use data: admission uses the run-wide lightweight reachable counts, rewrite uses the same frozen population behind the explicit `rewrites_started` boundary, and uncached checks can still rebuild current lightweight counts for whitebox comparison. The loop conditional helpers use the same count representation, including one shared count snapshot inside the loop-wide proof. No new control or payload family is admitted.

## Refreshed output matrix

The same three synthetic probes from the prior impact note were regenerated after the lowering change. Binaryen artifacts remain the pinned prior-oracle outputs.

| Probe | Input | Starshine direct | Starshine cleanup | Binaryen direct | Binaryen cleanup |
| --- | ---: | ---: | ---: | ---: | ---: |
| catch-all result bridge | 66 | 64 | 64 | 87 | 72 |
| recursive call tree | 69 | 74 | 74 | 94 | 82 |
| direct subtract call | 69 | 74 | 74 | 94 | 82 |
| **Aggregate** | **204** | **212** | **212** | **275** | **236** |

Every current Starshine direct and cleanup artifact passed `wasm-tools validate --features all`.

The narrow bridge/control/local family is now a measured Starshine size win:

- direct: 63 bytes smaller than Binaryen (`212` versus `275`);
- matched cleanup: 24 bytes smaller than Binaryen (`212` versus `236`);
- Starshine cleanup is a no-op on these already-clean emitted shapes.

The WAT difference is source-backed: nonthrowing catch bodies are unreachable, live try-label branches are preserved by one void block, and Starshine avoids Binaryen's extra result-copy locals. This classification is limited to the measured synthetic catch-all subset; it is not evidence for typed catches or broader EH.

## Runtime semantics

Node instantiated all input, Binaryen direct, Binaryen cleanup, current Starshine direct, and current Starshine cleanup artifacts with a no-op `env.sink` import. Every probe returned the expected deterministic result (`3` for the branch-free bridge and `7` for both table-transfer probes).

Sum of per-probe medians after 10,000 warmups and 15 samples of 100,000 calls:

| Lane | Sum of medians |
| --- | ---: |
| input | 1.342171 ms |
| Binaryen direct | 1.524702 ms |
| Binaryen cleanup | 1.364372 ms |
| Starshine direct | 1.379081 ms |
| Starshine cleanup | 1.365836 ms |

These samples establish deterministic agreement and no obvious runtime regression. They remain too narrow and noisy for a runtime-win claim.

## Pass-local performance

The representative native release benchmark prebuilt 120 HOT functions, evenly split across the one-multiply-child, two-multiply-child, and deeper-two-multiply-plus-constant call-argument families. Five warmups preceded 20 measured `flatten_run(...)` batches.

| Lane | Median | Range | Ratio to Binaryen |
| --- | ---: | ---: | ---: |
| prior current | 3,682.5 us | 3,529..3,765 us | 13.84x |
| run-wide cached current | 2,345.5 us | 2,248..2,660 us | 8.82x |
| cached EH/effective-terminal current | 1,641 us | 1,583..1,813 us | 6.17x |
| cached scalar-try support current | 1,275 us | 1,224..1,324 us | 4.79x |
| explicit EH admission-gate current | 1,347.5 us | 1,280..1,931 us | 5.06x |
| cached label-use / direct-shift current | 1,218.5 us | 1,159..1,310 us | 4.58x |
| signed-shift / state-threaded current | 1,259 us | 1,219..1,321 us | 4.73x |
| exact terminal-table proof cache | 1,195 us | 1,166..1,485 us | 4.49x |
| unsigned-shift / duplicate-router removal | 1,182.5 us | 1,166..1,425 us | 4.44x |
| same-session current-iteration baseline | 1,266.5 us | 1,221..1,517 us | 4.76x |
| lightweight reachable ownership counts | 1,115.5 us | 1,050..1,471 us | 4.19x |
| batched detached suffix deletion current | 970.5 us | 955..1,161 us | 3.65x |
| Binaryen v130 | 266.05 us | 250.16..380.856 us | 1.00x |

The follow-up profile attributed most measured time to repeated legacy-try support during rewrite. `FlattenRewriteState` now caches the immutable pre-admission EH prerequisite classification, try-target terminal checks consume the existing cached suffix proof instead of rebuilding an uncached use-def snapshot, and the complete scalar legacy-try support decision is cached per owner before mutation and consumed only by matching later rewrite checks. The representative median improved another 22.30% from `1,641 us` to `1,275 us`. After adding explicit catch-payload and exceptional-transfer admission outcomes, the same 120-function native-release shape reran at `1,347.5 us`. The next iteration cached immutable label-use facts once per rewrite state and reused them through scalar and multivalue control support/routing, reaching `1,218.5 us` in the first post-change sample. After adding direct signed-shift roots and threading state through rich branch admission, the rerun measured `1,259 us`.

The prior exact phase profile, measured across the same 120 prebuilt candidate-dense functions after five warmup batches, reported median batch attribution of `55.5 us` classify, `152.5 us` rewrite-state construction, `251.5 us` admission, `684.5 us` rewrite, and `5 us` body-result handling. The current iteration profiled inside those two dominant areas before choosing each slice. The state-construction subprofile attributed medians of `11.5 us` label-temp arrays, `15 us` EH prerequisite scan, `18.5 us` label-use computation, `131 us` full node-use use-def construction, and `16.5 us` cache-array initialization. Replacing only the immutable ownership need with reachable node-use counts reduced that subprofile's ownership component to `26.5 us`; the same-session pass median moved from `1,266.5 us` to `1,115.5 us`, an `11.92%` improvement.

The rewrite subprofile then attributed the successful terminal-table route to `27.5 us` preflight, `30 us` payload staging, `3.5 us` cached suffix lookup, `185 us` suffix mutation, `48.5 us` target copies, and `13 us` selector handling. Inside suffix mutation, region splice accounted for `64 us` and per-node detached deletion for `73.5 us`, with the remaining time in root search and repeated mutation bookkeeping. The batch deletion API preserves the exact cached distinct ownership set while replacing per-node revision bumps with one invalidation. The final pass-only median is `970.5 us` (`955..1,161 us`), down `13.00%` from code 1 and `23.37%` from the same-session iteration baseline.

The final exact phase profile at the lightweight-analysis/batch-mutation checkpoint reports `53.5 us` classify, `67.5 us` state construction, `245.5 us` admission, `590.5 us` rewrite, and `5.5 us` body-result handling. Relative to the prior exact phase profile, state construction fell `55.74%` and rewrite fell `13.73%`; rewrite remained dominant and admission second.

The next iteration profiled before each slice. In the pre-code-1 admission sample, scalar-try support consumed `265 us` across 120 functions, including `170 us` in the full-node target-use scan and `54 us` in terminal-tail checks; inputful-loop and rich-branch admission contributed `10 us` and `33 us`. After indexing exact branch targets once, a diagnostic one-batch profile reported `48 us` classify, `65 us` state, `222 us` admission, and `647 us` rewrite. Within rewrite, terminal-table routing contributed `238 us` and scalar-try result routing `134 us`, motivating one-for-one region-root replacement as code 2. These instrumented one-batch sums are diagnostic attribution, not substitutes for the repeated timing medians.

On one same-session reconstructed 120-function chain, the median moved from the pre-iteration `1,197.5 us` (`1,120..1,432`) to `1,092.5 us` (`1,057..1,135`) after the branch index, then `1,030 us` (`1,005..1,064`) after in-place value tails: a `13.99%` total reduction. On the exact candidate shape, code 1 measured `1,052.5 us` (`1,001..1,111`), while code 2 measured `1,033.5 us` (`969..1,122`) with a noisier `1,047 us` rerun (`997..1,536`). The prior stable checkpoint remains `970.5 us`; all samples remain outside the maximum acceptable `2x` threshold.

The suffix-truncation iteration reconstructed the same three-family, 120-function native-release chain from clean `1f1a2dfd0`. Clean HEAD measured `1,116.5 us` (`1,060..1,377`); `13fe7b744` measured `1,053.5 us` (`1,030..1,070`), a `5.64%` reduction from avoiding holder-span rebuilds during terminal suffix removal. The proof-boundary commit did not produce a measurable timing win: exact-candidate samples were `1,173 us` (`1,087..1,415`) and `1,202.5 us` (`1,064..1,572`), with a same-session `1,191.5 us` sample versus code 1 at `1,133.5 us`; a branch-index-heavy probe was similarly noisy and slower. Classify `9acdac744` as failure-atomic proof reuse and scan-removal, not a measured performance win. Relative to Binaryen v130's `266.05 us`, the best current-iteration sample is still `3.96x`, and the prior stable `970.5 us` checkpoint is `3.65x`.

The multivalue branch-index slice used 120 independently lifted two-lane block-branch functions with 256 extra roots to magnify whole-live-node target scans. In the clearer same-session ordering, clean code-1 baseline `9aa7499e9^` measured `5,581.5 us` (`5,183..7,300`) and `9aa7499e9` measured `5,099 us` (`4,711..6,343`), an `8.64%` reduction. An earlier ordering measured `5,323.5 -> 5,199 us` (`2.34%`). The representative scalar terminal-table fixture moved only `2,939 -> 2,904.5 us`, which is noise-level and expected because it does not exercise multivalue target scanning.

The table-vector slice used 120 two-target, four-payload-lane functions with 256 extra roots. Code 1 and code 2 measured `7,848.5` versus `7,767.5 us` in one order, then `8,324` versus `8,619 us` in reversed order. Classify `710cdc910` as bounded repeated-resolution removal and stable failure-atomic local-vector reuse, not a measured speed win.

The legacy-try branch/ownership slice used 120 tuple-made two-lane legacy-try `br_if` functions with 256 extra roots. The iteration baseline measured `16,524.5 us` (`15,971..16,676`); branch indexing measured `16,167 us` (`16,048..16,354`), a `2.16%` reduction; lightweight conditional ownership measured `6,724.5 us` (`5,999..7,291`), a further `58.41%` reduction and `59.31%` total reduction from baseline. This is a measured win for the targeted multivalue conditional family, but it does not replace the prior stable representative candidate checkpoint of `970.5 us`, which remains `3.65x` Binaryen v130. Performance remains a hard blocker for public exposure.

## Validation

- HOT-lower focused file: `88/88`.
- Flatten focused file: `240/240`.
- Private flatten file: `142/142`.
- Pass package: `5,712/5,712`.
- Full suite: `9,171/9,171`.
- `moon info`: passed with existing warnings.
- Every regenerated matrix artifact validated with all features.
- `git diff --check` and docs link/source review are required before commit.

Follow-up proof-cache validation: direct `i32.or` behavior was red at `240/241` and green at `241/241`; direct `i32.xor` behavior was red at `241/242` and green at `242/242`. Private flatten passed `142/142`, the pass package passed `5,714/5,714`, and `moon info` passed with the existing warnings.

Follow-up EH-gate validation used a pinned Binaryen v130 typed-catch probe. Direct `--flatten` stages the typed `(pop i32)` into a fresh local before the original drop, confirming that payload extraction is semantic work rather than optional cleanup. The updated private behavior test first failed because a rooted `Catch` plus an otherwise flattenable rich operand returned `{ changed: true }`; explicit `DeferredCatchPayloadRepair` and `DeferredExceptionalTransferRepair` admission outcomes now stop `Catch`/`CatchAll` and `Rethrow`/`Delegate` functions before locals or operand rewrites can begin. That iteration passed private flatten `142/142`, passes `5,714/5,714`, and the full suite `9,173/9,173`.

The next two red-first behavior slices admitted direct `i32.shl` and `i32.shr_s` resultless-call argument roots under the same complete distinct one-use proof. Each pinned Binaryen v130 probe retains the operation, call, and unreachable Flat-IR debris. Focused flatten moved from `242/243` to `243/243`, then `243/244` to `244/244`; the private boundary remained `142/142` while moving from `i32.shl` to `i32.shr_s` and then `i32.shr_u`. That iteration passed passes `5,716/5,716`, the full suite `9,175/9,175`, `moon info`, targeted formatting, and `git diff --check`.

The terminal-proof/routing validation moved private flatten from red `142/143` to green `143/143`, then focused flatten from red `244/245` to green `245/245`. That iteration passed private flatten `143/143`, passes `5,718/5,718`, the full suite `9,177/9,177`, `moon info`, targeted formatting, and `git diff --check`.

The lightweight-analysis/batch-mutation validation moved private flatten to `144/144` and focused HOT mutation to `10/10`; focused flatten remained `245/245`. That checkpoint passed passes `5,719/5,719`, the full suite `9,180/9,180`, `moon info`, targeted formatting, and `git diff --check`. The reviewed `src/ir/pkg.generated.mbti` diff added `HotNodeUseCounts`, `hot_node_use_counts_build`, `hot_node_use_count`, and `hot_delete_detached_nodes`; no pass or CLI public API changed.

The branch-index/in-place-tail iteration passes focused flatten `245/245`, private flatten `146/146`, passes `5,721/5,721`, the full suite `9,181/9,181`, `moon info`, targeted formatting, and `git diff --check`. It changes no `.mbti` snapshot and adds no public pass, CLI, or IR API.

The suffix-truncation/proof-boundary iteration passes focused region editing `4/4`, focused flatten `245/245`, private flatten `147/147`, passes `5,722/5,722`, the full suite `9,183/9,183`, `moon info`, targeted formatting, and `git diff --check`. The reviewed `src/ir/pkg.generated.mbti` diff adds only `hot_region_truncate_suffix`; no pass, CLI, compare, or preset API changed. Repository-wide `moon fmt --check` remains blocked only by the pre-existing `moon.mod` syntax disagreement.

The multivalue-index/table-vector iteration passes focused flatten `245/245`, private flatten `149/149`, passes `5,724/5,724`, the full suite `9,185/9,185`, `moon info`, targeted formatting, and `git diff --check`. No `.mbti`, registry, dispatcher, CLI, compare/API, or preset surface changed. The pinned owner hash was rechecked after both commits and remained `5b8836c46490095e98ba8202f866b153cfacc6f9c24ac498b703702adc3455b6`. Neither commit admits a new semantic family, so no additional Binaryen probe was required.

The legacy-try branch/ownership iteration passes focused flatten `245/245`, private flatten `151/151`, passes `5,726/5,726`, the full suite `9,187/9,187`, `moon info`, targeted formatting, and `git diff --check`. No `.mbti` or public pass surface changed. The pinned owner hash remained `5b8836c46490095e98ba8202f866b153cfacc6f9c24ac498b703702adc3455b6`. Both commits preserve the admitted semantic surface, so no new Binaryen probe was required.

## Classification and remaining blockers

- **Measured Starshine win:** nonthrowing synthetic catch-all bridge/control/local output is 24 aggregate bytes smaller than Binaryen after matched cleanup, with deterministic runtime agreement.
- **Performance movement:** run-wide suffix, EH, effective-terminal, scalar-try, label-use, exact terminal-table, scalar/multivalue exact branch-target caches, duplicate-router removal, lightweight reachable ownership counts, batched detached deletion, in-place value-tail replacement, in-place suffix truncation, one-time table target-vector resolution, exact legacy-try branch indexing, and lightweight conditional ownership reduce repeated immutable scans, region rebuilds, full use-def allocation, and local-vector checks. The latest targeted legacy-try conditional delta is `16,524.5 -> 6,724.5 us` (`59.31%` across the iteration); the prior stable representative median remains `970.5 us`. Scalar proof-boundary and table-vector timings were noisy and are not measured wins. The stable representative result remains outside the `<=2x` Binaryen target.
- **Behavior movement:** direct `i32.mul`, `i32.and`, `i32.or`, `i32.xor`, `i32.shl`, `i32.shr_s`, and `i32.shr_u` call roots now use the same recursive complete-ownership proof; `i32.rotl` remains the tested outside-roster boundary.
- **Validation failure:** none observed.
- **True semantic mismatch:** none observed in the measured probes.
- **Durable representation gate:** `Catch`/`CatchAll` now select `DeferredCatchPayloadRepair`, while `Rethrow`/`Delegate` select `DeferredExceptionalTransferRepair`, before any mutation. This closes a partial-mutation hole but does not implement EH repair.
- **Still gated:** typed catches and payloads, nested-pop repair, `rethrow`, `delegate`, structured suffix control-plus-label deletion, broader branch/control families, result calls, indirect/reference calls, and public execution.
- **Public signoff:** not run. No flatten GenValid aggregate or four-lane compare surface exists, and public wiring remains intentionally removed.

## Next work

1. continue profiling the remaining rewrite and admission work after scalar/multivalue/legacy-try exact branch-use indexing, lightweight conditional ownership, in-place tail replacement, suffix truncation, and one-time target-vector resolution, especially target-copy/local construction itself, recursive region traversal, remaining tuple-flow use-site builds, loop branch-population scans, and any uncached support retries;
2. investigate typed catch payload representation and nested-pop repair as a lib/HOT capability slice, retaining whole-function failure atomicity;
3. extend HOT mutation with a verified control-plus-owned-label deletion operation before admitting structured suffix roots; the detached-node batch API still intentionally does not remove label metadata;
4. add a flatten-specific GenValid aggregate only after the admitted public surface and failure contract are stable enough to compare honestly.
