---
kind: concept
status: supported
last_reviewed: 2026-09-28
sources:
  - ./index.md
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/passes/pass_manager_wbtest.mbt
  - ../../../../../src/passes/perf_test.mbt
  - ../../../../../src/passes/simplify_locals_test.mbt
  - ../../../../../CHANGELOG.md
  - ../../../../../agent-todo.md
related:
  - ./index.md
  - ./wat-shapes.md
  - ./starshine-hot-ir-strategy.md
  - ./implementation-map.md
  - ./performance-and-artifact-frontiers.md
  - ./parity.md
  - ./validation-and-signoff.md
---

# `simplify-locals` Raw Lane And Exact Writeback

## Type-indexed loop adjacent tee exception

Saved seven-pass case437 exposed a narrow raw-admission gap inside a type-indexed
loop. The broad HOT path still skips these loops because their parameter stack
flow needs path-sensitive proof. The full `simplify-locals` variant may now enter
the raw lane when the existing recursive exact rewrite finds an adjacent,
same-index `local.set X; local.get X` pair. Replacing that pair with
`local.tee X` preserves the write and the stack value without moving either
operation across another instruction. Other local-write shapes, `no-tee`, and
`no-structure` remain on the existing type-indexed-loop boundary.

The reduced saved module changes from raw/canonical `70/82` bytes to `68/80`;
Binaryen 132 emits `81/81`. Node 26.10.0 returns `[0, 0, 16, 0, 16]` for inputs
`[0, 1, -1, -2147483648, 2147483647]` from the original, Starshine candidate,
and Binaryen output. Direct pass-manager and active command-dispatch regressions
also require validation, the 68-byte raw output, and the exact `local.tee` shape.

## V131 cleanup additions

The 2026-07-27 renewal keeps the raw lane narrow but adds four exact postconditions: erase discarded default struct allocation; erase pure `local.get; drop`; move inert `nop`s before dupable return values and delete unreachable root suffixes; and replace an inert-prefix structured-result `local.set/local.get` carrier with `nop` plus the direct result producer. Binary-path encoded-size regressions guard the two stackifier-sensitive families.

## Reads after a nested branch exit

The leading-read sink must prove that the original local value has one read
across every enclosing suffix. A read inside an inner block does not make a
read after that block dead: `br_table` can select the inner exit and continue
at that second read. Each recursive descent now checks its enclosing suffix.
The scan also stops at an earlier read of the target instead of skipping it
and removing the write at a later read.

The reduced runtime case stores a call result of `21`, uses it to select a
branch-table target, then multiplies the same local by two after the inner
exit. The broken raw transform returned `0`; the fixed pipeline returns `42`.
The GC version lost an array element reference and trapped on a later cast.
The ordinary HOT path can still sink the value with `local.tee`, preserving
the write needed by that later read.

The same descent must respect loop backedges. A producer before a loop runs
once; moving it into a repeated loop would execute it again. The raw sink now
admits only loops whose bodies have no branch back to that loop. A two-iteration
call test previously returned `43` from two calls; it now returns `42` from
one call, with both iterations reading the saved value.

The runtime regressions and existing public SimplifyLocals tests pass in the
combined 215/215 CoalesceLocals/SimplifyLocals native run. Its 46.201-second
native build/test duration remains a compiler performance issue under the
30-second project limit.
The rebuilt native CLI takes 17.429 seconds. Node returns `42` for the reduced
call, load, GC, and repeated-loop cases. The saved O4z map-iterator prefix now
passes the same expected output in both Node and Wago after SimplifyLocals.


## Why The Raw Lane Exists

- Some artifact-scale functions are expensive to hot-lift, scan, and lower even when `simplify-locals` ultimately returns `changed=false`.
- Other families are easy to repair directly on exact instructions without paying the full lifted pass cost.
- The raw lane exists to keep those families from dominating the artifact lane while preserving Binaryen parity.

## The Three Raw-Lane Jobs

### 1. Cheap Exact Rewrites

- These are direct exact-instruction rewrites that are narrow, reduced, and parity-backed.
- Examples already in tree include:
  - pure later-call-argument cleanup
  - structured pure-tail temp cleanup
  - validator-skip copied-local cleanup across flat statement groups
  - validator-skip loop-temp cleanup across pure local-copy barriers

