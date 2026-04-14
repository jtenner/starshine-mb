---
kind: comparison
status: working
last_reviewed: 2026-04-14
sources:
  - ../../../../../agent-todo.md
  - ../../../../../CHANGELOG.md
  - ../../../../../src/passes/simplify_locals_test.mbt
  - ../../../../../src/passes/pass_manager_wbtest.mbt
  - ../../../../../src/passes/perf_test.mbt
  - ../../../../../src/passes_perf_long/simplify_locals_multivalue_perf_test.mbt
  - ../../../../../.tmp/pass-fuzz-sl-current-2026-04-14/result.json
  - ../../../../../.tmp/self-opt-sl-current-2026-04-14/result.json
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

- The pass has broad reduced coverage in [`src/passes/simplify_locals_test.mbt`](../../../../../src/passes/simplify_locals_test.mbt).
- The raw lane and skip reasons are guarded in:
  - [`src/passes/pass_manager_wbtest.mbt`](../../../../../src/passes/pass_manager_wbtest.mbt)
  - [`src/passes/perf_test.mbt`](../../../../../src/passes/perf_test.mbt)
  - [`src/passes_perf_long/simplify_locals_multivalue_perf_test.mbt`](../../../../../src/passes_perf_long/simplify_locals_multivalue_perf_test.mbt)
- The current 2026-04-14 native-binary fuzz lane is green:
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

- The old `Func 71` first-diff frontier recorded below is now historical context, not the current first failing comparison.
- The latest 2026-04-14 native-binary self-opt compare at `.tmp/self-opt-sl-current-2026-04-14` has:
  - `normalizedWatEqual=true`
  - `canonicalFuncPrettyEqual=true`
  - `firstDifferingFuncDefinedIndex=null`
  - `firstDifferingFuncAbsIndex=null`
- That means the checked-in debug artifact no longer has a surviving canonical per-function parity mismatch for the current keep-state.
- The remaining debt has shifted to:
  - raw wasm / raw text inequality (`wasmEqual=false`, `normalizedWatTextEqual=false`)
  - large runtime gap versus Binaryen
- Keep the older `Func 71` notes below as the audit trail for how the branch got here, but do not treat them as the live first frontier anymore.


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
- Treat a parity difference as a bug only when:
  - the family is reduced or traced to a stable shape
  - the difference is not merely explained by a documented raw stable-boundary rule
  - the fix stays green on the pass-fuzz lane

## Maintenance Rule

- Update this page when one of these changes:
  - a named artifact family is retired
  - a previously-accepted cleanup is rejected
  - the current frontier moves to a different category
  - a performance-only hotspot family is removed from the active list
