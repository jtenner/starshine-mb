---
kind: entity
status: working
last_reviewed: 2026-09-29
sources:
  - ../../../../../src/ir/hot_mutate.mbt
  - ../../../../../src/ir/catch_payload_preflight_wbtest.mbt
  - https://github.com/WebAssembly/binaryen/blob/version_133/src/passes/DeadArgumentElimination2.cpp
  - ../../../../../src/passes/dae2_module_env_wbtest.mbt
  - ../../../../../src/passes/lower_capture_cleanup.mbt
  - https://github.com/WebAssembly/binaryen/blob/version_132/src/passes/DeadArgumentElimination2.cpp
  - https://github.com/WebAssembly/binaryen/pull/8903
  - https://github.com/WebAssembly/binaryen/pull/8994
  - ../../../../../src/passes/dead_argument_elimination2.mbt
  - ../../../../../src/passes/dae2_repeated_solve_perf_wbtest.mbt
  - ../../../../../src/passes/dead_argument_elimination2_types.mbt
  - ../../../../../src/passes/dead_argument_elimination2_legacy.mbt
  - ../../../../../src/passes/dead_argument_elimination2_wbtest.mbt
  - ../../../../../src/passes/dead_argument_elimination2_intake_wbtest.mbt
related:
  - ./index.md
  - ./fuzzing.md
  - ../../version-132-upgrade.md
---

# Starshine DAE2 implementation

## September 29, 2026 packed CFG segment storage

Private CFG segment metadata now occupies three consecutive integers per row
instead of one heap record per segment. A value record decodes rows only when
all fields are needed; the next-block and entry queries read just the block ID.
Public CFG blocks, root mappings, source ordering and segmentation decisions
are unchanged. The primitive backing array also avoids the previously rejected
native debug compiler limitation for arrays of custom value records.

The [three bounded guards](../../../../../src/ir/cfg_segment_storage_wbtest.mbt)
cover empty/growing storage, exact ordered fields and complete block/root
mappings against a frozen boxed reference in both operand modes. The initial
arena/API tests fail to compile before the implementation because the private
API is absent; this is not a preexisting semantic failure. The structural
comparison passes before and after. Eight [native controls](../../../../../src/ir/cfg_segment_storage_perf_wbtest.mbt)
include growth/consumption or fresh builder/source-fact/segment construction:

| Control | Boxed → packed mean |
| --- | --- |
| 128 metadata rows | 1.14µs → 488.32ns |
| 1024 metadata rows | 8.74 → 3.12µs |
| 64 segments, region construction | 48.30 → 47.11µs |
| 512 segments, region construction | 389.75 → 374.13µs |

Three alternating v13→v15 pairs give near-flat compiler timings: large DAE2
**4510.768 → 4542.607ms (+0.71%)**, MAD 25.722/20.813ms; optimizing
**7585.983 → 7544.887ms (−0.54%)**, MAD 11.476/12.469ms. Small medians
are 4.264 → 4.278ms / 11.470 → 11.418ms; tee medians are
3.866 → 3.864ms / 106.370 → 105.713ms. Active joined-reader medians
are 20.772 → 21.071ms / 31.773 → 31.361ms; pure-tail medians are
14.080 → 14.276ms / 13.786 → 14.121ms. Preserve those control costs and
the pure-tail reference-drift retry; no full-pass speedup is established.
Managed process visibility does not establish quiet-host timing.

The reason to retain this slice is measured heap churn: dependency-only
incoming `mi_malloc` calls fall **41,287,576 → 40,796,729 (490,847 fewer,
1.19%)** and `mi_free` calls fall by the same count. Instructions fall
20,329,087,979 → 20,310,625,985 (0.09%). Small whole-command allocator
requests/frees fall by 248 in each pass; instructions change
80,558,748 → 80,550,362 / 172,281,532 → 172,289,872. These scopes count
calls, not allocation bytes or net live objects. Three alternating untraced
large RSS samples give plain medians 272,216 → 253,328 KiB (ranges
252,140–273,244 / 251,280–273,772) and optimizing 292,024 → 299,264 KiB
(ranges 289,788–313,424 / 292,144–300,008). Preserve the latter cost;
overlapping ranges do not prove a memory gain or regression.

Info/fmt, all **12,936 default wasm-gc tests**, native debug guards, release CLI
build and eight controls pass. The frozen binaries preserve every measured
output byte and pass independent validation, the 126-module / 1,029-observation
replay and both seven-module / 28-observation active replays against original
and verified v133. No public interface changes.

Fresh verified-v133 pass-local medians (one warmup, three samples) remain gaps:
small DAE2 4.653 / 1.02914ms (**4.52×**), optimizing 13.213 / 3.20605ms
(**4.12×**); large DAE2 4507.166 / 523.992ms (**8.60×**), optimizing
8534.009 / 1764.800ms (**4.84×**). MADs are 0.119/0.01865ms,
0.459/0.01736ms, 17.027/1.136ms and 52.358/5.520ms respectively.
These are a new oracle cohort, not a causal ratio improvement over v13.
Large canonical sizes remain 6,132,389 / 6,232,586 bytes for plain DAE2 and
5,995,920 / 5,573,450 for optimizing; the **422,470-byte optimizing parity
gap remains open**, and smaller plain output alone is not a proven win.

Local evidence under `.tmp/dae2-lean-20260929/` uses `v15`, including the
source manifest, validation/bench logs, `pairs-v15-*`, active replay folders,
`dependency-cost-v15.json`, `small-instructions-v15/`, `memory-v15/` and
`oracle-v15-{small,large}/`. Frozen candidate SHA-256 is
`7c48e6c9c62c2d3ad5278008cb05f42f73813094d5195519914466ed68b9493e`;
before is accepted v13 `a367397e0045ee3db4cc3711135edab4b1449cca2647cb0f202f684fc14360ab`.
The oracle is verified `wasm-opt version 133 (version_133)`, SHA-256
`8f25e9fd5db0fc5f210003aaa432922feb2e52d309e430def2f929e34da9466b`;
the pinned large input remains `98189860f95b4eb8464794eb9fab5f9fd8d16942c63a6e31ed9175e7e791cbbd`.
Long aggregate fuzz remains deferred at the user's request.

## September 29, 2026 rejected predecessor-row reuse

Two single-predecessor query trials are removed from production. The first
borrows a completed predecessor's immutable source row when it has no write
to the queried local. The revised version also resolves a sole preceding write
directly and avoids processing its first edge twice on the fallback path.
Both preserve exact source order, overwrite boundaries, exceptional policy,
entry-reaching loops and closed cycles. No retained cache is added.

The [candidate guards](../../../../../src/ir/local_graph_predecessor_cache_wbtest.mbt)
retain the frozen v13 reference and the rejected revised algorithm in white-box
code. Sharing and known-write workspace regressions fail before their respective
implementations; the boundary guard compares both locals and exceptional
policies. The [eight native controls](../../../../../src/ir/local_graph_predecessor_cache_perf_wbtest.mbt)
include cold cache/index/scratch allocation, query each block once and exclude
CFG/fact construction equally. The revised installed candidate measures:

| Query chain | Original → candidate |
| --- | --- |
| 64 read-only blocks | 10.43 → 3.90µs |
| 512 read-only blocks | 83.53 → 29.91µs |
| 64 overwriting blocks | 5.09 → 4.49µs |
| 512 overwriting blocks | 39.87 → 34.09µs |

The first trial's overwrite controls regress 4.90 → 5.82µs / 37.87 → 44.79µs;
the revision removes that helper cost, but neither trial improves the compiler
pipelines. Three alternating v13→v14b pairs measure large DAE2 **4248.864 →
4351.417ms (+2.41%)**, MAD 0.004/18.881ms, and optimizing **7296.766 →
7425.941ms (+1.77%)**, MAD 8.655/67.920ms. The first trial also records
large costs of +1.61%/+0.78%. Preserve those timing observations without
claiming every difference is causal: dependency-only instructions fall only
20,329,087,979 → 20,299,338,150 (−0.15%), and counted allocator requests/frees
fall by only 343 in that window. Active joined-reader and pure-tail pipelines
are near flat for the revision; helper wins do not establish a full-pass win.

Small revised medians are 4.968 → 4.485ms / 11.750 → 11.806ms; tee medians
are 3.706 → 3.728ms / 104.978 → 104.549ms. Small instructions fall
80,559,242 → 80,546,335 / 172,282,363 → 172,264,765, with two fewer allocator
requests/frees in each command. Reference-drift retries and the identical-binary
calibration limit small timing claims. Managed process visibility still does
not establish quiet-host timing. Counts are incoming allocator calls, not
allocated bytes, net live objects or RSS.

Installed v14/v14b prototypes pass 12,932/12,933 default tests, info/fmt,
native build, eight controls and the 126-module / 1,029-observation replay.
Each also passes the two seven-module / 28-observation active replays against
original and verified v133. All measured before/after bytes, traced/untraced
outputs and independent validation match. The production query is restored
exactly to v13; candidate implementations remain confined to dedicated tests.
Rejected binary SHA-256 values are
`092a57cd4f5bcc2870451d4649b5599a7fdfa37fcac2d2d083af0cec48e8c05b`
and `b52ea87e0602f61285f21b21a0f2928a8b8806e227c8001efbf8f94a1b0b3dd1`.
Local evidence under `.tmp/dae2-lean-20260929/` uses `v14`, `v14b`,
`rejected-v14/`, `rejected-v14b/` and `dependency-cost-v14b.json`.
Current production oracle evidence remains the accepted v13 sweep below.
Fuzz remains deferred.

After restoring production, info/fmt, all 12,933 default tests, native build
and the eight candidate-only controls pass. The rebuilt CLI is byte-identical
to v13, so its accepted oracle and runtime evidence still describe production.
Renewed control means are retained in `v14-controls-bench.log`; they do not
alter the installed-prototype pipeline results above.

Direct allocation attribution identifies larger targets: v13 dependency
analysis records 4,927,673 calls from CFG region segmentation to `mi_malloc`,
3,092,437 from preceding-dependency queries, and 1,914,225 from block creation.
The initially recorded “proposal-feature array” interpretation is superseded:
the 5,982,618 calls reach an int-sized generic allocation specialization named
for `ProposalFeature`, but 5,980,331 originate in `Array[Int]` reallocation.
The specialization name does not identify proposal metadata construction.
Upstream growth edges include 979,607 from CFG segmentation, 830,456 from
operand collection variants, and 472,703 from reverse entry-source queries.
These are call edges with potentially folded generic implementations and
wrapper layers, not independent allocation totals. Inspect buffer lifetimes
before adding another cache. Evidence is `allocation-callers-v13.json` and
`array-growth-callers-v13.json`.

## September 29, 2026 pure-subtree dependency pruning

The shared preceding-value collector and indexed minimum query stop at a pure
subtree. Effect masks already include every live child, while these dependency
queries follow subsets of those operands. A zero subtree mask therefore cannot
contain a value with nonzero effects that needs carrying across a statement.
The collector leaves its scratch arrays untouched; the minimum query caches
only the root's no-dependency sentinel. Calls, local-state reads, loads and
numeric traps still follow the existing traversal. No retained cache or new
allocation is introduced.

Two [work-invariant regressions](../../../../../src/ir/hot_source_order_pure_wbtest.mbt)
fail before the change: the old minimum query fills a pure leaf's cache slot,
and collection records all 33 nodes in its touched workspace. Both now pass,
with an additional effect/trap guard matching the original query reference.
Eight [native controls](../../../../../src/ir/hot_source_order_pure_perf_wbtest.mbt)
exclude fact construction and compare balanced 64/512-leaf trees. Collection
improves 2.45µs → 19.67ns / 19.74µs → 19.49ns; minimum queries, including
fresh cache-vector initialization, improve 2.40µs → 51.96ns /
19.37µs → 254.87ns. These are helper controls, not compiler-wide speedups.

Three alternating v11→v13 pairs, with CPU 6 affinity and the independent
precompute-reference bracket, measure the following pipeline medians:

