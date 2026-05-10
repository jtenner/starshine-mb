---
kind: comparison
status: working
last_reviewed: 2026-05-06
sources:
  - ../../../raw/research/0541-2026-05-06-simplify-locals-direct-revalidation.md
  - ../../../../../agent-todo.md
  - ../../../../../CHANGELOG.md
  - ../../../../../src/passes/simplify_locals_test.mbt
  - ../../../../../src/passes/pass_manager_wbtest.mbt
  - ../../../../../src/passes/perf_test.mbt
  - ../../../../../src/passes_perf_long/simplify_locals_multivalue_perf_test.mbt
related:
  - ./index.md
  - ./wat-shapes.md
  - ./raw-lane-and-writeback.md
  - ./validation-and-signoff.md
  - ./performance-and-artifact-frontiers.md
---

# `simplify-locals` Parity Status

## Scope

- This page is the living comparison note for Starshine versus Binaryen on `simplify-locals`.
- It keeps durable status and frontier information.
- It is not the place for every temporary trace or reducer transcript.

## What Is Green Today

- The 2026-05-09 direct semantic lane is green on current head:
  - `.tmp/pass-fuzz-simplify-locals-genvalid-10000` reached `10000/10000` compared cases with `10000` normalized matches and `0` mismatches.
  - `.tmp/pass-fuzz-simplify-locals-both-10000-keepgoing` reached `9975/10000` compared cases with `9975` normalized matches, `0` mismatches, and `25` command failures classified as Binaryen/tool parser or canonicalization failures.
- The 2026-05-09 reduced regression for dead one-armed `if` writes with side effects is green; Starshine now keeps the structure-result carrier instead of deleting the tail write before one-armed lifting can run.
- The pass has broad reduced coverage in [`src/passes/simplify_locals_test.mbt`](../../../../../src/passes/simplify_locals_test.mbt).
- The raw lane and skip reasons are guarded in:
  - [`src/passes/pass_manager_wbtest.mbt`](../../../../../src/passes/pass_manager_wbtest.mbt)
  - [`src/passes/perf_test.mbt`](../../../../../src/passes/perf_test.mbt)
  - [`src/passes_perf_long/simplify_locals_multivalue_perf_test.mbt`](../../../../../src/passes_perf_long/simplify_locals_multivalue_perf_test.mbt)
- The refreshed 2026-05-06 direct pass-fuzz lane is green after the fuzzer / harness audit:
  - `.tmp/pass-fuzz-simplify-locals` reached `6759/10000` compared cases with `6759` normalized matches, `0` mismatches, and `20` Binaryen empty-recursion-group parser/canonicalization command failures; see [`0541-2026-05-06-simplify-locals-direct-revalidation.md`](../../../raw/research/0541-2026-05-06-simplify-locals-direct-revalidation.md).
- The 2026-04-14 native-binary fuzz lane is historical green evidence:
  - `.tmp/pass-fuzz-sl-current-2026-04-14` finished at `10000/10000` compared cases with `10000` normalized matches and `0` mismatches.
- The current 2026-04-14 debug-artifact self-opt compare is semantically green at the canonical level:
  - `.tmp/self-opt-sl-current-2026-04-14` reports `normalizedWatEqual=true`, `canonicalFuncPrettyEqual=true`, and no differing function indices.

## Retired Artifact Families

### `Func 216` Single-Use `if (result i32)` Call-Argument Sink

- Retired.
- The pass now sinks a single-use self-contained `if (result i32)` into a later call argument when the leading-evaluation-path rule permits it.

### `StringView.make_init_no_rc` Loop-Carried Initializer

- Retired as a wrong-code bug.
- The pass no longer lets outer pending values flow into loop headers.

### One-Armed `if` Then-Arm `nop` And Live Prefix Roots

- Retired.
- The pass now preserves Binaryen's then-arm `nop` sentinel and live prefix roots when lifting one-armed `if` writes.

### `moonbit.malloc` Sibling-Argument Reordering

- Retired as a wrong-code bug.
- Pending local read/write effects are now collected through `if` / `try` / `try_table` region bodies, and effectful replacements only inline on the leading evaluation path.

### `Func 41` Tee-Backed Alias Drift

- Retired in two steps:
  - preserve tee-backed copied locals for later direct call or branch uses
  - narrow that protection so same-arm non-call aliases still collapse back to the source local

### Old `Func 50` Validator-Skip Loop Temp Drift

- Retired.
- The validator raw-skip path now sinks single-use effectful temps across disjoint pure local-copy barriers.

### Old `Func 71` Validator-Skip Leading-Condition Temp Drift

