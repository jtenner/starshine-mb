---
kind: workflow
status: supported
last_reviewed: 2026-10-09
sources:
  - ../../../raw/tooling/2026-10-09-output-differences-v133.json
  - ../../../tooling/tracing-playbook.md
  - ../../../tooling/pass-fuzz-compare.md
  - ../../../../../scripts/lib/pass-fuzz-compare-task.ts
  - ../../../../../src/validate/gen_valid.mbt
  - ../../../../../src/validate/gen_valid_ssa.mbt
  - ../../../../../src/validate/gen_valid_simplify_locals.mbt
  - ../../../../../src/validate/gen_valid_wbtest.mbt
  - ../../../../../src/passes/simplify_locals.mbt
  - ./transform-family-inventory.md
---

# SimplifyLocals family fuzzing profiles

## October 9, 2026 final native comparison renewal

The final native CLI, SHA-256 `42f386573da7ccab4ae923122b17e29e9069a5686fb91921f89f439fd2de85a3`,
completed 10,000 new `simplify-locals-all` comparisons with seed `0x5eed`,
eight workers, at most eight subprocesses, and verified Binaryen 133.
The complete result is `.tmp/output-difference-final-sl-v133-10000/result.json`;
the [durable evidence record](../../../raw/tooling/2026-10-09-output-differences-v133.json)
retains its counts and toolchain identity. There are 380 normalized matches,
0 cleanup-normalized matches and 9,620 residual output differences.
Raw totals are 1,854,432/2,080,551 bytes
(Starshine/Binaryen); canonical totals are
1,864,179/2,080,551 bytes.
No output is larger under either size measure. Validation, generator, property
and command failures are zero. Independent `wasm-tools` validation was required.
Runtime observation was off in this aggregate; the family evidence below
provides the scoped semantic judgments. The final bounded wasm-gc suite passes
14,001/14,001 tests. Earlier measurements retain their original binary scope.

## October 9 encoding cleanup and complete replay

The encoding cleanup closes the 1,539 raw size losses in the October 9
baseline. The review classifies the remaining 9,620 differences as scoped
Starshine size wins; 380 cases have equal output. This judgment uses source
contracts, field measurements, runtime observations and downstream output.
It is limited to the generated inputs and arguments below.

The frozen native CLI SHA-256 is
`fce72edb42289901fefb4ae40f2febe7482f55f1dc3c425b89cf9b36c80983e1`.
A later native CLI, SHA-256
`17d4da47c7bc8788b98a6d4995275b41b8f9d65dd83b38e9d3912f12202602ec`,
produced byte-identical direct SimplifyLocals outputs for all 8,719 distinct
inputs and the five added fixtures. Thus the complete validation, runtime
and downstream evidence also applies to that build.
The Binaryen 133 oracle and regenerated seed `0x5eed` manifest retain the
identities in the baseline section below. Two workers replayed all 10,000
`simplify-locals-all` cases, including all 8,719 distinct input SHA-256 hashes.
Every raw and common-writer canonical output passed independent validation.
Command failures and raw/canonical size losses were zero.

| Generated family | Cases / distinct inputs | Raw byte delta | Canonical byte delta | Review classification |
| --- | ---: | ---: | ---: | --- |
| `dae2-locals` | 561 / 371 | -2 to 0 | -2 to 0 | 181 size wins; 380 equal outputs |
| `effect-order` | 1,225 / 1,225 | -14 to -5 | -15 to -6 | Size win within the read-only generator contract |
| `family-coverage` | 2,894 / 2,894 | -53 | -49 | Size and local-access win |
| `flat-parent` | 1,161 / 617 | -24 to -16 | -24 to -16 | Size win from no-op removal |
| `local-traffic` | 1,764 / 1,345 | -6 to -4 | -6 to -4 | Size win from no-op removal |
| `stress` | 604 / 604 | -17 to -5 | -18 to -6 | Size win after declaration/type cleanup |
| `structure-result` | 1,791 / 1,663 | -16 to -8 | -16 to -8 | Size win after transparent block cleanup |

Deltas are Starshine minus Binaryen bytes. Raw totals are 1,854,432 versus
2,080,551; canonical totals are 1,864,179 versus 2,080,551. Canonical output
uses the Binaryen 133 writer with no optimization passes. Type-section
payload bytes, local-declaration bytes and local-group counts equal the
oracle for every case, in both representations. The remaining savings are
in code and instruction payloads. The raw `effect-order` and `stress`
outputs use one extra import-encoding byte. Their complete raw modules
remain smaller.

The instruction skeleton counts, with immediates and declarations excluded,
are 6 for `dae2-locals`, 4 for `effect-order`, 1 for `family-coverage`, 2 for
`flat-parent`, 2 for `local-traffic`, 5 for `stress` and 3 for
`structure-result`. Every seed/declaration variant was replayed. The
`family-coverage` raw output has four fewer `local.get` and four fewer
`local.set` instructions. The common writer restores one capture pair, so
its canonical output has three fewer of each. Both forms remove 31 no-ops
and replace two pure-arm `if` expressions with `select`. The other families
have equal static counts of local, stack and control operations, apart
from no-op removal. `select` evaluates both pure operands. These instruction
counts do not establish engine-speed gains.

For each distinct input, temporary copies exported all functions, memories,
globals and tables. Binaryen 133 `-O` and `-Oz` produced byte-identical
Starshine and oracle outputs for every pair. Node `v26.11.1` then compared
input, Starshine and Binaryen in 235,150 fresh-instance call scenarios
(250,195 when weighted by duplicate cases). Numeric arguments were 0, 1,
-1, 255 and 256; reference arguments were null and non-null. Values, traps,
memory contents, globals and table states matched, with zero blocked cases.
There were 2,894 trap scenarios. The generated corpus has no imported
function calls. Five added fixtures compared 25 scenarios with 20 imported
call events and seven traps: captured call results, a call/global write
before an out-of-bounds load, null-reference traps, a call before
`unreachable`, and a taken `try_table` catch with a live local. All matched.
Compact imports were expanded to ordinary imports for Node runtime copies.

