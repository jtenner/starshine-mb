---
kind: entity
status: supported
last_reviewed: 2026-10-15
sources:
  - ../../release-horizon-and-oracles.md
  - ../code-pushing/index.md
  - ../../../../../src/passes/tuple_optimization.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/passes/tuple_optimization_wbtest.mbt
  - ../../../../../src/passes/tuple_alias_chain_perf_wbtest.mbt
  - ../../../../../src/passes/tuple_passthrough_chain_perf_wbtest.mbt
  - ../../../../../src/ir/hot_lower.mbt
  - ../../../../../src/ir/hot_lower_wbtest.mbt
  - ../../../../../src/passes_perf_long/tuple_optimization_perf_test.mbt
  - ../../../../../src/cmd/cmd_wbtest.mbt
  - ../../../../../src/cmd/cmd_native_wbtest.mbt
  - ../../../../../src/passes/optimize.mbt
  - ../late-pipeline-dispatch.md
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/TupleOptimization.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/OptimizeInstructions.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/wasm/wasm.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/wasm/wasm-validator.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/tuple-optimization.wast
  - https://github.com/WebAssembly/binaryen/blob/main/src/passes/TupleOptimization.cpp
  - https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/tuple-optimization.wast
related:
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./implementation-map.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ./starshine-hot-ir-strategy.md
  - ./scheduler-and-gates.md
  - ./reduced-repros-and-evidence.md
  - ./parity.md
  - ../../no-dwarf-default-optimize-path.md
---

# `tuple-optimization`

## October 15 retained reads and available store runs

A retained scalar read can sit above a previously evaluated tuple while its
remaining lanes feed separate stores. The former generic fallback rejects
multi-result producers and evaluates that producer again. The new regression
observes all32 imports twice and a fresh local read64 instead of2. The repair
moves the rightmost physical lane only for a zero-result LocalSet with exactly
one input and one popped value. Generic tuple requests and multi-input prefixes
keep their old guards. Early, middle, late and multiple retained reads check
old values, newly stored values, import order and module validation.

A middle retained read also exposes32 scratch locals for completed independent
moves. The one-cover path now reuses at most eight exact typed pairs. Each pair
belongs to its allocation array and is live only through four consecutive
local set/get instructions; both values return to the operand stack before
recursive emission, calls or control transfer. Other movement paths retain
fresh locals. The red-first bound now needs two locals for this fixture.
[Typed-row tests](../../../../../src/ir/hot_lower_tuple_lane_types_regression_wbtest.mbt)
cover i32/i64/f32/f64/v128, nullable extern and nonnullable function references,
three covering rows, distinct typed pairs and changed allocation-array ownership.
They check the actual instructions, distinct value tokens, validation and
encoded round trips.

A separate ordering shortcut accepts only contiguous scalar stores of an
already available effectful tuple, with exact physical lane availability and
source-order bounds against every later root. A private immutable-region index
caches both admitted and rejected runs. The fallback discovers the run length
before scanning its physical rows, avoiding repeated wide scans for separated
one-store runs. Bounded semantic tests fail first at496 queried roots and590
admission visits, respectively. All14,288 WasmGC tests pass; native831b053c
renews58,336 runtime comparisons plus GC CLI arguments. Paired timing and
generated renewal remain open for these changes. The permanent64-lane
[mixed numeric fixture](../../../../../tests/fixtures/tuple-optimization/available-mixed-lanes.wat)
checks exact float bits and every host exception boundary through the
[native runtime lane](../../../../../scripts/test/tuple-alias-capture-runtime.ts). See the
[available-store regressions](../../../../../src/ir/hot_lower_available_tuple_stores_regression_wbtest.mbt)
and [lowering implementation](../../../../../src/ir/hot_lower.mbt).

## October 15 bulk publication and lowering follow-up

Checkpoint `193e58a7` queues direct-copy prefixes by stable original store ID,
then rebuilds each surviving root/unique top-level-loop region once. Only the
existing strict owned/disjoint copy proof can queue a prefix. Loops that are
Tuple producers are excluded. Missing or duplicate anchors fail the checked
flush; forest retirement and fresh analysis follow publication. Other nested
regions keep immediate publication. This removes repeated retained child spans
without widening the copy proof. [Region controls](../../../../../src/passes/tuple_publication_region_regression_wbtest.mbt)
check typed entries, independent weighted values/events, dead copy producers
and labels, a linear child-storage bound, mixed regions and repeat passes.
The storage test fails before the repair (536 children from 204 at width 8).

Against `d74c3902`, seven alternating native pairs after one warmup reduce the
1,024-copy loop's quiet command median from 60.307 to 25.767 ms and traced pass
median from 40,869 to 7,206 microseconds. Child-process peak RSS falls from
81,732 to 24,400 KiB. All seven command pairs improve and output bytes agree.
At width 512, command time is 22.792 to 14.714 ms and RSS 36,824 to 20,352 KiB.
The source-only control is 7.543 to 7.556 ms. This is fixture/compiler RSS
evidence, not live output-GC retention or a general allocation claim. Raw
samples, hashes, harness, engine checks and host records are under local
`tuple-nested-perf/{functional-bulk-data-types,timed-bulk-data-types}`.
Other projects' Go/QEMU work remains recorded as host noise.

The same checkpoint passes 14,267 WasmGC tests and the expanded native lanes:
13,440 Tuple, 12,288 numeric-group, 11,568 Heap2Local and 15,440 memory/trap
comparisons, plus GC CLI arguments. This renews the ascending-store native
coverage below. Fresh callable-generator aggregate renewal remains required.

