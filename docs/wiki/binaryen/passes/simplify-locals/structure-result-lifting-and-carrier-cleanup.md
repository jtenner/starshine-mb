---
kind: concept
status: supported
last_reviewed: 2026-10-15
sources:
  - ./index.md
  - ../../../../../src/passes/simplify_locals.mbt
  - ../../../../../src/passes/simplify_locals_test.mbt
  - ../../../../../src/passes/pass_manager_wbtest.mbt
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./wat-shapes.md
  - ./starshine-hot-ir-strategy.md
  - ./implementation-map.md
  - ./raw-lane-and-writeback.md
---

# `simplify-locals` structure-result lifting and carrier cleanup

## October 15 current finalization checkpoint

Native `193e58a7` passes all 14,267 WasmGC tests and 12,288 independent numeric
runtime comparisons. It includes the declaration-only repair below. After
changed-module local finalization, SL reuses the existing checked cleanup for
independent plain function types. This remaps all module type uses, including
unselected typed blocks, exported tags and public callback globals; local
regrouping stays selected. Ordinary custom/offset metadata and recursive, GC,
shared or descriptor type forms retain the existing conservative boundaries.
The two new [type-cleanup controls](../../../../../src/passes/simplify_locals_type_cleanup_regression_wbtest.mbt)
fail first, then check independent expected types, bytes, values and module-wide
indices. Four exact hash-verified replays now pass independent validation on this binary:
case496 shrinks160→148B (Binaryen133152B),4475 shrinks370→351B (366B),
5132 shrinks254→243B (253B), and control3 remains88B for both. These close
those three specific losses, not all154 older raw losses. Runtime renewal and
a fresh aggregate remain required. Evidence: local
`review/sl-bulk-data-types-loss-replay/result.json`.

Exact data-section sizing now counts shared immutable payload lengths without
copying their bytes. On a 2 MiB data fixture with one eligible function, quiet
command time is 8.120 to 7.317 ms and child peak RSS 30,584 to 26,900 KiB;
with 1,000 functions, 36.201 to 34.760 ms and 30,880 to 28,872 KiB. Output bytes
agree. These seven-pair `d74c3902` to `193e58a7` measurements isolate neither
whole-pipeline gains nor output memory use. Mixed 128-function control time
regresses 7.179 to 7.558 ms in all seven pairs; this remains a measured cost to
repeat and inspect. Full O4z 1,000-function time remains 1,751.834 ms versus
Binaryen133's explicitly different `-O4 --shrink-level=2` policy at 60.896 ms.
The 3-byte Starshine size win does not close this runtime gap. A repeat of the
same frozen d74→193e mixed128 comparison gives6.5543/6.5540ms medians,
MAD0.1051/0.0515ms, with four slower pairs and paired median+0.1119ms.
The original0.378ms loss is not reproduced as a stable cost. The exact fixture
has two distinct types, both used in headers; existing pruning returns before
walking bodies. A new header preflight would duplicate that proof. All bytes
agree. The same-type1000 repeat is26.313/26.560ms with five slower pairs.
Preserve these controls and their noise limits in local
`sl-local-group-perf/timed-bulk-data-types-repeat/`. Raw evidence is
under local `sl-{local-group,large-group,large-group-preset}-perf/`.


## October 15 numeric declaration grouping

The independent Claude review found that the shared frequency-order candidate
could also remove unused locals and their names above index128. Native replay
confirmed full SL changing131 locals to1 and dropping two unused names; the
earlier binary retained them. Two new implementing/command controls fail before
the fix. SL now requests declaration grouping only, while OptimizeInstructions
keeps frequency ordering by default. All45 selected controls pass, including
the no-structure spelling alias. This also skips the extra frequency parameter
cache on positive SL admission. The new full/native gate is running. All native
`972c897d` timings and checks below predate this later fix; no new cost or
full-source signoff is inferred from them.