The [shared encoding cleanup](../../../../../src/passes/pass_encoding_cleanup.mbt)
removes no-ops, uses the existing label-name-aware control cleanup, and
reuses validated byte-saving type remapping. The
[SimplifyLocals wrapper](../../../../../src/passes/simplify_locals_encoding_cleanup.mbt)
groups numeric declarations after repaired writeback. Offset-sensitive
metadata keeps the module unchanged. Local remapping preserves parameters,
nested accesses and names; touched paths preserve unselected local indices.
Partial selections also keep the original module type table, because inlining
can restore untouched bodies with original type indices. Whole-module runs
and selections that cover every function still allow type cleanup. The
[selected restore tests](../../../../../src/passes/encoding_selected_type_restore_wbtest.mbt)
cover indirect calls and descriptor types after original bodies are restored.
[Pass tests](../../../../../src/passes/simplify_locals_encoding_wbtest.mbt)
and [dispatcher tests](../../../../../src/cmd/simplify_locals_encoding_wbtest.mbt)
cover the previously failing live-local, dead-type, transparent-block,
fused-stack and touched-path fixtures.

Local evidence: `/tmp/starshine-sl-postfix-all/{identity,complete-summary,runtime-results}.json`,
`/tmp/starshine-sl-postfix-extra/runtime-results.json`, and
`.tmp/output-difference-sl-postfix/`. Earlier dated evidence below remains
historical. This replay proves the stated size and downstream results; it
does not establish a universal semantic proof or a pass-time gain.

### Final declaration-gate proof at native `42f386`

The final native CLI SHA-256 is
`42f386573da7ccab4ae923122b17e29e9069a5686fb91921f89f439fd2de85a3`.
Its declaration preflight skips numeric grouping when no selected function
has a removable zero declaration run or a repeated numeric declaration
type. The preflight preserves the helper's numeric/reference, local-count,
and selected-mask rules. The helper still guards parameter types, opaque
names, offset metadata, strict byte savings, and replaced-body validation.
The [gate tests](../../../../../src/passes/oi_numeric_group_admission_wbtest.mbt)
check skipped unique numeric runs, intentionally unsupported nonzero
reference runs, and a live local remap with smaller encoded output. The
[raw helper tests](../../../../../src/passes/numeric_group_wbtest.mbt)
cover parameter indices, zero runs, and local-index LEB boundaries.

The two-worker replay compared all 8,719 distinct input hashes, all 10,000
weighted cases, and the five extra runtime fixtures against the complete
validated corpus proof above. Every direct output was byte-identical.
Thus those generated-family size, runtime, validation and common `-O`/`-Oz`
results apply to this final build. The compiler artifact also matched the
saved `17d4` output SHA-256 `de32f9a7...` and passed independent validation.
Artifact runtime and native `-O4z` parity remain unverified. No full-preset
result transfers from direct SimplifyLocals equality alone.

The three small inputs had one warmup and seven alternating measured
triplets, with native baseline `437cc5...`, final `42f386...`, and the pinned
Binaryen 133 oracle on an isolated host. Values below are medians.

| Input | Native pipeline baseline / final | Native wall baseline / final | Binaryen wall | Direct final / Binaryen bytes |
| --- | ---: | ---: | ---: | ---: |
| 128 functions, fragmented numeric locals | 8.634 / 8.184 ms | 11.486 / 11.421 ms | 5.184 ms | 3,893 / 4,149 |
| 1,024 functions, fragmented numeric locals | 60.836 / 64.583 ms | 68.821 / 72.408 ms | 8.531 ms | 30,774 / 32,822 |
| 128 functions, 256 alternating dead locals each | 12.582 / 15.275 ms | 20.873 / 21.674 ms | 7.558 ms | 4,789 / 5,045 |

A separate isolated artifact run used five alternating baseline/final
pairs. Median pipeline time was 1.273972 / 1.439864 s, an added 165.892 ms
or 13.0%. Median wall time was 1.931875 / 2.085276 s. This is still a material
cleanup cost for the 20-byte native-baseline saving. Artifact output remains
6,058,213 bytes, 368,910 bytes larger than Binaryen 133. The prior `9d2f`
run measured the pinned oracle at 0.588245 s wall time. That oracle time was
not remeasured in the final five-pair artifact run. The artifact size and
performance gap stays open.

The small inputs retain their measured size wins with remaining pipeline
overhead on the 1,024-function and wide-local shapes. These measurements do
not show engine-speed gains or universal pass-time parity. Earlier `9d2f`,
`17d4`, and `f855` records below keep their original identities and costs.

Final local evidence is in
`.tmp/output-difference-sl-postfix/{final-byte-equality-42f386,timing-final-group-gate-small-42f386,timing-final-group-gate-artifact-42f386}.json`.
The full-preset synthetic evidence below remains scoped to `17d4`.

### Control-gate checkpoint at native `9d2f`

The candidate gates use the same structured-child and control-transfer
rules as the default branchless-block flattener. Typed blocks qualify only
when they have no parameters. Candidate propagation includes loops, both
`if` arms, `try_table` bodies, and legacy try/catch bodies. A root
`unreachable` with a following instruction still admits tail cleanup. The
label-name remap includes labels removed from that dead root tail. The
[nop/block gate tests](../../../../../src/passes/pass_encoding_cleanup_admission_wbtest.mbt)
cover skipped branchful bodies and retained nested cleanup.