A later red-first lowering test exposes quadratic failed buried-stack searches
for nodes requested for the first time. The private lowering context now tracks
requested nodes, including incoming stack values and synthetic control-prefix
values. Only previously requested nodes can need a buried reuse search; repeated
requests retain the existing effect/ownership checks. The mark occurs before
recursive descent, because a sole-edge child can be emitted before its parent.
Suspended stacks and pending parents must remain covered. Independent event and
value tests cover these cases, with no extra scratch locals. All 14,271 WasmGC
tests pass. Native `58491a9e` renews all52,736 runtime comparisons and GC CLI
checks. Wide512 quiet median30.560→28.823ms has four of seven adverse pairs;
no general command gain follows. Later shared-producer source-order scans
remain quadratic. The [measurement record](../../../tooling/tracing-playbook.md#first-emission-lowering-checkpoint)
retains slower controls, exact hashes and memory/code-size limits.
See [lowering controls](../../../../../src/ir/hot_lower_first_emission_regression_wbtest.mbt)
and [the lowering implementation](../../../../../src/ir/hot_lower.mbt).


## October 15 ascending scalar stores

Owned disjoint scalar copies now support ascending inner-store order for
three or more lanes. The original collector runs first; the new fallback
requires the same plain-read/store, unique-ownership, no-parameter and
source/destination-disjointness proof. It checks actual root-use positions.
It cannot admit effectful prefixes, tees, shared nodes or overlapping locals.

Pass and command tests cover three/four lanes, both store orders, both host
positions, root/loop placement, signed boundaries and repeated cleanup.
Weighted checks distinguish lane swaps. Overlap controls preserve a read
that follows a write to the same local. Native fixtures also expose every
copied lane as a separate result. The previous `5e20bf86` binary fails the
new required wrapper-removal assertion; current native renewal is pending.
See [pass controls](../../../../../src/passes/tuple_opaque_copy_size_regression_wbtest.mbt),
[command controls](../../../../../src/cmd/tuple_opaque_copy_size_regression_wbtest.mbt),
[native fixture](../../../../../tests/fixtures/tuple-optimization/wide-scalar-copies.wat)
and [runtime lane](../../../../../scripts/test/tuple-alias-capture-runtime.ts).

## October 15 batched control retirement

Native checkpoint `972c897d` batches detached scalar-copy control owners until
one checked forest deletion before cleanup or fresh analysis. The old owner
has no body roots, child edges or entry operands while pending. Proven unique
producers remain live until that deletion; each transferred lane keeps its
original read and publication position. The checked deletion still verifies
incoming edges, roots and labels. Private standalone helper callers retain the
immediate checked path. See [the implementation](../../../../../src/passes/tuple_optimization.mbt)
and [bounded ownership controls](../../../../../src/passes/tuple_control_retirement_regression_wbtest.mbt).

A native paired fixture with128 independent opaque two-lane copies has identical
5,979-byte output before and after batching. Seven alternating pairs after one
warmup reduce the traced pass median from6,024 to829µs and quiet CLI median
from10.786 to5.581ms. Width32 falls549 to228µs; width1 rises65 to77µs,
with quiet CLI3.222 to3.231ms. The NOP control is2.911 to2.962ms.
Binaryen133 is512µs and7,490 bytes at width128; this is not a general pass
speed claim. Separate quiet and trace runs, exact binaries, fixture hashes,
commands, raw samples and host records are retained under local
`tuple-size-perf/{functional-batched,timed-batched}` in the report evidence.
All224 raw/metadata-stripped observations agree. The earlier repeated checked
scan regression remains historical evidence; this paired result supersedes it
only for the measured fixtures and exact source delta.

Checked deletion now makes one graph-wide scan rather than one per selected
control. It still allocates incoming-reference scratch, two node bitsets and a
label bitset, and adds a queue of pending control IDs. RSS ranges overlap;
no allocation-free or reduced peak-memory claim follows. The current full
WasmGC suite passes14,242 tests and native tuple/local runtime checks pass12,432
comparisons. A fresh10,000-case combined Tuple campaign remains in progress.

## October 15 native checkpoint and remaining size gaps

Native build `a379e1a3d7d95e79b` contains Tuple source `52673d5a554134b2`.
All 14,171 explicit WasmGC tests and 121 focused controls pass. The expanded
[native lane](../../../../../scripts/test/tuple-alias-capture-runtime.ts) passes
11,704 original/Starshine/Binaryen observations, including earlier call operands,
traps, captured aliases, copy prefixes, typed entries, immutable/mutable argument
boundaries, and multiple pure groups before opaque calls. Raw evidence is in
`.tmp/tuple-alias-runtime-OE4sUN`.

A separate native scalar-source check covers direct and loop layouts at six
signed boundaries through one to four passes. Starshine removes the pair block,
keeps two body locals and six local operations, and stays at 61 encoded bytes.
Inputs are 64/67 bytes; Binaryen 133 emits 71/74 bytes. These are exact small
fixtures, not a general code-size or runtime result. Evidence is in
`.tmp/report-optimization-20261014/tuple-size-current`.

The broader fixture still exposes repeated-pass size gaps: pure captures grow
780→796 bytes, effect cases 2,609→2,669, and source/guard cases 552→576 between
one and two direct passes. Cleanup reduces those results, but does not establish
a direct-pass win. Retaining unprofitable opaque sources and forwarding real
copy consumers needs further proof. The aggregate 10,000-case renewal, larger
copy-size work, and current-source review remain open. This checkpoint supersedes
the older pending native statements below only for the inspected source and
fixtures; preset-slot signoff and historical parity claims keep their scopes.

The next reduced test set finds a separate call-parent carrier error in this
checkpoint. After an opaque pair, a scalar-result copy feeds `local.tee` and an
imported call. Original `run(10)` returns 23 and emits `[11,12,11]`; one pass,
two passes and cleanup return 0 and emit `[11,12,0]`. The output reads an
unwritten scratch local and omits a copied lane store. Native evidence is in
`.tmp/report-optimization-20261014/tuple-opaque-growth/red-native/call-parent/`.
New implementing and dispatcher tests reproduce the error. The prior 14,171-test
checkpoint does not cover these later tests; current-source signoff is open.

The source repair rejects an anchor in the copy producer's own body. That body
is cleared after replacement, so writes placed there cannot survive. The
existing value-subtree carrier keeps the writes at the enclosing use instead.
Current copy collectors take internal definitions directly from that body;
nested payload flattening collects reads, not nested defining stores. Four
separate Call-parent controls and all 114 selected Tuple tests pass. Native
replay and the broader size repair remain open.

## October 15, 2026 copy-carrier anchor repair under validation

A new bounded case exposed a wrong result when a scalar copy block fed a
`local.tee` under a Call. The original returned23 with marker arguments
`[11,12,11]`; frozen native a379 returned0 with `[11,12,0]`, after one pass,
two passes and cleanup. Its emitted code read a fresh local with no write.

The copy path selected an inner store as its staging anchor. The caller then
cleared that copy producer's body, which also removed the staged writes.
Copy anchors inside the producer body are now rejected; the existing carrier
replacement at the outer value use retains the writes. Current result-block
collectors put all internal defining nodes directly in that body. Nested
payload discovery collects reads, not nested defining nodes. Original seed
users lie outside their producer, and synthetic forwarding groups have no
producer to clear. A future collector that admits nested defining regions must
extend this exclusion to every region removed with the producer.

The [pass regressions](../../../../../src/passes/tuple_copy_call_parent_regression_wbtest.mbt)
and [dispatcher regressions](../../../../../src/cmd/tuple_copy_call_parent_regression_wbtest.mbt)
check the exact failure, earlier operands and traps, and a later operand that
observes the copied lane. All4 new tests and all114 prior focused Tuple tests
pass. Fresh native replay and the final full gate remain pending.

## October 15, 2026 source-only size repair under validation

A reduced source-only arithmetic pair kept its result block and added one
scratch local plus a set/get pair on each repeated pass. The recorded native
fixture grew from 88 bytes and two body locals to 92/3, 96/4, 100/5 and 104/6
across four passes. This is a code-size defect, separate from the capture and
effect-order repairs below.

The new narrow path removes an exact prefix-free block of `i32.add` lanes.
Its leaves are i32 constants or parameters with no writes anywhere in the
original function. It requires adjacent reverse-lane plain local stores in
one region, no host tee, and no copy consumer, including masked consumers.
A single precomputed consumer bitset avoids rescanning all groups per source.
Typed block entry operands keep the original carrier path. A depth limit of 32
and one total 128-visit budget across all lanes bound the proof even for shared
scalar graphs; budget exhaustion retains the existing carrier rewrite. It reuses the destination locals
and keeps their original publication positions. A current incoming-edge check
proves that the old block has no other users; after its scalar roots move, the
checked detached-control API deletes the empty block and retires its label.
Mutable parameter reads, destination-local reads, division, calls, prefixes and
interleaved definitions retain the existing staging paths. This first slice
does not extend the proof to other arithmetic instructions.

The [pass tests](../../../../../src/passes/tuple_source_only_size_regression_wbtest.mbt)
and [dispatcher tests](../../../../../src/cmd/tuple_source_only_size_regression_wbtest.mbt)
require a real block removal and first-pass byte saving, stable repeated output,
no added locals or local operations, and exact results at six signed boundaries.
Four size tests failed before the repair; the initial focused suite passed 115
tests. Further independent tests then exposed a typed-entry control-deletion
abort in both pass and dispatcher and excessive proof work on a small shared
scalar graph. Those three tests also failed before their repairs. The repaired focused suite passed 121/121, including typed-entry, proof-budget,
externally initialized guards, multiple source groups, root-lookup and
consumer-mask tests. The native checkpoint above records the later green
WasmGC and runtime/size checks. Additional bounded controls use externally initialized arguments to check
mutable parameters, overlapping reads, division traps, call order and partial
writes without an unrelated early rejection. Two pure source groups followed
by an opaque producer also cover stale analysis and retired node-ID reuse.
No compiler-time or runtime-memory improvement is claimed.

The next size slice is under validation. Existing opaque call-producing pairs
kept their original block but added one local and a set/get pair per pass.
Independent replay confirmed107→111→115→119→123 bytes on a reduced call case,
with unchanged values and events. Result-copy cases also grew after the first
pass; nested copies retained an extra carrier wrapper.

The new direct-copy proof accepts only exact prefix/trailing scalar result
blocks, an outer plain root store, owned plain local reads, increasing and
disjoint payload/destination locals, and no entry operands. It reuses the
existing root-copy helper in the enclosing region, including loops, keeps the
original read node positions and publication positions, and retires only the
proved detached empty carrier through the checked control API. Opaque source
blocks can stay unchanged when their plain stores already provide the needed
lanes and every selected consumer has this direct-copy proof. Explicit plan
bits initialize their original lane locals; other unselected sources still
reject. Supported pure, simple-payload, drop-only, host, overlapping, effectful
prefix and Call-parent paths retain their respective proofs and rewrites.

The [new size pass tests](../../../../../src/passes/tuple_opaque_copy_size_regression_wbtest.mbt)
and [active command tests](../../../../../src/cmd/tuple_opaque_copy_size_regression_wbtest.mbt)
require strict copy-wrapper removal and first-pass saving, stable repeated
bytes/locals/operations, captured aliases, typed entry values, exact effects
and intentional traps. The initial20 tests failed:18 size failures and the2
Call-parent failures repaired above. The size repair is frozen for focused
verification; no final compiler-time, allocation or memory result is claimed.

A subsequent shared-HOT control found that one outer store node can occur at
more than one root site. Moving its inner publications at only the first site
changed43 to33 while keeping the same four call arguments. The direct-copy
proof now requires exactly one outer root use. The current publication planners
also retain the connected tuple component when a defining node has multiple
uses; other components remain eligible. This is a narrow limitation of moving
shared publication nodes, not a restriction on ordinary separately owned
stores. The two direct-IR regressions failed before this repair; focused green
verification is pending.

Explicit precomputed drop-only elision remains protected by the simple-payload
exemption. A wider opaque mixed i32/i64 producer had an older generic staging
path which omitted its original stores but grew105 to107 encoded bytes and two
to three body locals. Retaining that source avoids this self-footprint loss.
Bounded pass and active dispatcher controls check the observable call, result,
validation, unchanged size/local/operation counts and four repeated passes.
This is a comparison with the prior Starshine output; no Binaryen size win is
claimed for this mixed-lane case.

Pure arithmetic plus a copy needs two steps in the current implementation:
the first pass removes the copy wrapper (102 encoded bytes), and the next
removes the now source-only pure block (99 bytes). This is further size
reduction, not repeated growth. Those controls require a strict first saving,
no growth in the second pass, and stable third/fourth results with the same
values, locals and operation bounds. Opaque-source controls still require exact
size stability from the first pass. No one-pass99-byte claim is made.

The combined current-source focused run passes147/147 tests, including shared
publications, the independent component's real size saving, opaque and mixed-lane
size controls, and both SimplifyLocals source-overlap repairs. The explicit
WasmGC suite passes14,219/14,219. Evidence is in
`.tmp/report-optimization-20261014/logs/sl-write-visit-combined-2.log` and
`sl-write-visit-wasmgc-all.log`. The intermediate native checkpoint `a4a765d3`
passes252 original/Starshine observations in six bounded size fixtures: opaque
107B and trapped113B remain stable; root prefix/trailing118B and loop121B shrink
to115B and remain stable through four passes. This does not close Binaryen shape
parity or the separate interleaved-write failure found in its broader cleanup
replay. The fresh combined-source native checkpoint `b29aee1d` passes12,432
Tuple/SL comparisons across the permanent fixture lane, including the previously
failing interleaved writes, SL-nostructure alone and once/twice cleanup. Evidence
is in `logs/write-visit-tuple-runtime.log`; artifacts are in
`.tmp/tuple-alias-runtime-XD80Fm/`. The current generated campaign remains open.

A bounded one-function size comparison keeps metadata policy separate from code.
At widths1/32/128, the C2 checkpoint emits122/1338/5979 raw bytes versus
Binaryen133's104/1697/7490. Starshine retains a25-byte name section. With all
custom sections removed explicitly, the corresponding sizes are97/1313/5954
versus104/1697/7490. At width1 its function body is45B versus52B. Thus the18B
raw excess there is a name-policy difference, not a larger body. All16 raw and16
metadata-free artifacts validate;112 observations in each set agree. The earlier
local harness used default `wasm-tools strip`, which retains names; its results
are preserved and superseded for this measurement by
`.tmp/report-optimization-20261014/tuple-size-perf/functional-canonical/`.
These are metadata-free measurements, not the repository canonical normalizer.
Compiler-time and peak-memory measurements remain pending.

The [root-lookup controls](../../../../../src/passes/tuple_definition_root_lookup_perf_wbtest.mbt)
make no production performance change. `HotUseDef` has no revision/owner token,
and allocating split locals already changes the function revision. Thus old
Child-only use sites cannot justify skipping the current whole-function root
fallback. A test-owned fresh-snapshot candidate is confined to a skipped manual
benchmark; its applicability and timings remain unproved. Supported moved-root
controls and the explicitly unsupported control-below-value-wrapper boundary
are kept separate.

## October 14, 2026 captured-alias repair under validation

Result-block copy discovery used an alias's producer local as both provenance
and payload. A producer can run again while the alias retains an earlier value.
Forwarding the current producer local then changes a saved snapshot. Reduced
loop tests failed with `113` instead of `111`, and with `111` instead of the
initial `0`.

Both result-block layouts now retain the local actually read as copy payload.
Alias resolution still identifies producer provenance and lane. This preserves
optimization while keeping the captured value and its lifetime.

Sources: [six value and payload regressions](../../../../../src/passes/tuple_alias_capture_regression_wbtest.mbt),
[command regression](../../../../../src/cmd/tuple_alias_capture_regression_wbtest.mbt),
and [V8 runtime lane](../../../../../scripts/test/tuple-alias-capture-runtime.ts).
Focused value tests pass. Final runtime, default-suite and 10,000-case v133
results remain pending; historical closure below did not cover this alias case.

### Nested source staging repair under validation

An independent V8 replay found a pre-existing nested carrier defect after a
second `tuple-optimization` pass following local cleanup. A mixed copy returned
`[11, 0]` instead of `[11, 100]`. A direct reduced nested block or loop reproduced
the failure with both the baseline and current CLI; the same function-level
statements retained the correct result.

The nested source path placed split-local writes inside a later carrier while
an earlier lane use read one of those new locals. An initial repair admitted
the preceding-root staging path in nested regions. Fresh native replay then
found a repeat-pass defect in that path: an arithmetic pair returned `111`
after one pass and `11` after two. A scratch-lane read preceded its new staging
write.

The root path now proves that every definition reaches a root in the same
region, directly or through single-child local-write/drop wrappers or the first
operand of a direct call. A call's later operands and call effect follow that
first operand. The pass stages private split locals before the earliest such
root, and publishes each original local at its original write or tee position
and source order. Thus an interleaved read observes the correct publication.
Other parent shapes retain the existing carrier rewrite. Opaque producers
retain one evaluation; simple payload cloning remains restricted to proved
constant and local-read lanes.

The staging roots also retain the producer's original evaluation order. Root
position alone does not prove that an earlier operand, still carried on the
wasm stack, has run. After cleanup separated a tee into a store/reload, a second
Tuple pass could place producer calls before an earlier call or division trap.
All 16 separate pass/dispatcher boundary tests failed before this position
repair. Reduced function-root cases also fail with the saved baseline; the
reduced loop cases are regressions against that baseline. Preserving the old
producer position uses the lowerer's existing pending-operand contract and
retains the supported source transform.

Sources: [direct and bounded effect/loop regressions](../../../../../src/passes/tuple_nested_overlap_regression_wbtest.mbt),
[encoded command regression](../../../../../src/cmd/tuple_nested_overlap_regression_wbtest.mbt),
[repeated synthetic-carrier regression](../../../../../src/passes/tuple_repeated_synthetic_carrier_regression_wbtest.mbt),
and [its command regression](../../../../../src/cmd/tuple_repeated_synthetic_carrier_regression_wbtest.mbt).
The [call-operand boundary tests](../../../../../src/passes/tuple_call_operand_boundary_regression_wbtest.mbt)
and [dispatcher tests](../../../../../src/cmd/tuple_call_operand_boundary_regression_wbtest.mbt)
cover original and reduced forms, direct Tuple, cleanup, a second Tuple pass,
and repeated cleanup, with exact call arguments and a trap-before-producer case.
Both repeated-carrier tests failed with `11` instead of `111` before the staging
repair. Interleaved-call variants also establish partial publication: the
original returns `100` with calls `[11, 100, 100]`, while the frozen native pass
returns `0`, with calls `[11, 100, 0]` for a set or `[0, 11, 100]` for a tee. The
first staging edit passed 85 focused tests but still failed both new tee tests;
the wrapper proof addresses that separate source path. The first Call operand
also returned `0` with calls `[0, 0, 11, 100]`; its permanent controls cover a
later operand with effects. The final focused run passes all 113 selected
Tuple and adjacent packed-field tests, including all 16 evaluation-order
boundary tests. Fresh native runtime, full-suite, and dedicated v133 checks
remain pending for this revision. Broad performance and size effects remain
unmeasured; the bounded size result below covers one fixture.

For the existing three-result `tri` / `show` host-tee fixture, the new route
keeps lane zero on the stack. Actual encoded test output uses six i32 locals
and ten local operations, versus seven locals and twelve operations in the
previous native output. With custom and export sections removed uniformly, its
module/code payload sizes are `99/39` bytes, versus `103/43` before and `111/51`
for v133. The original input is `93/33`, so tuple scalarization still adds six
bytes on this fixture. V8 replay of the actual bytes preserves all three
distinct result values, the `tri` arguments, and one ordered call to each
import, including signed-limit values. The
[host-tee regression](../../../../../src/passes/tuple_optimization_wbtest.mbt)
and [dispatcher regression](../../../../../src/cmd/cmd_wbtest.mbt) now check
those values and direct local opcodes instead of the superseded rendered
substring. This is a measured size improvement on one fixture; it is not a
native speed or runtime-memory measurement.

### Copy prefixes retain effects and traps

Copy discovery previously discarded the prefix returned by payload splitting.
A tuple or nested scalar-lane prefix could then lose calls or division traps.
Baseline and frozen native output returned `111` without the original call `9`;
a trapping prefix incorrectly returned normally. Separate bounded call and
trap tests failed in the pass and dispatcher before repair.

Pure copy forwarding now requires an empty prefix at the producer, nested lane,
and scalar trailing-copy boundaries. Prefix-bearing copies stay as opaque
producers, so the existing source rewrite retains their original effects and
traps. Prefix-free copies still use scalar forwarding. Forwarding an arbitrary
prefix separately from its payload remains unsupported; this is a correctness
limit, not a measured output-shape win over v133.

Sources: [pass regressions](../../../../../src/passes/tuple_prefix_effect_regression_wbtest.mbt)
and [dispatcher regressions](../../../../../src/cmd/tuple_prefix_effect_regression_wbtest.mbt).
Fresh native and full-suite checks remain pending for this revision.

## September 24, 2026 alias-chain measurement

Scalar copy-source resolution now walks an alias chain iteratively and appends each read node once. The previous recursive return built a new prefix array at every hop. The [native white-box benchmark](../../../../../src/passes/tuple_alias_chain_perf_wbtest.mbt) times the resolver itself on prebuilt HOT functions: 128 hops fell from `8.55` to `1.61 µs` (5.31×), and 256 from `17.01` to `3.35 µs` (5.08×). A direct order assertion and 61 existing tuple optimization white-box tests pass. This is helper-level synthetic evidence; other full-pass costs remain outside this measurement.

## September 24, 2026 passthrough-chain measurement

The root passthrough-chain finder now collects local tee/set ancestors in one mutable array instead of copying a growing array on every recursive step. Its [native white-box benchmark](../../../../../src/passes/tuple_passthrough_chain_perf_wbtest.mbt) uses a constant nested through local tees and a terminal set: at 128 tees, mean helper time fell from `6.20` to `1.18 µs` (5.25×); at 256, from `13.05` to `2.22 µs` (5.88×). The direct chain-order assertion and 61 existing tuple optimization white-box tests pass. This is helper-level evidence, with full-pass impact still unmeasured.

> **Comparison baseline:** New comparisons use [Binaryen 133](../../release-horizon-and-oracles.md). Earlier sources, commands, artifacts, and results retain their historical versions and do not establish v133 signoff.

## 2026-09-01 production candidate-free raw gate

The canonical 4,977,401-byte artifact contained thousands of scalar-only functions that could not form a TupleOptimization seed group, but the dispatcher still lifted each function, built use-def, and ran both root-group scans. A new fail-closed raw classifier recursively checks every nested instruction sequence for a static multi-result producer. It resolves direct and indirect/reference call signatures plus type-indexed `block`, `loop`, `if`, and `try_table` results through the cached module context; any unresolved signature is treated as a possible candidate and falls back to the full HOT path.

The candidate-free check runs before the older ownership-hazard probes, making scalar-only functions one-scan no-ops while preserving the hazard fallbacks whenever a real multivalue producer exists. On the production artifact, 11,767 functions take the candidate-free skip, 86 retain the effect-bracketed-call skip, 13 retain the load/call/set skip, and only 133 enter HOT lifting and the pass. Red-first tests lock both the scalar hazard ordering and the multivalue hazard fallback. A production-derived 2,000-function native-release benchmark fail-closes unless every scalar function takes the raw skip and measures `1.34ms ± 9.46us` on the AMD Ryzen 7 8845HS with MoonBit `0.1.20260713`.

Matched clean-HEAD/current one-warmup/three-sample medians reduce no-trace command `2,502.949ms -> 897.562ms` (`2.789x`, `-64.140%`), pass-local `302.034ms -> 8.113ms` (`37.228x`), HOT lift `642.690ms -> 8.197ms` (`78.406x`), and the optimizer pipeline `1,772.302ms -> 181.221ms` (`9.780x`). Paired recorded Binaryen v131 is `501.621ms` command / `3.709ms` pass-local; Starshine's `1.789x` command ratio clears the `<=1.053s` absolute gate by `155.438ms`. The remaining low-absolute candidate-heavy pass ratio remains covered by the existing 2026-06-30 soft acceptance.

Every measured output is byte-identical to the pre-change 4,976,841-byte result at SHA-256 `4b616a392d85a2c2dbf52ea08b27ad99cc07351a166838c0eaab2d9d6733d172`. Regular explicit-v131 GenValid is `10000/10000` normalized with equal canonical bytes and zero failures. The dedicated 10,000-case profile still produces the established pure/drop-only scalar-spelling family: all cases validate, Starshine is canonically smaller in all 10,000, and there are no property, generator, or command failures. `[P0-WALL-TUPLE]` is closed.

Evidence lives under `.tmp/tuple-production-baseline-matched-20260901-*`, `.tmp/tuple-production-final-clean-20260901-*`, `.tmp/pass-fuzz-tuple-final-clean-regular-10000-20260901`, and `.tmp/pass-fuzz-tuple-final-clean-dedicated-10000-20260901`. The final native binary is SHA-256 `bbfa580e0e1fdcf267a1e0c313498df8f90a911b923dedd0cd40fe6c36c71cca`.

## 2026-09-01 Moon component benchmark and shared HOT lower suffix index

A reusable native-release benchmark now reconstructs the established candidate-heavy contract as one function with 2,000 independent two-lane type-indexed pure/drop-only spills. It separately measures HOT lift, lowering after TupleOptimization, and the registry-dispatched pipeline. Across five matched clean-`04adcce0e`/current runs, median mean lift is neutral (`39.14ms -> 39.18ms`), HOT lower improves `467.70ms -> 11.41ms` (`-97.560%`, `40.990x`), and the complete pass pipeline improves `522.63ms -> 88.72ms` (`-83.024%`, `5.891x`).

The lowerer owner was the future-root dependency proof: every local-reading root could rescan all later roots even when no later root contained an effectful value created before the current root. Large regions now build one memoized minimum dependency id per node and one suffix minimum over region roots. The minimum deliberately traverses beneath later impure parents because the original threshold-sensitive collector does so when the parent itself is not old enough; regions below 64 roots retain the original exact scan. Red-first white-box coverage locks pure roots, direct earlier effects, nested earlier effects beneath later impure parents, and the region local-read gate. The first incomplete fallback experiment changed call order on the production artifact and was rejected; the final optional-index fallback restores exact bytes.

This is a synthetic shared-lowerer win, not a production-artifact speedup. Final one-warmup/three-pair production medians preserve the 4,976,841-byte raw output at SHA-256 `4b616a392d85a2c2dbf52ea08b27ad99cc07351a166838c0eaab2d9d6733d172`: clean/current no-trace is `1945.067ms -> 1955.632ms`, pass-local `268.023ms -> 272.397ms`, lift `568.033ms -> 575.643ms`, and lower `9.572ms -> 9.675ms`, all neutral host noise. Paired Binaryen v131 was `510.266ms` process / `3.713ms` pass-local, so `[P0-WALL-TUPLE]` remained open at this checkpoint; the production candidate-free raw gate documented above supersedes that status and closes it. Regular explicit-v131 GenValid is `10000/10000` normalized with zero failures and equal canonical bytes; the shared RUB recheck is `278` normalized plus `9722` cleanup-normalized with zero residual mismatches or failures.

## Binaryen v131 renewal status

Closed on July 28, 2026. `TupleOptimization.cpp` is byte-identical between v130 and v131 at SHA-256 `2809e78bb844a8a910c68def6caabaa7ddfcb8df4e3103d5d83ae9beb474e264`. The dedicated lit delta changes four bottom-valued `local.tee` expectations to `local.set` in the unreachability families; the tuple-local analysis and scalarization owner did not change.

A focused v131 source-WAT probe confirmed the new Binaryen `local.set` spelling. After wasm serialization, both Binaryen and Starshine canonicalize the reduced `unreachable.tuple.extract` probe to the same valid 30-byte `unreachable` function. Focused tuple tests pass `56/56`; explicit-v131 ordinary GenValid is `1000/1000` exact. A 100-case dedicated profile reproduces only the already approved pure/drop-only scalar-spelling wins: all 100 cases have zero effects/traps, Starshine is smaller in every case (`-22` bytes for spill; `-20` for tee and copy-chain), and there are no validation, property, generator, or command failures. No implementation slice is opened.

## Role

- `tuple-optimization` is an active implemented **hot pass** on Starshine's explicit pass surface.
- In upstream Binaryen `version_129`, it is a narrow tuple-local cleanup pass that splits safe tuple scratch locals into scalar locals before later local-cleanup passes run.
- The pass is easy to overstate.
  - It is **not** a general multivalue optimizer.
  - It is **not** a broad CFG-driven tuple dataflow pass.
  - It is **not** the pass that folds direct `tuple.extract(tuple.make(...))`; Binaryen does that earlier in `optimize-instructions`.

## Why this dossier still needed a refresh

The tracker no longer had any pass with wiki status `none`, so this thread had to justify an already-`deep` fallback.
`tuple-optimization` was the best major-gap fallback because:

- it still matters on the canonical no-DWARF function path:
  - `precompute -> code-pushing -> tuple-optimization -> simplify-locals-nostructure`
- it also still appears repeatedly in the saved generated-artifact optimize log, including later nested `precompute-propagate -> code-pushing -> tuple-optimization` reruns
- the existing folder already had the required living pass pages, but it still lacked an immutable raw primary-source manifest tying the reviewed official release page, source files, and dedicated lit file together in the raw-source system
- several living pages still relied on 2026-04-20 / 2026-04-21 freshness wording without one compact 2026-05-04 provenance anchor that connected those upstream surfaces directly to the exact Starshine code map
- this refresh therefore closes a provenance-and-navigation gap, not a missing-overview or missing-strategy gap

So this refresh is not a tracker-status promotion.
It is a source-backed clarification pass over a real existing dossier.

## Most important durable takeaways

- Upstream Binaryen is optimizing **tuple locals**, not multivalue syntax in general.
- The pass approves only a narrow writer/reader surface:
  - writers from `tuple.make` or tuple-local copies
  - readers through `tuple.extract` or tuple-local copies
- Copy-connected tuple locals succeed or fail together.
  - If one member escapes, Binaryen poisons the whole component.
- Tee preservation is part of the core contract, not a corner case.
- The pass is deliberately lightweight.
  - It does **not** depend on CFG, effects, liveness, dominance, or refinalization helpers.
- The real payoff comes later.
  - `tuple-optimization` exposes scalar locals so later local passes can remove dead lanes and dead copies.
- A narrow 2026-05-04 freshness check found no current-main drift in the core upstream pass file, the dedicated lit suite, or the tuple-specific scheduler / peephole sections relevant to this dossier.
- Direct tagged source URLs plus the retained 2026-05-04 current-main recheck record that the reviewed official Binaryen `version_129` release page observed on 2026-04-22 showed publish date **2026-04-01**.

## Current status summary

- The explicit Starshine pass exists and is wired into the pass manager and CLI.
- The public `optimize` and `shrink` presets now include the pass in the documented `precompute -> code-pushing -> tuple-optimization -> simplify-locals-nostructure -> vacuum -> reorder-locals -> remove-unused-brs -> heap2local` neighborhood. The historical large debug artifact is absent in this workspace, but the available candidate-heavy exact-slot neighborhood replay is green under normalized WAT and canonical function comparison.
- Final direct-pass closeout completed on 2026-06-30: regular GenValid `100000 / 100000` normalized with zero failures; random all-profiles `10000 / 10000` normalized with zero failures; wasm-smith had one unreachable-control-debris raw mismatch and known Binaryen/tool command failures, with the raw mismatch reduced by the documented normalizer.
- The dedicated `tuple-optimization-all` GenValid profile deliberately remains raw-red (`10000 / 10000`) but is now classified as a narrow measured Starshine-win scalar-spelling family for simple type-indexed pure/drop-only spill/tee/copy-chain cases: no effect/trap facts and uniform raw/text/local/op wins for Starshine across all sampled cases.
- Candidate-heavy pass-local performance is soft-accepted under the user's 2026-06-30 caveat after reasonable TO-owned optimizations were exhausted. Final measured direct timings are `0.122/0.037`, `0.460/0.148`, `0.892/0.301`, and `1.705/0.580` ms at 100/500/1000/2000 pairs.
- Raw normalized WAT text is still too strict to use as the only tuple-opt parity oracle.

## 2026-08-28 shared HOT lift checkpoint

The order-of-magnitude inventory attributed most artifact-scale command overhead around this pass to shared HOT lifting rather than the tuple transform alone. The retained IR checkpoint now:

- derives defined-function indices without rescanning imports;
- preserves compressed local declaration runs for validation;
- reuses known function results and builds one validation environment;
- allocates the initial all-initialized local bitmap by compressed length;
- caches repeated scalar and simple block-result type IDs without repeated string construction.

An alternating clean-HEAD/current comparison on the canonical 4,977,401-byte artifact reduces median HOT lift from `1,067.202ms` to `595.670ms` (`-44.2%`) and no-trace command from `2,762.360ms` to `2,264.276ms` (`-18.0%`), while tuple pass-local time remains neutral at about `285.3ms`. All paired outputs are byte-identical at 4,976,841 bytes, SHA-256 `4b616a392d85a2c2dbf52ea08b27ad99cc07351a166838c0eaab2d9d6733d172`.

The shared change also reduces single-sample lift attribution from the inventory baselines for RemoveUnusedNames (`822.383ms` to `432.602ms`), Heap2Local (`1,600.031ms` to `862.847ms`), and SimplifyLocalsNoNesting (`1,617.657ms` to `857.347ms`). These are cross-pass smoke comparisons, not replacement medians for each pass dossier.

Moon validation is 1,753/1,753 validate-package, 366/366 IR-package, 7,047/7,047 pass-package, and 10,737/10,737 full. The renewed ordinary tuple lane is 10,000/10,000 normalized with zero failures or mismatches; runtime-callable self semantics are exact 100/100. TupleOptimization remains an open wall-time P0 because its transform and function/pre-pass envelope still dominate the remaining gap.

## Biggest beginner correction

The safe mental model is:

- Binaryen uses this pass to split **safe tuple scratch storage** into scalar locals early enough that later local-cleanup passes can do better work.

The unsafe mental model is:

- “tuple-optimization” is where Binaryen lowers all tuple or multivalue constructs.

That broader reading is not what the source file or test suite implement today.

## Page map

- [`./binaryen-strategy.md`](./binaryen-strategy.md)
  - Exact upstream `version_129` algorithm: early gates, `uses` / `validUses`, symmetric copy graph, badness propagation, contiguous scalar-local allocation, `MapApplier`, and tee-preserving rewrites.
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md)
  - The upstream file map, helper dependencies, validation/finalize neighbors, official lit families, the immutable raw primary-source anchor, and the narrow current-main freshness note.
