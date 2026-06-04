---
kind: concept
status: working
last_reviewed: 2026-06-04
sources:
  - ../../../raw/research/0712-2026-06-04-simplify-locals-o4z-pass-audit.md
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

The `[O4Z-AUDIT-SL]` closeout refreshed direct and generated late-neighborhood semantic evidence, but intentionally did **not** claim that every raw threshold is boundary-tested. The remaining raw skip/gate boundary work stays under `[AUDIT002-F]` / `[AUDIT002-G]`, especially small structured call-mesh gates, giant validator / no-structure gates, practical `±1` thresholds, and public-pipeline fixtures that prove intended cleanup or intentional skip with a trace reason.

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