### 2. Raw Skip For Proven No-Op Families

- These are families where tracing showed Starshine and Binaryen were already equal enough that hot lift was pure cost.
- The pass-manager now recognizes several artifact-shaped no-op families and returns a skip reason instead of lifting.

#### Legacy EH must participate in routing

- Candidate statistics and the local-write precheck recurse through both the
  body and every catch of legacy `try`; a write in either region must prevent
  the `no-local-writes` shortcut.
- Saved seven-pass case 17 exposed this boundary: the missed catch write kept
  `local.set 1(local.get 0); local.get 1`, while Binaryen v132 and the existing
  HOT SimplifyLocals transform produce `nop; local.get 0`.
- The adjacent pass test locks the routing decision and exact catch body. The
  active dispatcher test locks the original seven-pass sequence.

Exact saved-input replay later showed that retained cases 17 and 21 are the
same module byte for byte: both inputs have SHA-256
`a39f36092c69354642168a59f50b8dbea6d716e4f349465c4cc84534263ac88e`.
A fresh native build from integrated main `d1b9d5ec0` (SHA-256
`a2103618fb9f96cf66008b01bc1d8926cc748768af0cf689df726be0a98fd50c`)
produced 55 raw and 55 canonical bytes for each case, matching verified
Binaryen 132 (SHA-256
`500201b4d13ccc3a61fa5254073e75a138bc57be198bd6c18c5a9562c081ad18`) at
55/55 bytes.
All raw and canonical outputs pass `wasm-tools validate --features all`.
Starshine's raw output preserves the input's function-type order while
Binaryen orders the empty tag type first; the harness projection canonicalizes
both to identical bytes with SHA-256
`97e045e447bb651e96b3e90cce3642420e615b00d2aff68d68fa770e8b308390`.
On Node 26.10.0, the original, Starshine, and Binaryen `run(i32) -> i32`
exports all return `[0, 1, -1, -2147483648, 2147483647]` for the same argument
vector. This was a bounded replay of those two saved files; no aggregate or
fuzz campaign ran, so it does not change the historical campaign totals.

### 3. Exact Writeback Cleanup

- After exact lowering, Starshine can still remove a very small set of dead temporary patterns without broad shape drift.
- This is intentionally separated from HOT IR because the lowered exact body has different constraints and because the repo rejected a broader cleanup experiment.

## Raw Rewrite Families Currently Worth Keeping

### `structured-pure-copy-call-tail`

- Family:
  - call-backed temp
  - pure stack prefix
  - later local get used in a compare or call tail
- Why it exists:
  - large exact instruction bodies often preserve a temp only because a pure prefix sits between producer and use
- Maintenance rule:
  - keep this family narrow and trace-backed

### Validator Structured Copy Cleanup

- Family:
  - validator-heavy structured helper
  - copied locals survive after flat zero-stack statement groups
  - top-level body still takes `skip-raw reason=validator-structured-call-heavy`
- Why it exists:
  - several artifact frontiers reduced only after the repo allowed copied-local cleanup to run even when the whole function stayed on the validator raw-skip lane

### Validator Cleanup-`if` Barrier

- Family:
  - exact copied local
  - one immediate zero-result cleanup `if`
  - barrier is the only top-level structured op
  - barrier does not touch source or target locals
- Why it exists:
  - it retires a real copied-local artifact family without reviving a broader "sink across arbitrary structured barriers" rewrite

### Validator Loop-Temp Barrier

- Family:
  - single-use effectful temp
  - intervening pure local-copy barrier
  - later compare/store consumer
- Why it exists:
  - this retired the old `Func 50` temp drift without needing the whole validator-heavy function to lift

### Validator Leading-Condition Temp Sink

- Family:
  - single-use effectful temp
  - later structured value root such as `block (result ...)`
  - the only meaningful use is on that structured body's leading condition path
  - the condition may start with a pure stack prefix before the temp read
- Why it exists:
  - the old `Func 71` frontier kept a call-indirect temp alive only because the validator raw-skip lane did not see through the structured condition body
  - reduced heavy regressions now prove the raw lane can sink that temp safely without lifting the whole function

## Raw Skip Families Currently Worth Keeping

### 2026-06-04 Audit Boundary