- [`./wat-shapes.md`](./wat-shapes.md)
  - Beginner-friendly catalog of the official positive and negative tuple-local shapes Binaryen rewrites or deliberately leaves alone, plus the HOT-native equivalents Starshine sees after lift.
- [`./starshine-strategy.md`](./starshine-strategy.md)
  - The current in-tree Starshine strategy page: exact direct-pass status, HOT-native strategy summary, and the shortest path to the code map.
- [`./starshine-hot-ir-strategy.md`](./starshine-hot-ir-strategy.md)
  - The deeper HOT-native implementation dossier, including the exact owner-file and line-location map for the main analysis, rewrite, wiring, and test surfaces.
- [`./implementation-map.md`](./implementation-map.md)
  - Exact MoonBit owner-file map for registry wiring, analysis clusters, rewrite clusters, cleanup clusters, and the focused wbtest / CLI / native-oracle lanes.
- [`./scheduler-and-gates.md`](./scheduler-and-gates.md)
  - Exact Binaryen slot, multivalue gate, and why the public Starshine presets still keep tuple-opt off even though the explicit pass exists.
- [`./reduced-repros-and-evidence.md`](./reduced-repros-and-evidence.md)
  - The reduced repro families that drove the Starshine implementation and the current evidence map for those families.
- [`./parity.md`](./parity.md)
  - The current signoff state: strong direct isolated parity, canonical full-artifact compare status, open preset-slot proof, and remaining runtime debt.