| Input | DAE2 before → after | DAE2-O before → after |
| --- | --- | --- |
| Large compiler | 4683.480 → 4615.983ms (−1.44%) | 8061.194 → 8024.433ms (−0.46%) |
| Small compiler | 4.418 → 4.346ms (−1.63%) | 11.536 → 11.448ms (−0.76%) |
| Active tee | 4.055 → 4.161ms (+2.61%) | 106.419 → 107.161ms (+0.70%) |

Large before/after MADs are 21.715/41.907ms and 57.195/27.438ms. Optimizing
compiler timing is near flat; small/control changes remain limited by the
identical-binary calibration. Managed-sandbox process visibility limits foreign
CPU observation, so empty observations do not establish a quiet host.
Dependency-only Callgrind instructions fall 20,486,620,723 → 20,329,087,979
(−0.77%). Small whole-command instructions fall 80,724,625 → 80,565,783 /
172,455,037 → 172,284,529; allocator request/free calls fall by only 7/9.
Do not interpret those request counts as allocated bytes or peak RSS.

The fresh verified-v133 sweep uses one warmup and three samples:

| Input / pass | Starshine | Binaryen 133 | Ratio |
| --- | ---: | ---: | ---: |
| Small DAE2 | 4.749ms | 0.999ms | 4.75× |
| Small DAE2-O | 14.283ms | 3.295ms | 4.33× |
| Large DAE2 | 4297.268ms | 451.817ms | 9.51× |
| Large DAE2-O | 7739.332ms | 1684.540ms | 4.59× |

Large Starshine/Binaryen MADs are 37.034/6.357ms and 42.177/0.870ms.
These separate cohorts are not a paired v11→v13 oracle-ratio improvement.
Canonical sizes remain 6,132,389/6,232,586 and 5,995,920/5,573,450 bytes;
the optimizing 422,470-byte gap and plain output-shape classification stay open.
The oracle/input hashes are the same verified v133 hashes recorded below;
new oracle evidence is `oracle-v13-{small,large}/`.

Info, fmt, all 12,929 default tests, native CLI build and all eight controls
pass. The fixed replay validates 126 modules with 1,029 matching
original/v133 observations; all measured before/after bytes and traced/untraced
outputs match. Candidate v13 SHA-256 is
`a367397e0045ee3db4cc3711135edab4b1449cca2647cb0f202f684fc14360ab`.
Evidence under `.tmp/dae2-lean-20260929/` uses `pairs-v13-*`,
`callgrind-v13-dependencies`, `small-instructions-v13/`,
`allocator-calls-v13.json`, `pure-red.log` and `validation-v13.json`.
The cumulative section below preserves the earlier directly measured checkpoint;
do not multiply its gains by this cohort's percentages. Fuzz remains deferred.

## September 29, 2026 active pure-tail pipeline benchmark

The [permanent full-pass workload](../../../../../src/passes_perf_long/dae2_pure_tail_perf_test.mbt)
has a private helper with one removable argument, a conditional local write,
32 calls that increment an exported global, and a balanced dropped numeric
tail. Fewer than 64 statement roots exercise direct future-dependency scanning:
previously every preceding call rediscovered the pure tail's operands. The
conditional reaching definitions and actual signature change keep DAE2 analysis
and rewriting active. Balanced trees avoid conflating that repeated work with
deep-stack stress.

The bounded eight-leaf test validates both pass outputs, checks argument removal
and confirms input ownership. All four dedicated native benchmarks pass at
512/8192 leaves: DAE2 means 961.23µs/13.59ms, optimizing means 1.01ms/13.57ms.
Setup validates the output and requires argument removal outside timing; these
standalone means are not before/after improvement percentages. Info/fmt and
the focused default guard pass after the 12,929-test full run recorded above.

A matching 8192-leaf CLI fixture, one warmup and three alternating v11/v13
pairs with the independent reference bracket, measures DAE2 **24.764 →
13.431ms (−45.76%)** and DAE2-O **25.466 → 13.921ms (−45.33%)**. Before/after
MADs are 0.038/0.060ms and 0.091/0.002ms. Before/after bytes, traced/untraced
outputs and validation match. Original, both frozen Starshine binaries and
verified v133 return identical results and exactly 32 writes for four inputs:
seven modules and 28 runtime observations. This scaling gain does not establish
a compiler-artifact speedup; the compiler results remain separately recorded.

Local evidence is `.tmp/dae2-lean-20260929/pure-tail-v13/`,
`pure-tail-{controls,bench,test}.log` and `pure-tail.wat`. Input SHA-256 is
`1ce3aa502916d19fec1f9740965806afa2fb4e633acf9e8105d0eda5a69966f0`.
Both frozen binary and verified oracle hashes are recorded in the surrounding
checkpoints. Production code is unchanged by this benchmark addition; no
aggregate fuzz runs.

## September 29, 2026 cumulative lean checkpoint

A fresh matched comparison uses v1 (the reverse-flow repair) as its baseline,
not the earlier correctness-broken V18 or the roughly 39-second dense solver.
Three alternating pairs, pinned to CPU 6 with an independent frozen precompute
reference, give the following pipeline medians:

| Input | DAE2 before → v11 | DAE2-O before → v11 |
| --- | --- | --- |
| Large compiler | 5403.347 → 4553.645ms (−15.73%) | 8689.363 → 8006.475ms (−7.86%) |
| Small compiler | 4.800 → 4.654ms (−3.04%) | 12.057 → 11.639ms (−3.47%) |
| Active tee | 3.885 → 3.930ms (+1.16%) | 111.039 → 106.728ms (−3.88%) |

Large before/after MADs are 0.851/183.876ms and 165.795/184.159ms.
All measured bytes match, traced/untraced outputs agree, and outputs validate.
Reference-drift retries are retained. Eleven of twelve accepted large runs
record foreign Chrome/kernel CPU activity, so this is not a quiet-host signoff;
the small differences also remain limited by the identical-binary calibration.
These cumulative figures are measured directly, not products of percentages from separate optimization cohorts.

A separate fresh **verified Binaryen 133** sweep, one warmup and three samples,
uses the same frozen v11 binary. Its pass-local pipeline medians are:

| Input / pass | Starshine | Binaryen 133 | Ratio |
| --- | ---: | ---: | ---: |
| Small DAE2 | 4.827ms | 1.036ms | 4.66× |
| Small DAE2-O | 14.155ms | 3.315ms | 4.27× |
| Large DAE2 | 4671.195ms | 458.548ms | 10.19× |
| Large DAE2-O | 8281.950ms | 1802.110ms | 4.60× |

Starshine/Binaryen large MADs are 38.016/5.873ms and 26.839/67.390ms.
The compiler performance target remains open. Canonical large output sizes are
6,132,389/6,232,586 bytes for DAE2 and 5,995,920/5,573,450 bytes for DAE2-O.
The optimizing size gap is 422,470 bytes; the smaller plain output alone does
not prove a Starshine win or close the output-shape parity investigation.
No output-shape difference is newly accepted by these performance measurements.

Local evidence is `.tmp/dae2-lean-20260929/cumulative-v11-{small,large,tee}/`
and `oracle-v11-{small,large}/`. V1 SHA-256 is
`a612ebefc2f7d54085530d22d88d2565861d26e4753b64e9660b282999a18fc3`;
v11 SHA-256 is
`c43278a2cf8ced917ccdcc21d3d2cfd216c75d182ac336126fb6b9e10482248b`.
The oracle is `wasm-opt version 133 (version_133)`, SHA-256
`8f25e9fd5db0fc5f210003aaa432922feb2e52d309e430def2f929e34da9466b`.
The large input SHA-256 remains
`98189860f95b4eb8464794eb9fab5f9fd8d16942c63a6e31ed9175e7e791cbbd`.
The dependency-only Callgrind profile falls from **26,495,753,239 instructions
at v2 to 20,486,620,723 at v11 (−22.68%)**, with byte-identical validated output.
This baseline already includes the direct tuple-opcode improvement; it differs
from the v1 timing baseline above. It counts the analysis dependency function,
not the whole compiler command. Remaining nonrecursive inclusive costs are
CFG construction 62.12% and LocalGraph 23.94%; source-order dependency
queries account for 19.04% inside CFG construction. These nested percentages
must not be added. Largest self costs include HOT node reads 13.35%, reverse
entry queries 7.06%, object destruction 6.61% and liveness reads 3.96%.
The source-order query total is essentially unchanged from v2, making repeated
region scans a useful next target. Profiles are `profile-v11-{self,inclusive}.txt`
and `callgrind-v11-dependencies`; v2 retains the earlier equivalent scope.

Whole-command small-input Callgrind controls compare v1/v11. DAE2 instructions
fall 85,690,018 → 80,721,030 (−5.80%); optimizing instructions fall
178,863,157 → 172,466,407 (−3.58%). Counted calls into `mi_malloc` fall
325,973 → 312,090 and 512,453 → 492,159 (13,883 and 20,294 fewer requests).
The corresponding frees fall by the same counts. These are native allocator
call counts, not allocated bytes or a claim about peak memory.

Three alternating large-input RSS samples overlap: DAE2 median 282,308 →
281,308 KiB, ranges 255,884–283,288 / 259,160–281,808; DAE2-O median
292,356 → 302,336 KiB, ranges 292,024–314,784 / 291,804–304,696. Retain the
higher optimizing median without claiming a proven memory regression or win.
The initial RSS launcher found no `/usr/bin/time`; its setup error is preserved,
and completed samples use a fresh Python child wrapper's Linux `ru_maxrss`.
Evidence is `memory-v11/`, `small-instructions-v11/` and `allocator-calls-v11.json`.
All corresponding outputs validate and retain exact before/after bytes.

This is bounded performance/correctness evidence; aggregate fuzz remains
explicitly deferred until the performance trials finish.

## September 29, 2026 rejected smaller-region index threshold

A 64 → 32 root-index threshold trial is removed. The existing index algorithm
is valid on small regions, but the measured compiler inputs show no pipeline
benefit. Three alternating pairs measure large DAE2/O 4349.487 → 4404.810ms
(+1.27%) / 7460.982 → 7517.513ms (+0.76%). Small medians are 4.241 →
4.870ms (+14.83%) / 11.727 → 11.892ms (+1.41%); active tee medians are
3.924 → 3.928ms / 108.375 → 107.433ms. Preserve these timing observations
without claiming all differences are causal: small instruction and allocator
counts are essentially identical, and prior calibration demonstrates timing
variation. Small instructions are 80,724,150 → 80,722,900 /
172,465,174 → 172,463,564; allocator request counts are unchanged.

The [suffix-query controls](../../../../../src/ir/hot_source_order_threshold_perf_wbtest.mbt)
include facts/index construction and compare direct/indexed queries at 4/16/32
roots. Their repeated-barrier pattern is a kernel workload. The additional
[region controls](../../../../../src/ir/hot_source_order_region_perf_wbtest.mbt)
query each actual effectful root once, with the real changing cutoff and suffix.
At 32 roots sparse regions improve 13.25 → 7.58µs, but dense regions cost
16.74 → 17.64µs (+5.38%). At 16 roots they measure 4.38 → 3.51µs and
5.72 → 6.12µs. These synthetic tradeoffs do not establish a compiler win.

The [bounded index guards](../../../../../src/ir/hot_source_order_threshold_wbtest.mbt)
retain equality across every suffix for sparse/dense 4/16/32-root regions, and
check the 32-root candidate set directly. The prototype's threshold-admission
regression was red first; after rejection its admission assertion becomes a
direct index-algorithm guard. The shipping threshold remains 64. No existing
feature or supported index algorithm is removed.

While the prototype was installed, info/fmt, 12,926 default tests, native build,
12 kernel controls, eight actual-region controls, and the 126-module /
1,029-observation original/v133 replay pass with identical output bytes.
The interrupted paired run was resumed by checking binary/input/reference
hashes and completed sample artifacts, retaining partial evidence and avoiding
re-measurement of completed pairs. Later managed-sandbox process visibility
limits foreign-CPU detection; an empty observation does not prove a quiet host.
Local evidence uses `v12`, `region-*`, `threshold-*` and `rejected-v12/` under
`.tmp/dae2-lean-20260929/`. Rejected candidate SHA-256 is
`6c698eb8a86eb8fa250a0562944ad547fe3c7f8e547fa879f0c255de6adc2798`.
Its completed v133 sweep remains saved under `oracle-v12-{small,large}/`;
the accepted production oracle at that checkpoint was v11, now superseded
by the v13 sweep above.
Fuzz remains deferred.