The `[O4Z-AUDIT-SL]` closeout refreshed direct and generated late-neighborhood semantic evidence. The follow-up `[AUDIT]002` threshold audit closed on 2026-07-19: [`../../pass-manager-threshold-guards.md`](../../pass-manager-threshold-guards.md) now classifies the raw gates, `pass_manager_threshold_wbtest.mbt` covers representative small unchecked, giant-validator, generic giant, and module-cutoff `±1` boundaries, and public-pipeline tests lock classified trace reasons. Future threshold changes follow that page's maintenance rules rather than the retired `[AUDIT002-F]` / `[AUDIT002-G]` labels.

### `validator-structured-call-heavy`

- Shape:
  - validator-like, loop-heavy, structured call walkers
- Why it is skipped:
  - these functions were repeatedly expensive and often unchanged
- Important nuance:
  - the repo no longer treats this as "nothing happens"
  - the exact temp cleanup helper now runs on validator raw-skip results too
  - the raw pure-call-tail cleanup now also runs recursively on this lane in a bounded fixpoint of `3`, because returning call tails can hide earlier copied args behind later copied args inside nested `if` bodies
  - that recursive pure-call-tail fixpoint is now guarded by a cheap nested candidate scan too, so validator-heavy functions stop before another full nested rewrite walk when no pure copy call tails remain
  - the raw pure-suffix copy cleanup now also duplicates one-instruction copy values (`local.get`, `i32.const`, `i64.const`, `f32.const`, `f64.const`) through the next statement on this lane
  - that pure-copy cleanup now runs in a bounded fixpoint of `3`, because artifact traces showed later copy shuttles can become visible only after earlier raw rewrites in the same block
  - that recursive pure-suffix fixpoint is now guarded by its own cheap nested candidate scan too, so functions with no remaining `pure-value -> local.set -> later local.get` family stop before another full nested pure-suffix walk
  - the same pure-copy lane now also has a narrower helper for `local.get/const -> local.set -> raw condition prefix -> if` when the copied local is only consumed on that escaping `if` condition path and is dead again before any later read
  - the same pure-copy lane now also prefers direct dupable-copy elimination over the older "move middle statements later" path, and can batch later dupable middle producer statements into the same final use once a target statement is found
  - but not every later tee-shaped Binaryen diff should be attacked with a blind post-pass tee sweep
  - the 2026-04-10 artifact replay showed that a whole-body adjacent-tee cleanup can erase the explicit `local.set $7` carrier in `Func 71` without recreating Binaryen's `local.tee $7`
  - the raw adjacent-tee helper itself is still kept and now has a whitebox guard proving it preserves later reads inside an `if` body on the reduced flat shape
  - the reduced returning-call-tail constant-copy subgroup is now retired in-tree by the recursive pure-call-tail cleanup plus the existing pure-suffix fixpoint
  - the rebuilt-binary replay now retires the old copied-local `$739 -> $18` and `$735 -> $24` carriers on this lane
  - a reduced Binaryen probe now also proves the later constant/copy fanout policy itself: Binaryen deletes the whole dupable fanout and leaves only `nop` sentinels plus direct constants or direct `local.get`
  - a later terminal-value reducer now also covers the tighter raw shape where the copied local is the final escaping value tail instead of the input to a later zero-stack statement
  - the reduced terminal probes also pinned one subtle Binaryen rule that the repo previously missed: deleting the copied local does not delete the lowered sentinel surface; the removed `local.set` becomes a `nop`, and any pre-existing middle `nop`s remain
  - that narrower reducer is green on reduced whitebox cases and on the rebuilt native fuzz lanes `.tmp/pass-fuzz-sl-terminal-value-2k`, `.tmp/pass-fuzz-sl-terminal-value-10k`, `.tmp/pass-fuzz-sl-terminal-sentinel-2k`, and `.tmp/pass-fuzz-sl-terminal-sentinel-10k`
  - the direct traced native `--print-func 71` path now shows the old `call $176` / `call $1988` wrapper sites fed by direct constants or direct source `local.get`, which matches Binaryen's reduced policy
  - a later reduced branch-terminated carrier regression now also proves that the later-read safety scan must stop at unconditional `br` / `br_table` boundaries but not at `br_if`, and the rebuilt native lanes `.tmp/pass-fuzz-sl-branch-terminated-carrier-2k` and `.tmp/pass-fuzz-sl-branch-terminated-carrier-10k` are green too
  - however, the real artifact still keeps the exact `$62 -> $930 -> $38` branch carrier in `Func 71`, so the remaining gap on this lane is still one uncaptured validator-skip raw statement shape, not a generic lack of Binaryen policy

