---
kind: concept
status: supported
last_reviewed: 2026-07-27
sources:
  - ./index.md
  - ../../../../../src/passes/simplify_locals.mbt
  - ../../../../../src/passes/simplify_locals_test.mbt
  - ../../../../../src/passes/pass_manager.mbt
related:
  - ./index.md
  - ./wat-shapes.md
  - ./binaryen-strategy.md
  - ./structure-result-lifting-and-carrier-cleanup.md
  - ./implementation-map.md
  - ./effect-ordering-and-barriers.md
  - ./raw-lane-and-writeback.md
  - ./validation-and-signoff.md
  - ./performance-and-artifact-frontiers.md
  - ../../../ir2/architecture-rules.md
  - ../../../ir2/local-ssa-policy.md
---

# `simplify-locals` Starshine Strategy

> **Comparison baseline — September 10, 2026:** new comparisons use [Binaryen 132](../../release-horizon-and-oracles.md). This supersedes older current/latest-baseline wording below. Recorded v131 sources, commands, artifacts and results retain their historical version and do not establish v132 signoff.

The v131 renewal preserves this three-layer design. The new parity work deliberately places HOT region-splice behavior in `simplify_locals.mbt` and exact stackifier-sensitive cleanup/finalization in `pass_manager.mbt`, rather than broadening either layer beyond its proof surface.

## Core Design Rule

- `simplify-locals` must stay inside the repo's existing `HotFunc` contract.
- We do not want a second owned optimizer IR just to mimic Binaryen's AST walker.
- The Starshine strategy is therefore not "copy Binaryen's implementation." It is:
  - preserve Binaryen's transform categories and safety rules
  - map them onto `HotFunc`, `HotRegionRef`, node ids, and exact writeback
  - keep artifact-only no-op families out of hot lift whenever a narrow raw-lane proof is good enough

## The Three-Layer Port

- In practice the pass is already split across three layers, and that split is intentional:
  1. the lifted HOT-IR pass in [`../../../../../src/passes/simplify_locals.mbt`](../../../../../src/passes/simplify_locals.mbt)
  2. the raw exact-instruction fast path and raw-skip path in [`../../../../../src/passes/pass_manager.mbt`](../../../../../src/passes/pass_manager.mbt)
  3. exact-body cleanup that runs after lower, and now also on selected raw-skip results
- A lot of confusion disappears once this is stated explicitly:
  - the HOT pass is where semantic parity lives
  - the raw lane is where artifact-scale no-op families are bypassed or cheaply rewritten
  - the exact writeback cleanup is where narrow lowered-temp cleanup happens without pretending lowered exact wasm is the same as HOT IR

## Why The Repo Went No-Structure First

- The worktree strategy is deliberately no-structure first.
- The reasons are practical, not aesthetic:
  - sink and tee parity closes many more Binaryen diffs per unit of implementation risk
  - effect-ordering mistakes in the no-structure path are easier to reduce and fuzz
  - structure lifting depends on the no-structure cleanup being trustworthy first
  - the artifact frontier repeatedly surfaced local-flow bugs before it surfaced genuinely-new structure families
- This is why many of the currently-documented wins are about:
  - sibling-argument ordering
  - loop-carried initializer safety
  - tee-backed copied locals
  - validator raw-skip temp cleanup
  and not only about blocks or `if` results.

## How Binaryen's Phases Map Onto HOT IR

### 1. Count Uses And Build Sinkable State

- HOT IR already gives Starshine stable local ids and node ids.
- The lifted pass mirrors Binaryen's need for future-use knowledge by computing local get counts up front.
- The in-tree functions for this layer include:
  - `simplify_locals_count_local_gets`
  - `simplify_locals_record_local_set`
  - `simplify_locals_new_sinkables`
- The sinkable state is more detailed than a simple map of local to node:
  - it carries aggregated effect masks
  - sparse local read/write footprints
  - scratch-stamp state used to avoid large whole-array clears on artifact-scale functions

### 2. Scan Linear Regions And Consume Later Gets

