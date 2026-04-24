---
kind: comparison
status: working
last_reviewed: 2026-04-15
sources:
  - ../../../../../agent-todo.md
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/passes/pass_manager_wbtest.mbt
  - ../../../../../src/passes/perf_test.mbt
  - ../../../../../src/passes_perf_long/simplify_locals_multivalue_perf_test.mbt
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
  - which artifact frontiers still matter as of 2026-04-15

## Measurement Sources

### Perf Timers

- `src/passes/perf_test.mbt` asserts on:
  - `perf:timer name=pass:simplify-locals`
  - `perf:timer name=detail:simplify-locals:equivalent-cleanup`
  - `perf:timer name=detail:simplify-locals:late-dead-cleanup`
- `src/passes_perf_long/simplify_locals_multivalue_perf_test.mbt` keeps the intentionally slower multivalue ladder stress shapes on a separate opt-in command lane.
- Interpretation:
  - the top-level pass timer tells us the lifted pass actually ran
  - the detail timers tell us which late cleanup phases were still exercised
  - a raw-skip family that correctly avoids lift should usually avoid these timers entirely
  - the default `moon test src/passes` loop should stay lean even when one stress family still needs a larger synthetic witness

### Raw Trace Reasons

- `src/passes/pass_manager_wbtest.mbt`, `src/passes/perf_test.mbt`, and `src/passes_perf_long/simplify_locals_multivalue_perf_test.mbt` assert on `pass[simplify-locals]:skip-raw reason=...` trace text.
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
- `branch-dense-structured-call-heavy-noop`
  - branch-dense helpers with many `if`s, low block counts, and enough repeated calls and local reads that lift is mostly wasted work
- `block-rich-structured-call-heavy-noop`
  - block-heavy structured helpers with moderate writes and repeated calls where traced and synthetic evidence say simplify-locals is effectively no-op
- `call-dense-structured-walker-noop`
  - structured walkers dominated by repeated calls and local reads rather than profitable local cleanup
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
- `low-local-decision-ladder-noop`
  - low-local decision ladders with many structured comparisons and later calls where raw skip is cheaper than relifting an unchanged helper

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

- The statements in this section are a dated snapshot from 2026-04-15.
- They should be refreshed when the current compare frontier or raw-skip roster moves materially.

### Remaining Exact-Path Frontier

- The old first mismatch was narrowed down far enough that the active frontier is no longer only the old validator raw-skip family.
- `agent-todo.md` records that:
  - the unreduced artifact frontier still references absolute `Func 71` / WAT `$50`
  - the old loop-temp `$273 / $276` drift is gone
  - the old validator condition-temp `$5` drift is gone too
  - the old `$928 -> $549` store shuttle is gone too after the new validator-skip pure-copy cleanup
  - the rebuilt-binary replay at `/tmp/starshine-self-optimize-compare-starshine-debug-wasi-2522582` no longer shows the returning-statement `$739 -> $18` copied-local carrier
  - the same replay retires the sibling `$735 -> $24` condition-copy carrier too
  - the first remaining diffs there now start at the nested `$930/$931/$932/$933` branch-carrier and constant-fanout groups
  - the older block-result `local.tee $7` carrier is no longer the first reported diff

### Later Unchanged Exact-Path Drifts

- The newer important finding is that unchanged exact-path functions such as `Func 386` and `Func 399` still differ even when Starshine reports `changed=false`.
- That means the next work bucket is not automatically another raw-skip tweak.
- Some of the remaining work is exact-path canonical-shape parity.

### Remaining Hotspot Cluster

- The generic branchy helper hotspot cluster is no longer only an implicit trace note.
- The repo now carries explicit raw-skip contracts for:
  - `branch-dense-structured-call-heavy-noop`
  - `block-rich-structured-call-heavy-noop`
  - `call-dense-structured-walker-noop`
  - `low-local-decision-ladder-noop`
- That means the next default-lane no-op helper family is pinned in-tree by wbtests and perf witnesses instead of living only as an unnamed artifact hotspot.
- The active cluster still called out in `agent-todo.md` is now led by:
  - `Func 473`
  - `Func 308`
  - `Func 1488`