After changed-body writeback, `simplify-locals` and
`simplify-locals-nostructure` now try the existing checked numeric local-group
candidate. The spelling alias has the same admission. Other SL modes keep
their existing behavior. All seven writeback paths use the same predicate.
The preflight skips identical modules, unchanged/untouched functions, reference
locals, and layouts without a repeated numeric declaration group. It allocates
a touched mask only after finding an eligible body. The shared candidate keeps
parameters fixed, remaps body indices and decoded names, retains metadata/EH
guards, validates changed bodies, and requires fewer complete encoded bytes.
See [the helper](../../../../../src/passes/simplify_locals.mbt),
[writeback integration](../../../../../src/passes/pass_manager.mbt),
[implementing tests](../../../../../src/passes/simplify_locals_local_groups_regression_wbtest.mbt),
[dispatcher tests](../../../../../src/cmd/simplify_locals_local_groups_regression_wbtest.mbt)
and [writeback-path tests](../../../../../src/passes/simplify_locals_local_group_writeback_regression_wbtest.mbt).

Six missing-behavior controls failed before implementation. A later endpoint
control exposed inconsistent mode admission; the shared predicate fixes it.
All21 new controls and the complete14,242-test WasmGC gate pass. The retained
raw-size cases2/11 improve from160/92 to150/88 bytes; the earlier1,453 raw
campaign losses are historical counts, not current signoff. A fresh aggregate
10,000-case campaign completes; the exact counters and remaining losses follow below.

Native checkpoint `972c897d` versus `b29aee1d` has119,224 matching executed
observations over four raw/metadata-stripped fixtures, including every function,
signed boundary arguments, fixed i64 parameters and exact import events. Mixed
numeric declarations save4B/function:32,751 to28,751B for1,000 functions,
versus29,751B from Binaryen133. Seven paired quiet CLI medians increase25.668
to26.687ms there; the same-type negative control is25.019 to24.799ms with
identical bytes. This is a measured size/compile-cost tradeoff, not a compiler
speed gain. The pass timer excludes boundary work and cannot price the grouping
alone. Candidate validation, remapping and complete encoding allocate work on
positive admission. Process RSS overlaps and does not prove lower allocation or
retention. Raw samples, controls, source/build hashes and commands are retained
under local `sl-local-group-perf/{functional,timed}` in the report evidence.

A separate [numeric runtime lane](../../../../../scripts/test/simplify-locals-numeric-groups-runtime.ts)
adds 12,288 comparisons against independent contracts. It executes live i64,
f32 and f64 body locals through root, loop and conditional code; checks both
SL modes once and twice against Binaryen133; and preserves signed zero,
infinities and raw quiet/signaling NaN payloads through reinterpret operations.
Fixed floating parameters, exact import order and pre-publication traps are
observed. Encoded local vectors must change from eight groups to four in all
three Starshine bodies. The previous `b29aee1d` binary fails that assertion;
current `972c897d` passes. This supplements the i32 fixture executor rather than
claiming that declaration validation executed the floating values.

## October 15 completed grouping aggregate and remaining raw losses

Checkpoint `972c897d` completes 10,000 `simplify-locals-all` comparisons with
verified Binaryen 133. All semantic observations, determinism and codec checks
agree. There are 9,620 structural differences and 380 normalized matches.
Raw totals are 1,884,822 versus 2,082,380 bytes: 9,342 Starshine-smaller,
504 equal and 154 Starshine-larger cases. Canonical totals are 1,864,179 versus
2,080,551 bytes, with no canonical losses. These numbers predate the later
named-local declaration-only repair and caller fixes.

The 154 raw losses total 306 bytes: 141 structure-result cases contribute
283 bytes, 12 stress cases contribute 22 bytes, and one effect-order case
contributes one byte. None is retained by the structural artifact cap.
Four exact seed/input-hash replays independently reproduce cases 496, 4475,
5132 and equal-size control 3. Extra type bytes exceed removed code bytes
in all three loss probes. They remain size/parity gaps; canonical size alone
is insufficient evidence of a Starshine benefit.

All 20 retained bundles are raw-smaller. Fresh export-only copies preserve
all non-export sections and execute all 91 defined functions, with 451 calls
per variant (1,353 expected-contract checks) and no differences. This includes
previously uncalled functions and null/non-null reference controls. It does
not inspect every unretained output or prove that every family is optimal.
Raw evidence: `.tmp/report-optimization-20261014/review/sl-final-batched-*`.

## October 15 current captured-read/write repair verification

Native `b29aee1d` completes10,000 `simplify-locals-all` comparisons with verified
Binaryen133 and Node26. All10,000 observations agree; validation, determinism and
codec checks pass with no blocked runtime or tool failures. There are380
normalized matches and9,620 structural differences. This campaign includes both
read/write-visit guards, unlike the earlier checkpoint below. The same binary
passes12,432 permanent Tuple/SL observations, including both reduced wrong-result
cases, and the explicit WasmGC suite passes14,219 tests.