## Freshness note

The direct Starshine pass was revalidated on 2026-05-06 with the refreshed pass-fuzz harness, keeping explicit-pass parity green while leaving preset-slot proof separate.

The reviewed official Binaryen release page on 2026-05-04 still showed `version_129` as the stable oracle, and the fresh current-main bridge keeps that provenance explicit.
A narrow 2026-05-04 comparison against current GitHub `main` found:

- `src/passes/TupleOptimization.cpp` unchanged from `version_129`
- the relevant `pass.cpp` scheduler / registration lines unchanged
- the tuple-specific `OptimizeInstructions.cpp` peephole section unchanged, even though the file has unrelated drift elsewhere
- `test/lit/passes/tuple-optimization.wast` unchanged

That means the tuple-opt dossier does **not** currently need a current-main drift warning on its core upstream surfaces.

## Current maintenance rule

- Treat this folder as the canonical home for Binaryen tuple-opt behavior, scheduler meaning, Starshine HOT-native strategy, exact local code ownership, and parity notes.
- Keep the main beginner correction explicit:
  - upstream `tuple-optimization` is a tuple-local scratch-storage splitter, not a generic multivalue optimizer.
- Keep the division of labor explicit between:
  - `optimize-instructions` handling direct `tuple.extract(tuple.make(...))`
  - `tuple-optimization` splitting safe tuple locals
  - later local-cleanup passes realizing the scalarization payoff