## September 29, 2026 fuse source-order operand walks

Source-order facts now compute maximum value order and first external-effect
order in one operand traversal. The two existing result arrays retain their
sentinels and discovery order; no cache is added. The standalone first-effect
query remains separate for consumers that need only that summary. The old
value-only traversal survives only as a test reference.

The [bounded guard](../../../../../src/ir/hot_source_order_fused_wbtest.mbt)
compares both arrays before and after on calls, stacked writes, indexed control,
loads and deleted nodes. Six [native controls](../../../../../src/ir/hot_source_order_fused_perf_wbtest.mbt)
compare full fact construction with the original two-walk reference. A repeated
low-variance cohort measures 8/64/128 roots at 19.58 → 15.79µs /
153.10 → 124.40µs / 340.18 → 246.32µs. The first noisy timing cohort is
preserved, but does not support the helper claim.

Three alternating pairs measure large DAE2 **4779.348 → 4589.724ms (−3.97%)**,
MAD 61.700/67.940ms, and DAE2-O **7924.408 → 7826.148ms (−1.24%)**,
MAD 19.823/44.409ms. Ten of twelve accepted large runs record foreign CPU
activity; preserve that limit alongside the helper and instruction evidence.
Small medians are 4.736 → 4.541ms /
12.252 → 12.391ms; active tee medians are 3.778 → 3.888ms /
106.876 → 105.483ms. Small changes remain subject to the calibration limits;
these results do not establish Binaryen competitiveness.

Info, fmt, 12,923 default tests, native build and all six controls pass. The
126-module / 1,029-observation original/v133 replay and before/after artifact
bytes match. Candidate SHA-256 is
`c43278a2cf8ced917ccdcc21d3d2cfd216c75d182ac336126fb6b9e10482248b`.
Local evidence under `.tmp/dae2-lean-20260929/` uses `v11`; the repeated
controls are in `controls-order-repeat.log`. No aggregate fuzz ran.

## September 29, 2026 borrow completed reverse-query rows

Reverse-flow query cache entries are immutable after collection. Cache insertion
and lookup now share the completed source row instead of copying it. Unique
reverse recording borrows the row; iterative recording keeps its existing
copy-on-write merge. Public owned queries still return independent arrays.
The [ownership regression](../../../../../src/ir/local_graph_source_cache_wbtest.mbt)
first failed because the returned row differed physically from the cache; it
now checks both cache sharing and isolation of a later merge.

The [full graph controls](../../../../../src/ir/local_graph_source_cache_perf_wbtest.mbt)
measure repeated entry-source reads in one block. At 128/512/2048 reads they
improve 13.06 → 10.94µs / 49.33 → 41.23µs / 194.82 → 162.59µs (about 16.5%).
Paired large DAE2 is flat at 4736.866 → 4732.602ms, MAD 16.009/13.716ms;
DAE2-O measures 7938.411 → 7812.697ms (−1.58%), MAD 92.021/1.483ms.
Small medians are 4.362 → 4.422ms / 11.594 → 11.633ms; active tee medians
are 4.582 → 3.963ms / 106.764 → 109.645ms. Preserve the +2.70% optimizing
tee observation and the timing-calibration limits rather than claiming a win
on every input.

Info, fmt, 12,923 default tests, native build, three cache benchmarks and six
next-stage order controls pass. The 126-module / 1,029-observation original/v133
replay and artifact byte checks pass. Candidate SHA-256 is
`0ca046728397956793707c6e2de24d672bc4ea3bd1ba164c832e8f15a6819fe3`;
local evidence uses `v10` and `cache-borrow-red.log`. The suite includes the
fused-order guard before that optimization. No aggregate fuzz ran.

## September 29, 2026 append unique reverse-flow readers

Reverse flow records each get once with a deduplicated source row. Its recorder
now assigns that row directly and appends each write influence without searching
all earlier readers. Dense/sparse iterative recording retains its merge and
deduplication logic. This removes quadratic reader-list searches and the unused
copy-on-write recorder on the reverse path, without adding an index or cache.

The [bounded guards](../../../../../src/ir/local_graph_unique_reads_wbtest.mbt)
pass before and after for ordered readers, branch-joined writes and shared-read
fallback. [Full graph controls](../../../../../src/ir/local_graph_unique_reads_perf_wbtest.mbt)
at 128/512/2048 readers improve 11.50 → 9.57µs / 68.77 → 32.84µs /
611.87 → 128.49µs. The high-count case is 4.76× faster and scaling is now
approximately linear. This is a graph-construction gain, not a compiler-wide
speedup claim.

An additional active DAE2 workload joins two writes (7 or 9) and consumes the
local 8,192 times in a balanced addition tree. Its private helper also has an
unused argument, which DAE2 removes. The v7/v9 paired full pipelines improve
**51.781 → 22.058ms (−57.40%)** and **64.182 → 32.221ms (−49.80%)** for
DAE2/O, with MADs 0.094/0.035ms and 0.551/0.467ms. Seven original/before/after/
v133 modules validate and return identical values in 28 observations; before/
after bytes match. This is a deliberate scalability workload, separate from the
compiler artifact below. The permanent [active pipeline benchmarks](../../../../../src/passes_perf_long/dae2_joined_readers_perf_test.mbt)
cover 512/8192 readers for both passes, with a bounded default guard proving
argument removal and input ownership. All four native controls and that guard
pass. Final v11 benchmark means are 1.33/21.28ms (DAE2) and 2.05/31.18ms
(DAE2-O); these are standalone controls, not matched improvement estimates.
The subsequent cache-borrowing change is flat on the active 8192-reader input:
21.871 → 22.012ms / 31.555 → 31.495ms, with seven validated modules and 28
matching observations. Local `joined-readers-v9/`, `joined-readers-v10/`, `joined-readers.wat` and
`joined-readers.py` retain it; input SHA-256 is
`60935ce550d11451d4dce59ff319d6ed58633b645496ecf9eac3fdcc62079f86`.

Independent-reference paired medians retain a large DAE2 cost:
4623.318 → 4697.854ms (+1.61%; MAD 78.203/38.001ms). DAE2-O is nearly
flat at 7955.797 → 7918.754ms, MAD 21.181/66.549ms. Small medians are
4.379 → 4.388ms / 11.641 → 11.566ms; active tee medians are
3.819 → 3.788ms / 107.230 → 107.812ms. Preserve the observed costs; the
asymptotic improvement does not close the compiler-artifact gap.

Seven-pair identical-binary controls with the separate reference measure small
DAE2/O variation of −1.08%/−2.61% and tee variation of −0.84%/−0.10%.
The new bracket removes asymmetric reference invocation, but timing noise
remains. These controls limit claims from small differences in later trials.

Info, fmt, 12,921 tests, native build, three reader benchmarks and three next-stage
cache controls pass. The 126-module / 1,029-observation original/v133 replay and
all output byte checks pass. Candidate SHA-256 is
`61a7017554e3ba466f22538b40c7fa90f9629c6c2e3e70ea7239f9b04efb2484`;
local evidence uses `v9` and `calibration-independent-{small,tee}/`. A corrected
runner-path argument error is preserved in `evidence-v9-harness-error.log`;
completed runtime evidence was hash-checked and reused before the successful
paired run. Fuzz remains deferred.

## September 29, 2026 rejected native getter annotation

Adding `#inline` to `hot_node_get` produced an **identical native binary** to
v7: SHA-256 `eeadc7c3e87fdb0a56b31aaf27721f92e97a718cea28ccf5ad6b8ac6ecf20763`,
14,352,728 bytes. The annotation was removed. All 12,921 tests, native build,
12 existing field-query controls and three next-stage reader controls pass;
no native performance benefit can be attributed to this source annotation.

The identical-binary v8 comparison is also a timing calibration: small DAE2/O
appeared +9.85%/+2.50%, large +0.75%/+0.58%, and active tee −0.40%/−2.97%.
These are measurement variation, not code regressions or wins. Preserve earlier
small/control timings as observations, but do not infer a causal improvement
from similarly small differences. Native helper scaling, fixed output/runtime
checks and large gains have separate evidence; sub-percent artifact changes
were already classified as near flat.

The earlier bracket ran `precompute` through the before binary. Subsequent
trials use a separate frozen reference executable for both brackets so neither
candidate receives that asymmetric code-cache warmup. An independent-reference
identical-binary calibration is recorded with subsequent results; this setup
change alone is not proof that all timing noise is eliminated. Local evidence
uses `v8`, `machine-v8.json` and `affinity-pairs-independent.py`. Fuzz remains
deferred.

## September 29, 2026 bounded SSA source summaries

LocalGraph's SSA flag needs only one distinct reaching source and agreement
with every write. It now records unseen/singleton/multiple identities in two
flat local-indexed arrays during one arena scan. This replaces growing unions
with linear membership searches, one heap array per local and a second arena
scan. Finalized nonnegative source IDs remain distinct from the private summary
sentinels; unused writes still invalidate singleton reads when identities differ.

The [bounded guards](../../../../../src/ir/local_graph_ssa_summary_wbtest.mbt)
cover entry values, singleton/multiple writes and unread conflicting writes;
they pass before and after. The [native controls](../../../../../src/ir/local_graph_ssa_summary_perf_wbtest.mbt)
compare the original union with the summary: 16/128/512 writes take
0.643 → 0.266µs / 6.22 → 1.68µs / 48.72 → 6.47µs. This removes the
quadratic union on that workload without claiming a large compiler gain.

Paired large DAE2/O medians are effectively flat at
4553.674 → 4562.817ms / 7615.647 → 7540.545ms; respective MADs are
33.512/51.085ms and 157.977/39.231ms. Small medians are
4.723 → 4.334ms / 11.619 → 11.747ms; active tee medians are
3.791 → 3.985ms (+5.12%) / 106.828 → 106.876ms. Preserve these noisy control
costs. Separate whole-command Callgrind counts on the small input fall
81,849,693 → 81,523,967 / 173,674,540 → 173,343,909 instructions
(−0.40%/−0.19%); active tee counts are essentially unchanged
102,629,320 → 102,633,080 / 2,049,641,510 → 2,049,674,565. Instruction
counts do not establish wall-time improvements or erase the observed costs.

Info, fmt, 12,919 default tests, native build, six controls and the fixed
126-module / 1,029-observation original/v133 replay pass with identical output
bytes. Local evidence has the `v7` suffix, plus `small-instructions-v7/` and
`tee-instructions-v7/`; candidate SHA-256 is
`eeadc7c3e87fdb0a56b31aaf27721f92e97a718cea28ccf5ad6b8ac6ecf20763`.
No aggregate fuzz ran.

## September 29, 2026 reuse CFG region-root snapshots

Expanded CFG construction already snapshots each region's roots for source
ordering. It now reuses that array when visiting roots and registering operand
blocks, removing repeated region/label/type lookups. Root-only construction
registers its already-known roots directly. This adds no cache or allocation.
The [bounded guard](../../../../../src/ir/cfg_root_snapshot_wbtest.mbt) checks
indexed inputs and exact body slots in both modes; it passes before and after.
The [native controls](../../../../../src/ir/cfg_root_snapshot_perf_wbtest.mbt)
measure full CFG construction: 8/64 expanded roots improve 82.75 → 72.05µs /
510.40 → 444.74µs, and 64 root-only roots 148.16 → 141.56µs.

Three alternating large-input pairs measure DAE2 **4663.759 → 4476.399ms
(−4.02%)**, MAD 5.624/7.962ms; DAE2-O is nearly flat at
7496.749 → 7452.244ms (−0.59%), MAD 72.745/17.440ms. Small medians are
4.507 → 4.402ms / 11.804 → 12.231ms; active tee medians are
3.743 → 3.813ms / 106.230 → 107.506ms. Small/control costs and rejected
reference-drift attempts remain recorded; this is chiefly a large DAE2 gain.
Do not combine absolute times from different cohorts as a matched comparison.