- Retired.
- The validator raw-skip path now sinks single-use effectful temps when the only real use is on a later structured value body's leading condition path, even when that condition begins with a pure stack prefix.

## Durable Negative Findings

### Broad Lowered-`nop` Stripping

- Rejected.
- The pass-fuzz lane diverged immediately enough that this is now a documented anti-pattern, not just an abandoned experiment.

### Broad `if (result) -> select` Cleanup

- Rejected.
- Reduced Binaryen probes showed Binaryen does not perform the simple selectification families the repo could trivially emit.

## Current Frontier

- The old `Func 71` first-diff frontier recorded below is historical context, not the current first failing comparison.
- The 2026-05-09 direct debug-artifact replay after the compare-canonicalizer follow-up is exact-red but accepted as representation drift for v0.1.0:
  - command: `bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --simplify-locals --out-dir .tmp/sl-artifact-direct-after-setget-canon`
  - `Canonical function compare equal: no`
  - first remaining difference: `defined=208 abs=225`
  - The retired `defined=5 abs=22` diff was representation drift: Binaryen preserved `drop (if (result i32) ...)` with pure terminal arm values while Starshine emitted the equivalent void `if`. `scripts/lib/self-optimize-compare-task.ts` canonicalizes that focused shape, with `scripts/test/self-optimize-compare-dropped-value-if-command.ts` covering it.
  - The new first diff is also a carrier-shape difference: Binaryen keeps an inline value-producing block plus extra typed/void wrappers as a call argument, while Starshine evaluates the same block into a local and later reloads it. The inspected diff did not show an observable call/store/load reordering across the spill boundary, and no pass-fuzz semantic mismatch points to this family.
  - Binaryen accepts both compared outputs through `wasm-opt --all-features -o ...` with the same large-local-count warning family; `wasm-tools validate` rejects the artifact for local-count limits outside `simplify-locals` parity scope.
  - pass-local timing is still well within the signoff threshold: Starshine `486.171ms`, Binaryen `481965.000ms`, `Starshine pass at least as fast: yes`.
- The prior 2026-05-09 direct artifact first diff at `defined=1 abs=18` is retired by allowing one-armed `if` lifting even when the written local has no later reads and by preserving dead one-armed tail writes until the structure rewrite runs.
- The remaining debt is now:
  - exact debug-artifact compare-helper normalization for value-carrier wrappers, tracked outside the v0.1.0 `simplify-locals` direct-pass gate
  - whole-command runtime attribution only when it is clearly not covered by `[WALL]001`

- The old validator raw-skip local-copy and condition-temp frontier is no longer the meaningful first mismatch.
- A newer raw-skip pure-copy fix is now also retired:
  - the `$928 -> $549` one-use store shuttle in `Func 71` is gone
  - the focused `2000`-case fuzz lanes stayed green after both the copy-propagation rewrite and the pure-suffix fixpoint
- The first durable open artifact bucket is now narrower:
  - the fresh rebuilt-binary replay at `/tmp/starshine-self-optimize-compare-starshine-debug-wasi-2522582` no longer shows the earlier `$739 -> $18` copied-local carrier
  - the sibling `$735 -> $24` copied-local carrier in the later returning arm is gone too
  - the first remaining `Func 71` diffs now start at the nested constant and copied-local fanout groups such as `$930`, `$931`, `$932`, `$933`, and the `$541`-through-`$548` / `$524`-through-`$531` const shuttles
  - that means the new raw validator-skip fix retired the returning-condition copy family, but it did not yet retire the later branch-carrier and constant-fanout subgroup
- The 2026-04-10 fanout follow-up clarified one more boundary:
  - a reduced `wasm-opt --simplify-locals` probe on `/tmp/sl-fanout-*.wat` shows Binaryen collapsing the whole dupable fanout in one shot, leaving only `nop` sentinels plus direct constants or direct `local.get` uses at the final `call`
  - Starshine now matches that reduced Binaryen behavior in-tree: the raw pure-suffix lane prefers direct dupable-copy elimination over the weaker "move middle statements later" path, and it can batch later dupable middle producer statements into the same final use
  - the new synthetic heavy regression and whitebox helper test are both green, and the clean native lanes `.tmp/pass-fuzz-sl-fanout-batch-2k-clean` and `.tmp/pass-fuzz-sl-fanout-batch-10k-clean` are green at `2000/2000` and `10000/10000`
  - but the real artifact replay at `/tmp/starshine-self-optimize-compare-starshine-debug-wasi-3176570` still shows the same `$930/$931/$932/$933` and `$541`-through-`$548` / `$524`-through-`$531` subgroup
  - so the next parity task is no longer "prove Binaryen wants this reduction"; it is "find the actual raw statement shape in `Func 71` that keeps the reducer from firing"
