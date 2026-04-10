---
kind: comparison
status: working
last_reviewed: 2026-04-10
sources:
  - ../../../../../agent-todo.md
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/passes/pass_manager_wbtest.mbt
  - ../../../../../src/passes/perf_test.mbt
related:
  - ./index.md
  - ./raw-lane-and-writeback.md
  - ./validation-and-signoff.md
  - ./parity.md
---

# `simplify-locals` Performance And Artifact Frontiers

## Scope

- This page keeps the performance-specific simplify-locals facts that are too detailed for the main parity page but too durable to leave only in `agent-todo.md`.
- It covers:
  - how the repo measures simplify-locals runtime
  - which raw skip reasons exist and why
  - which hotspot families have already been retired
  - which artifact frontiers still matter as of 2026-04-10

## Measurement Sources

### Perf Timers

- `src/passes/perf_test.mbt` asserts on:
  - `perf:timer name=pass:simplify-locals`
  - `perf:timer name=detail:simplify-locals:equivalent-cleanup`
  - `perf:timer name=detail:simplify-locals:late-dead-cleanup`
- Interpretation:
  - the top-level pass timer tells us the lifted pass actually ran
  - the detail timers tell us which late cleanup phases were still exercised
  - a raw-skip family that correctly avoids lift should usually avoid these timers entirely

### Raw Trace Reasons

- `src/passes/pass_manager_wbtest.mbt` and `src/passes/perf_test.mbt` assert on `pass[simplify-locals]:skip-raw reason=...` trace text.
- These reasons are not cosmetic logging.
- They are the stable contract for the exact artifact families the pass manager is allowed to bypass.

### Artifact Replay

- The canonical large-artifact comparison remains the self-opt compare lane on `tests/node/dist/starshine-debug-wasi.wasm`.
- That lane is the only place where:
  - wide artifact parity
  - real skip distribution
  - real runtime concentration
  can all be seen together.

### Backlog Snapshot

- `agent-todo.md` is still the live scratchpad for the newest frontier reductions.
- This page only carries conclusions that were stable enough to survive one session.

## Skip-Reason Taxonomy

### Large Structured Call-Heavy Families

- `giant-structured-call-heavy`
  - very large structured helpers where lift cost dominates and the reduced evidence says the pass is effectively no-op
- `medium-structured-call-heavy`
  - smaller but still expensive structured helpers
- `transformer-structured-call-heavy`
  - transformer-shaped walkers with heavy local churn
- `decode-structured-call-heavy`
  - decode-shaped helpers with repeated structured call traffic
- `branchy-decode-structured-call-heavy`
  - decode helpers where branch fanout makes the hot lift cost even worse
- `dense-structured-call-heavy`
  - dense low-loop helpers with enough call and local churn that raw skip wins
- `validator-structured-call-heavy`
  - validator-shaped loop-heavy structured walkers
  - this family mattered both for performance and correctness because several retained parity fixes were implemented as narrow raw rewrites that run before the skip
- `loop-heavy-structured-call-heavy`
  - compact and medium loop-heavy walkers that are still not good lift candidates
- `parser-structured-call-heavy`
  - parser-shaped structured local churn
- `giant-structured-local-churn`
  - very large helpers dominated more by local traffic than by meaningful simplify-locals wins

### Linear Builder And Churn Families

- `straight-line-builder-churn`
  - straight-line local churn that does not justify lift
- `huge-straight-line-call-builder`
  - even larger builder initializers with enough tee and call traffic that the raw lane should bail immediately

### Specialty Families

- `stringview-trim-loop-churn`
  - dedicated stringview trim family
- `multivalue-call-heavy-ladder`
  - special-case raw gate for i32-pair result ladders
  - this one is not only a performance family; it also marks an explicit semantic boundary because the repo intentionally avoids the broader multivalue tee/sink surface

## What The Skip Families Are For