The control-gate checkpoint native CLI SHA-256
`9d2f32298a86fe13ded4cd7ed3f97cf33a9f9ae03bd5f8d0c4a3b95e6289523b`
produced byte-identical direct SimplifyLocals output for all 8,719 distinct
inputs, all 10,000 weighted cases, and the five extra runtime fixtures.
The complete corpus validation, size, runtime and common `-O`/`-Oz`
evidence above therefore applies to this build. The 6,211,596-byte artifact
also matched the `17d4` direct output, SHA-256
`de32f9a7274f8c915995f1f6d879e8b11697edd5a524cea4ba5c797f324bce5d`,
and passed independent validation. This artifact equality transfers no
runtime or native `-O4z` claim, because those results were not established
for the artifact.

A new isolated timing run used the same inputs, pinned Binaryen 133,
one warmup per tool, and seven alternating measured triplets for small
inputs or three for the artifact. Values below are medians.

| Input | Native pipeline baseline / `9d2f` | Native wall baseline / `9d2f` | Binaryen wall | Direct `9d2f` / Binaryen bytes |
| --- | ---: | ---: | ---: | ---: |
| 128 functions, fragmented numeric locals | 7.924 / 8.653 ms | 11.01 / 11.54 ms | 5.78 ms | 3,893 / 4,149 |
| 1,024 functions, fragmented numeric locals | 62.851 / 64.575 ms | 71.88 / 72.44 ms | 8.86 ms | 30,774 / 32,822 |
| 128 functions, 256 alternating dead locals each | 13.494 / 15.834 ms | 21.82 / 21.86 ms | 7.90 ms | 4,789 / 5,045 |
| 6,211,596-byte compiler artifact | 1.266633 / 1.517453 s | 1.978215 / 2.206910 s | 0.588245 s | 6,058,213 / 5,689,303 |

The artifact still has a material added cleanup cost: 250.820 ms of native
pipeline time, or 19.8%, for the same 20-byte saving against the native
baseline. Native SimplifyLocals function work was 71.570 / 70.032 ms;
function-stage totals were 1.068032 / 1.064838 s. Thus the added cost remains
outside the function stage. The gate change does not close the artifact
performance gap or its 368,910-byte raw size gap against Binaryen. The
small generated shapes retain their measured size wins with some pipeline
overhead; this does not show an engine-speed win. Earlier adverse timings
below remain separate checkpoints, with their original binary identities.

Local evidence is in
`.tmp/output-difference-sl-postfix/{final-byte-equality-9d2f,timing-final-9d2f}.json`.
The direct replay used two workers. Its recorded duration is a replay cost,
not an isolated pass benchmark. Native `-O4z` results at `17d4` below remain
scoped to that checkpoint; direct SimplifyLocals equality does not establish
full-preset equality for the final gate change.

### Pass cost and artifact limits at native `17d4`

An isolated before/after comparison used the October 9 baseline native CLI
`437cc5...`, native `17d4...`, and the pinned Binaryen 133 oracle. Each small
fixture had one warmup and seven alternating measured triplets; the large
fixture had one warmup and three. Native timings used pass tracing to
separate decode, pipeline and encode work. Binaryen ran `--simplify-locals`
with all features and stripped debug sections. Values below are medians.

| Input | Native pipeline baseline / `17d4` | Native wall baseline / `17d4` | Binaryen wall | Direct `17d4` / Binaryen bytes |
| --- | ---: | ---: | ---: | ---: |
| 128 functions, fragmented numeric locals | 7.727 / 8.508 ms | 10.97 / 11.05 ms | 5.53 ms | 3,893 / 4,149 |
| 1,024 functions, fragmented numeric locals | 58.530 / 61.561 ms | 66.01 / 68.71 ms | 8.36 ms | 30,774 / 32,822 |
| 128 functions, 256 alternating dead locals each | 11.888 / 13.978 ms | 19.65 / 19.65 ms | 7.06 ms | 4,789 / 5,045 |
| 6,211,596-byte compiler artifact | 1.172937 / 1.468769 s | 1.791899 / 2.084641 s | 0.544726 s | 6,058,213 / 5,689,303 |

The three synthetic shapes retain a measured size win with some cleanup
pipeline overhead. The artifact still has a material cost gap: about 296 ms
extra pipeline time for a 20-byte saving against the native baseline. Its
raw output is also 368,910 bytes larger than the oracle. This artifact is
outside the generated-family size-win classification above; its broader
size/performance parity remains open. The actual native SimplifyLocals
function work was 66.698 / 71.459 ms. The remaining cost is outside that
function-pass timer.

The earlier `f8552a...` attempt had about 702 ms extra artifact pipeline
cost. It encoded and validated the complete module for a plain-type size
decision. The new guarded type-section proof reduces that cost, because
independent function type remaps have nonincreasing indices and LEB widths.
The adverse attempt is archived with its original identity. It is not a
performance win.

A separate native `-O4z` check exported every synthetic function. Baseline
and `17d4` outputs were byte-identical raw and canonical: 2,920 bytes for
128 functions and 24,449 bytes for 1,024. Common v133 `-O` and `-Oz` outputs
were also byte-identical at 1,758 and 14,327 bytes. Input/baseline-native/
`17d4`-native runtime replay compared 5,760 fresh-instance calls and imported
events, with no differences or blocked cases. This gives scoped evidence
that the early grouping does not worsen those preset outputs. Both native
versions exceeded the 60-second `-O4z` bound on the compiler artifact, so
its preset downstream result is unverified. These size checks ran outside
the isolated timing window.

Local cost/preset evidence is in
`.tmp/output-difference-sl-postfix/{timing-post-cp-f855,timing-final-17d4,downstream-live-17d4,final-byte-equality-17d4}.json`.
The synthetic preset runtime report is
`/tmp/starshine-sl-o4z-runtime-17d4/runtime-results.json`.

## October 9 baseline output differences

At commit `a61c3e418`, the fresh native CLI SHA-256 was
`437cc588c349279875b4bd5ad7a16929e2fb8c97c6199da05d00ba087b201bf5`.
The verified Binaryen 133 oracle SHA-256 was
`8f25e9fd5db0fc5f210003aaa432922feb2e52d309e430def2f929e34da9466b`.
The regenerated 10,000-case `simplify-locals-all` batch at seed `0x5eed`
matched the prior manifest SHA-256
`730983159a3e12d97f85109f6c8e0a497768f8908e4bed31e8f1b2862019dd8d`.
All 4,119 cases in the two families below replayed without command failures.