- If new work only changes raw normalized WAT while canonical per-function compare stays green, classify that as compare-surface or materialization noise first, not immediately as a tuple-opt semantic regression.
- Keep [`./starshine-hot-ir-strategy.md`](./starshine-hot-ir-strategy.md) and [`./implementation-map.md`](./implementation-map.md) in sync whenever a fix moves the owning helper cluster or the owning local test lane.

## Sources

- research note 0254
- research note 0239
- research note 0144
- research note 0076
- [research note 0115](../code-pushing/index.md)
- [`../../../../../src/passes/tuple_optimization.mbt`](../../../../../src/passes/tuple_optimization.mbt)
- [`../../../../../src/passes/tuple_optimization_wbtest.mbt`](../../../../../src/passes/tuple_optimization_wbtest.mbt)
- [`../../../../../src/cmd/cmd_wbtest.mbt`](../../../../../src/cmd/cmd_wbtest.mbt)
- [`../../../../../src/cmd/cmd_native_wbtest.mbt`](../../../../../src/cmd/cmd_native_wbtest.mbt)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [research note 0093](../late-pipeline-dispatch.md) preserves the saved generated-artifact `-O4z` slot, summary, and Binaryen debug-log facts; older `.artifacts` paths are replay identifiers, not durable wiki source links.
- Binaryen `version_129` sources:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/TupleOptimization.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/OptimizeInstructions.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/wasm/wasm.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/wasm/wasm-validator.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/tuple-optimization.wast>
- Narrow freshness-check surface:
  - <https://github.com/WebAssembly/binaryen/blob/main/src/passes/TupleOptimization.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/tuple-optimization.wast>