All20 retained bundles are independently inspected. Review-only copies export
all91 defined functions;451 fresh-instance invocations per variant (1,353 total)
match values, traps, imports, globals, memory and tables. This executes retained
bodies that had no exports in the original campaign. It does not execute all
unretained unexported functions or prove function/table-reference identity.

Raw quality remains open:7,757 outputs are smaller,790 equal and1,453 larger,
with a worst32B excess. Aggregate raw bytes are1,906,726 versus2,082,380;
repository-canonical bytes are1,864,179 versus2,080,551. Canonical savings do not
close individual raw losses. Cases2/11 are160/92B versus Binaryen151/90B, without
custom sections. Repeated numeric local-declaration groups add10/4B; case2 also
has an unused3B type. Instruction bytes already save4/2B. A guarded existing
local remapper can address the declaration cost; raw names, decoded local names,
parameters, offset metadata and index-LEB costs need focused controls and measured
cost before admission. Keep this separate from the repaired value faults.

A pinned seven-pair native check compares the old scanner with the guards on
64/512/4096 write sequences. Outputs are byte-identical and60 original/optimized
signed-input observations pass. Quiet medians are2.082/5.624/222.200ms before and
2.028/5.588/213.488ms after; RSS ranges overlap. A no-change control moves
24.040→24.372ms in the first run and24.271→24.035ms in the reversed-order repeat.
These bounded samples establish no consistent control regression or general
speed/memory gain. Raw samples, commands, hashes and host snapshots are retained.

Evidence: `.tmp/report-optimization-20261014/fuzz-write-visit/simplify-locals/`,
`review/sl-write-visit-families.txt`, `review/sl-write-visit-replay/` and
`sl-guard-perf/`. The source snapshot is in `native-write-visit-corrected/`.

## Earlier October 15 semantic renewal and execution limits

A fresh 10,000-case `simplify-locals-all` campaign uses native checkpoint
`a379e1a3`, unchanged repaired SimplifyLocals source, Node 26.11.1 and verified
Binaryen 133. Runtime-backed oracle commands disable compact-import encoding;
the earlier 1,829 discrepancy labels were blocked Binaryen compilations in Node,
not established semantic differences. The new campaign has 10,000 all-equal
observations, no validation/tool/runtime-blocked failures, deterministic bytes
and stable codecs. There are 380 normalized matches and 9,620 structural
differences. Raw evidence is in
`.tmp/report-optimization-20261014/fuzz-current/simplify-locals/`.

Execution is limited by generated interfaces. The complete manifest has 7,106
modules with exported functions and 2,894 family-coverage modules with no
exports, start function or imports. Those latter labels compare instantiation,
not execution of their 140-instruction bodies. All modules contain instructions;
metadata does not count each individual empty function body.

Independent review reads all 20 retained bundles. For four retained modules
without exports, copies receive matching exports for ten functions and their
memory, table and global. The other sections remain byte-identical; no optimizer
is used during instrumentation. These copies add 112 invocation-plan steps and
16 direct null/effect/resource scenarios. Original, Starshine and Binaryen
observations agree, including four null traps, memory hashes, global writes and
table changes. This does not execute all 2,894 unexported modules.

The inspected five macro families have source-backed canonical-size wins and
no larger canonical function bodies in the retained set. This is an agent
judgment for those inspected families. Raw encoding still loses in 1,453 cases
(7,539 bytes in total losses), including two retained bundles. Unretained shapes
and the aggregate DAE2/stress differences are not all decoded independently.
Keep raw-size and broader parity work open; no runtime or memory gain is claimed.
The local review record is
`.tmp/report-optimization-20261014/review/simplify-locals-current-families.txt`.

A later reduced overlap case exposes a correctness error outside that inspected
set. Local1 is initialized from the parameter, read by both lanes of a pair
block, then overwritten by one result. Original `run(10)` returns 23;
`simplify-locals-nostructure` alone returns 3 on native checkpoint `ff2b172e`.
Prior Tuple staging masks the error, while retaining its producer exposes it.
The generated renewal does not close this new read/write lifetime blocker.
Evidence is in
`.tmp/report-optimization-20261014/tuple-opaque-growth/mutable-cleanup-probe/`.