| Generated family | Cases and source structures | Canonical Starshine / Binaryen bytes | Classification |
| --- | ---: | ---: | --- |
| `effect-order` | 1,225; four module instruction counts (44, 66, 88, 110) | 334,517 / 347,618; saves 13,101 | Scoped size win |
| `family-coverage` | 2,894; one 140-instruction structure with seed-varying literals | 884,979 / 1,026,785; saves 141,806, or 49 per case | Scoped size and local-operation win |

The [effect-order generator](../../../../../src/validate/gen_valid_ssa.mbt)
has no calls or writes between the moved `global.get`/`drop` and the final
read-only load. The global value is discarded; the fixed loads use offsets
0, 4, 8 and 12 in a memory with at least one page. Starshine removes no-op
instructions and moves that discarded read after the final load without
changing values, effects or traps. The [family-coverage generator](../../../../../src/validate/gen_valid_simplify_locals.mbt)
has a fixed module layout. Its output removes 31 no-ops and six local accesses,
replaces two pure-arm `if` expressions with `select`, and keeps observable
call, memory, global, table and null-trap behavior. The
[pass effect-order guard](../../../../../src/passes/simplify_locals.mbt)
still blocks conflicting effects.

For **every** selected case, temporary copies exported all functions from the
input and both pass outputs.
Binaryen 133 `-O` and `-Oz` then produced byte-identical Starshine and Binaryen
outputs. A three-way Node replay of input, Starshine and Binaryen made 48,027
call comparisons with zero value, trap, import-event, global, memory or table
differences.
The replay covered zero/one numeric arguments and null/non-null references;
it did not activate the `try_table` throwing catch path. A separate forced
out-of-bounds load in an effect-order representative preserved the trap and
state. These results establish the two scoped output wins, not pass-time or
engine-speed gains. Other residual families and raw encoding gaps remain open.

Local evidence: `.tmp/output-difference-sl-inputs/manifest.json`,
`.tmp/output-difference-sl-effect-family/{records,downstream,all-export}.jsonl`,
and `/tmp/sl_runtime_all_result.log`.

Durable baseline totals and tool identities are in the
[October 9 evidence ledger](../../../raw/tooling/2026-10-09-output-differences-v133.json).
Its classifications are review judgments for the stated generated families.

## September 27 follow-up allocation campaign renewal