Info, fmt, 12,919 default tests, native build and three controls pass. The fixed
126-module / 1,029-observation original/v133 lane has zero behavioral or
before/after byte differences. Local evidence uses the `v6` suffix under
`.tmp/dae2-lean-20260929/`; candidate SHA-256 is
`c14847b66efd69ab8b8be8b7b20b1cb70ff37e270666b9c74ef0dc3506a339a1`.
The suite includes the next SSA trial's guards before its implementation.
Aggregate fuzz remains deferred.

## September 29, 2026 rejected source-order cache trials

Two cache prototypes are **not in production**. A lazy write-presence cache
avoided access-list materialization for read-only carried expressions. It reduced
the 128-deep one-direction control 250.33 → 22.27µs, but the reverse write/read
query still materialized the same trees: a bidirectional control remained
277.07 → 264.98µs. Its large DAE2/O medians were effectively flat
4607.042 → 4614.436ms / 7620.928 → 7566.612ms, with small/tee control costs.

A second prototype cached compact uniform-local identities and earliest-access /
latest-write orders, retaining the original mixed-local scan. It reduced the
bidirectional 128-deep control 279.23 → 26.78µs, but regressed paired small DAE2
4.421 → 4.672ms (+5.68%) and large DAE2 4600.324 → 4673.942ms (+1.60%).
Large DAE2-O was flat at 7659.031 → 7664.762ms; active tee medians were
3.797 → 3.784ms / 106.223 → 105.765ms. These synthetic wins do not justify
keeping the additional per-function cache and real-input costs. Both prototypes
were removed; the accepted production baseline remains v4 at this checkpoint.

The [read-only/dead-tail guards](../../../../../src/ir/hot_source_order_write_free_wbtest.mbt),
[bidirectional/order-bound guards](../../../../../src/ir/hot_source_order_uniform_wbtest.mbt)
and their [one-direction](../../../../../src/ir/hot_source_order_write_free_perf_wbtest.mbt)
/ [bidirectional](../../../../../src/ir/hot_source_order_uniform_perf_wbtest.mbt)
benchmarks remain useful controls. The selected benchmark path always measures
the current implementation; the reference retains the original scan. The
quadratic overlapping-access-list family remains open rather than being hidden
by a helper-only success claim.

The second prototype passed 12,918 default tests, native build and four controls;
both passed the 126-module / 1,029-observation fixed replay with unchanged bytes.
Local `.tmp/dae2-lean-20260929/` evidence uses `v5` and `v5b`; rejected v5b source
is preserved in `rejected-v5b/`. Binary hashes are
`2ad9d25559765dc54f191fb194ba807b8faa4f72d7b97f3996c2028bab13d912` and
`05a93a72a031a2996e3e273720945aeddf4c6d8c2335aeb6a944c67a29c1b5fe`.
This is experimental evidence, not accepted performance or aggregate signoff.

## September 29, 2026 reuse the write-local index

Reverse-flow construction now builds its required node-to-write-local vector
before queries and reuses it for short write scans, lazy block indexes and
transparent-chain admission. It retains the same vector in the finished graph;
there is no additional persistent index. This removes repeated complete HOT
node reads in predecessor queries. The
[bounded lookup guard](../../../../../src/ir/local_graph_write_index_wbtest.mbt)
passes before/after for reads, sets, tees, absent locals and prefix limits;
[native controls](../../../../../src/ir/local_graph_write_index_perf_wbtest.mbt)
compare the old scan and the indexed lookup on the same function. A 512-query
batch improves 6.31 → 3.70µs (−41.36%).

The enclosing effect is modest: three paired large medians are
4324.275 → 4293.496ms for DAE2 (−0.71%; MAD 3.134/13.836ms) and
7115.667 → 7094.366ms for DAE2-O (−0.30%; MAD 35.662/5.471ms).
Small medians are 4.261 → 4.151ms / 11.095 → 11.091ms; active tee medians
are 3.680 → 3.693ms / 103.460 → 102.506ms. These near-flat artifact controls
must not be presented as a major pipeline win. All bytes match; info, fmt,
12,914 default tests, native build, both controls and the fixed 126-module /
1,029-observation original/v133 lane pass. Candidate SHA-256 is
`df13c59e51ff5d011a90083dfd623f6a01d4e9aa473fb631bc1a4519702e5c04`;
local evidence has the `v4` suffix. The additional source-order tests present
in this validation are guards for the following trial, not yet its implementation.
No aggregate fuzz or new competitiveness claim is made.

## September 29, 2026 read-only predecessor chains

Reverse local-flow queries previously walked every intervening read-only block
again for each local. A linear prepass now resolves single-predecessor chains,
stopping at writes and joins. Closed read-only cycles retain one representative;
exceptional-edge selection follows the query policy. The
[bounded graph fixture](../../../../../src/ir/local_graph_transparent_wbtest.mbt)
compares sources with dense flow across chains, joins, reachable loops,
disconnected cycles and exception edges. Source sets pass before and after;
post-change assertions also check the compressed predecessor map.

The existing expanded-flow benchmarks now take 13.69/53.08/102.54µs at
32/128/256 reads, versus 25.92/279.86/1040µs in the earlier v1 cohort. These
helper cohorts differ; the current same-process dense controls are
66.56/867.01/3220µs. Scaling is now approximately linear on this fixture.
Three alternating artifact pairs give large DAE2 4558.704 → 4331.999ms
(−4.97%; MAD 2.407/14.058ms) and DAE2-O 7342.827 → 7083.803ms
(−3.53%; MAD 14.866/18.654ms). Small controls are 4.242 → 4.331ms and
11.376 → 11.057ms; active tee controls are 3.544 → 3.504ms and
104.067 → 106.056ms. Preserve the observed +2.10% small DAE2 and +1.91%
active optimizing costs; this does not establish a win for every workload.

All output bytes match. Full 12,911-test validation, native build, six native
benchmarks and the 126-module / 1,029-observation fixed replay lane pass.
Candidate SHA-256 is
`888b45565e826f0d7cabc51e8a7042fa889b29328302f51ebb6f8136b757e327`;
artifacts use `.tmp/dae2-lean-20260929/` and the `v3` suffix. Fuzz remains deferred.

A fresh dependency-only Callgrind profile of the preceding **v2** binary records
26,495,753,239 instructions with validated, byte-identical large output. Its
nonrecursive inclusive CFG and LocalGraph owners account for 56.38% and 32.81%;
self costs include HOT node reads 15.46%, reverse entry traversal 12.20%, indexed
last-write lookup 5.72%, and object destruction 5.44%. Recursive inclusive
attribution overlaps and must not be added. This is not a whole-command profile
or a timing comparison with v9. The next trials target repeated node decoding
in write lookup and source-order subtree scans; local `profile-v2-{self,inclusive}.txt`
and `callgrind-v2-dependencies` preserve the attribution.

## September 29, 2026 tuple preparation without opcode strings

Shared HOT lowering now tests `HotOp::TupleMake` directly and reads result
metadata only for tuple nodes. Previously it formatted every live opcode into
a temporary string merely to identify that one opcode. The
[bounded type/IR guard](../../../../../src/passes/tuple_prepare_opcode_wbtest.mbt)
passes before and after the change, preserving zero/scalar/multivalue handling,
node counts, type interning and valid HOT output. This is a performance change,
not a newly implemented semantic behavior.

[Native controls](../../../../../src/passes/tuple_prepare_opcode_perf_wbtest.mbt)
compare the original string scan with opcode matching, including fresh function
construction and active multivalue promotion each iteration. At 64/1024 roots,
means fall 31.45 → 6.15µs and 480.45 → 76.75µs; lowered IR and resulting type
sections match the reference. Full validation passes 12,910 default tests,
interface generation, formatting, native CLI build and all four benchmarks.
Frozen binary SHA-256 is
`cb4d1d0054ff4c54d08f95dd2bdc9a4c4c5987e05ac8fad626e1a1f92c1aa385`;
local artifacts use `.tmp/dae2-lean-20260929/` with the `v2` suffix.
Three alternating CPU-affined pairs after a warmup preserve all output bytes:
small DAE2/O medians 4.310 → 4.205ms / 11.295 → 10.921ms; large medians
4752.195 → 4567.170ms / 7575.284 → 7355.966ms (−3.89%/−2.90%). Large
MADs are 1.404/14.403ms and 25.654/17.601ms, respectively. Active tee DAE2
is flat (3.545 → 3.555ms), while DAE2-O improves 109.851 → 104.022ms
(−5.31%). The 126-module fixed runtime lane again validates 1,029 observations
with zero behavioral or byte differences. Rejected reference-drift warmup and
foreign CPU observations remain in local evidence; no aggregate fuzz ran.

## September 29, 2026 expanded-flow performance repair

Expanded operand CFGs now use the existing reverse reaching-definition solver.
Their nodes already represent evaluation order, so action extraction records
local reads/writes directly rather than recursively expanding operands again.
Root-only CFG admission and shared-expression fallback remain intact. The
[red-first regression](../../../../../src/ir/local_graph_expanded_reverse_wbtest.mbt)
first observed duplicate actions `[0,0,1,2,2]` instead of `[0,1,2]`; six bounded
fixtures compare source sets with the dense solver across stacked reads,
loop-carried writes, branches and indexed inputs. The
[native benchmark](../../../../../src/ir/local_graph_expanded_reverse_perf_wbtest.mbt)
compares both solvers at 32/128/256 reads and 128/512/1024 locals.

Three alternating, CPU-affined samples after one warmup give these pipeline
medians in milliseconds (identical before/after wasm bytes, validated outputs):

| Input | DAE2 before → after | DAE2-O before → after |
| --- | ---: | ---: |
| Small | 5.181 → 4.654 | 12.703 → 12.704 |
| Large compiler | 39136.021 → 5092.202 | 38973.233 → 7936.136 |
| Active tee | 3.723 → 3.801 | 106.362 → 106.250 |

Large reductions are 86.99%/79.64%; median absolute deviations are
30.347/73.633ms for DAE2 and 43.095/102.208ms for DAE2-O (before/after).
These repair the dense-flow regression introduced by the source-order
correctness fix: **they are not improvements of that magnitude over historical
V18's 4.17s/7.54s**, whose newly exposed semantic failures remain documented.
A traced large sample reduces dependency analysis 36317.052 → 2074.588ms;
rewrite/lower/validation costs remain. Native 128-read graph construction is
932.16 → 279.86µs, and 256-read construction 3.79 → 1.04ms. Residual scaling
and multi-second artifact costs remain active performance gaps.

`moon info`, `moon fmt`, all 12,909 default tests, native CLI build and six
native benchmarks pass. Eighteen fixed runtime fixtures validate 126 modules
and 1,029 result/effect/trap observations against original inputs and verified
Binaryen v133, with zero mismatches or before/after output changes. This bounded
lane is not aggregate fuzz signoff. Baseline binary SHA-256 is
`5c03b6a93d19e8c90403b7b691f87ebfc94c42eb670052506bfa7cad50a2fbf8`;
candidate is `a612ebefc2f7d54085530d22d88d2565861d26e4753b64e9660b282999a18fc3`.
Local reproducibility artifacts are `.tmp/dae2-lean-20260929/`: source manifests,
`validation-v1.json`, `runtime-v1/result.json`, and `pairs-v1-{small,large,tee}/`.
The pair runner retains rejected reference-drift attempts and foreign CPU
observations; no new v133 timing ratio or memory improvement is claimed.
Fuzz renewal is explicitly deferred until performance work is complete.

## September 29, 2026 branchless scalar blocks and source-order flow