### `dense-structured-call-heavy`

- Shape:
  - large low-loop structured call-heavy helpers
  - artifact examples include internal helpers like `Func 395`, `430`, `818`, `2083`, and `2098`
- Why it is skipped:
  - tracing showed these were Binaryen-equal but still paying full hot cost

### `branch-dense-structured-call-heavy-noop`

- Shape:
  - branch-dense helpers with many `if`s, few blocks, no meaningful loops, and repeated local-read plus call traffic
- Why it is skipped:
  - these helpers were still paying full hot-lift cost even when simplify-locals had no profitable rewrite to make

### `block-rich-structured-call-heavy-noop`

- Shape:
  - medium-large structured helpers with many blocks, moderate local writes, and dense call traffic
- Why it is skipped:
  - the reduced and synthetic witnesses for this family are effectively no-op, so the raw lane now retires them before lift

### `call-dense-structured-walker-noop`

- Shape:
  - structured walkers dominated by repeated calls and local reads, with only light local-write opportunities
- Why it is skipped:
  - these walkers burn time in lift and scan work without enough simplify-locals cleanup to pay that cost back

### `low-local-decision-ladder-noop`

- Shape:
  - low-local decision ladders with many structured comparisons and later calls but very little meaningful local traffic to simplify
- Why it is skipped:
  - this family is a cheap no-op boundary, so the pass manager should bypass lift entirely and let the function stay raw

### `huge-straight-line-call-builder`

- Shape:
  - giant straight-line tee-heavy builders
  - artifact example: `KeywordTable::new`
- Why it is skipped:
  - no-op family with high lift and scan cost

### Other Stable Skip Families

- The repo also carries other artifact-shaped raw skips such as:
  - stringview trim loops
  - decode-shaped structured helpers
  - branchy decode fanout
  - transformer catch walkers
  - loop-heavy validator helpers
- These belong in the raw lane because they are mainly artifact-scale performance decisions, not the semantic heart of simplify-locals.

## Exact Writeback Cleanup That Stayed

### Dead Copied `local.tee`

- Kept:
  - prune dead copied `local.tee` roots after lower
- Why:
  - this matched Binaryen often enough and stayed green on the fuzz lane

### Dead Adjacent `local.set` / `local.get`

- Kept:
  - erase adjacent one-use lowered temps when the local has no later exact reads
- Why:
  - removes a common lowered shuttle pattern without introducing new tees

## Exact Writeback Cleanup That Was Rejected

### Broad Lowered-`nop` Stripping

- Rejected:
  - removing lowered `nop` roots broadly after lower
- Why rejected:
  - the `gen-valid` differential lane diverged almost immediately
  - Binaryen preserves many lowered `nop`s that the repo had incorrectly assumed were disposable

### Broad Selectification

- Rejected:
  - turning simple `if (result)` shapes into `select` broadly
- Why rejected:
  - direct reduced Binaryen probes showed Binaryen does not perform the simple selectification variants Starshine could have emitted

## The Exact Cleanup Helper Rule

- A raw or exact-body cleanup belongs in the shared helper only if all of the following are true:
  - the family is exact-instruction-local, not structure-heavy
  - the family has a reduced regression
  - the family survives the pass-fuzz compare lane
  - the family does not require broad lowered-`nop` removal

## Escaping Tail Boundary

- The 2026-04-10 returning-fanout fix clarified a raw helper boundary:
  - `run_hot_pipeline_raw_simplify_locals_take_statement_prefix_allow_escape` must be able to return the full remaining escaping value tail when the whole suffix typechecks with a non-empty stack and `tc_escape_none`
  - otherwise the pure-suffix dupable-copy reducer only sees zero-stack prefixes and peels a few copied args instead of the full returning `call`