- These are the functions most likely to determine the next runtime reduction after the already-retired builder, dense structured helper, and newer helper-ladder no-op families.

## Current Runtime Snapshot

- `agent-todo.md` records a traced native checkpoint of `pass:simplify-locals total_us=2278863`.
- The same dated snapshot records a self-opt compare checkpoint where Starshine was still far slower than Binaryen on the large artifact.
- The latest direct native-binary sample on 2026-04-14 is:
  - `.tmp/self-opt-sl-current-2026-04-14`
  - Starshine `5316.608ms` total / `2190.921ms` in-pass
  - Binaryen `519.714ms` total / `264.709ms` in-pass
  - `starshinePassSkippedRaw=true`
  - `normalizedWatEqual=true`
  - `canonicalFuncPrettyEqual=true`
  - but `wasmEqual=false` and `normalizedWatTextEqual=false`
- So the current keep-state has closed the canonical per-function artifact mismatch on the checked-in debug artifact, but it is still far over the project runtime budget and still not byte/text identical to Binaryen.
- The latest dated sample on 2026-04-10 is still useful as historical progression data:
  - earlier same-day replay: Starshine `6069.134ms` total / `2733.866ms` in-pass, Binaryen `645.476ms` / `307.434ms`
  - latest replay after the pure-copy cleanup: Starshine `5484.740ms` total / `2394.874ms` in-pass, Binaryen `575.087ms` / `287.154ms`
  - latest replay after the rebuilt-binary returning-condition copy fix: Starshine `5618.329ms` total / `2572.867ms` in-pass, Binaryen `608.776ms` / `289.612ms`
  - latest replay after the clean native rebuild and the reduced dupable-fanout batch cleanup: Starshine `5122.776ms` total / `2333.173ms` in-pass, Binaryen `532.565ms` / `265.177ms`
- The new validator-heavy recursive pure-call-tail fix broadens the skip-lane work:
  - the reduced heavy regression is green and fuzz-clean at `2000/2000`
  - the earlier `5957`-case `moon run` launcher failure is now historical noise, not the current state
  - the same family now has a clean long lane: `.tmp/pass-fuzz-sl-validator-call-tail-gated-10k` finished at `10000/10000` normalized matches with `0` mismatches in `575.34s`
- The 2026-04-10 follow-up performance containment step narrowed that cost without changing the known frontier:
  - the recursive validator-skip pure-call-tail fixpoint now checks a cheap nested candidate scan before rerunning another full rewrite pass
  - `.tmp/pass-fuzz-sl-validator-call-tail-gated` stayed green at `2000/2000` normalized matches with `0` mismatches
  - the same gated 2k lane took `144.79s` wall clock on the local machine
  - the later pure-suffix containment step applies the same idea to the recursive pure-suffix fixpoint; `.tmp/pass-fuzz-sl-pure-suffix-gated-2k` stayed green at `2000/2000` in `147.61s`
  - the binary-backed long lane for that current keep-state, `.tmp/pass-fuzz-sl-pure-suffix-gated-10k-binary`, stayed green at `10000/10000` in `452.56s`
  - do not read the `452.56s` binary-backed number as a pure pass speedup over the earlier `575.34s` `moon run` lane; it also removes launcher overhead
  - the durable claim is only that the current keep-state is parity-clean on long lanes and that long compare-pass signoff should prefer a fixed native binary when the goal is to measure pass work instead of `moon run`
  - the newer returning-condition copy fix is also long-lane clean on a rebuilt binary: `.tmp/pass-fuzz-sl-next-if-condition-10k` finished at `10000/10000` normalized matches with `0` mismatches in `435.77s`
  - the dupable-fanout batch cleanup is also long-lane clean on the rebuilt binary: `.tmp/pass-fuzz-sl-fanout-batch-10k-clean` finished at `10000/10000` normalized matches with `0` mismatches in `432.24s`
  - the newer terminal-value pure-suffix cleanup is also long-lane clean on the rebuilt binary: `.tmp/pass-fuzz-sl-terminal-value-10k` finished at `10000/10000` normalized matches with `0` mismatches in `423.58s`