The next candidate admits input-free void/scalar blocks with no branches,
early returns, indexed signatures or other structured control. An iterative
walk flattens their ordered children for the existing symbolic scalar analysis
and direct mutation. Flat analysis retains its original shared instruction row;
block output matches the full-HOT reference exactly. Indexed, tuple, branched,
loop, exception and continuation families retain their complete fallback.
[Red-first block fixtures](../../../../../src/passes/dae2_raw_branchless_blocks_wbtest.mbt)
cover nested results, global effects, writes, load tees, import results, traps
and recursive forwarding in both world modes, with zero analysis/rewrite lifts.
[Native controls](../../../../../src/passes/dae2_raw_branchless_blocks_perf_wbtest.mbt)
compare complete HOT/direct DAE2 at tiny/wide sizes and depths 1/16.

The trials exposed a correctness error in the previous HOT fallback: a read
already on the operand stack could be assigned the definition from a later
block write because the root-only CFG visits its consuming parent later.
An entry read lost its parameter; a read after an earlier write lost that
write. A first-write entry-edge experiment fixed only the former and is
superseded. Demanded LocalGraph now uses expanded operand control, preserving
both actual source families and loop-carried writes. Read-only and proved
entry-write admission still avoid the graph.
[Dependency regressions](../../../../../src/passes/dae2_stacked_block_entry_wbtest.mbt)
first fail on the lost entry parameter and earlier write, then require exact
signatures, retained writes, valid output and owned input. The
[dispatcher](../../../../../src/cmd/dae2_raw_branchless_blocks_wbtest.mbt) checks
both modes. Nineteen focused checks pass; full/native, bounded execution and
artifact cost/size evidence remain under way. Keep this as a release blocker
until runtime replays and final affected aggregate renewal complete.

## September 29, 2026 scalar tees and solved graph transfer

V13 tracks a tee's stack value separately from its local write. Demanded writes
keep their ordered tee/drop shape; unread captures for removed parameters
vanish. The first V13 projection incorrectly retained unread original
body-local tees: the large DAE2 input grew 316 bytes across 86 functions.
V14 projects retention from surviving local.get instructions, matching
`hot_lower_impl_prune_dead_local_tees_in_body` even for reads preceding a later
write. [Red-first capture fixtures](../../../../../src/passes/dae2_raw_tee_captures_wbtest.mbt)
cover unread body locals, earlier reads, overwrites and removed parameters;
the dispatcher fixture also failed before the repair. [Tee fixtures](../../../../../src/passes/dae2_raw_tee_wbtest.mbt) compare
exact full-HOT bytes for stacked entry reads, overwritten definitions, mandatory
loads/calls, removed results and f32/f64 reinterpretation. Both
[dispatcher modes](../../../../../src/cmd/dae2_raw_tee_wbtest.mbt) retain discarded
import effects. The initial two tests failed with a second rewrite lift; the
combined tee/storage slice now passes seventeen focused checks.