- Why it matters:
  - the reduced returning `if (result i32)` dense-fanout regression stayed red until this boundary changed
  - after the change, the reduced regression and the direct 2k/10k lanes turned green without broadening the rewrite policy
- What it did not solve:
  - Binaryen still reparses the encoded debug-artifact output into the old `$930..$934` carrier family
  - so this helper change is part of the raw lane, while the still-open artifact frontier now sits at the Binaryen-facing writeback or reparse boundary

## Why The Raw Lane Must Stay Secondary

- The raw lane is not where new semantics should primarily be invented.
- It is acceptable for:
  - narrow exact rewrites
  - artifact-only no-op skips
  - shared exact cleanup on already-proven-safe shapes
- It is not the right long-term home for:
  - broad structure lifting
  - broad effect-ordering theory
  - general copied-local equivalence policy
  - control-result retagging

## Retirement Rule

- A raw heuristic should be retired when one of these becomes true:
  - the lifted HOT pass handles the family cheaply enough that the raw heuristic is no longer buying anything
  - the family stops appearing in artifact traces
  - the heuristic starts blocking a broader, cleaner HOT-IR parity fix

## Maintenance Rule

- Every raw-lane addition needs at least one of:
  - a focused synthetic regression
  - a perf test or wbtest for the skip reason
  - a traced artifact note that explains why the heuristic exists
- If a new idea's best evidence is "it makes the printed output look nicer," do not add it here.

## September 28, 2026 performance reuse contracts

Value-suffix cleanup first checks backward stack arity, then runs the original typechecker only for a possible split or an unsupported arity. The latest legal split, original errors, multi-value ordering and side-effect boundaries remain unchanged. The summary is candidate-local and rebuilt after mutation; all five variant policies still use the same proved suffix contract.