- The same 2026-04-10 follow-up also reinforced one process rule:
  - when native artifact timing is the thing being measured, force a clean native rebuild if the replay output looks unchanged in a suspicious way
  - the incremental native build produced a replay at `/tmp/starshine-self-optimize-compare-starshine-debug-wasi-2832774` that kept the old timing envelope and old frontier text
  - the forced clean rebuild moved the timing snapshot materially, so `/tmp/starshine-self-optimize-compare-starshine-debug-wasi-3176570` is the authoritative replay for this checkpoint
- The newer returning dense fanout fix changed the interpretation of the remaining cost:
  - `.tmp/pass-fuzz-sl-returning-const-fanout-2k` is green at `2000/2000` in `105.16s`
  - `.tmp/pass-fuzz-sl-returning-const-fanout-10k` is green at `10000/10000` in `478.26s`
  - `_build/native/release/build/cmd/cmd.exe --simplify-locals --print-func 71 ...` now shows the in-memory `Func 71` tree without the old `$930..$934` carriers or the `$540` / `$557` dense const webs
  - but the authoritative replay at `/tmp/starshine-self-optimize-compare-starshine-debug-wasi-1018195` is still red and slower than Binaryen: Starshine `6454.014ms` total / `2883.642ms` in-pass versus Binaryen `688.875ms` / `326.287ms`
  - so the remaining budget problem is now tied to the encoded-output / Binaryen-reparse frontier, not to the newly-fixed in-memory raw reducer
- The terminal-value follow-up on the same day improved the runtime envelope again without retiring the encoded frontier:
  - the new whitebox terminal-value regressions are green and the direct short lane `.tmp/pass-fuzz-sl-terminal-value-2k` is green at `2000/2000` in `94.88s`
  - the authoritative latest replay is now `/tmp/starshine-self-optimize-compare-starshine-debug-wasi-3772265`
  - that replay is still red on the same first `Func 71` line-`4860` `$930` carrier, but the timings improved materially versus the immediately preceding replay `/tmp/starshine-self-optimize-compare-starshine-debug-wasi-2841891`
  - previous replay: Starshine `8285.709ms` total / `3432.549ms` in-pass, Binaryen `937.833ms` / `466.100ms`
  - latest replay: Starshine `6455.017ms` total / `2593.016ms` in-pass, Binaryen `582.593ms` / `294.366ms`
  - the durable interpretation is that the narrower terminal-value rewrite removed real validator-heavy pass work, but it did not retire the encoded-output parity family that still dominates the first visible mismatch
- The later sentinel-and-branch follow-up changed the envelope again:
  - the Binaryen-sentinel alignment for terminal dupable tails stayed clean on `.tmp/pass-fuzz-sl-terminal-sentinel-2k` and `.tmp/pass-fuzz-sl-terminal-sentinel-10k`, with the long lane finishing at `10000/10000` in `467.03s`
  - the branch-terminated carrier guard stayed clean on `.tmp/pass-fuzz-sl-branch-terminated-carrier-2k` and `.tmp/pass-fuzz-sl-branch-terminated-carrier-10k`, with the long lane finishing at `10000/10000` in `404.01s`
  - the authoritative current replay is now `/tmp/starshine-self-optimize-compare-starshine-debug-wasi-3936664`
  - that replay is still red on the same remaining `Func 71` subgroup, now visible at line `5313`, where Binaryen still has `nop` and Starshine still has `local.set $930`
  - but the timings improved materially versus the immediately previous replay `/tmp/starshine-self-optimize-compare-starshine-debug-wasi-2445261`
  - previous replay: Starshine `6558.878ms` total / `2761.565ms` in-pass, Binaryen `677.653ms` / `326.029ms`
  - latest replay: Starshine `5556.185ms` total / `2380.989ms` in-pass, Binaryen `552.845ms` / `269.518ms`
  - the durable interpretation is that the newer reduced proofs and guards are cutting real validator-skip work on the artifact, but the surviving `$62 -> $930 -> $38` branch carrier still keeps parity red
- Treat those numbers as evidence of direction, not as eternal constants.
- The durable conclusion is:
  - the pass has improved significantly
  - recent validator raw-skip parity fixes keep moving the frontier, but the debug artifact is still far over budget
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