## October 15, 2026 captured reads and repeated publications

Equivalent cleanup can visit a shared physical read more than once. The first
read snapshot must remain attached to that node; replacing it on a later visit
can turn an initializing tee into a self-copy. The reduced case above fails
before the read guard and passes after it.

A separate interleaved-write case shows that the read guard alone is not enough.
The producer reads local1, one lane is consumed, local1 is set to99, then the
other lane is consumed. Additional parameter contributions keep the surrounding
reads observable. Two of three reduced tests fail before the write repair.
Native checkpoint `a4a765d3` returns -2147483645 instead of102 for the retained
`publication_2` input under the Tuple/SL/Coalesce/Vacuum pipeline.

Only the first visit to a physical write may establish an alias. Every visit
still advances the destination version; a repeated visit resets its alias.
Read and write markers share the existing per-node table. Their node IDs are
disjoint, and the source-read helper admits only `LocalGet`. This adds no array
or public API. It can conservatively lose a repeated-write optimization; no
runtime or memory gain is claimed.

The combined focused tests pass147/147; the explicit WasmGC suite passes
14,219/14,219. Independent source review finds no further confirmed defect in
this repair. Fresh native checkpoint `b29aee1d` passes12,432 Tuple/SL
comparisons, including SL-nostructure alone, once/twice cleanup, signed boundary
inputs and the interleaved-publication failures. It also passes11,568 Heap2Local
and15,440 memory16 comparisons. The current-source generated campaign above
subsequently completes10,000 comparisons. The earlier 10,000-case campaign predates both guards and did
not cover these failures. Evidence is retained in
`.tmp/report-optimization-20261014/logs/sl-write-visit-combined-2.log`,
`logs/sl-write-visit-wasmgc-all.log` and
`review/sl-read-snapshot-independent.txt`. Regression sources are the
[pass interleaved-publication tests](../../../../../src/passes/simplify_locals_interleaved_publication_regression_wbtest.mbt)
and [dispatcher tests](../../../../../src/cmd/simplify_locals_interleaved_publication_regression_wbtest.mbt).

## October 14, 2026 moved-write revisit repair

The combined `heap2local -> simplify-locals` pipeline trapped on a valid
non-null reference owner update. The same passes with an encode/decode boundary
returned the expected references. Full and no-tee SimplifyLocals variants
failed; the no-structure and no-nesting variants retained the correct values.

Block-result lifting moved an initialization block under a following
`ref.as_non_null` operand. The scanner then revisited that block's existing
pending writes. Overwritten-write cleanup treated each write as its own
predecessor and removed the definition. Later reference reads remained and
trapped on the default null value.

Overwritten-write cleanup now requires a distinct previous node. Structure
lifting, nesting, and removal of genuinely overwritten earlier writes remain
active. The [focused revisit invariant](../../../../../src/passes/simplify_locals_revisited_write_regression_wbtest.mbt)
failed before the guard. The [reference value/cycle/effect tests](../../../../../src/passes/heap2local_straightline_nonnull_regression_wbtest.mbt)
and [command regression](../../../../../src/cmd/heap2local_straightline_nonnull_regression_wbtest.mbt)
pass in the focused check. Fresh native runtime and final default-suite checks
remain pending.

> **Comparison baseline:** New comparisons require a verified [Binaryen 133](../../release-horizon-and-oracles.md) oracle. The September 10, 2026 baseline was v132. Earlier sources, commands, artifacts, and results retain their original versions.

The v131 renewal adds an exact direct-carrier subfamily: an inert root prefix followed by a result-producing structured expression, `local.set`, and the matching final `local.get` can become `nop` plus the structured producer. Encoded-byte tests cover both direct block results and branches to the owning block; a later-read guard and inert-prefix restriction keep the rewrite narrow.

## Why this page exists

The main `simplify-locals` dossier already had:

- a broad upstream strategy page
- a broad Starshine strategy page
- a WAT-shape catalog
- a code-oriented implementation map

What it still lacked was one compact bridge page for the most teachable family in the pass:

- locals that are not just dead temps
- they are *carriers* for structured values that really belong on a block, `if`, or loop result path instead

This page is that bridge.
It answers one question for beginner through advanced readers:

- when does `simplify-locals` stop treating a local as storage and start treating it as an exposed control-flow result?

## The shared mental model