- The newer 2026-04-10 returning-fanout follow-up retired one more in-memory raw gap:
  - a new reduced validator-heavy reproducer covers an effectful prefix followed by a returning `if (result i32)` arm whose final escaping `call` is fed by a dense `i32.const -> local.set` fanout
  - the kept fix is in the raw helper boundary, not the rewrite policy: `run_hot_pipeline_raw_simplify_locals_take_statement_prefix_allow_escape` now accepts the full remaining suffix when it typechecks with a non-empty stack and `tc_escape_none`
  - the new reduced regression is green in `src/passes/simplify_locals_test.mbt`, and the native direct lanes `.tmp/pass-fuzz-sl-returning-const-fanout-2k` and `.tmp/pass-fuzz-sl-returning-const-fanout-10k` are green at `2000/2000` and `10000/10000`
  - direct native CLI inspection now shows the in-memory `Func 71` tree without the old `$930..$934` carriers or the `$540` / `$557` dense const webs
  - but the full self-opt compare at `/tmp/starshine-self-optimize-compare-starshine-debug-wasi-1018195` is still red and still starts with Binaryen-only `$930/$931/$932/$933/$934` materialization
  - the first open parity bucket is therefore now explicitly a Binaryen-facing encoded-output or reparse shape problem, not another missed in-memory raw reducer
- The latest 2026-04-10 terminal-value follow-up tightened that diagnosis further:
  - the new reduced whitebox regressions cover the exact terminal dupable wrapper shapes that still appear in the encoded artifact family: `i32.const/local.get -> local.set -> safe middle -> local.get` when the copied local is the final escaping value, not the input to a later zero-stack statement
  - reduced `wasm-opt --simplify-locals` probes on `/tmp/sl-terminal-nop-probe.wat` and `/tmp/sl-terminal-probe-no-middle.wat` clarified the exact Binaryen policy there: the copied `local.set` becomes a `nop` sentinel, any existing middle `nop`s remain, and the final escaping value becomes the original constant or source `local.get`
  - the new current-state direct lanes `.tmp/pass-fuzz-sl-terminal-value-2k` and `.tmp/pass-fuzz-sl-terminal-value-10k` are green at `2000/2000` and `10000/10000`
  - the direct traced native path `_build/native/release/build/cmd/cmd.exe --simplify-locals --print-func 71 ...` now shows that exact behavior in `body_raw`: the old wrapper sites feed `call $176` / `call $1988` with direct `i32.const 0`, direct `i32.const 10000`, and direct source `local.get`
  - but the authoritative encoded replay at `/tmp/starshine-self-optimize-compare-starshine-debug-wasi-3772265` is still red and still begins at the same first mismatch, line `4860`, where Binaryen has `nop` and Starshine still has `local.set $930`
  - so the open parity task is no longer "find the missing validator raw reducer"; it is "find where the encoded-output path reconstructs the copied-local carrier after the in-memory reducer has already deleted it"
- The same day added one more reduced validator-skip proof without retiring the large-artifact frontier:
  - the new whitebox regressions now also cover branch reachability directly: later-read scans stop at unconditional `br` / `br_table`, but still treat `br_if` as live
  - a reduced raw reproducer now covers the exact branch-terminated carrier family `nop, local.get, local.set, middle local.set, copied local.get, local.set, br`, and the in-tree rewrite now produces the Binaryen-shaped `nop, nop, middle local.set, direct source local.get, local.set, br`
  - the rebuilt-binary lanes `.tmp/pass-fuzz-sl-terminal-sentinel-10k` and `.tmp/pass-fuzz-sl-branch-terminated-carrier-10k` are both green at `10000/10000` normalized matches with `0` mismatches
  - but the fresh authoritative artifact replay `/tmp/starshine-self-optimize-compare-starshine-debug-wasi-3936664` is still red and the first mismatch is now line `5313`: Binaryen has `nop, nop, local.set $39 (local.get $731), local.set $38 (local.get $62), br`, while Starshine still prints `local.set $930 (local.get $62)` followed by `local.set $38 (local.get $930)`
  - that means the remaining `Func 71` frontier is now pinned to one specific validator-skip branch-carrier subgroup, not to the older terminal-value wrapper family
- The later unchanged exact-path no-op bucket still exists too:
  - Starshine can still report `changed=false` while Binaryen prints a tighter control/value form in later functions such as `Func 386` and `Func 399`

## Why The Frontier Matters