- The closest HOT-IR analogue to Binaryen's linear walk is region scanning.
- The pass uses region order and root order to approximate the same "pending candidate on the active linear trace" model Binaryen has.
- The main region and node walk lives in:
  - `simplify_locals_scan_region`
  - `simplify_locals_scan_node`
  - `simplify_locals_try_consume_following_local_get`
  - `simplify_locals_try_inline_following_local_get`
  - `simplify_locals_try_inline_leading_local_get_child`
- This is the core place where the repo now handles:
  - direct single-use sink
  - multi-use sink through `local.tee`
  - pure later-call-argument inlining
  - loop-carried safety
  - sibling-argument ordering guards

### 3. Encode Effect Ordering Locally To The Pass

- HOT IR has effect information, but the pass still needs its own directional policy layer to mimic Binaryen.
- The relevant helpers in the current implementation include:
  - `simplify_locals_collect_region_local_effects`
  - `simplify_locals_collect_subtree_local_effects`
  - `simplify_locals_effects_for_pending_local_set`
  - `simplify_locals_effects_ordered_before`
  - `simplify_locals_invalidate_sinkables`
- This is where Starshine learned several non-obvious lessons from artifact reductions:
  - local-only traffic can sometimes commute and should not always kill a call-backed pending value
  - read-only trapping values can commute past later read-only traps in some narrow cases
  - memory writes still kill those trap-commuting candidates
  - loop bodies need a fresh sinkable set instead of inheriting outer pending values
  - region bodies under `if` / `try` / `try_table` must contribute local read/write information or sibling-argument moves become wrong

### 4. Rewrite Structure By Region Surgery, Not AST Pointer Tricks

- The most important beginner-facing bridge here is the structure-result carrier family:
  - block-result carriers
  - `if` / `else` result carriers
  - one-armed `if` defaultable-local lifting
  - narrow loop-tail carriers
  - local wrapper-forwarder cleanup around real artifact shapes
- Keep the compact cross-map for that family in [`./structure-result-lifting-and-carrier-cleanup.md`](./structure-result-lifting-and-carrier-cleanup.md).
  This page keeps the larger HOT/raw/writeback story; the bridge page is where future threads should start when the question is shape-to-helper ownership.

- Binaryen sometimes stages structure rewrites with trailing `nop` growth because its walker stores `Expression**` pointers.
- HOT IR does not need that exact trick because Starshine can operate on region references and node ids directly.
- The structure-rewrite layer lives in:
  - `simplify_locals_try_rewrite_block_return`
  - `simplify_locals_try_rewrite_if_return`
  - `simplify_locals_try_rewrite_loop_return`
  - `simplify_locals_try_rewrite_nested_one_armed_if_child`
  - `simplify_locals_build_one_armed_if_then_body`
- The important HOT-IR-specific choice is that the pass rebuilds the new region body explicitly:
  - preserve live then-arm roots
  - preserve Binaryen-style `nop` sentinels when the shape depends on them
  - replace only the tail local write, not the entire arm
- That is a deliberate deviation from the incidental Binaryen retry pattern while preserving the same semantic result.

### 5. Run Equivalent-Copy Cleanup As Its Own HOT Phase

- The repo's lifted pass carries a dedicated equivalent-local phase instead of trying to smuggle equivalent cleanup into the main scan.
- The main helpers are:
  - `simplify_locals_new_equivalences`
  - `simplify_locals_add_equivalence`
  - `simplify_locals_pick_best_equivalent_local`
  - `simplify_locals_run_equivalent_cleanup`
- This phase is where several subtle parity fixes landed:
  - preserve tee-backed copied locals for later branch or call uses
  - protect tee-defined locals only when the current use is a direct call child
  - allow same-arm non-call aliases to collapse back to the source local
- That behavior is not accidental cleanup polish. It is required to match Binaryen's exact preference ordering on copied locals.

### 6. Keep Dead Cleanup Separate From Equivalent Cleanup