For both Binaryen and Starshine, the structure-result family starts from the same observation:

- some `local.set` / `local.get` pairs are not arbitrary temporaries
- they are shuttling the value that the surrounding control node could produce directly

That leads to four high-value shape families:

1. named-block exits that all write the same local
2. `if` / `else` arms that compute the same later local value
3. one-armed `if` rewrites that speculatively expose the carried value
4. narrow loop-tail lifting when the loop can become a result-producing control node

Starshine then adds one practical local maintenance family around the same area:

5. wrapper-forwarder and debug-artifact carrier cleanup that makes the lifted rewrites survive local exact-path realities

## Upstream Binaryen source locations that matter most

The official `version_131` source file is still the anchor:

- `src/passes/SimplifyLocals.cpp`

The most useful reviewed locations from the 2026-04-21 source capture are:

- `visitBlock(...)` calling `optimizeBlockReturn(...)`
- `doNoteIfTrue(...)` calling `optimizeIfReturn(...)` for one-armed `if`
- `doNoteIfFalse(...)` calling `optimizeIfElseReturn(...)` for `if` / `else`
- `visitLoop(...)` calling `optimizeLoopReturn(...)`
- the explicit comment above `optimizeIfReturn(...)` calling the one-armed rewrite *speculative*
- `runLateOptimizations(...)` explaining why equivalent-copy cleanup runs after structure work instead of before it

Those source locations remain listed directly in the [`simplify-locals` landing page](./index.md)'s `version_131` source list.

## Shape family 1: named block exits become block results

### Core upstream idea

Binaryen records block exits in `blockBreaks` and later lets `optimizeBlockReturn(...)` ask a narrow question:

- do all relevant exits for this named block ultimately shuttle the same local?

If yes, the pass can replace the hidden local-carrier protocol with an explicit block result.

### Canonical before/after sketch

Before:

```wat
(block $out
  ...
  (local.set $x a)
  (br $out)
  ...
  (local.set $x b)
)
(local.get $x)
```

After shape:

```wat
(local.set $x
  (block $out (result T)
    ...
    a-or-b-through-exits
  )
)
```

### Important Binaryen guards

- unsupported target users such as `BrOn*` and `Switch` still poison the block for this optimization
- more-than-one nonlinear path to here clears the cheap linear sink state afterward
- the block must still be a good candidate after exit collection, not merely after surface pattern matching

### Starshine code locations

The local lifted cluster is:

- `simplify_locals_collect_block_return_candidates`
- `simplify_locals_collect_block_branch_exits`
- `simplify_locals_try_apply_block_return_candidate`
- `simplify_locals_try_rewrite_block_return`

All live in:

- [`src/passes/simplify_locals.mbt`](../../../../../src/passes/simplify_locals.mbt)

### Local regression anchors

Reduced semantic cases:

- `"simplify-locals lifts matching block exits into a block result"`
- `"simplify-locals lifts block returns past live intervening local sets"`

Debug-artifact and encoded-output lanes nearby:

- `"raw simplify-locals effectful suffix rewrites debug artifact Func 71 block-result carrier"`
- `"simplify-locals full pipeline keeps debug artifact Func 71 block-result carrier tee"`

## Shape family 2: `if` / `else` arms become an `if` result

### Core upstream idea

Binaryen's `doNoteIfFalse(...)` hands both arm states to `optimizeIfElseReturn(...)`.
The question is:

- do the two arms really compute one later value of the same local?

If yes, that value should be an explicit `if (result ...)` instead of an implicit local shuttle.

### Canonical before/after sketch

Before:

```wat
(if
  cond
  (then (local.set $x a))
  (else (local.set $x b))
)
(local.get $x)
```

After shape:

```wat
(local.set $x
  (if (result T)
    cond
    (then a)
    (else b)
  )
)
```

### Important Binaryen guards

- the `if` must still be a void carrier shape worth converting
- one side may also win when the other is unreachable, but that is still a controlled special case, not a blanket rule
- later equivalent-copy cleanup is intentionally delayed until after this structure phase

### Starshine code locations

The local lifted helpers are:

- `simplify_locals_try_rewrite_if_return`
- `simplify_locals_try_structure_rewrite_region`
- `simplify_locals_run_structure_rewrites`

### Local regression anchors

- `"simplify-locals lifts if-else local writes into an if result"`
- `"simplify-locals keeps later reads alive when lifting if results"`
- `"simplify-locals lifts reachable if-else arms even when the other arm is unreachable"`