V12 drops solved module adjacency before rewrite but requires mutable graph
fields. V13 instead transfers the same solved bitvector into a fresh empty
graph, so the owned analysis graph dies without adding mutable-field reference
work to every edge. [Transfer tests](../../../../../src/passes/dae2_solved_transfer_wbtest.mbt)
require shared solved values, zero new edge capacity and unchanged borrowed
storage. [Matched graph controls](../../../../../src/passes/dae2_graph_fields_perf_wbtest.mbt)
compare the frozen V12 mutable graph with immutable fields. V14 completes
12,853 default and 86 focused native tests, 46 benchmarks and 4,056 matching
bounded observations. Large DAE2/O bytes match V12. Small DAE2/O pipelines
improve 62.47%/40.67%; active tee pipelines improve 91.89%/18.29%. Large costs
remain multi-second with contended small movements; RSS ranges overlap, and
quiet GC/entry/pure costs remain. The [complete V14 report](../../../tooling/tracing-playbook.md#v14-complete-checkpoint-and-next-cleanup-targets)
records hashes, oracle ratios, size gaps and the SL stack-order hotspot.

## September 29, 2026 scalar direct mutation

V11 qualifies scalar flat bodies for mutation without a second HOT arena.
A body-local dependency graph demands stack values and the last local write
feeding each read. Calls demand only retained arguments; mandatory producers
still execute in original order and drop unused retained results at production.
Removed results, explicit returns and kept-result calls follow solved module
boundary liveness. Local slots and names use the existing reverse removed-param
placement and capture compaction map. Complete final-module validation remains.

[Exact HOT comparisons](../../../../../src/passes/dae2_raw_rewrite_wbtest.mbt)
cover writes beneath stacked reads, traps, effects, recursion, grouped locals,
names and 130 parameters. Tuple results and indirect calls retain HOT mutation at this checkpoint;
V13/V14 subsequently admit scalar tees under the contract above. The [dispatcher](../../../../../src/cmd/dae2_raw_rewrite_wbtest.mbt)
checks both modes. The initial eight-fixture test failed with two rewrite lifts
before implementation; the final focused slice passes fifteen checks. V11
passes 12,840 default and 73 focused native tests and 52 native benchmarks.
The 741-module bounded matrix has 3,380 matching runtime observations and
identical V10/V11 outputs. Direct-only mutation controls improve 38.62 →
12.98 µs at tiny scale and 8.44 → 1.52 ms at 32 bodies/128 operations.
Enclosing active flat DAE2/O improve 81.45%/66.02% and GC 89.71%/56.97%.
Large compiler DAE2/O remain 3.89/7.07 seconds at 9.19×/4.39× v133.
The [priority report](../../../tooling/tracing-playbook.md#dae-priority-scan-and-source-query-controls)
records the initial active O regression, its quiet renewal, RSS variation and
remaining size gaps. V12 completes releasing solved module adjacency before rewrite;
[storage and active rewrite checks](../../../../../src/passes/dae2_solved_storage_wbtest.mbt)
require zero retained edge capacity and unchanged solved liveness/output.

## September 29, 2026 mandatory producers and replay reset

V10 qualifies flat scalar loads, trapping numeric operations and selected GC,
reference, table and growth producers without the first HOT arena. All inputs
are observed even for a dropped result, preserving possible traps and effects;
struct field counts use the existing module subtype context. Changed functions
still replay and mutate through HOT. The
[direct opcode and exact-HOT fixtures](../../../../../src/passes/dae2_raw_producers_wbtest.mbt)
include array operations missing from the text reader, and the
[dispatcher](../../../../../src/cmd/dae2_raw_producers_wbtest.mbt) covers both modes.

Bulk replay reset preserves the retained-capacity and immutable-boundary
contracts, restoring the wide helper after V9's 7.18% regression. Fresh/reused
64-body controls measure 720.37/629.66 µs at 8,192 boundaries. V10 passes
12,830 default tests, 61 focused native tests and 2,808 bounded runtime
observations. Quiet active GC DAE2/O improve 7.53%/2.79%; large passes remain
four/seven seconds with a contended O increase requiring renewal. The
[priority report](../../../tooling/tracing-playbook.md#dae-priority-scan-and-source-query-controls)
owns exact hashes, RSS dispersion and fresh verified-v133 ratios.

## September 29, 2026 flat writes and rewrite allocation

V9 extends the symbolic stack with one current dependency per local. A flat
`local.set` replaces that symbol; `local.tee` replaces it while preserving the
stack value. Values already on the stack retain their earlier symbol across a
later write. Validation still precedes graph commitment, and structured writes
retain full HOT/LocalGraph analysis. The
[assignment fixtures](../../../../../src/passes/dae2_raw_assignments_wbtest.mbt)
compare exact full-HOT bytes for overwrites, tees, stacked entry reads and a
body-local carrier, with no initial lifts.

Changed raw bodies now share one module-scoped replay workspace. Reset clears
all expression edges, work and observed state, then reseeds the immutable solved
boundary prefix. Capacity is bounded by that prefix and the largest replayed
body; no HOT arena is retained. [Reset and multi-body tests](../../../../../src/passes/dae2_replay_workspace_wbtest.mbt)
prove old edges cannot affect a smaller next body or mutate module liveness.
[Native controls](../../../../../src/passes/dae2_replay_workspace_perf_wbtest.mbt)
compare fresh and reused replay allocation at 128/8,192 boundaries.

The rewrite walk reads checked child slots until a child ID changes, allocating
one owned parent snapshot at the first replacement. Unchanged ordinary nodes
return directly; calls retain the old producer IDs required for tuple grouping.
[Ownership fixtures](../../../../../src/passes/dae2_lazy_children_wbtest.mbt)
assert unchanged encoded expressions/revisions and independent changed snapshots;
[controls](../../../../../src/passes/dae2_lazy_children_perf_wbtest.mbt) compare
the former owned-map path against lazy snapshots. The expanded focused suite
passes 451 tests and V9 passes 12,819 default, 50 focused native and 479
native IR tests plus 64 native benchmark cases. Its 2,444 bounded runtime
observations match. Child controls improve 72.51 → 36.61 ns and
290.10 → 136.65 µs; replay improves 66.59 → 44.79 µs at 128 boundaries,
but regresses 765.67 → 820.62 µs at 8,192. The wide reset needs another
trial, completed by V10 above. The priority report records completed V9
enclosing, repeated memory and fresh oracle evidence; V8's historical costs
remain visible.

## September 29, 2026 symbolic flat-body analysis

An active flat body can record parameter and whole-result dependencies without
its initial HOT arena. Constants and default-initialized locals contribute no
dependency; readonly parameter reads alias their boundary location. Pure scalar
operators merge distinct dependencies through compact integer joins. Call
arguments depend on the callee's parameter locations, returned lanes alias its
whole-result location, and indirect/reference targets are observed. Stores
observe their operands. Recursive forwarding therefore retains the same least
fixed point without a fixed parameter-count limit.

Qualification completes before committing graph edges and every admitted body
is validated. Assignments, structured control, tail calls, intrinsic targets,
trapping producers and unsupported SIMD/GC operations retain full HOT analysis.
Only bodies needing a rewrite are lifted; their expression liveness is replayed
in a fresh graph seeded with the solved boundary prefix. No solved module edges
are mutated. A newly observed boundary triggers a complete HOT reanalysis of
the original module. The private reference switch enables exact encoded-output
comparisons; it is not a public optimizer option.

[Red-first tests](../../../../../src/passes/dae2_raw_analysis_wbtest.mbt)
cover stores, dropped expressions/results, final returns, multiple result lanes,
recursion, indirect/reference families, 96 parameters, input ownership and invalid
types. [Both command modes](../../../../../src/cmd/dae2_raw_analysis_wbtest.mbt)
retain live store operands while pruning an unused argument. Dedicated
[benchmarks](../../../../../src/passes/dae2_raw_analysis_perf_wbtest.mbt)
compare full HOT and raw analysis with active rewriting at tiny and wide sizes,
then measure complete plain and optimizing pipelines. V8 passes 12,812 default
and 43 focused native tests; 2,184 bounded runtime observations and exact
HOT-reference output controls match. Three quiet flat-body pairs improve
DAE2/O 10.37%/27.68%, while large DAE2 remains about four seconds. Five
V7b/V8 RSS pairs add median 15,796/6,060 KiB for DAE2/O with wide variation.
The compiler and memory gaps remain open; the priority report owns exact hashes,
MAD and host contention.

## September 29, 2026 readonly observable boundaries

Flat private void bodies can establish readonly parameter liveness before HOT
lifting. Qualification scans the whole body first and marks a parameter only
when a direct leaf read supplies an observable store or pinned call operand.
Parameter assignments, unsupported control and unknown arities retain the
complete analysis. Newly pinned boundaries use the same validated first-lift
admission as exposed functions; every call/control family must also be pinned,
and intrinsic calls retain HOT target analysis. Invalid bodies still reject.

[Pass and ownership regressions](../../../../../src/passes/dae2_observed_entry_wbtest.mbt)
and [both dispatcher modes](../../../../../src/cmd/dae2_observed_entry_wbtest.mbt)
preserve stores and live arguments while removing an unrelated dead parameter.
The V6 checkpoint passes 12,795 default tests and 1,716 bounded runtime
observations. Three quiet pairs improve the 128-wrapper/128-store pipeline
57.26% in DAE2 and 30.68% in DAE2-O with identical bytes. Full compiler costs
remain near their prior four/seven-second levels; this does not close P03.
The [priority report](../../../tooling/tracing-playbook.md#dae-priority-scan-and-source-query-controls)
owns exact hashes, native controls, MAD, memory uncertainty and pending renewal.

## September 28, 2026 compact locations and early admission

Node locations now occupy one contiguous range per analyzed function. The
function snapshot stores its base and count instead of an additional node-ID
array. Bulk graph growth retains spare capacity across neighboring bodies;
dependency IDs, negative sentinels and insertion order are unchanged. V3 fused
call metadata and intrinsic target pins into dependency analysis. V4 records
all six call forms during the existing raw control scan, including legacy
bodies/catches, and avoids collecting the same metadata again in HOT.

A body whose boundary, callees and indexed control families are fully pinned
may avoid its first HOT lift. Public type-family seeds count as pins before
fixed-point propagation; private direct boundaries stay independent. The
original body still undergoes function-body validation against a reusable
module environment. Each validation owns its local, label, operand and
initialization state; no sibling state is retained. Intrinsic calls retain
HOT analysis to pin their literal `ref.func` targets. Legacy/unknown controls,
invalid family IDs and unpinned boundaries retain the full path. Metadata still
drives rewrite admission after solving.

For a local with exactly one unconditional top-level `local.set`, root-order
analysis can resolve reads to entry or that write without building CFG and
LocalGraph. Operand reads precede completion of the write. Shared reads seen
on both sides, detached reads, conditional/repeated writes, shared writes and
handler/continuation bodies retain the complete flow/unknown fallback. The
proof does not mutate HOT and dies with the analyzed function.

The initial v2 proof expanded shared HOT subtrees repeatedly and stalled on the
large compiler input. That prototype is rejected: its small runtime controls
and faster graph-allocation benchmarks did not establish enclosing performance.
A sixteen-node regression subsequently failed its traversal-work bound while
preserving the expected cross-write unknown read. V3 caches non-read visits in
the source scratch, invalidating them after each admitted root write. This
fixes exponential expansion but can revisit a shared subtree after every
unrelated write. V4's red-first many-write DAG regression exposed that remaining
cost. Unique postorder plus one reverse propagation computes each node's first
and last reaching root ordinal. A read entirely before its sole write is an
entry read, a read entirely after is a write read, and a crossing interval is
unknown. Operands within the write root precede its completion. A write used
under another root, or repeated as a root, requires full flow. The work is
linear in nodes, child edges and roots; scratch remains function-scoped.

V4's one-write native controls regress, so V5 uses a separate single-write
proof with only two visit epochs and a scalar completion flag. It avoids the
interval/postorder arrays while preserving linear work. The multi-write proof
still uses root intervals; shared or repeatedly executed writes require full
flow. Indexed LocalGraph queries now return a scalar readonly source record
for DAE2, avoiding an enum allocation per source. Owned-array and enum queries
remain available, with identical source order and checked bounds.

V3 also keeps retained leaf rewrites scalar, classifies dependency-node effects
once per operand loop, and appends private function signatures in one owned type
workspace. The outer source group vector is copied once; original definitions
remain unchanged. Lowering may replace the workspace after adding control
types, at which point its flattened count is recomputed. Private appends update
that count directly, preserving metadata and allocation order. Family rewriting,
canonicalization, name remaps and full final validation remain unchanged.

Red-first controls exposed extra lifts, exact-capacity bulk growth, missing call
metadata, unnecessary local flow and repeated DAG traversal. V5 passes 12,788
default wasm-gc tests, 477 native IR tests and nineteen focused native tests.
The bounded runtime matrix validates 325 modules with 1,560 matching results,
effects and traps against original/baseline/candidate/verified-v133 behavior.
V4 pinned-call sibling pipelines improve DAE2/O 51.33%/18.88%, and V5
conditional-write DAE2 improves 3.99% over V4. The fresh V5 large pass-local
comparison remains 3,976.588 ms at 9.34× v133 for DAE2 and 7,213.857 ms at
4.44× for DAE2-O. DAE2-O also remains larger than the oracle by 382,584 raw
bytes. These improvements do not close the large compiler or output-quality
gaps. Exact hashes, dispersion and controls are in the
[priority report](../../../tooling/tracing-playbook.md#dae-priority-scan-and-source-query-controls).
Dedicated aggregate renewal remains deferred
during performance iteration; these changes do not inherit earlier signoff.

Sources: [implementation](../../../../../src/passes/dead_argument_elimination2.mbt),
[range invariants](../../../../../src/passes/dae2_compact_locations_wbtest.mbt),
[first-lift controls](../../../../../src/passes/dae2_first_lift_wbtest.mbt),
[raw call metadata](../../../../../src/passes/dae2_raw_calls_wbtest.mbt),
[pinned-call benchmarks](../../../../../src/passes/dae2_pinned_calls_perf_wbtest.mbt),
[entry-write behavior](../../../../../src/passes/dae2_entry_write_wbtest.mbt),
[source-order checks](../../../../../src/passes/dae2_entry_sources_wbtest.mbt),
[DAG interval benchmarks](../../../../../src/passes/dae2_entry_interval_perf_wbtest.mbt),
[scalar source ownership](../../../../../src/ir/local_graph_scalar_sources_wbtest.mbt),
[scalar query benchmarks](../../../../../src/ir/local_graph_scalar_sources_perf_wbtest.mbt),
[native controls](../../../../../src/passes/dae2_priority_perf_wbtest.mbt),
[leaf rewrites](../../../../../src/passes/dae2_rewrite_leaf_wbtest.mbt),
[type workspace](../../../../../src/passes/dae2_type_workspace_wbtest.mbt),
[allocation controls](../../../../../src/passes/dae2_rewrite_allocation_perf_wbtest.mbt),
[dispatcher](../../../../../src/cmd/dae2_entry_write_wbtest.mbt), and
[validation ownership](../../../../../src/ir/hot_validation_env_wbtest.mbt).

## September 27 follow-up allocation campaign renewal

The [final follow-up campaign](../../../tooling/tracing-playbook.md#september-27-2026-follow-up-pass-allocation-campaign)
supersedes pending-renewal notes for its allocation changes below. The frozen
source passes 12,583 default tests. Its 220,000 comparisons across 22 affected
lanes report no validation, generator, property-counter, command or observed
Starshine/original semantic failures. The report retains exact tool identities,
all artifact timings, active fixtures, residual/size replays and runtime limits.
Per-change measurements are historical isolated pairs, not additive gains.
Remaining timing, output-quality and runtime-coverage gaps stay open; rejected
prototypes remain rejected.

This page describes the implemented Binaryen 132 port, superseding the earlier
proposal to leave `dae2` unknown or to add only parameter forwarding.

The module pass owns a short-lived usage graph. Each function parameter and
whole result tuple has a location; HOT expression values have locations too.
Type-family locations connect referenced functions to indirect calls. Observable
uses seed the graph, and a queue visits each live location at most once.

## September 27, 2026 flat dependency storage

DAE2's parameter, result, and expression-value graph stores actual dependencies
in flat source/next arrays, with first/last edge indices for each location.
Creating a location no longer allocates an empty heap array. Appending through
the last edge preserves insertion order and therefore the existing observation
queue order. Duplicate dependencies remain harmless; unobserved cycles remain
unused, and a later observation resumes the same monotone fixed point.

The sparse-location regression first failed with 64 edge rows for an edgeless
64-location graph. It now requires no edge entries until a dependency is added,
then verifies exact live locations, duplicates, disconnected cycles, negative
sentinel inputs, insertion order, and repeated solving. The existing unrepresented
read test still checks both parameter-entry and write dependencies. The command
fixture verifies dead-argument removal while keeping a live forwarded parameter
in both DAE2 modes.

Sources: [graph implementation](../../../../../src/passes/dead_argument_elimination2.mbt),
[invariants](../../../../../src/passes/dae2_sparse_edges_wbtest.mbt),
[sparse and dense controls](../../../../../src/passes/dae2_sparse_edges_perf_wbtest.mbt),
[dispatcher fixture](../../../../../src/cmd/dae2_sparse_edges_wbtest.mbt).
All six focused regressions pass. Native construction/solve benchmarks compare
the original row algorithm and flat storage in the same binary: **114.69 →
32.27 µs** for 8,192 sparse locations, **454.05 → 127.55 µs** for 32,768, and
**117.19 → 79.24 µs** for a denser 4,096-location control. These isolate graph
storage and solving; they do not establish a whole-pass speedup. Final artifact
and generated evidence belongs to the
[tracing playbook](../../../tooling/tracing-playbook.md).

## September 26, 2026 sparse local-flow query storage

Reverse reaching-definition queries now allocate cache entries only for queried
block/local pairs. They reuse visited-block and worklist storage and index a
predecessor's last local writes lazily; blocks with at most four actions retain
the direct scan. The sparse control-flow fallback also reuses traversal storage.
Caches remain scoped to one immutable function/CFG, preserve source ordering,
and publish results only after completing the predecessor closure.

Bounded tests first failed on dense cache capacity and eight query-workspace
allocations instead of one. They retain exact reaching writes across separate
blocks. Existing join, loop and handler fixtures compare sparse results with
the converged reference solver. Command coverage checks real unused-argument
pruning while preserving a cross-block local value.

Focused native graph-construction benchmarks improve `749.80 → 401.22 µs` for
128 cross-block reads and `2.81 → 1.47 ms` for 256; each fixture declares four
times as many locals as it reads. These measurements establish the targeted
analysis gain, not a whole-DAE2 speedup. Evidence:
`src/ir/local_graph_query{,_perf}_wbtest.mbt`,
`src/cmd/perf_local_flow_wbtest.mbt`, and
`.tmp/pass-perf-work-20260926/local-query-{before,after}.log`.
Final aggregate results and runtime limits are in the [shared renewal](../../../tooling/tracing-playbook.md#september-26-2026-pass-time-allocation-and-indexing-renewal).

## September 26, 2026 shared source-order index

The [CoalesceLocals source-order renewal](../coalesce-locals/starshine-strategy.md#september-26-2026-source-order-local-access-index) also improves large-input DAE2: seven isolated alternating pairs give pipeline `7,633.494ms → 6,438.548ms` (**15.7% faster**), with byte-identical outputs. Unlike the lazy-flow fixture gain below, this is a confirmed compiler-artifact improvement. The shared ordering proof and strict bounds remain unchanged; the linked page owns hashes, tests, the small DAEO tradeoff and signoff evidence. Initial lifting and required local-flow solving remain open targets.

## September 26, 2026 lazy local-flow analysis

LocalGraph/CFG construction now waits for the first live local read. The conservative all-writes index waits for the first read whose reaching sources are unknown. Both snapshots are function-local and built at most once; unknown reads still depend on the entry parameter and every possible write, including unrepresented nodes. This follows the demand-driven `LazyLocalGraph` queries in [Binaryen 133 DAE2](https://github.com/WebAssembly/binaryen/blob/version_133/src/passes/DeadArgumentElimination2.cpp); Starshine also needs dependencies through body locals.

Two bounded regressions failed with two unnecessary builds each. Final tests cover real signature pruning, retained parameter reads, deliberately unrepresented reads with conservative dependencies, and command dispatch. The focused suite passes 77 tests; `moon info`/`moon fmt` succeed with no public API change.

Native `0925e7e8ae15e1e06d4fa171fdcf5b251e42f68f627ef7955a10bf032570748f` versus baseline `b084365e0bd4b2bc98457da7eb8773504b5cf2720665dea7ae5b961d30c41a06`, isolated alternating samples after one warmup:

- 1,000 store-heavy functions requiring signature rewrites: seven-pair pipeline `359.096ms → 322.358ms` (**10.2% faster**).
- 1,000 unchanged store-heavy functions: three-pair pipeline `114.711ms → 81.794ms` (**28.7% faster**).
- Small compiler: seven-pair `19.742ms → 19.508ms`, a small difference.
- Large compiler: an apparent three-pair `8,292.333ms → 8,176.763ms` gain did **not** repeat. Seven pairs give `8,200.787ms → 8,222.452ms`, with mixed per-pair deltas. This establishes no meaningful large-artifact speedup.

Every paired raw output is identical. Evidence: `.tmp/dae2-lazy-flow-paired-<fixture>-final-20260926/`, `.tmp/dae2-lazy-flow-confirm-large/result.json`, and the [fuzzing page](./fuzzing.md). Source/tests: [`dead_argument_elimination2.mbt`](../../../../../src/passes/dead_argument_elimination2.mbt), [`dae2_lazy_flow_wbtest.mbt`](../../../../../src/passes/dae2_lazy_flow_wbtest.mbt), and [command fixture](../../../../../src/cmd/dae2_lazy_flow_wbtest.mbt). Initial lifting and actual local-flow solving remain performance targets.

## September 26, 2026 skip unchanged rewrite lifts

The rewrite phase now reuses the first analysis phase's complete direct/indirect call summary. It rebuilds HOT only when a function or one of its callees changes signature, or when indexed control types require the existing preservation path. Legacy `Try` also retains that path. The rewrite decision is computed once; type-family identity, new function-type selection, names, final cleanup and validation still run. The bounded preflight leaves all analysis and fixed-point edges intact. [Binaryen 133's DAE2 optimizer](https://github.com/WebAssembly/binaryen/blob/version_133/src/passes/DeadArgumentElimination2.cpp) works on its retained IR and gates signature/local reconstruction on removed parameters or results; this change avoids Starshine's additional reconstruction of unaffected bodies.

A regression first failed with three rewrite lifts instead of two while successfully pruning the sibling's unused parameter. Two pass fixtures and one active command fixture verify the skip, retained indexed-control preparation, unchanged input/body preservation and the optimized call signature. All 74 focused DAE2 tests pass; `moon info` and `moon fmt` succeed without a public API change. The full wasm-gc suite passes 12466 tests with zero failures.

Fresh native `b084365e0bd4b2bc98457da7eb8773504b5cf2720665dea7ae5b961d30c41a06` is compared with baseline `8b7d8d8aa8de9342cf6148de10350ca9104217e18d2317cf92b2be7e7d08e0a1`. Isolated alternating pairs after one warmup preserve exact raw output on every fixture:

| Fixture | Samples | Before pipeline | After pipeline |
| --- | ---: | ---: | ---: |
| Small compiler | 7 | 19.135ms | 18.362ms |
| Large compiler | 3 | 8,394.226ms | 7,704.931ms |
| 100 unchanged functions | 3 | 14.341ms | 10.454ms |
| 500 unchanged functions | 3 | 73.810ms | 51.734ms |
| 1,000 unchanged functions | 3 | 152.037ms | 107.030ms |
| 1,000 functions requiring rewrites | 7 | 331.541ms | 335.645ms |

The large compiler improves **8.2%**, with command median `9,411.505ms → 8,622.409ms`. The 1,000-unchanged-function fixture improves **29.6%**. The all-changing synthetic fixture regresses **1.2% (4.104ms)**; this is a measured tradeoff, not a universal speedup. A preliminary implementation retained a duplicate rewrite check and was replaced before signoff; its interrupted oracle run does not establish final evidence.

Fresh v133 pass-local medians remain `18.699ms` versus `1.131ms` on the small compiler and `7,578.025ms` versus `396.714ms` on the large compiler. The remaining DAE2 performance gap stays open.

Evidence: `.tmp/dae2-relift-paired-{small,large,functions-1000,unchanged-100,unchanged-500,unchanged-1000}-final-20260926/`, `.tmp/dae2-relift-inputs/manifest.json`, and the [fuzzing renewal](./fuzzing.md). Source and fixtures: [`dead_argument_elimination2.mbt`](../../../../../src/passes/dead_argument_elimination2.mbt), [`dead_argument_elimination2_types.mbt`](../../../../../src/passes/dead_argument_elimination2_types.mbt), [`dae2_relift_wbtest.mbt`](../../../../../src/passes/dae2_relift_wbtest.mbt), and [command test](../../../../../src/cmd/dae2_relift_wbtest.mbt).

## September 26, 2026 catch-payload analysis preflight

DAE2 invokes ordered catch-payload repair on each lifted function. The repair planner previously built its complete node-use graph before checking whether the function contained typed catch payloads. It now performs the existing live-node preflight first and returns the same empty plan when there are no payloads. Catch-all markers still reject; real typed payloads still build the graph and use the original complete, atomic repair plan. Public repairability and mutation results are unchanged. This follows the lazy-analysis principle in [Binaryen 133 DAE2](https://github.com/WebAssembly/binaryen/blob/version_133/src/passes/DeadArgumentElimination2.cpp), whose parameter-use visitor queries `LazyLocalGraph` only after confirming a read targets a parameter; Starshine's catch repair remains its own representation bridge.

The bounded regression first failed because a payload-free function built one use graph. It now preserves the original lowered body and revision with zero graph constructions. A positive typed-payload regression still builds one graph, inserts a typed capture and local read, and validates control. All 969 IR, DAE2 and Flatten tests pass on wasm-gc. The preceding 1,000-helper instruction profile attributed 6.40% of total instructions to catch-repair planning, including 5.36% in use-graph construction; these are instruction counts, not timings.

Paired native measurements retain identical output bytes on every sample:

| Fixture | Before pipeline | After pipeline | Sampling |
| --- | ---: | ---: | --- |
| Small compiler | 20.446ms | 19.107ms | One warmup, seven alternating pairs |
| 1,000 store-heavy helpers | 353.583ms | 333.762ms | One warmup, three alternating pairs |
| Large compiler | 8,731.602ms | 8,317.893ms | One warmup, three alternating pairs |

These are 6.5%, 5.6% and 4.7% pipeline reductions respectively. Large command median changes `9,759.045ms → 9,315.220ms`. Paired artifacts are `.tmp/catch-preflight-paired-{small,functions-1000,large}-20260926/`. Baseline native SHA-256 is `30dc535a657e2467aaf55d765ee9393e742144f97186b862c517c30e6a513a4c`; updated is `a6385c90382a7a2925d0b4e049a5bcd5ccac3fc8d4f473e7cf41a0411a5943ea`. `moon info`, formatting and native release build pass; no public API changes.

Fresh verified-v133 sweeps measure small pass-local medians `19.130ms` versus `1.130ms` and large medians `8,260.168ms` versus `400.926ms`; the substantial remaining oracle performance gap is still open. Artifacts: `.tmp/pass-sweep-v133-catch-preflight-{small,large}-20260926/`.

The explicit-native `dae2` aggregate renewal uses verified v133, seed `0x5eed`, eight subprocesses, both debris normalizers and Node-v2. Each world compares 10,000 cases: open has 2,879 normalized, 667 cleanup-normalized and 6,454 residuals; closed has zero normalized, 100 cleanup-normalized and 9,900 residuals, including 706 canonical size losses. Each world has 9,312 runtime matches, 688 original-runtime-blocked continuation cases and zero semantic mismatches. Both have zero validation/property/generator/command failures. Counts match the preceding module-environment signoff.

Flatten also calls the repair planner, so its `flatten-all` aggregate runs 10,000 cases with all three documented debris normalizers: 837 normalized, 5,057 cleanup-normalized and 4,106 residuals, zero canonical size losses and zero validation/property/generator/command failures. Runtime execution was not enabled for Flatten. Agent judgment keeps current residuals open as parity gaps, including closed DAE2's size-losing cases; no historical Flatten cleanup-win classification is extended to v133 here. All 60 saved raw residual outputs replay identically against the pre-change compiler. Artifacts: `.tmp/pass-fuzz-dae2-catch-preflight-{open,closed}-v133-10000-20260926/`, `.tmp/pass-fuzz-flatten-catch-preflight-v133-10000-20260926/`, and `.tmp/catch-preflight-replay.json`. The 12,456-test full default suite passed immediately before this unit; its current focused suite passes 969 tests.

## September 26, 2026 shared cleanup module facts

The final branchless-block cleanup built a complete validation environment for every defined function. It now builds one environment after signatures, control types and local-throw folding are finalized, then supplies it to each cleanup. The helper only reads module block-type facts; the candidate's declarations stay unchanged throughout this map. Existing callers retain their original environment construction when no shared snapshot is supplied. [Binaryen 133 DAE2](https://github.com/WebAssembly/binaryen/blob/version_133/src/passes/DeadArgumentElimination2.cpp) likewise keeps one module object across analysis and rewriting and caches shared public-type facts.

The bounded regression prunes i32/i64 parameters, flattens typed result wrappers, preserves two live calls and their result, and limits cleanup environment construction to at most one. It first failed with three constructions; all 73 DAE2/shared-cleanup tests now pass on wasm-gc. `moon info`, formatting and the native release build pass; this unit adds no public API.

| Fixture | Before pipeline | After pipeline | Sampling |
| --- | ---: | ---: | --- |
| 100 helpers, 64 ordered stores each | 35.626ms | 33.593ms | One warmup, three alternating pairs |
| 500 helpers, 64 ordered stores each | 227.985ms | 172.662ms | One warmup, three alternating pairs |
| 1,000 helpers, 64 ordered stores each | 566.952ms | 357.659ms | One warmup, three alternating pairs |
| 6,211,596-byte compiler fixture | 350,398.025ms | 8,849.366ms | **One pair, no warmup** |

The single large pair is a 39.6x pipeline improvement, with command time `351,398.852ms → 9,841.313ms`. Its limited sample count is explicit; it is not a three-sample median. Output remains exactly 6,114,805 bytes, SHA-256 `2b9031cbfa2fce3ed29abf783daef2774688941baea42d00499db575d0321696`. Every repeated synthetic pair is also byte-identical. The 192,893-byte compiler fixture changes only `20.755ms → 20.393ms`, which is not claimed as a material gain.

Paired artifacts are `.tmp/dae2-module-env-paired-{small,functions-100,functions-500,functions-1000,large}-20260926/`; synthetic inputs and their hashes are in `.tmp/dae2-module-env-inputs/manifest.json`. Baseline native SHA-256 is `3063c88915ccf04bdcbc8d85d4b134bc3860f24d3a19775336a411c9de416278`; updated SHA-256 is `a9bc998439325ef23dec3af201619d4e86991cfe46fc8bde920b5e8aaa159475`. New oracle measurements use verified Binaryen 133; older v132 port evidence below retains its historical scope.

Fresh verified-v133 sweeps (one warmup, three samples) put current pass-local time at `21.162ms` versus `1.155ms` on the small compiler fixture, `8,892.905ms` versus `397.330ms` on the large fixture, and `353.336ms` versus `8.039ms` on the 1,000-helper input. Large command medians are `9,806.644ms` versus `856.742ms`. This removes the repeated module construction but leaves a substantial DAE2 performance gap. Sweep artifacts are `.tmp/pass-sweep-v133-dae2-module-env-{small,large,functions-1000}-20260926/`.

The renewed aggregate `dae2` profile uses seed `0x5eed`, explicit prebuilt native binaries, eight subprocesses, both cleanup normalizers, and Node-v2. Each world completes 10,000 comparisons: open has 2,879 normalized matches, 667 cleanup-normalized matches and 6,454 residuals; closed has zero normalized matches, 100 cleanup-normalized matches and 9,900 residuals, including 706 canonical size losses. Each world has 9,312 runtime matches and 688 original-runtime-blocked continuation cases, with zero semantic mismatches, validation, property, generator or command failures. Counts match the preceding nearest-write signoff; all 40 saved raw residual outputs are byte-identical to the pre-change compiler. Residuals remain agent-classified open parity gaps, including the closed-world size-losing family; runtime sampling does not establish complete transform parity. Artifacts: `.tmp/pass-fuzz-dae2-module-env-{open,closed}-v133-10000-20260926/`. The previous full default suite passed 12,451 tests before this unit; this unit's focused suite passes 73.

## September 25, 2026 nearest-write indexing

The shared reverse-flow LocalGraph builder now records each get's nearest within-block write during its existing action walk. It resets only written local slots at block boundaries and retains the same predecessor/exception closure when no within-block write exists. This removes repeated backward prefix scans without changing reaching-definition facts. The [dedicated native benchmark](../../../../../src/passes_perf_long/dae2_local_graph_perf_test.mbt) improved from `4.15ms` to `403.57µs` at 1,024 distant reads and from `14.95ms` to `795.21µs` at 2,048; [bounded tests](../../../../../src/ir/local_graph_reverse_wbtest.mbt) cover overwrites and sibling-block isolation. All 407 IR tests and 70 DAE2 tests pass on wasm-gc. `moon info` and formatting pass with no public API change from this unit.

On the 189 KB fixture, DAE2 pass-local median improved from `25.862ms` to `23.189ms` (10.3%), with identical raw output SHA-256 `f8b4d5e5c7b6372ad8d6a2193df5f2db61ec4ce2462b40095a762dfe226a35f7`. Verified Binaryen 133 measured `1.347ms` in the new sweep, so the pass still loses by `17.21x`. [Binaryen 133 DAE2](https://github.com/WebAssembly/binaryen/blob/version_133/src/passes/DeadArgumentElimination2.cpp) queries `LazyLocalGraph` only for parameter gets; Starshine still eagerly builds broader local liveness to support its expression-removal graph. That larger analysis difference remains an optimization target. Artifacts are `.tmp/dae2-localgraph-bench-{before,after}.log` and `.tmp/pass-sweep-v133-{dae2-localgraph-before,localgraph-after-small}-20260925/`.

The fresh open-world `dae2` aggregate compares 10,000 cases against verified v133 with the explicit native binary and eight subprocesses: 2,879 normalized matches, 667 cleanup-normalized matches, and 6,454 residual output differences. Node-v2 observes equal original/Starshine/Binaryen results in 9,312 cases; all 688 continuation cases remain blocked by the original runtime. There are no semantic mismatches or validation/property/generator/command failures. All residuals are canonically smaller, but size alone does not close parity: reviewed unused-local removal is an exact cleanup benefit; the remaining families remain parity gaps or runtime-blocked uncertainty. Evidence: `.tmp/pass-fuzz-dae2-localgraph-open-v133-10000/result.json` and its persisted diffs/runtime observations.

The closed-world companion also completes 10,000 cases: 100 cleanup-normalized matches and 9,900 residual differences, with the same 9,312 runtime matches, 688 runtime-blocked continuations, and zero semantic/validation/property/generator/command failures. Its 706 canonically larger indirect-call cases remain size-losing parity gaps: Starshine retains the indirect type family's parameter and dropped result where Binaryen removes them (saved case 5 is 83 versus 82 canonical bytes). The other residual families remain open unless individually justified. Both lanes use native SHA-256 `72b55be2e092167030dccf79d6e48f646d338c16791852a9a9171d73b41b9894`; closed-world evidence is `.tmp/pass-fuzz-dae2-localgraph-closed-v133-10000/result.json`. These results validate the indexing change without claiming complete DAE2 parity.

## September 24, 2026 repeated-solve measurement

Type-identity conflict handling can observe more graph locations and call `solve` again. The graph now retains its queue cursor between solves, so earlier locations are not scanned again; edges must be complete before the first solve. The native release white-box benchmark in [`dae2_repeated_solve_perf_wbtest.mbt`](../../../../../src/passes/dae2_repeated_solve_perf_wbtest.mbt) measured 128 incremental observations/solves at `10.11 → 2.29 µs` (4.41×) and 256 at `34.80 → 4.43 µs` (7.86×). A second-solve propagation test and 64 existing DAE2 tests pass. This isolates graph behavior; pass-level impact on real identity conflicts remains unmeasured.

Direct call arguments depend on the corresponding callee parameter. A used call
value depends on the callee result. Returns connect to the enclosing result.
Tail calls connect caller and callee result liveness in both directions. Local
flow distinguishes entry parameters from overwritten locals; branch payloads
and the result types of their targets remain valid.

Each HOT body is released after analysis. A second lift is limited to changed
function/call signatures or indexed-control preservation; other bodies are
reused directly. LocalGraph
uses symbolic block-entry sources and sparse changed-local summaries when a
linear reverse scan cannot represent nested control. It resolves complete
predecessor closures before caching, preserving loops and exception paths.
The new solver matches the converged forward reference on 5,000 GenValid modules.

After solving, the pass builds new signatures, preserves argument evaluation
order with typed temporary locals when necessary, removes unused pure values,
and keeps their effectful or trapping descendants. It rewrites functions,
call sites, returns and eligible type families as one candidate module, verifies
HOT and validates the completed module. The dispatcher rebuilds module analyses.

Referenced type families retain subtype/recursion metadata. Open-world type
exposure pins signatures; a private unreferenced sibling can receive a distinct
signature even when its former type also describes a continuation or export.
The intrinsic `binaryen-intrinsics` / `call.without.effects` pins its target's
signature. Ordinary DAE remains available for independent comparison.

Legacy catch payloads are captured at handler entry before call-argument wrappers
can change their stack position. Multiple handlers are represented through
`try_table` with explicit handler labels. Ordinary catches retain only payloads;
functions with a rethrow use `catch_ref` and capture exception identity, including
rethrows that target an outer handler. A handler executes outside its protected body, so a throw
inside one handler is not accidentally caught by its sibling.

This is implementation evidence, not a claim that every upstream output shape
or every proposal already matches. The [validation page](starshine-port-readiness-and-validation.md)
and [upgrade ledger](../../version-132-upgrade.md) track the remaining signoff.

## September 27, 2026: retain identical child spans during rewriting

**Timing supersession:** the [nested-timer correction](../../../tooling/tracing-playbook.md#september-27-2026-nested-timing-scope-correction)
reparses the same saved traces and supersedes the optimizing pipeline totals
below: small **26.037 → 25.455 ms**, large **8,517.890 → 8,502.036 ms**,
and active wide fixture **60.813 → 58.127 ms (4.4%)**. The previous totals
included nested cleanup twice. Plain DAE2, exact-byte checks, active signature
changes and runtime evidence are unchanged; large optimizing performance
remains open.

DAE2 compares replacement children with the node's current span and skips the
write when their order and count are identical. Calls and control rewrites can
reset a span before this point, so comparing against the originally captured
children would be incorrect. Real changes still use the shared mutation API;
unchanged spans avoid copying old children, appending duplicate arena storage
and invalidating revisions. Tuple memoization, ordering and signature rules
remain unchanged.

The unchanged-span test failed before implementation. Both bounded storage/order
invariants, the active kept/discarded call fixture and 86 other focused DAE2
checks pass (89 total), including tuples and handlers. Native batches improve
**3.12 → 1.40 µs** for 64 repeated writes and **37.76 → 11.54 µs** for 1,024.
Both controls create a fresh small function per batch because the former write
appends arena storage; setup is included equally and storage cannot accumulate
across benchmark iterations.

Compiler pipeline medians are effectively flat: large DAE2 **5,172.277 →
5,199.715 ms**, large DAE2-optimizing **11,435.083 → 11,431.747 ms**; small
DAE2 17.493 → 17.614 ms and optimizing 33.900 → 32.941 ms. These large
budgets remain open. A new 50,413-byte fixture with 64 private helpers, two
parameters and 256 live additions each measures an active rewrite: the unused
second argument disappears from every helper signature. DAE2 is 51.720 →
51.196 ms and optimizing improves **68.743 → 64.668 ms (5.9%)**. This is a
dedicated workload, not a claimed compiler-artifact gain.

All six one-warmup/three-pair comparisons retain exact before/after bytes,
traced/untraced agreement and independent validation. Original and both pass
outputs from both binaries return identical values at five inputs including
32-bit overflow boundaries. Final aggregate renewal remains pending.

Evidence: `.tmp/pass-perf-next-20260927/dae2-child-{checks.json,bench-1.log}`,
`dae2-child-pairs-{small,large,wide}/result.json`, and
`dae2-child-wide-{input,runtime,signatures}.json`. The first benchmark round
was rejected for foreign CPU contention. Native SHA-256: `928989c8aaf2b1a390fb5493571d8b746ac7536ab750d295be5cc7990b30bb08`.
Sources: [rewriter](../../../../../src/passes/dead_argument_elimination2.mbt),
[span invariants](../../../../../src/passes/dae2_child_rewrite_wbtest.mbt),
[native controls](../../../../../src/passes/dae2_child_rewrite_perf_wbtest.mbt),
and [dispatcher fixture](../../../../../src/cmd/perf_dae2_child_rewrite_wbtest.mbt).

## September 27, 2026: reject retained analysis bodies

Retaining analyzed HOT bodies until rewrite avoided a second lift and improved
the dedicated 64-function benchmark from 792.82 to 624.50 µs. It did not
improve the large compiler workload: one warmup and three alternating pairs
measured plain DAE2 **5,489.948 → 5,695.433 ms (+3.7%)** and optimizing DAE2
**9,154.678 → 9,429.039 ms (+3.0%)**. Peak resident memory increased from
302,124 to 394,520 KiB (+30.6%). All four small/large paired comparisons
retained identical bytes, traced/untraced agreement and independent validation.

A smaller 32,768-node cache also regressed large plain DAE2, **5,459.205 →
5,584.159 ms (+2.3%)**. That variant's remaining optimizing measurements were
stopped after rejection; they do not constitute a completed matrix. Production
retention code was removed. A later attempt must reduce live memory or shorten
retention lifetime, rather than assume fewer lifts imply faster full passes.

The bounded [fixture test](../../../../../src/passes/dae2_retention_wbtest.mbt)
checks active rewriting and source reuse. The retained [native benchmarks](../../../../../src/passes/dae2_retention_perf_wbtest.mbt)
measure the current uncached implementation at 64 and 1,024 functions; they
are controls for future work, not a shipped retention optimization. Local
evidence is under `.tmp/pass-perf-reuse-20260927/`: `dae2-retention-pairs-*`,
`dae2-retention-memory.json`, `dae2-retention-small-cache-pairs-*`, and rejected
source snapshots. The initial ownership/work regression failed before the
prototype; 74 focused checks passed before its performance rejection.

## September 28, 2026 performance reuse contracts

Compact indexed-control family summaries let unchanged functions avoid a second lift when every referenced signature family is unchanged; unresolved families retain the conservative rewrite path. Handler admission avoids rebuilding handler-free bodies and preserves untouched sibling bodies. Legacy adaptation still canonicalizes grouped local declarations when another function changes, preserving the original encoded output. Whole-HOT retention remains rejected.

Tests and native controls: [dae2_control_summary_wbtest.mbt](../../../../../src/passes/dae2_control_summary_wbtest.mbt), [dae2_control_summary_perf_wbtest.mbt](../../../../../src/passes/dae2_control_summary_perf_wbtest.mbt), [dae2_handler_admission_wbtest.mbt](../../../../../src/passes/dae2_handler_admission_wbtest.mbt), [dae2_handler_admission_perf_wbtest.mbt](../../../../../src/passes/dae2_handler_admission_perf_wbtest.mbt). The [campaign report](../../../tooling/tracing-playbook.md#september-28-2026-performance-backlog-campaign) owns frozen-binary artifact timings, verified-v133 evidence and final correctness outcomes; helper timings alone do not close the remaining pipeline or parity gaps.


## September 28, 2026 shared follow-up controls

Shared initialization ownership and HOT result queries retain their semantic
contracts in the [IR ownership rules](../../../ir2/architecture-rules.md#performance-reuse-ownership-contracts).
The [follow-up report](../../../tooling/tracing-playbook.md#september-28-2026-follow-up-performance-campaign)
separates new helper evidence from this pass's enclosing timings and final
aggregate status. Prior signoff does not automatically cover the new sources;
guarded paths and remaining size/parity gaps retain their existing limits.

The V21 expansion validates 3,172 modules and records 13,776 observations.
DAE2/O now agree with original and v133 on both old stacked-read witnesses;
V18 incorrectly returned 11. SL full/nostructure still return 22, so shared
cleanup signoff remains blocked. The V24 shared source-order repair is under
full/native/runtime confirmation; see the [failure and repair trial](../../../tooling/tracing-playbook.md#v21-stacked-block-runtime-failure-and-v24-repair-trial).
Historical 79-fixture V18 evidence does not cover these new witnesses.