Tests and native controls: [value_suffix_reuse_wbtest.mbt](../../../../../src/passes/value_suffix_reuse_wbtest.mbt), [value_suffix_reuse_test.mbt](../../../../../src/passes/value_suffix_reuse_test.mbt), [value_suffix_reuse_perf_wbtest.mbt](../../../../../src/passes/value_suffix_reuse_perf_wbtest.mbt). The [campaign report](../../../tooling/tracing-playbook.md#september-28-2026-performance-backlog-campaign) owns frozen-binary artifact timings, verified-v133 evidence and final correctness outcomes; helper timings alone do not close the remaining pipeline or parity gaps.


## September 28, 2026 follow-up cleanup ownership

Zero-read-set cleanup now preserves unchanged instruction/body storage and copies
the prefix only after a real replacement. Structured children reuse unaffected
siblings; function identity handles unchanged NaN payloads without structural
floating-point equality. Read counts and the supported control families retain
their previous meaning. No variant gains an additional skip condition.

[Bounded ownership and active tests](../../../../../src/passes/sl_zero_read_identity_wbtest.mbt)
compare the old opcode sequence and validate all five variants; the command
suite also covers their non-null branch-initialization behavior.
[Native controls](../../../../../src/passes/sl_zero_read_identity_perf_wbtest.mbt)
separate tiny/wide, unchanged/dense-change and flat/nested costs. Final enclosing
measurements remain tracked in the [follow-up report](../../../tooling/tracing-playbook.md#september-28-2026-follow-up-performance-campaign).


## September 29, 2026 mutation-scoped query reuse

V18's private get-count snapshot belongs to one HOT function, exact revision
and local count. Each consumer receives an owned copy because cleanup updates
its counts. Node/local/root changes and deleted reads invalidate the snapshot.
Functions below 32 nodes or with sparse locals retain the direct scan. Unchanged
main/dead cleanup stages share the fact; supported transformations and all five
variant policies are unchanged. [Work and behavior fixtures](../../../../../src/passes/sl_get_count_cache_wbtest.mbt)
cover ownership, edits, owner changes, tiny/sparse admission, active policies,
typed loops, tuples and effects. [Native controls](../../../../../src/passes/sl_get_count_cache_perf_wbtest.mbt)
include tiny/wide repeated scans and all five complete lift/pass/verify/lower paths.

Effect queries recompute masks on every call. A candidate-local epoch row avoids
reallocating visited flags, grows only to the current arena and clears on epoch
wrap; leaf queries allocate no row. [Direct fixtures](../../../../../src/passes/sl_effect_scan_workspace_wbtest.mbt)
check exact masks/visits after edits, shared DAG edges, storage reuse and wrap.
[Controls](../../../../../src/passes/sl_effect_scan_workspace_perf_wbtest.mbt)
compare the frozen traversal with retained scratch at 1/128/4,096 nodes and
both leaves and writes.

The stack-order predicate asks whether any reachable value-producing node has
an ID earlier than a threshold. Its exact answer is the minimum such ID, so a
revision-guarded memo row serves repeated thresholds without a fresh arena-sized
visited row for every later root. It follows the same control regions as the
original traversal and conservatively keeps a barrier on a temporary cycle.
Regions below 16 roots retain the direct predicate.
[Threshold/stack-hazard fixtures](../../../../../src/passes/sl_value_order_minimum_wbtest.mbt)
compare every threshold through typed if/loop/try-table control and require
invalidation after replacement. [Native controls](../../../../../src/passes/sl_value_order_minimum_perf_wbtest.mbt)
cover tiny/wide independent and older-stack hazard cases. The
[dispatcher](../../../../../src/cmd/sl_cleanup_cache_wbtest.mbt) checks active cleanup
and owned input across all five modes.

V18 passes 12,877 default tests, 112 focused native tests and 62 benchmark
cases. Its 79-fixture shared-consumer matrix validates 2,730 outputs with
12,008 matching observations and exact V14/V18 bytes. Complete enclosing
pairs improve active tee DAE2-O/SL 31.29%/29.98%, while large compiler DAE2/O
remain flat. The [V18 evidence](../../../tooling/tracing-playbook.md#v18-complete-enclosing-evidence-and-remaining-gaps)
records other mode/shared-owner costs, pure renewal, interference, overlapping
RSS and the remaining v133 gaps.

## September 29, 2026 fresh replacement wrappers

Five replacement factories allocate a wrapper, extract its exact node record
and immediately retire it before attaching any inbound reference. That ownership
proof permits the existing detached deletion API, preserving tombstones,
child spans, flags, source order and revision invalidation while avoiding
an arena-wide unreferenced-node scan. Older wrapper nodes retain checked
retirement; ordinary checked IR deletion keeps its contract. No public API
changes. [Factory and fallback fixtures](../../../../../src/passes/sl_fresh_wrapper_retirement_wbtest.mbt)
first fail on the scan work bounds and assert all five node shapes and ownership.
[Native controls](../../../../../src/passes/sl_fresh_wrapper_retirement_perf_wbtest.mbt)
compare checked/fresh factories at widths 1/128/4,096 with identical lift work,
arena records and lowered output. [Admission boundary fixtures](../../../../../src/passes/sl_cleanup_cache_boundaries_wbtest.mbt)
cover 31/32/33 nodes, local-density limits and 15/16/17 region roots.
Sixteen focused checks pass; full/native and enclosing shared-consumer evidence
remain pending for this next candidate. The V14 profile's 8.04% checked-deletion
self cost identifies the target but does not prove its resulting speedup.

## September 29, 2026 stacked reads and extracted block wrappers

A root-order traversal can visit a block overwrite before an older local read
contained in a later arithmetic consumer. Preserve an earlier pending write
when a source-ordered read exists between writes, and do not let an older read
consume a later pending definition. A block-result rewrite allocates a fresh
local-set wrapper at the block's preserved source position. Shared lowering and
expanded CFG dependency selection must compare that execution position with
consumer positions, rather than the wrapper's newer allocation ID.
[IR regression](../../../../../src/ir/hot_source_order_wrapper_wbtest.mbt)
covers both direct and indexed root queries; [pass fixtures](../../../../../src/passes/sl_stacked_block_order_wbtest.mbt)
follow the saved entry/constant through capture locals in all five policies,
with [dispatcher checks](../../../../../src/cmd/sl_stacked_block_order_wbtest.mbt)
and owned input bytes. Thirty-four focused checks pass. Native runtime
confirmation remains pending for V24. V21 has four true semantic failure rows
and V18 has eight in the new witnesses; their original 79-fixture signoff
does not cover these shapes. See the [trial evidence](../../../tooling/tracing-playbook.md#v21-stacked-block-runtime-failure-and-v24-repair-trial).
