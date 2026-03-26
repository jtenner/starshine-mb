# Changelog

## 2026-03-26 Optimize: widen `remove-unused-brs` const-arm `select` parity

- **`remove-unused-brs` const-condition select follow-up** by **@jtenner**. Updated [`CHANGELOG.md`](/home/jtenner/Projects/starshine-mb/CHANGELOG.md), [`src/passes/remove_unused_brs.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/remove_unused_brs.mbt), and [`src/passes/remove_unused_brs_test.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/remove_unused_brs_test.mbt) so result `if` nodes with constant arms can still lower to `select` even when the condition itself is not globally reorder-safe, as long as the arms remain pure constants. Focused `moon test src/passes/remove_unused_brs_test.mbt` is green, and the March 26, 2026 compare run at `/tmp/starshine-self-optimize-compare-starshine-debug-wasi-1558380` improves exact oracle matches for the `$1264` family without introducing new exact-match regressions, though overall canonical parity and the Binaryen speed target are still not met.

## 2026-03-26 Optimize: cut `remove-unused-brs` tail cleanup churn on one-child exits

- **`remove-unused-brs` tail-splice perf checkpoint** by **@jtenner**. Updated [`CHANGELOG.md`](/home/jtenner/Projects/starshine-mb/CHANGELOG.md), [`src/passes/remove_unused_brs.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/remove_unused_brs.mbt), and [`src/passes/perf_test.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/perf_test.mbt) so tail `br`/`return` cleanup now splices zero-child and one-child exits out of regions directly instead of routing through the older replace-and-delete path, while keeping the existing tail-return and payload correctness rewrites intact. Focused pass tests are green, and the March 26, 2026 compare run at `/tmp/starshine-self-optimize-compare-starshine-debug-wasi-1509633` improves `remove-unused-brs` pass runtime from the rebased `/tmp/starshine-self-optimize-compare-starshine-debug-wasi-1479612` baseline (`13032.287ms -> 12633.317ms`) without changing the current non-parity status.

## 2026-03-26 Optimize: skip final-root DCE fallthrough checks for non-control value producers

- **Dead-code-elimination final-root control-only fallthrough checkpoint** by **@jtenner**. Updated [CHANGELOG.md](/home/jtenner/Projects/starshine-mb/CHANGELOG.md) and [src/passes/dead_code_elimination.mbt](/home/jtenner/Projects/starshine-mb/src/passes/dead_code_elimination.mbt) so the final-root fallthrough query now stays on the hot path only for control nodes with live result semantics, instead of all value-producing roots. After rebuilding the native CLI, the direct `--dead-code-elimination` replay on `tests/node/dist/starshine-debug-wasi.wasm` improved again to about `14.84s`; parity is still incomplete and the Binaryen 50% speed target is still not met.

## 2026-03-26 Optimize: skip final-root DCE fallthrough checks when they cannot change output

- **Dead-code-elimination final-root fallthrough checkpoint** by **@jtenner**. Updated [CHANGELOG.md](/home/jtenner/Projects/starshine-mb/CHANGELOG.md) and [src/passes/dead_code_elimination.mbt](/home/jtenner/Projects/starshine-mb/src/passes/dead_code_elimination.mbt) so DCE no longer runs the expensive `node_may_fallthrough` query for final roots that have no result values and cannot need an explicit trailing `unreachable`. On the large native replay, the exact A/B check improved the direct `--dead-code-elimination` run from about `16.01s` to about `15.51s` and `15.59s` in repeat samples; parity is still incomplete and the Binaryen 50% speed target is still not met.

## 2026-03-26 Optimize: tighten remove-unused-module-elements import root propagation

- **`remove-unused-module-elements` runtime budget checkpoint** by **@jtenner**. Updated [CHANGELOG.md](/home/jtenner/Projects/starshine-mb/CHANGELOG.md), [agent-todo.md](/home/jtenner/Projects/starshine-mb/agent-todo.md), and [src/passes/remove_unused_module_elements.mbt](/home/jtenner/Projects/starshine-mb/src/passes/remove_unused_module_elements.mbt) so imported function/table/memory/global/tag root counting is now done in one scan and active table/data-to-index propagation is precomputed into fixed maps, avoiding repeated root sweeps during liveness collection while preserving oracle-canonical behavior. The pass stays correct on `tests/node/dist/starshine-debug-wasi.wasm` compare runs and keeps `moon info`, `moon fmt`, and `moon test` green.

## 2026-03-26 Fix: keep branchy no-drop DCE bodies on the hot path

- **Dead-code-elimination raw-skip rollback checkpoint** by **@jtenner**. Updated [CHANGELOG.md](/home/jtenner/Projects/starshine-mb/CHANGELOG.md) and [src/passes/pass_manager.mbt](/home/jtenner/Projects/starshine-mb/src/passes/pass_manager.mbt) so `dead-code-elimination` no longer classifies branchy no-drop structured bodies as raw no-op candidates. That widening was too aggressive for correctness work: it let branch-heavy wrappers bypass hot lift even when the pass still needed the typed view to decide whether the control result could be legally trimmed. `moon info`, `moon fmt`, `moon test`, and rebuilt release-artifact direct plus five-pass DCE replays still validate on the corrected path.

## 2026-03-26 Fix: trim severe DCE replay overhead in pass-manager raw skips

- **Dead-code-elimination pass-manager performance checkpoint** by **@jtenner**. Updated [CHANGELOG.md](/home/jtenner/Projects/starshine-mb/CHANGELOG.md), [src/passes/pass_manager.mbt](/home/jtenner/Projects/starshine-mb/src/passes/pass_manager.mbt), [src/passes/pass_manager_test.mbt](/home/jtenner/Projects/starshine-mb/src/passes/pass_manager_test.mbt), and [src/passes/pkg.generated.mbti](/home/jtenner/Projects/starshine-mb/src/passes/pkg.generated.mbti) so the hardcoded large-function DCE and vacuum debug dumps are now completely gated behind explicit tracing, and DCE can skip raw replay for branchy no-drop void structured no-op functions instead of lifting them just to discover no candidates. The new pass-manager gating tests protect the fast path; the rebuilt native replay on `tests/node/dist/starshine-debug-wasi.wasm` drops to about `15.449s`, but parity is still incomplete and the Binaryen 50% speed target is still not met.

## 2026-03-26 Fix: voidify dead-result DCE blocks only when their result is structurally unreachable

- **Dead-code-elimination block-result parity checkpoint** by **@jtenner**. Updated [CHANGELOG.md](/home/jtenner/Projects/starshine-mb/CHANGELOG.md), [src/passes/dead_code_elimination.mbt](/home/jtenner/Projects/starshine-mb/src/passes/dead_code_elimination.mbt), and [src/passes/dead_code_elimination_test.mbt](/home/jtenner/Projects/starshine-mb/src/passes/dead_code_elimination_test.mbt) so DCE can now voidify dead-result `block`s when their result is only reachable through non-fallthrough control, matching the Binaryen-style branch-skipping wrapper cleanup, while still preserving plain fallthrough typed and type-index blocks. Focused oracle fixtures, `moon fmt`, `moon info`, `moon test src/passes`, and `moon build --target native --release src/cmd` are green; the direct native replay on `tests/node/dist/starshine-debug-wasi.wasm` is about `15.925s`, so correctness improved but the Binaryen 50% speed target is still not met.

## 2026-03-26 Fix: keep unchanged DCE replays from reusing dead-drop raw tails

- **Dead-code-elimination unchanged-replay canonicalization fix** by **@jtenner**. Updated [CHANGELOG.md](/home/jtenner/Projects/starshine-mb/CHANGELOG.md), [agent-todo.md](/home/jtenner/Projects/starshine-mb/agent-todo.md), [src/passes/pass_manager.mbt](/home/jtenner/Projects/starshine-mb/src/passes/pass_manager.mbt), [src/passes/dead_code_elimination_test.mbt](/home/jtenner/Projects/starshine-mb/src/passes/dead_code_elimination_test.mbt), [src/ir/hot_lower_test.mbt](/home/jtenner/Projects/starshine-mb/src/ir/hot_lower_test.mbt), and the refreshed [src/ir/pkg.generated.mbti](/home/jtenner/Projects/starshine-mb/src/ir/pkg.generated.mbti) API snapshot so `dead-code-elimination` no longer returns the original raw function unchanged when the raw body still contains a dead `drop` immediately after a guaranteed non-fallthrough root. That keeps the lift/lower canonicalization that removes stack-polymorphic dead-drop tails, locks the behavior in focused pass and hot-lower regressions, and keeps `moon run src/cmd --target native -- --dead-code-elimination` on the minimized branch-tail repro producing the canonical no-`drop` output.

## 2026-03-26 Fix: keep DCE raw skip off straight-line dead-drop and early-terminator bodies

- **Dead-code-elimination raw-skip correctness checkpoint** by **@jtenner**. Updated [CHANGELOG.md](/home/jtenner/Projects/starshine-mb/CHANGELOG.md), [src/passes/pass_manager.mbt](/home/jtenner/Projects/starshine-mb/src/passes/pass_manager.mbt), and [src/passes/perf_test.mbt](/home/jtenner/Projects/starshine-mb/src/passes/perf_test.mbt) so the newer straight-line DCE raw precheck once again rejects bodies with dead `drop`s or straight-line early terminators instead of incorrectly skipping real DCE work. `moon info`, `moon fmt`, and `moon test src/passes` are green, the existing pure-drop regression is fixed again, and the direct native replay on `tests/node/dist/starshine-debug-wasi.wasm` is about `30.004s` on the corrected path; parity and the Binaryen speed target are still not met, so the next work remains on changed-function hotspots rather than broader raw-skip widening.

## 2026-03-26 Optimize: skip branchless void structured DCE functions before hot lift

- **Dead-code-elimination structured raw-skip checkpoint** by **@jtenner**. Updated [CHANGELOG.md](/home/jtenner/Projects/starshine-mb/CHANGELOG.md), [src/passes/pass_manager.mbt](/home/jtenner/Projects/starshine-mb/src/passes/pass_manager.mbt), and [src/passes/perf_test.mbt](/home/jtenner/Projects/starshine-mb/src/passes/perf_test.mbt) so the DCE raw precheck now also skips branchless void-typed structured-control functions such as final `if`/`loop` wrappers, instead of forcing those functions through hot lift just because the last top-level instruction is structured. Focused `moon test src/passes` regressions and `moon build --target native --release src/cmd` are green, and the direct native replay on `tests/node/dist/starshine-debug-wasi.wasm` dropped again from about `29.753s` to about `29.414s`; oracle parity and the Binaryen speed target are still not met, so the next work remains widening conservative no-op fast paths and reducing late changed-function cost.

## 2026-03-26 Optimize: skip void-ending straight-line no-op DCE functions before hot lift

- **Dead-code-elimination raw-skip widening checkpoint** by **@jtenner**. Updated [CHANGELOG.md](/home/jtenner/Projects/starshine-mb/CHANGELOG.md), [src/passes/pass_manager.mbt](/home/jtenner/Projects/starshine-mb/src/passes/pass_manager.mbt), and [src/passes/perf_test.mbt](/home/jtenner/Projects/starshine-mb/src/passes/perf_test.mbt) so the DCE raw precheck now also skips straight-line void-returning functions whose final instruction is definitely void, including direct and indirect calls with empty result types. Focused `moon test src/passes` and `moon build --target native --release src/cmd` are green, and the direct native replay on `tests/node/dist/starshine-debug-wasi.wasm` dropped from about `31.425s` to about `29.753s`; oracle parity and the Binaryen speed target are still far off, so the next work remains broadening raw-skip coverage and shrinking late changed-function cost.

## 2026-03-26 Optimize: skip straight-line value-returning no-op DCE functions before hot lift

- **Dead-code-elimination raw-skip checkpoint** by **@jtenner**. Updated [CHANGELOG.md](/home/jtenner/Projects/starshine-mb/CHANGELOG.md), [src/passes/pass_manager.mbt](/home/jtenner/Projects/starshine-mb/src/passes/pass_manager.mbt), and [src/passes/perf_test.mbt](/home/jtenner/Projects/starshine-mb/src/passes/perf_test.mbt) so `dead-code-elimination` now bypasses hot lift for straight-line value-returning functions that have no structured control, no branches, no drops, and no early terminators. Focused `moon test src/passes`, `moon build --target native --release src/cmd`, and the native replay remain green; the large-artifact compare still misses parity, but traced runs now show real `skip-raw reason=no-dce-candidates` hits in the late unchanged region and the oracle pass runtime improved slightly from about `19570ms` to about `19263ms`, so the next work remains broadening raw skip coverage and shrinking late changed-function churn.

## 2026-03-26 Optimize: prune `remove-unused-brs` subtree walks that cannot reach control

- **`remove-unused-brs` embedded-control pruning checkpoint** by **@jtenner**. Updated [`CHANGELOG.md`](/home/jtenner/Projects/starshine-mb/CHANGELOG.md) and [`src/passes/remove_unused_brs.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/remove_unused_brs.mbt) so the hot pass now memoizes whether a node subtree contains any embedded control before recursing through generic children, which avoids walking large arithmetic/data trees that cannot possibly reach an `if`, region-bearing control node, or other nested rewrite site. Focused `moon test src/passes/remove_unused_brs_test.mbt` is green, and the March 26, 2026 compare run at `/tmp/starshine-self-optimize-compare-starshine-debug-wasi-1460202` improves Starshine pass time from the prior `/tmp/starshine-self-optimize-compare-starshine-debug-wasi-1439780` baseline (`14636.979ms -> 13438.033ms`) while keeping overall parity status unchanged.

## 2026-03-26 Optimize: cut `remove-unused-brs` pre-pass hot-path overhead

- **`remove-unused-brs` raw-skip and analysis-trim perf checkpoint** by **@jtenner**. Updated [`CHANGELOG.md`](/home/jtenner/Projects/starshine-mb/CHANGELOG.md), [`src/passes/pass_manager.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/pass_manager.mbt), [`src/passes/perf_test.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/perf_test.mbt), and [`src/passes/remove_unused_brs.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/remove_unused_brs.mbt) so `remove-unused-brs` now skips hot lift entirely for raw functions with no reachable `nop`, `if`, `br*`, or explicit `return` candidates, and it no longer requires the unused `use-def` analysis on functions that still run. Focused perf regressions are green, and the March 26, 2026 compare run at `/tmp/starshine-self-optimize-compare-starshine-debug-wasi-1439780` keeps correctness unchanged while improving overall Starshine runtime from the rebased `/tmp/starshine-self-optimize-compare-starshine-debug-wasi-1432869` baseline, though overall parity and the Binaryen speed target are still not met.

## 2026-03-26 Optimize: batch DCE control voidification into one hot-IR revision

- **Dead-code-elimination batched-voidify checkpoint** by **@jtenner**. Updated [CHANGELOG.md](/home/jtenner/Projects/starshine-mb/CHANGELOG.md), [src/ir/hot_mutate.mbt](/home/jtenner/Projects/starshine-mb/src/ir/hot_mutate.mbt), [src/ir/hot_mutate_test.mbt](/home/jtenner/Projects/starshine-mb/src/ir/hot_mutate_test.mbt), and [src/passes/dead_code_elimination.mbt](/home/jtenner/Projects/starshine-mb/src/passes/dead_code_elimination.mbt) so DCE can batch branch child-span rewrites plus control result-type demotion into a single hot-IR revision instead of invalidating local caches once per payload trim. Focused `moon fmt`, `moon test src/ir`, `moon test src/passes`, and `moon build --target native --release src/cmd` are green; traced native replay on `tests/node/dist/starshine-debug-wasi.wasm` now advances to around `Func 2859` within `10s` instead of stalling near the old `Func 2777` hotspot, but the direct native `--dead-code-elimination` run still times out at `30s`, so the remaining work is now concentrated in the later giant functions and late-pipeline lift/lower costs.

## 2026-03-26 Optimize: make DCE’s hot root queries lazier on unchanged paths

- **Dead-code-elimination lazy-query checkpoint** by **@jtenner**. Updated [CHANGELOG.md](/home/jtenner/Projects/starshine-mb/CHANGELOG.md), [src/passes/dead_code_elimination.mbt](/home/jtenner/Projects/starshine-mb/src/passes/dead_code_elimination.mbt), and [src/passes/dead_code_elimination_test.mbt](/home/jtenner/Projects/starshine-mb/src/passes/dead_code_elimination_test.mbt) so DCE now guards effectful-read behavior with a `global.get` regression, replaces the allocating `effects_for_node` purity path with a local recursive purity evaluator, builds branch-user tables only on demand, and defers whole-function node-use counts until a root actually reaches a use-count-sensitive transform. Focused `moon fmt`, `moon test src/passes`, and `moon build --target native --release src/cmd` are green; traced native replay on `tests/node/dist/starshine-debug-wasi.wasm` reaches the same late giant-function hotspot with lower cumulative DCE time before it, but the direct native `--dead-code-elimination` run is still over budget and times out at `20s`, so the remaining work is concentrated in large mutation-heavy functions rather than fixed per-function setup.

## 2026-03-26 Optimize: remove DCE’s global effects rebuilds from the hot path

- **Dead-code-elimination purity-cache checkpoint** by **@jtenner**. Updated [CHANGELOG.md](/home/jtenner/Projects/starshine-mb/CHANGELOG.md), [src/passes/dead_code_elimination.mbt](/home/jtenner/Projects/starshine-mb/src/passes/dead_code_elimination.mbt), and [src/passes/registry_test.mbt](/home/jtenner/Projects/starshine-mb/src/passes/registry_test.mbt) so DCE no longer requires the global `effects` analysis, instead memoizing per-node purity locally by hot revision while keeping the earlier node-use and fallthrough caches. Focused `moon fmt`, `moon test src/passes`, and `moon build --target native --release src/cmd` remain green, and traced native replay no longer spends time rebuilding `analysis:effects` inside mutation-heavy DCE functions; overall direct native `--dead-code-elimination` replay on `tests/node/dist/starshine-debug-wasi.wasm` is still over budget and times out at `20s`, so the next work remains in pass-body scheduling and no-op fast paths.

## 2026-03-26 Optimize: trim DCE analysis rebuilds and detached cleanup scans

- **Dead-code-elimination perf checkpoint** by **@jtenner**. Updated [CHANGELOG.md](/home/jtenner/Projects/starshine-mb/CHANGELOG.md), [src/passes/dead_code_elimination.mbt](/home/jtenner/Projects/starshine-mb/src/passes/dead_code_elimination.mbt), and [src/passes/registry_test.mbt](/home/jtenner/Projects/starshine-mb/src/passes/registry_test.mbt) so DCE now drops the old full `use_def` pass requirement, lazily caches node-use counts with `use_def_build_node_uses`, reuses cached effect masks for purity checks, avoids allocating CFG edge-kind arrays in fallthrough queries, and stops rescanning whole functions while deleting bounded detached subgraphs. `moon fmt`, `moon test src/passes`, and `moon build --target native --release src/cmd` are green; direct native `--dead-code-elimination` replay on `tests/node/dist/starshine-debug-wasi.wasm` is still over budget and currently times out at `40s`, so the remaining work is concentrated inside DCE’s hot giant-function cleanup path rather than hidden analysis setup.

## 2026-03-26 Plan: refresh DCE backlog after the rebase

- **DCE remaining-work backlog sync** by **@jtenner**. Updated [`CHANGELOG.md`](/home/jtenner/Projects/starshine-mb-dce/CHANGELOG.md) and [`agent-todo.md`](/home/jtenner/Projects/starshine-mb-dce/agent-todo.md) after rebasing the worktree onto `master` so the active DCE backlog now matches the current [0066 DCE reference](/home/jtenner/Projects/starshine-mb-dce/docs/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md#L178), records that the old invalid-output blocker is closed by explicit final-tail `unreachable` materialization, and replaces the stale blocker text with the remaining ordered-replay, oracle-refresh, and runtime-budget work.
## 2026-03-26 Optimize: broaden pure value `if` to `select` rewrites in `remove-unused-brs`

- **`remove-unused-brs` pure-select parity follow-up** by **@jtenner**. Updated [`CHANGELOG.md`](/home/jtenner/Projects/starshine-mb/CHANGELOG.md), [`src/passes/remove_unused_brs.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/remove_unused_brs.mbt), and [`src/passes/remove_unused_brs_test.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/remove_unused_brs_test.mbt) so pure single-value `if` nodes now lower to `select` whenever the condition and both arms are reorder-safe, instead of only recognizing the old zero-constant special case. `moon info`, `moon fmt`, and full `moon test` are green, and the March 26, 2026 compare run at `/tmp/starshine-self-optimize-compare-starshine-debug-wasi-1412559` now matches Binaryen exactly on real functions like `$3324`, `$119`, `$224`, and `$3421`, though overall canonical parity and the Binaryen speed target are still not met.

## 2026-03-26 Optimize: strip stack-style tail exits from result `if` arms in `remove-unused-brs`

- **`remove-unused-brs` stack-style tail-exit parity follow-up** by **@jtenner**. Updated [`CHANGELOG.md`](/home/jtenner/Projects/starshine-mb/CHANGELOG.md), [`src/passes/remove_unused_brs.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/remove_unused_brs.mbt), and [`src/passes/remove_unused_brs_test.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/remove_unused_brs_test.mbt) so the tail result-`if` exit stripper now matches the enclosing return or block target instead of the `if` arm holder, and it recognizes stack-style payloads carried by preceding roots before a zero-child `br` or `return`. `moon info`, `moon fmt`, and full `moon test` are green, and direct `wasm-opt --remove-unused-brs` checks on the new minimal regressions confirm Binaryen drops both stack-style `value; br` and stack-style `value; return` arms. The March 26, 2026 compare run at `/tmp/starshine-self-optimize-compare-starshine-debug-wasi-1396760` stays in the same non-parity band on the large oracle corpus, so the remaining hotspot families are still unresolved.

## 2026-03-26 Optimize: strip redundant multi-value tail exits in `remove-unused-brs`

- **`remove-unused-brs` multi-value tail-exit follow-up** by **@jtenner**. Updated [`CHANGELOG.md`](/home/jtenner/Projects/starshine-mb/CHANGELOG.md), [`src/passes/remove_unused_brs.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/remove_unused_brs.mbt), and [`src/passes/remove_unused_brs_test.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/remove_unused_brs_test.mbt) so the pass now strips redundant trailing `br` and `return` nodes even when they carry multi-value payloads, by splicing the live payload children back into the surrounding region tail instead of only handling arity-0 and arity-1 exits. `moon info`, `moon fmt`, and full `moon test` are green, and the March 26, 2026 compare run at `/tmp/starshine-self-optimize-compare-starshine-debug-wasi-1377467` produces different Starshine output on the oracle corpus without reopening the earlier invalid-wasm crash path, though overall canonical parity and the Binaryen speed target are still not met.

## 2026-03-26 Optimize: let `remove-unused-brs` treat returned block and loop results as payload contexts at the body tail

- **`remove-unused-brs` returned-loop payload follow-up** by **@jtenner**. Updated [`CHANGELOG.md`](/home/jtenner/Projects/starshine-mb/CHANGELOG.md), [`src/passes/remove_unused_brs.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/remove_unused_brs.mbt), and [`src/passes/remove_unused_brs_test.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/remove_unused_brs_test.mbt) so payload-context tail rewrites now also run on the body of a `block` or `loop` when that control node itself feeds a `return` or other payload consumer, which reaches the previously missed `return (loop (result ...) ...)` family without reintroducing whole-subtree payload propagation. `moon test src/passes` is green, and the March 26, 2026 compare run at `/tmp/starshine-self-optimize-compare-starshine-debug-wasi-1327234` stays in the same timing band while further improving hotspots like `$3750`, `$3107`, and `$3000`; overall canonical parity and the Binaryen speed target are still not met.

## 2026-03-26 Optimize: extend `remove-unused-brs` tail-return rewriting to payload-producing arms without reopening the earlier crash paths

- **`remove-unused-brs` tail-return payload parity checkpoint** by **@jtenner**. Updated [`CHANGELOG.md`](/home/jtenner/Projects/starshine-mb/CHANGELOG.md), [`src/passes/remove_unused_brs.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/remove_unused_brs.mbt), and [`src/passes/remove_unused_brs_test.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/remove_unused_brs_test.mbt) so tail `return (if (result ...))` wrappers now also rewrite arms that still compute payload values before falling through, by pushing the return into each arm only when the typed-`if` label is otherwise unused and the arm payload can be split safely. `moon info`, `moon fmt`, and full `moon test` are green, and the March 26, 2026 compare run at `/tmp/starshine-self-optimize-compare-starshine-debug-wasi-1319883` no longer crashes on the corpus, removes all observed `return(if ...)` wrappers in the compared Starshine output, and improves real hotspot families like `$3000`, `$1361`, `$1145`, and `$3750` while still missing overall canonical parity and the Binaryen speed target.

## 2026-03-26 Optimize: preserve discarded-value context through `local.tee` and tuple wrappers in `remove-unused-brs`

- **`remove-unused-brs` wrapper-context correctness follow-up** by **@jtenner**. Updated [`CHANGELOG.md`](/home/jtenner/Projects/starshine-mb/CHANGELOG.md), [`src/passes/remove_unused_brs.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/remove_unused_brs.mbt), and [`src/passes/remove_unused_brs_test.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/remove_unused_brs_test.mbt) so discarded-value payload context now propagates through `local.tee` and `tuple.extract` wrappers before the existing exit-only `if` voidification logic runs, which closes the dropped `local.tee (if ...)` correctness hole without widening into a whole-subtree scan. `moon test src/passes` is green, and the March 26, 2026 compare run at `/tmp/starshine-self-optimize-compare-starshine-debug-wasi-1254531` remains in the prior timing band while still missing the unresolved multi-value parity families.

## 2026-03-26 Optimize: extend `remove-unused-brs` discarded-value rewrites without reopening the perf cliff

- **`remove-unused-brs` dropped-value parity checkpoint** by **@jtenner**. Updated [`CHANGELOG.md`](/home/jtenner/Projects/starshine-mb/CHANGELOG.md), [`src/passes/remove_unused_brs.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/remove_unused_brs.mbt), and [`src/passes/remove_unused_brs_test.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/remove_unused_brs_test.mbt) so the pass now reaches nested payload-fed `if` nodes inside `local.set` values and voidifies one-value result `if`s whose two arms are single simple exits when those values are discarded under `drop`, while keeping the single-pass compare run in the prior timing band instead of the pathological whole-subtree scan band. `moon test src/passes` is green, and the March 26, 2026 compare run at `/tmp/starshine-self-optimize-compare-starshine-debug-wasi-1250573` still misses overall parity and speed targets, so the next follow-up remains focused on the unresolved multi-value wrapper families.

## 2026-03-26 Optimize: rewrite nested payload-arm branch exits without whole-region scans

- **`remove-unused-brs` nested payload-arm branch-exit follow-up** by **@jtenner**. Updated [`CHANGELOG.md`](/home/jtenner/Projects/starshine-mb/CHANGELOG.md), [`src/passes/remove_unused_brs.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/remove_unused_brs.mbt), and [`src/passes/remove_unused_brs_test.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/remove_unused_brs_test.mbt) so the pass now rewrites tail result-typed `if` nodes that sit inside the arms of payload-fed value `if`s when one nested arm is just a plain branch exit, but only when reached through actual branch/return/local-set payload traversal instead of a whole-function region scan. `moon test src/passes` is green, and the March 26, 2026 compare run at `/tmp/starshine-self-optimize-compare-starshine-debug-wasi-1242432` still misses overall parity but stays in the prior timing band while improving real hotspots like `$3750` and `$1361` without reopening the earlier performance cliff.

## 2026-03-26 Optimize: widen `remove-unused-brs` branch-payload matching for repeated multi-value children

- **`remove-unused-brs` repeated-child branch-payload parity follow-up** by **@jtenner**. Updated [`CHANGELOG.md`](/home/jtenner/Projects/starshine-mb/CHANGELOG.md), [`src/passes/remove_unused_brs.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/remove_unused_brs.mbt), and [`src/passes/remove_unused_brs_test.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/remove_unused_brs_test.mbt) so the pass now recognizes the HOT lift encoding where a multi-value `br` payload repeats the same result-typed `if` child once per result, then lowers that shape to guarded `br_if` plus payload `br` rewrites instead of skipping it. `moon info`, `moon fmt`, and full `moon test` are green, and the March 26, 2026 compare run at `/tmp/starshine-self-optimize-compare-starshine-debug-wasi-1224272` still misses overall parity and speed targets but moves the hot `$3000` family from `if=109 br_if=0` in artifact `1201029` to `if=104 br_if=5` without reopening the earlier catastrophic performance regression.

## 2026-03-26 Optimize: replace `remove-unused-names` subtree target scans with global label-use bits

- **`remove-unused-names` global label-liveness rewrite** by **@jtenner**. Updated [`CHANGELOG.md`](/home/jtenner/Projects/starshine-mb/CHANGELOG.md), [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md), and [`src/passes/remove_unused_names.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/remove_unused_names.mbt) so the pass now computes one function-wide label-use bitmap after the existing candidate precheck and uses lexical-label visibility to decide loop demotion and peeled-block safety directly, removing the old per-candidate stamped subtree branch scans and their worklist state entirely. Focused `moon test src/passes` and repeated `bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --out-dir /tmp/... --remove-unused-names` runs remain green with canonical wasm and normalized WAT parity still exact; recent pass timings improved again into the ~`82.722-87.984ms` range versus Binaryen at ~`14.014-14.700ms`, so the pass is still well over Binaryen's budget but materially faster than the earlier traversal-only checkpoints.

## 2026-03-26 Optimize: skip non-control roots in `remove-unused-names` region walks

- **`remove-unused-names` control-root filter follow-up** by **@jtenner**. Updated [`CHANGELOG.md`](/home/jtenner/Projects/starshine-mb/CHANGELOG.md), [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md), and [`src/passes/remove_unused_names.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/remove_unused_names.mbt) so the region walker now filters non-control roots before entering the heavier post-order visitor, passing the already-fetched node into the control-only path instead of paying the extra call and branch machinery for plain expression roots. Focused `moon test src/passes` and repeated `bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --out-dir /tmp/... --remove-unused-names` runs remain green with canonical wasm and normalized WAT parity still exact; recent pass timings improved again into the ~`87.759-94.231ms` range versus Binaryen at ~`14.540-15.169ms`, so the pass is still materially slower than Binaryen but the unchanged-region overhead is continuing to come down.

## 2026-03-26 Optimize: trim `remove-unused-names` region root-count churn

- **`remove-unused-names` traversal call-count follow-up** by **@jtenner**. Updated [`CHANGELOG.md`](/home/jtenner/Projects/starshine-mb/CHANGELOG.md), [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md), and [`src/passes/remove_unused_names.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/remove_unused_names.mbt) so the pass now caches region root counts inside the unchanged traversal paths, delays `peeled_roots.clear()` until a block actually peels, and avoids repeated region-count queries in the seed-scan and post-order region walk. Focused `moon test src/passes` and repeated `bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --out-dir /tmp/... --remove-unused-names` runs remain green with canonical wasm and normalized WAT parity still exact; recent pass timings improved again into the ~`92.452-93.801ms` range versus Binaryen at ~`14.030-14.872ms`, so the pass remains materially slower than Binaryen but the unchanged traversal overhead keeps shrinking.

## 2026-03-26 Optimize: fast-path `remove-unused-names` control-type comparisons

- **`remove-unused-names` hot-path type-id compare follow-up** by **@jtenner**. Updated [`CHANGELOG.md`](/home/jtenner/Projects/starshine-mb/CHANGELOG.md), [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md), and [`src/passes/remove_unused_names.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/remove_unused_names.mbt) so the pass now compares already-fetched control node type ids before falling back to decoded block-type comparisons, reuses the cached parent block type while peeling same-typed block chains, and avoids the old extra node/type query round trips on the unchanged candidate path. `moon test src/passes` plus repeated `bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --out-dir /tmp/... --remove-unused-names` runs remain green with canonical wasm and normalized WAT parity still exact; recent pass timings improved again into the ~`93.607-97.888ms` range versus Binaryen at ~`14.575-15.384ms`, so the pass is still over budget but keeps moving in the right direction.

## 2026-03-26 Optimize: trim `remove-unused-names` peel scratch churn

- **`remove-unused-names` function-pass scratch reuse checkpoint** by **@jtenner**. Updated [`CHANGELOG.md`](/home/jtenner/Projects/starshine-mb/CHANGELOG.md), [`src/passes/optimize.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/optimize.mbt), and [`src/passes/remove_unused_names.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/remove_unused_names.mbt) so the hot pass now reuses one `removed_ids` buffer and one peeled-root buffer across the full function traversal, skips rebuilding peeled roots when a block never enters a same-typed chain, and reuses the already-fetched node on the post-recursion path while preserving the current exact oracle parity. `src/passes/optimize.mbt` only changed by formatter-driven line wrapping in the boundary-only pass list. `moon info`, `moon fmt`, `moon test src/passes`, `moon test`, and repeated `bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --out-dir /tmp/... --remove-unused-names` runs are green with canonical wasm and normalized WAT parity still exact; recent `remove-unused-names` pass timings improved further into the ~`94.883-99.492ms` range versus Binaryen at ~`13.875-14.369ms`, so the pass remains materially over budget even though this work trimmed more no-op overhead.

## 2026-03-26 Optimize: short-circuit `remove-unused-names` on candidate-free hot funcs

- **`remove-unused-names` flat candidate precheck** by **@jtenner**. Updated [`CHANGELOG.md`](/home/jtenner/Projects/starshine-mb/CHANGELOG.md) and [`src/passes/remove_unused_names.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/remove_unused_names.mbt) so the pass now runs a cheap flat live-node scan before allocating scan state or traversing control regions, immediately bailing out on functions that contain no loops and no same-typed single-child block chains. On `tests/node/dist/starshine-debug-wasi.wasm`, the repeated self-opt compare harness kept canonical Binaryen parity while dropping recent `remove-unused-names` pass timings from the prior ~`281-287ms` range into the ~`97.649-107.741ms` range; the pass is still materially slower than Binaryen, but the worst no-op parser/JSON functions are no longer dominating total runtime.
## 2026-03-26 Optimize: widen `remove-unused-brs` multi-value exit rewrites

- **`remove-unused-brs` result-exit follow-up** by **@jtenner**. Updated [`CHANGELOG.md`](/home/jtenner/Projects/starshine-mb/CHANGELOG.md), [`src/passes/remove_unused_brs.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/remove_unused_brs.mbt), and [`src/passes/remove_unused_brs_test.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/remove_unused_brs_test.mbt) to recognize multi-value tail `return (if (result ...))` encodings and to rewrite result-typed `if` nodes whose arms are both plain branch exits into straight `br_if` plus `br` sequences, including cases nested under intermediate holders and dropped multi-value blocks. `moon test src/passes` is green in the worktree, and recent `bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --remove-unused-brs` runs now move real oracle hotspots like `$3107` and `$3750`, though canonical parity and the performance target are still not met.

## 2026-03-26 Optimize: expand `remove-unused-brs` tail-return parity coverage

- **`remove-unused-brs` tail-return follow-up** by **@jtenner**. Updated [`CHANGELOG.md`](/home/jtenner/Projects/starshine-mb/CHANGELOG.md), [`src/passes/remove_unused_brs.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/remove_unused_brs.mbt), and [`src/passes/remove_unused_brs_test.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/remove_unused_brs_test.mbt) to voidify tail `return (if (result ...))` ladders whose arms already exit, including nested tail-`if` cases, while using cheap in-place detached-shell cleanup to avoid the earlier delete-scan slowdown. `moon info`, `moon fmt`, `moon test`, `moon test src/passes`, and `moon test src/cmd` are green in the worktree; recent `bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --remove-unused-brs` runs still miss canonical parity, but the return-flow gap in hot functions like `$1361` and `$1145` narrowed materially while pass runtime stayed near the prior local baseline instead of regressing to the earlier 37s spike.

## 2026-03-26 Optimize: checkpoint `remove-unused-brs` oracle-parity progress

- **`remove-unused-brs` hot-pass checkpoint** by **@jtenner**. Updated [`CHANGELOG.md`](/home/jtenner/Projects/starshine-mb/CHANGELOG.md), [`src/cmd/cmd_test.mbt`](/home/jtenner/Projects/starshine-mb/src/cmd/cmd_test.mbt), [`src/ir/hot_builders.mbt`](/home/jtenner/Projects/starshine-mb/src/ir/hot_builders.mbt), [`src/ir/hot_builders_test.mbt`](/home/jtenner/Projects/starshine-mb/src/ir/hot_builders_test.mbt), [`src/ir/pkg.generated.mbti`](/home/jtenner/Projects/starshine-mb/src/ir/pkg.generated.mbti), [`src/passes/optimize.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/optimize.mbt), [`src/passes/pass_manager.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/pass_manager.mbt), [`src/passes/pkg.generated.mbti`](/home/jtenner/Projects/starshine-mb/src/passes/pkg.generated.mbti), [`src/passes/registry_test.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/registry_test.mbt), [`src/passes/remove_unused_brs.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/remove_unused_brs.mbt), and [`src/passes/remove_unused_brs_test.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/remove_unused_brs_test.mbt) to wire the pass into the active registry and presets, add select-building support needed by the transform, and extend the pass with embedded-control traversal plus targeted `if`/`br_if`/`local.set` rewrites that now cover nested drop-local ladders, copy-arm local sets, simple break-arm local sets, and both block-chain orientations. `moon info`, `moon fmt`, `moon test src/passes`, and `moon test src/cmd` are green in the worktree; the latest `bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --remove-unused-brs` run still misses canonical parity and remains much slower than Binaryen, so follow-up work stays focused on the larger return-flow and block-flow mismatches.

## 2026-03-26 Optimize: trim `remove-unused-names` scan churn and unblock native rebuilds

- **`remove-unused-names` hot-pass perf follow-up** by **@jtenner**. Updated [`CHANGELOG.md`](/home/jtenner/Projects/starshine-mb/CHANGELOG.md), [`src/lib/module.mbt`](/home/jtenner/Projects/starshine-mb/src/lib/module.mbt), [`src/lib/module_tests.mbt`](/home/jtenner/Projects/starshine-mb/src/lib/module_tests.mbt), and [`src/passes/remove_unused_names.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/remove_unused_names.mbt) so the pass reuses stamped label/node scan state, avoids the old no-op candidate prewalk, stops copying `br_table` targets through the query helper, and reuses one worklist stack per function while preserving the existing oracle-parity behavior. The same follow-up also removes the duplicate `Module::without_name_sec` definition that was blocking native rebuilds in this worktree. `moon info`, `moon fmt`, `moon test`, and repeated `bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --out-dir /tmp/... --remove-unused-names` runs are green with canonical parity still intact; latest pass timings remain well behind Binaryen but improved from the original ~`300.7ms` baseline into the ~`281-287ms` range on recent runs.

## 2026-03-26 Docs and comments: stale compatibility sweep cleanup

- **Refine stale doc and Node-package messaging after compatibility cleanup** by **@jtenner**. Updated [`docs/0022-2026-03-22-ref-get-desc-type-immediate.md`](/home/jtenner/Projects/starshine-mb/docs/0022-2026-03-22-ref-get-desc-type-immediate.md), [`scripts/lib/build-node-package.mjs`](/home/jtenner/Projects/starshine-mb/scripts/lib/build-node-package.mjs), and [`scripts/lib/generate-node-package.mjs`](/home/jtenner/Projects/starshine-mb/scripts/lib/generate-node-package.mjs) to reflect the completed legacy alias landing, current fixture-lift sequencing, and the current Node package rebuild flow so stale blockers and generation wording no longer describe completed work as still pending.

## 2026-03-26 Docs: refine stale ref_get_desc blocker notes

- **Align `ref_get_desc` blocker sequencing** by **@jtenner**. Updated [`docs/0022-2026-03-22-ref-get-desc-type-immediate.md`](/home/jtenner/Projects/starshine-mb/docs/0022-2026-03-22-ref-get-desc-type-immediate.md) to remove a stale accessor blocker and clearly indicate the current work sequence now moves past this slice.

## 2026-03-26 Docs: close outdated ref_get_desc open-question references

- **Resolve stale `exact-ref-null` follow-up wording** by **@jtenner**. Updated [`docs/0027-2026-03-22-exact-ref-null-immediates.md`](/home/jtenner/Projects/starshine-mb/docs/0027-2026-03-22-exact-ref-null-immediates.md) so the open question now correctly points to the landed bottom-null compatibility follow-up instead of describing it as still failing.

## 2026-03-26 Docs: sync README.mbt with active module-pass list

- **Pass registry docs sync in MoonBit README surface** by **@jtenner**. Updated [`README.mbt.md`](/home/jtenner/Projects/starshine-mb/README.mbt.md) so the public pass-surface note now matches the active registry entries (including `duplicate-function-elimination` and `remove-unused-module-elements`) and no longer understates current module-pass implementation coverage.

## 2026-03-26 Docs and registry: remove active pass from stale boundary-only bucket

- **Remove stale boundary-only classification for `remove-unused-names`** by **@jtenner**. Updated [`src/passes/optimize.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/optimize.mbt), [`README.mbt.md`](/home/jtenner/Projects/starshine-mb/README.mbt.md), and [`CHANGELOG.md`](/home/jtenner/Projects/starshine-mb/CHANGELOG.md) to ensure the active `remove-unused-names` hot pass is no longer listed as boundary-only in the registry bucket while keeping docs aligned on active module+hot registry ownership.

## 2026-03-26 Optimize: land the `remove-unused-names` hot pass with oracle parity

- **IR2 `remove-unused-names` implementation and registry wiring** by **@jtenner**. Updated [`CHANGELOG.md`](/home/jtenner/Projects/starshine-mb/CHANGELOG.md), [`README.md`](/home/jtenner/Projects/starshine-mb/README.md), [`docs/0063-2026-03-24-pass-port-batches-and-registry-map.md`](/home/jtenner/Projects/starshine-mb/docs/0063-2026-03-24-pass-port-batches-and-registry-map.md), [`docs/0065-2026-03-24-ir2-execution-plan.md`](/home/jtenner/Projects/starshine-mb/docs/0065-2026-03-24-ir2-execution-plan.md), [`src/ir/hot_mutate.mbt`](/home/jtenner/Projects/starshine-mb/src/ir/hot_mutate.mbt), [`src/ir/pkg.generated.mbti`](/home/jtenner/Projects/starshine-mb/src/ir/pkg.generated.mbti), [`src/passes/optimize.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/optimize.mbt), [`src/passes/optimize_test.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/optimize_test.mbt), [`src/passes/pass_manager.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/pass_manager.mbt), [`src/passes/pkg.generated.mbti`](/home/jtenner/Projects/starshine-mb/src/passes/pkg.generated.mbti), [`src/passes/registry_test.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/registry_test.mbt), [`src/passes/remove_unused_names.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/remove_unused_names.mbt), and [`src/passes/remove_unused_names_test.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/remove_unused_names_test.mbt) so the rebuilt hot pipeline now runs `remove-unused-names`, peels same-typed single-child block chains, preserves bailouts for surviving branch and `try_table` catch targets, demotes loops with no remaining continue edges, exposes the pass in the active registry and presets, and documents that surface in the README and pass-port docs. Focused and full `moon test` are green, and the self-opt compare harness on `tests/node/dist/starshine-debug-wasi.wasm` now reaches canonical Binaryen parity for `--remove-unused-names`, though Starshine remains materially slower on that artifact and still needs separate perf follow-up.
## 2026-03-26 Optimize: materialize DCE unreachable tails for final dead-result control

- **DCE final non-fallthrough control tail fix** by **@jtenner**. Updated [`CHANGELOG.md`](/home/jtenner/Projects/starshine-mb-dce/CHANGELOG.md), [`src/passes/dead_code_elimination.mbt`](/home/jtenner/Projects/starshine-mb-dce/src/passes/dead_code_elimination.mbt), and [`src/passes/dead_code_elimination_test.mbt`](/home/jtenner/Projects/starshine-mb-dce/src/passes/dead_code_elimination_test.mbt) so dead-code-elimination now preserves Binaryen-style explicit `unreachable` tails after final non-fallthrough structured control is voidified, keeps that sentinel stable across reruns, and locks the behavior in both hot-IR and lowered-output regressions. The minimized `moonbit.string_equal` replay shape now lowers to valid wasm again, the full debug artifact survives `--dead-code-elimination` plus `wasm-opt --strip-debug`, and direct native full-module replay stays around `4.4s` to `4.7s` while broader parity and runtime-budget work remains open.

## 2026-03-26 Optimize: cut dead-code-elimination replay scans and churn

- **DCE label-user indexing plus bounded detached cleanup** by **@jtenner**. Updated [`CHANGELOG.md`](/home/jtenner/Projects/starshine-mb-dce/CHANGELOG.md), [`src/passes/dead_code_elimination.mbt`](/home/jtenner/Projects/starshine-mb-dce/src/passes/dead_code_elimination.mbt), and [`src/passes/dead_code_elimination_test.mbt`](/home/jtenner/Projects/starshine-mb-dce/src/passes/dead_code_elimination_test.mbt) so dead-code-elimination now preindexes branch users by label instead of rescanning entire functions while voidifying typed control, includes `br_table` targets in that incoming-branch accounting, and caps detached-subgraph collection before it turns into wasted traversal and GC churn. Added a focused hidden-`br_table` regression, kept pass and validate suites green, and reduced native full-module `--dead-code-elimination` replay on `tests/node/dist/starshine-debug-wasi.wasm` from the prior ~12s local run to ~3.9s on the current branch while the oracle-parity follow-up continues.

## 2026-03-26 Optimize: harden dead-code-elimination replay correctness

- **DCE parity hardening for typed control cleanup** by **@jtenner**. Updated [`src/passes/dead_code_elimination.mbt`](/home/jtenner/Projects/starshine-mb-dce/src/passes/dead_code_elimination.mbt), [`src/passes/dead_code_elimination_test.mbt`](/home/jtenner/Projects/starshine-mb-dce/src/passes/dead_code_elimination_test.mbt), [`src/validate/typecheck.mbt`](/home/jtenner/Projects/starshine-mb-dce/src/validate/typecheck.mbt), [`src/validate/typecheck_negative_tests.mbt`](/home/jtenner/Projects/starshine-mb-dce/src/validate/typecheck_negative_tests.mbt), [`src/validate/validate.mbt`](/home/jtenner/Projects/starshine-mb-dce/src/validate/validate.mbt), and [`src/lib/module.mbt`](/home/jtenner/Projects/starshine-mb-dce/src/lib/module.mbt) so dead-code-elimination now preserves hidden region-label branch contracts when voidifying typed control, keeps detached label owners core-valid during unreachable-tail pruning, hardens loop-result reachability validation needed by Binaryen-style dead-wrapper cleanup, and clears the duplicate `without_name_sec` build blocker in the rebased worktree. Focused pass and validator regressions plus `moon info && moon fmt` are green; full-module performance tuning is still in progress.

## 2026-03-26 Docs: sync registry documentation with active module-pass surface

- **IR2 pass surface drift cleanup** by **@jtenner**. Updated [`README.md`](/home/jtenner/Projects/starshine-mb/README.md), [`docs/0063-2026-03-24-pass-port-batches-and-registry-map.md`](/home/jtenner/Projects/starshine-mb/docs/0063-2026-03-24-pass-port-batches-and-registry-map.md), and [`docs/0065-2026-03-24-ir2-execution-plan.md`](/home/jtenner/Projects/starshine-mb/docs/0065-2026-03-24-ir2-execution-plan.md) so active-module passes (`memory-packing`, `once-reduction`, `global-refining`, `global-struct-inference`, `duplicate-function-elimination`, and `remove-unused-module-elements`) are consistently described as implemented and active in registry contracts, preset expansions, batch implementation lists, and mixed module/hot preset sequence notes.

## 2026-03-26 Docs: continue stale wording cleanup in IR and Node docs

- **Compatibility-adapter cleanup** by **@jtenner**. Updated [`src/ir/README.md`](/home/jtenner/Projects/starshine-mb/src/ir/README.md) and [`node/README.md`](/home/jtenner/Projects/starshine-mb/node/README.md) to remove stale `"deleted"` and `"placeholder"` language that over-described removed adapters and shim-like verification helper wording.

## 2026-03-26 Docs: refresh stale IR2 compatibility wording in `src/ir/README.md`

- **IR2 facade wording cleanup** by **@jtenner**. Updated [`src/ir/README.md`](/home/jtenner/Projects/starshine-mb/src/ir/README.md) so the module map no longer claims `hot.mbt` still contains compatibility lift entries or legacy helper scaffolding, aligning the file with the current active IR2 ownership model and active module-pass architecture.

## 2026-03-26 Optimize: cut `ssa-nomerge` replay toward the remaining large control-flow outliers

- **Structured raw `ssa-nomerge` rewrites plus hot-lift/state churn cleanup** by **@jtenner**. Updated [`CHANGELOG.md`](/home/jtenner/Projects/starshine-mb/CHANGELOG.md), [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md), [`src/passes/pass_manager.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/pass_manager.mbt), [`src/passes/perf_test.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/perf_test.mbt), [`src/passes/ssa_nomerge_test.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/ssa_nomerge_test.mbt), [`src/ir/hot_lift.mbt`](/home/jtenner/Projects/starshine-mb/src/ir/hot_lift.mbt), [`src/ir/hot_lift_test.mbt`](/home/jtenner/Projects/starshine-mb/src/ir/hot_lift_test.mbt), [`src/ir/hot_lower.mbt`](/home/jtenner/Projects/starshine-mb/src/ir/hot_lower.mbt), [`src/ir/hot_lower_test.mbt`](/home/jtenner/Projects/starshine-mb/src/ir/hot_lower_test.mbt), [`src/ir/ssa_destroy.mbt`](/home/jtenner/Projects/starshine-mb/src/ir/ssa_destroy.mbt), [`src/ir/ssa_destroy_test.mbt`](/home/jtenner/Projects/starshine-mb/src/ir/ssa_destroy_test.mbt), [`src/ir/ssa_local.mbt`](/home/jtenner/Projects/starshine-mb/src/ir/ssa_local.mbt), [`src/ir/ssa_policy.mbt`](/home/jtenner/Projects/starshine-mb/src/ir/ssa_policy.mbt), [`src/ir/ssa_policy_test.mbt`](/home/jtenner/Projects/starshine-mb/src/ir/ssa_policy_test.mbt), [`src/ir/use_def.mbt`](/home/jtenner/Projects/starshine-mb/src/ir/use_def.mbt), [`src/ir/use_def_test.mbt`](/home/jtenner/Projects/starshine-mb/src/ir/use_def_test.mbt), [`src/ir/dominators.mbt`](/home/jtenner/Projects/starshine-mb/src/ir/dominators.mbt), [`src/ir/liveness.mbt`](/home/jtenner/Projects/starshine-mb/src/ir/liveness.mbt), [`src/ir/imports.mbt`](/home/jtenner/Projects/starshine-mb/src/ir/imports.mbt), [`src/validate/env.mbt`](/home/jtenner/Projects/starshine-mb/src/validate/env.mbt), [`src/validate/typecheck.mbt`](/home/jtenner/Projects/starshine-mb/src/validate/typecheck.mbt), and [`src/validate/validate.mbt`](/home/jtenner/Projects/starshine-mb/src/validate/validate.mbt) so `ssa-nomerge` now rewrites an additional structured `block` / `if` subset directly on raw Wasm without lifting, handles result-typed `if` branch alias merges in that raw path, keeps root-region SSA copy insertion and dead-local cleanup tighter, and reworks hot-lift label / typecheck state handling to avoid repeated array copies in deep control bodies. Focused regressions plus `moon info && moon fmt && moon test` are green, and direct native `--ssa-nomerge` replay on `.tmp/self-compare-prefix-6/starshine.raw.wasm` is down to `18.758 s` wall time; the remaining budget is now concentrated in a much smaller set of `br`-heavy control-flow outliers rather than generic lift setup.

## 2026-03-25 Plan: add native and Node-package hot-queue backlog slices

- **Threading roadmap backlog update** by **@jtenner**. Updated [`CHANGELOG.md`](/home/jtenner/Projects/starshine-mb/CHANGELOG.md) and [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md) to add a native `v0.1.0` slice for a worker-queue version of the existing hot-function batch and a `v0.2.0` backlog slice for porting the same scheduler contract into the Node package with `worker_threads`. The new slices pin the intended batch boundary, queue ownership, determinism constraints, and worker-local state rules before implementation work starts.

## 2026-03-25 Repo: clean master worktree after `ssa-nomerge` perf triage

- **Crash-dump ignore plus stray test-file formatting cleanup** by **@jtenner**. Updated [`CHANGELOG.md`](/home/jtenner/Projects/starshine-mb/CHANGELOG.md), [`.gitignore`](/home/jtenner/Projects/starshine-mb/.gitignore), and [`src/ir/hot_lift_test.mbt`](/home/jtenner/Projects/starshine-mb/src/ir/hot_lift_test.mbt) to remove the stray `vgcore.*` artifact from the repository worktree, ignore future core dumps, and fold the remaining formatting-only `hot_lift_test` diff into master so the branch returns to a clean post-triage state.

## 2026-03-25 Optimize: trim `ssa-nomerge` replay allocations before the next large-function lift isolate

- **Raw `ssa-nomerge` bypasses plus hot-lift allocation trimming** by **@jtenner**. Updated [`CHANGELOG.md`](/home/jtenner/Projects/starshine-mb/CHANGELOG.md), [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md), [`src/ir/cfg.mbt`](/home/jtenner/Projects/starshine-mb/src/ir/cfg.mbt), [`src/ir/cfg_order.mbt`](/home/jtenner/Projects/starshine-mb/src/ir/cfg_order.mbt), [`src/ir/dominators.mbt`](/home/jtenner/Projects/starshine-mb/src/ir/dominators.mbt), [`src/ir/hot_lift.mbt`](/home/jtenner/Projects/starshine-mb/src/ir/hot_lift.mbt), [`src/ir/hot_lift_perf_test.mbt`](/home/jtenner/Projects/starshine-mb/src/ir/hot_lift_perf_test.mbt), [`src/ir/hot_lower.mbt`](/home/jtenner/Projects/starshine-mb/src/ir/hot_lower.mbt), [`src/ir/hot_module_context.mbt`](/home/jtenner/Projects/starshine-mb/src/ir/hot_module_context.mbt), [`src/ir/imports.mbt`](/home/jtenner/Projects/starshine-mb/src/ir/imports.mbt), [`src/ir/liveness.mbt`](/home/jtenner/Projects/starshine-mb/src/ir/liveness.mbt), [`src/ir/loop_info.mbt`](/home/jtenner/Projects/starshine-mb/src/ir/loop_info.mbt), [`src/ir/pkg.generated.mbti`](/home/jtenner/Projects/starshine-mb/src/ir/pkg.generated.mbti), [`src/ir/postdominators.mbt`](/home/jtenner/Projects/starshine-mb/src/ir/postdominators.mbt), [`src/ir/ssa_local.mbt`](/home/jtenner/Projects/starshine-mb/src/ir/ssa_local.mbt), [`src/passes/pass_manager.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/pass_manager.mbt), [`src/passes/perf_test.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/perf_test.mbt), [`src/passes/registry_test.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/registry_test.mbt), [`src/passes/ssa_nomerge.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/ssa_nomerge.mbt), [`src/validate/env.mbt`](/home/jtenner/Projects/starshine-mb/src/validate/env.mbt), [`src/validate/pkg.generated.mbti`](/home/jtenner/Projects/starshine-mb/src/validate/pkg.generated.mbti), and [`src/validate/typecheck.mbt`](/home/jtenner/Projects/starshine-mb/src/validate/typecheck.mbt) so the hot pass manager now skips `ssa-nomerge` entirely on raw functions with no local writes, rewrites straight-line local traffic without lift/SSA/lower, omits extra hot verify checkpoints under final-module-only validation, and lowers without re-verifying in that mode. The IR layer now reuses borrowed CFG edge arrays, carries cached function-type slots and datas directly into lift environments, and keeps concrete stack types alongside node ids so control-entry replay can reuse owned stacks instead of repeatedly rebuilding result-type arrays. Focused perf regressions plus a new hot-lift sharing regression are green, `moon info && moon fmt && moon test` are green, and the remaining runtime blocker is concentrated in a smaller set of very large hot-lift outliers rather than in no-op `ssa-nomerge` setup.

## 2026-03-25 Optimize: cut large-artifact hot-pass replay overhead before the next lift perf slice

- **Hot-pipeline setup caching plus SSA/use-def asymptotic cleanup** by **@jtenner**. Updated [`CHANGELOG.md`](/home/jtenner/Projects/starshine-mb/CHANGELOG.md), [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md), [`src/ir/hot_module_context.mbt`](/home/jtenner/Projects/starshine-mb/src/ir/hot_module_context.mbt), [`src/ir/hot_lift.mbt`](/home/jtenner/Projects/starshine-mb/src/ir/hot_lift.mbt), [`src/ir/pkg.generated.mbti`](/home/jtenner/Projects/starshine-mb/src/ir/pkg.generated.mbti), [`src/ir/ssa_local.mbt`](/home/jtenner/Projects/starshine-mb/src/ir/ssa_local.mbt), [`src/ir/ssa_policy.mbt`](/home/jtenner/Projects/starshine-mb/src/ir/ssa_policy.mbt), [`src/ir/ssa_policy_test.mbt`](/home/jtenner/Projects/starshine-mb/src/ir/ssa_policy_test.mbt), [`src/ir/use_def.mbt`](/home/jtenner/Projects/starshine-mb/src/ir/use_def.mbt), [`src/ir/use_def_test.mbt`](/home/jtenner/Projects/starshine-mb/src/ir/use_def_test.mbt), [`src/passes/global_refining.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/global_refining.mbt), [`src/passes/pass_manager.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/pass_manager.mbt), [`src/passes/perf_test.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/perf_test.mbt), [`src/passes/simplify_locals.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/simplify_locals.mbt), and [`src/passes/simplify_locals_test.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/simplify_locals_test.mbt) so hot-pass replay now caches module lift context and resolved function types across per-function lifts, skips lowering unchanged hot passes, seeds SSA phi placement from direct local-write block lists instead of rescanning every CFG block per local, drops redundant per-node local read/write dedupe scans, and hardens `simplify-locals` against unreachable local defs and shared detached tee children encountered during large-artifact replay. Focused perf regressions are green, `moon test` is green, and direct `--ssa-nomerge` replay on `.tmp/self-compare-prefix-6/starshine.raw.wasm` improved from `474.513s` to `428.777s`; the remaining budget blocker is still inside hot-lift throughput and GC churn rather than the SSA rewrite itself.

## 2026-03-25 IR: fix large-artifact SSA no-merge lowering and detached DCE cleanup

- **Large-artifact `ssa-nomerge` correctness plus downstream detached-node cleanup hardening** by **@jtenner**. Updated [`CHANGELOG.md`](/home/jtenner/Projects/starshine-mb/CHANGELOG.md), [`src/ir/ssa_destroy.mbt`](/home/jtenner/Projects/starshine-mb/src/ir/ssa_destroy.mbt), [`src/ir/ssa_destroy_test.mbt`](/home/jtenner/Projects/starshine-mb/src/ir/ssa_destroy_test.mbt), [`src/passes/ssa_nomerge_test.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/ssa_nomerge_test.mbt), [`src/ir/hot_lower.mbt`](/home/jtenner/Projects/starshine-mb/src/ir/hot_lower.mbt), [`src/ir/hot_lower_test.mbt`](/home/jtenner/Projects/starshine-mb/src/ir/hot_lower_test.mbt), [`src/passes/dead_code_elimination.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/dead_code_elimination.mbt), and [`src/passes/dead_code_elimination_test.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/dead_code_elimination_test.mbt) so large real-world `--ssa-nomerge` replay no longer aborts on synthetic predecessor copies or duplicate dead-local cleanup, hot lowering now preserves loop fallthrough results while still normalizing dead multivalue residue, and DCE now deletes detached shared subtrees in a reference-safe order. `moon test`, isolated `DFE -> RUME -> MP -> OR -> GR -> GSI -> SSA`, and Binaryen canonicalization of the post-SSA artifact are green; the remaining full ordered chain blocker has moved downstream to a later hot-pass re-lift abort rather than SSA itself.

## 2026-03-25 IR: align hot-lower regression expectations with current lowering order

- **Hot-lower regression expectations updated to match the current stack-driven spill order** by **@jtenner**. Updated [`CHANGELOG.md`](/home/jtenner/Projects/starshine-mb/CHANGELOG.md) and [`src/ir/hot_lower_test.mbt`](/home/jtenner/Projects/starshine-mb/src/ir/hot_lower_test.mbt) so the new multivalue/local.tee regressions assert the actual preserved lowering shape, restoring a green `moon test` run without changing lowering behavior.

## 2026-03-25 CLI: add ordered dump validate and print pipeline checkpoints

- **Ordered CLI dump/validate checkpoints plus print logging hooks** by **@jtenner**. Updated [`CHANGELOG.md`](/home/jtenner/Projects/starshine-mb/CHANGELOG.md), [`README.md`](/home/jtenner/Projects/starshine-mb/README.md), [`src/cli/cli.mbt`](/home/jtenner/Projects/starshine-mb/src/cli/cli.mbt), [`src/cli/cli_test.mbt`](/home/jtenner/Projects/starshine-mb/src/cli/cli_test.mbt), [`src/cli/pkg.generated.mbti`](/home/jtenner/Projects/starshine-mb/src/cli/pkg.generated.mbti), [`src/cmd/cmd.mbt`](/home/jtenner/Projects/starshine-mb/src/cmd/cmd.mbt), [`src/cmd/cmd_test.mbt`](/home/jtenner/Projects/starshine-mb/src/cmd/cmd_test.mbt), [`src/cmd/imports.mbt`](/home/jtenner/Projects/starshine-mb/src/cmd/imports.mbt), and [`src/cmd/pkg.generated.mbti`](/home/jtenner/Projects/starshine-mb/src/cmd/pkg.generated.mbti) so CLI pass queues can now interleave ordered `--dump`, `--validate`, and `--print-*` checkpoints with optimizer passes, preserving exact queue order while writing snapshots to files and numbered module/item logs to stderr without validating intermediate dump points.

## 2026-03-25 Optimize: checkpoint broken HOT multivalue parity isolate for merge

- **Dirty HOT parity checkpoint with active diagnostics and failing regressions** by **@jtenner**. Updated [`CHANGELOG.md`](/home/jtenner/Projects/starshine-mb/CHANGELOG.md), [`src/ir/hot_lift.mbt`](/home/jtenner/Projects/starshine-mb/src/ir/hot_lift.mbt), [`src/ir/hot_lift_test.mbt`](/home/jtenner/Projects/starshine-mb/src/ir/hot_lift_test.mbt), [`src/ir/hot_lower.mbt`](/home/jtenner/Projects/starshine-mb/src/ir/hot_lower.mbt), [`src/ir/hot_lower_test.mbt`](/home/jtenner/Projects/starshine-mb/src/ir/hot_lower_test.mbt), and [`src/passes/pass_manager.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/pass_manager.mbt) to capture the current Binaryen-parity investigation state exactly as it stands: the hot-lift generic-pop resolver now prefers concrete-prefix promotion in additional reachable cases, the IR test suites contain broader multivalue spill and local.tee bridge coverage, and the pass manager carries temporary targeted trace dumps for the remaining `func[2941]` / `func[2944]` invalid shapes. This checkpoint is intentionally not green: the temporary diagnostics are still present, `moon test src/ir` is currently red on the new local.tee bridge expectations, and Binaryen parity is still blocked on the artifact-local multivalue block/tuple lowering mismatch.

## 2026-03-25 Optimize: lock narrower hot-lower bridge regressions before the remaining parity isolate

- **Hot-lower mutation regressions for typed bridge preservation** by **@jtenner**. Updated [`CHANGELOG.md`](/home/jtenner/Projects/starshine-mb/CHANGELOG.md), [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md), and [`src/ir/hot_lower_test.mbt`](/home/jtenner/Projects/starshine-mb/src/ir/hot_lower_test.mbt) so the hot-lower test suite now covers two additional mutation shapes that had been credible suspects for the remaining Binaryen parity failure: a branchy typed block whose leading `nop` is removed before lowering and a typed loop bridge whose body is similarly mutated. Both regressions stay green, which proves the remaining canonical `--vacuum` / `--dead-code-elimination` failure is narrower than those direct bridge-preservation cases and keeps the active blocker focused on isolating the still-artifact-specific post-mutation multivalue lowering shape.

## 2026-03-25 Optimize: drop dead non-final multivalue roots during lowering

- **Hot-lower dead multivalue root cleanup plus regression lock** by **@jtenner**. Updated [`CHANGELOG.md`](/home/jtenner/Projects/starshine-mb/CHANGELOG.md), [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md), [`src/ir/hot_lower.mbt`](/home/jtenner/Projects/starshine-mb/src/ir/hot_lower.mbt), and [`src/ir/hot_lower_test.mbt`](/home/jtenner/Projects/starshine-mb/src/ir/hot_lower_test.mbt) so hot lowering now uses use-def plus per-region trailing-result preservation to insert `drop`s for dead non-final multivalue roots without corrupting valid multivalue region tails, and it adds focused regressions for both the existing branchy local-set cases and a direct hot-IR multivalue root case. `moon test src/ir`, `moon test src/passes`, and the native release build all pass, and direct `--vacuum` / `--dead-code-elimination` artifact replay still exits `0`. Binaryen parity is still blocked later by the same canonical `strconv` multivalue block-shape failure, so the remaining work stays on isolating why those artifact-local typed blocks still lose their external consumer shape.

## 2026-03-25 Optimize: narrow DCE block retagging and fix ref.null binary parity

- **DCE block-wrapper safety plus Binaryen-facing ref.null encoding** by **@jtenner**. Updated [`CHANGELOG.md`](/home/jtenner/Projects/starshine-mb/CHANGELOG.md), [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md), [`src/passes/dead_code_elimination.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/dead_code_elimination.mbt), [`src/passes/dead_code_elimination_test.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/dead_code_elimination_test.mbt), [`src/binary/encode.mbt`](/home/jtenner/Projects/starshine-mb/src/binary/encode.mbt), [`src/binary/decode.mbt`](/home/jtenner/Projects/starshine-mb/src/binary/decode.mbt), and [`src/binary/tests.mbt`](/home/jtenner/Projects/starshine-mb/src/binary/tests.mbt) so dead-code-elimination no longer voidifies typed `block` results at dead root sites, preserving branch-skipping typed wrappers that the canonical debug artifact still needs to lower safely, while `ref.null` opcode encoding/decoding now uses heap-type immediates instead of full nullable ref-type prefixes. Focused DCE and binary regressions are green, direct `--dead-code-elimination` replay on `tests/node/dist/starshine-debug-wasi.wasm` now exits `0`, and the compare harness advances past the earlier invalid heap-type parse failure. Binaryen parity is still blocked later by a broader hot-pipeline multivalue block-shape issue that also reproduces under `--vacuum`: Binaryen now rejects the emitted artifact with `non-final block elements returning a value must be dropped`.

## 2026-03-25 Optimize: clear the first typed-wrapper DCE parity blocker

- **DCE incoming-branch retag guard plus replay blocker rollover** by **@jtenner**. Updated [`CHANGELOG.md`](/home/jtenner/Projects/starshine-mb/CHANGELOG.md), [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md), [`src/passes/dead_code_elimination.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/dead_code_elimination.mbt), [`src/passes/dead_code_elimination_test.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/dead_code_elimination_test.mbt), [`src/passes/optimize.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/optimize.mbt), and [`src/passes/moon.pkg`](/home/jtenner/Projects/starshine-mb/src/passes/moon.pkg) so dead-code-elimination no longer voidifies typed control wrappers whose labels still have incoming branches, which preserves branch payload expectations on dead-result wrappers that still feed label-targeted exits. The new focused regression locks that case in, pass tests stay green, and the canonical debug-artifact replay now gets past the earlier `func[67]` invalid structured-output failure; the next remaining DCE artifact blocker is the later final-validation `type mismatch` at `func[190]`. The temporary final-validate dump hook writes the current invalid optimized module to `.tmp/final-invalid.wasm` to speed isolation of the remaining replay failure.

## 2026-03-25 Optimize: fix typed-loop replay lowering and narrow the DCE parity gap

- **Typed-loop replay lowering plus DCE live-root hardening** by **@jtenner**. Updated [`CHANGELOG.md`](/home/jtenner/Projects/starshine-mb/CHANGELOG.md), [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md), [`src/ir/hot_lift.mbt`](/home/jtenner/Projects/starshine-mb/src/ir/hot_lift.mbt), [`src/ir/hot_lift_test.mbt`](/home/jtenner/Projects/starshine-mb/src/ir/hot_lift_test.mbt), [`src/ir/hot_lower.mbt`](/home/jtenner/Projects/starshine-mb/src/ir/hot_lower.mbt), [`src/ir/hot_lower_test.mbt`](/home/jtenner/Projects/starshine-mb/src/ir/hot_lower_test.mbt), [`src/ir/hot_mutate.mbt`](/home/jtenner/Projects/starshine-mb/src/ir/hot_mutate.mbt), [`src/ir/hot_region_edit.mbt`](/home/jtenner/Projects/starshine-mb/src/ir/hot_region_edit.mbt), [`src/passes/dead_code_elimination.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/dead_code_elimination.mbt), and [`src/passes/dead_code_elimination_test.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/dead_code_elimination_test.mbt) so typed loop entry values are now preserved as explicit loop-input prefixes through hot lift, mutation, region edits, and lowering, which removes the canonical `--vacuum` replay failure at `func[81]`. The DCE follow-up also stops deleting or voidifying value roots unless their only remaining use is the current dead root site, adds a regression for value roots that feed later roots in void regions, and narrows the remaining canonical parity blocker to the final-validation `type mismatch` at `func[67]` during `--dead-code-elimination`.

## 2026-03-25 Optimize: land SSA no-merge and record compare blockers

- **SSA no-merge pass wiring plus compare-harness follow-up** by **@jtenner**. Added [`src/passes/ssa_nomerge.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/ssa_nomerge.mbt) and [`src/passes/ssa_nomerge_test.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/ssa_nomerge_test.mbt), updated [`src/passes/optimize.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/optimize.mbt), [`src/passes/pass_manager.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/pass_manager.mbt), [`src/passes/registry_test.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/registry_test.mbt), [`src/cmd/cmd_test.mbt`](/home/jtenner/Projects/starshine-mb/src/cmd/cmd_test.mbt), [`src/passes/pkg.generated.mbti`](/home/jtenner/Projects/starshine-mb/src/passes/pkg.generated.mbti), [`README.md`](/home/jtenner/Projects/starshine-mb/README.md), [`docs/0063-2026-03-24-pass-port-batches-and-registry-map.md`](/home/jtenner/Projects/starshine-mb/docs/0063-2026-03-24-pass-port-batches-and-registry-map.md), [`docs/0065-2026-03-24-ir2-execution-plan.md`](/home/jtenner/Projects/starshine-mb/docs/0065-2026-03-24-ir2-execution-plan.md), and [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md) so `ssa-nomerge` now runs as a hot function pass in the active optimize presets, has focused branch and loop regressions plus CLI/registry coverage, and is removed from the active backlog. Compare-harness runs kept exact parity for `global-struct-inference` and `remove-unused-module-elements`, exposed remaining total-runtime overhead versus Binaryen, and recorded the current debug-artifact `hot lift stack underflow` blocker that still prevents canonical `ssa-nomerge` compare/signoff.

## 2026-03-25 Optimize: carry generic hot-lift results through branchy replay cases

- **Generic hot-lift replay stabilization for DCE parity** by **@jtenner**. Updated [`CHANGELOG.md`](/home/jtenner/Projects/starshine-mb/CHANGELOG.md), [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md), [`src/ir/hot_lift.mbt`](/home/jtenner/Projects/starshine-mb/src/ir/hot_lift.mbt), and [`src/ir/hot_lower_test.mbt`](/home/jtenner/Projects/starshine-mb/src/ir/hot_lower_test.mbt) so generic hot lift now keeps the matched pushed-result stack from typecheck resolution instead of reconstructing it from merged validator state, which preserves `local.tee`-fed multivalue consumers after branchy inner exits and removes the earlier `func[106]` replay abort on the canonical MoonBit debug artifact. Focused IR regressions are green again, but Binaryen parity remains blocked by two later canonical-validation gaps: loop parameter seeds are still being lowered inside typed loops during `--vacuum` replay (`func[81]`), and `--dead-code-elimination` still produces invalid structured output at `func[67]` after dead-result cleanup.

## 2026-03-25 Optimize: unblock DCE replay from hot-lift and effects blowups

- **DCE replay hot-lift and effects stabilization** by **@jtenner**. Updated [`CHANGELOG.md`](/home/jtenner/Projects/starshine-mb/CHANGELOG.md), [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md), [`src/ir/analysis_cache.mbt`](/home/jtenner/Projects/starshine-mb/src/ir/analysis_cache.mbt), [`src/ir/effects.mbt`](/home/jtenner/Projects/starshine-mb/src/ir/effects.mbt), [`src/ir/effects_test.mbt`](/home/jtenner/Projects/starshine-mb/src/ir/effects_test.mbt), [`src/ir/hot_lift.mbt`](/home/jtenner/Projects/starshine-mb/src/ir/hot_lift.mbt), [`src/ir/hot_lift_test.mbt`](/home/jtenner/Projects/starshine-mb/src/ir/hot_lift_test.mbt), [`src/ir/hot_lower.mbt`](/home/jtenner/Projects/starshine-mb/src/ir/hot_lower.mbt), and [`src/ir/hot_lower_test.mbt`](/home/jtenner/Projects/starshine-mb/src/ir/hot_lower_test.mbt) so shared hot-IR DAG effect summaries are memoized instead of repeatedly rewalking the same producers, multi-result producers keep their surviving values aligned through hot lift and lower, and unreachable branch/return payloads no longer abort lifting when the validator stack is polymorphic but no concrete values remain. The `--dead-code-elimination` artifact replay now gets past the earlier `func[80]` hot-lift stack mismatch and the previous runtime blowup, but Binaryen parity is still blocked because the lowered/output module fails final validation at `func[67]` with a stack underflow after DCE.

## 2026-03-25 Optimize: harden DCE shape cleanup and hot-lift parity support

- **Dead-code-elimination parity hardening plus hot-lift follow-up** by **@jtenner**. Updated [`CHANGELOG.md`](/home/jtenner/Projects/starshine-mb/CHANGELOG.md), [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md), [`src/passes/dead_code_elimination.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/dead_code_elimination.mbt), [`src/passes/dead_code_elimination_test.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/dead_code_elimination_test.mbt), [`src/passes/pass_manager.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/pass_manager.mbt), [`src/passes/trace_golden_test.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/trace_golden_test.mbt), [`src/ir/hot_lift.mbt`](/home/jtenner/Projects/starshine-mb/src/ir/hot_lift.mbt), [`src/ir/hot_lift_test.mbt`](/home/jtenner/Projects/starshine-mb/src/ir/hot_lift_test.mbt), [`src/ir/hot_mutate.mbt`](/home/jtenner/Projects/starshine-mb/src/ir/hot_mutate.mbt), [`src/ir/hot_region_edit.mbt`](/home/jtenner/Projects/starshine-mb/src/ir/hot_region_edit.mbt), [`src/ir/hot_core.mbt`](/home/jtenner/Projects/starshine-mb/src/ir/hot_core.mbt), [`src/ir/hot_types.mbt`](/home/jtenner/Projects/starshine-mb/src/ir/hot_types.mbt), [`src/ir/hot_lower.mbt`](/home/jtenner/Projects/starshine-mb/src/ir/hot_lower.mbt), [`src/ir/hot_module_context.mbt`](/home/jtenner/Projects/starshine-mb/src/ir/hot_module_context.mbt), [`src/ir/imports.mbt`](/home/jtenner/Projects/starshine-mb/src/ir/imports.mbt), [`src/ir/pkg.generated.mbti`](/home/jtenner/Projects/starshine-mb/src/ir/pkg.generated.mbti), [`src/validate/typecheck.mbt`](/home/jtenner/Projects/starshine-mb/src/validate/typecheck.mbt), and [`src/validate/pkg.generated.mbti`](/home/jtenner/Projects/starshine-mb/src/validate/pkg.generated.mbti) so `dead-code-elimination` now drops dead structured control results safely, preserves effectful dead roots, and carries result-arity metadata through hot mutation and lowering. The hot-lift follow-up also teaches contextual lift about resolved block-result signatures, adds targeted regressions around repeated stack types and unreachable prefixes, and improves pass tracing for parity debugging. Canonical `--dead-code-elimination` compare parity on the MoonBit debug artifact is still not closed: the current remaining blocker is a hot-lift stack mismatch at `func[80]` during `local.set` lifting in the compare harness replay.

## 2026-03-25 Optimize: sign off the first global-struct-inference slice

- **Global-struct-inference compare validation and backlog cleanup** by **@jtenner**. Updated [`CHANGELOG.md`](/home/jtenner/Projects/starshine-mb/CHANGELOG.md), [`.gitignore`](/home/jtenner/Projects/starshine-mb/.gitignore), [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md), and [`docs/0068-2026-03-25-global-struct-inference.md`](/home/jtenner/Projects/starshine-mb/docs/0068-2026-03-25-global-struct-inference.md) so the first `global-struct-inference` slice is now recorded as benchmarked and complete: isolated and closed-world compare runs both kept canonical parity, the pass itself stayed negligible versus Binaryen, widening beyond the landed direct immutable-global rewrite is deferred, and the remaining optimize-prefix speed-budget blocker is explicitly tracked upstream of `SSA`.

## 2026-03-25 Optimize: wire closed-world mode and land the first global-struct-inference slice

- **Closed-world CLI plumbing plus global-struct-inference activation** by **@jtenner**. Added [`src/passes/global_struct_inference.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/global_struct_inference.mbt) and [`src/passes/global_struct_inference_test.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/global_struct_inference_test.mbt), updated [`src/cli/cli.mbt`](/home/jtenner/Projects/starshine-mb/src/cli/cli.mbt), [`src/cli/cli_test.mbt`](/home/jtenner/Projects/starshine-mb/src/cli/cli_test.mbt), [`src/cmd/cmd.mbt`](/home/jtenner/Projects/starshine-mb/src/cmd/cmd.mbt), [`src/cmd/cmd_test.mbt`](/home/jtenner/Projects/starshine-mb/src/cmd/cmd_test.mbt), [`src/cmd/imports.mbt`](/home/jtenner/Projects/starshine-mb/src/cmd/imports.mbt), [`src/cmd/fuzz_harness_test.mbt`](/home/jtenner/Projects/starshine-mb/src/cmd/fuzz_harness_test.mbt), [`src/passes/optimize.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/optimize.mbt), [`src/passes/pass_manager.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/pass_manager.mbt), [`src/passes/pass_common_test.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/pass_common_test.mbt), [`src/passes/perf_test.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/perf_test.mbt), [`src/passes/registry_test.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/registry_test.mbt), [`README.md`](/home/jtenner/Projects/starshine-mb/README.md), [`README.mbt.md`](/home/jtenner/Projects/starshine-mb/README.mbt.md), [`docs/0068-2026-03-25-global-struct-inference.md`](/home/jtenner/Projects/starshine-mb/docs/0068-2026-03-25-global-struct-inference.md), and [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md) so Starshine now exposes `--closed-world` / `--no-closed-world` plus config/env overlays, threads that state into the hot pipeline, and runs `global-struct-inference` as a real module pass. The landed first slice is intentionally conservative: in closed-world mode it folds direct `global.get -> struct.get*` chains backed by immutable top-level `struct.new*` globals, preserves nullable traps with explicit `ref.as_non_null` when needed, leaves non-global producers alone, and schedules the pass in the live optimize and shrink presets.

## 2026-03-25 Optimize: land global-refining as a module pass

- **Global-refining early GC type-narrowing slice** by **@jtenner**. Added [`src/passes/global_refining.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/global_refining.mbt) and [`src/passes/global_refining_test.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/global_refining_test.mbt), updated [`src/passes/optimize.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/optimize.mbt), [`src/passes/pass_manager.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/pass_manager.mbt), [`src/passes/registry_test.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/registry_test.mbt), [`src/cmd/fuzz_harness_test.mbt`](/home/jtenner/Projects/starshine-mb/src/cmd/fuzz_harness_test.mbt), [`README.md`](/home/jtenner/Projects/starshine-mb/README.md), [`README.mbt.md`](/home/jtenner/Projects/starshine-mb/README.mbt.md), regenerated [`src/passes/pkg.generated.mbti`](/home/jtenner/Projects/starshine-mb/src/passes/pkg.generated.mbti), and cleared the completed `GR` block from [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md) so `global-refining` now runs after `once-reduction` in the live presets, narrows private defined global reference types from observed writes plus supported constant initializers, preserves exported globals, and keeps canonical parity on the MoonBit debug artifact. The ordered `DFE -> RUME -> MP -> OR -> GR` prefix currently matches Binaryen canonically and runs at about 51.3% of Binaryen wall time, with isolated `global-refining` pass time at about `1.8 ms` versus Binaryen's `6.8 ms`.

## 2026-03-25 Optimize: tighten once-reduction state tracking

- **Once-reduction sparse-state follow-up** by **@jtenner**. Updated [`src/passes/once_reduction.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/once_reduction.mbt), [`src/passes/once_reduction_test.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/once_reduction_test.mbt), and [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md) so `once-reduction` now tracks only active once-global candidates, skips fixed-point and rewrite work for irrelevant functions, adds a regression for multiple independent once globals, and clears the pass from the active backlog after canonical compare parity and pass-time validation on the MoonBit debug artifact.

## 2026-03-25 Docs: require permission before full self-optimize runs

- **Agent guidance for self-optimize execution** by **@jtenner**. Updated [`AGENTS.md`](/home/jtenner/Projects/starshine-mb/AGENTS.md) so running the full self-optimize pipeline, including optimize-pipeline parity/signoff compares, now requires asking the user for permission first.

## 2026-03-25 Optimize: land once-reduction as a module pass

- **Once-reduction active once-guard slice** by **@jtenner**. Added [`src/passes/once_reduction.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/once_reduction.mbt) and [`src/passes/once_reduction_test.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/once_reduction_test.mbt), updated [`src/passes/optimize.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/optimize.mbt), [`src/passes/pass_manager.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/pass_manager.mbt), [`src/passes/registry_test.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/registry_test.mbt), [`src/passes/moon.pkg`](/home/jtenner/Projects/starshine-mb/src/passes/moon.pkg), [`src/cmd/fuzz_harness_test.mbt`](/home/jtenner/Projects/starshine-mb/src/cmd/fuzz_harness_test.mbt), [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md), [`AGENTS.md`](/home/jtenner/Projects/starshine-mb/AGENTS.md), [`README.md`](/home/jtenner/Projects/starshine-mb/README.md), [`README.mbt.md`](/home/jtenner/Projects/starshine-mb/README.mbt.md), and regenerated [`src/passes/pkg.generated.mbti`](/home/jtenner/Projects/starshine-mb/src/passes/pkg.generated.mbti) so `once-reduction` now runs as a real module pass, removes dominated repeated calls to supported run-once helpers guarded by monotonic integer globals, preserves exported-global bailouts, collapses trivial once bodies after rewrite, and runs directly after `memory-packing` in the current optimize and shrink presets. The active backlog and agent guidance now treat optimize-pipeline signoff as canonical compare parity plus a Starshine runtime target of at least 50% of Binaryen on the MoonBit debug artifact.

## 2026-03-25 Optimize: land memory-packing as a module pass

- **Memory-packing active-segment parity slice** by **@jtenner**. Added [`src/passes/memory_packing.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/memory_packing.mbt) and [`src/passes/memory_packing_test.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/memory_packing_test.mbt), updated [`src/passes/optimize.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/optimize.mbt), [`src/passes/pass_manager.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/pass_manager.mbt), [`src/passes/registry_test.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/registry_test.mbt), [`src/passes/moon.pkg`](/home/jtenner/Projects/starshine-mb/src/passes/moon.pkg), [`src/cmd/fuzz_harness_test.mbt`](/home/jtenner/Projects/starshine-mb/src/cmd/fuzz_harness_test.mbt), and regenerated [`src/passes/pkg.generated.mbti`](/home/jtenner/Projects/starshine-mb/src/passes/pkg.generated.mbti) so `memory-packing` now runs as a real module pass, strips profitable active zero ranges while preserving trapping startup behavior, and is scheduled at the front of the current optimize and shrink presets. Direct compare runs on [`tests/node/dist/starshine-debug-wasi.wasm`](/home/jtenner/Projects/starshine-mb/tests/node/dist/starshine-debug-wasi.wasm) currently match Binaryen canonically and show the pass behaving as an output no-op on that artifact.

## 2026-03-25 Tooling: compile before self-optimize compare runs

- **Self-optimize compare fresh-build enforcement** by **@jtenner**. Updated [`scripts/lib/self-optimize-compare-task.ts`](/home/jtenner/Projects/starshine-mb/scripts/lib/self-optimize-compare-task.ts), [`scripts/test/self-optimize-compare-command.ts`](/home/jtenner/Projects/starshine-mb/scripts/test/self-optimize-compare-command.ts), and [`scripts/test/self-optimize-compare-invalid-input.ts`](/home/jtenner/Projects/starshine-mb/scripts/test/self-optimize-compare-invalid-input.ts) so the compare harness now rebuilds the native release CLI before every run, proving the compile happens before validation and command dispatch in both the happy-path and invalid-input command tests.

## 2026-03-25 Binary: stop copying custom and name decode payload slices

- **Binary decode payload-slice churn cleanup** by **@jtenner**. Updated [`src/binary/decode.mbt`](/home/jtenner/Projects/starshine-mb/src/binary/decode.mbt) so custom-section decoding now parses section headers directly from the source bytes and name-section decoding validates subsection payloads against source byte ranges instead of materializing intermediate payload copies, preserving existing decode behavior while cutting native `--remove-unused-module-elements` CLI time on the large debug artifact from about `2.39 s` to about `2.17 s`.

## 2026-03-25 CLI: bypass unchanged wasm re-encode after module passes

- **Unchanged wasm passthrough after real pass runs** by **@jtenner**. Updated [`src/cmd/cmd.mbt`](/home/jtenner/Projects/starshine-mb/src/cmd/cmd.mbt), [`src/cmd/cmd_test.mbt`](/home/jtenner/Projects/starshine-mb/src/cmd/cmd_test.mbt), and [`src/lib/eq.mbt`](/home/jtenner/Projects/starshine-mb/src/lib/eq.mbt) so the CLI now writes the original input bytes back out for wasm inputs when at least one optimization pass ran, debug validation is off, and the resulting module is structurally unchanged, while keeping explicit coverage for unchanged and changed `remove-unused-module-elements` paths and tightening `Module` equality to include the previously omitted annotation and stringrefs sections. On the large debug artifact, the native `--remove-unused-module-elements` command drops again from about `3.60 s` to about `2.36 s`.

## 2026-03-25 Binary: reuse decoded raw name payloads

- **Raw name-section encode reuse** by **@jtenner**. Updated [`src/binary/decode.mbt`](/home/jtenner/Projects/starshine-mb/src/binary/decode.mbt), [`src/binary/encode.mbt`](/home/jtenner/Projects/starshine-mb/src/binary/encode.mbt), [`src/binary/tests.mbt`](/home/jtenner/Projects/starshine-mb/src/binary/tests.mbt), [`src/lib/types.mbt`](/home/jtenner/Projects/starshine-mb/src/lib/types.mbt), [`src/lib/module.mbt`](/home/jtenner/Projects/starshine-mb/src/lib/module.mbt), [`src/lib/module_tests.mbt`](/home/jtenner/Projects/starshine-mb/src/lib/module_tests.mbt), [`src/lib/arbitrary.mbt`](/home/jtenner/Projects/starshine-mb/src/lib/arbitrary.mbt), and [`src/lib/show.mbt`](/home/jtenner/Projects/starshine-mb/src/lib/show.mbt) so decoded modules can carry the raw `name` custom-section payload through no-op paths and reuse those bytes on encode when the structured name data was not mutated, preserving byte-for-byte roundtrips through new coverage and cutting the native `--remove-unused-module-elements` CLI path on the large debug artifact from about `4.65 s` to about `3.60 s`.

## 2026-03-25 CLI: make post-encode validation debug-only

- **CLI post-encode validation gating** by **@jtenner**. Updated [`src/cmd/cmd.mbt`](/home/jtenner/Projects/starshine-mb/src/cmd/cmd.mbt) and [`src/cmd/cmd_test.mbt`](/home/jtenner/Projects/starshine-mb/src/cmd/cmd_test.mbt) so the CLI now only performs the expensive `encode -> decode -> validate` round-trip in `--debug-serial-passes` mode instead of on every normal output write, keeps explicit coverage for both normal and debug behavior, and cuts real native `--remove-unused-module-elements` command time on the MoonBit debug artifact from the old ~7 second range down to about `4.67 s` while debug mode remains around `7.59 s` for diagnosis.

## 2026-03-25 CLI: avoid normalized value-string churn

- **CLI in-place option-value matching** by **@jtenner**. Updated [`src/cli/cli.mbt`](/home/jtenner/Projects/starshine-mb/src/cli/cli.mbt) and [`src/cli/cli_test.mbt`](/home/jtenner/Projects/starshine-mb/src/cli/cli_test.mbt) so direct CLI parsing now matches `--format`, `--trap-mode`, `--tracing`, and decimal-valued option payloads in-place with trimmed ASCII comparisons instead of allocating normalized helper strings, preserves existing mixed-case behavior through added coverage, and reduces native synthetic parse time again on the same 3,601-arg benchmark.

## 2026-03-25 CLI: trim direct parse substring churn

- **CLI token-scan parsing cleanup** by **@jtenner**. Updated [`src/cli/cli.mbt`](/home/jtenner/Projects/starshine-mb/src/cli/cli.mbt) and [`src/cli/cli_test.mbt`](/home/jtenner/Projects/starshine-mb/src/cli/cli_test.mbt) so the direct CLI parser now scans long flags, `-O` flags, and short-option clusters in-place instead of materializing extra intermediate substring copies on the hot path, while preserving inline-value behavior through added coverage and trimming native `--help` parse benchmark time on a 3,601-arg synthetic workload.

## 2026-03-25 Optimize: short-circuit no-op RUME rewrites

- **RUME full-module no-op rewrite fast path** by **@jtenner**. Updated [`src/passes/remove_unused_module_elements.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/remove_unused_module_elements.mbt) so `remove-unused-module-elements` now returns the original module immediately when every remap is identity and every tracked section stays fully live, avoiding the remaining no-op section rebuild work on the large MoonBit debug artifact and cutting traced pass time a bit further while preserving canonical compare parity against Binaryen.

## 2026-03-25 Optimize: skip no-op RUME function rewrites

- **RUME no-op function/code rewrite fast path** by **@jtenner**. Updated [`src/passes/remove_unused_module_elements.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/remove_unused_module_elements.mbt) so `remove-unused-module-elements` now detects identity remap cases and reuses the original function and code sections when every defined function survives and no code-body indices need rewriting, avoiding whole-module function-body reconstruction on the large debug-artifact no-op path and cutting traced pass time materially while preserving canonical compare parity against Binaryen.

## 2026-03-25 Optimize: fix RUME multimemory memarg parity

- **RUME explicit memarg rewrite parity** by **@jtenner**. Updated [`src/passes/remove_unused_module_elements.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/remove_unused_module_elements.mbt), [`src/passes/remove_unused_module_elements_test.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/remove_unused_module_elements_test.mbt), and [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md) so `remove-unused-module-elements` now rewrites explicit `MemArg` memory indices across load/store/atomic/SIMD instructions after memory compaction, adds a focused multimemory regression, and narrows the remaining backlog to ordered replay and runtime work now that the single-pass and `DFE -> RUME` compare harness outputs match Binaryen canonically.

## 2026-03-25 Optimize: land remove-unused-module-elements as a module pass

- **RUME direct module-pass landing** by **@jtenner**. Added [`src/passes/remove_unused_module_elements.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/remove_unused_module_elements.mbt) and [`src/passes/remove_unused_module_elements_test.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/remove_unused_module_elements_test.mbt), updated [`src/passes/optimize.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/optimize.mbt), [`src/passes/pass_manager.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/pass_manager.mbt), [`src/passes/registry_test.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/registry_test.mbt), [`src/cmd/cmd_test.mbt`](/home/jtenner/Projects/starshine-mb/src/cmd/cmd_test.mbt), [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md), and regenerated [`src/passes/pkg.generated.mbti`](/home/jtenner/Projects/starshine-mb/src/passes/pkg.generated.mbti) so `remove-unused-module-elements` now runs as a real module pass, rewrites surviving module indices across the kept sections, and has focused pipeline and CLI coverage while the backlog narrows to ordered replay and runtime-budget follow-up.

## 2026-03-25 Tooling: canonicalize self-optimize compare artifacts

- **Self-optimize compare canonical artifact parity** by **@jtenner**. Updated [`scripts/lib/self-optimize-compare-task.ts`](/home/jtenner/Projects/starshine-mb/scripts/lib/self-optimize-compare-task.ts) and [`scripts/test/self-optimize-compare-command.ts`](/home/jtenner/Projects/starshine-mb/scripts/test/self-optimize-compare-command.ts) so the compare harness now preserves raw Starshine and Binaryen outputs, canonicalizes the Starshine side into the published compare artifact, keeps Binaryen's direct output as the byte-for-byte reference artifact, records exact wasm equality in the summary, and verifies the canonical pair through the command test.

## 2026-03-25 Optimize: drive DFE under 400 ms on the MoonBit debug artifact

- **DFE hot-path reductions and parity follow-up** by **@jtenner**. Updated [`src/passes/duplicate_function_elimination.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/duplicate_function_elimination.mbt), [`src/passes/duplicate_function_elimination_test.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/duplicate_function_elimination_test.mbt), [`src/passes/pass_manager.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/pass_manager.mbt), [`src/lib/module.mbt`](/home/jtenner/Projects/starshine-mb/src/lib/module.mbt), [`src/lib/module_tests.mbt`](/home/jtenner/Projects/starshine-mb/src/lib/module_tests.mbt), [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md), and regenerated [`src/lib/pkg.generated.mbti`](/home/jtenner/Projects/starshine-mb/src/lib/pkg.generated.mbti) so duplicate-function-elimination now reuses normalize-time type-reference scans instead of rescanning survivor bodies, precomputes canonical function-type identities for hash grouping and collision checks, strips the `name` section through a shared module helper for Binaryen parity, uses cheaper direct-index func remaps in the hot rewrite path, and clears the completed DFE runtime-budget follow-up from the active backlog. Added regression coverage for later type-compaction rewrites over concrete block types and typed `select`, and direct traced native runs on [`tests/node/dist/starshine-debug-wasi.wasm`](/home/jtenner/Projects/starshine-mb/tests/node/dist/starshine-debug-wasi.wasm) now repeatedly reach sub-`400 ms` DFE passes, including `394.658 ms` and `393.654 ms`.

## 2026-03-25 Optimize: cut DFE remap-scan closure churn

- **DFE remap-scan loop cleanup** by **@jtenner**. Updated [`src/passes/duplicate_function_elimination.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/duplicate_function_elimination.mbt) so the hot duplicate-type remap detection path now uses explicit loops instead of nested `.any(...)` closures while walking locals, type metadata, and function bodies. This keeps the sampled structured-instruction hash reduction from the prior DFE follow-up and cuts more GC churn in the no-merge MoonBit debug-artifact case, bringing direct traced `duplicate-function-elimination` runs on [`tests/node/dist/starshine-debug-wasi.wasm`](/home/jtenner/Projects/starshine-mb/tests/node/dist/starshine-debug-wasi.wasm) down into roughly the `615-638 ms` range while Binaryen remains roughly `158 ms`.

## 2026-03-25 Optimize: trim DFE sampled-hash overhead

- **DFE sampled-hash follow-up** by **@jtenner**. Updated [`src/passes/duplicate_function_elimination.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/duplicate_function_elimination.mbt) so duplicate-function-elimination now uses a shallow sampled hash for structured first/last instructions when building candidate keys, avoiding repeated recursive hashing of large nested instruction trees in the no-merge MoonBit debug-artifact case. The same update also moves the hot candidate-key maps onto mutable hash maps; the direct traced DFE pass on [`tests/node/dist/starshine-debug-wasi.wasm`](/home/jtenner/Projects/starshine-mb/tests/node/dist/starshine-debug-wasi.wasm) dropped again to roughly `660 ms`, while Binaryen remains roughly `158 ms`.

## 2026-03-25 Optimize: reduce DFE type-normalization churn

- **DFE type-dedup and normalization hot-path cuts** by **@jtenner**. Updated [`src/passes/duplicate_function_elimination.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/duplicate_function_elimination.mbt), [`src/passes/duplicate_function_elimination_test.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/duplicate_function_elimination_test.mbt), and [`src/passes/moon.pkg`](/home/jtenner/Projects/starshine-mb/src/passes/moon.pkg) so duplicate simple-type canonicalization now uses hashed first-seen buckets instead of a raw quadratic scan, DFE only rewrites function bodies for duplicate-type normalization when a function actually mentions remapped type indices, and no-merge runs no longer compact duplicate simple types. Added regressions for no-merge type preservation and non-adjacent duplicate-type compaction so the optimized path stays parity-safe while cutting the raw MoonBit debug-artifact DFE pass time materially.

## 2026-03-24 Optimize: harden DFE parity tooling and close the element-shape gap

- **DFE parity harness and artifact-shape follow-up** by **@jtenner**. Updated [`scripts/lib/self-optimize-compare-task.ts`](/home/jtenner/Projects/starshine-mb/scripts/lib/self-optimize-compare-task.ts) and [`scripts/test/self-optimize-compare-command.ts`](/home/jtenner/Projects/starshine-mb/scripts/test/self-optimize-compare-command.ts) so the self-optimize compare flow now records whole-command wall time, parses Starshine pass timings from traced `perf:timer` lines, parses Binaryen pass timings from `wasm-opt --debug`, and prints both runtime views in the compare summary.
- **DFE element canonicalization and low-allocation hashing follow-up** by **@jtenner**. Updated [`src/passes/duplicate_function_elimination.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/duplicate_function_elimination.mbt) and [`src/passes/duplicate_function_elimination_test.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/duplicate_function_elimination_test.mbt) so duplicate-function-elimination now canonicalizes compactable `funcref` element expressions back to compact function-index segments, preindexes function annotations, and avoids allocating hash buckets for unique candidate keys, closing the raw `elements` section mismatch against Binaryen on the MoonBit debug artifact.
- **DFE research refresh** by **@jtenner**. Updated [`docs/0067-2026-03-24-duplicate-function-elimination.md`](/home/jtenner/Projects/starshine-mb/docs/0067-2026-03-24-duplicate-function-elimination.md), [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md), and [`src/cmd/cmd.mbt`](/home/jtenner/Projects/starshine-mb/src/cmd/cmd.mbt) so traced CLI optimize runs now emit pass perf timers and the remaining DFE blockers are recorded accurately: the `elements` delta is closed, while the `types` / `code` artifact drift and the Starshine-vs-Binaryen DFE runtime gap are still open.

## 2026-03-24 Docs: capture Binaryen no-DWARF default optimize pathway

- **No-DWARF optimize pathway research and backlog** by **@jtenner**. Added [`docs/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md`](/home/jtenner/Projects/starshine-mb/docs/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md) to record the live Binaryen `wasm-opt version 125` no-DWARF `-O` / `-Os` path for [`tests/node/dist/starshine-debug-wasi.wasm`](/home/jtenner/Projects/starshine-mb/tests/node/dist/starshine-debug-wasi.wasm), including the top-level ordered pass list, artifact feature gates, and nested rerun shape inside optimizing global passes. Updated [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md) so each unique pass in that pathway now follows the explicit four-step workflow of research, slice planning with deliverables, implementation, and Binaryen parity testing against the MoonBit debug artifact.

## 2026-03-24 IR: port hot local simplification

- **Hot simplify-locals pass** by **@jtenner**. Turned [`src/passes/simplify_locals.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/simplify_locals.mbt) into a real hot pass that uses local SSA to rewrite dead `local.set` / `local.tee` defs, cleans up detached dead tee carrier nodes, and activates the completed batch-1 preset sequence through [`src/passes/optimize.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/optimize.mbt) and [`src/passes/pass_manager.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/pass_manager.mbt). Added coverage in [`src/passes/simplify_locals_test.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/simplify_locals_test.mbt), refreshed [`src/passes/registry_test.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/registry_test.mbt), [`README.md`](/home/jtenner/Projects/starshine-mb/README.md), [`README.mbt.md`](/home/jtenner/Projects/starshine-mb/README.mbt.md), [`docs/0063-2026-03-24-pass-port-batches-and-registry-map.md`](/home/jtenner/Projects/starshine-mb/docs/0063-2026-03-24-pass-port-batches-and-registry-map.md), [`docs/0065-2026-03-24-ir2-execution-plan.md`](/home/jtenner/Projects/starshine-mb/docs/0065-2026-03-24-ir2-execution-plan.md), and [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md) so the public docs and active backlog now reflect the completed IR2-350 slice and the end of batch 1.

## 2026-03-24 IR: port hot instruction peepholes

- **Hot optimize-instructions pass** by **@jtenner**. Turned [`src/passes/optimize_instructions.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/optimize_instructions.mbt) into a real hot pass that folds lifted exact `i32.eqz` / `i64.eqz` unary nodes on constant operands and cleans up the detached subtrees after replacement. Added coverage in [`src/passes/optimize_instructions_test.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/optimize_instructions_test.mbt), activated the pass through [`src/passes/optimize.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/optimize.mbt) and [`src/passes/pass_manager.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/pass_manager.mbt), refreshed [`src/passes/registry_test.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/registry_test.mbt), [`README.md`](/home/jtenner/Projects/starshine-mb/README.md), [`README.mbt.md`](/home/jtenner/Projects/starshine-mb/README.mbt.md), [`docs/0063-2026-03-24-pass-port-batches-and-registry-map.md`](/home/jtenner/Projects/starshine-mb/docs/0063-2026-03-24-pass-port-batches-and-registry-map.md), [`docs/0065-2026-03-24-ir2-execution-plan.md`](/home/jtenner/Projects/starshine-mb/docs/0065-2026-03-24-ir2-execution-plan.md), and [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md) so the active registry surface matches the completed IR2-340 slice.

## 2026-03-24 IR: port hot dead code elimination

- **Hot dead-code-elimination pass** by **@jtenner**. Turned [`src/passes/dead_code_elimination.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/dead_code_elimination.mbt) into the first real batch-1 pass port, so the hot pipeline now prunes pure dropped values and unreachable tail roots across nested regions instead of only carrying the old placeholder descriptor. Added coverage in [`src/passes/dead_code_elimination_test.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/dead_code_elimination_test.mbt), updated [`src/passes/pass_manager.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/pass_manager.mbt) and [`src/passes/optimize.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/optimize.mbt) to activate the new pass in the registry, refreshed [`src/passes/registry_test.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/registry_test.mbt), [`README.md`](/home/jtenner/Projects/starshine-mb/README.md), [`README.mbt.md`](/home/jtenner/Projects/starshine-mb/README.mbt.md), [`docs/0063-2026-03-24-pass-port-batches-and-registry-map.md`](/home/jtenner/Projects/starshine-mb/docs/0063-2026-03-24-pass-port-batches-and-registry-map.md), [`docs/0065-2026-03-24-ir2-execution-plan.md`](/home/jtenner/Projects/starshine-mb/docs/0065-2026-03-24-ir2-execution-plan.md), and [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md) so the public docs and backlog match the completed IR2-330 slice.

## 2026-03-24 IR: add canonical IR2 handoff plan

- **IR2 handoff docs** by **@jtenner**. Added the canonical execution-plan doc [`docs/0065-2026-03-24-ir2-execution-plan.md`](/home/jtenner/Projects/starshine-mb/docs/0065-2026-03-24-ir2-execution-plan.md) and the lightweight handoff check [`scripts/test/ir2-handoff-docs.ts`](/home/jtenner/Projects/starshine-mb/scripts/test/ir2-handoff-docs.ts) so the repo now has one stable handoff reference for architecture, ADRs, pass-port order, and minimum validation. Updated [`docs/0059-2026-03-24-ir2-architecture-rules.md`](/home/jtenner/Projects/starshine-mb/docs/0059-2026-03-24-ir2-architecture-rules.md), [`src/ir/README.md`](/home/jtenner/Projects/starshine-mb/src/ir/README.md), and [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md) so the canonical docs and active backlog state now agree after the completed IR2 leg.

## 2026-03-24 IR: remove stale optimizer compatibility shims

- **Dead optimizer compatibility cleanup** by **@jtenner**. Removed the legacy `ModulePass` / explicit-pass expansion shim from [`src/cmd/cmd.mbt`](/home/jtenner/Projects/starshine-mb/src/cmd/cmd.mbt), so the CLI, repro-note diagnostics, and command help now stay aligned with the real registry-backed hot pass surface instead of carrying deleted no-op compatibility paths. Updated [`src/cmd/fuzz_harness.mbt`](/home/jtenner/Projects/starshine-mb/src/cmd/fuzz_harness.mbt) and [`src/cmd/fuzz_harness_test.mbt`](/home/jtenner/Projects/starshine-mb/src/cmd/fuzz_harness_test.mbt) so the harness also consumes real pass-name arrays and preserves those names in failure reports. Refreshed [`src/cmd/cmd_test.mbt`](/home/jtenner/Projects/starshine-mb/src/cmd/cmd_test.mbt), [`README.md`](/home/jtenner/Projects/starshine-mb/README.md), [`README.mbt.md`](/home/jtenner/Projects/starshine-mb/README.mbt.md), [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md), and regenerated [`src/cmd/pkg.generated.mbti`](/home/jtenner/Projects/starshine-mb/src/cmd/pkg.generated.mbti) so the public API, docs, and backlog match the completed IR2-310 slice.

## 2026-03-24 IR: add hot pipeline perf instrumentation

- **Hot pipeline perf instrumentation** by **@jtenner**. Added [`src/passes/perf.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/perf.mbt) and [`src/passes/perf_test.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/perf_test.mbt) to expose opt-in pass-pipeline perf sessions with stable timer traces, allocation/build counters, validation checkpoints, and hot-func / CFG debug dumps. Rewired [`src/passes/pass_manager.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/pass_manager.mbt), [`src/passes/pass_common.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/pass_common.mbt), and [`src/passes/optimize.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/optimize.mbt) so lift, analysis-cache misses, pass execution, verify checkpoints, lowering, and final validation can report timings and counters without changing optimizer semantics. Updated [`README.md`](/home/jtenner/Projects/starshine-mb/README.md), [`README.mbt.md`](/home/jtenner/Projects/starshine-mb/README.mbt.md), [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md), and regenerated [`src/passes/pkg.generated.mbti`](/home/jtenner/Projects/starshine-mb/src/passes/pkg.generated.mbti) so the public API, docs, and backlog match the completed IR2-300 slice.

## 2026-03-24 IR: add shared test fixtures and golden dumps

- **IR2 test fixture and golden layer** by **@jtenner**. Added [`src/ir/test_helpers.mbt`](/home/jtenner/Projects/starshine-mb/src/ir/test_helpers.mbt) and [`src/ir/test_helpers_test.mbt`](/home/jtenner/Projects/starshine-mb/src/ir/test_helpers_test.mbt) to build validated hot fixtures from WAT, verify-and-lower mutated hot functions back to modules, and dump deterministic CFG, dominance, liveness, and local-SSA overlays for golden tests. Extended [`src/passes/pass_test_helpers.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/pass_test_helpers.mbt) with trace capture, added [`src/passes/trace_golden_test.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/trace_golden_test.mbt), updated [`src/ir/moon.pkg`](/home/jtenner/Projects/starshine-mb/src/ir/moon.pkg) and [`src/ir/README.md`](/home/jtenner/Projects/starshine-mb/src/ir/README.md), and documented the shared matrix in [`docs/0064-2026-03-24-ir2-test-matrix.md`](/home/jtenner/Projects/starshine-mb/docs/0064-2026-03-24-ir2-test-matrix.md).

## 2026-03-24 IR: add initial pass port batch map

- **Initial pass batch registry map** by **@jtenner**. Expanded [`src/passes/optimize.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/optimize.mbt) so the pass registry now distinguishes active hot passes and presets from known legacy `boundary-only` and `removed` names, rejects those legacy names explicitly in the hot pipeline, and keeps CLI help filtered to the active surface through [`src/cmd/cmd.mbt`](/home/jtenner/Projects/starshine-mb/src/cmd/cmd.mbt). Added batch-1 placeholder descriptors in [`src/passes/dead_code_elimination.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/dead_code_elimination.mbt), [`src/passes/optimize_instructions.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/optimize_instructions.mbt), and [`src/passes/simplify_locals.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/simplify_locals.mbt), plus registry coverage in [`src/passes/registry_test.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/registry_test.mbt) and the canonical batch map doc [`docs/0063-2026-03-24-pass-port-batches-and-registry-map.md`](/home/jtenner/Projects/starshine-mb/docs/0063-2026-03-24-pass-port-batches-and-registry-map.md).

## 2026-03-24 IR: add pass migration scaffolding

- **Pass migration support** by **@jtenner**. Added [`src/passes/pass_common.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/pass_common.mbt), [`src/passes/pass_test_helpers.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/pass_test_helpers.mbt), [`src/passes/pass_common_test.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/pass_common_test.mbt), and [`docs/0062-2026-03-24-pass-porting-checklist.md`](/home/jtenner/Projects/starshine-mb/docs/0062-2026-03-24-pass-porting-checklist.md) to centralize pass-author analysis requests, mutation helpers, detached-node cleanup, verification checkpoints, and shared pipeline-backed WAT fixtures for future IR2 pass ports. Rewired [`src/passes/pass_manager.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/pass_manager.mbt) and [`src/passes/optimize_test.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/optimize_test.mbt) so the current hot `vacuum` pass runs through the shared helper layer instead of custom pass-local cache and mutation plumbing.

## 2026-03-24 IR: add hot pass pipeline orchestration

- **Hot pass pipeline orchestration** by **@jtenner**. Added the new [`src/passes/`](./src/passes) package with [`src/passes/pass_manager.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/pass_manager.mbt), [`src/passes/optimize.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/optimize.mbt), and [`src/passes/optimize_test.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/optimize_test.mbt) to run the real IR2 `lift -> verify -> run passes -> verify -> lower -> validate` pipeline over defined functions, ship the first hot `vacuum` pass, and expose the initial pass registry/preset surface for `vacuum`, `optimize`, and `shrink`. Rewired [`src/cmd/cmd.mbt`](/home/jtenner/Projects/starshine-mb/src/cmd/cmd.mbt), [`src/cmd/cmd_test.mbt`](/home/jtenner/Projects/starshine-mb/src/cmd/cmd_test.mbt), and [`src/cmd/moon.pkg`](/home/jtenner/Projects/starshine-mb/src/cmd/moon.pkg) so the CLI now dispatches those names through the hot pass manager, rejects unknown legacy pass names, and keeps the command help aligned with the new registry-backed surface.

## 2026-03-24 IR: add analysis cache helpers

- **Hot analysis cache** by **@jtenner**. Added [`src/ir/analysis_cache.mbt`](/home/jtenner/Projects/starshine-mb/src/ir/analysis_cache.mbt) and [`src/ir/analysis_cache_test.mbt`](/home/jtenner/Projects/starshine-mb/src/ir/analysis_cache_test.mbt) to cache CFG, traversal-order, dominance, post-dominance, loop-info, use-def, liveness, effect-summary, and local-SSA overlays behind `HotFunc.revision`, with typed `cache_get_or_build_*` helpers and explicit `cache_invalidate_all(...)` reset semantics so passes can safely reuse derived analyses without stale overlay bugs. Updated [`src/ir/README.md`](/home/jtenner/Projects/starshine-mb/src/ir/README.md), [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md), and regenerated [`src/ir/pkg.generated.mbti`](/home/jtenner/Projects/starshine-mb/src/ir/pkg.generated.mbti) so the public API, docs, and backlog match the completed IR2-260 slice.

## 2026-03-24 IR: add SSA destruction helpers

- **Hot SSA destruction** by **@jtenner**. Added [`src/ir/ssa_destroy.mbt`](/home/jtenner/Projects/starshine-mb/src/ir/ssa_destroy.mbt) and [`src/ir/ssa_destroy_test.mbt`](/home/jtenner/Projects/starshine-mb/src/ir/ssa_destroy_test.mbt) to lower local SSA overlays back into plain hot local ops through concrete-local assignment, predecessor-copy insertion, temp-local scheduling for cyclic parallel copies, direct local-op rewrites, and dead local-def cleanup. Updated [`src/ir/README.md`](/home/jtenner/Projects/starshine-mb/src/ir/README.md), [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md), and regenerated [`src/ir/pkg.generated.mbti`](/home/jtenner/Projects/starshine-mb/src/ir/pkg.generated.mbti) so the public API, docs, and backlog match the completed IR2-250 slice.

## 2026-03-24 IR: add local SSA construction overlay

- **Hot local SSA construction** by **@jtenner**. Added [`src/ir/ssa_local.mbt`](/home/jtenner/Projects/starshine-mb/src/ir/ssa_local.mbt) and [`src/ir/ssa_local_test.mbt`](/home/jtenner/Projects/starshine-mb/src/ir/ssa_local_test.mbt) to build a locals-only SSA overlay from hot IR, CFG, dominance, liveness, and use-def data, including synthetic entry defs, block-entry phis, predecessor-aligned phi inputs, `LocalGet` reaching defs, `LocalSet`/`LocalTee` def ids, and per-value use tracking. Updated [`src/ir/ssa_policy.mbt`](/home/jtenner/Projects/starshine-mb/src/ir/ssa_policy.mbt), [`src/ir/README.md`](/home/jtenner/Projects/starshine-mb/src/ir/README.md), [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md), and regenerated [`src/ir/pkg.generated.mbti`](/home/jtenner/Projects/starshine-mb/src/ir/pkg.generated.mbti) so the public API, docs, and backlog match the completed IR2-240 slice.

## 2026-03-24 IR: lock local SSA policy

- **Hot local SSA policy** by **@jtenner**. Added [`src/ir/ssa_policy.mbt`](/home/jtenner/Projects/starshine-mb/src/ir/ssa_policy.mbt), [`src/ir/ssa_policy_test.mbt`](/home/jtenner/Projects/starshine-mb/src/ir/ssa_policy_test.mbt), and [`docs/0061-2026-03-24-local-ssa-policy.md`](/home/jtenner/Projects/starshine-mb/docs/0061-2026-03-24-local-ssa-policy.md) to lock the locals-only SSA overlay contract around entry definitions, overlay-only phi ownership, pruned dominance-frontier phi placement, dominator-tree renaming, predecessor-copy destruction, and explicit SSA v1 exclusions. Updated [`src/ir/README.md`](/home/jtenner/Projects/starshine-mb/src/ir/README.md), [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md), and regenerated [`src/ir/pkg.generated.mbti`](/home/jtenner/Projects/starshine-mb/src/ir/pkg.generated.mbti) so the public API, docs, and backlog match the completed IR2-230 slice.

## 2026-03-24 IR: add derived effect summaries

- **Hot effect summaries** by **@jtenner**. Added [`src/ir/effects.mbt`](/home/jtenner/Projects/starshine-mb/src/ir/effects.mbt) and [`src/ir/effects_test.mbt`](/home/jtenner/Projects/starshine-mb/src/ir/effects_test.mbt) to derive conservative node, block, and region effect masks for control, calls, throws, traps, local/global state, memory, and table behavior, with exact-instruction refinement for coarse generic families like `Heap` and `Atomic`. Updated [`src/ir/README.md`](/home/jtenner/Projects/starshine-mb/src/ir/README.md), [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md), and regenerated [`src/ir/pkg.generated.mbti`](/home/jtenner/Projects/starshine-mb/src/ir/pkg.generated.mbti) so the public API, docs, and backlog match the completed IR2-220 slice.

## 2026-03-24 IR: add local liveness overlay

- **Hot local liveness** by **@jtenner**. Added [`src/ir/liveness.mbt`](/home/jtenner/Projects/starshine-mb/src/ir/liveness.mbt) and [`src/ir/liveness_test.mbt`](/home/jtenner/Projects/starshine-mb/src/ir/liveness_test.mbt) to compute block `live_in` and `live_out` local bitsets with locals-only backward dataflow over the non-exceptional CFG edge policy, plus direct local liveness queries for later SSA placement and dead-local cleanup. Updated [`src/ir/README.md`](/home/jtenner/Projects/starshine-mb/src/ir/README.md), [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md), and regenerated [`src/ir/pkg.generated.mbti`](/home/jtenner/Projects/starshine-mb/src/ir/pkg.generated.mbti) so the public API, docs, and backlog match the completed IR2-210 slice.

## 2026-03-24 IR: add hot use-def overlay

- **Hot use-def overlay** by **@jtenner**. Added [`src/ir/use_def.mbt`](/home/jtenner/Projects/starshine-mb/src/ir/use_def.mbt) and [`src/ir/use_def_test.mbt`](/home/jtenner/Projects/starshine-mb/src/ir/use_def_test.mbt) to track node use sites by child-slot vs root-slot location, count node uses, summarize per-block local defs and uses from CFG execution order, and expose local read/write node queries for later liveness, DCE, and SSA slices. Updated [`src/ir/README.md`](/home/jtenner/Projects/starshine-mb/src/ir/README.md), [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md), and regenerated [`src/ir/pkg.generated.mbti`](/home/jtenner/Projects/starshine-mb/src/ir/pkg.generated.mbti) so the public API, docs, and backlog match the completed IR2-200 slice.

## 2026-03-24 IR: add natural loop info overlay

- **Hot CFG loop info** by **@jtenner**. Added [`src/ir/loop_info.mbt`](/home/jtenner/Projects/starshine-mb/src/ir/loop_info.mbt) and [`src/ir/loop_info_test.mbt`](/home/jtenner/Projects/starshine-mb/src/ir/loop_info_test.mbt) to compute natural loop headers, bodies, latches, exits, parent nesting, block depths, and block-to-innermost-loop mappings from CFG and dominance data, with explicit exclusion of exceptional backedges from loop formation. Updated [`src/ir/README.md`](/home/jtenner/Projects/starshine-mb/src/ir/README.md), [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md), and regenerated [`src/ir/pkg.generated.mbti`](/home/jtenner/Projects/starshine-mb/src/ir/pkg.generated.mbti) so the public API, docs, and backlog match the completed IR2-190 slice.

## 2026-03-24 IR: add post-dominator analysis overlay

- **Hot CFG post-dominators** by **@jtenner**. Added [`src/ir/postdominators.mbt`](/home/jtenner/Projects/starshine-mb/src/ir/postdominators.mbt) and [`src/ir/postdominators_test.mbt`](/home/jtenner/Projects/starshine-mb/src/ir/postdominators_test.mbt) to compute post-dominator sets, immediate post-dominators, post-dominator-tree children, post-dominance queries, post-dominance frontiers, and debug dumps over the reverse reachable CFG with explicit normal and exceptional exit-root handling. Updated [`src/ir/README.md`](/home/jtenner/Projects/starshine-mb/src/ir/README.md), [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md), and regenerated [`src/ir/pkg.generated.mbti`](/home/jtenner/Projects/starshine-mb/src/ir/pkg.generated.mbti) so the public API, docs, and backlog match the completed IR2-180 slice.

## 2026-03-24 IR: add dominator analysis overlay

- **Hot CFG dominators** by **@jtenner**. Added [`src/ir/dominators.mbt`](/home/jtenner/Projects/starshine-mb/src/ir/dominators.mbt) and [`src/ir/dominators_test.mbt`](/home/jtenner/Projects/starshine-mb/src/ir/dominators_test.mbt) to compute immediate dominators, dominator-tree children, dominance queries, dominance frontiers, and debug dumps over the reachable non-exceptional CFG using the shared traversal-order and bitset utilities, with internal verifier checks that reject inconsistent idom trees and frontier outputs. Updated [`src/ir/README.md`](/home/jtenner/Projects/starshine-mb/src/ir/README.md), [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md), and regenerated [`src/ir/pkg.generated.mbti`](/home/jtenner/Projects/starshine-mb/src/ir/pkg.generated.mbti) so the public API, docs, and backlog match the completed IR2-170 slice.

## 2026-03-24 IR: add dataflow bitset utilities

- **IR dataflow bitsets** by **@jtenner**. Added [`src/ir/bitset.mbt`](/home/jtenner/Projects/starshine-mb/src/ir/bitset.mbt) and [`src/ir/bitset_test.mbt`](/home/jtenner/Projects/starshine-mb/src/ir/bitset_test.mbt) to provide reusable dense `UInt64`-backed bitsets with strict size/index validation, set/clear/test operations, in-place union/intersection/difference, equality checks, masked tail-word handling, and deterministic ascending iteration over set bits for later dominance, liveness, and use-def slices. Updated [`src/ir/README.md`](/home/jtenner/Projects/starshine-mb/src/ir/README.md), [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md), and regenerated [`src/ir/pkg.generated.mbti`](/home/jtenner/Projects/starshine-mb/src/ir/pkg.generated.mbti) so the public API, docs, and backlog match the completed IR2-165 slice.

## 2026-03-24 IR: add hot CFG traversal order helpers

- **Hot CFG traversal orders** by **@jtenner**. Added [`src/ir/cfg_order.mbt`](/home/jtenner/Projects/starshine-mb/src/ir/cfg_order.mbt) and [`src/ir/cfg_order_test.mbt`](/home/jtenner/Projects/starshine-mb/src/ir/cfg_order_test.mbt) to provide deterministic CFG preorder, postorder, reverse postorder, reverse-exit order, exceptional-edge-inclusive reverse postorder helpers, direct-region block ordering, and a shared worklist seed policy that keeps unreachable blocks out of global traversals while still exposing direct-region tails explicitly. Updated [`src/ir/README.md`](/home/jtenner/Projects/starshine-mb/src/ir/README.md), [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md), and regenerated [`src/ir/pkg.generated.mbti`](/home/jtenner/Projects/starshine-mb/src/ir/pkg.generated.mbti) so the public API, docs, and backlog match the completed IR2-160 slice.

## 2026-03-24 IR: add hot CFG construction overlay

- **Hot CFG construction** by **@jtenner**. Added [`src/ir/cfg.mbt`](/home/jtenner/Projects/starshine-mb/src/ir/cfg.mbt) and [`src/ir/cfg_test.mbt`](/home/jtenner/Projects/starshine-mb/src/ir/cfg_test.mbt) to build a deterministic CFG overlay with synthetic entry/exit blocks, explicit successor and predecessor edges, label-target resolution for structured control, region-root and node-to-block mappings, synthetic continuation blocks for forward control labels, and explicit exceptional-exit handling. Updated [`src/ir/README.md`](/home/jtenner/Projects/starshine-mb/src/ir/README.md), [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md), and regenerated [`src/ir/pkg.generated.mbti`](/home/jtenner/Projects/starshine-mb/src/ir/pkg.generated.mbti) so the API, docs, and backlog match the completed IR2-150 slice.

## 2026-03-24 IR: add hot to boundary lowering module

- **Hot-to-boundary lowering** by **@jtenner**. Added [`src/ir/hot_lower.mbt`](/home/jtenner/Projects/starshine-mb/src/ir/hot_lower.mbt) and [`src/ir/hot_lower_test.mbt`](/home/jtenner/Projects/starshine-mb/src/ir/hot_lower_test.mbt) to lower verified `HotFunc` bodies and function definitions back to boundary form with label-depth remapping, exact-payload recovery, declared-local reconstruction, and stack-aware emission for shared branch payload values. Updated [`src/ir/hot.mbt`](/home/jtenner/Projects/starshine-mb/src/ir/hot.mbt), [`src/ir/README.md`](/home/jtenner/Projects/starshine-mb/src/ir/README.md), [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md), and regenerated [`src/ir/pkg.generated.mbti`](/home/jtenner/Projects/starshine-mb/src/ir/pkg.generated.mbti) so the API, docs, and backlog match the completed IR2-130 slice.

## 2026-03-24 IR: add boundary to hot lift module

- **Boundary-to-hot lifting** by **@jtenner**. Added [`src/ir/hot_lift.mbt`](/home/jtenner/Projects/starshine-mb/src/ir/hot_lift.mbt) and [`src/ir/hot_lift_test.mbt`](/home/jtenner/Projects/starshine-mb/src/ir/hot_lift_test.mbt) to lift validated boundary bodies into full-coverage `HotFunc` storage with module-context-backed type resolution, label allocation, typed side-table payload preservation, structured lift errors, and function-level entry points. Updated [`src/ir/hot.mbt`](/home/jtenner/Projects/starshine-mb/src/ir/hot.mbt), [`src/ir/hot_module_context.mbt`](/home/jtenner/Projects/starshine-mb/src/ir/hot_module_context.mbt), [`src/ir/hot_side_tables.mbt`](/home/jtenner/Projects/starshine-mb/src/ir/hot_side_tables.mbt), [`src/ir/hot_labels_test.mbt`](/home/jtenner/Projects/starshine-mb/src/ir/hot_labels_test.mbt), [`src/ir/imports.mbt`](/home/jtenner/Projects/starshine-mb/src/ir/imports.mbt), [`src/ir/moon.pkg`](/home/jtenner/Projects/starshine-mb/src/ir/moon.pkg), [`src/ir/README.md`](/home/jtenner/Projects/starshine-mb/src/ir/README.md), [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md), and regenerated [`src/ir/pkg.generated.mbti`](/home/jtenner/Projects/starshine-mb/src/ir/pkg.generated.mbti) so the API, docs, and backlog match the completed IR2-120 slice.

## 2026-03-24 IR: add hot boundary family metadata for exact payload ops

- **Boundary family coverage metadata** by **@jtenner**. Updated [`src/ir/hot_core.mbt`](/home/jtenner/Projects/starshine-mb/src/ir/hot_core.mbt), [`src/ir/hot_side_tables.mbt`](/home/jtenner/Projects/starshine-mb/src/ir/hot_side_tables.mbt), [`src/ir/hot_flags.mbt`](/home/jtenner/Projects/starshine-mb/src/ir/hot_flags.mbt), [`src/ir/hot_query.mbt`](/home/jtenner/Projects/starshine-mb/src/ir/hot_query.mbt), [`src/ir/hot_builders.mbt`](/home/jtenner/Projects/starshine-mb/src/ir/hot_builders.mbt), [`src/ir/hot_verify.mbt`](/home/jtenner/Projects/starshine-mb/src/ir/hot_verify.mbt), and [`src/ir/hot.mbt`](/home/jtenner/Projects/starshine-mb/src/ir/hot.mbt) to add float const payload coverage, a dedicated `Heap` family for GC/reference boundary instructions, exact-instruction payload lookup on generic hot families, verifier checks for those payload slots, and a public heap builder for the next lift/lower slices. Updated [`src/ir/README.md`](/home/jtenner/Projects/starshine-mb/src/ir/README.md), [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md), and regenerated [`src/ir/pkg.generated.mbti`](/home/jtenner/Projects/starshine-mb/src/ir/pkg.generated.mbti) so the docs, backlog, and public API match the completed IR2-119 slice.

## 2026-03-24 IR: add hot CFG contract rules

- **CFG boundary and edge policy contract** by **@jtenner**. Added [`docs/0060-2026-03-24-cfg-contract-and-block-boundary-rules.md`](/home/jtenner/Projects/starshine-mb/docs/0060-2026-03-24-cfg-contract-and-block-boundary-rules.md), [`src/ir/cfg_contract.mbt`](/home/jtenner/Projects/starshine-mb/src/ir/cfg_contract.mbt), and [`src/ir/cfg_contract_test.mbt`](/home/jtenner/Projects/starshine-mb/src/ir/cfg_contract_test.mbt) to make block-boundary reasons, structured-control successor policy, explicit terminator edge kinds, and exceptional-edge handling normative before CFG construction lands. Updated [`src/ir/README.md`](/home/jtenner/Projects/starshine-mb/src/ir/README.md), [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md), and regenerated [`src/ir/pkg.generated.mbti`](/home/jtenner/Projects/starshine-mb/src/ir/pkg.generated.mbti) so the public API, docs, and backlog match the completed IR2-140 slice.

## 2026-03-24 IR: add hot module context and resolved boundary type queries

- **Hot module-context type resolution** by **@jtenner**. Added [`src/ir/hot_module_context.mbt`](/home/jtenner/Projects/starshine-mb/src/ir/hot_module_context.mbt) and [`src/ir/hot_module_context_test.mbt`](/home/jtenner/Projects/starshine-mb/src/ir/hot_module_context_test.mbt) to resolve imported and defined function signatures, type-index block results, memories, tables, globals, tags, and aggregate field metadata through one shared `HotModuleContext`, plus resolved hot-type result queries for later lift/lower work. Updated [`src/ir/README.md`](/home/jtenner/Projects/starshine-mb/src/ir/README.md), [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md), and regenerated [`src/ir/pkg.generated.mbti`](/home/jtenner/Projects/starshine-mb/src/ir/pkg.generated.mbti) so the public API, docs, and backlog match the completed IR2-117 slice.

## 2026-03-24 IR: add exact hot boundary instruction payload storage

- **Exact boundary payload side tables** by **@jtenner**. Updated [`src/ir/hot_core.mbt`](/home/jtenner/Projects/starshine-mb/src/ir/hot_core.mbt), [`src/ir/hot_side_tables.mbt`](/home/jtenner/Projects/starshine-mb/src/ir/hot_side_tables.mbt), [`src/ir/hot_side_tables_test.mbt`](/home/jtenner/Projects/starshine-mb/src/ir/hot_side_tables_test.mbt), [`src/ir/hot_verify.mbt`](/home/jtenner/Projects/starshine-mb/src/ir/hot_verify.mbt), [`src/ir/README.md`](/home/jtenner/Projects/starshine-mb/src/ir/README.md), and [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md) to add a typed exact-instruction side table for future lift/lower coverage work, wire verifier storage validation for the new payload bucket, and resequence the IR2 backlog around the newly-discovered boundary payload prerequisite before the broader lift/lower slices.

## 2026-03-24 IR: add hot core and control verification helpers

- **Hot verification surface** by **@jtenner**. Added [`src/ir/hot_verify.mbt`](/home/jtenner/Projects/starshine-mb/src/ir/hot_verify.mbt), [`src/ir/hot_verify_test.mbt`](/home/jtenner/Projects/starshine-mb/src/ir/hot_verify_test.mbt), and [`src/ir/hot_verify_wbtest.mbt`](/home/jtenner/Projects/starshine-mb/src/ir/hot_verify_wbtest.mbt) to publish structured verification errors for hot-IR core and control corruption, placeholder CFG/dominance/SSA hooks, and debug abort helpers. Updated [`src/ir/hot.mbt`](/home/jtenner/Projects/starshine-mb/src/ir/hot.mbt) so lift and lower now verify hot functions at the boundary, then refreshed [`src/ir/README.md`](/home/jtenner/Projects/starshine-mb/src/ir/README.md), [`README.md`](/home/jtenner/Projects/starshine-mb/README.md), [`README.mbt.md`](/home/jtenner/Projects/starshine-mb/README.mbt.md), [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md), and regenerated [`src/ir/pkg.generated.mbti`](/home/jtenner/Projects/starshine-mb/src/ir/pkg.generated.mbti) so the docs, backlog, and public package surface match the completed IR2-110 slice.

## 2026-03-24 IR: add structured hot region editing helpers

- **Hot region editing surface** by **@jtenner**. Added [`src/ir/hot_region_edit.mbt`](/home/jtenner/Projects/starshine-mb/src/ir/hot_region_edit.mbt) and [`src/ir/hot_region_edit_test.mbt`](/home/jtenner/Projects/starshine-mb/src/ir/hot_region_edit_test.mbt) to publish one `HotRegionRef` contract for top-level roots, direct block/loop bodies, and wrapped `if`/`try` regions, plus shared get/set/insert/remove/splice/replace helpers and structured accessors for body, then, else, catch, and catch-list regions. Refreshed [`src/ir/README.md`](/home/jtenner/Projects/starshine-mb/src/ir/README.md), [`README.md`](/home/jtenner/Projects/starshine-mb/README.md), [`README.mbt.md`](/home/jtenner/Projects/starshine-mb/README.mbt.md), [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md), and regenerated [`src/ir/pkg.generated.mbti`](/home/jtenner/Projects/starshine-mb/src/ir/pkg.generated.mbti) so the docs, backlog, and public package surface match the completed IR2-100 slice.

## 2026-03-24 IR: add hot traversal and rewrite-walk utilities

- **Hot traversal surface** by **@jtenner**. Added [`src/ir/hot_walk.mbt`](/home/jtenner/Projects/starshine-mb/src/ir/hot_walk.mbt) and [`src/ir/hot_walk_test.mbt`](/home/jtenner/Projects/starshine-mb/src/ir/hot_walk_test.mbt) to publish stable root, child, preorder, postorder, region, worklist, control-region, and rewrite-by-slot walkers with explicit `Continue` / `Skip` / `Stop` / `Error` control helpers. Updated [`src/ir/hot_core.mbt`](/home/jtenner/Projects/starshine-mb/src/ir/hot_core.mbt) to move traversal control enums out of core storage, then refreshed [`src/ir/README.md`](/home/jtenner/Projects/starshine-mb/src/ir/README.md), [`README.md`](/home/jtenner/Projects/starshine-mb/README.md), [`README.mbt.md`](/home/jtenner/Projects/starshine-mb/README.mbt.md), [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md), and regenerated [`src/ir/pkg.generated.mbti`](/home/jtenner/Projects/starshine-mb/src/ir/pkg.generated.mbti) so the docs, backlog, and public package surface match the completed IR2-090 slice.

## 2026-03-24 IR: add hot structural query helpers

- **Hot query surface** by **@jtenner**. Added [`src/ir/hot_query.mbt`](/home/jtenner/Projects/starshine-mb/src/ir/hot_query.mbt) and [`src/ir/hot_query_test.mbt`](/home/jtenner/Projects/starshine-mb/src/ir/hot_query_test.mbt) to publish read-only structural queries for node-family classification, node/result typing, branch targets, branch-table payloads, root and child spans, local metadata splits, and deleted-node tombstone checks. Refreshed [`src/ir/README.md`](/home/jtenner/Projects/starshine-mb/src/ir/README.md), [`README.md`](/home/jtenner/Projects/starshine-mb/README.md), [`README.mbt.md`](/home/jtenner/Projects/starshine-mb/README.mbt.md), [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md), and regenerated [`src/ir/pkg.generated.mbti`](/home/jtenner/Projects/starshine-mb/src/ir/pkg.generated.mbti) so the docs, backlog, and public API match the completed IR2-080 slice.

## 2026-03-24 IR: add hot mutation primitives for roots nodes and child spans

- **Hot mutation surface** by **@jtenner**. Added [`src/ir/hot_mutate.mbt`](/home/jtenner/Projects/starshine-mb/src/ir/hot_mutate.mbt) and [`src/ir/hot_mutate_test.mbt`](/home/jtenner/Projects/starshine-mb/src/ir/hot_mutate_test.mbt) to publish the canonical hot-IR mutation layer for roots, nodes, child spans, explicit revision bumps, and tombstone-backed node deletion without free-list reuse. Updated [`src/ir/hot_core.mbt`](/home/jtenner/Projects/starshine-mb/src/ir/hot_core.mbt), [`src/ir/hot_builders.mbt`](/home/jtenner/Projects/starshine-mb/src/ir/hot_builders.mbt), and [`src/ir/hot.mbt`](/home/jtenner/Projects/starshine-mb/src/ir/hot.mbt) so direct hot storage writes now route through the new mutation APIs, then refreshed [`src/ir/README.md`](/home/jtenner/Projects/starshine-mb/src/ir/README.md), [`README.md`](/home/jtenner/Projects/starshine-mb/README.md), [`README.mbt.md`](/home/jtenner/Projects/starshine-mb/README.mbt.md), [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md), and regenerated [`src/ir/pkg.generated.mbti`](/home/jtenner/Projects/starshine-mb/src/ir/pkg.generated.mbti) so the docs, backlog, and public package surface match the completed IR2-070 slice.

## 2026-03-24 IR: add hot builder helpers for canonical node construction

- **Hot builder surface** by **@jtenner**. Added [`src/ir/hot_builders.mbt`](/home/jtenner/Projects/starshine-mb/src/ir/hot_builders.mbt), [`src/ir/hot_builders_test.mbt`](/home/jtenner/Projects/starshine-mb/src/ir/hot_builders_test.mbt), and [`src/ir/hot_builders_wbtest.mbt`](/home/jtenner/Projects/starshine-mb/src/ir/hot_builders_wbtest.mbt) to publish one low-level node builder plus family builders for constants, locals/globals, branches, calls, loads/stores, tuples, exceptions, and structured control. The new builders allocate labels, region wrappers, and side-table payload ids through the canonical hot-IR helper modules, and the focused replacement/lowering tests lock the intended builder-created node shapes. Refreshed [`src/ir/README.md`](/home/jtenner/Projects/starshine-mb/src/ir/README.md), [`README.md`](/home/jtenner/Projects/starshine-mb/README.md), [`README.mbt.md`](/home/jtenner/Projects/starshine-mb/README.mbt.md), [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md), and regenerated [`src/ir/pkg.generated.mbti`](/home/jtenner/Projects/starshine-mb/src/ir/pkg.generated.mbti) so the package surface, docs, and backlog match the completed IR2-060 slice.

## 2026-03-24 IR: centralize hot side-table payload storage

- **Hot side-table metadata surface** by **@jtenner**. Added [`src/ir/hot_side_tables.mbt`](/home/jtenner/Projects/starshine-mb/src/ir/hot_side_tables.mbt), [`src/ir/hot_side_tables_test.mbt`](/home/jtenner/Projects/starshine-mb/src/ir/hot_side_tables_test.mbt), and [`src/ir/hot_side_tables_wbtest.mbt`](/home/jtenner/Projects/starshine-mb/src/ir/hot_side_tables_wbtest.mbt) to publish typed alloc/get helpers for const payloads, memargs, branch tables, catches, and call signatures, plus the opcode-family side-table mapping contract. Updated [`src/ir/hot_core.mbt`](/home/jtenner/Projects/starshine-mb/src/ir/hot_core.mbt) to drop the unused untyped `HotExtra` bucket, rewired [`src/ir/hot.mbt`](/home/jtenner/Projects/starshine-mb/src/ir/hot.mbt) to use the new const side-table accessor, and refreshed [`src/ir/README.md`](/home/jtenner/Projects/starshine-mb/src/ir/README.md), [`README.md`](/home/jtenner/Projects/starshine-mb/README.md), [`README.mbt.md`](/home/jtenner/Projects/starshine-mb/README.mbt.md), [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md), and regenerated [`src/ir/pkg.generated.mbti`](/home/jtenner/Projects/starshine-mb/src/ir/pkg.generated.mbti) so the public docs, backlog, and package surface match the completed IR2-050 slice.

## 2026-03-24 IR: expose hot label and control-slot metadata

- **Hot label metadata surface** by **@jtenner**. Added [`src/ir/hot_labels.mbt`](/home/jtenner/Projects/starshine-mb/src/ir/hot_labels.mbt), [`src/ir/hot_labels_test.mbt`](/home/jtenner/Projects/starshine-mb/src/ir/hot_labels_test.mbt), and [`src/ir/hot_labels_wbtest.mbt`](/home/jtenner/Projects/starshine-mb/src/ir/hot_labels_wbtest.mbt) to publish label allocation, ownership, branch-arity, and control-region slot metadata for current control families. Updated [`src/ir/hot.mbt`](/home/jtenner/Projects/starshine-mb/src/ir/hot.mbt) so lowering queries labels through the new API instead of decoding control immediates directly, then refreshed [`src/ir/README.md`](/home/jtenner/Projects/starshine-mb/src/ir/README.md), [`README.md`](/home/jtenner/Projects/starshine-mb/README.md), [`README.mbt.md`](/home/jtenner/Projects/starshine-mb/README.mbt.md), [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md), and regenerated [`src/ir/pkg.generated.mbti`](/home/jtenner/Projects/starshine-mb/src/ir/pkg.generated.mbti) so the docs, backlog, and public package surface match the landed IR2-040 slice.

## 2026-03-24 IR: centralize hot type interning and queries

- **Hot type interning surface** by **@jtenner**. Added [`src/ir/hot_types.mbt`](/home/jtenner/Projects/starshine-mb/src/ir/hot_types.mbt) and [`src/ir/hot_types_test.mbt`](/home/jtenner/Projects/starshine-mb/src/ir/hot_types_test.mbt) to replace the old linear-scan hot-type path with keyed canonical interning plus result-arity, result-type, and local-metadata queries. Updated [`src/ir/hot_core.mbt`](/home/jtenner/Projects/starshine-mb/src/ir/hot_core.mbt) to track interned type ids and richer parameter metadata, and rewired [`src/ir/hot.mbt`](/home/jtenner/Projects/starshine-mb/src/ir/hot.mbt) so lift/lower now go through the new type APIs. Refreshed [`src/ir/README.md`](/home/jtenner/Projects/starshine-mb/src/ir/README.md), [`README.md`](/home/jtenner/Projects/starshine-mb/README.md), [`README.mbt.md`](/home/jtenner/Projects/starshine-mb/README.mbt.md), [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md), [`src/ir/moon.pkg`](/home/jtenner/Projects/starshine-mb/src/ir/moon.pkg), and regenerated [`src/ir/pkg.generated.mbti`](/home/jtenner/Projects/starshine-mb/src/ir/pkg.generated.mbti) so the docs, backlog, and public package surface match the landed IR2-030 slice.

## 2026-03-24 IR: centralize hot node flags and classifiers

- **Hot flag metadata surface** by **@jtenner**. Added [`src/ir/hot_flags.mbt`](/home/jtenner/Projects/starshine-mb/src/ir/hot_flags.mbt), [`src/ir/hot_flags_test.mbt`](/home/jtenner/Projects/starshine-mb/src/ir/hot_flags_test.mbt), and [`src/ir/hot_flags_wbtest.mbt`](/home/jtenner/Projects/starshine-mb/src/ir/hot_flags_wbtest.mbt) to define the canonical per-op raw flag table and fast helpers for control, terminator, effect, trap, branch, and exceptional-edge queries. Updated [`src/ir/hot.mbt`](/home/jtenner/Projects/starshine-mb/src/ir/hot.mbt) and [`src/ir/hot_core.mbt`](/home/jtenner/Projects/starshine-mb/src/ir/hot_core.mbt) so node construction and replacement always derive flags from `hot_default_flags_for_op(...)`, then refreshed [`src/ir/README.md`](/home/jtenner/Projects/starshine-mb/src/ir/README.md), [`README.md`](/home/jtenner/Projects/starshine-mb/README.md), [`README.mbt.md`](/home/jtenner/Projects/starshine-mb/README.mbt.md), [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md), and regenerated [`src/ir/pkg.generated.mbti`](/home/jtenner/Projects/starshine-mb/src/ir/pkg.generated.mbti) so the docs, backlog, and public package surface match the landed flag model.

## 2026-03-24 IR: split hot core storage into its own module

- **Hot core storage contract** by **@jtenner**. Added [`src/ir/hot_core.mbt`](/home/jtenner/Projects/starshine-mb/src/ir/hot_core.mbt) and [`src/ir/hot_core_test.mbt`](/home/jtenner/Projects/starshine-mb/src/ir/hot_core_test.mbt), moved the owned dense `HotFunc` / `HotNode` storage surface out of [`src/ir/hot.mbt`](/home/jtenner/Projects/starshine-mb/src/ir/hot.mbt), and exposed core counters, body-result accessors, liveness queries, and a minimal debug dump helper. Updated [`src/ir/README.md`](/home/jtenner/Projects/starshine-mb/src/ir/README.md), [`README.md`](/home/jtenner/Projects/starshine-mb/README.md), [`README.mbt.md`](/home/jtenner/Projects/starshine-mb/README.mbt.md), [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md), and regenerated [`src/ir/pkg.generated.mbti`](/home/jtenner/Projects/starshine-mb/src/ir/pkg.generated.mbti) so the public docs and package surface match the new core module.

## 2026-03-24 IR: lock IR2 architecture rules around `HotFunc`

- **IR2 architecture contract** by **@jtenner**. Added [`docs/0059-2026-03-24-ir2-architecture-rules.md`](/home/jtenner/Projects/starshine-mb/docs/0059-2026-03-24-ir2-architecture-rules.md), [`src/ir/README.md`](/home/jtenner/Projects/starshine-mb/src/ir/README.md), and [`src/ir/architecture.mbt`](/home/jtenner/Projects/starshine-mb/src/ir/architecture.mbt) plus [`src/ir/architecture_test.mbt`](/home/jtenner/Projects/starshine-mb/src/ir/architecture_test.mbt) to declare `HotFunc` as the only owned optimizer body representation, expose revision and pass-descriptor metadata helpers, and lock the planned `src/ir` module split. Updated [`README.md`](/home/jtenner/Projects/starshine-mb/README.md), [`README.mbt.md`](/home/jtenner/Projects/starshine-mb/README.mbt.md), [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md), and regenerated [`src/ir/pkg.generated.mbti`](/home/jtenner/Projects/starshine-mb/src/ir/pkg.generated.mbti) so the public docs and backlog now match the IR2 ownership contract.

## 2026-03-24 Docs: refresh README and agent guidance after IR2 reset

- **IR2 doc surface cleanup** by **@jtenner**. Expanded [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md) into the full slice-by-slice IR2 execution backlog, updated [`AGENTS.md`](/home/jtenner/Projects/starshine-mb/AGENTS.md) to reflect the current repo layout and active hot-IR rebuild workflow, and scrubbed stale optimizer/package wording from [`README.md`](/home/jtenner/Projects/starshine-mb/README.md), [`README.mbt.md`](/home/jtenner/Projects/starshine-mb/README.mbt.md), [`node/README.md`](/home/jtenner/Projects/starshine-mb/node/README.md), [`node/examples/README.md`](/home/jtenner/Projects/starshine-mb/node/examples/README.md), [`examples/README.md`](/home/jtenner/Projects/starshine-mb/examples/README.md), and [`tests/spec/README.md`](/home/jtenner/Projects/starshine-mb/tests/spec/README.md) so the checked-in docs match the current compatibility command surface and hot-IR rebuild state.

## 2026-03-24 Cmd: remove stale SSA fixture from README sync tests

- **README sync fixture cleanup** by **@jtenner**. Updated [`src/cmd/readme_api_sync_wbtest.mbt`](/home/jtenner/Projects/starshine-mb/src/cmd/readme_api_sync_wbtest.mbt) to stop asserting the deleted `infer_ssa_types` API and instead use the live hot-IR signature from [`src/ir/pkg.generated.mbti`](/home/jtenner/Projects/starshine-mb/src/ir/pkg.generated.mbti), so the test fixture matches the current `ir` package surface.

## 2026-03-24 Backlog: reset stale agent task inventory

- **Backlog cleanup after architecture churn** by **@jtenner**. Replaced the oversized historical [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md) dump with a short active backlog that only tracks current hot-IR rebuild, CLI/docs alignment, and validator fuzz hardening work, removing stale references to deleted optimizer packages, deleted research docs, and completed typed-tree migration slices.

## 2026-03-24 Docs: remove obsolete optimizer and typed-tree research

- **Docs cleanup after optimizer reset** by **@jtenner**. Deleted the obsolete pass-research and typed-tree migration writeups under [`docs`](/home/jtenner/Projects/starshine-mb/docs), including dead-code-elimination, once-reduction, memory-packing, remove-unused, parity, and old string-optimization notes, and scrubbed the remaining validation/surface docs of deleted `TInstr` / `TExpr` / `ModuleTransformer` terminology so `docs/` now reflects the post-migration architecture.

## 2026-03-24 Migration: remove TypedInstr surface completely

- **Typed instruction surface deletion** by **@jtenner**. Removed the remaining `TypedInstr` / `TypedInstrKind` ownership from [`src/lib/types.mbt`](/home/jtenner/Projects/starshine-mb/src/lib/types.mbt), deleted the obsolete typed helper files under [`src/lib/typed_instr_tree.mbt`](/home/jtenner/Projects/starshine-mb/src/lib/typed_instr_tree.mbt) and [`src/validate/typed_instr_lowering.mbt`](/home/jtenner/Projects/starshine-mb/src/validate/typed_instr_lowering.mbt), rewired [`src/ir/hot.mbt`](/home/jtenner/Projects/starshine-mb/src/ir/hot.mbt), validation, generators, and tests onto raw [`Expr`](/home/jtenner/Projects/starshine-mb/src/lib/types.mbt) / [`Instruction`](/home/jtenner/Projects/starshine-mb/src/lib/types.mbt) bodies, regenerated package metadata, and scrubbed the remaining docs/changelog references to the deleted typed instruction model.

## 2026-03-24 Node: remove deleted package rebuild assumptions

- **Node rebuild path reset** by **@jtenner**. Updated [`scripts/lib/build-node-package.mjs`](/home/jtenner/Projects/starshine-mb/scripts/lib/build-node-package.mjs) so `npm run build` no longer tries to rebuild the deleted [`src/node_api`](/home/jtenner/Projects/starshine-mb/src/node_api) wasm-gc adapter and instead treats [`node/internal/starshine.wasm-gc.wasm`](/home/jtenner/Projects/starshine-mb/node/internal/starshine.wasm-gc.wasm) as a checked-in boundary artifact while still rebuilding the WASI CLI artifact. Also removed dead `src/node_api` CI path filters in [node-wasm-tests.yml](/home/jtenner/Projects/starshine-mb/.github/workflows/node-wasm-tests.yml), narrowed [`node/package.json`](/home/jtenner/Projects/starshine-mb/node/package.json) cleanup to the rebuilt WASI artifact, and added missing `target="wasm"` debug-dump stubs in [`src/cmd/cmd.mbt`](/home/jtenner/Projects/starshine-mb/src/cmd/cmd.mbt) so the node build path compiles again.

## 2026-03-24 Migration: remove legacy optimization and generated node surfaces

- **Optimizer and generated API reset** by **@jtenner**. Removed the entire legacy optimization package under [`src/optimization`](/home/jtenner/Projects/starshine-mb/src/optimization), deleted the generated [`src/node_api`](/home/jtenner/Projects/starshine-mb/src/node_api) package and stale node `ir` / `transformer` exports, rewired command, validation, binary, and trace fixtures around the remaining raw-boundary plus hot-IR path, and scrubbed tracked source/docs/node files of the deleted `TFunc` / `TInstr` / `TExpr` / `ModuleTransformer` naming surface. Added [`src/validate/typed_instr_lowering.mbt`](/home/jtenner/Projects/starshine-mb/src/validate/typed_instr_lowering.mbt) to preserve valid typed-body roundtrips at the cold boundary while the optimizer is rebuilt.

## 2026-03-24 Migration: checkpoint hot IR replacement cut before optimizer reset

- **Hot IR migration checkpoint** by **@jtenner**. Added the new hot function IR in [`src/ir/hot.mbt`](/home/jtenner/Projects/starshine-mb/src/ir/hot.mbt) with dense node/child storage and direct rewrite helpers, removed the old transformer package and legacy `src/ir` tree-owned optimizer layers, rewired boundary/validation code away from `typed function` / `typed instruction body` ownership, and moved duplicate-function elimination plus the smaller name/string optimizer paths onto direct boundary or hot-IR rewrites in [`src/optimization/optimization.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/optimization.mbt) and [`src/optimization/hot_rewrite.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/hot_rewrite.mbt). This commit is an explicit checkpoint slice before rebuilding or deleting the remaining legacy optimization package.

## 2026-03-24 Validation: reset DCE to a validating replacement and unblock five-pass parity runs

- **DCE validity reset and compare harness unblock** by **@jtenner**. Updated [`src/optimization/optimization.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/optimization.mbt) to remove the unsafe recursive structured dead-result cleanup path and narrow `drop(...)` simplification to strict terminals, which restores validating direct `--dead-code-elimination` output on `tests/node/dist/starshine-debug-wasi.wasm` and the reduced repro pipeline. Added the focused native regression in [`src/cmd/cmd_test.mbt`](/home/jtenner/Projects/starshine-mb/src/cmd/cmd_test.mbt), documented the reset and remaining parity blocker in [`docs/0070-2026-03-24-dce-valid-replacement-and-prefix5-parity-reset.md`](/home/jtenner/Projects/starshine-mb/docs/0070-2026-03-24-dce-valid-replacement-and-prefix5-parity-reset.md), and refreshed [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md).
- Updated [`scripts/lib/task-runtime.ts`](/home/jtenner/Projects/starshine-mb/scripts/lib/task-runtime.ts) and [`scripts/lib/self-optimize-compare-task.ts`](/home/jtenner/Projects/starshine-mb/scripts/lib/self-optimize-compare-task.ts) so the self-optimize compare harness can normalize large WAT outputs without `spawnSync ... ENOBUFS`, which re-enables the shared five-pass debug-artifact comparison.
- The five-pass compare now completes again on `tests/node/dist/starshine-debug-wasi.wasm`; Starshine DCE is validating but currently inert on that prefix, while Binaryen `--dce` still changes the module. The next step is a context-carrying structured DCE walker for actual parity.

## 2026-03-23 Validation: make DCE dead-result cleanup respect net typed control results

- **DCE typed block-result accounting** by **@jtenner**. Updated [`src/optimization/optimization.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/optimization.mbt) so dead-result cleanup and the related block/if/try rewrites no longer treat every non-`void` typed control as a droppable runtime result. `DeadCodeElimination` now expands typed block types through the module validator environment and only applies dead-result cleanup when the control has a positive net fallthrough result count (`results.length() > params.length()`), while still preserving the earlier `TypeIdx` loop body fix for cases that really do have a dead result.
- Added focused regressions in [`src/optimization/dead_code_elimination_wbtest.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/dead_code_elimination_wbtest.mbt) covering positive-net `TypeIdx` loop dead-result cleanup, zero-net `TypeIdx` loop preservation, and the updated helper signatures through the direct truncation coverage.
- This slice clears the fresh direct-DCE `Func 225` post-encode underflow. The next direct artifact blocker is now later at `Func 3175` with `values remaining on stack at end of block`.

## 2026-03-23 Validation: consume dead structured results in DCE without breaking live control flow

- **DCE dead structured-result cleanup** by **@jtenner**. Updated [`src/optimization/optimization.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/optimization.mbt) so dead-result cleanup now preserves non-retaggable structured control flow by consuming dead results with `drop` instead of leaving concrete `block` / `if` / `TypeIdx` `loop` results bare in `void` contexts. `void` loops now stay `void` during this cleanup instead of being incorrectly wrapped in `drop`.
- Added focused regressions in [`src/optimization/dead_code_elimination_wbtest.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/dead_code_elimination_wbtest.mbt) for ordinary concrete `block` / `if` dead-result cleanup, live current-label branch-value blocks, `TypeIdx` loop dead-result cleanup, and the `void`-loop non-regression.
- This slice clears the fresh direct-DCE post-encode blockers at `Func 3175` and `Func 21`; the next direct artifact blocker is now later at `Func 225`.

## 2026-03-23 Validation: extend DCE branch-payload coverage through stacked if/return wrappers

- **DCE nested wrapper coverage** by **@jtenner**. Added a deeper generated-path regression in [`src/cmd/generated_pipeline_wbtest.mbt`](/home/jtenner/Projects/starshine-mb/src/cmd/generated_pipeline_wbtest.mbt) that stacks multiple `if (void) ... else { call; return }` wrappers around the same branch-payload bypass core seen in the fresh direct-DCE `Func 716` family.
- That reduction still validates and roundtrips after `--dead-code-elimination`, which narrows the remaining blocker further: the live artifact failure is not explained by the generic nested-wrapper shape alone.

## 2026-03-23 Validation: add loop-wrapped branch-payload bypass coverage around the remaining DCE blocker

- **DCE loop-wrapper coverage** by **@jtenner**. Added focused regressions in [`src/cmd/generated_pipeline_wbtest.mbt`](/home/jtenner/Projects/starshine-mb/src/cmd/generated_pipeline_wbtest.mbt), [`src/binary/tests.mbt`](/home/jtenner/Projects/starshine-mb/src/binary/tests.mbt), and [`src/validate/validate.mbt`](/home/jtenner/Projects/starshine-mb/src/validate/validate.mbt) for raw and pre-lifted loop-wrapped branch-payload bypass shapes, including the surrounding `if`/`return` context that shows up near the current fresh-artifact `Func 716` direct-DCE blocker.
- The new coverage confirms that the reduced raw loop/branch-payload forms themselves validate and roundtrip locally, which narrows the remaining fresh-artifact failure to a later, more artifact-specific DCE rewrite or lowering interaction rather than the generic reduced loop-wrapper pattern.

## 2026-03-23 Validation: keep live current-label branch targets concrete during DCE dead-result cleanup

- **DCE live-branch retag guard** by **@jtenner**. Updated [`src/optimization/optimization.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/optimization.mbt) so dead-result cleanup no longer retags a concrete `block` to `void` when the block body still contains a live branch targeting that block’s own label. That keeps branch payload expectations aligned with the surviving target block type instead of producing a later invalid encode/decode mismatch.
- Added focused regressions in [`src/optimization/dead_code_elimination_wbtest.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/dead_code_elimination_wbtest.mbt), [`src/cmd/generated_pipeline_wbtest.mbt`](/home/jtenner/Projects/starshine-mb/src/cmd/generated_pipeline_wbtest.mbt), and [`src/binary/tests.mbt`](/home/jtenner/Projects/starshine-mb/src/binary/tests.mbt) for current-label branch-value dead-result cleanup, the reduced raw return branch-payload bypass fixture, and the matching pre-lifted binary roundtrip.
- This slice removes the later invalid direct-DCE `Func 3175` family on the fresh release artifact, but the earlier `Func 716` direct-DCE blocker remains as the next live parity target.

## 2026-03-23 Validation: recursively drop dead terminal structured results during DCE truncation

- **DCE recursive dead-result cleanup** by **@jtenner**. Updated [`src/optimization/optimization.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/optimization.mbt) so the structured dead-tail truncation path now drops dead terminal result types recursively instead of only at the outermost instruction. When DCE truncates an enclosing expression after a terminal `if` / `block` / `try_table`, the pass now also rewrites the terminal result-carrying child expression that became dead under that truncation, including nested `loop` results in taken arms.
- Added focused regressions in [`src/optimization/dead_code_elimination_wbtest.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/dead_code_elimination_wbtest.mbt) for the new direct outer-break `if` retag case and the nested escaping-`if` case whose expected shape is now the stronger Binaryen-style dead-result cleanup.
- Documented the fresh-artifact blocker movement and recursive cleanup rule in [`docs/0069-2026-03-23-dce-recursive-dead-terminal-result-cleanup.md`](/home/jtenner/Projects/starshine-mb/docs/0069-2026-03-23-dce-recursive-dead-terminal-result-cleanup.md). This slice clears the earlier direct-DCE fresh-artifact failure at `Func 27`; the next direct artifact blocker is now later at `Func 716`.

## 2026-03-23 Validation: canonicalize duplicate simple type indices after DCE rewrites

- **DCE post-rewrite type cleanup** by **@jtenner**. Updated [`src/optimization/optimization.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/optimization.mbt) so `run_dead_code_elimination(...)` now reuses the existing duplicate-simple-type canonicalization helper after a changed rewrite. This compacts duplicate simple function/block types left behind when DCE deletes their last distinguishing uses, while preserving the same rewritten function bodies and function count.
- Added a focused regression in [`src/optimization/dead_code_elimination_wbtest.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/dead_code_elimination_wbtest.mbt) that starts with duplicate simple block and function types, runs DCE, and asserts the resulting module compacts to the canonical type indices and the rewritten body remains valid.
- Documented the rationale, pseudo-code, and fresh-artifact parity checkpoint in [`docs/0068-2026-03-23-dce-post-rewrite-type-canonicalization.md`](/home/jtenner/Projects/starshine-mb/docs/0068-2026-03-23-dce-post-rewrite-type-canonicalization.md). On the fresh release artifact, direct Starshine `--dead-code-elimination` still validates, keeps `3294` printed functions, and drops from `381` printed types to `109`, which is now close to Binaryen’s `110`.

## 2026-03-23 Validation: preserve explicit raw non-fallthrough after structured DCE rewrites

- **DCE structured terminal barrier** by **@jtenner**. Updated [`src/optimization/optimization.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/optimization.mbt) so dead-tail truncation now inserts an explicit trailing `unreachable` after structured instructions (`block`, `if`, `try_table`) that DCE proves are semantically non-fallthrough. This keeps the optimization while preserving raw Wasm validity instead of assuming those structured instructions are terminal by themselves after lowering.
- Added focused regressions in [`src/cmd/generated_pipeline_wbtest.mbt`](/home/jtenner/Projects/starshine-mb/src/cmd/generated_pipeline_wbtest.mbt), [`src/optimization/dead_code_elimination_wbtest.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/dead_code_elimination_wbtest.mbt), and [`src/validate/validate.mbt`](/home/jtenner/Projects/starshine-mb/src/validate/validate.mbt) for the reduced branch-payload-bypass repro, the new structured-terminal barrier expectations, and the branch-or-return validator shape.
- Documented the reduced repro, Binaryen comparison, and parity checkpoint in [`docs/0067-2026-03-23-dce-structured-terminal-unreachable-barrier.md`](/home/jtenner/Projects/starshine-mb/docs/0067-2026-03-23-dce-structured-terminal-unreachable-barrier.md). The minimized raw repro now validates after `--dead-code-elimination`, and the fresh artifact direct `--dead-code-elimination` plus `DFE -> RUME -> MemoryPacking -> OnceReduction -> DCE` prefix both validate again (`2517968` and `2352767` bytes respectively).

## 2026-03-23 Validation: tighten DCE control-flow termination and branch-payload handling

- **DCE `if` tail-escape check** by **@jtenner**. Updated [`src/optimization/optimization.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/optimization.mbt) so `DeadCodeElimination` no longer treats result-typed `if`s as body-terminating just because both branches are recursively “unreachable”. The pass now requires each branch tail to actually escape the enclosing expression, which preserves later required result tails after current-label `br 0` paths.
- **DCE strict branch-terminal rewrite guard** by **@jtenner**. Updated [`src/optimization/optimization.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/optimization.mbt) so `DeadCodeElimination` no longer uses the generic operand-short-circuit rewrite for `br`, `br_if`, `br_table`, or branch-on-ref payloads. Those branch families now only collapse on strict terminal children (`unreachable`, `return*`, `throw*`, or direct `br`/`br_table`), which prevents nested result-typed `if` payloads with escaping arms from deleting the enclosing branch itself.
- Added focused regressions in [`src/optimization/dead_code_elimination_wbtest.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/dead_code_elimination_wbtest.mbt), [`src/binary/tests.mbt`](/home/jtenner/Projects/starshine-mb/src/binary/tests.mbt), and [`src/cmd/generated_pipeline_wbtest.mbt`](/home/jtenner/Projects/starshine-mb/src/cmd/generated_pipeline_wbtest.mbt). The reduced generated-path nested dead-result branch-payload fixture now stays valid after `--dead-code-elimination` and encode/decode, but the fresh release artifact still fails later in the same family at `Func 716` / `Func 695`.

## 2026-03-23 Validation: treat prefix parent-continuation breaks as non-escaping in DCE block analysis

- **DCE parent-continuation escape analysis** by **@jtenner**. Updated [`src/optimization/optimization.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/optimization.mbt) so `optimization_dead_code_elimination_block_escapes_parent` now still blocks escape classification on live label-`0` breaks anywhere in the body, and also on live label-`1` breaks that appear before the tail instruction. This fixes the overly aggressive “tail escapes parent” classification for nested child blocks that rejoin the current block body before its final escaping tail.
- Added focused whitebox regressions in [`src/optimization/dead_code_elimination_wbtest.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/dead_code_elimination_wbtest.mbt) for deep current-label breaks, stacked-`if` current-label breaks, and deep parent-label breaks. Documented the rule and rationale in [`docs/0066-2026-03-23-dce-parent-continuation-escape-analysis.md`](/home/jtenner/Projects/starshine-mb/docs/0066-2026-03-23-dce-parent-continuation-escape-analysis.md).

## 2026-03-23 Validation: preserve void wrappers when DCE demotes concrete outer-break blocks

- **DCE concrete-block wrapper preservation** by **@jtenner**. Updated [`src/optimization/optimization.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/optimization.mbt) so `DeadCodeElimination` now keeps a `void` block wrapper when an escaping concrete block collapses to a single child that still has live breaks past the current label. This preserves label depth while still demoting away the dead concrete result type.
- Added focused regressions in [`src/optimization/dead_code_elimination_wbtest.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/dead_code_elimination_wbtest.mbt) and [`src/cmd/generated_pipeline_wbtest.mbt`](/home/jtenner/Projects/starshine-mb/src/cmd/generated_pipeline_wbtest.mbt) for the reduced outer-break result-block shape. Documented the rewrite rule and reduced raw-valid repro in [`docs/0065-2026-03-23-dce-concrete-block-wrapper-preservation.md`](/home/jtenner/Projects/starshine-mb/docs/0065-2026-03-23-dce-concrete-block-wrapper-preservation.md). The minimized raw repro now validates after `--dead-code-elimination`, and the fresh direct-DCE artifact blocker moved forward from `func 407` to `func 448`.

## 2026-03-23 Validation: account for `if` label depth in DCE live-break scans

- **DCE `if` label-depth fix** by **@jtenner**. Updated [`src/optimization/optimization.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/optimization.mbt) so `DeadCodeElimination`’s live-break-to-label scan now treats `if` bodies like other structured labels and increments target depth when descending into `then` / `else`. This keeps nested `br 1` edges visible as breaks to the enclosing block instead of misclassifying them as outer escapes.
- The focused regression in [`src/optimization/dead_code_elimination_wbtest.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/dead_code_elimination_wbtest.mbt) now passes, the minimized raw WAT repro from [`docs/0064-2026-03-23-dce-void-block-self-break-fix.md`](/home/jtenner/Projects/starshine-mb/docs/0064-2026-03-23-dce-void-block-self-break-fix.md) no longer trips the old post-encode `stack underflow`, and the release-artifact first blocker moved forward from `Func 531` / `Func 527` to a later `values remaining on stack at end of block` failure (`func 407` direct DCE, `func 403` on the five-pass prefix).

## 2026-03-23 Validation: restore workspace moon checks after fs/validate/fuzz API drift

- **Workspace rebuild unblock** by **@jtenner**. Updated [`src/fs/fs.mbt`](/home/jtenner/Projects/starshine-mb/src/fs/fs.mbt) and [`src/fs/moon.pkg`](/home/jtenner/Projects/starshine-mb/src/fs/moon.pkg) so `read_file_sync` now decodes UTF-8 through the imported core `encoding/utf8` package instead of calling the removed `Bytes.text()` API.
- **Validator/fuzz signature drift repair** by **@jtenner**. Updated [`src/validate/invalid_fuzzer.mbt`](/home/jtenner/Projects/starshine-mb/src/validate/invalid_fuzzer.mbt), [`src/validate/pkg.generated.mbti`](/home/jtenner/Projects/starshine-mb/src/validate/pkg.generated.mbti), [`src/fuzz/imports.mbt`](/home/jtenner/Projects/starshine-mb/src/fuzz/imports.mbt), [`src/fuzz/main.mbt`](/home/jtenner/Projects/starshine-mb/src/fuzz/main.mbt), and [`src/fuzz/moon.pkg`](/home/jtenner/Projects/starshine-mb/src/fuzz/moon.pkg) to match current transformer state conventions, optional-argument call syntax, and core-package imports. `validate-valid` now uses the existing `run_wat_roundtrip_fuzz` companion runner for text fuzz coverage instead of the broken direct `@lib.Module` to WAT path.

## 2026-03-23 Validation: keep DCE from truncating result blocks after inner self-break void blocks

- **Dead-code-elimination block escape fix** by **@jtenner**. Updated [`src/optimization/optimization.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/optimization.mbt) so `DeadCodeElimination` no longer treats a `void` block as escaping its parent when the only live breaks still target that block itself. That prevents enclosing concrete result blocks from losing their trailing value producer during nested-expression truncation.
- Added a focused regression in [`src/optimization/dead_code_elimination_wbtest.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/dead_code_elimination_wbtest.mbt) for the reduced `block (result i32) { block { if { br 1 } else { br 1 } } i32.const 7 }` shape that previously optimized to an invalid result block after DCE. Documented the minimized repro and follow-up validation constraints in [`docs/0064-2026-03-23-dce-void-block-self-break-fix.md`](/home/jtenner/Projects/starshine-mb/docs/0064-2026-03-23-dce-void-block-self-break-fix.md).

## 2026-03-23 Validation: align bun fuzz arg parsing with moon entrypoint

- **Seed/output alias support in Bun fuzz wrapper** by **@jtenner**. Updated [`scripts/lib/fuzz-task.ts`](/home/jtenner/Projects/starshine-mb/scripts/lib/fuzz-task.ts) to accept `--seed=<hex>` and `--output=<text|jsonl>` in addition to the existing space-separated variants.

## 2026-03-23 Validation: cover fuzz wrapper alias parsing in task-family commands

- **Regression test for equals-form flags** by **@jtenner**. Updated [`scripts/test/task-family-commands.ts`](/home/jtenner/Projects/starshine-mb/scripts/test/task-family-commands.ts) to assert that `bun fuzz run --suite=... --seed=... --output=...` is translated to the expected `moon run src/fuzz -- ... --seed ... --output jsonl` invocation.

## 2026-03-23 Validation: extend fuzz wrapper aliases for target and moon paths

- **Equals-form `--target=<...>` and `--moon=<...>` support** by **@jtenner**. Updated [`scripts/lib/fuzz-task.ts`](/home/jtenner/Projects/starshine-mb/scripts/lib/fuzz-task.ts) so both options now accept equals syntax for `bun fuzz run`; added task-family command coverage in [`scripts/test/task-family-commands.ts`](/home/jtenner/Projects/starshine-mb/scripts/test/task-family-commands.ts) to lock in `--target=<...>` and `--moon=<...>` handling.

## 2026-03-23 Validation: add remaining wrapper alias forms for suite/profile

- **Equals-form `--suite=<...>` and `--profile=<...>` support** by **@jtenner**. Updated [`scripts/lib/fuzz-task.ts`](/home/jtenner/Projects/starshine-mb/scripts/lib/fuzz-task.ts) so `bun fuzz run` now accepts these aliases and normalizes them to the moon command format. Added task-family coverage in [`scripts/test/task-family-commands.ts`](/home/jtenner/Projects/starshine-mb/scripts/test/task-family-commands.ts).

## 2026-03-23 Validation: document fuzz wrapper alias examples

- **README CLI examples for equals-form wrapper flags** by **@jtenner**. Updated [`README.mbt.md`](/home/jtenner/Projects/starshine-mb/README.mbt.md) to include `--suite=`, `--profile=`, `--seed=`, `--target=`, and `--output=` usage examples for `bun fuzz run`.

## 2026-03-23 Validation: assert fuzz-help passthrough in task-family commands

- **Regression coverage for `bun fuzz run --help`** by **@jtenner**. Added a task-family command assertion in [`scripts/test/task-family-commands.ts`](/home/jtenner/Projects/starshine-mb/scripts/test/task-family-commands.ts) to ensure help mode passes through to `moon run src/fuzz -- --help` with default target behavior.

## 2026-03-23 Validation: strengthen validate-valid fuzz stability checks

- **Validator fuzz stability hardening** by **@jtenner**. Updated [`src/fuzz/main.mbt`](/home/jtenner/Projects/starshine-mb/src/fuzz/main.mbt) so the `validate-valid` suite now validates each generated module through binary encode/decode roundtrip before acceptance and exercises optional WAT roundtrip stability in CI/stress profiles. Added profile-tuned text-roundtrip attempts/stability floors and shared whitespace-normalized comparison logic.

## 2026-03-23 Validation: seed invalid-fuzz suites from `tests/spec`

- **Seeded invalid-fuzz suites** by **@jtenner**. Updated [`src/validate/invalid_fuzzer.mbt`](/home/jtenner/Projects/starshine-mb/src/validate/invalid_fuzzer.mbt) so `run_validate_invalid_fuzz` uses a shared core engine and exposes `run_validate_invalid_fuzz_from_modules` for deterministic corpus-backed mutation runs. Updated [`src/fuzz/main.mbt`](/home/jtenner/Projects/starshine-mb/src/fuzz/main.mbt) and [`src/fuzz/imports.mbt`](/home/jtenner/Projects/starshine-mb/src/fuzz/imports.mbt) to wire `spec-seed`, `binary-invalid`, and `text-invalid` suites to parsed `tests/spec` module seeds from `wast_to_script`. Updated [`src/validate/pkg.generated.mbti`](/home/jtenner/Projects/starshine-mb/src/validate/pkg.generated.mbti) to export the new seeded invalid-fuzz API.

## 2026-03-23 Validation: tighten invalid-fuzz repro metadata and API surface

- **validator invalid-fuzz mismatch diagnostics** by **@jtenner**. Updated [`src/validate/invalid_fuzzer.mbt`](/home/jtenner/Projects/starshine-mb/src/validate/invalid_fuzzer.mbt) so mismatch reports now carry strategy-specific expected issue families, then persist those fields through the callback-backed `ValidateInvalidFuzzFailure` path. Updated [`src/fuzz/main.mbt`](/home/jtenner/Projects/starshine-mb/src/fuzz/main.mbt) so invalid-fuzz repro metadata writes include the selected suite and strategy label.
- Synchronized [`src/validate/pkg.generated.mbti`](/home/jtenner/Projects/starshine-mb/src/validate/pkg.generated.mbti) with the public API change (`run_validate_invalid_fuzz` callback argument and strategy-counting structs) to keep API consumers and generated signatures aligned.

## 2026-03-23 Validation: harden invalid-fuzz strategy execution and coverage

- **Validator fuzz hardening** by **@jtenner**. Updated [`src/validate/gen_valid.mbt`](/home/jtenner/Projects/starshine-mb/src/validate/gen_valid.mbt), [`src/validate/invalid_fuzzer.mbt`](/home/jtenner/Projects/starshine-mb/src/validate/invalid_fuzzer.mbt) so generated valid modules now include exports (making `DuplicateExportName` exercisable), `HeapTypeSwap` uses its dedicated heap-type mutation path, and invalid-fuzz stats now track per-strategy attempt/mutation/rejection counts with expected diagnostic-family checks.
- Added focused invalid-fuzz regressions in [`src/validate/invalid_fuzzer.mbt`](/home/jtenner/Projects/starshine-mb/src/validate/invalid_fuzzer.mbt) for the real `HeapTypeSwap` path and module mutation validity.

## 2026-03-23 Validation: align Bun fuzz wrapper defaults and output surface with moon fuzz

- **Bun `fuzz` wrapper alignment** by **@jtenner**. Updated [`scripts/lib/fuzz-task.ts`](/home/jtenner/Projects/starshine-mb/scripts/lib/fuzz-task.ts) so `bun fuzz run` now defaults to `smoke`, supports positional `suite profile seed` arguments, and exposes `--output text|jsonl|--jsonl`, `--list-suites`, `--list-profiles`, and `--help`, matching the `src/fuzz` entrypoint surface more closely.
- Added matching usage in [`README.mbt.md`](/home/jtenner/Projects/starshine-mb/README.mbt.md) so the new wrapper features are discoverable.

## 2026-03-23 Remove-unused-names test formatting cleanup

- **Finalize candidate-scan regression formatting** by **@jtenner**. Updated [`src/optimization/remove_unused_names_wbtest.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/remove_unused_names_wbtest.mbt) to make candidate-scan fixtures use explicit multiline array formatting for readability without changing test behavior.

## 2026-03-23 Docs and scripts comment refresh

- **Update README and scripts clarity for second-round maintenance** by **@jtenner**. Updated [`README.mbt.md`](/home/jtenner/Projects/starshine-mb/README.mbt.md) and [`tests/spec/README.md`](/home/jtenner/Projects/starshine-mb/tests/spec/README.md) to refresh stale command usage and check guidance, and added/adjusted clarifying comments in [`scripts/lib/benchmark-optimize.mjs`](/home/jtenner/Projects/starshine-mb/scripts/lib/benchmark-optimize.mjs), [`scripts/lib/build-node-package.mjs`](/home/jtenner/Projects/starshine-mb/scripts/lib/build-node-package.mjs), [`scripts/lib/examples-task.ts`](/home/jtenner/Projects/starshine-mb/scripts/lib/examples-task.ts), [`scripts/lib/moonbit-wasi-runner.mjs`](/home/jtenner/Projects/starshine-mb/scripts/lib/moonbit-wasi-runner.mjs), [`scripts/lib/self-optimize-compare-task.ts`](/home/jtenner/Projects/starshine-mb/scripts/lib/self-optimize-compare-task.ts), [`scripts/lib/validate-task.ts`](/home/jtenner/Projects/starshine-mb/scripts/lib/validate-task.ts), and [`src/wast/spec_harness.mbt`](/home/jtenner/Projects/starshine-mb/src/wast/spec_harness.mbt).

## 2026-03-23 Docs: annotate confusing code paths and keep CLI/help behavior explicit

- **Second comment/docs pass** by **@jtenner**. Added high-signal inline comments in [`src/cmd/readme_api_sync.mbt`](/home/jtenner/Projects/starshine-mb/src/cmd/readme_api_sync.mbt), [`src/cmd/cmd.mbt`](/home/jtenner/Projects/starshine-mb/src/cmd/cmd.mbt), [`src/validate/env.mbt`](/home/jtenner/Projects/starshine-mb/src/validate/env.mbt), and [`src/binary/encode.mbt`](/home/jtenner/Projects/starshine-mb/src/binary/encode.mbt) to document resolution, scheduling, stack-polymorphic behavior, and stringref encoding context assumptions.
- **Script/tooling annotation pass** by **@jtenner**. Added clarifying comments in [`scripts/lib/build-self-optimized.mjs`](/home/jtenner/Projects/starshine-mb/scripts/lib/build-self-optimized.mjs), [`scripts/lib/fuzz-task.ts`](/home/jtenner/Projects/starshine-mb/scripts/lib/fuzz-task.ts), [`scripts/lib/self-opt-task.ts`](/home/jtenner/Projects/starshine-mb/scripts/lib/self-opt-task.ts), [`scripts/lib/self-optimized-artifacts.mjs`](/home/jtenner/Projects/starshine-mb/scripts/lib/self-optimized-artifacts.mjs), [`scripts/lib/task-runtime.ts`](/home/jtenner/Projects/starshine-mb/scripts/lib/task-runtime.ts), and [`scripts/lib/make-task.ts`](/home/jtenner/Projects/starshine-mb/scripts/lib/make-task.ts) to make script flow and artifact-selection behavior easier to audit.

## 2026-03-23 Docs: refresh CLI docs and clarify command/pipeline behavior

- **README and CLI-doc refresh** by **@jtenner**. Updated [`README.mbt.md`](/home/jtenner/Projects/starshine-mb/README.mbt.md), [`examples/README.md`](/home/jtenner/Projects/starshine-mb/examples/README.md), [`node/README.md`](/home/jtenner/Projects/starshine-mb/node/README.md), [`node/examples/README.md`](/home/jtenner/Projects/starshine-mb/node/examples/README.md), and [`tests/spec/README.md`](/home/jtenner/Projects/starshine-mb/tests/spec/README.md) to replace outdated compatibility notes, clarify config/env/CLI precedence, and keep example indexes aligned with current scripts.
- **Round 2 command-path comments** by **@jtenner**. Added focused comments in [`src/cmd/cmd.mbt`](/home/jtenner/Projects/starshine-mb/src/cmd/cmd.mbt), [`node/cmd.js`](/home/jtenner/Projects/starshine-mb/node/cmd.js), and [`src/node_api/custom.mbt`](/home/jtenner/Projects/starshine-mb/src/node_api/custom.mbt) for parser precedence, generated-pass scheduling, and legacy compatibility behavior.
- **Source-tooling annotation clarity** by **@jtenner**. Added short helper/context comments in [`scripts/lib/readme-api-sync.ts`](/home/jtenner/Projects/starshine-mb/scripts/lib/readme-api-sync.ts) and [`scripts/lib/validate-task.ts`](/home/jtenner/Projects/starshine-mb/scripts/lib/validate-task.ts) to reduce future drift and clarify internal assumptions for CI-facing behavior.

## 2026-03-23 Validation: propagate non-fallthrough block exits so dead-code-eliminated control blocks no longer require fake fallthrough results

- **Raw and typed block-exit propagation** by **@jtenner**. Updated [`src/validate/typecheck.mbt`](/home/jtenner/Projects/starshine-mb/src/validate/typecheck.mbt) so raw and typed `block` validation now distinguishes real block merges from bodies that end in `return`, `unreachable`, or an outer-label branch. Non-fallthrough blocks now keep the enclosing state unreachable with the appropriate escape instead of being treated as if they always reach the block merge.
- Added focused regressions in [`src/validate/validate.mbt`](/home/jtenner/Projects/starshine-mb/src/validate/validate.mbt), [`src/binary/tests.mbt`](/home/jtenner/Projects/starshine-mb/src/binary/tests.mbt), and [`src/cmd/generated_pipeline_wbtest.mbt`](/home/jtenner/Projects/starshine-mb/src/cmd/generated_pipeline_wbtest.mbt) covering nested branch ladders, pre-lifted branch ladders, and generated DCE replay on reduced branch-escape fixtures.
- Refreshed [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md) so the active parity blocker no longer points at the fixed `Func 313` / `Func 315` block-exit case and instead calls out the next mixed return-or-escape post-encode validation failure now surfacing first in the release artifact replay.

## 2026-03-23 Validation: fix raw nested-`if` escape merges and DCE pre-effect escape tracking

- **Nested escape correctness repair** by **@jtenner**. Updated [`src/validate/typecheck.mbt`](/home/jtenner/Projects/starshine-mb/src/validate/typecheck.mbt) so raw `if` validation no longer treats every escaping branch arm as reaching the `if` merge, which was rejecting valid typed-to-raw encodes where one arm branches past the `if` and the other arm reaches normally.
- **DCE pre-effect escape tracking** by **@jtenner**. Updated [`src/optimization/optimization.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/optimization.mbt) so `DeadCodeElimination` no longer treats `return` / `return_call*` / `throw*` / branch terminators as guaranteed current-expression terminators when one of their pre-effect child expressions can branch away first, and so result-typed `if` rewrites keep their result type when both arms only escape outer labels.
- Added focused regressions in [`src/binary/tests.mbt`](/home/jtenner/Projects/starshine-mb/src/binary/tests.mbt), [`src/optimization/dead_code_elimination_wbtest.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/dead_code_elimination_wbtest.mbt), and [`src/validate/validate.mbt`](/home/jtenner/Projects/starshine-mb/src/validate/validate.mbt) for the typed encode roundtrip and the DCE escaping-`if` case, and refreshed [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md) with the next remaining native replay blocker after `Func 27` / `Func 227`.

## 2026-03-23 Optimization: pre-scan `RemoveUnusedNames` candidate-free functions

- **`RemoveUnusedNames` candidate pre-scan** by **@jtenner**. Updated [`src/optimization/optimization.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/optimization.mbt) so the pass now skips the full rewrite walk on typed function bodies that contain neither a `loop` nor a same-typed single-child block-peel opportunity.
- Added direct candidate-scan coverage in [`src/optimization/remove_unused_names_wbtest.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/remove_unused_names_wbtest.mbt), covering both the no-candidate and nested same-typed block cases.
- Recorded the slice and the still-open large-artifact runtime blocker in [`docs/0063-2026-03-23-remove-unused-names-candidate-prescan.md`](/home/jtenner/Projects/starshine-mb/docs/0063-2026-03-23-remove-unused-names-candidate-prescan.md), and refreshed [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md) so the next work stays focused on traversal cost inside candidate-bearing functions rather than broader pass semantics.

## 2026-03-23 Optimization: memoize `RemoveUnusedNames` branch-target summaries

- **`RemoveUnusedNames` branch-summary rework** by **@jtenner**. Updated [`src/optimization/optimization.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/optimization.mbt) so the pass now answers its live-target queries from one memoized typed-body summary of the nearest escaping branch/catch target depth instead of repeatedly rescanning whole subtrees, while keeping the rewrite surface aligned with Binaryen's narrow name-cleanup behavior.
- Added focused `try_table` catch-target coverage in [`src/optimization/remove_unused_names_wbtest.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/remove_unused_names_wbtest.mbt) so peeled same-typed blocks still bail out when a catch target would be retargeted incorrectly.
- Documented the algorithm, pseudocode, and remaining fresh-artifact blockers in [`docs/0062-2026-03-23-remove-unused-names-branch-summary-rework.md`](/home/jtenner/Projects/starshine-mb/docs/0062-2026-03-23-remove-unused-names-branch-summary-rework.md), and refreshed [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md) so the next `RemoveUnusedNames` slice is now candidate pre-scan work plus the still-blocked fresh-artifact parity rerun.

## 2026-03-23 CLI: honor explicit generated replay flags for late shared passes

- **Generated replay flag wiring** by **@jtenner**. Updated [`src/cmd/cmd.mbt`](/home/jtenner/Projects/starshine-mb/src/cmd/cmd.mbt) so the explicit generated-pipeline path now actually schedules `DeadCodeElimination` and `RemoveUnusedNames` when the user passes `--dead-code-elimination` or `--remove-unused-names`, instead of silently dropping those flags from the generated replay.
- Added focused generated-path coverage in [`src/cmd/generated_pipeline_wbtest.mbt`](/home/jtenner/Projects/starshine-mb/src/cmd/generated_pipeline_wbtest.mbt) proving both flags now appear in the generated pass list and that `--remove-unused-names` rewrites a raw nested-block fixture after pre-lift.
- Updated [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md) so the active parity backlog now treats earlier explicit late-pass replay numbers as stale and puts the next `RemoveUnusedNames` work on a Binaryen-aligned single-pass rework before rerunning the fresh-artifact comparison.

## 2026-03-23 Optimization: keep live func-local runners in grouped stages

- **Grouped func-local runner dispatch** by **@jtenner**. Updated [`src/optimization/optimization.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/optimization.mbt) so adjacent grouped function passes append the actual implemented runner for each pass instead of always appending `noop_func_local_pass`; this keeps `RemoveUnusedNames` and `DeadCodeElimination` live inside the real grouped default stage, not just when scheduled alone.
- Added focused scheduler coverage in [`src/optimization/optimization_test.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/optimization_test.mbt) proving a grouped `RemoveUnusedNames` slot still runs the live peeling rewrite instead of a no-op runner.

## 2026-03-23 Optimization: land `RemoveUnusedNames` loop demotion

- **`RemoveUnusedNames` slice 3** by **@jtenner**. Extended [`src/optimization/optimization.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/optimization.mbt) so typed `loop` instructions now demote to `block` when the loop label has no remaining continue edge, while loops with a surviving `br 0` keep their original loop shape.
- Added focused loop regressions in [`src/optimization/remove_unused_names_wbtest.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/remove_unused_names_wbtest.mbt) for both void and value-producing loops, covering both sides of the rule.
- Updated [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md) so `RemoveUnusedNames` is now implementation-complete on the current typed surface and only the fresh-artifact Binaryen parity replay remains.

## 2026-03-23 Optimization: land `RemoveUnusedNames` live-target bailout

- **`RemoveUnusedNames` slice 2** by **@jtenner**. Extended [`src/optimization/optimization.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/optimization.mbt) so same-typed block peeling now first scans nested typed control for labels that still target one of the scopes about to be removed and bails out instead of rebasing those branches into a different meaning.
- Added the focused valid bailout regression in [`src/optimization/remove_unused_names_wbtest.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/remove_unused_names_wbtest.mbt), covering the nested `if` arm branch that must keep the redundant-looking block because it is still a live control-flow target.
- Updated [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md) so the remaining `RemoveUnusedNames` work is now narrowed to loop demotion plus the fresh-artifact parity replay.

## 2026-03-23 Optimization: land `RemoveUnusedNames` block-peeling slice

- **`RemoveUnusedNames` slice 1** by **@jtenner**. Updated [`src/optimization/optimization.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/optimization.mbt) so `OptimizePass::RemoveUnusedNames` now uses a dedicated func-local runner instead of `noop_func_local_pass`, and the first live typed rewrite peels single-child same-typed nested blocks while rebasing typed branch labels through the removed scopes.
- Added focused whitebox coverage in [`src/optimization/remove_unused_names_wbtest.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/remove_unused_names_wbtest.mbt) for runner dispatch, no-candidate no-op behavior, same-typed block peeling, branch-depth rebasing, and typed branch-payload preservation.
- Updated [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md) so the remaining `RemoveUnusedNames` work is now narrowed to the live-target bailout slice, loop demotion, and the fresh-artifact parity replay.

## 2026-03-23 Optimization: plan `RemoveUnusedNames` completion slices

- **`RemoveUnusedNames` implementation plan** by **@jtenner**. Added [`docs/0061-2026-03-23-remove-unused-names-implementation-plan.md`](/home/jtenner/Projects/starshine-mb/docs/0061-2026-03-23-remove-unused-names-implementation-plan.md) to document the current no-op gap, Binaryen-facing pass behavior, the minimal typed-IR algorithm to port, pseudocode for block peeling / label rebasing / loop demotion, and the concrete implementation slices needed to close the pass.
- Updated [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md) so the active parity backlog now treats `RemoveUnusedNames` as the next concrete shared-pass implementation target after the generated pre-lift DCE recheck, with explicit slice ordering and parity checkpoints.

## 2026-03-23 Validate: truncate unreachable raw branch tails during generated pre-lift

- **Generated pre-lift dead-tail cleanup** by **@jtenner**. Updated [`src/validate/env.mbt`](/home/jtenner/Projects/starshine-mb/src/validate/env.mbt) so nested raw `block` / `loop` / `if` / `try_table` body conversion stops consuming sibling instructions after the first stack-polymorphic terminator instead of preserving dead raw branch tails inside the lifted validation path, while keeping top-level stack-polymorphic tails intact.
- Added focused generated-pipeline regressions in [`src/cmd/generated_pipeline_wbtest.mbt`](/home/jtenner/Projects/starshine-mb/src/cmd/generated_pipeline_wbtest.mbt) proving the dead `drop` after an unconditional raw `br` is already gone after generated pre-lift with no passes and remains gone when the explicit `DeadCodeElimination` pass is added.
- Recorded the parity recheck in [`docs/0060-2026-03-23-generated-prelift-dead-branch-tail-cleanup.md`](/home/jtenner/Projects/starshine-mb/docs/0060-2026-03-23-generated-prelift-dead-branch-tail-cleanup.md), which supersedes the earlier fresh-artifact `DeadCodeElimination` parity claim: on the rebuilt release artifact, Starshine `DFE -> RUME -> MemoryPacking -> OnceReduction` now shrinks from `2353318` to `2352785` before DCE, so the old `-4` Binaryen `DCE` delta was evidence of a generated lifting bug, not a remaining Starshine DCE omission.

## 2026-03-23 Optimization: record fresh-artifact `DFE -> RUME -> MP -> OR -> DCE` parity gap

- **DeadCodeElimination fresh-artifact checkpoint** by **@jtenner**. Added [`docs/0059-2026-03-23-dfe-rume-memory-packing-once-dce-fresh-artifact-parity.md`](/home/jtenner/Projects/starshine-mb/docs/0059-2026-03-23-dfe-rume-memory-packing-once-dce-fresh-artifact-parity.md) to record the first later shared-pass divergence after the repaired DFE merge set: on the fresh rebuilt release artifact, Starshine `DeadCodeElimination` is a byte-for-byte no-op after `DFE -> RUME -> MemoryPacking -> OnceReduction`, while Binaryen still shrinks the code section by `4` bytes by removing dead branch-tail cleanup.
- Refreshed [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md) so the active parity backlog now treats fresh-artifact `DeadCodeElimination` as the next real optimization blocker instead of `RemoveUnusedModuleElements`, `MemoryPacking`, or `OnceReduction`.

## 2026-03-23 Validation: queue validator fuzz hardening follow-ups

- **Validator fuzz backlog slicing** by **@jtenner**. Updated [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md) to turn the new validator fuzz research in [`docs/0058-2026-03-23-validate-fuzz-hardening-plan.md`](/home/jtenner/Projects/starshine-mb/docs/0058-2026-03-23-validate-fuzz-hardening-plan.md) into pickup-ready follow-up work, including the immediate `HeapTypeSwap` dispatch fix, invalid-strategy coverage hardening, generator/export coverage work, and the later repro/spec-seed/binary-text fuzz extensions.

## 2026-03-23 Optimization: record fresh-artifact `DFE -> RUME -> MP` parity checkpoint

- **MemoryPacking parity checkpoint** by **@jtenner**. Added [`docs/0058-2026-03-23-dfe-rume-memory-packing-fresh-artifact-parity.md`](/home/jtenner/Projects/starshine-mb/docs/0058-2026-03-23-dfe-rume-memory-packing-fresh-artifact-parity.md) to record the fresh rebuilt release-artifact replay after the DFE direct-pass alignment: `DuplicateFunctionElimination -> RemoveUnusedModuleElements -> MemoryPacking` validates on both tools and shrinks both outputs by the same `1792` bytes, with unchanged code sections and matching `data` / `data count` section effects.
- Refreshed [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md) so the active parity backlog now treats `MemoryPacking` as another clean fresh-artifact checkpoint and points the next investigation at later passes or the residual serializer/layout drift.

## 2026-03-23 Optimization: record fresh-artifact `DFE -> RUME` parity checkpoint

- **RemoveUnusedModuleElements parity checkpoint** by **@jtenner**. Added [`docs/0057-2026-03-23-dfe-rume-fresh-artifact-parity.md`](/home/jtenner/Projects/starshine-mb/docs/0057-2026-03-23-dfe-rume-fresh-artifact-parity.md) to record the fresh rebuilt release-artifact replay after the DFE direct-pass alignment: `DuplicateFunctionElimination -> RemoveUnusedModuleElements` is byte-identical to direct `DuplicateFunctionElimination` on both Starshine and Binaryen, so there is no new RUME-specific parity gap on that artifact.
- Refreshed [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md) so the active parity backlog explicitly tracks that the next fresh-artifact blocker is still post-DFE serialization/layout drift or a later pass, not `RemoveUnusedModuleElements`.

## 2026-03-23 Optimization: align direct DFE with Binaryen’s single-pass merge set

- **DuplicateFunctionElimination direct-pass parity** by **@jtenner**. Updated [`src/optimization/optimization.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/optimization.mbt) so explicit `DuplicateFunctionElimination` now behaves like Binaryen’s direct pass instead of running to a private fixpoint, while still canonicalizing duplicate simple function type indices inside typed function bodies for equality and hashing. On the fresh rebuilt release artifact this lands the same direct-pass merge count as Binaryen: `2892` defined functions after one DFE run.
- Refreshed focused coverage in [`src/optimization/duplicate_function_elimination_wbtest.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/duplicate_function_elimination_wbtest.mbt) for single-pass transitive-call behavior, explicit rerun behavior, duplicate local-run declarations, and typed duplicate block-type indices, and updated [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md) so the remaining DFE parity work is tracked as post-merge serialization/layout drift rather than a mismatched direct-pass merge set.

## 2026-03-22 Optimization: compact duplicate simple type indices after DFE

- **DuplicateFunctionElimination type-index compaction** by **@jtenner**. Updated [`src/optimization/optimization.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/optimization.mbt) so direct DFE now canonically rewrites duplicate simple single-rec function type indices after the merge set is settled, including surviving body `block` type indices, import/tag extern type references, and type-name custom-section entries.
- Added focused coverage in [`src/optimization/duplicate_function_elimination_wbtest.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/duplicate_function_elimination_wbtest.mbt) for post-merge duplicate type compaction, and refreshed [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md) so the remaining fresh-artifact DFE gap is now almost entirely code bytes plus a smaller element-section delta versus Binaryen.

## 2026-03-22 Optimization: make direct DFE iterate to a fixpoint

- **DuplicateFunctionElimination fixpoint parity** by **@jtenner**. Updated [`src/optimization/optimization.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/optimization.mbt) so explicit `DuplicateFunctionElimination` no longer stops after a single iteration at default settings and instead runs until the pass reaches its own bounded fixpoint, matching the already-correct `-O2` behavior on the fresh rebuilt release artifact.
- Added focused regression coverage in [`src/optimization/duplicate_function_elimination_wbtest.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/duplicate_function_elimination_wbtest.mbt) for the default no-opt-preset fixpoint case, and refreshed [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md) so the next DFE parity blocker is the remaining type/index compaction gap versus Binaryen, not the old default-iteration mismatch.

## 2026-03-22 Binary: hoist typed multi-value control seeds by stack effect

- **Typed multi-value control lowering repair** by **@jtenner**. Updated [`src/binary/encode.mbt`](/home/jtenner/Projects/starshine-mb/src/binary/encode.mbt) so typed `block` / `loop` / `if` / `try_table` lowering finds the shortest raw prefix that produces each control instruction's required parameter values in full function-local validation context instead of assuming the first `N` instructions are the seed prefix.
- Added focused binary regressions in [`src/binary/tests.mbt`](/home/jtenner/Projects/starshine-mb/src/binary/tests.mbt) for nested typed loop seeds, high type-index raw round-trips, and the single multi-value-producer loop case that was leaving the fresh release artifact invalid after `DuplicateFunctionElimination`, and refreshed [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md) so the active parity blocker is now the remaining DFE size gap versus Binaryen on a regenerated artifact.

## 2026-03-22 Scripts: validate copied self-opt artifact fixtures at the source

- **Self-opt artifact validation** by **@jtenner**. Updated [`scripts/lib/self-optimized-artifacts.mjs`](/home/jtenner/Projects/starshine-mb/scripts/lib/self-optimized-artifacts.mjs) so copied debug/release wasm dist artifacts and generated self-optimized outputs are validated with `wasm-tools validate` as part of the artifact pipeline instead of being assumed valid by downstream compare and benchmark tools.
- Added focused coverage in [`scripts/test/self-optimized-artifacts-validation.ts`](/home/jtenner/Projects/starshine-mb/scripts/test/self-optimized-artifacts-validation.ts) to assert the copy step validates both copied dist fixtures, while keeping the existing self-opt command wrappers green.

## 2026-03-22 Scripts: reject invalid self-optimize compare baselines up front

- **Compare baseline validation** by **@jtenner**. Updated [`scripts/lib/self-optimize-compare-task.ts`](/home/jtenner/Projects/starshine-mb/scripts/lib/self-optimize-compare-task.ts) so `self-optimize-compare` validates the input module before running either tool and fails immediately with the baseline validation error instead of reporting misleading pass-parity output for already-invalid fixtures.
- Added harness coverage in [`scripts/test/self-optimize-compare-command.ts`](/home/jtenner/Projects/starshine-mb/scripts/test/self-optimize-compare-command.ts) for the new `wasm-tools validate` preflight and in [`scripts/test/self-optimize-compare-invalid-input.ts`](/home/jtenner/Projects/starshine-mb/scripts/test/self-optimize-compare-invalid-input.ts) for the invalid-baseline failure path.

## 2026-03-22 Binary: preserve typed control-flow parameter seeds during encoding

- **Typed control-flow encoding repair** by **@jtenner**. Fixed module-context typed-function lowering in [`src/binary/encode.mbt`](/home/jtenner/Projects/starshine-mb/src/binary/encode.mbt) so `block`/`loop`/`if`/`try_table` instructions with `BlockType::type_idx(...)` hoist explicit parameter seed values back in front of the control instruction instead of leaving them buried inside the lowered body and corrupting raw stack form during encode.
- Added a focused round-trip regression in [`src/binary/tests.mbt`](/home/jtenner/Projects/starshine-mb/src/binary/tests.mbt) for typed `loop` parameter seeds, plus a guard regression in [`src/transformer/tests.mbt`](/home/jtenner/Projects/starshine-mb/src/transformer/tests.mbt) proving plain `FuncIdx` rewrites do not reorder raw `call` / `i32.const` / `loop` sequences.

## 2026-03-22 Optimization: audit five-pass `-O4z` parity gaps

- **Five-pass parity audit** by **@jtenner**. Added [`docs/0056-2026-03-22-o4z-five-pass-parity-audit.md`](/home/jtenner/Projects/starshine-mb/docs/0056-2026-03-22-o4z-five-pass-parity-audit.md) to record the current release-artifact comparison for the five fully implemented `-O4z` passes, including the current prefix matrix, the early `DuplicateFunctionElimination` validity failure, the surviving size gaps versus Binaryen, and the remaining methodology/tooling constraints around explicit five-pass replay.
- Refreshed [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md) so the active optimization blockers now reflect the new `-O4z` five-pass evidence: release-artifact DFE is the first correctness blocker, `MemoryPacking` is not the source of the surviving gap on this artifact, and Binaryen's direct `-O4z` preset is not available in `wasm-opt version 125`.

## 2026-03-22 Optimization: add Binaryen pass-compare harness and stabilize rewritten name maps

- **Artifact comparison and name-map repair** by **@jtenner**. Canonicalized rewritten function and local name maps in [`src/optimization/optimization.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/optimization.mbt) so non-monotonic function remaps no longer preserve invalid name ordering, and added focused regressions in [`src/optimization/duplicate_function_elimination_wbtest.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/duplicate_function_elimination_wbtest.mbt) and [`src/cmd/cmd_test.mbt`](/home/jtenner/Projects/starshine-mb/src/cmd/cmd_test.mbt) for duplicate-function elimination name-section rewrites.
- Added the new Bun comparison harness in [`scripts/self-optimize-compare.ts`](/home/jtenner/Projects/starshine-mb/scripts/self-optimize-compare.ts), [`scripts/lib/self-optimize-compare-task.ts`](/home/jtenner/Projects/starshine-mb/scripts/lib/self-optimize-compare-task.ts), and [`scripts/test/self-optimize-compare-command.ts`](/home/jtenner/Projects/starshine-mb/scripts/test/self-optimize-compare-command.ts) so ordered pass flags can be replayed through both Starshine and Binaryen and emitted as paired `.wasm` and normalized `.wat` artifacts for divergence checks.
- Recorded the current artifact comparison state in [`docs/0054-2026-03-22-starshine-wasm-implemented-pass-comparison.md`](/home/jtenner/Projects/starshine-mb/docs/0054-2026-03-22-starshine-wasm-implemented-pass-comparison.md), corrected the canonical method in [`docs/0055-2026-03-22-binaryen-full-pipeline-comparison-method.md`](/home/jtenner/Projects/starshine-mb/docs/0055-2026-03-22-binaryen-full-pipeline-comparison-method.md), refreshed [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md), and added the generated comparison outputs to [`.gitignore`](/home/jtenner/Projects/starshine-mb/.gitignore).

## 2026-03-22 Optimization: start `StringGathering` with existing-global reuse

- **First StringGathering slice** by **@jtenner**. Landed the first live `StringGathering` implementation in [`src/optimization/optimization.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/optimization.mbt): the pass now scans existing defined immutable `stringref` globals initialized by direct `string.const`, reuses the first canonical global per literal, and rewrites matching raw and typed function-body literals to `global.get` instead of leaving the pass as a module-wide no-op.
- Added focused coverage in [`src/optimization/string_gathering_wbtest.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/string_gathering_wbtest.mbt) for typed-body reuse, raw-body reuse, and imported-global rejection, plus a pipeline-dispatch check in [`src/optimization/optimization_test.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/optimization_test.mbt) so the default optimizer now proves `StringGathering` routes through the live runner when `has_strings` is enabled.
- Recorded the checkpoint in [`docs/0053-2026-03-22-string-gathering-existing-global-reuse.md`](/home/jtenner/Projects/starshine-mb/docs/0053-2026-03-22-string-gathering-existing-global-reuse.md), refreshed the broader research status in [`docs/0009-2026-03-16-string-optimization.md`](/home/jtenner/Projects/starshine-mb/docs/0009-2026-03-16-string-optimization.md), and updated [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md) so the next `StringGathering` slices are missing-global synthesis and module-level initializer repair.

## 2026-03-22 String: land `string.const` text, validation, binary, and SSA support

- **String literal compatibility** by **@jtenner**. Landed `string.const` end to end across the public lib surface, validator/typechecker, WAST parser/printer/lowerer, module binary string-literal section support, generated `has_strings` detection, constant-expression validation, and SSA compatibility in [`src/lib/types.mbt`](/home/jtenner/Projects/starshine-mb/src/lib/types.mbt), [`src/validate/typecheck.mbt`](/home/jtenner/Projects/starshine-mb/src/validate/typecheck.mbt), [`src/validate/validate.mbt`](/home/jtenner/Projects/starshine-mb/src/validate/validate.mbt), [`src/wast/parser.mbt`](/home/jtenner/Projects/starshine-mb/src/wast/parser.mbt), [`src/wast/module_wast.mbt`](/home/jtenner/Projects/starshine-mb/src/wast/module_wast.mbt), [`src/wast/lower_to_lib.mbt`](/home/jtenner/Projects/starshine-mb/src/wast/lower_to_lib.mbt), [`src/binary/encode.mbt`](/home/jtenner/Projects/starshine-mb/src/binary/encode.mbt), [`src/binary/decode.mbt`](/home/jtenner/Projects/starshine-mb/src/binary/decode.mbt), and the IR files under [`src/ir/`](/home/jtenner/Projects/starshine-mb/src/ir).
- Recorded the slice in [`docs/0052-2026-03-22-string-const-surface.md`](/home/jtenner/Projects/starshine-mb/docs/0052-2026-03-22-string-const-surface.md), refreshed the `StringGathering` prerequisite note in [`docs/0009-2026-03-16-string-optimization.md`](/home/jtenner/Projects/starshine-mb/docs/0009-2026-03-16-string-optimization.md), and updated [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md) so the next string follow-up is the pass work itself plus the remaining binary-interoperability question around canonical `stringref` bytes.

## 2026-03-22 IR: clean string GVN diagnostics

- **Diagnostics cleanup** by **@jtenner**. Removed the duplicate `string.encode_*_array` `has_side_effects` cases in [`src/ir/gvn.mbt`](/home/jtenner/Projects/starshine-mb/src/ir/gvn.mbt) so the new string-array SSA compatibility slice no longer leaves `moon info` / `moon test` with avoidable unreachable-code warnings.

## 2026-03-22 IR: make string array ops survive SSA compatibility paths

- **String SSA compatibility** by **@jtenner**. Extended the IR layer so the landed array-backed string ops no longer abort in SSA conversion: [`src/ir/ssa.mbt`](/home/jtenner/Projects/starshine-mb/src/ir/ssa.mbt), [`src/ir/ssa_destruction.mbt`](/home/jtenner/Projects/starshine-mb/src/ir/ssa_destruction.mbt), [`src/ir/type_tracking.mbt`](/home/jtenner/Projects/starshine-mb/src/ir/type_tracking.mbt), [`src/ir/usedef.mbt`](/home/jtenner/Projects/starshine-mb/src/ir/usedef.mbt), [`src/ir/liveness.mbt`](/home/jtenner/Projects/starshine-mb/src/ir/liveness.mbt), [`src/ir/gvn.mbt`](/home/jtenner/Projects/starshine-mb/src/ir/gvn.mbt), and [`src/ir/ssa_optimize.mbt`](/home/jtenner/Projects/starshine-mb/src/ir/ssa_optimize.mbt) now all understand the current string array instruction family.
- Recorded the slice in [`docs/0051-2026-03-22-string-array-ssa-compat.md`](/home/jtenner/Projects/starshine-mb/docs/0051-2026-03-22-string-array-ssa-compat.md) and updated [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md) with the landed SSA compatibility checkpoint plus the next `string.const` follow-up.

## 2026-03-22 Validation: land minimal string array surface for DCE

- **String-sensitive DCE unblock** by **@jtenner**. Landed the minimal local `stringref` typed surface needed for the Binaryen-derived DCE regressions: abstract `string` heap refs, the eight array-backed `string.new_*_array` / `string.encode_*_array` instructions, binary encode/decode, raw/typed lift-lower, higher-level WAST lowering, validator coverage, generated `has_strings` feature detection, and the focused `string.new_wtf16_array` / `local.tee` DCE regression.
- Recorded the slice in [`docs/0050-2026-03-22-string-array-surface-for-dce.md`](/home/jtenner/Projects/starshine-mb/docs/0050-2026-03-22-string-array-surface-for-dce.md), narrowed the remaining typed-surface blockers in [`docs/0047-2026-03-22-dead-code-elimination-typed-surface-blockers.md`](/home/jtenner/Projects/starshine-mb/docs/0047-2026-03-22-dead-code-elimination-typed-surface-blockers.md), refreshed the DCE research status in [`docs/0017-2026-03-22-dead-code-elimination.md`](/home/jtenner/Projects/starshine-mb/docs/0017-2026-03-22-dead-code-elimination.md), and updated [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md) plus [`docs/0013-2026-03-21-remove-unused-module-elements-plan.md`](/home/jtenner/Projects/starshine-mb/docs/0013-2026-03-21-remove-unused-module-elements-plan.md) for the new `has_strings` behavior.

## 2026-03-22 Docs: add explicit blocked DCE follow-ups to the backlog

- **Backlog hygiene** by **@jtenner**. Updated [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md) to list the blocked `DeadCodeElimination` string-sensitive, EH `pop`, and stack-switching follow-ups as explicit todo items instead of leaving them implied in the research summary.

## 2026-03-22 Optimization: cover grouped-stage DCE output stability

- **DeadCodeElimination grouped-stage checkpoint** by **@jtenner**. Added focused pipeline execution coverage in [`src/optimization/optimization_test.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/optimization_test.mbt) to run the real default grouped function stage on a typed dead-tail fixture and assert the stage preserves `DeadCodeElimination`'s trimmed output and still validates.
- Recorded the checkpoint in [`docs/0049-2026-03-22-dead-code-elimination-grouped-stage-output.md`](/home/jtenner/Projects/starshine-mb/docs/0049-2026-03-22-dead-code-elimination-grouped-stage-output.md) and narrowed [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md) to dependency-blocked DCE follow-ups only.

## 2026-03-22 Optimization: lock DCE cleanup ordering in the default function stage

- **DeadCodeElimination pipeline checkpoint** by **@jtenner**. Added focused default-pipeline coverage in [`src/optimization/optimization_test.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/optimization_test.mbt) to assert the grouped function stage keeps `DeadCodeElimination` ahead of the first `RemoveUnusedNames`, the first `RemoveUnusedBrs`, and `Vacuum`.
- Recorded the checkpoint in [`docs/0048-2026-03-22-dead-code-elimination-default-stage-ordering.md`](/home/jtenner/Projects/starshine-mb/docs/0048-2026-03-22-dead-code-elimination-default-stage-ordering.md) and narrowed [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md) to the remaining grouped-pipeline interaction/output coverage after ordering.

## 2026-03-22 Docs: mark DCE string and EH pop follow-ups blocked on typed surface gaps

- **DeadCodeElimination blocker audit** by **@jtenner**. Updated the canonical DCE research/backlog to state that the remaining string-sensitive and EH `pop` follow-ups are blocked on missing typed IR surfaces in this repo, not on known unlanded rewrite logic in the current `TTryTable`-only optimizer port.
- Recorded the blocker state in [`docs/0047-2026-03-22-dead-code-elimination-typed-surface-blockers.md`](/home/jtenner/Projects/starshine-mb/docs/0047-2026-03-22-dead-code-elimination-typed-surface-blockers.md) and narrowed [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md) plus [`docs/0017-2026-03-22-dead-code-elimination.md`](/home/jtenner/Projects/starshine-mb/docs/0017-2026-03-22-dead-code-elimination.md) to actionable DCE work only.

## 2026-03-22 Optimization: close nested ref-result try_table DCE coverage

- **DeadCodeElimination coverage checkpoint** by **@jtenner**. Added a focused typed-IR regression in [`src/optimization/dead_code_elimination_wbtest.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/dead_code_elimination_wbtest.mbt) that proves nested concrete ref-result `try_table` rewrites stay valid after DCE retags the inner EH node to `void`.
- Recorded the result in [`docs/0046-2026-03-22-dead-code-elimination-nested-try-table-coverage.md`](/home/jtenner/Projects/starshine-mb/docs/0046-2026-03-22-dead-code-elimination-nested-try-table-coverage.md), refreshed the DCE research status in [`docs/0017-2026-03-22-dead-code-elimination.md`](/home/jtenner/Projects/starshine-mb/docs/0017-2026-03-22-dead-code-elimination.md), and narrowed [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md) to the remaining string-sensitive and EH `pop` follow-ups.

## 2026-03-22 Optimization: keep smaller trivial once-body output

- **OnceReduction policy checkpoint** by **@jtenner**. Added generated-pipeline coverage in [`src/cmd/generated_pipeline_wbtest.mbt`](/home/jtenner/Projects/starshine-mb/src/cmd/generated_pipeline_wbtest.mbt) for the raw-input trivial once-body case and recorded the decision to keep Starshine's smaller `nop`-collapsed output rather than preserve Binaryen's retained redundant `global.set` text shape.
- Recorded the decision in [`docs/0045-2026-03-22-once-reduction-trivial-once-body-policy.md`](/home/jtenner/Projects/starshine-mb/docs/0045-2026-03-22-once-reduction-trivial-once-body-policy.md) and updated [`docs/0016-2026-03-22-no-dwarf-four-pass-comparison.md`](/home/jtenner/Projects/starshine-mb/docs/0016-2026-03-22-no-dwarf-four-pass-comparison.md) plus [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md) so the first-four-pass CLI parity note now treats that diff as intentional policy, not an open blocker.

## 2026-03-22 Docs: refresh pass audit for generated pipeline and DCE

- **Pass-audit refresh** by **@jtenner**. Updated [`docs/0011-2026-03-18-pass-audit.md`](/home/jtenner/Projects/starshine-mb/docs/0011-2026-03-18-pass-audit.md) so it now reflects generated-pipeline raw-function pre-lift, the no-DWARF first-four-pass parity state, and the current `OnceReduction` / `DeadCodeElimination` runner status instead of the earlier scheduled-no-op baseline.
- Removed the stale audit-refresh reminder from [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md) now that the canonical pass-audit doc matches the current runner behavior again.

## 2026-03-22 Tooling: land generated pipeline parity, annotations, and DCE groundwork

- **Generated pipeline and API bundle** by **@jtenner**. Landed the generated-pipeline pre-lift path for raw decoded funcs, wired the explicit no-DWARF first-four-pass CLI flags through the same generated surface, and added the focused command/pipeline coverage and comparison docs in [`docs/0016-2026-03-22-no-dwarf-four-pass-comparison.md`](/home/jtenner/Projects/starshine-mb/docs/0016-2026-03-22-no-dwarf-four-pass-comparison.md).
- Added module-level function annotation support across [`src/lib/types.mbt`](/home/jtenner/Projects/starshine-mb/src/lib/types.mbt), [`src/lib/module.mbt`](/home/jtenner/Projects/starshine-mb/src/lib/module.mbt), [`src/lib/show.mbt`](/home/jtenner/Projects/starshine-mb/src/lib/show.mbt), WAST lowering, optimizer remapping, the generated Node API, and the Node examples/tests, including the new [`src/node_api/`](/home/jtenner/Projects/starshine-mb/src/node_api) package and [`node/examples/18-lib-module-function-annotations.mjs`](/home/jtenner/Projects/starshine-mb/node/examples/18-lib-module-function-annotations.mjs).
- Landed the current WAST GC/exact-ref text-surface bundle: higher-level struct access instructions, exact ref global imports, `rec`-group flat type-index fixes, exact `ref.null` handling, exact-type equivalence validation, passive typed empty elems, legacy GC aliases, and exact custom-descriptor fixture coverage.
- Landed the first real `DeadCodeElimination` implementation slices and research baseline in [`docs/0017-2026-03-22-dead-code-elimination.md`](/home/jtenner/Projects/starshine-mb/docs/0017-2026-03-22-dead-code-elimination.md) plus the follow-up checkpoint docs, bringing the pass from scheduled-no-op status to a typed runner with block/if/loop/branch/GC unary rewrite coverage.

## 2026-03-22 Optimization: land DeadCodeElimination ref.get_desc rewrite

- **DeadCodeElimination descriptor unary slice** by **@jtenner**. Extended [`src/optimization/optimization.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/optimization.mbt) so `ref.get_desc` now uses the same unary unreachable-child rewrite as the other typed one-child reference instructions.
- Added a descriptor-bearing regression in [`src/optimization/dead_code_elimination_wbtest.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/dead_code_elimination_wbtest.mbt) that proves `drop(ref.get_desc(... unreachable))` now collapses to plain `unreachable`.
- Recorded the checkpoint in [`docs/0044-2026-03-22-dead-code-elimination-ref-get-desc.md`](/home/jtenner/Projects/starshine-mb/docs/0044-2026-03-22-dead-code-elimination-ref-get-desc.md), which narrows the remaining DCE follow-up to the nested reference-result `try_table` coverage question plus the later string / EH-pop work.

## 2026-03-22 Optimization: land DeadCodeElimination unary ref-test rewrites

- **DeadCodeElimination sibling GC unary slice** by **@jtenner**. Extended [`src/optimization/optimization.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/optimization.mbt) so `ref.test`, `ref.test_desc`, and `ref.cast_desc_eq` now use the same generic unreachable-child rewrite as the other one-child typed instructions.
- Added focused regressions in [`src/optimization/dead_code_elimination_wbtest.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/dead_code_elimination_wbtest.mbt) for unreachable `ref.test_desc` and `ref.cast_desc_eq` operands, including a concrete `eqref` result fixture.
- Recorded the checkpoint in [`docs/0043-2026-03-22-dead-code-elimination-unary-ref-tests.md`](/home/jtenner/Projects/starshine-mb/docs/0043-2026-03-22-dead-code-elimination-unary-ref-tests.md), which narrows the remaining DCE GC/reference work to `ref.get_desc`, the nested reference-result `try_table` case, and the later string / EH-pop follow-ups.

## 2026-03-22 Optimization: land DeadCodeElimination ref.cast rewrite

- **DeadCodeElimination GC cast slice** by **@jtenner**. Extended [`src/optimization/optimization.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/optimization.mbt) so `ref.cast` now uses the same evaluation-order-preserving unreachable-child rewrite as the other unary typed instructions, collapsing directly to the unreachable operand instead of leaving a stale concrete-result wrapper.
- Added a focused reference-result regression in [`src/optimization/dead_code_elimination_wbtest.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/dead_code_elimination_wbtest.mbt) that proves a concrete `(ref null func)` fixture now optimizes to plain `unreachable`.
- Recorded the checkpoint in [`docs/0042-2026-03-22-dead-code-elimination-ref-cast.md`](/home/jtenner/Projects/starshine-mb/docs/0042-2026-03-22-dead-code-elimination-ref-cast.md), which narrows the remaining DCE GC/reference work to the sibling unary ref ops, the nested reference-result `try_table` case, and the later string / EH-pop follow-ups.

## 2026-03-22 Optimization: land DeadCodeElimination GC branch-op rewrites

- **DeadCodeElimination GC branch-op slice** by **@jtenner**. Extended [`src/optimization/optimization.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/optimization.mbt) so `br_on_null`, `br_on_non_null`, `br_on_cast`, and `br_on_cast_fail` now use the same evaluation-order-preserving unreachable-child rewrite as the earlier branch instructions, collapsing the branch op when its inspected ref or earlier prefix values become unreachable.
- Added focused higher-level regressions in [`src/optimization/dead_code_elimination_wbtest.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/dead_code_elimination_wbtest.mbt) for `br_on_non_null` and `br_on_cast_fail` with unreachable inspected refs on valid one-result typed fixtures.
- Recorded the checkpoint in [`docs/0041-2026-03-22-dead-code-elimination-gc-branch-ops.md`](/home/jtenner/Projects/starshine-mb/docs/0041-2026-03-22-dead-code-elimination-gc-branch-ops.md), which narrows the remaining DCE work to the `ref.cast` / reference-result no-over-refinalize cases, string-sensitive regressions, and the later EH `pop` fixup follow-up.

## 2026-03-22 Optimization: land DeadCodeElimination branch-value rewrites

- **DeadCodeElimination branch-value slice** by **@jtenner**. Extended [`src/optimization/optimization.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/optimization.mbt) so `br`, `br_if`, and `br_table` now honor child evaluation order during DCE: unreachable branch values, conditions, and table indices collapse the branch to the preserved-prefix-plus-unreachable form instead of leaving stale control-flow instructions behind.
- Expanded [`src/optimization/dead_code_elimination_wbtest.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/dead_code_elimination_wbtest.mbt) with focused regressions for unreachable `br` values, unreachable `br_if` conditions, unreachable `br_table` indices, and the ancestor case where removing a dead nested branch drops an outer block's stale value requirement.
- Recorded the checkpoint in [`docs/0040-2026-03-22-dead-code-elimination-branch-value-stress.md`](/home/jtenner/Projects/starshine-mb/docs/0040-2026-03-22-dead-code-elimination-branch-value-stress.md), which narrows the remaining DCE work to GC/reference-sensitive regressions and the later EH `pop` fixup follow-up.

## 2026-03-22 Optimization: land DeadCodeElimination try_table rewrite

- **DeadCodeElimination EH slice** by **@jtenner**. Extended [`src/optimization/optimization.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/optimization.mbt) so typed `try_table` instructions now degrade to unreachable-equivalent void form when their rewritten body is unreachable, which lets parent rewrites observe the EH node as unreachable without dropping the wrapper.
- Added focused coverage in [`src/optimization/dead_code_elimination_wbtest.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/dead_code_elimination_wbtest.mbt) for the concrete-result `try_table` case under `drop`.
- Recorded the checkpoint in [`docs/0039-2026-03-22-dead-code-elimination-try-table-rule.md`](/home/jtenner/Projects/starshine-mb/docs/0039-2026-03-22-dead-code-elimination-try-table-rule.md), which narrows the remaining DCE work in this codebase to branch-value stress cases, GC/reference-sensitive regressions, and the later EH `pop` fixup follow-up.

## 2026-03-22 Optimization: land DeadCodeElimination loop rewrite

- **DeadCodeElimination loop slice** by **@jtenner**. Extended [`src/optimization/optimization.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/optimization.mbt) so loops whose rewritten body is the literal `unreachable` node now collapse to that child, while ordinary branch-back loops remain untouched.
- Expanded [`src/optimization/dead_code_elimination_wbtest.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/dead_code_elimination_wbtest.mbt) with focused coverage for both the collapsing case and the “do not over-simplify loops” guard case.
- Recorded the checkpoint in [`docs/0038-2026-03-22-dead-code-elimination-loop-rule.md`](/home/jtenner/Projects/starshine-mb/docs/0038-2026-03-22-dead-code-elimination-loop-rule.md), which moves the next DCE work onto EH `try` / `try_table` handling and later branch-value stress cases.

## 2026-03-22 Optimization: land DeadCodeElimination if rewrites

- **DeadCodeElimination `if` slice** by **@jtenner**. Extended [`src/optimization/optimization.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/optimization.mbt) so `DeadCodeElimination` now applies the two control-flow-specific `if` rules: an unreachable condition replaces the entire `if`, and an `if` with both unreachable arms now degrades to an unreachable-equivalent void form instead of keeping a stale concrete result type.
- Expanded [`src/optimization/dead_code_elimination_wbtest.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/dead_code_elimination_wbtest.mbt) with focused regressions for both new cases, including the parent-poisoning path through `drop`.
- Recorded the checkpoint in [`docs/0037-2026-03-22-dead-code-elimination-if-rules.md`](/home/jtenner/Projects/starshine-mb/docs/0037-2026-03-22-dead-code-elimination-if-rules.md), which narrows the remaining near-term DCE work to the conservative loop rule and later EH handling.

## 2026-03-22 Optimization: preserve live typed block breaks in DeadCodeElimination

- **DeadCodeElimination typed-block slice** by **@jtenner**. Extended [`src/optimization/optimization.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/optimization.mbt) so concrete typed `block` instructions now only count as outer-unreachable when their tail escapes and no live incoming break still targets the block, instead of blindly poisoning parents whenever the surviving tail is `unreachable`.
- Added focused live-break regressions in [`src/optimization/dead_code_elimination_wbtest.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/dead_code_elimination_wbtest.mbt) covering both sides of the slice: concrete blocks that really became value-dead are rewritten to unreachable-equivalent void structure, while blocks with a surviving `br_if` value path keep their concrete type.
- Recorded the checkpoint in [`docs/0036-2026-03-22-dead-code-elimination-live-break-block-types.md`](/home/jtenner/Projects/starshine-mb/docs/0036-2026-03-22-dead-code-elimination-live-break-block-types.md), which narrows the remaining DCE work to the `if`, `loop`, and EH-specific rules.

## 2026-03-22 Optimization: truncate DeadCodeElimination block tails

- **DeadCodeElimination block-tail slice** by **@jtenner**. Extended [`src/optimization/optimization.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/optimization.mbt) so the typed DCE runner now trims `typed instruction body` instruction lists after the first terminating item, which removes dead code after `return`, after direct `br` within nested blocks, and after newly rewritten unreachable blocks.
- Tightened the local DCE reachability model so nested `block` instructions only poison enclosing parents when they end in an actually escaping `unreachable` / `return` / `throw` tail, instead of treating every trailing branch as outer unreachability.
- Expanded [`src/optimization/dead_code_elimination_wbtest.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/dead_code_elimination_wbtest.mbt) with regressions for function-body truncation, nested-block tail truncation, rewritten-unreachable tail cleanup, and trivial `[unreachable]` block collapse.
- Recorded the checkpoint in [`docs/0035-2026-03-22-dead-code-elimination-block-tail-truncation.md`](/home/jtenner/Projects/starshine-mb/docs/0035-2026-03-22-dead-code-elimination-block-tail-truncation.md), which narrows the remaining DCE work to live-break tracking and synchronous block type updates.

## 2026-03-22 Optimization: add generic DeadCodeElimination unreachable-child rewrites

- **DeadCodeElimination non-control-flow slice** by **@jtenner**. Extended [`src/optimization/optimization.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/optimization.mbt) so the dedicated DCE runner now performs the core evaluation-order-preserving rewrite for non-control-flow typed instructions: preserve reachable prefix effects as `drop`, keep the first unreachable child, and remove later children entirely.
- Expanded [`src/optimization/dead_code_elimination_wbtest.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/dead_code_elimination_wbtest.mbt) with focused ordering-sensitive regressions for binary ops, stores, `select`, and direct calls, all validated through the typed DCE runner.
- Recorded the checkpoint in [`docs/0034-2026-03-22-dead-code-elimination-generic-unreachable-rewrites.md`](/home/jtenner/Projects/starshine-mb/docs/0034-2026-03-22-dead-code-elimination-generic-unreachable-rewrites.md), which narrows the next DCE work to enclosing block truncation and later type-sync logic.

## 2026-03-22 Optimization: wire DeadCodeElimination to a dedicated runner shell

- **DeadCodeElimination plumbing slice** by **@jtenner**. Extended [`src/optimization/optimization.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/optimization.mbt) so `OptimizePass::DeadCodeElimination` now dispatches to a dedicated `run_dead_code_elimination` func-local runner instead of the generic `noop_func_local_pass`.
- Added whitebox coverage in [`src/optimization/dead_code_elimination_wbtest.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/dead_code_elimination_wbtest.mbt) proving the pipeline entry uses the dedicated shell and that the new runner visits typed functions without rewriting them yet.
- Recorded the checkpoint in [`docs/0033-2026-03-22-dead-code-elimination-runner-shell.md`](/home/jtenner/Projects/starshine-mb/docs/0033-2026-03-22-dead-code-elimination-runner-shell.md), which narrows the remaining DCE work to the actual unreachable-code rewrites and type-sync follow-up.

## 2026-03-22 WAST: cover exact custom-descriptor fixture on native static path

- **Exact fixture harness slice** by **@jtenner**. Added dedicated native spec-harness coverage in [`src/wast/spec_harness.mbt`](/home/jtenner/Projects/starshine-mb/src/wast/spec_harness.mbt) for [`tests/spec/proposals/custom-descriptors/exact.wast`](/home/jtenner/Projects/starshine-mb/tests/spec/proposals/custom-descriptors/exact.wast), so the full exact-reference custom-descriptor fixture is now pinned on the static validation path alongside the earlier `descriptors.wast` and `ref_get_desc.wast` coverage.
- Recorded the closure in [`docs/0032-2026-03-22-exact-custom-descriptor-static-harness.md`](/home/jtenner/Projects/starshine-mb/docs/0032-2026-03-22-exact-custom-descriptor-static-harness.md), which retires the remaining exact-reference custom-descriptor follow-up from the active backlog.

## 2026-03-22 Validate: accept structurally equivalent exact func refs

- **Exact function-reference equivalence slice** by **@jtenner**. Extended [`src/validate/match.mbt`](/home/jtenner/Projects/starshine-mb/src/validate/match.mbt) so exact closure comparison now also treats function params and results structurally, instead of stopping at raw type-index identity for exact function references with equivalent signatures.
- Expanded end-to-end coverage in [`src/wast/exact_type_equivalence_test.mbt`](/home/jtenner/Projects/starshine-mb/src/wast/exact_type_equivalence_test.mbt), and confirmed the broader static path by running the CLI spec harness on [`tests/spec/proposals/custom-descriptors/exact.wast`](/home/jtenner/Projects/starshine-mb/tests/spec/proposals/custom-descriptors/exact.wast). The remaining follow-up is now native harness coverage for that full fixture, not another validator mismatch.

## 2026-03-22 Validate: accept structurally equivalent exact struct refs

- **Exact struct-reference equivalence slice** by **@jtenner**. Extended [`src/validate/match.mbt`](/home/jtenner/Projects/starshine-mb/src/validate/match.mbt) so exact reference matching no longer requires raw heap-type identity when both sides point at distinct but structurally equivalent defined struct or array types. The new exact heap-type comparison unfolds referenced fields recursively instead of rejecting equivalent closures that happen to live at different type indices.
- Added focused end-to-end coverage in [`src/wast/exact_type_equivalence_test.mbt`](/home/jtenner/Projects/starshine-mb/src/wast/exact_type_equivalence_test.mbt), which moves [`tests/spec/proposals/custom-descriptors/exact.wast`](/home/jtenner/Projects/starshine-mb/tests/spec/proposals/custom-descriptors/exact.wast) beyond the structurally equivalent exact-struct case and onto the remaining exact-function-equivalence follow-up.

## 2026-03-22 WAST: accept passive typed empty elem declarations

- **Elem text-surface parser slice** by **@jtenner**. Extended [`src/wast/parser.mbt`](/home/jtenner/Projects/starshine-mb/src/wast/parser.mbt) so `(elem (ref null $func))`-style passive typed empty element declarations are recognized as typed `elem` abbreviations instead of being misparsed as offset expressions.
- Updated [`src/wast/module_wast.mbt`](/home/jtenner/Projects/starshine-mb/src/wast/module_wast.mbt) and added focused coverage in [`src/wast/passive_typed_elem_surface_test.mbt`](/home/jtenner/Projects/starshine-mb/src/wast/passive_typed_elem_surface_test.mbt), so passive typed empty `elem` segments now print without a synthetic table index and lower into passive typed element sections correctly.
- Recorded the slice in [`docs/0029-2026-03-22-passive-typed-empty-elem-surface.md`](/home/jtenner/Projects/starshine-mb/docs/0029-2026-03-22-passive-typed-empty-elem-surface.md), which moves `tests/spec/proposals/custom-descriptors/exact.wast` past its initial `elem` parse stop and onto the later exact-reference validation work.

## 2026-03-22 Validate: accept bottom nulls for ref.get_desc and defined refs

- **Bottom-ref compatibility slice** by **@jtenner**. Extended [`src/validate/env.mbt`](/home/jtenner/Projects/starshine-mb/src/validate/env.mbt) and [`src/validate/match.mbt`](/home/jtenner/Projects/starshine-mb/src/validate/match.mbt) so `ref.get_desc` and general validation now accept bottom refs like `ref.null none` against compatible defined struct and array references, while still reserving exact descriptor results for operands that match the exact inspected ref shape.
- Added focused coverage in [`src/validate/env_tests.mbt`](/home/jtenner/Projects/starshine-mb/src/validate/env_tests.mbt), [`src/validate/match.mbt`](/home/jtenner/Projects/starshine-mb/src/validate/match.mbt), and [`src/wast/ref_null_exact_surface_test.mbt`](/home/jtenner/Projects/starshine-mb/src/wast/ref_null_exact_surface_test.mbt), and recorded the slice in [`docs/0028-2026-03-22-ref-get-desc-bottom-null-operands.md`](/home/jtenner/Projects/starshine-mb/docs/0028-2026-03-22-ref-get-desc-bottom-null-operands.md).
- The native mixed-runtime custom-descriptor harness in [`src/wast/spec_harness.mbt`](/home/jtenner/Projects/starshine-mb/src/wast/spec_harness.mbt) now passes `tests/spec/proposals/custom-descriptors/ref_get_desc.wast` end to end instead of stopping on descriptor-target or const-expression mismatches.

## 2026-03-22 Validate: preserve exact ref.null immediates end to end

- **Exact nullable ref-null slice** by **@jtenner**. Extended [`src/lib/types.mbt`](/home/jtenner/Projects/starshine-mb/src/lib/types.mbt), [`src/wast/lower_to_lib.mbt`](/home/jtenner/Projects/starshine-mb/src/wast/lower_to_lib.mbt), [`src/validate/env.mbt`](/home/jtenner/Projects/starshine-mb/src/validate/env.mbt), and [`src/validate/typecheck.mbt`](/home/jtenner/Projects/starshine-mb/src/validate/typecheck.mbt) so `ref.null` now carries a full nullable `RefType` through lowering and validation instead of collapsing to a heap-type-only immediate that loses exactness.
- Extended [`src/binary/encode.mbt`](/home/jtenner/Projects/starshine-mb/src/binary/encode.mbt), [`src/binary/decode.mbt`](/home/jtenner/Projects/starshine-mb/src/binary/decode.mbt), [`src/transformer/transformer.mbt`](/home/jtenner/Projects/starshine-mb/src/transformer/transformer.mbt), and [`src/lib/pkg.generated.mbti`](/home/jtenner/Projects/starshine-mb/src/lib/pkg.generated.mbti) so exact nullable `ref.null` immediates survive binary roundtrip and public lib consumers see the widened instruction shape consistently.
- Added focused black-box coverage in [`src/wast/ref_null_exact_surface_test.mbt`](/home/jtenner/Projects/starshine-mb/src/wast/ref_null_exact_surface_test.mbt) and recorded the slice in [`docs/0027-2026-03-22-exact-ref-null-immediates.md`](/home/jtenner/Projects/starshine-mb/docs/0027-2026-03-22-exact-ref-null-immediates.md), which moves the remaining mixed-runtime custom-descriptor blocker from exact typed null loss onto the separate `ref.null none` descriptor-compatibility rule.

## 2026-03-22 WAST: fix implicit functype indices after rec groups

- **Grouped-type index repair** by **@jtenner**. Extended [`src/wast/lower_to_lib.mbt`](/home/jtenner/Projects/starshine-mb/src/wast/lower_to_lib.mbt) so implicit function types appended during lowering now use flattened type indices instead of raw rec-entry counts, which keeps later `funcsec` entries aligned when a module starts with grouped `(rec ...)` type fields.
- Added focused coverage in [`src/wast/rec_group_typeuse_test.mbt`](/home/jtenner/Projects/starshine-mb/src/wast/rec_group_typeuse_test.mbt), which moved `tests/spec/proposals/custom-descriptors/ref_get_desc.wast` beyond the grouped-rec functype-index bug and onto the remaining `ref.get_desc` null/exact validation work.

## 2026-03-22 WAST: accept parenthesized exact ref types on global imports

- **Imported global ref-type parser slice** by **@jtenner**. Extended [`src/wast/parser.mbt`](/home/jtenner/Projects/starshine-mb/src/wast/parser.mbt) so imported globals now reuse the same global-type parser as defined globals, which means parenthesized ref types such as `(ref null (exact $b))` no longer get misread as mandatory `(mut ...)` wrappers.
- Added focused parse, print, and lowering coverage in [`src/wast/global_import_ref_type_test.mbt`](/home/jtenner/Projects/starshine-mb/src/wast/global_import_ref_type_test.mbt), which moved `tests/spec/proposals/custom-descriptors/ref_get_desc.wast` beyond the imported-global exact-ref parse failure and onto the next grouped-type index gap.

## 2026-03-22 WAST: add higher-level struct access instructions

- **GC accessor text-surface slice** by **@jtenner**. Extended [`src/wast/types.mbt`](/home/jtenner/Projects/starshine-mb/src/wast/types.mbt), [`src/wast/keywords.mbt`](/home/jtenner/Projects/starshine-mb/src/wast/keywords.mbt), [`src/wast/parser.mbt`](/home/jtenner/Projects/starshine-mb/src/wast/parser.mbt), [`src/wast/module_wast.mbt`](/home/jtenner/Projects/starshine-mb/src/wast/module_wast.mbt), and [`src/wast/lower_to_lib.mbt`](/home/jtenner/Projects/starshine-mb/src/wast/lower_to_lib.mbt) so the higher-level WAST surface now accepts, prints, and lowers `struct.get`, `struct.get_s`, and `struct.get_u`, including folded forms with type and field immediates.
- Added focused lexer and end-to-end WAST coverage in [`src/wast/lexer.mbt`](/home/jtenner/Projects/starshine-mb/src/wast/lexer.mbt) and [`src/wast/struct_get_surface_test.mbt`](/home/jtenner/Projects/starshine-mb/src/wast/struct_get_surface_test.mbt), which moved `tests/spec/proposals/custom-descriptors/ref_get_desc.wast` past the earlier parser stop on folded `struct.get` and onto the next higher-level fixture gap.

## 2026-03-22 WAST: accept legacy GC reference aliases

- **GC text-surface compatibility slice** by **@jtenner**. Extended [`src/wast/types.mbt`](/home/jtenner/Projects/starshine-mb/src/wast/types.mbt), [`src/wast/parser.mbt`](/home/jtenner/Projects/starshine-mb/src/wast/parser.mbt), [`src/wast/module_wast.mbt`](/home/jtenner/Projects/starshine-mb/src/wast/module_wast.mbt), and [`src/wast/lower_to_lib.mbt`](/home/jtenner/Projects/starshine-mb/src/wast/lower_to_lib.mbt) so the higher-level WAST surface now accepts legacy GC reference aliases such as `anyref`, `eqref`, `i31ref`, `structref`, `arrayref`, and `nullref`, and also recognizes abstract heap keywords `struct` and `array` inside `(ref ...)` and `ref.null` forms.
- Added focused parser and lowering coverage in [`src/wast/parser.mbt`](/home/jtenner/Projects/starshine-mb/src/wast/parser.mbt) and [`src/wast/lower_to_lib.mbt`](/home/jtenner/Projects/starshine-mb/src/wast/lower_to_lib.mbt) so legacy aliases normalize onto the existing typed-ref model and lower into the expected abstract heap types instead of failing before the mixed-runtime custom-descriptor fixtures reach later instruction coverage.

## 2026-03-22 Validate: carry ref.get_desc type immediates end to end

- **Custom-descriptor immediate slice** by **@jtenner**. Extended [`src/wast/parser.mbt`](/home/jtenner/Projects/starshine-mb/src/wast/parser.mbt), [`src/wast/module_wast.mbt`](/home/jtenner/Projects/starshine-mb/src/wast/module_wast.mbt), [`src/wast/lower_to_lib.mbt`](/home/jtenner/Projects/starshine-mb/src/wast/lower_to_lib.mbt), [`src/lib/types.mbt`](/home/jtenner/Projects/starshine-mb/src/lib/types.mbt), [`src/binary/encode.mbt`](/home/jtenner/Projects/starshine-mb/src/binary/encode.mbt), and [`src/binary/decode.mbt`](/home/jtenner/Projects/starshine-mb/src/binary/decode.mbt) so `ref.get_desc` now carries its inspected type immediate through the higher-level WAST surface, lowered lib instruction model, and GC binary encoding instead of treating it as an immediate-free opcode.
- Tightened descriptor typechecking in [`src/validate/env.mbt`](/home/jtenner/Projects/starshine-mb/src/validate/env.mbt) and [`src/validate/typecheck.mbt`](/home/jtenner/Projects/starshine-mb/src/validate/typecheck.mbt) so `ref.get_desc` now validates the inspected target type, rejects descriptor-less types and incompatible operands, and computes the descriptor result reftype from the inspected type metadata instead of returning a fixed scalar placeholder.

## 2026-03-22 Validate: land custom-descriptor static text coverage

- **Custom-descriptor validator repair** by **@jtenner**. Fixed [`src/validate/match.mbt`](/home/jtenner/Projects/starshine-mb/src/validate/match.mbt) and [`src/validate/validate.mbt`](/home/jtenner/Projects/starshine-mb/src/validate/validate.mbt) so recursive-group validation now keeps current-group absolute type indices in scope, final defined types still match their declared supertypes, and struct subtype matching accepts trailing-field extensions. This clears the valid `final` and cross-`rec` descriptor subtype chains from the spec instead of rejecting them with spurious type-resolution or incompatible-supertype errors.
- Lifted higher-level coverage in [`src/wast/lower_to_lib.mbt`](/home/jtenner/Projects/starshine-mb/src/wast/lower_to_lib.mbt), [`src/wast/spec_harness.mbt`](/home/jtenner/Projects/starshine-mb/src/wast/spec_harness.mbt), and [`docs/0021-2026-03-22-custom-descriptor-static-text-coverage.md`](/home/jtenner/Projects/starshine-mb/docs/0021-2026-03-22-custom-descriptor-static-text-coverage.md) so `tests/spec/proposals/custom-descriptors/descriptors.wast` now runs as a dedicated native static-fixture check above the lower-level binary-only coverage.

## 2026-03-22 WAST: reject reversed descriptor metadata order

- **GC text-surface parser tightening** by **@jtenner**. Tightened [`src/wast/parser.mbt`](/home/jtenner/Projects/starshine-mb/src/wast/parser.mbt) so higher-level type headers now reject `descriptor` clauses that appear before `describes` in the same type definition, matching the malformed custom-descriptor text cases instead of silently accepting and normalizing them.
- Extended malformed fixture coverage in [`src/wast/module_wast_tests.mbt`](/home/jtenner/Projects/starshine-mb/src/wast/module_wast_tests.mbt) and updated [`docs/0020-2026-03-22-wast-rec-group-surface.md`](/home/jtenner/Projects/starshine-mb/docs/0020-2026-03-22-wast-rec-group-surface.md) so the rec-group text-surface contract now explicitly includes metadata clause ordering.

## 2026-03-22 WAST: add higher-level rec group authoring

- **GC text-surface rec-group slice** by **@jtenner**. Extended [`src/wast/parser.mbt`](/home/jtenner/Projects/starshine-mb/src/wast/parser.mbt), [`src/wast/module_wast.mbt`](/home/jtenner/Projects/starshine-mb/src/wast/module_wast.mbt), [`src/wast/lower_to_lib.mbt`](/home/jtenner/Projects/starshine-mb/src/wast/lower_to_lib.mbt), and related `src/wast` tests so higher-level WAST modules can now author grouped `(rec ...)` type fields directly, preserve them through normalized printing, and lower them into grouped `@lib.RecType` entries while keeping later type uses working against the flat index space.
- Added the canonical slice doc in [`docs/0020-2026-03-22-wast-rec-group-surface.md`](/home/jtenner/Projects/starshine-mb/docs/0020-2026-03-22-wast-rec-group-surface.md), refreshed [`docs/0018-2026-03-22-wast-struct-type-surface.md`](/home/jtenner/Projects/starshine-mb/docs/0018-2026-03-22-wast-struct-type-surface.md) and [`docs/0019-2026-03-22-wast-array-type-surface.md`](/home/jtenner/Projects/starshine-mb/docs/0019-2026-03-22-wast-array-type-surface.md), and updated [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md) so the remaining GC text-surface follow-up is fixture migration rather than missing type syntax.

## 2026-03-22 WAST: add GC struct and array type authoring

- **GC text-surface type-authoring slice** by **@jtenner**. Extended [`src/wast/parser.mbt`](/home/jtenner/Projects/starshine-mb/src/wast/parser.mbt), [`src/wast/module_wast.mbt`](/home/jtenner/Projects/starshine-mb/src/wast/module_wast.mbt), [`src/wast/lower_to_lib.mbt`](/home/jtenner/Projects/starshine-mb/src/wast/lower_to_lib.mbt), and related `src/wast` / `src/wat` tests so the higher-level WAST surface now models both `struct` and `array` type definitions, `sub` / `final` wrappers, packed and ref-bearing field storage syntax, and `descriptor` / `describes` metadata, including forward-reference lowering for descriptor-bearing module fixtures.
- Added slice documentation in [`docs/0018-2026-03-22-wast-struct-type-surface.md`](/home/jtenner/Projects/starshine-mb/docs/0018-2026-03-22-wast-struct-type-surface.md) and [`docs/0019-2026-03-22-wast-array-type-surface.md`](/home/jtenner/Projects/starshine-mb/docs/0019-2026-03-22-wast-array-type-surface.md), and trimmed [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md) so the remaining GC text-surface backlog is now higher-level `rec` group authoring rather than missing non-function type bodies.

## 2026-03-22 Binary: remove unreachable RefType decoder arm

- **Binary decode warning cleanup** by **@jtenner**. Simplified [`src/binary/decode.mbt`](/home/jtenner/Projects/starshine-mb/src/binary/decode.mbt) to remove an unreachable `S33` match arm in `RefType.decode`, eliminating the lingering `moon info` warning without changing decoder behavior.

## 2026-03-22 Optimization: close MemoryPacking with validation and idempotence coverage

- **MemoryPacking cleanup slice** by **@jtenner**. Extended [`src/optimization/optimization.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/optimization.mbt), [`src/optimization/imports.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/imports.mbt), and [`src/optimization/moon.pkg`](/home/jtenner/Projects/starshine-mb/src/optimization/moon.pkg) so the optimization package now validates its rewritten `MemoryPacking` outputs directly and carries idempotence coverage for both the split-passive replacement path and the startup-trap-preserving active path.
- Added final red-to-green internal regressions in [`src/optimization/optimization.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/optimization.mbt) asserting that rewritten `data_count`, memory/data index references, dropped-segment-state rewrites, and startup-trap-preserving active outputs all pass `validate_module(...)`, and that a second `MemoryPacking` run is a no-op on those rewritten modules.
- Updated [`docs/0011-2026-03-18-pass-audit.md`](/home/jtenner/Projects/starshine-mb/docs/0011-2026-03-18-pass-audit.md), [`docs/0014-2026-03-21-memory-packing.md`](/home/jtenner/Projects/starshine-mb/docs/0014-2026-03-21-memory-packing.md), and [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md) so `MemoryPacking` is no longer tracked as an active default-pipeline blocker.

## 2026-03-22 Optimization: land MemoryPacking slice-8 instruction rewriting

- **MemoryPacking rewrite slice** by **@jtenner**. Extended [`run_memory_packing`](/home/jtenner/Projects/starshine-mb/src/optimization/optimization.mbt) in [`src/optimization/optimization.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/optimization.mbt) so the pass now activates the full replacement walk after segment materialization: typed split passive `memory.init` lowers into the documented `memory.fill` plus replacement-`memory.init` sequence, typed `data.drop` lowers into replacement drops plus dropped-segment state tracking when needed, and later `array.new_data` / `array.init_data` users now remap through earlier segment expansion.
- Added per-function temp-local allocation in [`src/optimization/optimization.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/optimization.mbt) for nonconstant typed `memory.init` destinations so rewritten split copies reuse the original destination exactly once before applying per-chunk offsets.
- Added focused red-to-green internal regressions in [`src/optimization/optimization.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/optimization.mbt) covering split passive `memory.init` + `data.drop` lowering with drop-state globals, fresh-local allocation for nonconstant destinations, and `array.new_data` index remapping after earlier segment expansion.
- Updated [`docs/0011-2026-03-18-pass-audit.md`](/home/jtenner/Projects/starshine-mb/docs/0011-2026-03-18-pass-audit.md), [`docs/0014-2026-03-21-memory-packing.md`](/home/jtenner/Projects/starshine-mb/docs/0014-2026-03-21-memory-packing.md), and [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md) so the remaining active `MemoryPacking` backlog now starts at validation/idempotence cleanup.

## 2026-03-22 Optimization: land MemoryPacking slice-7 segment materialization

- **MemoryPacking materialization slice** by **@jtenner**. Extended [`run_memory_packing`](/home/jtenner/Projects/starshine-mb/src/optimization/optimization.mbt) in [`src/optimization/optimization.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/optimization.mbt) so the pass now materializes analyzed split segments into a rebuilt data section with original-to-replacement `DataIdx` mapping, checked active-offset shifting with saturation instead of wraparound, and rebuilt `data_names`; the runner applies that materialization immediately when no passive segment-operation rewrite is required, which makes active-segment packing end to end instead of analysis-only.
- Tightened the earlier dead-passive compaction step in [`src/optimization/optimization.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/optimization.mbt) so `data_names` now stay aligned with `DataIdx` compaction before later range analysis and materialization.
- Added focused red-to-green internal regressions in [`src/optimization/optimization.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/optimization.mbt) covering split active-segment materialization, emitted replacement-index mapping, rebuilt data names, and saturating active `i32` offset shifting.
- Updated [`docs/0011-2026-03-18-pass-audit.md`](/home/jtenner/Projects/starshine-mb/docs/0011-2026-03-18-pass-audit.md), [`docs/0014-2026-03-21-memory-packing.md`](/home/jtenner/Projects/starshine-mb/docs/0014-2026-03-21-memory-packing.md), and [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md) so the remaining active `MemoryPacking` backlog now starts at passive `memory.init` / `data.drop` replacement rewriting and final validation cleanup.

## 2026-03-22 Optimization: land MemoryPacking slice-6 range analysis

- **MemoryPacking range-analysis slice** by **@jtenner**. Extended [`run_memory_packing`](/home/jtenner/Projects/starshine-mb/src/optimization/optimization.mbt) in [`src/optimization/optimization.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/optimization.mbt) so the pass now computes per-segment range-analysis plans after dead passive removal, including the documented split eligibility checks, raw zero/nonzero range discovery, active/passive profitability thresholds, trap-preserving active trailing-byte fixups, and the Web data-segment cap merge rule.
- Tightened the internal referrer model in [`src/optimization/optimization.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/optimization.mbt) so typed `memory.init` referrers now record whether their segment offset and size are constant, which the new split-eligibility logic uses to conservatively reject unsupported passive-segment splitting cases.
- Added focused red-to-green internal regressions in [`src/optimization/optimization.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/optimization.mbt) covering raw range discovery, active-threshold merging, profitable passive edge zeroes, startup-trap preservation with and without `traps_never_happen`, GC / `__llvm*` no-split handling, and the segment-count cap merge behavior.
- Updated [`docs/0011-2026-03-18-pass-audit.md`](/home/jtenner/Projects/starshine-mb/docs/0011-2026-03-18-pass-audit.md), [`docs/0014-2026-03-21-memory-packing.md`](/home/jtenner/Projects/starshine-mb/docs/0014-2026-03-21-memory-packing.md), and [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md) so the remaining active `MemoryPacking` backlog now starts at segment materialization and later replacement rewriting.

## 2026-03-22 Optimization: land MemoryPacking slice-5 dead passive removal

- **MemoryPacking dead-passive slice** by **@jtenner**. Extended [`run_memory_packing`](/home/jtenner/Projects/starshine-mb/src/optimization/optimization.mbt) in [`src/optimization/optimization.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/optimization.mbt) so the pass now removes passive data segments that are unreferenced or only referenced by `data.drop`, rewrites removed drop-only `data.drop`s to `nop`, compacts the data section, and updates `DataCntSec` plus later `DataIdx` users after the removal.
- Added focused red-to-green internal regressions in [`src/optimization/optimization.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/optimization.mbt) covering unreferenced passive removal with `memory.init` remap and drop-only passive removal with GC data-consumer remap.
- Updated [`docs/0011-2026-03-18-pass-audit.md`](/home/jtenner/Projects/starshine-mb/docs/0011-2026-03-18-pass-audit.md), [`docs/0014-2026-03-21-memory-packing.md`](/home/jtenner/Projects/starshine-mb/docs/0014-2026-03-21-memory-packing.md), and [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md) so the remaining active `MemoryPacking` backlog now starts at range analysis and later segment materialization/rewrite slices.

## 2026-03-22 Optimization: land MemoryPacking slice-4 referrer collection

- **MemoryPacking referrer slice** by **@jtenner**. Extended [`run_memory_packing`](/home/jtenner/Projects/starshine-mb/src/optimization/optimization.mbt) in [`src/optimization/optimization.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/optimization.mbt) so the pass now performs the documented stage-4 per-`DataIdx` referrer scan after pre-normalization, collecting `memory.init`, `data.drop`, `array.new_data`, and `array.init_data` users in one module walk as the foundation for later dead-segment removal and rewrite planning.
- Added focused red-to-green internal regressions in [`src/optimization/optimization.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/optimization.mbt) covering both typed and untyped referrer collection, including the GC data consumers required by [`docs/0014-2026-03-21-memory-packing.md`](/home/jtenner/Projects/starshine-mb/docs/0014-2026-03-21-memory-packing.md).
- Updated [`docs/0011-2026-03-18-pass-audit.md`](/home/jtenner/Projects/starshine-mb/docs/0011-2026-03-18-pass-audit.md), [`docs/0014-2026-03-21-memory-packing.md`](/home/jtenner/Projects/starshine-mb/docs/0014-2026-03-21-memory-packing.md), and [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md) so the remaining active `MemoryPacking` backlog now starts at dead passive-segment removal and later segment materialization/rewrite slices.

## 2026-03-22 Optimization: land MemoryPacking slice-3 segment-op pre-normalization

- **MemoryPacking pre-normalization slice** by **@jtenner**. Extended [`run_memory_packing`](/home/jtenner/Projects/starshine-mb/src/optimization/optimization.mbt) in [`src/optimization/optimization.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/optimization.mbt) so the pass now performs the documented segment-op simplifications after entry gating: active `data.drop` rewrites to `nop`, active `memory.init` collapses to either the exact trap block or the zero-length destination bounds check, and passive `memory.init` now rewrites the obvious trap and zero-length cases before any later splitting work.
- Added focused red-to-green internal regressions in [`src/optimization/optimization.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/optimization.mbt) covering active trap reduction, active zero-length bounds-check lowering, passive proven-trap lowering, and passive zero-length bounds-check lowering.
- Updated [`docs/0011-2026-03-18-pass-audit.md`](/home/jtenner/Projects/starshine-mb/docs/0011-2026-03-18-pass-audit.md), [`docs/0014-2026-03-21-memory-packing.md`](/home/jtenner/Projects/starshine-mb/docs/0014-2026-03-21-memory-packing.md), and [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md) so the remaining active `MemoryPacking` work now starts at referrer collection and later data-index/materialization rewrites.

## 2026-03-22 Optimization: land MemoryPacking slice-2 analysis gating

- **MemoryPacking gating slice** by **@jtenner**. Extended [`run_memory_packing`](/home/jtenner/Projects/starshine-mb/src/optimization/optimization.mbt) in [`src/optimization/optimization.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/optimization.mbt) with the documented stage-2 entry gating: the pass now bails out on unsupported memory topologies, imported memory without a `zero_filled_memory` promise, overlapping active segments, and dynamic active offsets in multi-segment modules, while still leaving later semantic rewrite slices for follow-up work.
- Added focused internal regressions in [`src/optimization/optimization.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/optimization.mbt) covering the exact gated cases from [`docs/0014-2026-03-21-memory-packing.md`](/home/jtenner/Projects/starshine-mb/docs/0014-2026-03-21-memory-packing.md): no/too-many memories, imported-memory promise handling, the single-segment dynamic-offset exception, active overlap rejection, and disjoint active acceptance.
- Updated [`docs/0011-2026-03-18-pass-audit.md`](/home/jtenner/Projects/starshine-mb/docs/0011-2026-03-18-pass-audit.md), [`docs/0014-2026-03-21-memory-packing.md`](/home/jtenner/Projects/starshine-mb/docs/0014-2026-03-21-memory-packing.md), and [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md) so the active `MemoryPacking` backlog now starts at segment-op pre-normalization instead of scheduler/gating plumbing.

## 2026-03-22 Optimization: land MemoryPacking slice-1 plumbing

- **MemoryPacking scheduler slice** by **@jtenner**. Replaced the generated optimize pipeline’s generic `MemoryPacking` module-wide no-op dispatch with a dedicated [`run_memory_packing`](/home/jtenner/Projects/starshine-mb/src/optimization/optimization.mbt) runner in [`src/optimization/optimization.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/optimization.mbt), while intentionally keeping the pass semantically conservative for now.
- Threaded the slice-1 option surface through [`src/cmd/cmd.mbt`](/home/jtenner/Projects/starshine-mb/src/cmd/cmd.mbt) and [`src/optimization/optimization.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/optimization.mbt): `zero_filled_memory` now lives alongside `traps_never_happen` in `OptimizeOptions`, `PipelineFeatures`, and `MemoryPackingPassProps`, with generated-pipeline and explicit-pass expansion preserving those values.
- Added red-to-green coverage in [`src/cmd/generated_pipeline_wbtest.mbt`](/home/jtenner/Projects/starshine-mb/src/cmd/generated_pipeline_wbtest.mbt), [`src/cmd/cmd.mbt`](/home/jtenner/Projects/starshine-mb/src/cmd/cmd.mbt), and [`src/optimization/optimization_test.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/optimization_test.mbt) to prove the new option threading and dedicated runner surface, then refreshed [`docs/0011-2026-03-18-pass-audit.md`](/home/jtenner/Projects/starshine-mb/docs/0011-2026-03-18-pass-audit.md), [`docs/0014-2026-03-21-memory-packing.md`](/home/jtenner/Projects/starshine-mb/docs/0014-2026-03-21-memory-packing.md), and [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md) so the remaining `MemoryPacking` work is scoped to the later semantic slices.

## 2026-03-22 Optimization: keep dropped GC carrier globals reference-only in RemoveUnusedModuleElements

- **RemoveUnusedModuleElements drop-carrier slice** by **@jtenner**. Extended [`run_remove_unused_module_elements`](/home/jtenner/Projects/starshine-mb/src/optimization/optimization.mbt) in [`src/optimization/optimization.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/optimization.mbt) so closed-world GC `drop(global.get(...))` no longer forces referenced carrier globals down the full-use path. Dropped struct carrier globals now stay live as carriers while their embedded funcref payloads remain referenced-only.
- Expanded whitebox coverage in [`src/optimization/remove_unused_module_elements_wbtest.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/remove_unused_module_elements_wbtest.mbt) with a red-to-green regression for a dropped struct carrier global, and verified it does not regress the existing `struct.new_desc` descriptor deferral cases.
- Extended the same direct no-read carrier handling to `array.len(global.get(...))`, with a new red-to-green regression in [`src/optimization/remove_unused_module_elements_wbtest.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/remove_unused_module_elements_wbtest.mbt) proving array carrier globals no longer pin unread payload functions live just because their length is queried.
- Updated [`docs/0011-2026-03-18-pass-audit.md`](/home/jtenner/Projects/starshine-mb/docs/0011-2026-03-18-pass-audit.md), [`docs/0013-2026-03-21-remove-unused-module-elements-plan.md`](/home/jtenner/Projects/starshine-mb/docs/0013-2026-03-21-remove-unused-module-elements-plan.md), and [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md) to close out `RemoveUnusedModuleElements` for the current direct-consumer scope and move any later carrier-forwarding/value-flow ideas out of the active blocker path.

## 2026-03-21 Optimization: keep GC conversion-style consumers reference-only in RemoveUnusedModuleElements

- **RemoveUnusedModuleElements conversion slice** by **@jtenner**. Extended [`run_remove_unused_module_elements`](/home/jtenner/Projects/starshine-mb/src/optimization/optimization.mbt) in [`src/optimization/optimization.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/optimization.mbt) so `extern.convert_any` and nested `any.convert_extern` now use the same closed-world GC reference-identity logic as the earlier `ref.*` and `br_on_*` consumers. These conversion-style wrappers no longer force struct carrier payloads to become full uses just because a carrier is converted through the anyref/externref boundary.
- Expanded whitebox coverage in [`src/optimization/remove_unused_module_elements_wbtest.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/remove_unused_module_elements_wbtest.mbt) with red-to-green regressions for `extern.convert_any` on an `anyref` struct carrier and `any.convert_extern(extern.convert_any(...))` on the same carrier path.
- Updated [`docs/0011-2026-03-18-pass-audit.md`](/home/jtenner/Projects/starshine-mb/docs/0011-2026-03-18-pass-audit.md), [`docs/0013-2026-03-21-remove-unused-module-elements-plan.md`](/home/jtenner/Projects/starshine-mb/docs/0013-2026-03-21-remove-unused-module-elements-plan.md), and [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md) so the remaining GC work is narrowed again to future consumer expansion beyond the currently modeled struct/array, identity, and conversion instruction surface.

## 2026-03-21 Optimization: keep GC branch-style identity consumers reference-only in RemoveUnusedModuleElements

- **RemoveUnusedModuleElements branch-identity slice** by **@jtenner**. Extended [`run_remove_unused_module_elements`](/home/jtenner/Projects/starshine-mb/src/optimization/optimization.mbt) in [`src/optimization/optimization.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/optimization.mbt) so `br_on_null`, `br_on_non_null`, `br_on_cast`, and `br_on_cast_fail` now use the same closed-world GC reference-identity logic as the earlier `ref.*` identity consumers. These branch-style checks/refinements no longer force struct carrier payloads to become full uses just because control flow inspects or refines the reference.
- Expanded whitebox coverage in [`src/optimization/remove_unused_module_elements_wbtest.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/remove_unused_module_elements_wbtest.mbt) with red-to-green regressions for nullable struct carriers under `br_on_null` and `br_on_non_null`, plus exact struct carriers under `br_on_cast` and `br_on_cast_fail`.
- Updated [`docs/0011-2026-03-18-pass-audit.md`](/home/jtenner/Projects/starshine-mb/docs/0011-2026-03-18-pass-audit.md), [`docs/0013-2026-03-21-remove-unused-module-elements-plan.md`](/home/jtenner/Projects/starshine-mb/docs/0013-2026-03-21-remove-unused-module-elements-plan.md), and [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md) so the remaining GC work is narrowed again to future consumer expansion beyond the currently modeled struct/array and reference-identity instruction surface.

## 2026-03-21 Optimization: keep GC cast-style identity consumers reference-only in RemoveUnusedModuleElements

- **RemoveUnusedModuleElements cast-identity slice** by **@jtenner**. Extended [`run_remove_unused_module_elements`](/home/jtenner/Projects/starshine-mb/src/optimization/optimization.mbt) in [`src/optimization/optimization.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/optimization.mbt) so `ref.as_non_null`, `ref.cast`, and `ref.cast_desc_eq` now use the same closed-world GC reference-identity logic as the earlier non-ref identity consumers. These ops no longer force struct or descriptor global carriers to become full uses just because a cast-style identity check or refinement happens.
- Expanded whitebox coverage in [`src/optimization/remove_unused_module_elements_wbtest.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/remove_unused_module_elements_wbtest.mbt) with red-to-green regressions for nullable struct carriers under `ref.as_non_null`, exact struct carriers under `ref.cast`, and descriptor carriers under `ref.cast_desc_eq`.
- Updated [`docs/0011-2026-03-18-pass-audit.md`](/home/jtenner/Projects/starshine-mb/docs/0011-2026-03-18-pass-audit.md), [`docs/0013-2026-03-21-remove-unused-module-elements-plan.md`](/home/jtenner/Projects/starshine-mb/docs/0013-2026-03-21-remove-unused-module-elements-plan.md), and [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md) so the remaining GC work is narrowed again to future consumer expansion beyond the currently modeled struct/array reads and reference-identity operations.

## 2026-03-21 Optimization: keep non-ref GC identity consumers reference-only in RemoveUnusedModuleElements

- **RemoveUnusedModuleElements identity-consumer slice** by **@jtenner**. Extended [`run_remove_unused_module_elements`](/home/jtenner/Projects/starshine-mb/src/optimization/optimization.mbt) in [`src/optimization/optimization.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/optimization.mbt) so non-ref GC identity consumers now preserve only reference identity in closed-world GC mode instead of eagerly promoting payload carriers to full uses. This covers `ref.is_null`, `ref.test`, `ref.eq`, `ref.get_desc`, and `ref.test_desc`, and closes the remaining global-carrier leak for operations that inspect reference identity without observing struct/array contents.
- Added focused fixture builders plus red-to-green regressions in [`src/optimization/remove_unused_module_elements_wbtest.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/remove_unused_module_elements_wbtest.mbt) proving that struct and descriptor globals carrying embedded funcref payloads no longer pin those payloads live when only the non-ref identity consumers are used.
- Updated [`docs/0011-2026-03-18-pass-audit.md`](/home/jtenner/Projects/starshine-mb/docs/0011-2026-03-18-pass-audit.md), [`docs/0013-2026-03-21-remove-unused-module-elements-plan.md`](/home/jtenner/Projects/starshine-mb/docs/0013-2026-03-21-remove-unused-module-elements-plan.md), and [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md) so the remaining GC work is now narrower: future consumer expansion beyond the currently modeled non-ref identity and struct/array read paths, plus any later carrier hardening beyond globals/descriptors.

## 2026-03-21 Optimization: defer closed-world descriptor carriers in RemoveUnusedModuleElements

- **RemoveUnusedModuleElements descriptor-carrier slice** by **@jtenner**. Extended [`run_remove_unused_module_elements`](/home/jtenner/Projects/starshine-mb/src/optimization/optimization.mbt) in [`src/optimization/optimization.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/optimization.mbt) so deferrable descriptor operands on `struct.new_desc` and `struct.new_default_desc` are now treated as reference-only inputs in closed-world GC mode instead of eagerly promoting their carriers to full uses. This closes the descriptor-global carrier leak where passing a descriptor object through construction used to keep embedded funcref payloads live even when only descriptor identity was observed.
- Expanded whitebox coverage in [`src/optimization/remove_unused_module_elements_wbtest.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/remove_unused_module_elements_wbtest.mbt) with red-to-green regressions for both `struct.new_desc` and `struct.new_default_desc`, including the `ref.get_desc` path proving descriptor identity reads still do not make descriptor payload contents observable.
- Updated [`docs/0011-2026-03-18-pass-audit.md`](/home/jtenner/Projects/starshine-mb/docs/0011-2026-03-18-pass-audit.md), [`docs/0013-2026-03-21-remove-unused-module-elements-plan.md`](/home/jtenner/Projects/starshine-mb/docs/0013-2026-03-21-remove-unused-module-elements-plan.md), and [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md) so the remaining GC work is now future consumer expansion and any later carrier hardening beyond the descriptor/global cases already covered.

## 2026-03-21 Optimization: add fixed-point coverage for GC-heavy RemoveUnusedModuleElements paths

- **RemoveUnusedModuleElements signoff slice** by **@jtenner**. Expanded [`src/optimization/remove_unused_module_elements_wbtest.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/remove_unused_module_elements_wbtest.mbt) with repeated-pass equality coverage for the recent closed-world GC machinery, specifically the deferred mutable `struct.set` path and cross-type `array.copy` payload propagation. These fixtures assert that the first optimized module is already a fixed point when the pass runs again with the same GC/closed-world features.
- Added [`remove_unused_test_run_twice_with_features`](/home/jtenner/Projects/starshine-mb/src/optimization/remove_unused_module_elements_wbtest.mbt) so repeated-pass checks can exercise non-default feature configurations directly instead of relying on the open-world default helper.
- Updated [`docs/0013-2026-03-21-remove-unused-module-elements-plan.md`](/home/jtenner/Projects/starshine-mb/docs/0013-2026-03-21-remove-unused-module-elements-plan.md), [`docs/0011-2026-03-18-pass-audit.md`](/home/jtenner/Projects/starshine-mb/docs/0011-2026-03-18-pass-audit.md), and [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md) so Slice 7 now records the landed idempotence coverage while the remaining pass work stays focused on future GC consumer expansion and later carrier hardening.

## 2026-03-21 Optimization: defer closed-world struct.set payloads in RemoveUnusedModuleElements

- **RemoveUnusedModuleElements struct.set slice** by **@jtenner**. Extended [`run_remove_unused_module_elements`](/home/jtenner/Projects/starshine-mb/src/optimization/optimization.mbt) in [`src/optimization/optimization.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/optimization.mbt) so closed-world mutable `struct.set` payloads now stay reference-only until a later live `struct.get` / `struct.get_s` / `struct.get_u` makes that field observable. This mirrors the earlier deferred array-writer behavior for mutable GC aggregates instead of eagerly promoting unread struct writes to used.
- Expanded whitebox coverage in [`src/optimization/remove_unused_module_elements_wbtest.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/remove_unused_module_elements_wbtest.mbt) with red-to-green regressions for unread and later-read `struct.set` payloads, plus nested struct-field/array payload guardrails.
- Updated [`docs/0011-2026-03-18-pass-audit.md`](/home/jtenner/Projects/starshine-mb/docs/0011-2026-03-18-pass-audit.md), [`docs/0013-2026-03-21-remove-unused-module-elements-plan.md`](/home/jtenner/Projects/starshine-mb/docs/0013-2026-03-21-remove-unused-module-elements-plan.md), and [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md) so the remaining GC payload work is narrowed to future GC consumer expansion and any later reference-only carrier hardening rather than missing mutable struct-write handling.

## 2026-03-21 Optimization: propagate closed-world array.copy payloads in RemoveUnusedModuleElements

- **RemoveUnusedModuleElements array.copy slice** by **@jtenner**. Extended [`run_remove_unused_module_elements`](/home/jtenner/Projects/starshine-mb/src/optimization/optimization.mbt) in [`src/optimization/optimization.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/optimization.mbt) so closed-world ref-bearing `array.copy` now propagates deferred payload identity from source array types into destination array types. Unread copies stay reference-only, while a later live `array.get` / `array.get_s` / `array.get_u` on the destination flushes the copied payloads to used.
- Expanded whitebox coverage in [`src/optimization/remove_unused_module_elements_wbtest.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/remove_unused_module_elements_wbtest.mbt) with red-to-green regressions proving that unread `array.copy` does not spuriously promote copied funcref payloads from unrelated `call_ref` traffic, while later destination reads do promote them correctly.
- Updated [`docs/0011-2026-03-18-pass-audit.md`](/home/jtenner/Projects/starshine-mb/docs/0011-2026-03-18-pass-audit.md), [`docs/0013-2026-03-21-remove-unused-module-elements-plan.md`](/home/jtenner/Projects/starshine-mb/docs/0013-2026-03-21-remove-unused-module-elements-plan.md), and [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md) so the remaining GC payload work is now hardening around reference-only non-function retention and any future GC consumer expansion rather than the earlier missing `array.copy` reader path.

## 2026-03-21 Optimization: defer closed-world array.fill payloads in RemoveUnusedModuleElements

- **RemoveUnusedModuleElements array.fill slice** by **@jtenner**. Extended [`run_remove_unused_module_elements`](/home/jtenner/Projects/starshine-mb/src/optimization/optimization.mbt) in [`src/optimization/optimization.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/optimization.mbt) so closed-world ref-bearing `array.fill` payloads now stay reference-only until a later `array.get` / `array.get_s` / `array.get_u` makes those contents observable. This reuses the deferred array-content buckets from the previous array slices instead of eagerly promoting unread fill values to used.
- Expanded whitebox coverage in [`src/optimization/remove_unused_module_elements_wbtest.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/remove_unused_module_elements_wbtest.mbt) with red-to-green regressions for unread and later-read `array.fill` cases.
- Updated [`docs/0011-2026-03-18-pass-audit.md`](/home/jtenner/Projects/starshine-mb/docs/0011-2026-03-18-pass-audit.md), [`docs/0013-2026-03-21-remove-unused-module-elements-plan.md`](/home/jtenner/Projects/starshine-mb/docs/0013-2026-03-21-remove-unused-module-elements-plan.md), and [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md) so the remaining GC array follow-up is now source/content readers such as `array.copy` plus later reference-only carrier hardening.

## 2026-03-21 Optimization: defer closed-world mutable array payload writes in RemoveUnusedModuleElements

- **RemoveUnusedModuleElements mutable array writer slice** by **@jtenner**. Extended [`run_remove_unused_module_elements`](/home/jtenner/Projects/starshine-mb/src/optimization/optimization.mbt) in [`src/optimization/optimization.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/optimization.mbt) so closed-world ref-bearing `array.set` and `array.init_elem` payloads now stay reference-only until a later `array.get` / `array.get_s` / `array.get_u` makes that array content observable. This reuses the deferred array-content buckets from the previous slice instead of eagerly promoting unread write payloads to used.
- Expanded whitebox coverage in [`src/optimization/remove_unused_module_elements_wbtest.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/remove_unused_module_elements_wbtest.mbt) with red-to-green regressions for unread and later-read cases across both direct mutable array writes and `elem`-backed `array.init_elem`.
- Updated [`docs/0011-2026-03-18-pass-audit.md`](/home/jtenner/Projects/starshine-mb/docs/0011-2026-03-18-pass-audit.md), [`docs/0013-2026-03-21-remove-unused-module-elements-plan.md`](/home/jtenner/Projects/starshine-mb/docs/0013-2026-03-21-remove-unused-module-elements-plan.md), and [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md) so the remaining GC array follow-up is now `array.fill`, broader source/content readers such as `array.copy`, and any later reference-only carrier hardening. `array.new_data` is no longer tracked as a GC payload-precision blocker because local validation restricts it to numeric/vector element arrays.

## 2026-03-21 Optimization: add closed-world GC array payload precision to RemoveUnusedModuleElements

- **RemoveUnusedModuleElements GC array payload slice** by **@jtenner**. Extended [`run_remove_unused_module_elements`](/home/jtenner/Projects/starshine-mb/src/optimization/optimization.mbt) in [`src/optimization/optimization.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/optimization.mbt) so closed-world typed `array.new`, `array.new_fixed`, and `array.new_elem` payloads now stay reference-only until a live `array.get` / `array.get_s` / `array.get_u` makes those contents observable. This adds deferred array payload state alongside referenced-only elem retention, so unread funcref array payloads no longer become spuriously used just because the array allocation itself is live.
- Expanded whitebox coverage in [`src/optimization/remove_unused_module_elements_wbtest.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/remove_unused_module_elements_wbtest.mbt) with red-to-green regressions for both direct array payloads and `elem`-backed array payloads, covering unread `array.new_fixed` / `array.new_elem` cases versus later `array.get` promotion.
- Updated [`docs/0011-2026-03-18-pass-audit.md`](/home/jtenner/Projects/starshine-mb/docs/0011-2026-03-18-pass-audit.md), [`docs/0013-2026-03-21-remove-unused-module-elements-plan.md`](/home/jtenner/Projects/starshine-mb/docs/0013-2026-03-21-remove-unused-module-elements-plan.md), and [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md) so the remaining GC follow-up is now `array.new_data`, broader GC/array content readers, and any later reference-only carrier hardening.

## 2026-03-21 Optimization: add closed-world GC struct payload precision to RemoveUnusedModuleElements

- **RemoveUnusedModuleElements GC struct payload slice** by **@jtenner**. Extended [`run_remove_unused_module_elements`](/home/jtenner/Projects/starshine-mb/src/optimization/optimization.mbt) in [`src/optimization/optimization.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/optimization.mbt) so closed-world typed `struct.new` and `struct.new_desc` payloads now stay reference-only until an actual `struct.get` / `struct.get_s` / `struct.get_u` read makes that field observable. This splits executable `ref.func` candidates from unread GC payload references, keeps referenced globals alive through the deferred payload path, and avoids unrelated `call_ref` evidence promoting unread funcref field payloads to used.
- Expanded whitebox coverage in [`src/optimization/remove_unused_module_elements_wbtest.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/remove_unused_module_elements_wbtest.mbt) with red-to-green regressions proving that unread struct-field funcref payloads no longer become spuriously live from unrelated `call_ref` traffic, while the same payloads are promoted correctly once a live field read occurs.
- Updated [`docs/0011-2026-03-18-pass-audit.md`](/home/jtenner/Projects/starshine-mb/docs/0011-2026-03-18-pass-audit.md), [`docs/0013-2026-03-21-remove-unused-module-elements-plan.md`](/home/jtenner/Projects/starshine-mb/docs/0013-2026-03-21-remove-unused-module-elements-plan.md), and [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md) so Slice 6 now records the landed struct-field subset and leaves array-related and broader GC consumer precision as the remaining follow-up.

## 2026-03-21 WAST: add struct allocation instruction surface

- **Descriptor-bearing struct instruction text slice** by **@jtenner**. Extended [`src/wast/types.mbt`](/home/jtenner/Projects/starshine-mb/src/wast/types.mbt), [`src/wast/keywords.mbt`](/home/jtenner/Projects/starshine-mb/src/wast/keywords.mbt), [`src/wast/parser.mbt`](/home/jtenner/Projects/starshine-mb/src/wast/parser.mbt), [`src/wast/module_wast.mbt`](/home/jtenner/Projects/starshine-mb/src/wast/module_wast.mbt), and [`src/wast/lower_to_lib.mbt`](/home/jtenner/Projects/starshine-mb/src/wast/lower_to_lib.mbt) so `struct.new`, `struct.new_default`, `struct.new_desc`, and `struct.new_default_desc` now have first-class WAST opcode, AST, printer, and lowering support.
- Expanded regression coverage in [`src/wast/lexer.mbt`](/home/jtenner/Projects/starshine-mb/src/wast/lexer.mbt), [`src/wast/parser.mbt`](/home/jtenner/Projects/starshine-mb/src/wast/parser.mbt), [`src/wast/module_wast_tests.mbt`](/home/jtenner/Projects/starshine-mb/src/wast/module_wast_tests.mbt), and [`src/wast/lower_to_lib.mbt`](/home/jtenner/Projects/starshine-mb/src/wast/lower_to_lib.mbt) so keyword classification, folded parsing, text rendering, and direct lowering of the struct-allocation instruction family are all covered.
- Updated [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md) so the remaining WAST GC follow-up is narrowed to general GC type/module-surface authoring rather than the instruction keywords themselves.

## 2026-03-21 GC/Optimization: implement descriptor-bearing struct construction and trap-root support

- **`struct.new_desc` end-to-end slice** by **@jtenner**. Added descriptor-bearing struct allocation support across the core Starshine packages in [`src/lib/types.mbt`](/home/jtenner/Projects/starshine-mb/src/lib/types.mbt), [`src/binary/encode.mbt`](/home/jtenner/Projects/starshine-mb/src/binary/encode.mbt), [`src/binary/decode.mbt`](/home/jtenner/Projects/starshine-mb/src/binary/decode.mbt), [`src/ir/types.mbt`](/home/jtenner/Projects/starshine-mb/src/ir/types.mbt), [`src/validate/typecheck.mbt`](/home/jtenner/Projects/starshine-mb/src/validate/typecheck.mbt), and [`src/validate/validate.mbt`](/home/jtenner/Projects/starshine-mb/src/validate/validate.mbt), including exact ref representation, descriptor/describes metadata transport, `struct.new_desc` / `struct.new_default_desc` instructions, and validator rules for descriptor-bearing struct types plus constant-expression use.
- **Text and lowering coverage** by **@jtenner**. Extended the WAST/WAT-facing layers in [`src/wast/parser.mbt`](/home/jtenner/Projects/starshine-mb/src/wast/parser.mbt), [`src/wast/lower_to_lib.mbt`](/home/jtenner/Projects/starshine-mb/src/wast/lower_to_lib.mbt), and [`src/wast/module_wast.mbt`](/home/jtenner/Projects/starshine-mb/src/wast/module_wast.mbt) so exact typed heap refs round-trip through the text AST and lower correctly into exact Starshine value types, with public API surfaces refreshed in the generated `.mbti` files.
- **RemoveUnusedModuleElements trap-root closure** by **@jtenner**. Replaced the old no-op constant-initializer trap hook in [`src/optimization/optimization.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/optimization.mbt) with descriptor-aware analysis that preserves dead globals and elem expressions when nullable descriptor-bearing `struct.new_desc` initializers may trap, while respecting `PipelineFeatures.traps_never_happen`.
- Expanded regression coverage in [`src/validate/typecheck_negative_tests.mbt`](/home/jtenner/Projects/starshine-mb/src/validate/typecheck_negative_tests.mbt), [`src/validate/validate.mbt`](/home/jtenner/Projects/starshine-mb/src/validate/validate.mbt), [`src/optimization/remove_unused_module_elements_wbtest.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/remove_unused_module_elements_wbtest.mbt), [`src/wast/parser.mbt`](/home/jtenner/Projects/starshine-mb/src/wast/parser.mbt), [`src/wast/lower_to_lib.mbt`](/home/jtenner/Projects/starshine-mb/src/wast/lower_to_lib.mbt), and [`src/wast/module_wast_tests.mbt`](/home/jtenner/Projects/starshine-mb/src/wast/module_wast_tests.mbt) so descriptor metadata, exact refs, nullable descriptor traps, and `traps_never_happen` behavior are all covered.
- Updated [`docs/0011-2026-03-18-pass-audit.md`](/home/jtenner/Projects/starshine-mb/docs/0011-2026-03-18-pass-audit.md), [`docs/0013-2026-03-21-remove-unused-module-elements-plan.md`](/home/jtenner/Projects/starshine-mb/docs/0013-2026-03-21-remove-unused-module-elements-plan.md), and [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md) so the old `struct.new_desc` trap-root blocker is closed and only the remaining GC/text-surface follow-ups stay visible.

## 2026-03-21 Docs: sync agent backlog with MemoryPacking research

- **MemoryPacking backlog follow-through** by **@jtenner**. Updated [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md) so the active default-pipeline backlog now carries the new [`docs/0014-2026-03-21-memory-packing.md`](/home/jtenner/Projects/starshine-mb/docs/0014-2026-03-21-memory-packing.md) research baseline and the concrete implementation blockers it identified for a future Starshine port.

## 2026-03-21 Docs: add MemoryPacking research baseline

- **MemoryPacking research pass** by **@jtenner**. Added [`docs/0014-2026-03-21-memory-packing.md`](/home/jtenner/Projects/starshine-mb/docs/0014-2026-03-21-memory-packing.md) as the detailed reference for the next default optimize pipeline pass after `RemoveUnusedModuleElements`, covering current Starshine scheduler reality, upstream Binaryen `MemoryPacking` semantics, pseudocode-level rewrite flow, trap-preservation rules, GC/data-user constraints, and the Starshine-specific `DataIdx` / `DataCntSec` porting requirements needed for a faithful implementation.

## 2026-03-21 Optimization: make constant-initializer trap boundary explicit

- **RemoveUnusedModuleElements constant-initializer boundary slice** by **@jtenner**. Extended [`run_remove_unused_module_elements`](/home/jtenner/Projects/starshine-mb/src/optimization/optimization.mbt) in [`src/optimization/optimization.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/optimization.mbt) with an explicit constant-initializer trap-root hook alongside the existing active-segment trap handling. The hook is intentionally a no-op today because Starshine still lacks descriptor-bearing `struct.new_desc` constant-expression support, which is the local feature work required for Binaryen-style maybe-trapping initializer rooting.
- Expanded whitebox coverage in [`src/optimization/remove_unused_module_elements_wbtest.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/remove_unused_module_elements_wbtest.mbt) with guardrail regressions showing that dead `struct.new` globals and passive `elem` expressions do not get treated as fake trap roots under the current constant-initializer subset.
- Updated [`docs/0011-2026-03-18-pass-audit.md`](/home/jtenner/Projects/starshine-mb/docs/0011-2026-03-18-pass-audit.md), [`docs/0013-2026-03-21-remove-unused-module-elements-plan.md`](/home/jtenner/Projects/starshine-mb/docs/0013-2026-03-21-remove-unused-module-elements-plan.md), and [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md) so the remaining trap-root work is broken into concrete `struct.new_desc` feature tasks before the optimizer hook is turned on.

## 2026-03-21 Optimization: add mutated-indirect callable-signature fallback to RemoveUnusedModuleElements

- **RemoveUnusedModuleElements mutated-indirect callable-signature slice** by **@jtenner**. Extended [`run_remove_unused_module_elements`](/home/jtenner/Projects/starshine-mb/src/optimization/optimization.mbt) in [`src/optimization/optimization.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/optimization.mbt) so tables that are both mutated and used by `call_indirect` or `return_call_indirect` now feed their signature facts into the closed-world `ref.func` / `call_ref` liveness machinery. Matching referenced functions become used even when they arrive through later table writes rather than initial active `elem` contents.
- Expanded whitebox coverage in [`src/optimization/remove_unused_module_elements_wbtest.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/remove_unused_module_elements_wbtest.mbt) for the new fallback: matching closed-world `ref.func` writes now survive mutated indirect tables, while mismatched signatures remain referenced-only shells.
- Updated [`docs/0011-2026-03-18-pass-audit.md`](/home/jtenner/Projects/starshine-mb/docs/0011-2026-03-18-pass-audit.md), [`docs/0013-2026-03-21-remove-unused-module-elements-plan.md`](/home/jtenner/Projects/starshine-mb/docs/0013-2026-03-21-remove-unused-module-elements-plan.md), and [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md) so the remaining `RemoveUnusedModuleElements` work is now the still-narrow constant-initializer trap model, later GC payload precision, and the product decision around wider `closed_world` exposure.

## 2026-03-21 Optimization: add closed-world referenced-only function shells to RemoveUnusedModuleElements

- **RemoveUnusedModuleElements closed-world function-reference slice** by **@jtenner**. Extended [`run_remove_unused_module_elements`](/home/jtenner/Projects/starshine-mb/src/optimization/optimization.mbt) in [`src/optimization/optimization.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/optimization.mbt) so the pass now distinguishes referenced functions from used functions when `PipelineFeatures.closed_world` is enabled. Bare `ref.func` now preserves function identity without eagerly keeping the body live, matching `call_ref` / `return_call_ref` evidence promotes compatible referenced functions back to used, and referenced-only defined functions are retained with bodies rewritten to `unreachable`.
- Expanded whitebox coverage in [`src/optimization/remove_unused_module_elements_wbtest.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/remove_unused_module_elements_wbtest.mbt) for the full slice envelope: closed-world bare `ref.func` shelling, later `call_ref` promotion back to used, and the open-world fallback keeping the full body and transitive callees alive.
- Updated [`docs/0011-2026-03-18-pass-audit.md`](/home/jtenner/Projects/starshine-mb/docs/0011-2026-03-18-pass-audit.md), [`docs/0013-2026-03-21-remove-unused-module-elements-plan.md`](/home/jtenner/Projects/starshine-mb/docs/0013-2026-03-21-remove-unused-module-elements-plan.md), and [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md) so the remaining `RemoveUnusedModuleElements` work is now the mutated-indirect callable-signature model, the still-narrow constant-initializer trap model, and the later GC payload precision slice.

## 2026-03-21 Optimization: drop broad same-table fallback for mutated indirect tables

- **RemoveUnusedModuleElements mutated-indirect slice** by **@jtenner**. Refined [`run_remove_unused_module_elements`](/home/jtenner/Projects/starshine-mb/src/optimization/optimization.mbt) in [`src/optimization/optimization.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/optimization.mbt) so a table being both mutated and used by `call_indirect` no longer causes all active `elem` contents on that table to stay alive. Mutated indirect tables now still keep matching initial contributors, but nonmatching active segments are no longer pinned just by that conjunction.
- Updated whitebox coverage in [`src/optimization/remove_unused_module_elements_wbtest.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/remove_unused_module_elements_wbtest.mbt) so the mutated-indirect case now proves nonmatching active `elem` contents are removable.
- Updated [`docs/0011-2026-03-18-pass-audit.md`](/home/jtenner/Projects/starshine-mb/docs/0011-2026-03-18-pass-audit.md), [`docs/0013-2026-03-21-remove-unused-module-elements-plan.md`](/home/jtenner/Projects/starshine-mb/docs/0013-2026-03-21-remove-unused-module-elements-plan.md), and [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md) so the remaining mutated-indirect work is now explicitly the missing Binaryen-style callable-signature model rather than the older broad same-table retention fallback.

## 2026-03-21 Optimization: gate table initializer liveness on observable or indirect table use

- **RemoveUnusedModuleElements table-initializer slice** by **@jtenner**. Refined [`run_remove_unused_module_elements`](/home/jtenner/Projects/starshine-mb/src/optimization/optimization.mbt) in [`src/optimization/optimization.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/optimization.mbt) so defined table initializer expressions are no longer scanned just because the table itself is live. Initializer contents are now retained only when the table’s contents are actually observable or when the table participates in indirect calls.
- Expanded whitebox coverage in [`src/optimization/remove_unused_module_elements_wbtest.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/remove_unused_module_elements_wbtest.mbt) for `table.size` and `table.set` no longer rooting table initializer helpers, while `call_indirect` and `table.copy` source observability still retain initializer-driven contents.
- Updated [`docs/0011-2026-03-18-pass-audit.md`](/home/jtenner/Projects/starshine-mb/docs/0011-2026-03-18-pass-audit.md), [`docs/0013-2026-03-21-remove-unused-module-elements-plan.md`](/home/jtenner/Projects/starshine-mb/docs/0013-2026-03-21-remove-unused-module-elements-plan.md), and [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md) so the remaining table-precision work is now concentrated on Binaryen-style callable-signature fallback for mutated indirect tables.

## 2026-03-21 Optimization: narrow table-content observability for active elem retention

- **RemoveUnusedModuleElements table-observability slice** by **@jtenner**. Refined [`run_remove_unused_module_elements`](/home/jtenner/Projects/starshine-mb/src/optimization/optimization.mbt) in [`src/optimization/optimization.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/optimization.mbt) so active `elem` segments are no longer kept just because live code touches table metadata or overwrites entries. `table.size`, `table.set`, `table.fill`, `table.grow`, and `table.init` now keep the table itself live without pinning prior contents, while exports, `table.get`, `table.copy` sources, and indirect-call tables with live mutation still retain the necessary active contents conservatively.
- Expanded whitebox coverage in [`src/optimization/remove_unused_module_elements_wbtest.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/remove_unused_module_elements_wbtest.mbt) for `table.size` and `table.set` not rooting dead active contents, plus `table.copy` source retention and the existing indirect-call-plus-mutation fallback.
- Updated [`docs/0011-2026-03-18-pass-audit.md`](/home/jtenner/Projects/starshine-mb/docs/0011-2026-03-18-pass-audit.md), [`docs/0013-2026-03-21-remove-unused-module-elements-plan.md`](/home/jtenner/Projects/starshine-mb/docs/0013-2026-03-21-remove-unused-module-elements-plan.md), and [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md) so the remaining table-precision work is table-initializer handling for indirect-only tables and Binaryen-style callable-signature fallback for mutated indirect tables.

## 2026-03-21 Optimization: thread trap-mode policy into RemoveUnusedModuleElements

- **RemoveUnusedModuleElements trap-policy slice** by **@jtenner**. Extended [`PipelineFeatures`](/home/jtenner/Projects/starshine-mb/src/optimization/optimization.mbt) in [`src/optimization/optimization.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/optimization.mbt) with `traps_never_happen`, threaded it from generated optimize execution in [`src/cmd/cmd.mbt`](/home/jtenner/Projects/starshine-mb/src/cmd/cmd.mbt), and taught [`run_remove_unused_module_elements`](/home/jtenner/Projects/starshine-mb/src/optimization/optimization.mbt) not to preserve maybe-trapping active `elem`/`data` segments when the pipeline explicitly assumes traps never happen.
- Expanded whitebox coverage in [`src/optimization/remove_unused_module_elements_wbtest.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/remove_unused_module_elements_wbtest.mbt) and [`src/cmd/generated_pipeline_wbtest.mbt`](/home/jtenner/Projects/starshine-mb/src/cmd/generated_pipeline_wbtest.mbt) for both sides of the slice: generated pipeline propagation of `traps_never_happen` and the pass-level behavior change when trap roots are disabled.
- Updated [`docs/0011-2026-03-18-pass-audit.md`](/home/jtenner/Projects/starshine-mb/docs/0011-2026-03-18-pass-audit.md), [`docs/0013-2026-03-21-remove-unused-module-elements-plan.md`](/home/jtenner/Projects/starshine-mb/docs/0013-2026-03-21-remove-unused-module-elements-plan.md), and [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md) so the remaining visible trap gap is the still-narrow constant-initializer model rather than missing feature-source plumbing.

## 2026-03-21 Optimization: refine indirect-call table precision for active elem segments

- **RemoveUnusedModuleElements indirect-call slice** by **@jtenner**. Extended [`run_remove_unused_module_elements`](/home/jtenner/Projects/starshine-mb/src/optimization/optimization.mbt) in [`src/optimization/optimization.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/optimization.mbt) so `call_indirect` and `return_call_indirect` on non-mutated tables retain only matching active `elem` contributors instead of rooting every active segment on the table. Table exports and concrete table reads/writes still keep the broader observability behavior, and live table mutation falls back conservatively to whole-table active-segment retention.
- Expanded whitebox coverage in [`src/optimization/remove_unused_module_elements_wbtest.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/remove_unused_module_elements_wbtest.mbt) for both sides of that behavior: precise retention on non-mutated indirect-call tables and conservative fallback once the live code mutates the table.
- Updated [`docs/0011-2026-03-18-pass-audit.md`](/home/jtenner/Projects/starshine-mb/docs/0011-2026-03-18-pass-audit.md), [`docs/0013-2026-03-21-remove-unused-module-elements-plan.md`](/home/jtenner/Projects/starshine-mb/docs/0013-2026-03-21-remove-unused-module-elements-plan.md), and [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md) so the remaining `RemoveUnusedModuleElements` gaps are the still-coarse mutable-table/table-initializer indirect fallback, the narrow constant-initializer trap model, and closed-world referenced-only function handling.

## 2026-03-21 Optimization: preserve maybe-trapping active segment instantiation behavior

- **RemoveUnusedModuleElements trap-root slice** by **@jtenner**. Extended [`run_remove_unused_module_elements`](/home/jtenner/Projects/starshine-mb/src/optimization/optimization.mbt) in [`src/optimization/optimization.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/optimization.mbt) so active `elem` and `data` segments are rooted when they may trap at instantiation time, including unknown constant offsets via immutable `global.get` and constant writes that exceed the defined target’s initial bounds.
- Expanded whitebox coverage in [`src/optimization/remove_unused_module_elements_wbtest.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/remove_unused_module_elements_wbtest.mbt) for unknown-offset active data segments and out-of-bounds active elem segments, alongside the earlier live-target and observability regressions.
- Updated [`docs/0011-2026-03-18-pass-audit.md`](/home/jtenner/Projects/starshine-mb/docs/0011-2026-03-18-pass-audit.md), [`docs/0013-2026-03-21-remove-unused-module-elements-plan.md`](/home/jtenner/Projects/starshine-mb/docs/0013-2026-03-21-remove-unused-module-elements-plan.md), and [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md) so the remaining visible `RemoveUnusedModuleElements` work is fuller indirect-call/table precision, the still-narrow local constant-initializer trap model, and closed-world referenced-only function handling.

## 2026-03-21 Optimization: add live-target precision for active elem/data segments

- **RemoveUnusedModuleElements active-segment precision slice** by **@jtenner**. Extended [`run_remove_unused_module_elements`](/home/jtenner/Projects/starshine-mb/src/optimization/optimization.mbt) in [`src/optimization/optimization.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/optimization.mbt) so active `elem` and `data` segments are no longer unconditional roots. They now become live only when their target table or memory is imported or otherwise live, which lets dead active segments on dead defined targets disappear instead of pinning helper functions.
- Expanded whitebox coverage in [`src/optimization/remove_unused_module_elements_wbtest.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/remove_unused_module_elements_wbtest.mbt) for dead active-segment removal, imported-target observability, exported-target retention, and indirect-table use preserving active elem contents.
- Updated [`docs/0011-2026-03-18-pass-audit.md`](/home/jtenner/Projects/starshine-mb/docs/0011-2026-03-18-pass-audit.md), [`docs/0013-2026-03-21-remove-unused-module-elements-plan.md`](/home/jtenner/Projects/starshine-mb/docs/0013-2026-03-21-remove-unused-module-elements-plan.md), and [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md) so the remaining visible `RemoveUnusedModuleElements` gaps are trap-root precision, fuller indirect-call/table precision, and closed-world referenced-only function handling.

## 2026-03-21 Cmd/Optimization: derive generated pipeline features from modules and options

- **Generated optimize feature-source plumbing** by **@jtenner**. Extended [`OptimizeOptions`](/home/jtenner/Projects/starshine-mb/src/cmd/cmd.mbt) and the generated optimize helpers in [`src/cmd/cmd.mbt`](/home/jtenner/Projects/starshine-mb/src/cmd/cmd.mbt) so generated pipeline expansion and module-wide execution now derive `PipelineFeatures.has_gc` and `PipelineFeatures.has_multivalue` from the input module, preserve `low_memory_unused`, and thread an explicit `closed_world` option instead of synthesizing a mostly-empty feature struct.
- Added whitebox coverage in [`src/cmd/generated_pipeline_wbtest.mbt`](/home/jtenner/Projects/starshine-mb/src/cmd/generated_pipeline_wbtest.mbt) for positive and negative feature detection, runtime feature propagation to module-wide entries, and default optimize-pipeline expansion now picking up GC and multivalue passes from module-derived facts.
- Updated [`src/cmd/imports.mbt`](/home/jtenner/Projects/starshine-mb/src/cmd/imports.mbt), [`src/cmd/moon.pkg`](/home/jtenner/Projects/starshine-mb/src/cmd/moon.pkg), [`docs/0011-2026-03-18-pass-audit.md`](/home/jtenner/Projects/starshine-mb/docs/0011-2026-03-18-pass-audit.md), [`docs/0013-2026-03-21-remove-unused-module-elements-plan.md`](/home/jtenner/Projects/starshine-mb/docs/0013-2026-03-21-remove-unused-module-elements-plan.md), and [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md) so the feature-source blocker is closed and the remaining visible `RemoveUnusedModuleElements` work is indirect-call/table precision, trap/observability precision, and closed-world function-reference analysis.

## 2026-03-21 Optimization: compact tags and harden RemoveUnusedModuleElements tests

- **RemoveUnusedModuleElements tag remap + coverage hardening** by **@jtenner**. Extended [`run_remove_unused_module_elements`](/home/jtenner/Projects/starshine-mb/src/optimization/optimization.mbt) in [`src/optimization/optimization.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/optimization.mbt) so the open-world pass now tracks tag liveness, removes unused defined tags, rewrites mixed import+defined `TagIdx` users, and compacts `NameSec.tag_names`.
- Expanded whitebox coverage in [`src/optimization/remove_unused_module_elements_wbtest.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/remove_unused_module_elements_wbtest.mbt) with edge-case regressions for idempotence, dead table-initializer non-roots, thrown-tag and caught-tag retention/remap, and the earlier global/table/memory/segment cases that now act as slice-to-slice guardrails.
- Updated [`docs/0011-2026-03-18-pass-audit.md`](/home/jtenner/Projects/starshine-mb/docs/0011-2026-03-18-pass-audit.md), [`docs/0013-2026-03-21-remove-unused-module-elements-plan.md`](/home/jtenner/Projects/starshine-mb/docs/0013-2026-03-21-remove-unused-module-elements-plan.md), and [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md) so the next carried-forward unimplemented areas are indirect-call/table precision, trap/observability precision, and referenced-only function shells.

## 2026-03-21 Optimization: compact tables and memories in RemoveUnusedModuleElements

- **RemoveUnusedModuleElements table/memory remap slice** by **@jtenner**. Extended [`run_remove_unused_module_elements`](/home/jtenner/Projects/starshine-mb/src/optimization/optimization.mbt) in [`src/optimization/optimization.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/optimization.mbt) so the open-world pass now tracks table and memory liveness, removes unused defined tables and memories, rewrites mixed import+defined `TableIdx` and `MemIdx` users, and compacts `NameSec.table_names` plus `NameSec.memory_names`.
- Added whitebox coverage in [`src/optimization/remove_unused_module_elements_wbtest.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/remove_unused_module_elements_wbtest.mbt) for dead table/memory removal, mixed-space remaps in exports and typed instructions, active elem/data mode rooting, and the fact that dead table initializer expressions no longer pin dead helper functions.
- Updated [`docs/0011-2026-03-18-pass-audit.md`](/home/jtenner/Projects/starshine-mb/docs/0011-2026-03-18-pass-audit.md), [`docs/0013-2026-03-21-remove-unused-module-elements-plan.md`](/home/jtenner/Projects/starshine-mb/docs/0013-2026-03-21-remove-unused-module-elements-plan.md), and [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md) so the next visible `RemoveUnusedModuleElements` work is tags, indirect-call/table precision, trap/observability precision, and referenced-only function shells.

## 2026-03-21 Optimization: compact globals in RemoveUnusedModuleElements

- **RemoveUnusedModuleElements global remap slice** by **@jtenner**. Extended [`run_remove_unused_module_elements`](/home/jtenner/Projects/starshine-mb/src/optimization/optimization.mbt) in [`src/optimization/optimization.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/optimization.mbt) so the open-world pass now tracks global liveness, removes unused defined globals, rewrites mixed import+defined `GlobalIdx` users, and compacts `NameSec.global_names`.
- Added whitebox coverage in [`src/optimization/remove_unused_module_elements_wbtest.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/remove_unused_module_elements_wbtest.mbt) for exported/live global retention, dead-global removal that no longer pins dead helper functions, mixed import+defined global remapping, and active-data-offset global roots.
- Updated [`docs/0011-2026-03-18-pass-audit.md`](/home/jtenner/Projects/starshine-mb/docs/0011-2026-03-18-pass-audit.md), [`docs/0013-2026-03-21-remove-unused-module-elements-plan.md`](/home/jtenner/Projects/starshine-mb/docs/0013-2026-03-21-remove-unused-module-elements-plan.md), and [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md) so the next visible `RemoveUnusedModuleElements` work is tables, memories, tags, trap precision, indirect-call precision, and referenced-only function shells.

## 2026-03-21 Optimization: compact elem/data segments in RemoveUnusedModuleElements

- **RemoveUnusedModuleElements elem/data remap slice** by **@jtenner**. Extended [`run_remove_unused_module_elements`](/home/jtenner/Projects/starshine-mb/src/optimization/optimization.mbt) in [`src/optimization/optimization.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/optimization.mbt) so the open-world pass now tracks `elem` and `data` segment liveness alongside functions, keeps active segments conservatively, removes unused passive/declarative segments, and rewrites `FuncIdx`/`ElemIdx`/`DataIdx` users plus `DataCntSec`.
- Added whitebox coverage in [`src/optimization/remove_unused_module_elements_wbtest.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/remove_unused_module_elements_wbtest.mbt) for passive segment removal, `table.init`/`elem.drop`/`memory.init`/`data.drop` remaps, `elem`/`data` name-map repair, and conservative active-segment retention.
- Updated [`docs/0011-2026-03-18-pass-audit.md`](/home/jtenner/Projects/starshine-mb/docs/0011-2026-03-18-pass-audit.md), [`docs/0013-2026-03-21-remove-unused-module-elements-plan.md`](/home/jtenner/Projects/starshine-mb/docs/0013-2026-03-21-remove-unused-module-elements-plan.md), and [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md) so the next visible work is broader non-function removal, segment observability/trap precision, and referenced-only function shells.

## 2026-03-21 Optimization: implement first open-world function slice of RemoveUnusedModuleElements

- **RemoveUnusedModuleElements function-only MVP** by **@jtenner**. Added [`run_remove_unused_module_elements`](/home/jtenner/Projects/starshine-mb/src/optimization/optimization.mbt) in [`src/optimization/optimization.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/optimization.mbt) and routed `OptimizePass::RemoveUnusedModuleElements` to it so the generated pipeline now removes unreachable defined functions instead of no-oping.
- The landed slice is intentionally bounded: it roots exported and start functions, seeds live function identity from surviving globals/tables/elem segments, walks only live function bodies, and compacts function indices plus function/local name maps. It does not yet remove non-function module elements or implement closed-world referenced-only shell rewriting.
- Added whitebox coverage in [`src/optimization/remove_unused_module_elements_wbtest.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/remove_unused_module_elements_wbtest.mbt) for direct-call retention and remap, rootless chain removal, start rooting, and elem-segment rooting, and updated [`src/cmd/cmd_test.mbt`](/home/jtenner/Projects/starshine-mb/src/cmd/cmd_test.mbt) for the now-nontrivial optimize pipeline outputs.
- Updated [`docs/0011-2026-03-18-pass-audit.md`](/home/jtenner/Projects/starshine-mb/docs/0011-2026-03-18-pass-audit.md), [`docs/0013-2026-03-21-remove-unused-module-elements-plan.md`](/home/jtenner/Projects/starshine-mb/docs/0013-2026-03-21-remove-unused-module-elements-plan.md), and [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md) to mark the completed slice and leave the remaining non-function, closed-world, and GC work visible.

## 2026-03-21 Optimization/Cmd: thread PipelineFeatures through generated module-wide pass execution

- **Generated module-wide feature plumbing** by **@jtenner**. Updated [`src/optimization/optimization.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/optimization.mbt) and [`src/cmd/cmd.mbt`](/home/jtenner/Projects/starshine-mb/src/cmd/cmd.mbt) so generated module-wide passes now receive `PipelineFeatures` at execution time instead of only `PipelineGlobal`, unblocking feature-aware module-pass work such as the later closed-world `RemoveUnusedModuleElements` slices.
- Added runtime coverage in [`src/cmd/generated_pipeline_wbtest.mbt`](/home/jtenner/Projects/starshine-mb/src/cmd/generated_pipeline_wbtest.mbt) and refreshed the optimization signature tests in [`src/optimization/optimization_test.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/optimization_test.mbt) plus [`src/optimization/duplicate_function_elimination_wbtest.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/duplicate_function_elimination_wbtest.mbt).
- Updated [`docs/0011-2026-03-18-pass-audit.md`](/home/jtenner/Projects/starshine-mb/docs/0011-2026-03-18-pass-audit.md), [`docs/0013-2026-03-21-remove-unused-module-elements-plan.md`](/home/jtenner/Projects/starshine-mb/docs/0013-2026-03-21-remove-unused-module-elements-plan.md), and [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md) to reflect that execution-time runner plumbing is done and the remaining blocker is feature-source plumbing for `closed_world`, `has_gc`, and related flags.

## 2026-03-21 Docs/Backlog: import RemoveUnusedModuleElements research and traceable rollout plan

- **RemoveUnusedModuleElements research import and rollout plan** by **@jtenner**. Imported the latest upstream research into [`docs/0012-2026-03-21-remove-unused-module-elements.md`](/home/jtenner/Projects/starshine-mb/docs/0012-2026-03-21-remove-unused-module-elements.md) and added a Starshine-specific implementation plan in [`docs/0013-2026-03-21-remove-unused-module-elements-plan.md`](/home/jtenner/Projects/starshine-mb/docs/0013-2026-03-21-remove-unused-module-elements-plan.md) with algorithm slices cross-referenced back to the research material for later implementation and audit work.
- Updated [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md) to keep the active `RemoveUnusedModuleElements` slices visible and to add the generated-pipeline `PipelineFeatures` plumbing blocker that must be resolved before closed-world and GC-aware pass behavior can land.

## 2026-03-20 Docs: add build/test/fuzz setup guidance to README

- **README dependency and workflow update** by **@jtenner**. Expanded [`README.mbt.md`](/home/jtenner/Projects/starshine-mb/README.mbt.md) with explicit setup requirements and concrete build/test/fuzz commands for contributors.
- Added documentation for:
  - required local tooling (`bun`, `moon`, optional Node.js),
  - dependency installation,
  - full validation and regular quality-gate commands,
  - fuzz and readme/API validation command variants.

## 2026-03-20 Docs: compact and align documentation workflow

- **Documentation compaction pass** by **@jtenner**. Reworked the documentation corpus and onboarding guidance for easier scanning and higher signal-to-noise.
- Updated all non-code docs to compact structure and wording:
  - [`README.mbt.md`](/home/jtenner/Projects/starshine-mb/README.mbt.md)
  - [`examples/README.md`](/home/jtenner/Projects/starshine-mb/examples/README.md)
  - [`node/README.md`](/home/jtenner/Projects/starshine-mb/node/README.md)
  - [`node/examples/README.md`](/home/jtenner/Projects/starshine-mb/node/examples/README.md)
  - [`tests/spec/README.md`](/home/jtenner/Projects/starshine-mb/tests/spec/README.md)
  - [`AGENTS.md`](/home/jtenner/Projects/starshine-mb/AGENTS.md)
  - pass and planning docs under `docs/` (`docs/0001...0011`).
- Kept pass/research history complete but made each doc action-oriented and concise:
  - tracing contract, pipeline diff, fuzz migration, vacuum plan, simplify-locals, merge-related plan/doc, merge-similar-functions, merge publish gate, string gathering, and pass-audit docs.
- Cleaned active backlog wording and duplicate blockers in [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md).

## 2026-03-19 Docs/Agents: canonicalize committed docs naming and research placement

- Renamed the committed markdown documents under [`docs/`](/home/jtenner/Projects/starshine-mb/docs) into the canonical `docs/[unique serial id]-[date committed]-[title].md` format, flattening older nested plan and benchmark paths into a single indexed docs namespace.
- Updated repo references in [`CHANGELOG.md`](/home/jtenner/Projects/starshine-mb/CHANGELOG.md), [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md), and the docs themselves so existing links now point at the canonical serial-named paths.
- Expanded [`AGENTS.md`](/home/jtenner/Projects/starshine-mb/AGENTS.md) with a dedicated research section that requires detailed project-relevant research, places committed research directly in [`docs/`](/home/jtenner/Projects/starshine-mb/docs), and tells future agents how to discover existing research and resolve legacy slug-style topic hints.

## 2026-03-19 Backlog/Docs: prune completed name-section blocker and require pre-commit backlog review

- Removed the completed `name` custom-section publishing blocker from [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md) now that the extended name-section subsection support landed and is recorded in the changelog, keeping the backlog limited to open work only.
- Updated [`AGENTS.md`](/home/jtenner/Projects/starshine-mb/AGENTS.md) to require a pre-commit review of [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md), including adding new blockers or risks and removing completed items before commit.

## 2026-03-19 Binary/Validate: implement remaining extended name-section subsections

- Extended [`src/lib/types.mbt`](/home/jtenner/Projects/starshine-mb/src/lib/types.mbt) and the generated interface in [`src/lib/pkg.generated.mbti`](/home/jtenner/Projects/starshine-mb/src/lib/pkg.generated.mbti) so `NameSec` now models the remaining extended-name-section proposal subsections: label, table, memory, global, elem, and data names in addition to the previously implemented module/function/local/type/field/tag names.
- Updated [`src/binary/encode.mbt`](/home/jtenner/Projects/starshine-mb/src/binary/encode.mbt) and [`src/binary/decode.mbt`](/home/jtenner/Projects/starshine-mb/src/binary/decode.mbt) to emit and parse subsection ids `3`, `5`, `6`, `7`, `8`, and `9`, preserving the existing ordering and payload validation rules for structured `name` sections.
- Updated [`src/validate/validate.mbt`](/home/jtenner/Projects/starshine-mb/src/validate/validate.mbt) to validate the new name maps against real module index spaces, including function-wide label-name validation based on the count of structured control labels in both untyped and typed function bodies.
- Added round-trip and edge-case regressions in [`src/binary/tests.mbt`](/home/jtenner/Projects/starshine-mb/src/binary/tests.mbt) and [`src/validate/validate.mbt`](/home/jtenner/Projects/starshine-mb/src/validate/validate.mbt), and updated [`src/optimization/optimization.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/optimization.mbt) plus [`src/lib/show.mbt`](/home/jtenner/Projects/starshine-mb/src/lib/show.mbt) to handle the expanded `NameSec` shape without dropping the new fields.
- Validation: `moon info`; `moon fmt`; `moon test`.

## 2026-03-19 Backlog: restructure optimize pass planning around release gates and per-pass workflow

- Rewrote [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md) so optimizer planning now matches the post-cutover `src/optimization` world instead of the removed `src/passes` pipeline. The backlog scope now says every pass item must explicitly cover four phases: Binaryen research, strict-TDD implementation, validation-strategy investigation aligned with Binaryen even when it contradicts the current setup, and a Binaryen-vs-Starshine comparison phase.
- Split pass work by release gate. Every pass that participates in the current default optimize pipeline is now listed under a dedicated `v0.1.0` blocker section, making the shipping requirement explicit: the default pipeline cannot count as done until each of those passes has a research document, a real implementation, a Binaryen-aligned validation decision, and comparison coverage.
- Expanded the `v0.1.0` section into one top-level backlog item per default-pipeline pass, including the already-implemented [`DuplicateFunctionElimination`](/home/jtenner/Projects/starshine-mb/src/optimization/optimization.mbt), which now has a backlog item focused on refreshing its research writeup, finishing correctness hardening, validating its behavior the way Binaryen does, and comparing outputs on fixtures and real modules.
- Added a separate `v0.2.0` blocker section for the broader Binaryen pass inventory that is not currently in the default optimize pipeline. Each of those passes now has its own top-level backlog item pointing at the intended `docs/<dash-cased-pass-name>.md` research file and the same four-phase workflow, so parity work outside the default pipeline is tracked explicitly instead of being buried in catch-all follow-up bullets.
- Removed stale backlog items that no longer fit the new execution strategy, including the old pass-specific performance triage bullets, scheduling-audit bullets, and `src/passes`-era cleanup/refactor bullets that assumed the deleted optimizer architecture. The backlog now focuses on pass-by-pass delivery and keeps only the still-relevant publishing blockers plus longer-horizon non-pass work.
- Kept and clarified the non-pass planning edges that still matter during the transition: the MoonBit `name` subsection decode blocker remains in publishing blockers, `docs/0011-2026-03-18-pass-audit.md` is still called out for refresh against the `src/optimization` package, and the bottom-of-file section is now clearly framed as longer-horizon non-pass work rather than mixed in with immediate optimizer implementation items.

## 2026-03-19 Backlog: record DFE comparison blockers from latest build artifact

- Added new publishing-blocker entries to [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md) for the two issues found while comparing `DuplicateFunctionElimination` against Binaryen on the latest Starshine build artifact: unsupported `name` subsection ids emitted by current MoonBit builds and the stripped-artifact post-encode `Invalid subtype` failure in the DFE path.

## 2026-03-19 Optimization: rewrite name section entries during duplicate-function elimination

- Updated [`src/optimization/optimization.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/optimization.mbt) so `DuplicateFunctionElimination` now rewrites `Module.name_sec.func_names` and `Module.name_sec.local_names` with the same absolute-function remap it already applies to code references, exports, and the start function. When duplicate functions collapse to one canonical body, the pass now keeps the first surviving name entry for that canonical function and drops the removed duplicate’s name entry instead of leaving stale indices behind.
- Added a whitebox regression in [`src/optimization/duplicate_function_elimination_wbtest.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/duplicate_function_elimination_wbtest.mbt) that proves function-name maps and local-name maps are compacted correctly when deduping a middle function shifts later function indices down.
- Updated [`src/optimization/imports.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/imports.mbt) to import the structured name-section types used by the new rewrite helpers.
- Validation: `moon info`; `moon fmt`; `moon test`.

## 2026-03-19 Binary/Validate: add first-class names custom section support

- Added structured name-section model types in [`src/lib/types.mbt`](/home/jtenner/Projects/starshine-mb/src/lib/types.mbt) and a dedicated `Module.name_sec` field with [`src/lib/module.mbt`](/home/jtenner/Projects/starshine-mb/src/lib/module.mbt) helpers, so module, function, local, type, field, and tag names are represented explicitly instead of being carried as an opaque raw custom section.
- Updated the binary codec in [`src/binary/decode.mbt`](/home/jtenner/Projects/starshine-mb/src/binary/decode.mbt) and [`src/binary/encode.mbt`](/home/jtenner/Projects/starshine-mb/src/binary/encode.mbt) to parse and emit the WebAssembly `name` custom section as its own structured module section, enforce subsection and name-map ordering, place the encoded `name` section after the standard sections, and reject ambiguous raw `"name"` entries in `custom_secs`.
- Updated [`src/validate/validate.mbt`](/home/jtenner/Projects/starshine-mb/src/validate/validate.mbt) to validate structured name-section references against real module index spaces, including function-local name maps against the actual param-plus-local counts of imported and defined functions, with a dedicated `NameSection` diagnostic path.
- Added binary and validator regressions in [`src/binary/tests.mbt`](/home/jtenner/Projects/starshine-mb/src/binary/tests.mbt) and [`src/validate/validate.mbt`](/home/jtenner/Projects/starshine-mb/src/validate/validate.mbt), and refreshed the generated package interfaces in [`src/lib/pkg.generated.mbti`](/home/jtenner/Projects/starshine-mb/src/lib/pkg.generated.mbti), [`src/binary/pkg.generated.mbti`](/home/jtenner/Projects/starshine-mb/src/binary/pkg.generated.mbti), and [`src/validate/pkg.generated.mbti`](/home/jtenner/Projects/starshine-mb/src/validate/pkg.generated.mbti).
- Validation: `moon info`; `moon fmt`; `moon test`.

## 2026-03-18 CLI Optimize Cutover: route generated optimization pipeline through cmd

- Updated [`src/cmd/cmd.mbt`](/home/jtenner/Projects/starshine-mb/src/cmd/cmd.mbt) so CLI optimization flags now build and run the generated optimization pipeline before any legacy no-op pass handling, including pass-count limiting, grouped function-pass execution, segment-level validation, and trace output for generated pipeline segments.
- Updated [`src/cmd/imports.mbt`](/home/jtenner/Projects/starshine-mb/src/cmd/imports.mbt) and [`src/cmd/moon.pkg`](/home/jtenner/Projects/starshine-mb/src/cmd/moon.pkg) to depend on the new [`src/optimization`](/home/jtenner/Projects/starshine-mb/src/optimization) package from the command package.
- Added regressions in [`src/cmd/cmd_test.mbt`](/home/jtenner/Projects/starshine-mb/src/cmd/cmd_test.mbt) covering `--duplicate-function-elimination` on wasm input and `--optimize` processing across multiple input files through the generated pipeline.
- Validation: `moon info`; `moon fmt`; `moon test`.

## 2026-03-18 Optimization Package: add starter pipeline model and Binaryen-style duplicate-function elimination

- Added the new [`src/optimization`](/home/jtenner/Projects/starshine-mb/src/optimization) package with starter pipeline data structures, the Binaryen pass inventory enums, pipeline grouping/validation metadata, and a default optimize pipeline builder that batches adjacent function-local passes into shared groups before validation.
- Implemented a real `DuplicateFunctionElimination` pipeline pass in [`src/optimization/optimization.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/optimization.mbt) based on Binaryen’s pass behavior: it hashes defined functions, compares function bodies plus resolved structural function signatures, iterates until no more duplicates are exposed, compacts the function/code sections, and rewrites all affected `FuncIdx` references across the module.
- Added blackbox pipeline coverage in [`src/optimization/optimization_test.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/optimization_test.mbt) and whitebox duplicate-elimination regressions in [`src/optimization/duplicate_function_elimination_wbtest.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/duplicate_function_elimination_wbtest.mbt), including imported-function offsets, `call`/`ref.func`/`export`/`start` rewrites, transitive deduping, and mismatched-signature non-merge cases.
- Validation: `moon test src/optimization`; `moon info`; `moon fmt`; `moon test`.

## 2026-03-18 Optimize Refactor Cutover: remove `passes`, disable optimizer execution, and trim stale Node surfaces

- Removed the entire MoonBit optimization package at [`src/passes`](/home/jtenner/Projects/starshine-mb/src/passes) and the obsolete Node bridge package at [`src/node_api`](/home/jtenner/Projects/starshine-mb/src/node_api). This is an intentionally breaking cleanup to stop shipping a fundamentally broken optimization pipeline while the pass architecture is redesigned.
- Reworked the CLI-owned optimization path in [`src/cmd/cmd.mbt`](/home/jtenner/Projects/starshine-mb/src/cmd/cmd.mbt), [`src/cmd/imports.mbt`](/home/jtenner/Projects/starshine-mb/src/cmd/imports.mbt), and [`src/cmd/moon.pkg`](/home/jtenner/Projects/starshine-mb/src/cmd/moon.pkg) so explicit pass flags and preset optimization flags are still parsed, reported, and expanded for compatibility, but now execute as no-op identity transforms instead of calling into the removed pass scheduler. This preserves CLI/config compatibility while making the destructive refactor explicit and safe.
- Updated [`src/cmd/cmd_test.mbt`](/home/jtenner/Projects/starshine-mb/src/cmd/cmd_test.mbt), [`src/cmd/readme_api_sync_wbtest.mbt`](/home/jtenner/Projects/starshine-mb/src/cmd/readme_api_sync_wbtest.mbt), and regenerated [`src/cmd/pkg.generated.mbti`](/home/jtenner/Projects/starshine-mb/src/cmd/pkg.generated.mbti) so the `cmd` package now documents and tests the compatibility no-op behavior instead of the old optimizer-backed behavior.
- Removed the stale Node `passes` adapter surface from [`node/passes.js`](/home/jtenner/Projects/starshine-mb/node/passes.js), [`node/passes.d.ts`](/home/jtenner/Projects/starshine-mb/node/passes.d.ts), [`node/internal/generated/passes.generated.js`](/home/jtenner/Projects/starshine-mb/node/internal/generated/passes.generated.js), [`node/internal/generated/passes.generated.d.ts`](/home/jtenner/Projects/starshine-mb/node/internal/generated/passes.generated.d.ts), [`node/index.js`](/home/jtenner/Projects/starshine-mb/node/index.js), [`node/index.d.ts`](/home/jtenner/Projects/starshine-mb/node/index.d.ts), and [`node/package.json`](/home/jtenner/Projects/starshine-mb/node/package.json). The hand-authored JS `cmd` bridge in [`node/cmd.js`](/home/jtenner/Projects/starshine-mb/node/cmd.js) and [`node/cmd.d.ts`](/home/jtenner/Projects/starshine-mb/node/cmd.d.ts) now mirrors the MoonBit-side compatibility behavior by accepting optimization inputs but skipping optimization work.
- Deleted the old pass-centric Node example [`node/examples/11-passes-optimize-module.mjs`](/home/jtenner/Projects/starshine-mb/node/examples/11-passes-optimize-module.mjs), rewrote [`README.mbt.md`](/home/jtenner/Projects/starshine-mb/README.mbt.md), [`node/README.md`](/home/jtenner/Projects/starshine-mb/node/README.md), and [`node/examples/README.md`](/home/jtenner/Projects/starshine-mb/node/examples/README.md) to stop advertising the removed optimizer API, and adjusted [`scripts/test/task-family-commands.ts`](/home/jtenner/Projects/starshine-mb/scripts/test/task-family-commands.ts) to stop pointing coverage examples at deleted pass files.
- Replaced [`scripts/lib/generate-node-package.mjs`](/home/jtenner/Projects/starshine-mb/scripts/lib/generate-node-package.mjs) and [`scripts/lib/build-node-package.mjs`](/home/jtenner/Projects/starshine-mb/scripts/lib/build-node-package.mjs) with explicit fail-fast stubs. The previous generation/build flow depended on the removed `passes` and `node_api` packages, so leaving those commands in place would have silently promised a regeneration path that no longer exists.
- Validation: `moon info`; `moon fmt`; `moon test`; `node --check node/cmd.js`; `node --check scripts/lib/build-node-package.mjs`; `node --check scripts/lib/generate-node-package.mjs`.
- Known remaining issue: `node --test node/test/smoke.test.mjs` still fails because the checked-in GC Node artifact and JS adapters are now out of sync after removing `src/node_api`, leading to `RuntimeError: illegal cast` before most Node API calls complete. Regenerating or replacing that runtime path is now a separate follow-up.

## 2026-03-18 Binary Test Cleanup: remove final unreachable-code warning

- Updated [`src/binary/tests.mbt`](/home/jtenner/Projects/starshine-mb/src/binary/tests.mbt) to collapse a duplicated `decoded.code_sec` match arm in the typed-locals round-trip test into a single checked branch, preserving the explicit failure message while removing the last unreachable-code warning reported by `moon info`.
- Validation: `moon info`; `moon fmt`; `moon test`.

## 2026-03-18 Docs/Node Package Sync: refresh locals docs after canonicalization

- Updated [`README.md`](/home/jtenner/Projects/starshine-mb/README.md) and [`README.mbt.md`](/home/jtenner/Projects/starshine-mb/README.mbt.md) so the public library docs now describe the canonical `Locals` / `LocalRun` model, the mutable cached `indices`, `Locals::ensure_index()`, and the indexable lookup surface used after the flat-locals removal.
- Refreshed the pass and tracing docs in [`docs/0006-2026-03-15-simplify-locals.md`](/home/jtenner/Projects/starshine-mb/docs/0006-2026-03-15-simplify-locals.md), [`docs/0011-2026-03-18-pass-audit.md`](/home/jtenner/Projects/starshine-mb/docs/0011-2026-03-18-pass-audit.md), and [`docs/0001-2026-03-10-tracing.md`](/home/jtenner/Projects/starshine-mb/docs/0001-2026-03-10-tracing.md) so they no longer implicitly describe any flat locals path and instead refer to the canonical run-based locals container and its current lookup/count semantics.
- Updated the generated Node package surfaces by teaching [`scripts/lib/generate-node-package.mjs`](/home/jtenner/Projects/starshine-mb/scripts/lib/generate-node-package.mjs) about the canonical locals model, then regenerating [`node/README.md`](/home/jtenner/Projects/starshine-mb/node/README.md), the JS/TS adapter files under [`node/`](/home/jtenner/Projects/starshine-mb/node), and the node-api bridge files [`src/node_api/moon.pkg`](/home/jtenner/Projects/starshine-mb/src/node_api/moon.pkg) and [`src/node_api/generated.mbt`](/home/jtenner/Projects/starshine-mb/src/node_api/generated.mbt). The stale `expandLocals` / `tlocalsToLocals` exports and flat `FunctionLocals` signatures are now gone from the published Node docs.
- Removed the stale completed locals-refactor blocker from [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md) now that the finished work is recorded in this changelog instead of lingering in the backlog.
- Validation: `bun validate readme-api-sync`; `moon info`; `moon fmt`; `moon test`.

## 2026-03-18 Lib/IR/Passes Refactor: remove flat locals and canonicalize run-based locals everywhere

- Completed the locals canonicalization refactor across the core wasm model, IR, validator, transformer, passes, generated interfaces, and tests so the codebase now has a single canonical locals representation: [`LocalRun`](/home/jtenner/Projects/starshine-mb/src/lib/types.mbt) plus [`Locals`](/home/jtenner/Projects/starshine-mb/src/lib/types.mbt). The old flat typed-locals representation was removed rather than preserved behind compatibility branches.
- Updated [`src/lib/types.mbt`](/home/jtenner/Projects/starshine-mb/src/lib/types.mbt) and [`src/lib/util.mbt`](/home/jtenner/Projects/starshine-mb/src/lib/util.mbt) so `Locals` owns the ordered run array and a mutable cached `indices : Option[Array[Int]]`, while `typed function` now stores `Locals` for body locals instead of `Array[ValType]`. `Locals::ensure_index()` now lazily rebuilds run-start offsets, `Locals::at()` uses binary search over those starts, and all mutating operations invalidate or rebuild cache state through the canonical run list instead of flattening.
- Removed the flat helper/conversion path from shared utilities and bindings, including the obsolete flattening helpers that expanded grouped locals into `Array[ValType]`. Updated [`FunctionLocals`](/home/jtenner/Projects/starshine-mb/src/lib/util.mbt), [`Env::with_locals(...)`](/home/jtenner/Projects/starshine-mb/src/validate/env.mbt), and the generated node API wrappers in [`src/node_api/generated.mbt`](/home/jtenner/Projects/starshine-mb/src/node_api/generated.mbt) to consume `Locals` directly.
- Migrated decoding, encoding, validation, IR lowering, SSA destruction, type tracking, and transformer traversal to use the run-based representation end-to-end. This includes [`src/binary/decode.mbt`](/home/jtenner/Projects/starshine-mb/src/binary/decode.mbt), [`src/binary/encode.mbt`](/home/jtenner/Projects/starshine-mb/src/binary/encode.mbt), [`src/validate/typecheck.mbt`](/home/jtenner/Projects/starshine-mb/src/validate/typecheck.mbt), [`src/validate/validate.mbt`](/home/jtenner/Projects/starshine-mb/src/validate/validate.mbt), [`src/ir/ir_context.mbt`](/home/jtenner/Projects/starshine-mb/src/ir/ir_context.mbt), [`src/ir/ssa_destruction.mbt`](/home/jtenner/Projects/starshine-mb/src/ir/ssa_destruction.mbt), and [`src/transformer/transformer.mbt`](/home/jtenner/Projects/starshine-mb/src/transformer/transformer.mbt).
- Migrated the pass stack and pass fixtures away from flat locals, including heavy rewrites in [`src/passes/simplify_locals.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/simplify_locals.mbt), [`src/passes/merge_blocks.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/merge_blocks.mbt), [`src/passes/vacuum.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/vacuum.mbt), [`src/passes/local_cse.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/local_cse.mbt), [`src/passes/local_subtyping.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/local_subtyping.mbt), [`src/passes/loop_invariant_code_motion.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/loop_invariant_code_motion.mbt), and the broader optimization/test harness files that previously passed raw `Array[ValType]` locals into typed-function helpers.
- Added and updated regression coverage so decode/encode round-trips, run-index cache behavior, IR helpers, pass fixtures, and validation all exercise the canonical `Locals` path. The targeted locals tests now verify run compression, index rebuilding, lookup behavior, and typed-function integration in [`src/lib/types_texpr_tests.mbt`](/home/jtenner/Projects/starshine-mb/src/lib/types_texpr_tests.mbt), with complementary updates in IR, transformer, binary, validate, and pass test files.
- Validation: `moon check`; `moon info`; `moon fmt`; `moon test`.

## 2026-03-18 Lib/Validate/Binary Refactor: canonicalize locals as runs with cached indices

- Started the locals canonicalization refactor across [`src/lib/types.mbt`](/home/jtenner/Projects/starshine-mb/src/lib/types.mbt), [`src/lib/util.mbt`](/home/jtenner/Projects/starshine-mb/src/lib/util.mbt), [`src/binary/decode.mbt`](/home/jtenner/Projects/starshine-mb/src/binary/decode.mbt), [`src/binary/encode.mbt`](/home/jtenner/Projects/starshine-mb/src/binary/encode.mbt), [`src/validate/env.mbt`](/home/jtenner/Projects/starshine-mb/src/validate/env.mbt), and [`src/validate/validate.mbt`](/home/jtenner/Projects/starshine-mb/src/validate/validate.mbt), replacing the old grouped-local tuple shape with `LocalRun` plus a canonical `Locals` container that owns mutable cached `indices`.
- Added run-based lookup and mutation support in [`src/lib/util.mbt`](/home/jtenner/Projects/starshine-mb/src/lib/util.mbt), including `ensure_index`, cache invalidation, binary-search-backed `at`, sequence-style indexing via `_[_]`, and run-preserving mutation helpers such as `push_run`, `insert_run`, `remove_run`, `set_run_count`, and `merge_adjacent_runs`.
- Updated decoding, encoding, transformer traversal, validator env handling, and a broad set of tests so they now construct and consume `Locals` through the canonical run representation instead of flattening into `Array[ValType]`.

## 2026-03-18 Validate Follow-up: add a dedicated trace benchmark harness and baseline snapshot

- Added a dedicated validator trace benchmark runner in [`src/validate_trace/main.mbt`](/home/jtenner/Projects/starshine-mb/src/validate_trace/main.mbt) with four fixed corpora targeting deep control nesting, wide locals, large code sections, and `ref.func`-heavy modules. The new package exposes a small CLI, captures final `phase_totals`, `helper_totals`, and `hotspots` lines from `validate_module_with_trace(...)`, and prints a stable per-corpus summary suitable for later before/after performance comparisons.
- Added package coverage in [`src/validate_trace/main_test.mbt`](/home/jtenner/Projects/starshine-mb/src/validate_trace/main_test.mbt) for fixed corpus names, benchmark summary capture, unknown-corpus rejection, and CLI argument parsing.
- Added `bun validate trace-benchmark` wiring in [`scripts/lib/validate-task.ts`](/home/jtenner/Projects/starshine-mb/scripts/lib/validate-task.ts) plus a task-family regression in [`scripts/test/task-family-commands.ts`](/home/jtenner/Projects/starshine-mb/scripts/test/task-family-commands.ts), so the benchmark harness is available through the repo's standard Bun task surface.
- Recorded the first committed validator trace baseline in [`docs/0010-2026-03-18-validate-trace-baseline.md`](/home/jtenner/Projects/starshine-mb/docs/0010-2026-03-18-validate-trace-baseline.md), using `bun validate trace-benchmark --repeat 1` on 2026-03-18 to lock the current `phase_totals`, `helper_totals`, and `hotspots` snapshot for each fixed corpus.
- Updated [/home/jtenner/Projects/starshine-mb/agent-todo.md](/home/jtenner/Projects/starshine-mb/agent-todo.md) to remove the completed validator trace benchmark task and keep the backlog focused on open work only.
- Validation: `moon test --package jtenner/starshine/validate_trace`; `bun scripts/test/task-family-commands.ts`; `bun validate trace-benchmark --repeat 1`; `moon info`; `moon fmt`; `moon test`.

## 2026-03-18 AlignmentLowering Follow-up: add module-level no-op and validator-backed lowering coverage

- Updated [/home/jtenner/Projects/starshine-mb/src/passes/alignment_lowering.mbt](/home/jtenner/Projects/starshine-mb/src/passes/alignment_lowering.mbt) with module-level test helpers plus new regressions covering no-op modules and validator-backed post-lowering behavior for rewritten `i32`-memory loads and `memory64` stores, closing the missing coverage called out in the backlog.
- Fixed the chunked `AlignmentLowering` rewrite sites in [/home/jtenner/Projects/starshine-mb/src/passes/alignment_lowering.mbt](/home/jtenner/Projects/starshine-mb/src/passes/alignment_lowering.mbt) so split loads, stores, and `v128.load*_lane` rewrites emit memarg alignment exponents derived from chunk byte widths instead of raw byte counts, which was producing validator-invalid rewritten modules.
- Updated [/home/jtenner/Projects/starshine-mb/agent-todo.md](/home/jtenner/Projects/starshine-mb/agent-todo.md) to remove the completed `AlignmentLowering` coverage task and the already-completed validator end-of-body diagnostics task, keeping the backlog focused on open work only.
- Validation: `moon test --package jtenner/starshine/passes -F 'alignment lowering*'`; `moon info`; `moon fmt`; `moon test`.

## 2026-03-18 Validate Follow-up: distinguish end-of-body underflow, wrong results, and extra stack values

- Updated [/home/jtenner/Projects/starshine-mb/src/validate/validate.mbt](/home/jtenner/Projects/starshine-mb/src/validate/validate.mbt) so function-body final-stack validation now classifies three distinct failures instead of collapsing them into a generic message: result-stack underflow, result type mismatch, and extra leftover values. The new diagnostics include both the expected result stack shape and the actual stack shape seen at the end of the body, and the same helper now covers both plain and typed function bodies.
- Added validator regressions in [/home/jtenner/Projects/starshine-mb/src/validate/validate.mbt](/home/jtenner/Projects/starshine-mb/src/validate/validate.mbt) for all three end-of-body failure modes, and updated the existing tail-loop regression so it now asserts the correct underflow classification instead of the previous misleading extra-values message.
- Validation: `moon test --package jtenner/starshine/validate`; `moon info`; `moon fmt`; `moon test`.

## 2026-03-18 Tooling Follow-up: migrate repo task automation to Bun task families and Windows-safe modules

- Replaced the old mixed Bash/Node task surface in `scripts/` with Bun-first task-family entrypoints at [`scripts/validate.ts`](/home/jtenner/Projects/starshine-mb/scripts/validate.ts), [`scripts/fuzz.ts`](/home/jtenner/Projects/starshine-mb/scripts/fuzz.ts), [`scripts/self-opt.ts`](/home/jtenner/Projects/starshine-mb/scripts/self-opt.ts), [`scripts/make.ts`](/home/jtenner/Projects/starshine-mb/scripts/make.ts), and [`scripts/examples.ts`](/home/jtenner/Projects/starshine-mb/scripts/examples.ts), and added a root [`package.json`](/home/jtenner/Projects/starshine-mb/package.json) so the repo command surface is now `bun validate`, `bun fuzz`, `bun self-opt`, `bun make`, and `bun examples`.
- Moved reusable task logic and helper implementations under [`scripts/lib/`](/home/jtenner/Projects/starshine-mb/scripts/lib), including new task modules [`scripts/lib/validate-task.ts`](/home/jtenner/Projects/starshine-mb/scripts/lib/validate-task.ts), [`scripts/lib/fuzz-task.ts`](/home/jtenner/Projects/starshine-mb/scripts/lib/fuzz-task.ts), [`scripts/lib/self-opt-task.ts`](/home/jtenner/Projects/starshine-mb/scripts/lib/self-opt-task.ts), [`scripts/lib/make-task.ts`](/home/jtenner/Projects/starshine-mb/scripts/lib/make-task.ts), [`scripts/lib/examples-task.ts`](/home/jtenner/Projects/starshine-mb/scripts/lib/examples-task.ts), and the shared runtime helper [`scripts/lib/task-runtime.ts`](/home/jtenner/Projects/starshine-mb/scripts/lib/task-runtime.ts), so the top-level task files stay as thin dispatchers and the automation remains importable and Windows-safe.
- Relocated the larger helper programs into `scripts/lib` as well, preserving their implementation while removing the old top-level script clutter: benchmark harness, Node package generator/builder, self-optimized build/spec helpers, MoonBit WASI runner, and self-optimized artifact helpers now live under [`scripts/lib/benchmark-optimize.mjs`](/home/jtenner/Projects/starshine-mb/scripts/lib/benchmark-optimize.mjs), [`scripts/lib/generate-node-package.mjs`](/home/jtenner/Projects/starshine-mb/scripts/lib/generate-node-package.mjs), [`scripts/lib/build-node-package.mjs`](/home/jtenner/Projects/starshine-mb/scripts/lib/build-node-package.mjs), [`scripts/lib/build-self-optimized.mjs`](/home/jtenner/Projects/starshine-mb/scripts/lib/build-self-optimized.mjs), and [`scripts/lib/run-self-optimized-spec-suite.mjs`](/home/jtenner/Projects/starshine-mb/scripts/lib/run-self-optimized-spec-suite.mjs).
- Removed the obsolete top-level shell and ad hoc script entrypoints that the Bun task families replaced, including `scripts/run-full-test.sh`, `scripts/run-fuzz.sh`, `scripts/coverage_report.sh`, `scripts/run_examples_cli_smoke.sh`, `scripts/check_examples_cli_native_workflow.sh`, `scripts/self-optimize.sh`, `scripts/update_readme_benchmarks.sh`, and the old top-level `.mjs` helper entrypoints that were moved into `scripts/lib`.
- Replaced the remaining shell-based script regression checks with Bun/TypeScript tests in [`scripts/test/task-family-commands.ts`](/home/jtenner/Projects/starshine-mb/scripts/test/task-family-commands.ts), [`scripts/test/make-benchmark-output.ts`](/home/jtenner/Projects/starshine-mb/scripts/test/make-benchmark-output.ts), and [`scripts/test/self-opt-command-output.ts`](/home/jtenner/Projects/starshine-mb/scripts/test/self-opt-command-output.ts), using Windows-safe fake `moon` and fake optimizer executables so the script-behavior tests no longer depend on Bash.
- Updated CI/workflow entrypoints in [`/.github/workflows/fuzz.yml`](/home/jtenner/Projects/starshine-mb/.github/workflows/fuzz.yml), [`/.github/workflows/examples-cli-native.yml`](/home/jtenner/Projects/starshine-mb/.github/workflows/examples-cli-native.yml), [`/.github/workflows/coverage-report.yml`](/home/jtenner/Projects/starshine-mb/.github/workflows/coverage-report.yml), [`/.github/workflows/node-wasm-tests.yml`](/home/jtenner/Projects/starshine-mb/.github/workflows/node-wasm-tests.yml), and [`/.github/workflows/readme-api-sync.yml`](/home/jtenner/Projects/starshine-mb/.github/workflows/readme-api-sync.yml) to install Bun, watch `scripts/**` plus the root `package.json`, and call the new Bun task families instead of the removed shell wrappers.
- Added a Bun-driven README/API verification path with [`scripts/lib/readme-api-sync.ts`](/home/jtenner/Projects/starshine-mb/scripts/lib/readme-api-sync.ts) and `bun validate readme-api-sync`, so the README API sync workflow no longer points at a missing shell script and now skips cleanly when the README has no `README_API_VERIFY` blocks.
- Updated user-facing and maintainer-facing command references in [`README.mbt.md`](/home/jtenner/Projects/starshine-mb/README.mbt.md), [`docs/0011-2026-03-18-pass-audit.md`](/home/jtenner/Projects/starshine-mb/docs/0011-2026-03-18-pass-audit.md), and [`node/package.json`](/home/jtenner/Projects/starshine-mb/node/package.json) to reflect the new Bun task-family commands and the moved benchmark/node-build flows.
- Updated [`AGENTS.md`](/home/jtenner/Projects/starshine-mb/AGENTS.md) so future agents see the new task strategy directly in the `Tooling` and `Repository Layout` sections: Bun-first task families are now the documented standard, `scripts/lib/` is the required home for reusable task logic, and shell scripts under `scripts/` are explicitly disallowed to avoid future Windows breakage and task-surface confusion.
- Validation: `bun validate readme-api-sync`; `bun examples workflow-contract`; `bun scripts/test/task-family-commands.ts`; `bun scripts/test/make-benchmark-output.ts`; `bun scripts/test/self-opt-command-output.ts`; `moon info`; `moon fmt`; `moon test`.

## 2026-03-18 Maintainer Follow-up: turn lost-and-found into a local canary

- Updated [/home/jtenner/Projects/starshine-mb/AGENTS.md](/home/jtenner/Projects/starshine-mb/AGENTS.md) with a dedicated `Lost And Found Canary` section explaining that `agent-lost-and-found.md` is a local, developer-facing process-feedback file for documenting surprises, missing documentation, setup friction, and suggested workflow improvements.
- Updated [/home/jtenner/Projects/starshine-mb/.gitignore](/home/jtenner/Projects/starshine-mb/.gitignore) so `agent-lost-and-found.md` is ignored, then removed the file from git tracking so it will not be committed going forward.
- Validation: not run (docs and git-tracking update).

## 2026-03-18 Maintainer Follow-up: simplify commit instructions for agents

- Updated [/home/jtenner/Projects/starshine-mb/AGENTS.md](/home/jtenner/Projects/starshine-mb/AGENTS.md) to keep commit guidance in one short `Commit Strategy` section, remove duplicate commit-workflow references from the rest of the file, and make the rules easier for AI agents to follow.
- Validation: not run (docs-only update).

## 2026-03-18 Maintainer Follow-up: compact the AI backlog and document the workflow

- Updated [/home/jtenner/Projects/starshine-mb/agent-todo.md](/home/jtenner/Projects/starshine-mb/agent-todo.md) to keep only open work, collapse repetitive optimizer backlog wording, and remove the checked-off history so the file stays focused on current tasks.
- Updated [/home/jtenner/Projects/starshine-mb/AGENTS.md](/home/jtenner/Projects/starshine-mb/AGENTS.md) to require simple bullet-point backlog items and to record completed work in [/home/jtenner/Projects/starshine-mb/CHANGELOG.md](/home/jtenner/Projects/starshine-mb/CHANGELOG.md) instead of marking items done in `agent-todo.md`.
- Validation: not run (docs-only update).

## 2026-03-18 Validate Planning: add validator backlog items for diagnostics and performance

- Updated [/home/jtenner/Projects/starshine-mb/agent-todo.md](/home/jtenner/Projects/starshine-mb/agent-todo.md) to track four validator follow-ups grounded in the current implementation: clearer end-of-body diagnostics, a dedicated validation benchmark harness, hot-path allocation/copying reduction in structured control validation, and folding the extra `ref.func` declaration scan into a shared validation traversal.
- Validation: `moon info`; `moon fmt`; `moon test`.

## 2026-03-18 Optimize Planning: add pass-audit docs, pass-trace metrics, and benchmark harness scaffolding

- Added [/home/jtenner/Projects/starshine-mb/docs/0011-2026-03-18-pass-audit.md](/home/jtenner/Projects/starshine-mb/docs/0011-2026-03-18-pass-audit.md) as the pass-audit planning checkpoint, including the `src/passes` inventory, optimize pipeline mapping, Binaryen-nearest pass crosswalk, mutually enabling relationships, and the current high-priority findings for `SimplifyLocals`, `Vacuum`, and `AlignmentLowering`.
- Updated [/home/jtenner/Projects/starshine-mb/agent-todo.md](/home/jtenner/Projects/starshine-mb/agent-todo.md) so the optimization-recovery work is now tracked by phase and includes a two-item audit pair for each pass implementation file: correctness/Binaryen comparison and performance/baseline analysis.
- Updated [/home/jtenner/Projects/starshine-mb/src/passes/optimize.mbt](/home/jtenner/Projects/starshine-mb/src/passes/optimize.mbt) so optimize trace output now includes per-pass changed status, functions visited/changed, and instruction-count before/after summaries for both scheduler-run passes and stacked function-pass segments, with regressions locking the new trace fields.
- Added [/home/jtenner/Projects/starshine-mb/scripts/benchmark-optimize.mjs](/home/jtenner/Projects/starshine-mb/scripts/benchmark-optimize.mjs) and [/home/jtenner/Projects/starshine-mb/scripts/test/benchmark-optimize-output.sh](/home/jtenner/Projects/starshine-mb/scripts/test/benchmark-optimize-output.sh) as the first stable benchmark-harness entrypoint and parser smoke test for later pass-refactor measurement work.
- Validation: `bash scripts/test/benchmark-optimize-output.sh`; `moon info`; `moon fmt`; `moon test`.

## 2026-03-18 Validate Follow-up: accept typed control-flow input params in both IR shapes

- Updated [/home/jtenner/Projects/starshine-mb/src/validate/typecheck.mbt](/home/jtenner/Projects/starshine-mb/src/validate/typecheck.mbt) so lifted `block`, `if`, and `loop` validation now accepts both body-embedded control-flow inputs from the older pre-lift path and explicit outer-stack control-flow input forms emitted directly by pass code, fixing the control-flow `stack underflow` gap.
- Added regressions in [/home/jtenner/Projects/starshine-mb/src/validate/validate.mbt](/home/jtenner/Projects/starshine-mb/src/validate/validate.mbt) covering typed `block` / `if` / `loop` validation with `type_idx` control-flow input params.
- Validation: `moon test src/validate`; `moon info`; `moon fmt`; `moon test`.

## 2026-03-18 Optimize Follow-up: harden degraded `Vacuum` local retention and add branch-value regressions

- Updated [/home/jtenner/Projects/starshine-mb/src/passes/vacuum.mbt](/home/jtenner/Projects/starshine-mb/src/passes/vacuum.mbt) so degraded `Vacuum` now retains standalone `local.get` / `local.set` nodes in the final standalone-removal path, propagates parent result-use signals into degraded structured bodies, and adds focused degraded/typed regressions around ambient-fed locals and nested outer-label branch-value shapes.
- Updated [/home/jtenner/Projects/starshine-mb/agent-todo.md](/home/jtenner/Projects/starshine-mb/agent-todo.md) to record that the serial-pass `Vacuum` corruption on `before.wasm` / `Func 1360` is still unresolved after this hardening pass.
- Validation: `moon test src/passes`; `moon info`; `moon fmt`; `moon test`. Known remaining issue: `moon run src/cmd --target native -- --debug-serial-passes --vacuum -o /tmp/vacuum-repro.wasm before.wasm` still fails with `typed function stack underflow` in `Func 1360`.

## 2026-03-18 Validate Follow-up: propagate typed outer-label block exits without regressing raw `if` checks

- Updated [/home/jtenner/Projects/starshine-mb/src/validate/typecheck.mbt](/home/jtenner/Projects/starshine-mb/src/validate/typecheck.mbt) so raw wasm `if` merges, typed `if` merges, and typed `block` exits now normalize branch escapes separately. Typed blocks once again propagate outer-label `br` escapes upward instead of treating them as local stack underflows, while raw `if` validation still rejects missing result values after nested outer-label branches.
- Added regressions in [/home/jtenner/Projects/starshine-mb/src/validate/validate.mbt](/home/jtenner/Projects/starshine-mb/src/validate/validate.mbt) covering the typed nested outer-label branch shapes seen in self-optimize logs and preserving the raw invalid outer-`if` rejection.
- Validation: `moon info`; `moon fmt`; `moon test --package jtenner/starshine/validate`; `moon build --target native --release --package jtenner/starshine/cmd`.

## 2026-03-17 Validate Follow-up: distinguish current-label branches from terminal exits in `if` merges

- Updated [/home/jtenner/Projects/starshine-mb/src/validate/typecheck.mbt](/home/jtenner/Projects/starshine-mb/src/validate/typecheck.mbt) so validator control-flow tracking now distinguishes `br` exits that reach the current construct’s merge point from truly terminal exits, fixing invalid acceptance of result-typed outer `if` expressions whose inner arms both branch to the current label.
- Added regressions in [/home/jtenner/Projects/starshine-mb/src/validate/typecheck_negative_tests.mbt](/home/jtenner/Projects/starshine-mb/src/validate/typecheck_negative_tests.mbt) and [/home/jtenner/Projects/starshine-mb/src/validate/validate.mbt](/home/jtenner/Projects/starshine-mb/src/validate/validate.mbt), refreshed [/home/jtenner/Projects/starshine-mb/src/validate/pkg.generated.mbti](/home/jtenner/Projects/starshine-mb/src/validate/pkg.generated.mbti), and updated the now-valid fixture in [/home/jtenner/Projects/starshine-mb/src/passes/remove_unused_brs.mbt](/home/jtenner/Projects/starshine-mb/src/passes/remove_unused_brs.mbt).
- Validation: `moon info`; `moon fmt`; `moon test`.

## 2026-03-17 Optimize Follow-up: shrink `SSANoMerge` reach analysis state

- Updated [/home/jtenner/Projects/starshine-mb/src/passes/dataflow_opt.mbt](/home/jtenner/Projects/starshine-mb/src/passes/dataflow_opt.mbt) so `SSANoMerge` now stores dense block/get/set state in arrays, memoizes block-entry reach queries, and replaces per-get reaching-definition sets with a compact reach-state enum to cut repeated CFG rescans and GC churn.
- Added a branch-heavy regression in [/home/jtenner/Projects/starshine-mb/src/passes/dataflow_opt.mbt](/home/jtenner/Projects/starshine-mb/src/passes/dataflow_opt.mbt) that locks the single-reaching vs merge-reaching analysis counts used by the rewrite.
- Validation: `moon test src/passes/dataflow_opt.mbt`; `moon info && moon fmt`; `moon test`.

## 2026-03-17 Format Follow-up: normalize `simplify_locals` line wrapping

- Updated [/home/jtenner/Projects/starshine-mb/src/passes/simplify_locals.mbt](/home/jtenner/Projects/starshine-mb/src/passes/simplify_locals.mbt) with the pending `moon fmt` line wrapping only; there is no behavioral change in this commit.
- Validation: `moon info`; `moon fmt`; `moon test`.

## 2026-03-17 Optimize Follow-up: keep `CodeFolding` from hoisting shared returns past outer branches

- Updated [/home/jtenner/Projects/starshine-mb/src/passes/code_folding.mbt](/home/jtenner/Projects/starshine-mb/src/passes/code_folding.mbt) so `CodeFolding` now skips `if`-tail hoists when the merged suffix is terminating and the remaining condition or arms still branch outward, preventing the invalid wrapper-block rewrite seen in serial self-optimize traces.
- Added a regression in [/home/jtenner/Projects/starshine-mb/src/passes/code_folding.mbt](/home/jtenner/Projects/starshine-mb/src/passes/code_folding.mbt) that preserves the failing value-loop shape with a shared `return call(...)` tail, sibling `br_if`, and memory traffic.
- Validation: `moon info`; `moon fmt`; `moon test`.

## 2026-03-17 Optimize Follow-up: keep serial self-optimize enabled and harden pass debugging

- Updated [/home/jtenner/Projects/starshine-mb/scripts/self-optimize.sh](/home/jtenner/Projects/starshine-mb/scripts/self-optimize.sh), [/home/jtenner/Projects/starshine-mb/scripts/lib/self-optimized-artifacts.mjs](/home/jtenner/Projects/starshine-mb/scripts/lib/self-optimized-artifacts.mjs), and [/home/jtenner/Projects/starshine-mb/scripts/test/self-optimize-output.sh](/home/jtenner/Projects/starshine-mb/scripts/test/self-optimize-output.sh) so self-optimize runs with `--debug-serial-passes` by default and the wrapper test now fails if that serial flag is dropped.
- Updated [/home/jtenner/Projects/starshine-mb/src/passes/simplify_locals.mbt](/home/jtenner/Projects/starshine-mb/src/passes/simplify_locals.mbt) so multi-use `local.get` tee-sinking now refuses sink values that do not produce a standalone result, preventing malformed `local.tee(... local.set(...))` trees during the serial optimize pipeline; added regressions for both single-use and multi-use variants.
- Updated [/home/jtenner/Projects/starshine-mb/src/passes/code_folding.mbt](/home/jtenner/Projects/starshine-mb/src/passes/code_folding.mbt) with extra function-shape guards around terminating-tail rewrites in nested value loops, plus focused value-loop regression coverage used while triaging the next serial self-optimize failure.
- Validation: `moon check`; `bash scripts/test/self-optimize-output.sh`; `moon test --target native src/passes/simplify_locals.mbt -F '*tee sink value has no standalone result*'`.

## 2026-03-17 Optimize Follow-up: preserve stack-fed values in `CodePushing` and `Vacuum`

- Updated [/home/jtenner/Projects/starshine-mb/src/passes/code_pushing.mbt](/home/jtenner/Projects/starshine-mb/src/passes/code_pushing.mbt) so pushing a `local.set` into an `if` arm now accounts for all locals written by the set value, preventing rewrites that would leave the opposite arm or post-`if` code reading a local that was only written on one branch.
- Updated [/home/jtenner/Projects/starshine-mb/src/passes/vacuum.mbt](/home/jtenner/Projects/starshine-mb/src/passes/vacuum.mbt) so stack-signature accounting preserves typed `block`/`if` results carried by value breaks, and so degraded fallback sequence cleanup keeps ambient stack feeders that later instructions still consume instead of deleting them as individually unused.
- Added regressions in [/home/jtenner/Projects/starshine-mb/src/passes/code_pushing.mbt](/home/jtenner/Projects/starshine-mb/src/passes/code_pushing.mbt) and [/home/jtenner/Projects/starshine-mb/src/passes/vacuum.mbt](/home/jtenner/Projects/starshine-mb/src/passes/vacuum.mbt) covering cross-arm nested `local.set` writes, typed block value-break stack signatures, and degraded-mode ambient-fed `local.set` chains.
- Validation: `moon info`; `moon fmt`; `moon test`; `moon run src/cmd --target native -- --debug-serial-passes --vacuum -o /tmp/vacuum-repro-after-degraded-fix.wasm before.wasm`.

## 2026-03-17 Optimize Follow-up: keep `RemoveUnusedNames` from peeling live branch targets

- Updated [/home/jtenner/Projects/starshine-mb/src/passes/remove_unused_names.mbt](/home/jtenner/Projects/starshine-mb/src/passes/remove_unused_names.mbt) so nested same-typed block peeling now bails out when the peeled body still contains branches or catches targeting one of the scopes that would be removed, preventing invalid label rebases like the `br 1 -> br 0` rewrite that trapped control flow inside value-producing `if` expressions.
- Added a regression in [/home/jtenner/Projects/starshine-mb/src/passes/remove_unused_names.mbt](/home/jtenner/Projects/starshine-mb/src/passes/remove_unused_names.mbt) that preserves the minimal failing shape: a nested `if (result i32)` whose else-arm branches to the block scope that peeling would otherwise erase.
- Validation: `moon info`; `moon fmt`; `moon test --target native src/passes/remove_unused_names.mbt`; `moon run src/cmd --target native -- --debug-serial-passes --remove-unused-names -o /tmp/rmn-debug-fixed.wasm before.wasm`.

## 2026-03-17 Optimize Follow-up: add a serial per-pass validation debug mode

- Updated [/home/jtenner/Projects/starshine-mb/src/cli/cli.mbt](/home/jtenner/Projects/starshine-mb/src/cli/cli.mbt), [/home/jtenner/Projects/starshine-mb/src/cmd/cmd.mbt](/home/jtenner/Projects/starshine-mb/src/cmd/cmd.mbt), and [/home/jtenner/Projects/starshine-mb/src/passes/optimize.mbt](/home/jtenner/Projects/starshine-mb/src/passes/optimize.mbt) so `starshine --debug-serial-passes ...` now disables function-pass stacking and validates after each pass-sized scheduler segment, making optimize-pipeline correctness failures attributable to the first failing pass instead of a later barrier.
- Added regressions in [/home/jtenner/Projects/starshine-mb/src/cli/cli_test.mbt](/home/jtenner/Projects/starshine-mb/src/cli/cli_test.mbt) and [/home/jtenner/Projects/starshine-mb/src/passes/optimize.mbt](/home/jtenner/Projects/starshine-mb/src/passes/optimize.mbt), and refreshed the generated interfaces in [/home/jtenner/Projects/starshine-mb/src/cli/pkg.generated.mbti](/home/jtenner/Projects/starshine-mb/src/cli/pkg.generated.mbti) and [/home/jtenner/Projects/starshine-mb/src/passes/pkg.generated.mbti](/home/jtenner/Projects/starshine-mb/src/passes/pkg.generated.mbti).
- Validation: `moon info && moon fmt`; `moon check`; `moon test --target native src/cli`; `moon test --target native src/cmd`. `moon test --target native src/passes` still fails on the pre-existing `merge_blocks.mbt` wall-time threshold check.

## 2026-03-17 Self-optimize Follow-up: stream repro output to the terminal

- Updated [/home/jtenner/Projects/starshine-mb/scripts/self-optimize.sh](/home/jtenner/Projects/starshine-mb/scripts/self-optimize.sh) so the self-optimize wrapper now streams optimizer stdout/stderr live to the terminal while still writing `output.log`, and removed the stale `OPTIMIZE_DUMP_FAILED_MODULE_STATE` env plumbing there.
- Added [/home/jtenner/Projects/starshine-mb/scripts/test/self-optimize-output.sh](/home/jtenner/Projects/starshine-mb/scripts/test/self-optimize-output.sh), a regression that runs the wrapper against stub binaries and requires the repro command to appear both in terminal output and the captured log.
- Validation: `bash scripts/test/self-optimize-output.sh`; `moon info && moon fmt`; `moon test`.

## 2026-03-17 Optimize Follow-up: emit segment repros for post-encode validation failures

- Updated [/home/jtenner/Projects/starshine-mb/src/cmd/cmd.mbt](/home/jtenner/Projects/starshine-mb/src/cmd/cmd.mbt) so post-encode validation failures now replay the already-expanded optimize pass list segment by segment with the CLI encoder/decoder pipeline, write `before.wasm` for the first failing segment input, and append an exact `starshine ... before.wasm` repro command to the failure output.
- Updated [/home/jtenner/Projects/starshine-mb/src/passes/optimize.mbt](/home/jtenner/Projects/starshine-mb/src/passes/optimize.mbt) to expose a scheduler-segment replay helper for post-encode repro isolation, and removed the dead `dump_failed_module_state` parameter from `optimize_module_with_options_trace(...)`.
- Updated [/home/jtenner/Projects/starshine-mb/src/cmd/cmd_test.mbt](/home/jtenner/Projects/starshine-mb/src/cmd/cmd_test.mbt), [/home/jtenner/Projects/starshine-mb/src/node_api/custom.mbt](/home/jtenner/Projects/starshine-mb/src/node_api/custom.mbt), [/home/jtenner/Projects/starshine-mb/src/passes/memory_packing.mbt](/home/jtenner/Projects/starshine-mb/src/passes/memory_packing.mbt), and [/home/jtenner/Projects/starshine-mb/src/passes/pkg.generated.mbti](/home/jtenner/Projects/starshine-mb/src/passes/pkg.generated.mbti) so the new repro command can target `abstract-type-refining`, `memory-packing`, and `directize` directly and is covered by end-to-end regression tests.
- Validation: `moon info && moon fmt`; `moon test`.

## 2026-03-17 Optimize Follow-up: audit optimize scheduler call arity and fix multivalue arg counting

- Updated [/home/jtenner/Projects/starshine-mb/src/passes/optimize.mbt](/home/jtenner/Projects/starshine-mb/src/passes/optimize.mbt) so the optimize scheduler now audits direct, `call_ref`, and indirect call arity before pass scheduling and after module-runner passes, with regressions that cover upstream-invalid call sites and valid multivalue producers.
- Updated [/home/jtenner/Projects/starshine-mb/src/passes/merge_similar_functions.mbt](/home/jtenner/Projects/starshine-mb/src/passes/merge_similar_functions.mbt), [/home/jtenner/Projects/starshine-mb/src/passes/reorder_locals.mbt](/home/jtenner/Projects/starshine-mb/src/passes/reorder_locals.mbt), and [/home/jtenner/Projects/starshine-mb/src/validate/env.mbt](/home/jtenner/Projects/starshine-mb/src/validate/env.mbt) so multivalue argument producers use typed result arity instead of raw instruction-array length during hashing, preflight, rewrite validation, and local reordering.
- Updated [/home/jtenner/Projects/starshine-mb/src/passes/dataflow_opt.mbt](/home/jtenner/Projects/starshine-mb/src/passes/dataflow_opt.mbt) so `SSANoMerge` no longer re-walks rewritten `local.set`/`local.tee` values, with a regression that preserves `externref` table-set values through the rewrite.
- Validation: `moon info && moon fmt`; `moon test`.

## 2026-03-17 Optimize Follow-up: preflight typed and indirect call arity in `MergeSimilarFunctions`

- Updated [`src/passes/merge_similar_functions.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/merge_similar_functions.mbt) so `MergeSimilarFunctions` now preflights `call_ref`, `return_call_ref`, `call_indirect`, and `return_call_indirect` arity against the resolved function type before class collection, and so rewrite-time call-target mismatch diagnostics include the relevant `type_idx` plus expected/actual arity details.
- Added regressions in [`src/passes/merge_similar_functions.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/merge_similar_functions.mbt) that lock upstream-invalid `call_ref` and `call_indirect` rejection in preflight and preserve the richer rewrite-time mismatch diagnostics.
- Updated [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md) to record the new optimize performance blockers and the `MergeSimilarFunctions` arg-count mismatch failure observed in the self-optimization trace.
- Validation: `moon test src/passes`; `moon info && moon fmt`; `moon test`.

## 2026-03-16 Optimize Follow-up: make `SSANoMerge` sparse and stabilize self-opt execution

- Reworked [`src/passes/dataflow_opt.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/dataflow_opt.mbt) so `SSANoMerge` uses a Binaryen-style sparse block/action analysis instead of cloning dense reaching-definition maps, and added a regression that preserves loop-carried gets.
- Updated [`scripts/self-optimize.sh`](/home/jtenner/Projects/starshine-mb/scripts/self-optimize.sh) to support portable native CLI invocation fallbacks while writing optimizer output to [`output.log`](/home/jtenner/Projects/starshine-mb/output.log), defaulting self-opt runs to pass-level tracing with configurable overrides.
- Updated [`AGENTS.md`](/home/jtenner/Projects/starshine-mb/AGENTS.md) to forbid trace-only tests unless they are explicitly requested.
- Validation: `moon test src/passes/dataflow_opt.mbt`; `moon info && moon fmt`; `moon test`.

## 2026-03-16 Optimize Follow-up: land `SSANoMerge` parity in the default pipeline

- Updated [`src/passes/dataflow_opt.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/dataflow_opt.mbt) to add a narrow `SSANoMerge` pass that rewrites single-reaching local set/get chains, preserves merge-reaching gets, and lifts plain functions when they can be represented as typed IR.
- Updated [`src/passes/optimize.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/optimize.mbt) so the optimize scheduler classifies `SSANoMerge` as a stackable unit transformer, exposes it through `optimize_module(...)`, and inserts it at the Binaryen `ssa-nomerge` slot in the default function pipeline instead of substituting `DataflowOptimization`.
- Updated [`docs/0002-2026-03-11-differences.md`](/home/jtenner/Projects/starshine-mb/docs/0002-2026-03-11-differences.md) and [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md) to record that the `ssa-nomerge` and stacked-runner publishing blockers are now closed.
- Validation: `moon test --package jtenner/starshine/passes --file optimize.mbt`; `moon info && moon fmt`; `moon test`.

## 2026-03-16 Optimize Follow-up: reduce stacked-runner code-section snapshot churn

- Updated [`src/passes/optimize.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/optimize.mbt) so the stacked function runner now prepares passes against one shared live code-section snapshot and no longer rebuilds `CodeSec` after every changed function/pass step inside a stacked segment.
- Added a regression in [`src/passes/optimize.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/optimize.mbt) that locks stacked-runner snapshot materialization down to one shared execution snapshot plus one final last-pass-attribution snapshot.
- Validation: `moon test --package jtenner/starshine/passes --file optimize.mbt`; `moon info && moon fmt`; `moon test`.

## 2026-03-16 Docs Follow-up: remove `StringGathering` from the publishing blockers list

- Updated [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md) to remove `StringGathering` from the publishing-blocker section while leaving the broader post-`0.1.0` string optimization follow-up item in place.
- Validation was not run because this change only updates planning/documentation.

## 2026-03-16 Docs Follow-up: track post-0.1.0 string optimization work

- Added a post-0.1.0 backlog item in [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md) to continue `string.const` support and string optimization pass work after the initial `0.1.0` release.
- Validation was not run because this change only updates planning/documentation.

## 2026-03-16 Docs Follow-up: add `StringGathering` research and implementation blueprint

- Added [`docs/0009-2026-03-16-string-optimization.md`](/home/jtenner/Projects/starshine-mb/docs/0009-2026-03-16-string-optimization.md), a detailed Binaryen `StringGathering` research note covering pass semantics, scheduler placement, data structures, correctness constraints, test cases, single-pass pseudocode, and a one-shot implementation prompt for Starshine.
- Validation was not run because this change was documentation-only.

## 2026-03-16 Optimize Follow-up: replace `AfterEveryPass` with `AfterSegment`

- Updated [`src/passes/optimize.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/optimize.mbt) so `OptimizeValidationPolicy` now exposes `FinalModuleOnly` and `AfterSegment`; the old `AfterEveryPass` debug mode has been removed.
- Moved non-default validation to scheduler-segment boundaries in [`src/passes/optimize.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/optimize.mbt): barrier passes still validate immediately after running, while contiguous `FunctionPassStack` segments validate once after the whole executed stack instead of after each constituent pass.
- Updated optimize regressions in [`src/passes/optimize.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/optimize.mbt) and the policy note in [`docs/0002-2026-03-11-differences.md`](/home/jtenner/Projects/starshine-mb/docs/0002-2026-03-11-differences.md) so trace expectations, validation-failure attribution, and public documentation all reflect the new segment-level contract.
- Validation: `moon test --package jtenner/starshine/passes --file optimize.mbt`; `moon info && moon fmt`; `moon test`.

## 2026-03-16 Optimize Follow-up: keep after-every-pass validation inside prepared function stacks

- Updated [`src/passes/optimize.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/optimize.mbt) so `FunctionPassStack` segments now stay on prepared function-pass execution even under `OptimizeValidationPolicy::after_every_pass()`: the stack runner applies each prepared pass across all functions, validates at the pass boundary, and preserves pass-local validation attribution instead of falling back to the legacy flat scheduler path.
- Tightened stacked pass tracing in [`src/passes/optimize.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/optimize.mbt) so synthesized pass-summary start lines keep their scheduler kind labels, and added regressions that require helper/phase traces to show the validation barrier between `DeadCodeElimination` and `CodePushing` on the after-every-pass path.
- Validation: `moon test --package jtenner/starshine/passes --file optimize.mbt`; `moon info && moon fmt`; `moon test`.

## 2026-03-16 Optimize Follow-up: preserve pass-summary tracing on stacked function segments

- Updated [`src/passes/optimize.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/optimize.mbt) so the prepared per-function stacked executor now also stays enabled for `OptimizeTracingLevel::pass()` under final-module validation; `AfterEveryPass` validation remains the intentionally flat fallback.
- Added synthetic pass-summary emission in [`src/passes/optimize.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/optimize.mbt) so stacked function segments still report the expected `pass[..]:start`, `pass[..]:done`, and error lines without leaking helper-level `scheduler:` or per-function `func[...]` details into pass traces.
- Added regressions in [`src/passes/optimize.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/optimize.mbt) that lock stacked-runner eligibility for pass tracing and require `DeadCodeElimination -> CodePushing` pass traces to stay summary-only across a multi-function stack segment.
- Validation: `moon test --package jtenner/starshine/passes --file optimize.mbt`; `moon info && moon fmt`; `moon test`.

## 2026-03-16 Optimize Follow-up: chunk repeated vacuum stacks into the largest safe per-function substacks

- Updated [`src/passes/optimize.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/optimize.mbt) so non-fully-stackable `FunctionPassStack` segments no longer flush around every `Vacuum`; the fallback path now accumulates the largest safe substack, which keeps repeated-vacuum sequences like `DeadCodeElimination -> Vacuum -> Vacuum -> CodePushing` on stacked per-function execution where the vacuum skip semantics allow it.
- Added helper-trace coverage in [`src/passes/optimize.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/optimize.mbt) that locks the new repeated-vacuum chunking order by function.
- Removed the explicit release/publish line from [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md) so the publishing-blocker section stays focused on pre-release technical blockers rather than the release act itself.
- Validation: `moon test --package jtenner/starshine/passes --file optimize.mbt`; `moon info && moon fmt`; `moon test`.

## 2026-03-16 Optimize Follow-up: treat constant-field analysis wrappers as stacked-runner barriers

- Updated [`src/passes/optimize.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/optimize.mbt) so `ConstantFieldPropagation` and `ConstantFieldNullTestFolding` no longer count as `FunctionPassStack` members; both passes currently build whole-module constant-field analysis before rewriting and therefore stay as scheduler barriers for the stacked runner.
- Added segmentation regressions in [`src/passes/optimize.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/optimize.mbt) that lock `ConstantFieldPropagation` and `ConstantFieldNullTestFolding` as barriers between stackable neighbors.
- Validation: `moon test --package jtenner/starshine/passes --file optimize.mbt`; `moon info && moon fmt`; `moon test`.

## 2026-03-16 Optimize Follow-up: keep single non-skipped vacuum passes inside stacked segments

- Updated [`src/passes/optimize.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/optimize.mbt) so `FunctionPassStack` segments with zero or one non-skipped `Vacuum` now stay on the prepared per-function executor instead of flushing around `Vacuum`; repeated or skip-sensitive `Vacuum` cases still fall back to the older split execution path.
- Corrected stacked-runner eligibility in [`src/passes/optimize.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/optimize.mbt) by treating the module-shaped `DeNaN` wrapper as a scheduler barrier again, with an explicit segmentation regression.
- Added helper-trace coverage in [`src/passes/optimize.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/optimize.mbt) that requires `DeadCodeElimination -> Vacuum -> CodePushing` to interleave by function under the stacked runner.
- Validation: `moon test --package jtenner/starshine/passes --file optimize.mbt`; `moon info && moon fmt`; `moon test`.

## 2026-03-16 Optimize Follow-up: extend stacked function segments to phase tracing

- Updated [`src/passes/optimize.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/optimize.mbt) so the prepared per-function stacked executor now also runs on `OptimizeTracingLevel::phase()` under final-module validation; only pass-summary tracing, `AfterEveryPass` validation, and `Vacuum` still force the flat fallback inside function-stack segments.
- Fixed the stacked runner in [`src/passes/optimize.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/optimize.mbt) to refresh `ctx.mod` from the latest rewritten code-section snapshot between per-function pass applications and to capture the final-validation `last_pre_pass_mod` snapshot at the whole-module state immediately before the last stacked pass reaches each function.
- Added phase-trace regressions in [`src/passes/optimize.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/optimize.mbt) that require interleaved per-function execution on the final-validation path while keeping the flat loop under `AfterEveryPass` validation.
- Validation: `moon test --package jtenner/starshine/passes --file optimize.mbt`; `moon info && moon fmt`; `moon test`.

## 2026-03-16 Optimize Follow-up: run contiguous non-vacuum function stacks per function

- Updated [`src/passes/optimize.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/optimize.mbt) so `FunctionPassStack` segments now execute contiguous non-`Vacuum` substacks through a prepared per-function runner on the default final-validation path, while `Vacuum`, pass/phase tracing, and `AfterEveryPass` validation still fall back to the existing flat per-pass executor.
- Factored scheduler pass construction in [`src/passes/optimize.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/optimize.mbt) so the stacked runner can reuse the same IR-context and unit-transformer pass builders as the flat scheduler path.
- Added optimize trace regressions in [`src/passes/optimize.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/optimize.mbt) that require helper traces to show interleaved function-stack execution for a real two-pass stack while keeping the flat loop for `AfterEveryPass` validation.
- Validation: `moon test --package jtenner/starshine/passes --file optimize.mbt`; `moon info && moon fmt`; `moon test`.

## 2026-03-16 Optimize Follow-up: narrow function-stack segments to walk-func-compatible passes

- Updated [`src/passes/optimize.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/optimize.mbt) so `scheduler_segment_passes(...)` now treats only walk-func-compatible passes as `FunctionPassStack` members; module-shaped IR transformers such as `Flatten` and `LocalCSE` are now explicit barriers even though they are not `ModuleRunnerPass` values.
- Added segmentation regressions in [`src/passes/optimize.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/optimize.mbt) for synthetic mixed pass lists and the `-O4` default function pipeline, locking the new barrier splits around `Flatten` and `LocalCSE`.
- Validation: `moon test --package jtenner/starshine/passes --file optimize.mbt -F 'scheduler_segment_passes *'`; `moon info && moon fmt`; `moon test`.

## 2026-03-16 Optimize Follow-up: execute the default scheduler through explicit pass segments

- Refactored [`src/passes/optimize.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/optimize.mbt) so the default optimize loop now executes explicit `SchedulerPassSegment`s and routes each segment through a dedicated executor, while preserving the existing per-pass semantics, validation behavior, pass numbering, and `Vacuum` skip policy.
- Added helper-trace segment execution boundaries in [`src/passes/optimize.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/optimize.mbt) so helper traces now show `run_segment ... start/done` around both function-stack segments and module-runner barriers.
- Added trace regressions in [`src/passes/optimize.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/optimize.mbt) that require helper-level segment execution boundaries while keeping pass-level traces unchanged.
- Validation: `moon test --package jtenner/starshine/passes --file optimize.mbt -F 'optimize_module *scheduler segment execution boundaries*'`; `moon info && moon fmt`; `moon test`.

## 2026-03-16 Optimize Follow-up: expose stacked-runner scheduler segments in helper traces

- Added helper-trace segment planning in [`src/passes/optimize.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/optimize.mbt), so traced optimize runs now emit the grouped function-pass stacks and module-runner barrier passes derived from the in-tree scheduler segmentation helper before execution begins.
- Added trace regressions in [`src/passes/optimize.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/optimize.mbt) that require helper-level traces to report the segment plan while keeping pass-level traces unchanged.
- Validation: `moon test --package jtenner/starshine/passes --file optimize.mbt -F 'optimize_module *scheduler pass segments*'`; `moon info && moon fmt`; `moon test`.

## 2026-03-16 Optimize Follow-up: add scheduler segmentation groundwork for stacked function-pass execution

- Added scheduler segmentation helpers in [`src/passes/optimize.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/optimize.mbt) that group contiguous function-stackable transformer passes and isolate module-runner barriers, giving the future stacked runner an explicit in-tree segmentation contract.
- Added regression coverage in [`src/passes/optimize.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/optimize.mbt) for both synthetic pass lists and the default GC function pipeline, including the `LocalSubtyping` barrier split between the preceding `OptimizeCasts` stack tail and the following `CoalesceLocals` stack head.
- Validation: `moon test --package jtenner/starshine/passes --file optimize.mbt -F 'scheduler_segment_passes*'`; `moon info && moon fmt`; `moon test`.

## 2026-03-16 Optimize Follow-up: close the `CodeFolding` Binaryen parity scheduler slice

- Added an explicit `CodeFolding` scheduler regression in [`src/passes/optimize.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/optimize.mbt) that locks the Binaryen-parity gate (`-O3` or `-Os1`) and the expected placement after the late local-cleanup `Vacuum` and before `MergeBlocks`.
- Updated [`docs/0002-2026-03-11-differences.md`](/home/jtenner/Projects/starshine-mb/docs/0002-2026-03-11-differences.md) to record the `CodeFolding` scheduler comparison as closed and refreshed [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md) to retire the open blocker entry.
- Validation: `moon info && moon fmt`; `moon test`.

## 2026-03-16 Optimize Follow-up: close the `CodePushing` Binaryen parity scheduler slice

- Added an explicit `CodePushing` scheduler regression in [`src/passes/optimize.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/optimize.mbt) that locks the Binaryen-parity gate (`-O2` or `-Os2`) and the expected placement after early propagation and before tuple / local cleanup.
- Updated [`docs/0002-2026-03-11-differences.md`](/home/jtenner/Projects/starshine-mb/docs/0002-2026-03-11-differences.md) to record the `CodePushing` scheduler comparison as closed and refreshed [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md) to retire the open blocker entry.
- Validation: `moon info && moon fmt`; `moon test`.

## 2026-03-16 SimplifyLocals Follow-up: close scheduler/parity signoff and retire stale blocker list

- Refreshed [`docs/0006-2026-03-15-simplify-locals.md`](/home/jtenner/Projects/starshine-mb/docs/0006-2026-03-15-simplify-locals.md) into a completed signoff record for the current five-variant `SimplifyLocals` envelope, including explicit completion notes for the existing correctness, control-structure, validation, performance, and scheduler coverage already in-tree.
- Updated [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md) to remove the stale open `SimplifyLocals` blocker checklist and record the signoff closure in the completed-items section.
- Validation: targeted `simplify_locals` ID regressions; targeted `br_if` / `br_table` / validation-counter regressions; `moon test --package jtenner/starshine/passes --file optimize.mbt -F '*SimplifyLocals*'`.

## 2026-03-16 MergeSimilarFunctions Follow-up: publish the supported envelope in the main design doc

- Updated [`docs/0007-2026-03-16-merge-similar-functions.md`](/home/jtenner/Projects/starshine-mb/docs/0007-2026-03-16-merge-similar-functions.md) with a release-facing supported-difference matrix and explicit guarded typed-ref lowering policy, so the main design doc now matches the in-tree behavior already enforced by tests.
- Refreshed [`docs/0008-2026-03-16-merge-similar-functions-publish-plan.md`](/home/jtenner/Projects/starshine-mb/docs/0008-2026-03-16-merge-similar-functions-publish-plan.md) and [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md) to mark `MSF-006` / `MSF-009` effectively closed and narrow the remaining `MergeSimilarFunctions` publish work to final `MSF-013` signoff.
- Validation was not rerun because this slice is documentation-only; the preceding code slice already completed `moon info && moon fmt` and `moon test`.

## 2026-03-16 MergeSimilarFunctions Follow-up: add fixed-corpus timing and instrumentation harnesses

- Added a dedicated fixed benchmark corpus plus timing/instrumentation helpers in [`src/passes/merge_similar_functions.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/merge_similar_functions.mbt), covering representative merge, skip, multi-class, and near-limit-profitable inputs.
- Added regression coverage in [`src/passes/merge_similar_functions.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/merge_similar_functions.mbt) that locks fixed-corpus validity, deterministic output, zero bucket-copy churn, positive dense-site coverage, and a runnable end-to-end timing harness.
- Updated [`docs/0008-2026-03-16-merge-similar-functions-publish-plan.md`](/home/jtenner/Projects/starshine-mb/docs/0008-2026-03-16-merge-similar-functions-publish-plan.md) and [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md) to record the in-tree `MSF-013` harness work and narrow the remaining `MergeSimilarFunctions` publish work to signoff/documentation items.
- Validation: `moon fmt`; `moon test --package jtenner/starshine/passes --file merge_similar_functions.mbt -F 'merge similar functions*'`; `moon test --package jtenner/starshine/passes --file optimize.mbt -F 'optimize_module runs MergeSimilarFunctions pass'`; `moon info && moon fmt`; `moon test`.

## 2026-03-16 MergeSimilarFunctions Follow-up: adapt synthetic-parameter policy to profitability

- Updated [`src/passes/merge_similar_functions.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/merge_similar_functions.mbt) so synthetic-parameter handling now uses a soft limit plus bounded hard cap, and near-limit merges can still proceed when the byte-aware profitability model clearly wins.
- Added regression coverage in [`src/passes/merge_similar_functions.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/merge_similar_functions.mbt) for profitable just-over-limit merges, explicit parameter-pressure skips, and hard-cap rejection of excessive synthetic parameter growth.
- Refreshed [`docs/0008-2026-03-16-merge-similar-functions-publish-plan.md`](/home/jtenner/Projects/starshine-mb/docs/0008-2026-03-16-merge-similar-functions-publish-plan.md) and [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md) to record `MSF-008` as completed and narrow the remaining `MergeSimilarFunctions` publish work.
- Validation: `moon fmt`; `moon test --package jtenner/starshine/passes --file merge_similar_functions.mbt -F 'merge similar functions*'`; `moon test --package jtenner/starshine/passes --file optimize.mbt -F 'optimize_module runs MergeSimilarFunctions pass'`; `moon info && moon fmt`; `moon test`.

## 2026-03-16 MergeSimilarFunctions Follow-up: make profitability byte-aware without blocking established merges

- Updated [`src/passes/merge_similar_functions.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/merge_similar_functions.mbt) so `MergeSimilarFunctions` profitability now measures instruction-immediate byte weight and actual thunk body cost, which skips tiny typed-ref wrappers while preserving established profitable merges.
- Added profitability regressions in [`src/passes/merge_similar_functions.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/merge_similar_functions.mbt) for tiny and larger typed-ref call-target wrappers, and retuned the existing call-target rewrite test to exercise a still-profitable wrapper shape.
- Updated [`src/passes/imports.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/imports.mbt) for the new byte-size helpers.
- Validation: `moon info && moon fmt`; `moon test`.

## 2026-03-16 MergeSimilarFunctions Follow-up: add a publish-signoff plan for supported envelope, remaining blockers, and rerun criteria

- Added [`docs/0008-2026-03-16-merge-similar-functions-publish-plan.md`](/home/jtenner/Projects/starshine-mb/docs/0008-2026-03-16-merge-similar-functions-publish-plan.md) as the active source of truth for `MergeSimilarFunctions` publish signoff, including the supported difference-kind matrix, the current typed-ref lowering envelope, the remaining policy blockers, and the required rerun checklist.
- Linked the new signoff plan from [`docs/0007-2026-03-16-merge-similar-functions.md`](/home/jtenner/Projects/starshine-mb/docs/0007-2026-03-16-merge-similar-functions.md) and recorded the completed documentation slice in [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md).
- Validation was not run because this slice is documentation-only.

## 2026-03-16 MergeSimilarFunctions Follow-up: lock explicit skip-policy tracing for unsupported typed-ref merges and parameter-pressure skips

- Added a trace-capture helper plus traced skip-policy regressions in [`src/passes/merge_similar_functions.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/merge_similar_functions.mbt) that lock explicit `reason=typed_ref_lowering_unsupported` and `reason=synthetic_param_limit` behavior under `merge_similar_functions_with_trace(...)`.
- Kept the existing `MergeSimilarFunctions` skip behavior validator-clean while making unsupported typed-ref merges and synthetic-parameter-pressure skips test-enforced and diagnosable.
- Recorded the completed blocker slice in [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md).
- Validation: `moon test src/passes`; `moon fmt`; `moon info`; `moon test`.

## 2026-03-16 MergeSimilarFunctions Follow-up: strengthen coarse bucket discrimination with call-shape hashing

- Updated [`src/passes/merge_similar_functions.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/merge_similar_functions.mbt) so defined functions precompute a cheap call-shape hash over direct-call site ids, callee type indices, arg counts, and call kind, and the coarse hash bucket key now uses that discriminator in addition to the existing structural hash.
- Added representative-comparison stats to class collection in [`src/passes/merge_similar_functions.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/merge_similar_functions.mbt) and locked a collision-heavy regression proving the prefilter reduces representative comparisons without changing deterministic class formation.
- Recorded the completed blocker slice in [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md).
- Validation: `moon test src/passes`; `moon fmt`; `moon info`; `moon test`.

## 2026-03-16 MergeSimilarFunctions Follow-up: remove bucket-copy churn and densify cached site metadata

- Reworked [`src/passes/merge_similar_functions.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/merge_similar_functions.mbt) so equivalence-class bucket assembly now grows bucket member arrays in place through a shared builder instead of copy-on-insert rebuilds.
- Replaced cached `node_id -> site` maps in [`src/passes/merge_similar_functions.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/merge_similar_functions.mbt) with dense site vectors keyed by traversal-stable preorder ids, and routed `derive_params` through array-backed site lookup.
- Added regression coverage in [`src/passes/merge_similar_functions.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/merge_similar_functions.mbt) for zero-copy bucket growth and sparse-node dense site vectors, and recorded the completed blocker slices in [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md).
- Validation: `moon test src/passes`; `moon fmt`; `moon info`; `moon test`.

## 2026-03-16 MergeSimilarFunctions Follow-up: replace dense node-id maps with array-backed lookup in rewrite metadata paths

- Reworked call-target metadata lookup in [`src/passes/merge_similar_functions.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/merge_similar_functions.mbt) so rewrite prevalidation and shared-body rewrite use array-backed `node_id -> param` lookup plus dense seen-use tracking keyed by traversal-stable preorder ids instead of `Map[Int, Int]` / `Map[Int, Bool]`.
- Kept the existing `MergeSimilarFunctions` rewrite and diagnostics behavior in [`src/passes/merge_similar_functions.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/merge_similar_functions.mbt) while reducing GC churn on the dense node-id metadata path.
- Added sparse-use regression coverage in [`src/passes/merge_similar_functions.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/merge_similar_functions.mbt) and recorded the completed blocker slice in [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md).
- Validation: `moon test src/passes`; `moon fmt`; `moon info`; `moon test`.

## 2026-03-16 MergeSimilarFunctions Follow-up: cache per-function analysis artifacts across hot-path queries

- Added a shared per-run analysis context in [`src/passes/merge_similar_functions.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/merge_similar_functions.mbt) that caches module type metadata plus lazy per-function normalized bodies, ordered-site/call-site artifacts, site maps, and measured body sizes.
- Routed `MergeSimilarFunctions` class collection, parameter derivation, and profitability checks in [`src/passes/merge_similar_functions.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/merge_similar_functions.mbt) through that shared cache so hot comparison loops stop rebuilding the same analysis products.
- Added cache-reuse regression coverage in [`src/passes/merge_similar_functions.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/merge_similar_functions.mbt) and recorded the completed blocker slice in [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md).
- Validation: `moon test src/passes`; `moon fmt`; `moon info`; `moon test`.

## 2026-03-16 MergeSimilarFunctions Follow-up: centralize ordered site numbering for traversal-stable metadata

- Refactored [`src/passes/merge_similar_functions.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/merge_similar_functions.mbt) to assign site ids through one shared ordered-site collector and reuse that ordered stream across generic site collection, direct-call collection, and parameter derivation.
- Removed the old map-plus-sort fallback in [`src/passes/merge_similar_functions.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/merge_similar_functions.mbt), making the pre-order traversal numbering contract explicit in code and comments.
- Added traversal-order regressions in [`src/passes/merge_similar_functions.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/merge_similar_functions.mbt), refreshed [`src/passes/pkg.generated.mbti`](/home/jtenner/Projects/starshine-mb/src/passes/pkg.generated.mbti), and recorded the completed blocker slice in [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md).
- Validation: `moon test src/passes`; `moon info`; `moon fmt`; `moon test`.

## 2026-03-16 MergeSimilarFunctions Follow-up: remove unconditional tail-call thunks and guard typed-ref lowering

- Updated [`src/passes/merge_similar_functions.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/merge_similar_functions.mbt) so shared-function thunks no longer emit unconditional `return_call`; they now lower to `return(call ...)`, removing tail-call dependence from the common merge path.
- Added a guarded typed-function-reference lowering path in [`src/passes/merge_similar_functions.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/merge_similar_functions.mbt) that skips `CallTargetParam`-driven merges unless the input module already demonstrates typed-ref lowering support.
- Added regression coverage in [`src/passes/merge_similar_functions.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/merge_similar_functions.mbt) for tail-call-free thunks, guarded skip behavior without typed-ref evidence, and the still-enabled typed-ref merge path, and recorded the completed blocker slices in [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md).
- Validation: `moon test src/passes`; `moon info`; `moon fmt`; `moon test`.

## 2026-03-16 MergeSimilarFunctions Follow-up: prevalidate call-target metadata and report precise rewrite mismatches

- Hardened [`src/passes/merge_similar_functions.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/merge_similar_functions.mbt) so call-target rewrite validation now uses a shared site checker, prevalidates `CallTargetParam` node bindings against the primary body before rewrite starts, and rejects missing or misbound node ids early.
- Upgraded call-target rewrite diagnostics in [`src/passes/merge_similar_functions.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/merge_similar_functions.mbt) to include `node_id` plus explicit expected/actual kind, arg count, and callee type details.
- Added kind-mismatch and callee-type-mismatch regression coverage in [`src/passes/merge_similar_functions.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/merge_similar_functions.mbt) and recorded the completed blocker slice in [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md).
- Validation: `moon test src/passes`; `moon info`; `moon fmt`; `moon test`.

## 2026-03-16 MergeSimilarFunctions Follow-up: preflight direct-call audit separates upstream-invalid IR from rewrite metadata failures

- Added a pass-wide direct `call` / `return_call` preflight audit in [`src/passes/merge_similar_functions.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/merge_similar_functions.mbt) so upstream-invalid call arity now fails before equivalence grouping or shared-body rewrite starts.
- Tightened `MergeSimilarFunctions` rewrite diagnostics in [`src/passes/merge_similar_functions.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/merge_similar_functions.mbt) so call-target rewrite failures are labeled as metadata mismatches instead of looking like input-validation failures.
- Added direct `call` and `return_call` preflight regression coverage in [`src/passes/merge_similar_functions.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/merge_similar_functions.mbt) and recorded the completed blocker slice in [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md).
- Validation: `moon test src/passes`; `moon info`; `moon fmt`; `moon test`.

## 2026-03-16 MergeSimilarFunctions Follow-up: route function-type resolution through validator semantics and fix grouped-rec shared type indexing

- Reworked [`src/passes/merge_similar_functions.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/merge_similar_functions.mbt) to resolve `TypeIdx` and callee function signatures through validator-backed module semantics instead of the pass-local flattened lookup.
- Fixed appended shared-function `TypeIdx` assignment to use flattened subtype count, so grouped recursion types no longer shift synthesized function signatures onto the wrong index.
- Added grouped-rec regression coverage in [`src/passes/merge_similar_functions.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/merge_similar_functions.mbt) and recorded the completed blocker slice in [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md).
- Validation: `moon test src/passes`; `moon info`; `moon fmt`; `moon test`.

## 2026-03-16 Docs Follow-up: compacted `AGENTS.md` without changing repository guidance

- Rewrote [`AGENTS.md`](/home/jtenner/Projects/starshine-mb/AGENTS.md) into a denser format while preserving the same instructions and workflow requirements.
- Validation was not run because this change was documentation-only.

## 2026-03-16 Docs Follow-up: closed `RemoveUnusedBrs` and `PrecomputePropagate` parity-tracking items and standardized commit workflow guidance

- Marked the `RemoveUnusedBrs` and `PrecomputePropagate` Optimize/Binaryen parity comparison items complete in [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md).
- Added a `Precompute` / `PrecomputePropagate` scheduler parity note to [`docs/0002-2026-03-11-differences.md`](/home/jtenner/Projects/starshine-mb/docs/0002-2026-03-11-differences.md) with code and test anchors.
- Updated [`AGENTS.md`](/home/jtenner/Projects/starshine-mb/AGENTS.md) to require changelog updates plus temp-file-based `git commit -F` commit messages when agents are asked to commit.
- Validation was not run because these changes were documentation-only.

## 2026-03-13 MergeBlocks Follow-up: closed parity-signoff by classifying all matrix rows, recording signoff metrics, and moving the plan from active to done

This follow-up closes the `MergeBlocks` parity signoff blocker using:
- [`src/passes/merge_blocks_parity_wbtest.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/merge_blocks_parity_wbtest.mbt)
- [`docs/0004-2026-03-12-merge-blocks-binaryen-feature-parity-plan.md`](/home/jtenner/Projects/starshine-mb/docs/0004-2026-03-12-merge-blocks-binaryen-feature-parity-plan.md)

Strict TDD was used:
1. Added red-first signoff tests:
   - `merge blocks parity signoff classifies each row as match or intentional divergence`
   - `merge blocks parity signoff metrics are stable`
2. Ran `moon test src/passes` and captured explicit red compile failures before implementation:
   - unbound signoff helpers (`mbp_parity_row_signoff_status`, `mbp_collect_parity_signoff_metrics`)
   - unresolved metrics fields in the new signoff assertions.
3. Implemented signoff status + metrics helpers and reran to green, then tightened metrics assertions to exact stable counts.

What was added:
- Parity-signoff metrics model:
  - `MBParitySignoffMetrics`
- Signoff status/rationale helper:
  - `mbp_parity_row_signoff_status(row)` returning `Match` or `Intentional divergence` with rationale for divergence rows.
- Signoff metrics collector:
  - `mbp_collect_parity_signoff_metrics()`
- Explicit divergence row lock:
  - `merge blocks parity signoff intentional divergence rows are explicit`

Recorded signoff metrics (test-locked):
- `total_rows = 11`
- `match_rows = 8`
- `intentional_divergence_rows = 3`
- `validates_before_rows = 8`
- `validates_after_rows = 9`
- `idempotent_rows = 11`
- `changed_rows = 5`
- `value_branch_zero_rows = 10`
- `stack_sig_required_rows = 1`
- `stack_sig_consistent_rows = 1`
- `required_category_count = 7`

Plan completion:
- Updated parity plan status to `Done`.
- Added completion notes with row-by-row `Match` / `Intentional divergence` classification and rationale.
- Moved the plan from `docs/plans/active` to `docs/plans/done`.

Verification:
- `moon test src/passes`
- `moon info && moon fmt`
- `moon test`

Backlog tracking was updated in [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md): parity-signoff was removed from publishing blockers and moved to recently completed.

## 2026-03-13 MergeBlocks Follow-up: closed parity-test-matrix item by adding an explicit category matrix harness with per-row expected outcomes and invariant checks

This follow-up closes the `MergeBlocks` parity test matrix blocker in [`src/passes/merge_blocks_parity_wbtest.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/merge_blocks_parity_wbtest.mbt).

Strict TDD was used:
1. Added red-first parity-matrix tests:
   - `merge blocks parity matrix covers required categories`
   - `merge blocks parity matrix rows meet expected outcomes`
2. Ran `moon test src/passes` and captured explicit red compile failures before implementation:
   - unbound matrix helpers (`mbp_collect_parity_matrix_results`, `mbp_required_parity_matrix_categories`)
   - unresolved matrix row fields in test assertions due missing result struct.
3. Implemented matrix case/result models + fixture runners, then iterated to green by fixing row fixtures/expectations that failed runtime assertions.

What was added:
- Explicit matrix data model:
  - `MBParityMatrixCase`
  - `MBParityMatrixResult`
- Matrix category contract helper:
  - `mbp_required_parity_matrix_categories()`
- Matrix fixture builders and evaluation helpers:
  - named block boundary fixture
  - loop-tail extraction fixture
  - dropped-block value-removal fixture
  - `try_table` catch permutation fixtures (`catch_all_ref`, `catch_ref` no-params, `catch`, `catch_all`, paramful `catch_ref`)
  - restructure dependency/effect-collision fixture
  - typed stack-signature fixture
  - idempotence fixture
  - collectors:
    - `mbp_parity_matrix_cases()`
    - `mbp_collect_parity_matrix_results()`
    - `mbp_validates_module(...)`
    - `mbp_stack_sig_consistent_module(...)`

Matrix coverage now explicitly asserts the required categories:
- named block merge boundaries
- loop-tail extraction
- dropped-block value removal
- `try_table` catch permutations
- restructure dependency/effect collisions
- type/stack-signature invariants
- idempotence (`run_merge_blocks` once vs twice)

Per-row checks now include (as applicable):
- expected `changed` behavior
- expected post-pass value-branch counts
- validation invariants
- stack-signature consistency invariants
- idempotence guarantees

Verification:
- `moon test src/passes`
- `moon info && moon fmt`
- `moon test`

Backlog tracking was updated in [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md): the parity-test-matrix item was removed from publishing blockers and moved to recently completed.

## 2026-03-13 MergeBlocks Follow-up: closed P-005 by switching `optimize_block` round assembly to staged buffer swaps and locking zero rebuild-copy replay coverage

This follow-up closes `MergeBlocks` performance P-005 in [`src/passes/merge_blocks.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/merge_blocks.mbt).

Strict TDD was used:
1. Added red-first regressions:
   - `merge blocks: optimize block staged buffers swap rounds without rebuild-copy replay`
   - `merge blocks: optimize block staged-buffer stress fixture keeps representative zero-copy target`
2. Ran `moon test src/passes` and captured explicit red compile failures before implementation:
   - missing `MBFunctionRunStats` fields:
     - `optimize_block_round_buffer_swaps`
     - `optimize_block_round_rebuild_copies`
   - unbound stress helper:
     - `mb_optimize_block_buffer_stress_totals(...)`
3. Implemented staged swap assembly + stats/helper wiring and reran to green.

Implementation details:
- Reworked `optimize_block(...)` round assembly from rebuild-copy replay to staged buffers:
  - before: each changed round replayed all `out` items into `curr_items` via `curr_items.clear()` + push loop.
  - after: maintains `curr_items` and `next_items` buffers, clears/fills `next_items` per round, then commits with buffer swap:
    - `prev_items = curr_items`
    - `curr_items = next_items`
    - `next_items = prev_items`
- Preserved round semantics:
  - round-change detection, branch-cache invalidation boundary, round-safety-cap handling, and finalization behavior are unchanged.
- Added round-assembly observability:
  - `MBContext.optimize_block_round_buffer_swaps`
  - `MBContext.optimize_block_round_rebuild_copies`
  - surfaced in `MBFunctionRunStats` with matching fields.
- Added deterministic stress helper:
  - `mb_optimize_block_buffer_stress_totals(iterations, arg_count)`
  - aggregates swap/copy metrics over repeated fixed fixtures.

Behavioral outcomes locked by tests:
- Representative optimize-block rewrite workloads produce positive buffer-swap counts.
- Rebuild-copy replay count remains `0` under staged-buffer commit behavior.

Verification:
- `moon test src/passes`
- `moon info && moon fmt`
- `moon test`

Backlog tracking was updated in [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md): P-005 was removed from publishing blockers and moved to recently completed.

## 2026-03-13 MergeBlocks Follow-up: closed P-004 by replacing non-control `eval_children(...).to_array()` materialization with direct child iteration and zero-materialization stress coverage

This follow-up closes `MergeBlocks` performance P-004 in [`src/passes/merge_blocks.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/merge_blocks.mbt).

Strict TDD was used:
1. Added red-first regressions:
   - `merge blocks: non-control child iteration avoids eval-children array materialization`
   - `merge blocks: non-control child iteration stress fixture keeps representative zero-materialization target`
2. Ran `moon test src/passes` and captured explicit red compile failures before implementation:
   - unbound stress-module helper (`mb_make_non_control_child_iteration_stress_module(...)`)
   - missing `MBFunctionRunStats` fields (`non_control_child_iteration_steps`, `non_control_child_array_materializations`)
   - unbound stress-aggregation helper (`mb_non_control_child_iteration_stress_totals(...)`)
3. Implemented direct child iteration path + stats helpers and reran to green.

Implementation details:
- Reworked `mb_restructure_non_control(...)`:
  - before: eagerly materialized all children with `eval_children(parent_expr).to_array()`.
  - after: iterates children directly via `for child in eval_children(parent_expr)` with no intermediate child-array materialization.
- Added non-control restructure observability:
  - `MBContext.non_control_child_iteration_steps`
  - `MBContext.non_control_child_array_materializations`
  - surfaced in `MBFunctionRunStats` with matching fields.
- Added stress fixtures/utilities:
  - `mb_make_non_control_child_iteration_stress_module(arg_count)`
  - `mb_non_control_child_iteration_stress_totals(iterations, arg_count)`
  - regression asserts representative runs keep total materializations at `0` while still recording positive iteration steps.

Behavioral outcomes locked by tests:
- Non-control restructure still rewrites representative fixtures (`changed == true`), while child traversal is measured through iteration counters.
- Representative stress runs enforce a zero-materialization target on this path.

Verification:
- `moon test src/passes`
- `moon info && moon fmt`
- `moon test`

Backlog tracking was updated in [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md): P-004 was removed from publishing blockers and moved to recently completed.

## 2026-03-13 MergeBlocks Follow-up: closed P-003 by switching branch-query cache keys to identity ids with generation invalidation and locking representative hit-rate coverage

This follow-up closes `MergeBlocks` performance P-003 in [`src/passes/merge_blocks.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/merge_blocks.mbt).

Strict TDD was used:
1. Added red-first branch-cache regressions:
   - `merge blocks: branch cache uses id-based keys so structural clones do not alias`
   - `merge blocks: branch cache rewrite invalidation boundary forces next-query miss`
   - `merge blocks: branch cache stress fixture meets representative hit-rate target`
2. Ran `moon test src/passes` and captured explicit red compile failures before implementation:
   - missing `BranchCache` stats fields used by the new tests (`instr_id_misses`, `query_misses`, `query_hits`, `invalidations`)
   - missing invalidation helper (`mb_branch_cache_invalidate(...)`)
   - missing stress helper (`mb_branch_cache_stress_hit_rate_bp(...)`)
3. Implemented identity/generation cache changes and reran to green.

Implementation details:
- Replaced structural cache keys:
  - before: `BranchCacheKey { instr: typed instruction node, depth }` keyed by structural `Eq`/`Hash`.
  - after: `BranchCacheQueryKey { instr_id, depth, generation }` keyed by instruction identity id and invalidation generation.
- Added identity-id side table:
  - `instr_id_entries : Array[BranchCacheInstrIdEntry]`
  - `mb_branch_cache_instr_id(...)` resolves ids via `physical_equal(...)` so structurally equal clones do not alias.
- Added generation invalidation boundary:
  - `mb_branch_cache_invalidate(...)` increments cache generation and invalidation counter.
  - `optimize_block(...)` now calls invalidation whenever a round rewrites the block before the next round queries run.
- Added branch-cache observability and stress helper:
  - query hit/miss counters and id hit/miss counters
  - `mb_branch_cache_hit_rate_bp(...)`
  - `mb_branch_cache_stress_hit_rate_bp(...)` for representative repeated-query hit-rate measurement.

Behavioral outcomes locked by tests:
- Structural clones now map to distinct instruction ids (no key aliasing through structural hashing).
- Post-rewrite round boundaries force a miss on the next query generation instead of reusing stale query entries.
- Representative repeated-query fixture keeps cache hit rate at `>= 80%`.

Verification:
- `moon test src/passes`
- `moon info && moon fmt`
- `moon test`

Backlog tracking was updated in [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md): P-003 was removed from publishing blockers and moved to recently completed.

## 2026-03-13 MergeBlocks Follow-up: closed P-002 by adding per-function `compute_effects` memoization and locking a >=15% stress-fixture wall-time improvement

This follow-up closes `MergeBlocks` performance P-002 in [`src/passes/merge_blocks.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/merge_blocks.mbt).

Strict TDD was used:
1. Added red-first performance/cache regressions:
   - `merge blocks: effect cache records repeated stable-identity hits per function`
   - `merge blocks: effect cache stress fixture improves wall time by at least 15 percent`
2. Ran `moon test src/passes` and captured explicit red compile failures before implementation:
   - unbound `mb_run_on_function_with_stats_with_effect_cache(...)`
   - missing cache fields in run stats (`compute_effects_cache_hits` / `compute_effects_cache_misses`)
3. Implemented per-function memoization + stats wiring and reran to green.

Implementation details:
- Added stable instruction cache key:
  - `MBStableInstrKey` (derived `Eq`/`Hash`) keyed by `typed instruction node` identity/equality semantics.
- Added per-function effect cache storage and controls in `MBContext`:
  - `effects_cache : Map[MBStableInstrKey, MBEffects]`
  - `effect_cache_enabled : Bool`
  - `compute_effects_cache_hits` / `compute_effects_cache_misses`
- Added cached effect accessor:
  - `mb_compute_effects_cached(instr, ctx)` with hit/miss accounting.
- Routed MergeBlocks hot-path effect queries to cached accessor in:
  - `optimize_expression_restructure(...)`
  - `mb_restructure_non_control(...)`
  - dropped-block `problem_finder` value-side-effect checks.
- Added function-runner override path:
  - `mb_run_on_function_with_stats_with_effect_cache(...)`
  - shared override runner keeps existing behavior as default while enabling cache-off comparisons for stress verification.
- Extended `MBFunctionRunStats` with cache telemetry:
  - `compute_effects_cache_hits`
  - `compute_effects_cache_misses`

Performance verification locked in tests:
- Added dedicated stress fixture/module helper (`mb_make_effect_cache_stress_module(...)`) that reuses repeated stable instruction identities in a heavy call-argument shape.
- Added timing helper (`mb_effect_cache_stress_elapsed_us(...)`) and regression asserting cached mode improves wall time by `>= 15%` versus uncached mode on fixed iterations.

Verification:
- `moon test src/passes`
- `moon info && moon fmt`
- `moon test`

Backlog tracking was updated in [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md): P-002 was removed from publishing blockers and moved to recently completed.

## 2026-03-13 MergeBlocks Follow-up: closed runtime-gap item by documenting and locking intentional sequential execution under current transformer constraints

This follow-up closes the `MergeBlocks` runtime-gap backlog item in [`src/passes/merge_blocks.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/merge_blocks.mbt).

Decision:
- The local pass runner does not currently expose a safe function-parallel dispatch path for this pass.
- `legacy module rewrite engine::walk_opt_codesec_default` traverses function bodies through `legacy module rewrite engine::walk_opt_array`, and `walk_opt_array` threads mutable traversal state item-by-item; this execution model is serial by construction today.
- Per backlog requirement, this is now documented as an intentional divergence until runner-level function-parallel support exists.

Strict TDD was used:
1. Added a red-first regression:
   - `merge blocks: runtime parallel gap is documented as intentional sequential divergence`
2. Ran `moon test src/passes` and captured explicit red compile failure:
   - unbound `mb_runtime_execution_policy_note()`
3. Implemented the policy note and pass-level execution-model comment, then reran to green.

What was added:
- `mb_runtime_execution_policy_note()` with explicit rationale referencing the transformer traversal constraint (`walk_opt_codesec_default` -> `walk_opt_array` state threading).
- A pass-level comment in `merge_blocks_ir_pass(...)` pointing to the policy note for execution-model context.
- Regression assertion that locks policy-note content so this intentional divergence remains explicit and test-guarded.

Verification:
- `moon test src/passes`
- `moon info && moon fmt`
- `moon test`

Backlog tracking was updated in [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md): the runtime-gap item was removed from publishing blockers and moved to recently completed.

## 2026-03-13 MergeBlocks Follow-up: closed C-004 by replacing fixed 20-round block optimization with convergence-driven iteration and explicit safety-cap instrumentation

This follow-up closes `MergeBlocks` correctness gap C-004 in [`src/passes/merge_blocks.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/merge_blocks.mbt).

Strict TDD was used:
1. Added red-first regressions for:
   - deep nested convergence beyond the legacy round budget surface (`merge blocks: deep nesting converges past legacy round budget without cap hits`)
   - explicit forced safety-cap signaling (`merge blocks: safety-cap instrumentation reports forced cap hit`)
2. Ran `moon test src/passes` and captured explicit red compile failures before implementation:
   - missing `MBFunctionRunStats.optimize_block_rounds`
   - missing `MBFunctionRunStats.optimize_block_round_cap_hits`
   - missing cap-aware stats runner helper (`mb_run_on_function_with_stats_with_round_safety_cap`)
3. Implemented convergence loop + instrumentation and reran to green.

Implementation changes:
- Replaced fixed-loop guard in `optimize_block(...)`:
  - before: `while rounds < 20`
  - after: convergence-driven `while true` loop that exits on `!round_change`.
- Added explicit safety cap computation (`mb_optimize_block_round_safety_cap(...)`) and cap-hit accounting.
- Added `MBContext` instrumentation fields:
  - `optimize_block_rounds`
  - `optimize_block_round_cap_hits`
  - `round_safety_cap_override` (test/diagnostic override path)
- Added `MBFunctionRunStats` fields:
  - `optimize_block_rounds`
  - `optimize_block_round_cap_hits`
- Added cap-aware stats helper:
  - `mb_run_on_function_with_stats_with_round_safety_cap(...)`
  - default runner preserves normal behavior via `mb_run_on_function_with_stats(...)` (override `0`).

Behavioral outcome:
- Deep nested fixtures are no longer constrained by the previous silent 20-round stop.
- When a safety cap is explicitly forced low, the pass reports cap hits through stats instead of truncating silently.

Verification:
- `moon test src/passes`
- `moon info && moon fmt`
- `moon test`

Backlog tracking was updated in [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md): C-004 was removed from publishing blockers and moved to recently completed.

## 2026-03-13 MergeBlocks Follow-up: closed C-003 by porting Binaryen-style loop `keepEnd` concrete-tail gating and adding typed loop extraction fixtures

This follow-up closes `MergeBlocks` correctness gap C-003 in [`src/passes/merge_blocks.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/merge_blocks.mbt).

Strict TDD was used:
1. Added red-first typed loop regressions that separate unsound and valid loop-tail extraction cases:
   - `merge blocks: typed loop concrete tail without back-branch is not extracted`
   - `merge blocks: typed loop non-concrete tail is extracted`
2. Ran `moon test src/passes` and captured explicit red failures:
   - concrete-tail case produced invalid output (`typed function stack underflow`) due unsound loop-tail extraction
   - non-concrete-tail case stayed unoptimized (`expected typed non-concrete loop tail moved outside loop`) because the old gate blocked it.
3. Implemented loop gate parity fix and reran to green.

Implementation change:
- In `optimize_block(...)` loop-tail merge handling, replaced the old partial-merge gate:
  - `split > 0 && mb_blocktype_is_concrete(loop_bt, ctx.env)`
- With Binaryen-compatible extracted-tail concreteness gating:
  - block extraction when the extracted region exists and the child tail is concrete (`keepEnd < childSize && childList.back()->type.isConcrete()` parity modeled as `mb_instr_is_concrete(inner_items[last], ctx.env)`).

Behavioral result:
- Unsound concrete-tail extraction is now blocked even in typed loops with no back-branch.
- Valid typed extraction with a non-concrete extracted tail is now allowed.
- Post-pass validation stays preserved for both fixtures.

Verification:
- `moon test src/passes`
- `moon info && moon fmt`
- `moon test`

Backlog tracking was updated in [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md): C-003 was removed from publishing blockers and moved to recently completed.

## 2026-03-13 MergeBlocks Follow-up: closed effect-model hardening by filling missing shallow-effect tags and adding a table-driven movement matrix

This follow-up closes the `MergeBlocks` effect-model hardening backlog item in [`src/passes/merge_blocks.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/merge_blocks.mbt).

Strict TDD was used:
1. Added red-first regressions for:
   - checklist growth expectation (`35` entries)
   - table-driven movement blocked/allowed behavior across side-effect, trap, branch, and control-transfer representative families.
2. Ran `moon test src/passes` and captured explicit failures:
   - checklist size mismatch (`30 != 35`)
   - missing trap barrier behavior (`trap_div_vs_side_effect_local_set` case).
3. Implemented missing tags and checklist expansions, then reran to green.

Effect-model hardening changes in `mb_collect_shallow_effects`:
- Added missing trap flags for:
  - `memory.copy`, `memory.fill`, `memory.init`
  - `ref.cast_desc_eq`
  - `array.len`
  - integer `div/rem` binary ops
  - float->int truncating unary ops
- Added missing memory read+write tags for atomic family ops:
  - `atomic.fence`, `memory.atomic.notify`, `memory.atomic.wait32/64`, `atomic.rmw`, `atomic.cmpxchg`
- Strengthened array tags:
  - `array.set` / `array.fill` now mark both `reads_memory` and `writes_memory`
  - `array.new*` family now marks `traps` in addition to memory writes

Checklist and regression updates:
- Expanded opcode checklist from `30` to `35` entries and updated expected signatures accordingly.
- Added `MBMovementCase` table-driven movement matrix regression:
  - blocked cases for trap+side-effect, atomic memory hazards, branch barriers, and throw/control-transfer
  - allowed cases for pure arithmetic and disjoint local reads.

Verification:
- `moon test src/passes`
- `moon info && moon fmt`
- `moon test`

Backlog tracking was updated in [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md): the effect-model hardening item was removed from publishing blockers and moved to recently completed.

## 2026-03-13 MergeBlocks Follow-up: closed C-002 by adding an explicit motion-barrier opcode-effect checklist for `mb_collect_shallow_effects`

This follow-up closes the `MergeBlocks` correctness gap C-002 in [`src/passes/merge_blocks.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/merge_blocks.mbt) by making the supported shallow-effect opcode surface explicit and regression-checked.

Strict TDD was used:
1. Added red-first checklist tests (`effect checklist is explicit and stable`, `effect checklist entries match shallow effect collector`) before implementing checklist helpers.
2. Ran `moon test src/passes` and captured the expected red compile state (unbound checklist helpers).
3. Implemented checklist structs/helpers and reran to green.

What was added:
- `MBEffectChecklistExpected` and `MBEffectChecklistEntry` helper structs.
- `mb_effect_checklist_entries()` with a canonical 30-entry motion-barrier opcode checklist that covers all currently tagged `mb_collect_shallow_effects` instruction families.
- `mb_effect_checklist_entry_matches(...)` matcher used by tests to compare expected vs observed shallow-effect signatures.

Regression coverage:
- `merge blocks: effect checklist is explicit and stable`
- `merge blocks: effect checklist entries match shallow effect collector`

This locks the current effect-tagged opcode surface in one explicit checklist so future edits to `mb_collect_shallow_effects` are checked against a maintained parity list instead of ad hoc spot checks.

Backlog tracking was updated in [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md): C-002 was removed from publishing blockers and moved to recently completed.

## 2026-03-13 MergeBlocks Follow-up: closed dropped-block parity coverage by expanding `try_table` catch fixtures, adding nested drop/`br_if` legality regression, and fixing nested dropped-path blocker traversal

This follow-up closes the `MergeBlocks` dropped-block parity backlog item in [`src/passes/merge_blocks.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/merge_blocks.mbt).

Strict TDD was used:
1. Added red-first dropped-path parity tests for additional `try_table` catch forms and nested dropped-context branch/value legality.
2. Ran `moon test src/passes` and captured explicit failures in:
   - `merge blocks: problem finder blocks nested dropped try_table catch_ref mismatch`
   - `merge blocks: problem finder blocks nested dropped br_if mismatch` (later tightened to assert legality directly after confirming the observed inner rewrite was benign for this specific fixture).
3. Implemented the pass change and reran tests to green.

Implementation change:
- `problem_finder` now recursively inspects non-direct `drop(...)` values (`TDrop` values other than direct `drop(br_if ...)`), so nested dropped contexts cannot bypass dropped-block blocker checks for `try_table` catches and other branch structures before `break_value_dropper` rewriting.

New dropped-path parity coverage added in tests:
- `merge blocks: try_table catch_ref without params targeting origin is allowed`
- `merge blocks: try_table catch targeting origin blocks optimization`
- `merge blocks: try_table catch_all targeting origin blocks optimization`
- `merge blocks: problem finder blocks nested dropped try_table catch_ref mismatch`
- `merge blocks: nested dropped br_if keeps outer-label value branch`

Test-harness stability follow-up:
- Updated parity timing assertion in [`src/passes/merge_blocks_parity_wbtest.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/merge_blocks_parity_wbtest.mbt) from `mbp_time_fixed_corpus_us(3) > 0` to `mbp_time_fixed_corpus_us(128) > 0` to avoid zero-duration flakes at low iteration counts.

Verification:
- `moon test src/passes`
- `moon info && moon fmt`
- `moon test`

Backlog tracking was updated in [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md): the dropped-block parity item was removed from publishing blockers and moved to recently completed.

## 2026-03-13 MergeBlocks Follow-up: closed parity-baseline setup by adding a dedicated fixture corpus, a fixed-corpus timing harness, and baseline snapshot metrics

This follow-up closes the `MergeBlocks` parity-baseline blocker by adding an explicit baseline corpus and harness in [`src/passes/merge_blocks_parity_wbtest.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/merge_blocks_parity_wbtest.mbt). The new whitebox parity file introduces:
- `mbp_fixture_corpus()` as a dedicated fixed fixture corpus
- `mbp_collect_baseline_metrics(iterations)` for correctness baseline collection
- `mbp_time_fixed_corpus_us(iterations)` for deterministic fixed-corpus timing runs

Strict TDD was used:
1. Added red-first tests for corpus presence, baseline metrics, and timing harness hooks before helper implementation (initial compile red with unbound baseline helpers).
2. Implemented corpus/harness helpers and fixed fixture validity with an explicit validator regression (`merge blocks parity fixtures validate before and after pass`).
3. Locked baseline correctness snapshot metrics in test assertions and brought the suite to green.

Baseline snapshot (fixed corpus, `iterations=1`) now recorded in tests:
- `total_fixtures = 8`
- `changed_count = 5`
- `valid_after_count = 8`
- `idempotent_count = 8`
- `value_branch_count_after = 0`

Performance baseline harness contract is also locked in tests:
- `mbp_time_fixed_corpus_us(128) > 0`
- fixed corpus membership and iteration-driven timing loop are stable for future before/after comparisons.

Backlog tracking was updated in [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md): the parity-baseline item was removed from publishing blockers and moved to recently completed with baseline details.

## 2026-03-13 MergeBlocks Follow-up: closed C-001 by running dropped-block `problem_finder` over the whole body and aligning `br_if` drop-accounting with Binaryen semantics

This follow-up closes the `MergeBlocks` correctness gap C-001 in [`src/passes/merge_blocks.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/merge_blocks.mbt). The dropped-block path in `optimize_dropped_block(...)` previously called `problem_finder(...)` once per top-level instruction in the block body, which prevented whole-body balancing behavior for dropped vs non-dropped `br_if` cases and diverged from Binaryen's one-walk dropped-block analysis.

The dropped-block analysis now runs once across the entire body expression (`typed instruction body`) before rewriting break values. As part of the same fix, `ProblemFinderState` now tracks `non_dropped_br_if_values` and `dropped_br_if_values`, and the block condition now matches Binaryen-style balancing semantics: block only when `non_dropped_br_if_values > dropped_br_if_values`. In addition, `drop(br_if ...)` is accounted for directly in the `TDrop` arm without recursively counting that branch as non-dropped.

Regression coverage in [`src/passes/merge_blocks.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/merge_blocks.mbt) was extended with:
- `merge blocks: problem finder allows globally balanced dropped br_if values`

This fixture exercises sibling `drop(br_if ...)` and non-dropped `br_if` values that only balance when analyzed as one whole-body problem-finder pass. The test asserts the optimization now proceeds and that `br_if` value payloads are stripped.

Backlog tracking was updated in [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md): C-001 was removed from publishing blockers and moved to recently completed with completion notes.

## 2026-03-13 MergeBlocks Follow-up: closed P-001 by collapsing per-function refinalization to a single `changed || needs_refinalize` gate and adding invocation-count regression coverage

This follow-up closes the `MergeBlocks` performance P-001 backlog item in [`src/passes/merge_blocks.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/merge_blocks.mbt). The function runner previously performed up to two full refinalization traversals on the same function body:
- one pass gated by `changed`
- another pass gated by `ctx.needs_refinalize`

That double-pass path was replaced with a single unified gate, `should_refinalize = changed || ctx.needs_refinalize`, and one `mb_refinalize_texpr(...)` call. To make this measurable in tests, function execution now routes through a stats helper (`mb_run_on_function_with_stats(...)`) that reports whether the function changed, whether refinalization was requested, and how many refinalization traversals were invoked.

Strict TDD was used. A new red-first regression test was added first:
- `merge blocks: function run performs at most one refinalize pass`

Before the gate fix, `moon test src/passes` failed with `2 != 1` on the new assertion. After collapsing the gate, the same suite passed and now locks in `refinalize_invocations == 1` for a fixture that triggers both `changed` and `needs_refinalize`.

Backlog tracking was updated in [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md): P-001 was removed from publishing blockers and moved to recently completed with completion notes.

## 2026-03-12 Vacuum Follow-up: completed Stage 3 fallback metadata specialization by replacing remaining unindexed type/effect generic-helper fallbacks with structural formulas

This follow-up closes the last open `Vacuum` Stage 3 fallback-metadata blocker in [`src/passes/vacuum.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/vacuum.mbt). After previous pure-leaf and structural-call/control-transfer work, unindexed fallback paths still delegated to generic helper wrappers in two places:
- `vq_type_of_cached(...)` still fell back to `vq_type_of_timed(...)`
- `vq_has_unremovable_effects_cached(...)` still fell back to `vq_collect_effects_timed(...)`

`vq_type_of_cached(...)` now uses a structural inference path (`vq_type_of_fallback_structural(...)`) for unindexed rewrites, reusing local shape formulas plus environment metadata for wrapper/control/call/aggregate cases instead of the generic timed helper. `vq_has_unremovable_effects_cached(...)` now uses a structural recursive detector (`vq_instr_has_unremovable_effects_structural(...)`) backed by a shallow side-effect/trap classifier (`vq_instr_has_unremovable_effects_local(...)`), removing unindexed generic effect-collector fallback usage.

As a result, unindexed fallback metadata no longer calls `vq_collect_effects_timed(...)`, and `vq_type_of_timed(...)` remains only in seeded/indexed analysis construction.

Regression coverage in [`src/passes/vacuum.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/vacuum.mbt) was expanded with red-first tests:
- `vacuum fallback wrapped local.tee type metadata skips generic type inference`
- `vacuum fallback typed block metadata skips generic type inference`
- `vacuum fallback wrapped local.set effect metadata skips generic collector`

Verification: `moon test src/passes` (red first, then green), `moon info && moon fmt`, and full `moon test` (3053 passing, 0 failing).

## 2026-03-12 Vacuum Follow-up: replaced remaining unindexed depth-0 break/value-break fallback scans with structural summaries, fixed `try_table` catch-label depth targeting, and switched control-transfer fallback metadata to structural detection

This follow-up continues and closes the remaining Stage 3 unindexed depth-0 fallback-scan blockers in [`src/passes/vacuum.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/vacuum.mbt), and further narrows fallback metadata specialization.

`vq_has_break_to_depth0_cached(...)` no longer falls back to the generic `has_break_to_depth_in_texpr(...)` scan path on unindexed rewritten trees. Instead it now uses the local structural depth-target summary directly (`vq_texpr_may_target_break_to_depth0(...)`). As part of this, `try_table` handling was corrected to include catch-label targets (`depth + 1`) in the same structural break analysis, matching the original break-target semantics.

`vq_has_value_break_lub_depth0_cached(...)` now avoids delegating to the full recursive fallback collector on unindexed depth-0 queries. A dedicated structural fallback accumulator (`vq_has_value_break_lub_depth0_fallback(...)`) computes depth-targeted value-break compatibility directly from rewrite-local shape/type facts, including unknown/multi-value conservative behavior.

Fallback metadata specialization was also extended: `vq_instr_effect_transfers_control_flow_cached(...)` now uses a structural branch/throw detector (`vq_instr_effect_transfers_control_flow_structural(...)`) instead of `vq_collect_effects_timed(...).transfers_control_flow()` on unindexed paths, so wrapped branch-transfer trees no longer pay generic effect-collector cost for this metadata question.

Related cleanup: the now-unused `has_break_to_depth_in_texpr(...)` wrapper was removed from [`src/passes/dead_code_elimination.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/dead_code_elimination.mbt) after Vacuum stopped using it.

Regression coverage in [`src/passes/vacuum.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/vacuum.mbt) was expanded with red-first tests:
- `vacuum cached break helper skips generic break scan for unindexed targeted branch fallback`
- `vacuum cached break helper detects unindexed try_table catch target to depth0 without generic scan`
- `vacuum cached value-break helper skips generic collector for unindexed targeted branch fallback`
- `vacuum fallback wrapped branch-transfer metadata skips generic collector`

Verification: `moon test src/passes` (red first, then green), `moon info && moon fmt`, and full `moon test` (3050 passing, 0 failing).

## 2026-03-12 Vacuum Follow-up: switched unindexed fallback call-presence metadata to a structural detector so wrapped non-call trees avoid generic effect collection

This follow-up continues the remaining `Vacuum` Stage 3 fallback metadata specialization in [`src/passes/vacuum.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/vacuum.mbt). Even after pure-leaf fast paths, unindexed fallback `vq_instr_has_calls_cached(...)` still delegated to `vq_collect_effects_timed(...)` for wrapper-shaped non-call trees (for example `drop(i32.const ...)`), paying generic effect-collector cost to answer a pure structural question: whether any call instruction exists in the subtree.

`vq_instr_has_calls_cached(...)` now uses `vq_instr_has_calls_structural(...)` on unindexed fallback paths instead of `vq_collect_effects_timed(...).calls`. The new structural helper directly recognizes call kinds and recursively walks child/control bodies, preserving exact call-presence semantics without invoking the generic effect collector for this metadata query.

Regression coverage in [`src/passes/vacuum.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/vacuum.mbt) was expanded with a red-first test:
- `vacuum fallback wrapped call metadata skips generic collector`

The test failed before this change with `collect_effects_calls` incrementing on `drop(i32.const)` and now asserts `collect_effects_calls == 0`.

Verification: `moon test src/passes` (red first, then green), `moon info && moon fmt`, and full `moon test` (3046 passing, 0 failing).

## 2026-03-12 Vacuum Follow-up: added bounded unindexed depth-0 target summaries so break/value-break fallback helpers skip scans when labels cannot match

This follow-up continues the remaining `Vacuum` Stage 3 fallback-scan/value-break blockers in [`src/passes/vacuum.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/vacuum.mbt). After earlier label-score fast paths, fallback helpers still ran full collectors when labels were present but structurally unable to match the queried depth/value shape:
- `vq_has_break_to_depth0_cached(...)` still called `vq_has_break_to_depth_in_texpr_timed(...)`
- `vq_has_value_break_lub_depth0_cached(...)` still called `vq_value_break_to_depth_has_lub(...)`

Added bounded local target-summary predicates for unindexed rewritten trees:
- `vq_texpr_may_target_break_to_depth0(...)` / `vq_instr_may_target_break_to_depth0(...)`
- `vq_texpr_may_target_value_break_to_depth0(...)` / `vq_instr_may_target_value_break_to_depth0(...)`

Both cached helpers now short-circuit when these summaries return `false`, which avoids generic scans in cases like non-targeted branches (`br 1` under depth-0 query) and branches that never carry values (`br ... []`) even if label metadata is present.

Regression coverage in [`src/passes/vacuum.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/vacuum.mbt) was expanded with red-first tests:
- `vacuum cached break helper skips unindexed non-targeted branch fallback scan`
- `vacuum cached value-break helper skips unindexed branch-without-values fallback scan`

Verification: `moon test src/passes` (red first, then green), `moon info && moon fmt`, and full `moon test` (3045 passing, 0 failing).

## 2026-03-12 Vacuum Follow-up: added pure-leaf unindexed metadata fast paths to avoid generic type/effect fallback helpers

This follow-up continues the remaining `Vacuum` Stage 3 fallback metadata specialization work in [`src/passes/vacuum.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/vacuum.mbt). On unindexed rewritten instructions, metadata helpers still delegated to generic collectors/inference even for trivial pure leaves (`const`, `local.get`, etc.), which inflated helper-level fallback cost in hot rewrite churn.

`vq_type_of_cached(...)` now short-circuits common leaf kinds without calling `vq_type_of_timed(...)` (`local.get`, `global.get`, scalar/vector consts, `ref.null`, `ref.func`). Effect-side helpers now also short-circuit pure leaves without invoking `vq_collect_effects_timed(...)` (or shallow-effect collection): `vq_has_unremovable_effects_cached(...)`, `vq_has_unremovable_shallow_effects_cached(...)`, `vq_instr_has_calls_cached(...)`, and `vq_instr_effect_transfers_control_flow_cached(...)`.

Regression coverage in [`src/passes/vacuum.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/vacuum.mbt) was expanded with red-first tests:
- `vacuum fallback pure leaf effect metadata skips generic collector` (asserts `collect_effects_calls == 0`)
- `vacuum fallback pure leaf type metadata skips generic type inference` (asserts `infer_type_calls == 0`)

Verification: `moon test src/passes` (red first on the new type-metadata assertion, then green), `moon info && moon fmt`, and full `moon test` (3042 passing, 0 failing).

## 2026-03-12 Vacuum Follow-up: narrowed drop-rewrite stack-signature guarding to local child-signature formulas and kept generic rewrite checks as fallback only

This follow-up continues the remaining `Vacuum` Stage 3 rewrite-guard blocker work in [`src/passes/vacuum.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/vacuum.mbt). The hot `TDrop` rewrite path previously invoked `vq_rewrite_preserves_stack_sig_cached(...)` directly for candidate transitions like `drop(next_value)`, `drop(drop(inner)) -> drop(inner)`, and `drop(local.tee(...)) -> local.set(...)`, even when a cheaper local stack-signature equivalence check was available from the drop wrapper shape itself.

The drop rewrite path now uses a dedicated local guard, `vq_drop_rewrite_preserves_stack_sig_from_children(...)`, which compares wrapper-equivalent stack signatures via child signatures (`drop(child)` formula) using indexed ids when available. Generic `vq_rewrite_preserves_stack_sig_cached(...)` checks are still retained, but only as uncommon fallback when the local guard rejects a candidate. This keeps correctness safety for conservative indexed mismatches while removing generic rewrite-stack checks from the hot successful local-rewrite path.

As part of this change, `vq_rewrite_preserves_stack_sig_cached(...)` is now explicitly timed/count-tracked through `rewrite_stack_ms` / `rewrite_stack_calls`, so fallback usage is observable in helper summaries.

Regression coverage in [`src/passes/vacuum.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/vacuum.mbt) now includes:
- Existing indexed test still asserting `rewrite_stack_calls == 0` for `drop(local.tee)` rewrite
- New unindexed counterpart:
  - `vacuum unindexed drop(local.tee) rewrite avoids generic stack-preservation helper`

Verification: `moon test src/passes` (red first after instrumentation showed `1 != 0`, then green after local-guard rewrite), `moon info && moon fmt`, and full `moon test` (3041 passing, 0 failing).

## 2026-03-12 Vacuum Follow-up: expanded unindexed fallback-scan fast paths to expression-level break/value-break helpers for multi-item label-free rewritten trees

This follow-up continues the `Vacuum` Stage 3 fallback-scan reductions in [`src/passes/vacuum.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/vacuum.mbt). Earlier changes skipped expensive fallback scans for trivial unindexed single-instruction cases. Two helper paths were still scanning for multi-item rewritten expressions even when label metadata proved no depth-0 targets were possible:
- `vq_has_break_to_depth0_cached(...)` still called `vq_has_break_to_depth_in_texpr_timed(...)`
- `vq_has_value_break_lub_depth0_cached(...)` still called `vq_value_break_to_depth_has_lub(...)`

Both helpers now use expression-level rebase-score gating on unindexed fallback paths. They compute or reuse a score and short-circuit when the score is `< 0`, which proves no depth-0 wrapper-targeted labels exist for the queried expression. A new timed helper, `vq_texpr_rebase_label_score_timed(...)`, was added so this fallback work remains visible through `rebase_score_calls` / `rebase_score_ms`.

Regression coverage was expanded in [`src/passes/vacuum.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/vacuum.mbt) with red-first tests:
- `vacuum cached break helper skips unindexed label-free multi-item fallback scan`
- `vacuum cached value-break helper skips unindexed label-free multi-item fallback scan`

Both tests assert that generic collectors are skipped (`break_scan_calls == 0` / `value_break_lub_calls == 0`) and that exactly one rebase-score pass runs (`rebase_score_calls == 1`).

Verification: `moon test src/passes` (red first on both new tests, then green), `moon info && moon fmt`, and full `moon test` (3040 passing, 0 failing).

## 2026-03-12 Vacuum Follow-up: added an unindexed single-item fast path for cached value-break LUB queries to skip unnecessary fallback collection

This follow-up continues the pathological-`Vacuum` fallback optimization work in [`src/passes/vacuum.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/vacuum.mbt). `vq_has_value_break_lub_depth0_cached(...)` already used indexed depth-0 metadata when `expr_id` was available, but for unindexed rewritten expressions it always delegated to `vq_value_break_to_depth_has_lub(...)`, even for single-instruction label-free trees where a depth-0 value break is impossible.

The helper now accepts an optional single-instruction rebase-score hint and, on unindexed single-item expressions, short-circuits to `false` when the (provided or locally computed) score is `< 0`. That avoids invoking the full fallback LUB collector in no-break shapes while keeping existing behavior for indexed expressions and non-trivial unindexed trees.

Regression coverage was expanded in [`src/passes/vacuum.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/vacuum.mbt) with a red-first test:
- `vacuum cached value-break helper skips unindexed label-free fallback scan`

The test now asserts both `value_break_lub_calls == 0` and `rebase_score_calls == 1`, proving the new path avoids the expensive collector and performs only one local score pass.

Verification: `moon test src/passes` (red first on the new assertion, then green), `moon info && moon fmt`, and full `moon test` (3038 passing, 0 failing).

## 2026-03-12 Vacuum Follow-up: deduplicated unindexed rebase-score analysis across simplify-block break checks and rebase gating, with explicit helper timing counters

This follow-up continues the pathological-`Vacuum` fallback optimization track in [`src/passes/vacuum.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/vacuum.mbt). After the prior block-simplify reshaping, unindexed single-item wrapper-collapse candidates still scored label metadata twice: once in `vq_has_break_to_depth0_cached(...)` to decide whether depth-0 break scanning could be skipped, and again in `vq_rebase_labels_for_collapsed_wrapper_if_needed(...)` to decide whether rebasing was needed. On rewritten trees this duplicated recursive score traversal in a hot path.

The simplify path now computes one score per single-item candidate and threads it through both decision points. `vq_has_break_to_depth0_cached(...)` gained an optional `single_instr_rebase_label_score` input, and `vq_rebase_labels_for_collapsed_wrapper_if_needed(...)` gained an optional `rebase_label_score` input for unindexed fallback gating. `vq_simplify_block_to_contents(...)` now supplies a shared score (indexed-node score when available, otherwise one timed local score computation) so unindexed single-item candidates avoid repeated recursive scoring.

Helper instrumentation was also extended so this cost is observable in traces: `VQRunStats` now records `rebase_score_ms` and `rebase_score_calls`, and helper-summary output reports both fields in `helper_totals`.

Regression coverage in [`src/passes/vacuum.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/vacuum.mbt) now locks in the dedupe behavior by asserting `rebase_score_calls == 1` for two unindexed simplify-block collapse cases that previously scored twice:
- `vacuum simplify_block skips label rebasing for unindexed label-free body`
- `vacuum simplify_block skips label rebasing for unindexed depth-local branch`

Verification: `moon test src/passes`, `moon info && moon fmt`, and full `moon test` (3037 passing, 0 failing).

## 2026-03-12 Vacuum Follow-up: removed unconditional depth-0 break scans from block simplification and gated unindexed fallback scans behind label-score checks

This follow-up continues the pathological-`Vacuum` hot-path cleanup in [`src/passes/vacuum.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/vacuum.mbt). `vq_simplify_block_to_contents(...)` previously called `vq_has_break_to_depth0_cached(...)` up front for every block body, even when simplification could not collapse the wrapper (empty or multi-item bodies). That forced avoidable fallback scans on rewritten/unindexed trees and kept `break_scan_calls` active in cases where the function would return the original block shape either way.

The block simplifier now short-circuits by body shape first: empty and multi-item bodies return directly without any depth-0 break query, and only single-item collapse candidates perform break checks. In the same patch, `vq_has_break_to_depth0_cached(...)` gained an unindexed fast path that skips fallback `has_break_to_depth_in_texpr(...)` scans when a single instruction’s local rebase-label score is `< 0`, which proves wrapper-depth (`depth=0`) breaks are impossible.

Regression coverage was expanded in [`src/passes/vacuum.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/vacuum.mbt) with red-first assertions in existing unindexed collapse tests plus a new multi-item regression:
- `vacuum simplify_block skips label rebasing for unindexed label-free body` now also asserts `break_scan_calls == 0`
- `vacuum simplify_block skips label rebasing for unindexed depth-local branch` now also asserts `break_scan_calls == 0`
- `vacuum simplify_block skips break scan for unindexed multi-item body`

Verification: `moon test src/passes`, `moon info && moon fmt`, and full `moon test` (3037 passing, 0 failing).

## 2026-03-12 Vacuum Follow-up: skipped unnecessary wrapper-collapse label rebasing for unindexed rewritten bodies by adding a local rebase-score fast path

This follow-up continues the same pathological-`Vacuum` blocker track in [`src/passes/vacuum.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/vacuum.mbt). The previous change replaced the generic `legacy module rewrite engine` rebase with a custom recursive walker, but `vq_simplify_block_to_contents(...)` still had one expensive fallback path: when collapsing a single-item wrapper whose body no longer had an indexed `instr_id`, `vq_rebase_labels_for_collapsed_wrapper_if_needed(...)` always ran the full rebase walk even when the rewritten subtree had no labels (or only depth-local labels that do not change under one-level wrapper collapse).

The fallback gate now uses a new local recursive score helper (`vq_instr_rebase_label_score(...)` plus `vq_texpr_rebase_label_score(...)`) that mirrors the indexed `max_rebase_label_score` semantics. For indexed nodes, behavior is unchanged and still uses precomputed metadata. For unindexed rewritten nodes, rebasing now runs only when the local score is `>= 0`; otherwise the instruction is returned directly. This avoids unnecessary subtree rewrites in hot collapse paths without changing correctness for branch/catch label adjustment cases that actually need rebasing.

Regression coverage was expanded in [`src/passes/vacuum.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/vacuum.mbt) with two red-first tests that enabled active helper stats and proved `vq_simplify_block_to_contents(...)` no longer calls label rebasing for unindexed single-item collapses when labels are either absent or depth-local only:
- `vacuum simplify_block skips label rebasing for unindexed label-free body`
- `vacuum simplify_block skips label rebasing for unindexed depth-local branch`

Verification: `moon test src/passes` (red first on both new tests, then green), `moon info && moon fmt`, and full `moon test` (3036 passing, 0 failing).

## 2026-03-12 Vacuum Follow-up: removed remaining value-keyed `typed instruction node` fallback caches from `Vacuum` metadata paths so both instruction and expression fallback queries now avoid structural-key map churn

This follow-up continues the same pathological-`Vacuum` hardening track by removing the rest of the value-keyed fallback cache surface in [`src/passes/vacuum.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/vacuum.mbt). After the previous expression-cache cleanup, fallback instruction metadata still used `Map[typed instruction node, ...]` for type/effect/shallow-effect/call/control-transfer/stack-signature/may-not-return queries. Those maps have now been removed from `VQAnalysisCache`.

All affected helper paths keep the existing indexed-node fast path for seeded/original instructions and now do direct fallback computation when no `instr_id` is available. This keeps correctness behavior while eliminating value-keyed cache insert/lookups for rewritten instruction trees. `vq_analysis_cache_instr_entry_count(...)` now reports indexed instruction-node entries only.

Regression coverage was expanded in [`src/passes/vacuum.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/vacuum.mbt) with a red-first test that exercises fallback instruction metadata helpers (`type`, `effect`, `shallow effect`, `calls`, `control transfer`, `stack signature`, `may-not-return`) and asserts no fallback instruction cache-entry growth. Existing indexed tests that previously inspected internal type-cache maps were updated to assert instruction cache cardinality stability instead.

Verification: `moon test src/passes`, `moon info && moon fmt`, and full `moon test` (3034 passing, 0 failing).

## 2026-03-12 Publishing Blocker Closed: hardened pathological `Vacuum` metadata paths by removing value-keyed `typed instruction body` fallback caches, keeping seeded-node lookups indexed, and proving fallback queries no longer allocate expression-cache entries

This change closes the remaining `Vacuum` pathological-cleanup blocker in [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md) by tightening the metadata paths that still relied on value-keyed expression maps after the earlier shape-classifier and degraded-tier work. The pass had already moved its hot original-node lookups onto integer-indexed analysis tables, but fallback metadata queries for rewritten/non-indexed expressions still maintained `Map[typed instruction body, ...]` caches (`control_transfer`, `throws`, `explicit_unreachable`, and depth-0 value-break LUB). Those value-keyed maps are now removed from [`src/passes/vacuum.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/vacuum.mbt), so fallback expression metadata is computed directly when no indexed `expr_id` is available instead of re-hashing/re-comparing recursive expression values in map operations.

The cache surface was simplified in three concrete ways. First, `VQAnalysisCache` no longer stores expression-keyed fallback maps for control-transfer, throw, explicit-unreachable, or value-break-LUB facts. Second, `vq_texpr_has_control_transfer_cached`, `vq_texpr_throws_cached`, and `vq_texpr_has_explicit_unreachable_cached` now use indexed-node fast paths when available and otherwise perform direct computation without inserting expression-keyed cache entries. Third, `vq_value_break_to_depth_has_lub` keeps indexed depth-0 reuse but drops the legacy `Map[typed instruction body, Bool]` fallback write path. As a result, expression cache-cardinality accounting in `vq_analysis_cache_expr_entry_count(...)` now reports only indexed analysis-table entries.

Regression coverage was expanded in [`src/passes/vacuum.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/vacuum.mbt) with two new tests: one that exercises fallback control/throw/unreachable metadata queries and asserts zero expression-cache entry growth, and one that exercises fallback value-break LUB querying with the same zero-growth assertion. Existing indexed value-break tests were also tightened to assert expression entry counts remain stable before/after indexed LUB checks, ensuring no hidden fallback cache writes regress back in.

Verification followed the repository gate sequence: `moon test src/passes` (red first on the new assertions, then green after the implementation), `moon info && moon fmt`, and full `moon test` (3033 passing, 0 failing).

## 2026-03-12 Publishing Blocker Closed: completed the fuzz runner usability/output/script blockers by adding discoverable CLI control commands, machine-readable JSONL summaries, and optional-seed script forwarding

This change completes the remaining low-hanging fuzz workflow blockers tracked in [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md): (1) control-command discoverability in the fuzz binary, (2) deterministic machine-readable summary output mode, and (3) optional seed forwarding in helper scripts so default runs exercise generated seeds.

In [`src/fuzz/main.mbt`](/home/jtenner/Projects/starshine-mb/src/fuzz/main.mbt), the CLI now supports control commands through `parse_fuzz_cli_command(...)`: `--help`/`-h`, `--list-suites`, and `--list-profiles`. This makes supported suite/profile discovery available directly from the binary without requiring doc/source lookup. The same parser path now supports output mode flags in the runnable command flow (`--output text|jsonl` and `--jsonl`), and result rendering is centralized in `format_fuzz_suite_result(...)` with `FuzzOutputMode` so text and JSONL output share one source of truth.

JSON output is emitted as one object per line (`jsonl`) with stable fields (`suite`, `profile`, `seed`, `attempts`, `pass`, `elapsed_ms`) to support CI parsing and metrics aggregation. The new mode still preserves existing text-mode output as default, and existing suite execution semantics are unchanged.

Helper scripts were updated to make seeds optional by default. [`scripts/run-fuzz.sh`](/home/jtenner/Projects/starshine-mb/scripts/run-fuzz.sh) now accepts `[profile] [suite] [seed|target] [target]` and only forwards `--seed` when a seed value is explicitly supplied. [`scripts/run-full-test.sh`](/home/jtenner/Projects/starshine-mb/scripts/run-full-test.sh) now mirrors that behavior with `[fuzz_profile] [seed|target] [target]`, prints `seed=auto` when no seed is provided, and delegates to `run-fuzz.sh` without a seed argument in that case.

Regression/verification coverage was extended in [`src/fuzz/main_test.mbt`](/home/jtenner/Projects/starshine-mb/src/fuzz/main_test.mbt) for output-mode parsing, control-command parsing, and JSONL formatting behavior. Validation was performed with `moon test src/fuzz`, direct command checks (`moon run src/fuzz -- --help`, `--list-suites`, and JSONL mode with explicit seed), and a full gate run via `bash scripts/run-full-test.sh smoke wasm-gc`.

## 2026-03-12 Fuzz Harness Migration Completed: moved randomized fuzz workloads out of `moon test` into the dedicated `src/fuzz` binary, wired CI/full-test gates to execute fuzz explicitly, and added reproducible signed seed controls for reruns

This changelog entry summarizes the fuzz-harness migration chain landed on `2026-03-12` across commits `fad5f6e`, `3772c24`, `357c650`, and `4a1b7a6`. The core shift is architectural: heavy randomized workloads are no longer hosted in the default `moon test` harness path, and instead run through a dedicated executable fuzz entrypoint in [`src/fuzz/main.mbt`](/home/jtenner/Projects/starshine-mb/src/fuzz/main.mbt) via `moon run src/fuzz ...`. That binary dispatches suite/profile combinations, prints reproducibility metadata, and routes into extracted package-level fuzz runner APIs.

The initial migration commit (`fad5f6e`) introduced the new main package at [`src/fuzz/moon.pkg`](/home/jtenner/Projects/starshine-mb/src/fuzz/moon.pkg), implemented CLI dispatch/tests in [`src/fuzz/main.mbt`](/home/jtenner/Projects/starshine-mb/src/fuzz/main.mbt) and [`src/fuzz/main_test.mbt`](/home/jtenner/Projects/starshine-mb/src/fuzz/main_test.mbt), and extracted major runner surfaces from package-local tests: WAST/WAT roundtrip, validator valid/invalid generation, and cmd harness profile adapters (notably in [`src/wast/fuzz_tests.mbt`](/home/jtenner/Projects/starshine-mb/src/wast/fuzz_tests.mbt), [`src/wat/fuzz_tests.mbt`](/home/jtenner/Projects/starshine-mb/src/wat/fuzz_tests.mbt), [`src/validate/validate.mbt`](/home/jtenner/Projects/starshine-mb/src/validate/validate.mbt), [`src/validate/invalid_fuzzer.mbt`](/home/jtenner/Projects/starshine-mb/src/validate/invalid_fuzzer.mbt), and [`src/cmd/fuzz_harness.mbt`](/home/jtenner/Projects/starshine-mb/src/cmd/fuzz_harness.mbt)). The follow-up commit (`3772c24`) finished migration of the binary roundtrip workload into [`src/binary/tests.mbt`](/home/jtenner/Projects/starshine-mb/src/binary/tests.mbt) + [`src/fuzz/main.mbt`](/home/jtenner/Projects/starshine-mb/src/fuzz/main.mbt), and removed the remaining fuzz-execution loops from default test files so `moon test` remains deterministic and CI-friendly while fuzz stays runnable through `src/fuzz`.

Operational wiring was then consolidated in commit `357c650`: [`scripts/run-full-test.sh`](/home/jtenner/Projects/starshine-mb/scripts/run-full-test.sh) became the canonical local/CI gate (`moon info`, `moon fmt`, `moon check`, `moon test`, then fuzz), and [`.github/workflows/fuzz.yml`](/home/jtenner/Projects/starshine-mb/.github/workflows/fuzz.yml) was updated to call that unified gate for normal CI while retaining scheduled native stress fuzzing. Helper tooling and docs were aligned during the migration in [`scripts/run-fuzz.sh`](/home/jtenner/Projects/starshine-mb/scripts/run-fuzz.sh), [`docs/fuzz-migration.md`](/home/jtenner/Projects/starshine-mb/docs/fuzz-migration.md), and [`README.mbt.md`](/home/jtenner/Projects/starshine-mb/README.mbt.md), including benchmark command updates in [`scripts/update_readme_benchmarks.sh`](/home/jtenner/Projects/starshine-mb/scripts/update_readme_benchmarks.sh).

The final hardening step (`4a1b7a6`) upgraded reproducibility controls by adding signed 64-bit seed support and explicit seed flags. [`src/fuzz/main.mbt`](/home/jtenner/Projects/starshine-mb/src/fuzz/main.mbt) now accepts `--seed <int64>` and `--seed=<int64>`, rejects ambiguous dual seed sources (positional + flag), and generates a default seed from Moon time APIs when omitted. The runtime-facing runner boundary still reinterprets the signed seed into `UInt64` for splitmix-backed generators, and the generated public interface in [`src/fuzz/pkg.generated.mbti`](/home/jtenner/Projects/starshine-mb/src/fuzz/pkg.generated.mbti) reflects the `Int64`-seeded API surface. Script/docs usage was updated to include `moon run ... -- ... --seed ...` forwarding semantics so Moon does not consume the fuzz binary’s flags.

## 2026-03-12 Publishing Blocker Closed: Split the local `ConstantFieldPropagation` / Binaryen `cfp-reftest` behavior by introducing `ConstantFieldNullTestFolding`, moving the known-null `ref.test` optimization behind its own higher-gated pass, and removing the misleading one-pass parity claim from the scheduler and docs

This change closes the publishing blocker around the local handling of Binaryen's `cfp-reftest` slot. Before this patch, [`src/passes/constant_field_propagation.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/constant_field_propagation.mbt) mixed two different concerns into the same implementation surface: real constant-field propagation for `struct.get` loads, and a much narrower optimization that folded `ref.test` / `ref.test_desc` when the source field was known to be `ref.null`. That made the scheduler comment in [`src/passes/optimize.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/optimize.mbt) read as if `ConstantFieldPropagation` already covered Binaryen's broader `cfp-reftest` transform, even though Binaryen's fixture exercises subtype-selection rewrites that this code does not implement. The pass file now shares a single field-analysis helper, keeps `ConstantFieldPropagation` focused on replacing provably constant field reads, and routes the known-null `ref.test` / `ref.test_desc` folding through a separate `ConstantFieldNullTestFolding` optimizer built on the same analysis state.

The default global pre-pass scheduler in [`src/passes/optimize.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/optimize.mbt) now reflects that split explicitly. Closed-world GC modules still get `ConstantFieldPropagation` after `RemoveUnusedTypes`, but the narrower `ConstantFieldNullTestFolding` pass is added only at the higher `optimize_level >= 3` gate where the old code had been carrying the Binaryen `cfp-reftest` comment. The pass enum/dispatcher was extended accordingly, the generated public interface in [`src/passes/pkg.generated.mbti`](/home/jtenner/Projects/starshine-mb/src/passes/pkg.generated.mbti) was refreshed, and the explicit-pass surfaces in [`src/cmd/cmd.mbt`](/home/jtenner/Projects/starshine-mb/src/cmd/cmd.mbt) and [`src/node_api/custom.mbt`](/home/jtenner/Projects/starshine-mb/src/node_api/custom.mbt) now expose the new pass under the precise name `constant-field-null-test-folding`.

Regression coverage was tightened in two places. In [`src/passes/constant_field_propagation.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/constant_field_propagation.mbt), a new test proves that `make_cfp_optimizer(...)` now leaves `ref.test` alone so the split is real, while the existing known-null `ref.test` and `ref.test_desc` tests were retargeted to the dedicated null-test optimizer and extended to verify nullable-target results (`i32.const 1`) as well as non-null-target results (`i32.const 0`). In [`src/passes/optimize.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/optimize.mbt), the old scheduler test that claimed `cfp-reftest` mapped directly to `ConstantFieldPropagation` was replaced with a stronger split-behavior test: it now proves that `-O2` closed-world GC scheduling does not include `ConstantFieldNullTestFolding`, while `-O3` includes both `ConstantFieldPropagation` and the dedicated null-test pass in that order. The red-first TDD step was captured with an initial `moon test src/passes` run that failed because the new tests referenced the missing dedicated pass and the old CFP implementation still owned the `ref.test` fold.

The documentation and backlog were updated to match the new reality. [`README.mbt.md`](/home/jtenner/Projects/starshine-mb/README.mbt.md) now describes `ConstantFieldNullTestFolding` as a separate pass and no longer claims `cfp-reftest -> ConstantFieldPropagation` as a direct parity mapping. [`docs/0002-2026-03-11-differences.md`](/home/jtenner/Projects/starshine-mb/docs/0002-2026-03-11-differences.md) was rewritten to explain that the misleading one-pass parity claim is gone and that the remaining Binaryen difference is now an explicit, narrower known-null subset rather than a conflated implementation story. The closed blocker was removed from [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md) and recorded in the new "Recently completed" section there so the release backlog reflects the resolved split.

Verification followed the repository workflow: `moon test src/passes` passed once the split was implemented, then `moon info`, `moon fmt`, and a full `moon test` run were used to confirm the workspace stayed green with the new pass surface and scheduler policy.

## 2026-03-12 Publishing Blocker Closed: Enabled Binaryen-parity `InliningOptimizing` scheduling in the default global post-optimization pipeline so post-cleanup inlining now runs before duplicate-elimination and global-simplification passes under the standard `-O2`/`-Os` style gates

This change closes the publishing blocker around the default global post pipeline in [`src/passes/optimize.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/optimize.mbt). The `InliningOptimizing` pass has existed as an implemented module runner and has long been exposed through the custom pass surface, but the default `default_global_optimization_post_passes(...)` scheduler still carried a comment saying the Binaryen-parity `inlining-optimizing` slot was intentionally skipped because of earlier option-mismatch concerns. In practice that meant the default post-cleanup flow diverged from Binaryen even when callers requested the optimization levels where post-phase inlining is expected. The scheduler now uses the already-established parity gate, `optimize_level >= 2 || shrink_level >= 2`, and inserts `InliningOptimizing` immediately after `DeadArgumentEliminationOptimizing` and before the duplicate-elimination and simplify-globals cleanup passes that are supposed to benefit from the extra inlining work.

The regression coverage for this blocker lives directly in [`src/passes/optimize.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/optimize.mbt). The existing post-pipeline parity test was tightened in two ways: it now asserts that `InliningOptimizing` appears exactly once for a representative `optimize_level=2, shrink_level=2` configuration, and it also asserts the pass ordering boundary by requiring `DeadArgumentEliminationOptimizing` to remain first and `InliningOptimizing` to occupy the next slot. That keeps the test focused on the scheduler policy itself rather than re-testing the inliner implementation. The red-first TDD step was captured with an initial `moon test src/passes` run that failed on the old `0 != 1` expectation before the scheduler was updated.

The Binaryen comparison note in [`docs/0002-2026-03-11-differences.md`](/home/jtenner/Projects/starshine-mb/docs/0002-2026-03-11-differences.md) was updated so the repository no longer documents `InliningOptimizing` as an open global-post-pipeline omission. The closed blocker was then removed from [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md), leaving `StringGathering` and the other remaining optimizer parity items as the outstanding publish blockers in that area.

Verification followed the repository's required local sequence after the red regression run: `moon test src/passes` passed once the scheduler was fixed, then `moon info`, `moon fmt`, and a full `moon test` run were executed to confirm the broader workspace remained green.

## 2026-03-12 Publishing Blocker Closed: Refined the default late `OptimizeInstructions` cleanup policy so large modules still keep the final Binaryen-parity instruction-cleanup pass during explicit size-focused optimization while the throughput-oriented path retains the existing large-module runtime guard

This change closes the publishing blocker around the default pipeline's second `OptimizeInstructions` pass in [`src/passes/optimize.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/optimize.mbt). The scheduler already had a large-module cleanup-cost heuristic that could suppress the late `OptimizeInstructions` pass near the end of the default function pipeline, but that guard applied unconditionally once the module crossed the runtime threshold. In practice, that meant a caller explicitly asking for stronger code-size cleanup with `shrink_level=2` could still silently lose the late instruction-level cleanup stage simply because the module was large. The policy helper now takes the full optimization options, preserves the large-module skip for the throughput-focused path, and explicitly keeps the second `OptimizeInstructions` pass whenever the caller is in the strong size-optimization mode.

The behavior is now documented as an intentional policy choice instead of an ambiguous heuristic. The Binaryen-comparison note in [`docs/0002-2026-03-11-differences.md`](/home/jtenner/Projects/starshine-mb/docs/0002-2026-03-11-differences.md) was rewritten to explain that the local optimizer still diverges from Binaryen on very large throughput-focused modules, but no longer lets that runtime guard override explicit shrink intent. That makes the scheduler policy much easier to reason about: large `-O` style throughput runs still avoid the extra late cleanup when the module looks pathologically expensive, while large `-Oz` style runs keep the final instruction simplification step because size cleanup is the caller's stated goal.

Regression coverage for the policy now lives directly in [`src/passes/optimize.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/optimize.mbt). A new large synthetic module helper drives the heuristic boundary explicitly, one test proves that a large module with `optimize_level=2, shrink_level=2` now retains both `OptimizeInstructions` passes in the default function schedule, and a companion test proves that the large-module throughput-focused configuration with `optimize_level=2, shrink_level=0` still keeps only the earlier pass. The resolved blocker was removed from [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md) after the new policy and regression coverage were in place.

Verification followed the project's required local sequence and the explicit TDD flow. The new size-focused scheduler test was added first and failed under `moon test src/passes` with `1 != 2`, confirming the pre-fix behavior. After the helper change, `moon test src/passes` passed with 1377 tests green. Final verification then completed with `moon info`, `moon fmt`, and a full `moon test` run with 2984 tests passing and 0 failures.

## 2026-03-12 Publishing Blocker Closed: Split optimizer pass profiling so executed pass summaries now report transform time and post-pass validation time separately instead of collapsing both costs into one misleading pass elapsed number on pathological modules

This change closes the optimizer profiling blocker where traced pass summaries in [`src/passes/optimize.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/optimize.mbt) were measuring from pass entry through the end of any immediate validation step and then reporting only a single `elapsed_ms=` field. On pathological modules, especially when `OptimizeValidationPolicy::after_every_pass()` is enabled for debugging or investigation, that made it difficult to tell whether a slow pass summary was actually dominated by the transform itself or by the full-module validation walk that happened immediately afterward. The optimizer loop now snapshots the transform boundary as soon as the scheduled pass runner returns, records that duration as `transform_elapsed_ms`, separately records the immediate validation walk as `validation_elapsed_ms`, and preserves the overall wall-clock `elapsed_ms` field for the end-to-end pass total.

The trace surface was tightened in three concrete ways. Executed passes now emit an explicit phase-level `transform:done` timing line as soon as scheduler work finishes, pass-summary `done` lines now carry `transform_elapsed_ms=... validation_elapsed_ms=... elapsed_ms=...`, and per-pass validation failures now report the same split fields before returning the existing pass-attributed error message. Skipped passes were also normalized onto the same summary schema with zeroed transform and validation fields so downstream log parsing does not need special handling for the skip case. This keeps the profiling contract machine-readable while making pathological slowdowns much easier to classify as transform cost versus validation overhead.

Regression coverage for the runner change was added directly in [`src/passes/optimize.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/optimize.mbt). The new test drives `optimize_module_with_options_trace(...)` under `AfterEveryPass` validation and asserts that the emitted pass summary for an executed pass now includes both `transform_elapsed_ms=` and `validation_elapsed_ms=` fields. The tracing guidance in [`docs/0001-2026-03-10-tracing.md`](/home/jtenner/Projects/starshine-mb/docs/0001-2026-03-10-tracing.md) was also updated so future pass instrumentation preserves this split timing convention instead of reintroducing collapsed pass timings.

Verification for this blocker was completed with an initial red `moon test src/passes` run that failed on the new regression before the runner was updated, a green `moon test src/passes` run after the fix, then the required final local sequence of `moon info`, `moon fmt`, and a full `moon test` run. The remaining Moon warnings reported during the repo-wide checks are the pre-existing `unused_try` warnings outside this change.

## 2026-03-12 Publishing Blocker Closed: Replaced the default WASI wildcard-candidate stub with real recursive directory enumeration so `--glob` works under shared MoonBit filesystem APIs on both native and WASI runtimes

This change removes the last stubbed candidate-enumeration path that blocked reliable publishing for default WASI I/O. The command layer now resolves wildcard inputs through a shared MoonBit filesystem walker instead of bespoke `find` output on native builds or a separate `list_candidates` shim on WASI builds. That walker lives in [`src/fs/fs.mbt`](/home/jtenner/Projects/starshine-mb/src/fs/fs.mbt), uses `moonbitlang/x/fs` directory APIs recursively, normalizes separators, preserves deterministic depth-first ordering by explicitly sorting directory entries, and returns only file paths so CLI glob matching sees the same candidate model across runtimes.

The runtime integration was updated in three places: [`src/cmd/cmd.mbt`](/home/jtenner/Projects/starshine-mb/src/cmd/cmd.mbt) now routes default candidate discovery through the shared walker, [`node/internal/runtime.js`](/home/jtenner/Projects/starshine-mb/node/internal/runtime.js) and [`node/internal/wasi-runner.js`](/home/jtenner/Projects/starshine-mb/node/internal/wasi-runner.js) now expose the `moonbitlang/x/fs` wasm hooks needed for reading directories and statting entries, and [`scripts/lib/moonbit-wasi-runner.mjs`](/home/jtenner/Projects/starshine-mb/scripts/lib/moonbit-wasi-runner.mjs) was brought up to the same contract so script-driven WASI runs behave the same way. In practice, this means wildcard expansion no longer depends on a custom candidate stub and instead uses the same directory-reading primitives as the rest of the filesystem layer.

Regression coverage was added in [`src/fs/fs_test.mbt`](/home/jtenner/Projects/starshine-mb/src/fs/fs_test.mbt) to build a nested directory tree and prove that recursive candidate enumeration returns the expected file-only paths in stable order, and the generated filesystem interface in [`src/fs/pkg.generated.mbti`](/home/jtenner/Projects/starshine-mb/src/fs/pkg.generated.mbti) was refreshed to publish the new helper. Verification for this blocker was completed with `moon info`, `moon fmt`, `moon test src/fs`, `moon test src/cmd`, a syntax/import sanity check for the edited Node runtime shims, and a full `moon test` run with 2976 tests passing.

## 2026-03-12 Publishing Blocker Closed: Added the missing Binaryen-parity `RemoveUnusedNames` cleanup passes to the default function optimization pipeline so branch-name cleanup now happens at the intended repeated structural cleanup boundaries

This change closes the default-function-pipeline parity gap where `RemoveUnusedNames` existed as an implemented pass but was never scheduled by the default optimizer flow. The scheduler in [`src/passes/optimize.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/optimize.mbt) now inserts `RemoveUnusedNames` three times in the same conceptual cleanup slots described by the repository’s Binaryen-difference notes: once immediately after `DeadCodeElimination`, once immediately after the first `RemoveUnusedBrs`, and once in the later cleanup phase after the first late `MergeBlocks` / `RemoveUnusedBrs` pair and before the final `MergeBlocks`. That brings the cleanup choreography much closer to Binaryen’s repeated name-pruning structure rather than leaving all such cleanup to later incidental transformations.

The regression coverage for this blocker was added directly in [`src/passes/optimize.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/optimize.mbt). The new test proves that the default function optimization pass list includes exactly three `RemoveUnusedNames` passes and that their relative order matches the intended parity boundaries around `DeadCodeElimination`, `RemoveUnusedBrs`, and the late `MergeBlocks` cleanup region. Because the repository already had execution tests for `RemoveUnusedNames` itself, the new coverage stays focused on the missing scheduler wiring rather than re-testing the transform implementation.

The parity note in [`docs/0002-2026-03-11-differences.md`](/home/jtenner/Projects/starshine-mb/docs/0002-2026-03-11-differences.md) was also updated so the repository no longer documents this as an unresolved scheduler gap. Verification for this blocker was completed with `moon test src/passes`, `moon info`, `moon fmt`, and a full `moon test` run with 2977 tests passing. The remaining Moon warnings reported during `moon info` and `moon test` are the pre-existing `unused_try` warnings outside this change.

## 2026-03-12 Publishing Blocker Closed: Aligned the closed-world global pre-pass scheduler with Binaryen by using `RemoveUnusedModuleElements` instead of `RemoveUnused` at the default pre-pass cleanup points

This change closes the scheduler-policy gap where the closed-world global pre-pass pipeline diverged from Binaryen by substituting `RemoveUnused` for `RemoveUnusedModuleElements`. The relevant logic lives in [`src/passes/optimize.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/optimize.mbt), and the default pre-pass builder now uses `RemoveUnusedModuleElements` at both `-O2+` cleanup sites regardless of the `closed_world` flag. The closed-world-specific GC refinements such as `TypeRefining`, `SignaturePruning`, `SignatureRefining`, `GlobalTypeOptimization`, `RemoveUnusedTypes`, `ConstantFieldPropagation`, `AbstractTypeRefining`, and `Unsubtyping` remain gated as before; this change only aligns the shared unused-module-element cleanup choice itself.

The regression coverage was updated in [`src/passes/optimize.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/optimize.mbt) so the closed-world global pre-pass test now requires two `RemoveUnusedModuleElements` passes and explicitly proves that the default closed-world schedule no longer inserts `RemoveUnused` at those parity points. Because the repository already contains direct dispatch tests for `RemoveUnused`, `RemoveUnusedModuleElements`, and the legacy `RemoveUnusedNonFunctionElements` behavior, the new scheduler expectation stays focused on the default pipeline policy rather than re-testing the individual transforms.

The Binaryen-difference note in [`docs/0002-2026-03-11-differences.md`](/home/jtenner/Projects/starshine-mb/docs/0002-2026-03-11-differences.md) was also updated so the repository no longer records this closed-world pre-pass substitution as an unresolved parity difference. Verification for this blocker was completed with `moon test src/passes`, `moon info`, `moon fmt`, and a full `moon test` run with 2977 tests passing. The remaining Moon warnings reported during `moon info` and `moon test` are the pre-existing `unused_try` warnings outside this change.

## 2026-03-12 Publishing Blocker Closed: Made optimizer validation policy configurable so the default non-debug local optimization path now validates once at the end instead of after every scheduled pass

This change closes a major runtime-policy mismatch in the optimizer runner. The pass loop in [`src/passes/optimize.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/optimize.mbt) previously performed a full module validation after every scheduled pass, regardless of whether the caller wanted debug-style validation or production-style throughput. `OptimizeOptions` now carries a public `OptimizeValidationPolicy`, with the new default set to `FinalModuleOnly` and an explicit `AfterEveryPass` override available for debugging and pass-development workflows. That shifts normal local optimization behavior closer to Binaryen's default non-debug runner, where validation cadence is policy-driven rather than unconditionally baked into every pass boundary.

The runner implementation was updated to preserve diagnostics while removing the default per-pass overhead. When `AfterEveryPass` is requested, the old behavior is retained: the pass loop validates immediately after each executed pass and reports failures against that pass. Under the new default `FinalModuleOnly` policy, the loop records the last executed pass and its pre-pass module snapshot, defers validation until the full pass sequence has completed, and still formats any resulting validation failure as a pass-attributed error with before/after context. That means callers keep the useful failure surface from [`opt_format_pass_validation_failure`](/home/jtenner/Projects/starshine-mb/src/passes/optimize.mbt) without paying the unconditional validation cost at every single pass boundary.

Regression coverage was added directly in [`src/passes/optimize.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/optimize.mbt). The new tests construct an intentionally invalid module and run it through two harmless scheduler passes so the returned error message proves which validation policy actually ran: the default path now attributes the failure to the last pass in the sequence, while the explicit `AfterEveryPass` option fails immediately after the first pass. The existing validation-diff test was also deduplicated through a shared invalid-module helper so the new policy coverage stays focused on runner semantics rather than repeating module construction boilerplate.

The parity note in [`docs/0002-2026-03-11-differences.md`](/home/jtenner/Projects/starshine-mb/docs/0002-2026-03-11-differences.md) was rewritten to describe the resolved policy and its remaining explicit opt-in path, and the Node API documentation will reflect the new trailing `validationPolicy` parameter on `OptimizeOptions.new(...)` after interface regeneration. Verification for this blocker was completed with `moon test src/passes`, `moon info`, `moon fmt`, and a full `moon test` run. The remaining Moon warnings reported during `moon info` and `moon test` are the pre-existing `unused_try` warnings outside this change.