- The current status means the next work is not "add more raw validator cleanup blindly."
- The repo already learned that:
  - several validator-heavy temp families are retired
  - broad lowered cleanup is unsafe
  - some remaining gaps are in unchanged exact-path output, not in obvious sink failures
- The remaining `Func 71` drift is now narrower than before:
  - the old `local $5` condition-temp carrier is gone
  - the old `$928 -> $549` store shuttle is gone too
  - the old returning-statement copied-local `$739 -> $18` carrier is now gone too, and the sibling `$735 -> $24` copy is gone with it
  - the next open parity difference there is still the later branch-carrier plus constant-fanout subgroup, not the older call-indirect temp or store shuttle
  - the later terminal-value and branch-terminated reduced probes now prove the Binaryen policy for two more subfamilies inside that bucket: preserve `nop` sentinels, delete the copied local, and feed the final escaping use directly
  - but the latest replay shows the exact `$62 -> $930 -> $38` branch carrier is still not matching in the artifact, so the open problem is now the real validator-skip statement boundary or guard that keeps that one subgroup from firing on the large function
- The 2026-04-10 investigation added one important negative result:
  - the direct raw `local.set -> local.get -> if` tee helper is not the missing piece
  - a whitebox regression now proves that helper does preserve writes that are read later from an `if` body
  - a broader attempt to run that helper across the full validator skip path was backed out after the real artifact changed to a direct block-fed condition instead of Binaryen's `local.tee $7`
- So the next parity work has to distinguish:
  - true missed transform
  - exact-path pretty-print or canonicalization drift
  - performance-only hotspot family
- The latest direct-pass evidence for the new validator-heavy returning-call-tail cleanup is:
  - `moon test src/passes` green with the new heavy traced regression
  - `.tmp/pass-fuzz-sl-validator-call-tail` green at `2000/2000` normalized matches with `0` mismatches
  - `.tmp/pass-fuzz-sl-validator-call-tail-10k` is now historical evidence only: the old `5957`-case launcher failure no longer reproduces on the current keep-state
  - `.tmp/pass-fuzz-sl-validator-call-tail-gated-10k` is green at `10000/10000` normalized matches with `0` mismatches or failures, so the validator-heavy returning-call-tail fix now has a clean long-lane signoff
  - the later pure-suffix performance containment change now also has clean direct-pass evidence: the whitebox pure-suffix candidate guard is green in `src/passes/pass_manager_wbtest.mbt`, `.tmp/pass-fuzz-sl-pure-suffix-gated-2k` is green at `2000/2000`, and `.tmp/pass-fuzz-sl-pure-suffix-gated-10k-binary` is green at `10000/10000` with the fixed native CLI binary
  - the newer returning-condition pure-copy fix now also has clean rebuilt-binary evidence: `.tmp/pass-fuzz-sl-next-if-condition-2k` is green at `2000/2000`, and `.tmp/pass-fuzz-sl-next-if-condition-10k` is green at `10000/10000`
  - the newer dupable-fanout batch cleanup is also clean on the rebuilt native binary: `.tmp/pass-fuzz-sl-fanout-batch-2k-clean` is green at `2000/2000` in `101.11s`, and `.tmp/pass-fuzz-sl-fanout-batch-10k-clean` is green at `10000/10000` in `432.24s`
  - the later Binaryen-sentinel alignment and branch-terminated carrier follow-ups are also long-lane clean on the rebuilt native binary: `.tmp/pass-fuzz-sl-terminal-sentinel-10k` finished at `10000/10000` in `467.03s`, and `.tmp/pass-fuzz-sl-branch-terminated-carrier-10k` finished at `10000/10000` in `404.01s`

## Performance Status

- The raw-skip heuristics removed several artifact-scale no-op families from the hotspot list.
- Important retired performance families include:
  - huge straight-line tee-heavy builders
  - dense structured call-heavy helpers
  - several validator and decode-shaped no-op walkers
- The remaining hotspot cluster is now smaller and more internal, with examples such as `Func 473`, `308`, and `1488` recorded in the backlog.

## Current Project Rule

- Treat Binaryen-equal no-op families as performance work, not semantic wins.
- Treat artifact-only carrier wrappers as cosmetic unless a reduced case proves an observable reordering, invalid output, or a pass-fuzz semantic mismatch.
- Treat a parity difference as a bug only when:
  - the family is reduced or traced to a stable shape
  - the difference is not merely explained by a documented raw stable-boundary rule or accepted compare-helper limitation
  - the fix stays green on the pass-fuzz lane

## Maintenance Rule

- Update this page when one of these changes:
  - a named artifact family is retired
  - a previously-accepted cleanup is rejected
  - the current frontier moves to a different category
  - a performance-only hotspot family is removed from the active list