The [final follow-up report](../../../tooling/tracing-playbook.md#september-27-2026-follow-up-pass-allocation-campaign)
uses native CLI `6610a792ef8d07151ee38bd6c6fbfe82097086e4f50f6dfd3902eecacb00320e`,
verified Binaryen 133, seed `0x5eed`, eight subprocesses and 10,000 cases
per listed aggregate. It supersedes pending renewal for the follow-up
allocation changes and earlier current-baseline wording. New evidence
requires verified v133; older dated results retain their original scope.

| Lane | Aggregate | Canonical / cleanup matches | Residuals | Canonically larger | Star/original matches / blocked |
| --- | --- | ---: | ---: | ---: | ---: |
| `simplify-locals` | `simplify-locals-all` | 380 / 0 | 9,620 | 0 | 10,000 / 0 |
| `simplify-locals-notee` | `simplify-locals-notee-all` | 0 / 0 | 10,000 | 0 | 10,000 / 0 |
| `simplify-locals-nonesting` | `simplify-locals-nonesting-all` | 5,026 / 0 | 4,974 | 0 | 10,000 / 0 |
| `simplify-locals-nostructure` | `simplify-locals-nostructure-all` | 0 / 0 | 10,000 | 1,662 | 10,000 / 0 |
| `simplify-locals-notee-nostructure` | `simplify-locals-notee-nostructure-all` | 0 / 0 | 10,000 | 0 | 10,000 / 0 |

Validation, generator, property-counter, command and observed Starshine/
original semantic failures are zero. Blocked runtime cases remain unverified.
The report owns exact commands, normalizers, cache use, size-loss and retained
baseline replays, downstream evidence and agent classifications. Residual
parity/size gaps are not closed by validation or smaller output alone.

Local results: `.tmp/pass-perf-next-20260927/final-fuzz-simplify-locals/result.json`, `.tmp/pass-perf-next-20260927/final-fuzz-simplify-locals-notee/result.json`, `.tmp/pass-perf-next-20260927/final-fuzz-simplify-locals-nonesting/result.json`, `.tmp/pass-perf-next-20260927/final-fuzz-simplify-locals-nostructure/result.json`, `.tmp/pass-perf-next-20260927/final-fuzz-simplify-locals-notee-nostructure/result.json`.

## September 26 final allocation/indexing renewal

The [final shared campaign](../../../tooling/tracing-playbook.md#september-26-2026-pass-time-allocation-and-indexing-renewal)
uses frozen native CLI `da5f112b6bbf092476d2d6ac6694128e19adca3d288003526ab01c3e0b0bfcbb`,
verified Binaryen 133 and 10,000 cases per documented aggregate at seed `0x5eed`.
The shared record owns exact commands, profiles, normalizers, cache counts,
runtime limits and baseline replays. This supersedes earlier current-baseline
wording; historical v131/v132 results keep their original scope.

| Lane | Canonical / cleanup matches | Residuals | Canonically larger | Star/original matches / blocked |
| --- | ---: | ---: | ---: | ---: |
| `simplify-locals` | 380 / 0 | 9,620 | 0 | 10,000 / 0 |

All listed lanes report zero validation, generator or command failures and no
observed Starshine/original semantic mismatches. Cases blocked on the original
input remain unverified.
Residuals remain open parity gaps; canonically larger outputs remain quality
gaps even when cleanup normalization matches. Valid or smaller output alone is not an accepted win. Saved residuals and all canonically larger
cases reproduce the starting compiler bytes, as recorded in the shared replay.

Local reports: `.tmp/pass-perf-work-20260926/final4-fuzz-simplify-locals/result.json`.

Node cannot execute the Binaryen output in 1,829 of the Starshine/original
matches above. The shared audit classifies these as runtime coverage gaps,
not observed wrong results or full three-way agreement.

> **Comparison baseline — September 10, 2026:** new comparisons use [Binaryen 132](../../release-horizon-and-oracles.md). This supersedes older current/latest-baseline wording below. Recorded v131 sources, commands, artifacts and results retain their historical version and do not establish v132 signoff.

## Inserted control and call ordering — 2026-09-11

`simplify-locals-all` now includes `dae2-locals` at weight one. Its new variants
expose a later parameter write moving before an earlier conditional call and a
conditional call moving across an exported-global write. A third variant derives
a pointer from an allocation result before writing its header; it detects a
definition sunk across an older read stored in a later root. They supplement the
35 source-owned family rows with compiler-derived composition cases. Direct
lowering, public pass and command regressions accompany the observable fixtures
in [the runtime lane](../../../../../scripts/test/binaryen132-lifetime-runtime.ts).
Native `766c3e35…` passes 10,000/10,000 `dae2-locals` execution, validation,
determinism and codec checks. The 6,717 output residuals include 4,201 equal-size
cases; an unused lowering scratch declaration is a parity gap, not a measured
win. A red-first declaration-count regression and suffix-only compaction address
that family. Follow-up review identifies the derived-pointer family's adjacent
lowered `local.set`/`local.get` as an equal-size gap: two removed nops merely
cancel the extra local access bytes. A red-first regression now folds that
adjacent pair to `local.tee` after lowering, preserving the allocation's position
and local assignment. Full aggregate renewal remains required; see the
[upgrade status](../../version-132-upgrade.md).

## Binaryen 132 tuple capture regression — 2026-09-11

The renewed `dae2` GenValid aggregate includes private three-result producers,
overlapping lane copy-backs and an observable call counter. Composing DAE2 with
SimplifyLocals exposed a whole-tuple substitution into a scalar read: the reduced
module called its producer three times and returned 207858 instead of one call
and 204567. Scalar local substitution and adjacent-read inlining now require a
single-result source. The captured producer remains shared while ordinary scalar
copy cleanup proceeds. Adjacent tests in `simplify_locals_wbtest.mbt` and
`dead_argument_elimination2_wbtest.mbt` count the producer/consumer calls; the
[independent runtime check](../../../../../scripts/test/binaryen132-lifetime-runtime.ts)
also checks values and effects. All 24 independent lifetime comparisons pass
on fresh native `c447149a…`; the 10,000-case aggregate renewals are running;
this does not close the older size/shape gaps below.

## Tail-call nonfallthrough resultification — 2026-08-20

Native SHA-256 `b536e6105356d6b51dc10c7954047c933159dd46809b7c47566f979198a91093` extends the existing structured tail-local resultification proof to `return_call`, `return_call_indirect`, and `return_call_ref`. These operations cannot fall through, so when the sibling arm ends in the only live local assignment and the next use reads that local, SimplifyLocals can make the `if` result-typed and remove the carrier. Existing type, use-count, typed-control, and branch-owner guards remain unchanged.

Focused SimplifyLocals behavior is 95/95. The typed-function-reference `return_call_ref.0` retained artifact falls 472 → 460 bytes, two bytes smaller than Binaryen, while fresh-instance probes preserve all constant exports, the null `unreachable` trap, factorial accumulator results, count recursion, and even/odd results.

All smoke uses explicit pinned `.tmp/binaryen-version-131-bin/bin/wasm-opt`. Regular `.tmp/pass-fuzz-simplify-locals-final8-regular-1000` compares 1,000/1,000 with 1,000 normalized matches. Dedicated `.tmp/pass-fuzz-simplify-locals-final8-dedicated-1000` compares 1,000/1,000 and reproduces only established stronger Starshine families: every output is 4..56 bytes smaller, aggregate -25,294, with zero failures. Explicit wasm-smith `.tmp/pass-fuzz-simplify-locals-final8-wasm-smith-1000` compares 997/1,000 with 997 normalized matches and three Binaryen command failures. Bounded random-all `.tmp/pass-fuzz-simplify-locals-final8-random-all-100` completes 100/100 with 55 normalized matches and 45 existing cross-pass residuals; zero validation/property/generator/command failures occur, and no residual is attributed to the tail-call classifier.

## Exact loop recurrence carriers — 2026-08-20

Native SHA-256 `316f270a1cb94441c97400931fde91370caa924c9ec1aa8d5f40949230fdf996` adds two exact repeated-loop transforms before the broad unconditional-backedge lifetime bailout. The three-local i32 form carries the third value across at least two identical `local.get seed; local.get second; i32.add; local.tee first; local.get third; i32.add; local.tee second; local.get first; i32.add; local.set third` rounds. The alternating SIMD form carries the old right value across at least two exact shared-constant `v128.bitselect` assignment pairs. Both require distinct locals, preserve every assignment point with tees, preserve operand and effect order, and stop at the first nonmatching round.

Focused behavior is 94/94. `isa_var` falls 507 → 451 bytes with 12/12 runtime checks; `isa_simd_v128` falls 2,188 → 2,126, exact Binaryen size, with 36/36 runtime checks. The full ISA lane remains 1,394/1,394.

All authoritative smoke runs use explicit pinned `.tmp/binaryen-version-131-bin/bin/wasm-opt`; earlier same-day attempts that defaulted to system v116 are discarded. Regular GenValid `.tmp/pass-fuzz-simplify-locals-pass8-recurrences-v131-regular-1000` compared 1,000/1,000 with 1,000 normalized matches and zero failures. Dedicated aggregate `.tmp/pass-fuzz-simplify-locals-pass8-recurrences-v131-profile-1000` compared 1,000/1,000 and reproduced only established stronger Starshine cleanup families: every residual is smaller, ranging 4..56 bytes and totaling -25,294 bytes, with zero command, validation, property, or generator failures. Selected counts were effect-order 126, flat-parent 125, local-traffic 187, structure-result 189, family-coverage 311, and stress 62.

Explicit wasm-smith `.tmp/pass-fuzz-simplify-locals-pass8-recurrences-v131-wasm-smith-1000` compared 997/1,000 with 997 normalized matches, three cached Binaryen command failures, and no mismatches or validation/property/generator failures. Random-all `.tmp/pass-fuzz-simplify-locals-pass8-recurrences-v131-random-all-1000` hit the command timeout after 911 records: 556 normalized matches, 355 existing cross-pass residuals, zero validation/property/generator/command failures, and no residual attributable to either new recurrence family. This partial random lane is development smoke, not closeout evidence.

## Bounded stack-carried local-get refresh — 2026-08-14

Native SHA-256 `fe272853c7194597d2ad1cbe2a2be23727ce2eaca393dfc697a62ea0ee844430` adds exact set/get stackification for 6,144..16,384-instruction functions with at most 64 body locals. The O4z-only late path also admits functions with at most 2,048 instructions once the module has at most 128 definitions; direct pass behavior and larger earlier module shapes remain unchanged. A candidate `local.set X` becomes `local.tee X` and its next `local.get X` becomes `nop` only when the intervening unstructured instruction sequence typechecks independently from an empty operand stack; scanning is bounded to 256 instructions. This preserves the assignment, producer timing, effects, and traps while proving that no intervening instruction consumes the carried value. Older operand-stack values, structured control, local rewrites, escapes, and longer spans fail closed.

Regular GenValid at `.tmp/pass-fuzz-simplify-locals-small-o4z-regular-v131-10000` compared `10000/10000` with `10000` normalized matches and zero failures against explicit verified Binaryen v131. The resumed dedicated aggregate at `.tmp/pass-fuzz-simplify-locals-small-o4z-profile-v131-10000` compared all `10000`: `5000` normalized matches and the established `5000` generated structural residuals, with zero validation, property, generator, or command failures. The small-function admission is O4z-level-gated, so direct compare behavior is intentionally unchanged. A focused Node runtime fixture preserves an out-of-bounds load trap before a global-mutating call and, after memory growth, returns the same value and global state before and after transformation.

## Commutative SIMD carrier refresh — 2026-08-14

The bounded `v128.xor` / `i32x4.add` carrier-forwarding slice used the current native release CLI and verified Binaryen-v131 oracle. Regular GenValid at `.tmp/pass-fuzz-simplify-locals-simd-carrier-regular-10000` compared `10000/10000` with `10000` normalized matches and zero mismatches, validation/property/generator failures, or command failures.

The dedicated aggregate at `.tmp/pass-fuzz-simplify-locals-simd-carrier-profile-10000` requested `10000`, compared `6875`, and retained the known profile distribution: `5000` normalized matches, `1875` existing `simplify-locals-structure-result` residuals, and `3125` Binaryen command failures on `simplify-locals-family-coverage`. It had zero validation, property, and generator failures. Selected counts were effect-order `1250`, flat-parent `1250`, local-traffic `1875`, structure-result `1875`, family-coverage `3125`, and stress `625`. No new comparable mismatch family is attributable to the SIMD carrier rewrite.

The loop-order follow-up, which runs the same exact SIMD rewrites before the broad loop-carried fallback, refreshed regular GenValid at `.tmp/pass-fuzz-simplify-locals-loop-simd-pre-guard-regular-10000` with `10000/10000` normalized matches and no failures. Its aggregate at `.tmp/pass-fuzz-simplify-locals-loop-simd-pre-guard-profile-10000` reproduced the same `5000` matches, `1875` structure-result residuals, and `3125` Binaryen family-coverage command failures, again with zero validation/property/generator failures.

## Guarded SIMD rotate probe — 2026-08-13

After adding the full-pass raw rewrite for complementary split `i32x4` rotate temporaries, a 1,000-case `simplify-locals-all` probe used the explicit native release CLI and verified Binaryen-v131 oracle. It requested `1000`, compared `689`, and reported `500` normalized matches plus `189` residuals, with zero validation, property, and generator failures. The `311` command failures were Binaryen failures on every selected `simplify-locals-family-coverage` case.

All `189` comparable residuals selected the pre-existing `simplify-locals-structure-result` family and were 2..4 canonical bytes larger in Starshine, aggregate `+571`. No new residual family was attributable to the SIMD rewrite. This is focused development evidence only; it does not replace the required four-lane closeout matrix or reclassify the known structure-result debt as acceptable.

Artifacts: `.tmp/pass-fuzz-simplify-locals-simd-rewrite-1000`.

## Live-out repair refresh — 2026-08-12

Native SHA-256 `443fa73acbe3789b0e1b330fdf28652fe5f567c4e6df53470e46217b65b92d47` ran the dedicated `simplify-locals-all` aggregate against the verified Binaryen-v131 oracle at `.tmp/pass-fuzz-simplify-locals-liveout-final-443fa73-dedicated-10000-v131-20260812`. The lane compared `10000/10000`: `5000` normalized matches and `5000` deterministic structural residuals, with zero validation, property, generator, or command failures.

Agent inspection classifies the residuals as two existing generated shape families, not failures attributed by the harness:

- `3125` `simplify-locals-family-coverage` cases are fourteen canonical bytes smaller in Starshine, aggregate `-43,750`.
- `1875` `simplify-locals-structure-result` cases are `2..4` canonical bytes larger in Starshine, aggregate `+5,615`, because Starshine retains one generated `nop` per function around the result-structure/drop shape.

The net canonical residual delta is `-38,135` bytes. The second family is output-shape debt and is **not** an approved Starshine win: the outputs validate and the shape was present in the prior aggregate, but Starshine is larger and should align to Binaryen unless a future measured benefit proves otherwise. This refresh followed the structured-child live-out repair for the late SGO-owned SimplifyLocals wave; it does not replace the earlier five-variant renewal or claim runtime coverage for generated inputs.

## Binaryen-v131 profile refresh — 2026-07-27

All lanes used official `wasm-opt version 131 (version_131)` and the explicit native release binary `_build/native/release/build/cmd/cmd.exe` (SHA-256 `5935985cb02530a77aba751dd88f0103a3eadc6ada8e4a0c0b040c878ba4e5bf`).

| Variant | Refreshed aggregate (`10000`, seed `0x5eed`) | Canonical size classification | Idempotence (`1000`, seed `0x1d3a`) |
| --- | --- | --- | --- |
| `simplify-locals` | `7298` exact, `2702` differences | all smaller, `-8..-4` bytes | `1000/1000` |
| `simplify-locals-notee` | `2766` exact, `7234` differences | all smaller, `-54..-4` bytes | `1000/1000` |
| `simplify-locals-nostructure` | `7115` exact, `2885` differences | all smaller, `-12..-8` bytes | `1000/1000` |
| `simplify-locals-notee-nostructure` | `2766` exact, `7234` differences | all smaller, `-54..-10` bytes | `1000/1000` |
| `simplify-locals-nonesting` | `7684` exact, `2316` differences | all smaller, `-6..-2` bytes | `1000/1000` |

Every aggregate completed `10000/10000` comparisons with zero validation, property, generator, or command failures. The no-structure count intentionally supersedes the older exact-profile result: Starshine now removes pure `local.get; drop` observations and the local writes that become dead, preserving effects and validity while saving bytes.

The full-pass random-all regression corpus was also replayed against every one of its prior `2433` mismatches. `81` now match exactly; the remaining `2352` contain `2262` smaller and `90` equal-size Starshine outputs, with zero larger outputs, validation failures, property failures, or command failures. This replay specifically closes the former `175` size-losing cases and the later narrowed `63` cases.

The broad aggregate profiles exercise every pre-existing registered leaf. The July 28 follow-up adds a deterministic `simplify-locals-family-coverage` leaf for the source-owned `SL-01` through `SL-35` inventory and includes it in all five aggregates. New focused binary-path tests retain the discovered return-suffix and branch-result carrier witnesses.

## Deterministic source-family coverage — 2026-07-28

The `simplify-locals-family-coverage` leaf emits one dense valid module spanning all 35 source-owned transform rows. It covers repeated-local cycles, structured carriers, no-tee/no-structure policy, effects, `try_table`, transparent copy chains, and nondefaultable references. The follow-up repairs structure formation in walker postorder, preserve Hot IR value/label ownership, lower payload-bearing `br_if` statements without spill locals, restore aggregate first-cycle deferral, distinguish direct copies from refined fallthrough equivalence, and keep variant gates explicit.

This deterministic leaf complements the larger 10,000-case aggregate and measured-win evidence above: it is a reproducible interaction probe, while the broad lanes remain authoritative for the integrated pass's stronger pure-drop and dead-local cleanup classifications.

The post-rebase integrated native binary completed five fresh 100-case lanes with zero validation, property, generator, or command failures:

| Variant | Result | Classification |
| --- | --- | --- |
| `simplify-locals` | `100/100` differences, uniformly `-14` encoded bytes | measured stronger dead-local/pure-drop cleanup |
| `simplify-locals-notee` | `100/100` differences, uniformly `-1` encoded byte | measured dead aggregate-copy observation cleanup |
| `simplify-locals-nostructure` | `100/100` differences, uniformly `-3` encoded bytes | measured transparent-copy/pure-drop cleanup |
| `simplify-locals-notee-nostructure` | `100/100` exact normalized matches | exact |
| `simplify-locals-nonesting` | `100/100` exact normalized matches | exact |

The three differing lanes retain effects and trap order while deleting only local carrier traffic or pure dropped reads. They are the same measured-win policy already established by the larger v131 aggregate and random-all evidence, not new parity gaps. Artifacts are `.tmp/pass-fuzz-simplify-locals-v131-family-post-rebase-final-100`, `.tmp/pass-fuzz-simplify-locals-notee-v131-family-post-rebase-final-100`, `.tmp/pass-fuzz-simplify-locals-nostructure-v131-family-post-rebase-final-100`, `.tmp/pass-fuzz-simplify-locals-notee-nostructure-v131-family-post-rebase-100`, and `.tmp/pass-fuzz-simplify-locals-nonesting-v131-family-post-rebase-100`.

## Canonical aggregate profiles

Every Binaryen public variant now has a direct aggregate GenValid name:

| Pass | Aggregate profile |
| --- | --- |
| `simplify-locals` | `simplify-locals` / `simplify-locals-all` |
| `simplify-locals-notee` | `simplify-locals-notee` / `simplify-locals-notee-all` |
| `simplify-locals-nostructure` | `simplify-locals-nostructure` / `simplify-locals-nostructure-all` |
| `simplify-locals-notee-nostructure` | `simplify-locals-notee-nostructure` / `simplify-locals-notee-nostructure-all` |
| `simplify-locals-nonesting` | `simplify-locals-nonesting` / `simplify-locals-nonesting-all` |

Compatibility pass spellings resolve to their canonical aggregate where applicable.

## Shared family leaves

The four newly covered aggregates select from:

- `simplify-locals-local-traffic`;
- `simplify-locals-structure-result`;
- `simplify-locals-flat-parent`;
- `simplify-locals-effect-order`;
- `simplify-locals-stress`.

The established no-structure aggregate retains its existing straight-line, tee-control, and effect-order leaves for replay continuity.

The body generator now emits dedicated structure-result and nonesting parent-position slices instead of falling through to the broad SSA matrix. Effect/stress leaves deliberately keep memory and global barriers while excluding random calls, function-result tails, and table/reference/tag shapes that obscured the intended pass family or exceeded the installed Binaryen oracle's decoding surface. Call barriers remain covered by focused tests and the regular generator lane.

## Red-first evidence

The aggregate/profile test was added before the constructors and failed to compile for all nine new leaf/aggregate constructors. After implementation, `gen_valid_tests.mbt` passes `150/150` and proves canonical resolution, composite membership, and feature envelopes.

## Initial profile audit

The first profile-backed compare runs successfully generated valid modules and removed the earlier generic-profile validation/unsupported-heap failures. They also exposed real residual families rather than being declared green:

- structure-enabled output-shape differences around redundant arm blocks/nops;
- effect-order gaps where Binaryen moves or clones local carriers across read-only loads and later consumers;
- no-tee fresh-local spill differences on repeated-local flat-parent shapes;
- dead effectful local-write cleanup differences in nonesting;
- one no-structure canonical wrapper difference.

The profile was then narrowed to void, family-owned bodies and rerun with Node runtime execution. Across five 100-case canonical lanes, every residual mismatch was strictly smaller in canonical Starshine wasm, with zero runtime semantic mismatches. The residual families are therefore classified as measured Starshine wins for these leaves: redundant structure-arm block/nop removal and stronger dead local-write cleanup that preserves effect/trap execution as `drop`. The no-structure lane reached raw parity on one 100-case run and had one `-3` byte Starshine-win cleanup on the independent runtime run.

## Smoke command

```text
moon build --target native --release src/cmd
bun fuzz compare-pass --pass <canonical-pass> --count 1000 --seed <seed> \
  --gen-valid-profile <canonical-pass> --jobs auto \
  --starshine-bin _build/native/release/build/cmd/cmd.exe \
  --out-dir .tmp/pass-fuzz-<canonical-pass>-profile-1000
```

## Final 2026-07-17 closeout

All commands used the explicit native release binary, `--jobs auto`, default caches, and the required seeds.

| Variant | Regular GenValid (`100000`, `0x5eed`) | wasm-smith (`10000`, `0x5eed`) | Dedicated (`10000`, `0x5eed`) | Random all profiles (`10000`, `0x5555`) |
| --- | --- | --- | --- | --- |
| full | `100000` matches | `6718/6719`, `1` measured win | `7298` matches, `2702` measured wins | `5915/8983`, `3068` classified differences |
| no-tee | `100000` matches | `6718/6719`, `1` measured win | `2766` matches, `7234` measured wins | `5915/8983`, `3068` classified differences |
| no-structure | `100000` matches | `6718/6719`, `1` measured win | `10000` matches | `7160/8983`, `1823` classified differences |
| no-tee/no-structure | `100000` matches | `6718/6719`, `1` measured win | `4572` matches, `5428` measured wins | `6215/8983`, `2768` classified differences |
| nonesting | `100000` matches | `6719/6719` matches | `7684` matches, `2316` measured wins | `8018/8983`, `965` classified differences |

Every lane had zero validation, property, generator, and Starshine command failures. The wasm-smith lane's shared `3281` command failures were Binaryen/tool decode failures: `2967` generic parser failures, `226` bad-section-size failures, `39` empty-rec-group failures, `48` table-index failures, and `1` invalid-type-index failure. Random-all's shared `1017` failures were Binaryen parser rejection of `coverage-forced-portable` table encodings.

Dedicated-profile selected-leaf counts were nonzero for every member. Full and no-tee selected `2766/1770/2702/1863/899` local-traffic/effect/structure/flat/stress cases; no-structure selected `4290/2885/2825`; no-tee/no-structure selected `2766/1770/1806/2759/899`; nonesting selected `3107/1523/1546/3031/793` local/effect/structure/flat/stress cases.

### Residual classification

No residual is a true semantic mismatch or an unmeasured size regression.

- Dedicated residuals are strictly smaller Starshine outputs. They remove redundant result-arm blocks/nops, clone only proven constants in nesting-enabled no-tee modes, and replace zero-read effectful writes with effect/trap-preserving drops.
- Random-all residuals are confined to deterministic SSA, coalesce-locals, and local-subtyping leaves. Starshine is strictly smaller except full `ssa-nomerge-parity`, where canonical sizes are equal; that family has `43` Starshine IR nodes versus `45` Binaryen nodes and converges to equal `-Oz` (`35` bytes) and vacuum-cleaned (`122` bytes) output.
- The one comparable wasm-smith residual removes an unreachable result block while preserving the same `memory.size`, constant evaluation, and final trap; Starshine is `5` bytes smaller.
- Five independent 100-case Node lanes reported zero runtime semantic mismatches. Final idempotence lanes compared `1000/1000` cases per variant with zero property failures.

### O4z neighborhood and rerun proof

The exact `flatten -> simplify-locals-notee-nostructure -> local-cse` neighborhood completed both ordinary and pass-owned `10000`-case lanes. The ordinary lane had `4200` raw matches and `5800` strictly smaller Starshine outputs (`-510..-123` bytes). The dedicated lane had `10000` strictly smaller Starshine outputs (`-48..-4` bytes). The per-variant idempotence lanes prove the shared implementation reaches the same fixed point when rerun.

### Timing

Representative pass-local timings meet the repository's `Starshine <= 2 * Binaryen` target using medians where microsecond noise was material: full about `1.75x`, no-tee about `1.98x`, no-structure `0.82x`, no-tee/no-structure about `1.53x`, and nonesting about `1.11x`. Whole-command Starshine time was faster in every timing replay.

The family is closed under the current behavior-parity contract. Reopen only for a new source-owned transform family, a true semantic mismatch, a validation failure, or a measured output/performance regression.