- The repo pass ends with a dedicated dead cleanup phase, mirroring the fact that Binaryen also separates "equivalent locals" from "dead writes."
- The in-tree cleanup helpers live in:
  - `simplify_locals_run_dead_cleanup`
  - `simplify_locals_delete_detached_nodes`
- This separation matters because:
  - some dead writes are pure and can vanish
  - some must become `drop(value)`
  - some detached nodes are already known dead and should not pay whole-function scans again

## Why There Is Still A Raw Lane

- The raw lane exists for two reasons:
  - some large debug-artifact functions are extremely expensive to lift but turn out to be Binaryen-equal no-ops
  - some narrow exact-instruction rewrites are easy to prove safe and cheap without lifting the whole function
- The raw lane is *not* a shadow optimizer that should gradually replace HOT IR.
- It is a pressure-relief valve for:
  - giant builder initializers
  - validator-heavy structured helpers
  - dense structured call-heavy no-op families
  - a few narrow exact rewrites that are parity-safe and easy to trace
- The detailed rules live in [`./raw-lane-and-writeback.md`](./raw-lane-and-writeback.md), but the architectural rule is simple:
  - if a rewrite needs structural understanding, rich effect ordering, or result retagging, prefer HOT IR
  - if a no-op family can be proven cheap and stable from exact instruction shape alone, prefer the raw lane

## Why Exact Writeback Cleanup Lives Beside The Raw Lane

- Lowered exact wasm is not HOT IR, but it still exposes obvious temporary scaffolding that Binaryen also tends to remove.
- The repo now uses a fail-closed exact writeback cleanup for very narrow families:
  - dead copied `local.tee`
  - dead adjacent `local.set` / `local.get`
- Crucially, the broader "strip lowered nops" experiment was rejected because it diverged almost immediately on the pass-fuzz lane.
- So the Starshine rule is:
  - exact writeback cleanup is allowed only when the family is narrow, reduced, and oracle-backed
  - preserving Binaryen's lowered `nop` scaffolding is part of parity, not an optional prettifier

## HOT IR Boundaries That Must Stay True

- The pass must preserve the repo's IR2 contract:
  - mutate only through public region and node helpers
  - keep node identity and live/dead status coherent
  - keep control result types explicit
  - respect lower-time invariants instead of assuming a tree printer will repair them later
- This is why some potential Binaryen-like moves remain intentionally rejected in Starshine:
  - broad selectification of lifted `if` results
  - broad lowered-`nop` stripping
  - broad structured barrier rewrites without a reduced Binaryen-backed proof

## Current In-Tree Shape

- The exact lifted pass in [`../../../../../src/passes/simplify_locals.mbt`](../../../../../src/passes/simplify_locals.mbt) carries:
  - sinkable-state tracking
  - effect-ordering and local-effect collection
  - structure rewrites
  - equivalent cleanup
  - dead cleanup
- The raw lane in [`../../../../../src/passes/pass_manager.mbt`](../../../../../src/passes/pass_manager.mbt) carries:
  - narrow exact rewrites such as structured pure-call-tail and validator-heavy temp cleanup
  - no-op raw-skip gates for artifact-scale helper families
  - post-lower exact cleanup reused on selected raw-skip results
- Focused regressions live in:
  - [`../../../../../src/passes/simplify_locals_test.mbt`](../../../../../src/passes/simplify_locals_test.mbt)
  - [`../../../../../src/passes/pass_manager_wbtest.mbt`](../../../../../src/passes/pass_manager_wbtest.mbt)
  - [`../../../../../src/passes/perf_test.mbt`](../../../../../src/passes/perf_test.mbt)

## Open Maintenance Rule

- Keep this page as the live explanation of how `simplify-locals` is being ported onto HOT IR.
- File future structure-lifting decisions, raw-lane retirement rules, and Binaryen parity boundaries here or in sibling simplify-locals pages instead of generic optimizer notes.
- If a future change only updates artifact frontiers or evidence, prefer updating [`./parity.md`](./parity.md) instead of growing this page with transient chronology.

## Sources