## Shape family 3: one-armed `if` lifting is real, but speculative and defaultability-gated

### Core upstream idea

Binaryen's `doNoteIfTrue(...)` calls `optimizeIfReturn(...)` for one-armed `if`.
The source explicitly labels this family speculative.
That wording matters.

The pass is willing to rewrite:

- a one-armed `if` that writes a local
- the common case followed by a later read of that local
- the Binaryen-shaped speculative case where the write is dead but the arm still has structured side effects that should not be deleted before lifting

into a value-producing `if` that also synthesizes an else-side carrier.

### Canonical before/after sketch

Before:

```wat
(if
  cond
  (then (local.set $x value))
)
(local.get $x)
```

After shape:

```wat
(local.set $x
  (if (result T)
    cond
    (then value)
    (else (local.get $x))
  )
)
```

### The crucial guard

This is only safe for **defaultable** locals.

That is the most important beginner correction in this family.
If the local is nondefaultable, the synthesized else-side get would rely on fixup machinery that can introduce a real trap, so Binaryen skips the rewrite.

### Starshine code locations

The matching local helpers are:

- `simplify_locals_try_rewrite_nested_one_armed_if_child`
- `simplify_locals_try_rewrite_nested_one_armed_if_children`
- `simplify_locals_build_one_armed_if_then_body`
- `simplify_locals_one_armed_if_tail_sets`
- `simplify_locals_local_type_is_defaultable`

### Local regression anchors

- `"simplify-locals lifts one-armed if writes for defaultable locals"`
- `"simplify-locals lifts dead one-armed if writes instead of dropping structured side effects"`
- `"simplify-locals preserves then-arm nop when lifting one-armed if writes"`
- `"simplify-locals keeps live then-arm roots when lifting one-armed if writes"`
- `"simplify-locals lifts nested one-armed if writes inside consumed result ifs"`
- `"simplify-locals skips one-armed if lifting for non-defaultable locals"`

## Shape family 4: loop result lifting is narrow, not general loop value optimization

### Core upstream idea

`visitLoop(...)` calls `optimizeLoopReturn(...)`, but only on a deliberately narrow family.

The key question is not “can this loop somehow produce a value?”
It is more like:

- is there a trailing loop-local carrier that can be moved to a loop result without violating the pass's narrow shape and cycle assumptions?

### Canonical before/after sketch

Before:

```wat
(loop
  ...
  (local.set $x value)
)
(local.get $x)
```

After shape:

```wat
(local.set $x
  (loop (result T)
    ...
    value
  )
)
```

### Important Binaryen guards

- the loop must currently be void
- the body may need to become or remain a block with a trailing `nop` slot
- multi-use or nontrivial tee pressure can still block the rewrite on early cycles

### Starshine code locations

The local lifted entry is:

- `simplify_locals_try_rewrite_loop_return`

with control-support helpers nearby:

- `simplify_locals_node_is_nonfallthrough_exit`
- `simplify_locals_control_has_typed_branch_payload`
- `simplify_locals_branch_payload_count`

### Local regression anchors

- `"simplify-locals lifts loop tail writes across the loop fallthrough"`

## Shape family 5: Starshine also owns practical carrier cleanup around wrapper forms

Binaryen teaches the structure-result family in AST terms.
Starshine has to keep that family alive across its HOT-IR plus raw-lane split.
That creates one extra local teaching surface worth keeping explicit.

### The local extra family

Some real artifact carriers are not just simple block/if/loop textbook shapes.
They also involve wrapper-forwarder cleanup, exact-path retention issues, and raw skipped-function stack-carrier cleanup.

That is why Starshine has dedicated helpers including:

- `simplify_locals_try_rewrite_split_local_set_wrapper_forwarder`
- `run_hot_pipeline_raw_simplify_locals_rewrite_control_carrier_local_gets_fixpoint`

and dedicated raw-lane tests in `pass_manager_wbtest.mbt` for the nearby debug-artifact families. The raw control-carrier helper is deliberately narrow: it handles a typed-control value immediately followed by a `local.set`, optional `nop`s, and a same-local leading read in the next expression, producing either an inline carrier or a `local.tee` when later reads still need the local.

### Why this is not a contradiction

This does **not** mean Starshine has a different core pass.
It means the repo has an extra maintenance burden:

- preserve the same transformed-value meaning
- while surviving HOT lift, exact lowering, raw-skip heuristics, and encoded-output roundtrips

### Local regression anchors

- `"simplify-locals rewrites split-wrapper debug artifact Func 50"`
- `"simplify-locals full pipeline rewrites debug artifact Func 71 returning condition copy carrier"`
- `"simplify-locals full pipeline rewrites debug artifact Func 71 split value wrappers"`
- `"simplify-locals full pipeline hoists debug artifact Func 71 nop-separated call args"`

## What runs before and after these rewrites matters

### Before

The structure family depends on the same earlier machinery as the simpler sink-and-tee wins:

- get counting
- pending sinkable tracking
- effect ordering
- branch-target awareness

### After

The structure family is intentionally followed by late equivalent-copy cleanup and then dead cleanup.
That ordering is part of the real contract.
It prevents the pass from deleting a copy too early and accidentally hiding a structure-return opportunity.

On the local side, that same story explains why the folder still needs both:

- the lifted structure helpers in `simplify_locals.mbt`
- the raw-lane and exact-cleanup notes in [`./raw-lane-and-writeback.md`](./raw-lane-and-writeback.md)

## Maintenance rule

If a future `simplify-locals` bug report mentions any of these phrases:

- block-result carrier
- if-result carrier
- one-armed `if`
- loop tail write
- wrapper forwarder
- copied local after structure lift

start with this page, then jump to:

- [`./wat-shapes.md`](./wat-shapes.md) for the source-backed before/after family
- [`./implementation-map.md`](./implementation-map.md) for the owning MoonBit helper cluster
- [`./starshine-hot-ir-strategy.md`](./starshine-hot-ir-strategy.md) for the HOT/raw/writeback split

That path is now the shortest route from shape-level confusion to exact local ownership.

## October 15, 2026: depth-128 WasmGC stack safety

A valid function with 128 consecutive void blocks exposed host stack overflow in
both `simplify-locals` and `simplify-locals-nostructure`. The failure had four
owners. HOT lift consumed one host frame per block. Lowered no-structure cleanup
used derived equality on deep instruction trees to infer whether wrappers or
block bodies changed. The adjacent-pair raw cleanup compared a newly rewritten
deep body structurally after its identity had already proved a rewrite. The
command no-op byte path also compared complete modules structurally.

HOT lift now recognizes a 32-or-deeper singleton void-block chain, allocates its
labels iteratively, lifts the leaf once, and unwinds the regions in reverse.
The unwind retains only the typechecker states, entry states, and node ids that
it consumes; label pop no longer stores an unused integer for every nesting
level.
Lowered cleanup records wrapper and block-body changes at the rewrite sites.
Adjacent-pair cleanup, the SIMD sink, and command byte reuse use their existing
physical-identity contracts. The command accumulates change state at every
pipeline-segment boundary and reuses source bytes only when all segments are
unchanged and no encoding cleanup is due.

Red-first coverage includes depths 31, 32, 33 and 128; a branch to the outer
label; branches to the innermost, middle, outermost, and implicit function
labels; invalid label rejection; a live value across the chain; sibling label
restoration; a conditional exit; both pass names; direct and command-adapter
roundtrips; exact observable `global.set 0` value 42; and a deep rewrite before
a root terminator. A command regression also proves that an early changed
segment followed by an unchanged final segment still encodes the result. The
root-terminator case reproduced a second `RangeError` before the adjacent
structural comparison was removed. The final release command with
SHA256 `85f3c1354ff67dd55d9cfb570438b3783db673a8361297f82786bc8dd531af42`
processes the active and unchanged depth-128 binary fixtures under both passes;
all four outputs validate with wasm-tools 1.260.0. Their sizes are 29 bytes for
the active fixture and 32 bytes for the unchanged fixture, identical between
the two passes. The output hashes are respectively `9d35753f` and `a8aba485`.
Local evidence is under
`.tmp/report-optimization-20261014/review/depth128-fused-stack-replay-current/`.

MoonBit's current native test backend cannot lower the IR package's
uninitialized non-null GC-reference scratch arrays. Native unit tests therefore
do not execute this path; the release WasmGC command replay is the executable
backend evidence. Fresh generated Binaryen-133 renewal is still required because
the completed 10,000-case campaign used the preceding frozen build.