- They are not "give up on parity" switches.
- They exist only when the project has evidence that:
  - the function family is effectively a no-op for simplify-locals, or
  - a very narrow raw rewrite plus cheap cleanup captures the meaningful win without paying full lift cost
- If a family still contains real exact-path parity work, the correct fix is usually a narrower rewrite or a better lifted rule, not a broader skip.

## Raw Rewrite Families That Matter To Performance

- `structured-pure-copy-call-tail`
  - narrow raw cleanup of copied locals and later pure tails
- effectful suffix local-get sinking
  - narrow validator-heavy family that now sinks single-use effectful temps through safe pure barriers
- pure suffix local-set sinking
  - copied-local cleanup that avoids waking the full pass for known artifact tails
- adjacent local-tee cleanup
  - cheap exact rewrite for obvious local churn
- straight-line lane-builder rewrite
  - targeted cleanup for builder-shaped local traffic

## Retired Hotspot Families

### Artifact Families Retired For Correctness And Cost

- Old `Func 216`
  - single-use `if (result i32)` call-argument sink family retired in-tree
- `StringView.make_init_no_rc`
  - loop-carried initializer wrong-code family retired
- old `moonbit.malloc` sibling-order drift
  - retired by better nested local-effect collection and leading-path restrictions
- old `Func 41`
  - tee-backed alias drift retired
- old `Func 50` validator-skip temp drift
  - retired by raw validator-skip cleanup that now sinks effectful temps across safe local-copy barriers

### Artifact Families Retired Primarily For Runtime

- `Func 1800`
  - now covered by `huge-straight-line-call-builder`
- `Func 395`, `430`, `818`, `2083`, `2098`
  - now covered by `dense-structured-call-heavy`

## Current Frontier Snapshot

### Dated Status

- The statements in this section are a dated snapshot from 2026-04-10.
- They should be refreshed when the current compare frontier moves materially.

### Remaining Exact-Path Frontier

- The old first mismatch was narrowed down far enough that the active frontier is no longer only the old validator raw-skip family.
- `agent-todo.md` records that:
  - the unreduced artifact frontier still references absolute `Func 71` / WAT `$50`
  - the old loop-temp `$273 / $276` drift is gone
  - the remaining early drift there involves Binaryen-only `nop` sentinels and a deeper call-indirect block chain

### Later Unchanged Exact-Path Drifts

- The newer important finding is that unchanged exact-path functions such as `Func 386` and `Func 399` still differ even when Starshine reports `changed=false`.
- That means the next work bucket is not automatically another raw-skip tweak.
- Some of the remaining work is exact-path canonical-shape parity.

### Remaining Hotspot Cluster

- The active cluster called out in `agent-todo.md` is now led by:
  - `Func 473`
  - `Func 308`
  - `Func 1488`
- These are the functions most likely to determine the next runtime reduction after the already-retired builder and dense structured helper families.

## Current Runtime Snapshot

- `agent-todo.md` records a traced native checkpoint of `pass:simplify-locals total_us=2278863`.
- The same dated snapshot records a self-opt compare checkpoint where Starshine was still far slower than Binaryen on the large artifact.
- Treat those numbers as evidence of direction, not as eternal constants.
- The durable conclusion is:
  - the pass has improved significantly
  - it is still not within the desired steady-state budget on the debug artifact

## Project Performance Rule

- Per `AGENTS.md`, parity bugs are primary and performance work is secondary.
- The performance target remains:
  - under one second wall time where possible, or
  - at least half of Binaryen wall time where possible
- A performance shortcut that introduces a Binaryen parity regression is not a valid simplify-locals win.

## Maintenance Rule

- When a new skip family is added, record:
  - the helper that implements it
  - the trace reason string
  - the owning perf or whitebox test
  - whether it is a pure skip or a narrow raw rewrite plus skip
- When a hotspot is retired, remove it from `agent-todo.md` and fold only the durable result into this page.