- Upstream `version_131` sources: [`./index.md`](./index.md#sources)
- Follow-up note: [research note 0241](./index.md)
- Archived research note: [research note 0076](./index.md)
- Implementation: [`../../../../../src/passes/simplify_locals.mbt`](../../../../../src/passes/simplify_locals.mbt)
- Focused tests: [`../../../../../src/passes/simplify_locals_test.mbt`](../../../../../src/passes/simplify_locals_test.mbt)
- Raw lane: [`../../../../../src/passes/pass_manager.mbt`](../../../../../src/passes/pass_manager.mbt)
- IR2 rules: [`../../../ir2/architecture-rules.md`](../../../ir2/architecture-rules.md) and [`../../../ir2/local-ssa-policy.md`](../../../ir2/local-ssa-policy.md)

## Block-result writes and escaping branches

A local write can become a block result only if moving it past the trailing
roots preserves every path that can observe the write. Checking branches to the
candidate block's own label is insufficient: a branch to an enclosing block
also skips the new outer local set. The motion check tracks labels contained
inside each trailing subtree and rejects exits from that subtree. Internal
branches remain eligible; returns, throws, and calls that can enter an enclosing
handler prevent moving a prior local write past them.

The reduced regression in `simplify_locals_dew_outer_exit_test.mbt` writes 31
inside an inner block, branches to the enclosing exit, and reads the local.
The old result was 0 because the transform placed the write after the branch.
The test executes branch depths and checks the required result 31.

## September 25, 2026: exact child-use scan

`simplify_locals_child_use_count_capped_at_two` must count every child edge
from every live HOT node, including detached nodes and duplicate operand
slots. Unique-use queries therefore scan the whole arena. Leaf nodes cannot
hold a child edge; the helper now skips their liveness lookup and reads stored
child spans directly for non-leaf nodes. The native helper benchmark measured
1,024 trailing leaf nodes at `3.89 → 1.16 µs` and 4,096 at
`15.31 → 4.40 µs` for a unique use. Shared-child early-exit controls also
improved from about 22.7 ns to 10–13 ns. Full-pass impact remains unmeasured.

The protected-region dropped-tee rewrite checks unique use of both the tee
and its value without mutating between queries. It now counts both targets in
one all-live-node traversal and rejects as soon as either reaches two uses.
The native helper benchmark measured 1,024 trailing leaf nodes at
`2.30 → 1.12 µs` and 4,096 at `8.85 → 4.29 µs`; single-target controls stayed
near 1.14 and 4.43 µs. A focused test rejects either shared target.

## October 2, 2026: reuse the current census for absent leaf conditionals

The raw canonical SimplifyLocals dispatcher already computes a complete current
`RawSimplifyLocalsGateStats`. Its `if_count == 0` now proves that the leaf
conditional-to-select cleanup cannot rewrite anything. The entry returns the
original body and zero rewrites before allocating either rewrite array or any
cloned control/Expr. The dispatcher already ignores the body when the rewrite
count is zero. All possible candidates still use the unchanged recursive owned
worker; this is not a new pass admission/skip gate. Recursive workers do not
rescan the census. A private direct call without supplied stats computes one
fresh entry census; production supplies its existing immutable-body census.

[Red-first ownership regression](../../../../../src/passes/sl_leaf_census_wbtest.mbt)
failed on the original implementation's real no-`if` cloning. Four focused
contracts cover flat/block/loop/try_table bodies, GC/NaN/signed-zero bytes,
ordered global writes and traps, ownership of changed output including unchanged
siblings, fresh nested candidates after mutation, and intentionally unadmitted
reference/effectful/unreachable arms. The [command test](../../../../../src/cmd/cmd.mbt)
requires actual select creation and ordered global writes through both canonical
SimplifyLocals and DAE2 optimizing. A source-normalized audit proves the worker
algorithm is identical apart from its private name. Generated native C confirms
supplied stats are a nullable pointer with no added box; the negative path still
allocates its existing return tuple, not normalized/rewritten body storage.

`moon info`, `moon fmt`, all 13,304 bounded wasm-gc tests, `moon check` and native
release build pass, with no public API change. Final binary SHA-256:
`a1a06e2e0d7745deb92d6fb48d930e95adbb470a1bc8486ee111add5f93fd68a`.
Eight [native controls](../../../../../src/passes/sl_leaf_census_perf_wbtest.mbt)
pass (ten batches, mean±sigma; existing census and fixture setup outside timing):

| Body | Original owned worker | Census entry |
| --- | ---: | ---: |
| No if, width 1, depth 0 | 86.07±1.44 ns | 16.85±.50 ns |
| No if, width 256, depth 0 | 9.47±.529 µs | 16.44±.32 ns |
| No if, width 32, depth 8 | 22.39±.546 µs | 20.89±3.41 ns |
| Active, width 32, depth 8 | 28.97±3.31 µs | 26.89±.205 µs |

The active spread does not establish an improvement; retain the possible-case
control rather than claiming that the guard accelerates real rewrites. No new
persistent facts, cache invalidation, cross-revision reuse or dense rows exist.

Matched large DAE2/O command evidence is essentially flat: five alternating
pairs before 7827.891±55.344 / after 7849.162±51.696 ms (median±MAD), paired
+.16%, v133 2516.327±43.522 ms. Every row flags foreign CPU work. Three separate
traced inner pairs give 6883.159±48.735→6870.953±23.287 ms, within dispersion.
These compare the exact-sized-CFG predecessor to this guard, excluding builds.
Do not promote the large helper improvement into a full-command or Binaryen
speed-parity claim. The remaining cleanup envelope and repeated raw scans,
recurrence cloning, verification, lift/lower and byte-quality work stay open.

SimplifyLocals and DAE2/O fixed execution matrices validate 56 modules and
compare 168 original/before/after/v133 observations, including loops, carried
reads, imported effects, traps, globals, memory and GC. All before/after bytes
match. Compiler optimizing output remains 5,563,501 B, with existing raw wins
and the symmetric canonical deficit preserved. Aggregate fuzz, coverage/full
release gate and independent review remain deferred; local source/diff review
is recorded. Artifacts: `.tmp/large-pass-hotspots-20261001/sl-leaf-census-*`,
source audit, native-entry excerpt, exact frozen manifest, eight native controls,
two-mode runtime matrices and five-pair/three-trace cohort.

## October 2, 2026: reject existing flat statement control boundaries before typechecking

Balanced local forwarding already excludes completed statements containing its
structured-control or early-terminator predicates. The private prefix helper
now accepts `flat_only=true` for this one caller and applies those same predicates
before typechecking each instruction. It returns the original start on rejection;
complete eligible prefixes still use the original left-to-right typecheck and
all later effect/initialization proofs. Other prefix clients keep default behavior.
The caller avoids an empty statement allocation and the redundant post-check.
Legacy Try classification, public error diagnostics, final function/module
verification and optimization coverage are unchanged. No cached analysis, new
allocation or public API is introduced.

Sources: [prefix helper](../../../../../src/passes/statement_prefix_reuse.mbt),
[balanced caller](../../../../../src/passes/pass_manager.mbt),
[boundary and active rewrite regressions](../../../../../src/passes/flat_statement_admission_wbtest.mbt),
[native controls](../../../../../src/passes/flat_statement_admission_perf_wbtest.mbt).
The first regression run fails because the private admission option is absent;
this is a red API/work-contract test, not a demonstrated semantic defect.
Tests compare complete boundaries to the original gate, retain invalid-flat
checking, preserve nonzero starts, and exercise later actual forwarding after a
structured boundary for i32/i64/externref while checking input ownership and
output validation. Existing dispatcher tests also pass.

Frozen native predecessor `a1a06e2e…` versus candidate `8b4ee1ea…`, identical
6,211,596-byte input, CPU 6, one warmup, five alternating release CLI pairs:

| Scope | Before | After | Binaryen 133 |
| --- | ---: | ---: | ---: |
| DAE2 optimizing full command, median ± MAD ms | 7651.716 ± 28.354 | 7489.234 ± 74.687 | 2503.784 ± 13.284 |
| Separate traced Starshine inner pass, three samples, median ± MAD ms | 7087.029 ± 130.900 | 6909.190 ± 133.157 | not measured here |

Command ranges are 7623.363–7875.010 / 7385.271–7809.481 / 2462.777–2584.385 ms.
Paired median change is −3.04%; all rows record foreign CPU activity, so this is
an observed improvement under contention, not a quiet-host parity result.
Builds are outside timing; traced scopes are separate and nested timers are not
added. Equivalent Binaryen work is `--all-features --dae2 --simplify-locals
--vacuum`, not DAE/O. All large Starshine outputs remain exactly 5,563,501 bytes,
SHA-256 `a2cfeaf22bab817cbcd0e97048bddd6723e258ba25eec3375e96b08230676e1d`.

Complete matched nonrecursive cleanup wrapper profiles collect
26,733,676,648→24,075,360,577 instructions (−9.94%). Within that scope, prefix
entry instruction-typechecking edges fall 4,060,249,089→1,455,815,645 (−64.14%).
These nested costs must not be added to the root reduction. Shared incoming call
counters remain mixed across collected/uncollected contexts and are not an
allocation measurement. Instrumentation is absent from release timing. The
[complete cleanup attribution](../dae2/starshine-strategy.md#october-2-2026-complete-optimizing-cleanup-instruction-attribution)
records the delayed-instrumentation protocol and its accepted C control.

Eight native controls pass (ten batches, mean ± sigma): rejected structured
width 1 costs 364.63±21.77→10.58±.51 ns; width 1024 costs
28.84±.118 µs→10.27±.04 ns. Eligible flat width 1 stays
108.19±.46→106.92±1.07 ns; width 1024 stays 32.92±.232→32.33±.181 µs.
These are same-compiler original-gate versus early-gate controls, not frozen
whole-command binaries. All 13,307 bounded tests, info/fmt/check and native
release build pass. SL and DAE2 optimizing runtime lanes validate 64 modules and
match 192 fixed original/before/after/v133 observations (ordered imported calls,
mutable state, memory, references and traps), with exact before/after bytes.

Artifacts: `.tmp/large-pass-hotspots-20261001/flat-statement-*`,
`dae2-cleanup-census-before-*`, `dae2-cleanup-flat-statement-*`, manifests,
commands, raw samples and local report. Full fuzz/coverage gates remain deferred
at the user's request; this is a focused performance checkpoint, not release
signoff. Remaining raw Vacuum unreachable rescans, recurrence arrays, CFG/lower,
validation and the canonical byte gap remain active.

## October 2, 2026: retain unchanged flat recurrence rows

The three-local additive and alternating-bitselect flat helpers always allocated
and copied their entire input after discovering no recurrence. They now return
their read-only input with count zero: before allocation when length is below
the original two-times-ten minimum, and after the unchanged complete discovery
otherwise. Positive construction is source-audited identical. The recursive
worker still builds its owned normalized tree; changed siblings and nested
results retain that existing deep ownership. This does not introduce general
borrowed changed results, a cache, a new admission bypass or less verification.

Sources: [flat helpers and recursive owner](../../../../../src/passes/pass_manager.mbt),
[red identity and positive ownership/validation regressions](../../../../../src/passes/recurrence_unchanged_row_wbtest.mbt),
[frozen-original native controls](../../../../../src/passes/recurrence_unchanged_row_perf_wbtest.mbt),
[active dispatcher coverage](../../../../../src/cmd/cmd.mbt).
The unchanged-row identity assertion fails before implementation; both positive
scalar/SIMD tests already pass and continue to verify actual rewrite counts,
encoded input preservation and valid owned output. Dispatcher SL/optimizing
fixtures retain active byte reductions and ordered global writes.

All 13,314 bounded tests, info/fmt/check and native release build pass. Eight
native controls pass twice (ten batches, mean ± sigma; fixtures/assertions outside
timing). Initial wide unchanged additive cost is 5.81±.365→1.62±.052 µs;
repeat 4.61±.015→1.35±.001 µs. Bitselect costs 4.36±.106→1.35±.002 µs,
repeat 4.38±.034→1.36±.005 µs. Active additive128 stays
8.04±.042→8.03±.073 µs initially, repeat 8.00±.013→8.06±.023 µs
(+.06 µs retained as a small cost). Initial active bitselect128
10.03±.192→11.61±.746 µs is slower and variable; repeat
9.65±.149→9.51±.026 µs does not reproduce that slowdown. Preserve both cohorts;
do not claim a general active-kernel speedup or hide the first result.

Frozen predecessor `833e27c8…` versus candidate `db187830…`, fixed large compiler
input, CPU6, one warmup/five alternating normal optimizing CLI pairs:
median ± MAD 7367.606±90.825→7334.925±111.276 ms, v1332455.192±33.879 ms.
Ranges are7263.055–7492.981 /7223.648–7542.529 /2421.313–2525.889 ms.
Paired change −.52% lies within spread; all rows record foreign activity and a
normal command improvement is not established. Separate three traced inner
samples are6601.018±11.980→6788.242±194.775 ms, with broad ranges
6589.038–7143.182 /6351.738–6983.017; they likewise do not prove a timing win.
Builds and Callgrind instrumentation are excluded from normal samples.

Complete matched optimizing cleanup profiles reduce
23,332,741,822→22,697,100,543 collected instructions (−2.72%). The nested raw SL
recurrence child falls1,120,775,663→452,833,981 (−59.60%); root and child must
not be added. Shared call counters are not scoped allocation counts. Source
inspection proves absent copies/row allocations on short unchanged inputs;
no exclusive allocation percentage or RSS saving is measured. There is no new
production heap allocation and supported matching work remains complete.

Two fixed runtime lanes (SL and optimizing) validate100 modules (96 raw and four
expanded compact-import oracle encodings) and match288 differential observations,
including active scalar and SIMD recurrences, ordered calls, global/memory state,
references and traps. Exact before/after compiler bytes remain5,563,501 with hash
`a2cfeaf22bab817cbcd0e97048bddd6723e258ba25eec3375e96b08230676e1d`.
Oracle compact-import replay uses the documented
[encoding-only protocol](../vacuum/starshine-hot-ir-strategy.md#october-2-2026-bound-indexed-tag-wrapper-admission-before-deep-scans);
normal v133 flags stay `--all-features --dae2 --simplify-locals --vacuum`.

Artifacts: `.tmp/large-pass-hotspots-20261001/recurrence-row-*`,
`dae2-cleanup-recurrence-row-*`, source/kernel reviews, both native batches,
commands, frozen manifests and local report. The wider recursive normalization,
other recurrence/SIMD rows, exact cleanup, shared CFG/lower and byte gaps remain
active. Full fuzz/coverage and release signoff are deferred; this is a scoped
storage/work improvement with limited enclosing wall evidence.

A distinct combined three-change comparison uses the frozen leaf-census
predecessor `a1a06e2e…` and final `db187830…`: one warmup, three alternating
normal optimizing CLI pairs on CPU6. Before/after/v133 median ± MAD is
8379.033±175.850 /7545.154±227.149 /2579.124±82.160 ms; ranges
8203.182–8703.332 /7318.004–8271.640 /2482.402–2661.284 ms. Paired changes
are−9.95%,−4.96%,−10.79%, median−9.95%; all rows retain foreign CPU flags.
This is an observed combined improvement under contention, not a quiet-host
result or a replacement for the individual inconclusive cohorts. Three-change
cleanup instruction work falls26,733,676,648→22,697,100,543 (−15.10%) under the
identical complete wrapper scope. This percentage is computed from the two
root totals, not summed from nested/per-change percentages. Raw compiler bytes
and all quality gains remain identical. Artifacts:
`combined-cleanup-dae2-optimizing-pairs/` and `measure-combined-cleanup.py`.
