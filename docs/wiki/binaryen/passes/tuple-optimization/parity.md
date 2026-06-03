---
kind: comparison
status: working
last_reviewed: 2026-05-09
sources:
  - ../../../raw/research/0546-2026-05-06-tuple-optimization-gen-valid-rerun.md
  - ../../../raw/research/0542-2026-05-06-tuple-optimization-direct-revalidation.md
  - ../../../raw/binaryen/2026-05-04-tuple-optimization-current-main-recheck.md
  - ../../../raw/research/0434-2026-05-04-tuple-optimization-current-main-recheck.md
  - ../../../raw/research/0076-2026-04-01-tuple-optimization-binaryen-port-plan.md
  - ../../../raw/research/0079-2026-04-11-pass-fuzz-health-round-two.md
  - ../../../../../src/passes/tuple_optimization.mbt
  - ../../../../../src/passes/tuple_optimization_wbtest.mbt
  - ../../../../../src/cmd/cmd_wbtest.mbt
  - ../../../../../src/cmd/cmd_native_wbtest.mbt
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../agent-todo.md
  - ../../../../../CHANGELOG.md
related:
  - ./index.md
  - ./starshine-strategy.md
  - ./scheduler-and-gates.md
  - ./reduced-repros-and-evidence.md
  - ../../no-dwarf-default-optimize-path.md
---

# `tuple-optimization` Binaryen Parity

## Durable Conclusions

- Starshine's tuple-opt should be judged first against Binaryen, not against a home-grown notion of "reasonable multivalue cleanup."
- The explicit pass surface is real and useful today, and the exact in-tree preset slot is now scheduled in `optimize` and `shrink`.
- The isolated pass has fresh direct parity evidence under the 2026-05-09 refreshed `pass-fuzz-compare` harness.
- The old white-box exact-shape reds were stale expectation debt and are now rebaselined to the current Binaryen-backed scalarization contract; full exact-slot artifact parity is still not signed off.

## Current In-Tree Status

- The implementation lives in [`../../../../../src/passes/tuple_optimization.mbt`](../../../../../src/passes/tuple_optimization.mbt).
- Focused white-box coverage lives in [`../../../../../src/passes/tuple_optimization_wbtest.mbt`](../../../../../src/passes/tuple_optimization_wbtest.mbt).
- CLI and emitted-module shape checks live in [`../../../../../src/cmd/cmd_wbtest.mbt`](../../../../../src/cmd/cmd_wbtest.mbt).
- Direct native Binaryen comparison lives in [`../../../../../src/cmd/cmd_native_wbtest.mbt`](../../../../../src/cmd/cmd_native_wbtest.mbt).
- Preset placement now lives in [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt): `precompute -> code-pushing -> tuple-optimization -> simplify-locals-nostructure -> vacuum -> reorder-locals -> remove-unused-brs -> heap2local`.

## Current Direct Test Evidence

Fresh direct revalidation taken for this doc update on `2026-05-09`:

- `moon test src/passes`
  - result: `806 / 806` passed after the preset-slot scheduling tests were updated
- `moon test src/cmd`
  - result: `130 / 130` passed
- `bun scripts/pass-fuzz-compare.ts --pass tuple-optimization --count 10000 --seed 0x5eed --max-failures 20 --out-dir .tmp/pass-fuzz-tuple-optimization-slot`
  - result: `6759 / 10000` compared, `6759` normalized matches, `0` mismatches, `0` validation failures, `0` generator failures, `20` command failures
  - command-failure classification: `binaryen-rec-group-zero` (`17`), `binaryen-bad-section-size` (`1`), `binaryen-table-index-out-of-range` (`1`), `binaryen-invalid-tag-index` (`1`)
- `bun scripts/pass-fuzz-compare.ts --pass tuple-optimization --count 10000 --seed 0x5eed --generator gen-valid --max-failures 20 --out-dir .tmp/pass-fuzz-tuple-optimization-gen-valid-slot`
  - result: `10000 / 10000` compared, `10000` normalized matches, `0` mismatches, `0` validation failures, `0` generator failures, `0` command failures

Previous direct revalidation taken on `2026-05-06`:

- `moon info`
  - result: completed with existing warnings only
- `moon fmt`
  - result: completed, no formatting work needed
- `moon test`
  - result: `2820 / 2820` passed
- `bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass tuple-optimization --out-dir .tmp/pass-fuzz-tuple-optimization`
  - result: `6759 / 10000` compared, `6759` normalized matches, `0` mismatches, `0` validation failures, `0` generator failures, `20` command failures
  - command-failure classification: the already-seen Binaryen parser/canonicalization failure class on wasm-smith inputs with empty recursion groups, not a Starshine/Binaryen semantic mismatch
- `bun scripts/pass-fuzz-compare.ts --pass tuple-optimization --generator gen-valid --count 10000 --seed 0x5eed --max-failures 20 --out-dir .tmp/pass-fuzz-tuple-gen-valid-10000-20260506`
  - result: `10000 / 10000` compared, `10000` normalized matches, `0` mismatches, `0` validation failures, `0` generator failures, `0` command failures

Older focused local checks taken on `2026-04-10`:

- `moon test --package jtenner/starshine/cmd --file cmd_native_wbtest.mbt --target native --filter '*tuple-optimization*'`
  - result: `15 / 15` passed
- `moon test --package jtenner/starshine/passes --file tuple_optimization_wbtest.mbt`
  - result: `42 / 42` passed
- `moon test --package jtenner/starshine/cmd --file cmd_wbtest.mbt --filter '*tuple-optimization*'`
  - result: `7 / 7` passed

Interpretation:

- the direct native Binaryen-compare lane is green again on every committed tuple-opt regression in that file
- the black-box command-surface tuple lane is also green again
- the white-box tuple file is green again after rebasing stale temp-local shape checks onto stable scalarization and copyback invariants
- the remaining open work is preset placement plus the larger artifact/runtime proof gap, not direct explicit-pass parity

## Current Green Surface

The branch is already in good shape on these fronts:

- explicit pass registration and CLI execution
- scalar-only explicit no-op behavior
- reduced direct spill, copy-chain, host-tee, mixed scalar-forward, nested no-host, nested scalar-result, terminal host-drop, and chained `tail-live0` parity families in the native compare suite
- black-box lowered-module checks for all committed tuple-opt command regressions
- white-box rewrite and analysis coverage for all committed tuple-opt reduced regressions
- historical and fresh isolated fuzz lanes with zero semantic mismatches on comparable cases

## Current Red Surface

Direct explicit-pass parity is signed off under the refreshed 2026-05-09 harness, and the public preset slot is now enabled. These broader lanes remain open:

- exact-slot debug-artifact replay is still canonically red in `.tmp/to-exact-slot-artifact`
- the initial `defined=0 abs=17` `select`/`if` temporary-local representation drift is now classified in the compare tool, along with follow-on pure dropped-add, global-get alias, tail-return lowering, and simple trap-if inversion shapes
- the current first differing function in that replay is `defined=29 abs=46`; the actual Starshine output now avoids the tail `return` + trailing `unreachable` and empty-then `if` inversions, so the remaining byte-efficiency/code-quality gap is the extra block-result local materialization before `local.set $2`
- feature-off preset coverage is still pending explicit Starshine feature options
- full debug-artifact replay and tuple-only runtime remain active TO005 debt

## 2026-04-11 Health Rerun

- `bun scripts/pass-fuzz-compare.ts --pass tuple-optimization --count 200 --seed 0x5eed --max-failures 30 --out-dir /tmp/health-tuple-200-2026-04-11-smoke`:
  - `199 / 199` compared, `199` normalized matches, `0` mismatches, `1` command failure (`binaryen-rec-group-zero`)
- `bun scripts/pass-fuzz-compare.ts --pass tuple-optimization --generator gen-valid --count 200 --seed 0x5eed --out-dir /tmp/health-tuple-200-genvalid-2026-04-11-smoke`:
  - `200 / 200` compared, `200` normalized matches, `0` mismatches
- This keeps tuple-optimization classified as direct-clean in this smoke band, with no semantic mismatches introduced since the prior check.

## Current Reduced Host-Copy Status

As of the current `2026-04-10` working tree:

- the reduced `terminal drop-only host copy groups` and `chained host-copy tail-live0` native compare regressions are green again
- the lowered command-surface repro for `tail-live0` is green again at `7 / 7` tuple cmd tests
- the remaining debt in that family is now performance/shape debt rather than a direct Binaryen mismatch:
  - raw rewritten HOT still retains one live `TupleMake`
  - pass-manager lowering hides that node by promoting it before `hot_lower`
  - the reduced self-opt compare is still red and slow even though the reduced native parity lane is green

## Standing Fuzz Evidence

Fresh current-head evidence:

- `bun scripts/pass-fuzz-compare.ts --pass tuple-optimization --generator gen-valid --count 10000 --seed 0x5eed --max-failures 20 --out-dir .tmp/pass-fuzz-tuple-gen-valid-10000-20260506`
  - result: `10000 / 10000` compared, `10000` normalized matches, `0` mismatches, `0` validation failures, `0` generator failures, `0` command failures
- `bun scripts/pass-fuzz-compare.ts --pass tuple-optimization --generator gen-valid --count 1000 --max-failures 20 --out-dir /tmp/pass-fuzz-tuple-gen-valid-2026-04-10`
  - result: `1000 / 1000` compared, `1000` normalized matches, `0` mismatches, `0` validation failures, `0` generator failures, `0` command failures
- `bun scripts/pass-fuzz-compare.ts --pass tuple-optimization --generator wasm-smith --count 200 --max-failures 20 --out-dir /tmp/pass-fuzz-tuple-smith-2026-04-10`
  - result: `199 / 200` compared, `199` normalized matches, `0` mismatches, `0` validation failures, `0` generator failures, `1` command failure
  - current failure classification: `binaryen-rec-group-zero` at case `29` (`Recursion groups of size zero not supported`)
- `bun scripts/pass-fuzz-compare.ts --pass tuple-optimization --generator gen-valid --count 1000 --max-failures 20 --out-dir /tmp/pass-fuzz-tuple-gen-valid-visitmarks-2026-04-10`
  - result: `1000 / 1000` compared, `1000` normalized matches, `0` mismatches, `0` validation failures, `0` generator failures, `0` command failures
- `bun scripts/pass-fuzz-compare.ts --pass tuple-optimization --generator wasm-smith --count 200 --max-failures 20 --out-dir /tmp/pass-fuzz-tuple-smith-visitmarks-2026-04-10`
  - result: `199 / 200` compared, `199` normalized matches, `0` mismatches, `0` validation failures, `0` generator failures, `1` command failure
  - current failure classification is unchanged: `binaryen-rec-group-zero` at case `29` (`Recursion groups of size zero not supported`)
- `bun scripts/pass-fuzz-compare.ts --pass tuple-optimization --generator gen-valid --count 1000 --max-failures 20 --out-dir /tmp/pass-fuzz-tuple-gen-valid-forwardcache-2026-04-10`
  - result: `1000 / 1000` compared, `1000` normalized matches, `0` mismatches, `0` validation failures, `0` generator failures, `0` command failures
- `bun scripts/pass-fuzz-compare.ts --pass tuple-optimization --generator wasm-smith --count 200 --max-failures 20 --out-dir /tmp/pass-fuzz-tuple-smith-forwardcache-2026-04-10`
  - result: `199 / 200` compared, `199` normalized matches, `0` mismatches, `0` validation failures, `0` generator failures, `1` command failure
  - current failure classification is still `binaryen-rec-group-zero` at case `29` (`Recursion groups of size zero not supported`)
- `bun scripts/pass-fuzz-compare.ts --pass tuple-optimization --generator gen-valid --count 1000 --max-failures 20 --out-dir /tmp/pass-fuzz-tuple-gen-valid-emptysummary-2026-04-10`
  - result: `1000 / 1000` compared, `1000` normalized matches, `0` mismatches, `0` validation failures, `0` generator failures, `0` command failures
- `bun scripts/pass-fuzz-compare.ts --pass tuple-optimization --generator wasm-smith --count 200 --max-failures 20 --out-dir /tmp/pass-fuzz-tuple-smith-emptysummary-2026-04-10`
  - result: `199 / 200` compared, `199` normalized matches, `0` mismatches, `0` validation failures, `0` generator failures, `1` command failure
  - current failure classification is still `binaryen-rec-group-zero` at case `29` (`Recursion groups of size zero not supported`)
- `bun scripts/pass-fuzz-compare.ts --starshine-bin _build/native/release/build/cmd/cmd.exe --pass tuple-optimization --generator gen-valid --count 1000 --max-failures 20 --out-dir /tmp/pass-fuzz-tuple-gen-valid-bincurrent-2026-04-10`
  - result: `1000 / 1000` compared, `1000` normalized matches, `0` mismatches, `0` validation failures, `0` generator failures, `0` command failures
- `bun scripts/pass-fuzz-compare.ts --starshine-bin _build/native/release/build/cmd/cmd.exe --pass tuple-optimization --generator wasm-smith --count 200 --max-failures 20 --out-dir /tmp/pass-fuzz-tuple-smith-bincurrent-2026-04-10`
  - result: `199 / 200` compared, `199` normalized matches, `0` mismatches, `0` validation failures, `0` generator failures, `1` command failure
  - current failure classification is still `binaryen-rec-group-zero` at case `29` (`Recursion groups of size zero not supported`)
- `bun scripts/pass-fuzz-compare.ts --starshine-bin _build/native/release/build/cmd/cmd.exe --pass tuple-optimization --generator gen-valid --count 1000 --max-failures 20 --out-dir /tmp/pass-fuzz-tuple-gen-valid-wbrefresh-2026-04-10`
  - result: `1000 / 1000` compared, `1000` normalized matches, `0` mismatches, `0` validation failures, `0` generator failures, `0` command failures
- `bun scripts/pass-fuzz-compare.ts --starshine-bin _build/native/release/build/cmd/cmd.exe --pass tuple-optimization --generator wasm-smith --count 200 --max-failures 20 --out-dir /tmp/pass-fuzz-tuple-smith-wbrefresh-2026-04-10`
  - result: `199 / 200` compared, `199` normalized matches, `0` mismatches, `0` validation failures, `0` generator failures, `1` command failure
  - current failure classification is still `binaryen-rec-group-zero` at case `29` (`Recursion groups of size zero not supported`)
- `bun scripts/pass-fuzz-compare.ts --starshine-bin _build/native/release/build/cmd/cmd.exe --pass tuple-optimization --generator gen-valid --count 10000 --max-failures 20 --out-dir /tmp/pass-fuzz-tuple-gen-valid-10000-bin-sharedmarks-2026-04-10`
  - result: `10000 / 10000` compared, `10000` normalized matches, `0` mismatches, `0` validation failures, `0` generator failures, `0` command failures

Standing larger evidence now includes the fresh current-head `10000 / 10000` `gen-valid` lane plus the older direct-native `10000 / 10000` lane.

These results are still not enough for final signoff because:

- they cover the explicit pass in isolation
- they do not substitute for exact preset-slot proof
- they do not close the remaining artifact/runtime family
- the current kept performance state is broader than visit-buffer reuse alone:
  - stamped visit-buffer reuse was parity-safe but did not materially move the reduced runtime gap
  - direct-use summary construction alone regressed the reduced pass timing
  - the current kept combination of forwarded-use memoization plus no-group summary skipping recovered that regression and moved reduced pass time to `0.511 ms`, but it still does not close the much larger Binaryen gap
- the long `gen-valid` parity lane also exposed an infrastructure distinction:
  - historical `moon run`-backed `bun scripts/pass-fuzz-compare.ts --pass tuple-optimization --generator gen-valid --count 10000 --max-failures 20 --out-dir /tmp/pass-fuzz-tuple-gen-valid-10000-emptysummary-2026-04-10` stopped after `2124` matches with `20` repeated missing-output validation failures
  - direct replay of the first recorded input still writes valid output
  - the same `10000`-case lane is clean when the harness calls the built native binary directly via `--starshine-bin _build/native/release/build/cmd/cmd.exe`
  - `pass-fuzz-compare` now retries that narrow successful-but-no-output `moon run` launcher churn, so the historical stop remains launcher evidence rather than a standing tuple-opt workaround or semantic mismatch

## Preset And Scheduler Status

The pass is now present in `optimize` and `shrink`.

Current scheduled neighborhood:

- `precompute -> code-pushing -> tuple-optimization -> simplify-locals-nostructure -> vacuum -> reorder-locals -> remove-unused-brs -> heap2local`

This intentionally matches Binaryen's local no-DWARF slot rather than an approximate placement. The remaining scheduler gap is no longer pass availability; it is exact-slot artifact proof plus feature-off coverage.

## Artifact And Performance Gap

Fresh exact-slot artifact evidence on `2026-05-09`:

- `bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --code-pushing --tuple-optimization --simplify-locals-nostructure --vacuum --reorder-locals --remove-unused-brs --out-dir .tmp/to-exact-slot-artifact`
  - `Canonical wasm equal: no`
  - `Normalized WAT text equal: no`
  - `Normalized WAT equal: no`
  - `Canonical function compare equal: no`
  - first differing function before this compare-tool normalization slice: `defined=0 abs=17`
  - `Starshine pass runtime (ms): 2485.260`
  - `Binaryen pass runtime (ms): 488565.000`
  - `Starshine pass at least as fast: yes`
- Follow-up exact-slot artifact evidence after fixing actual output code-quality gaps on `2026-05-09`:
  - command: `bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --code-pushing --tuple-optimization --simplify-locals-nostructure --vacuum --reorder-locals --remove-unused-brs --out-dir .tmp/to-exact-slot-artifact`
  - `Canonical wasm equal: no`
  - `Normalized WAT text equal: no`
  - `Normalized WAT equal: no`
  - `Canonical function compare equal: no`
  - current first differing function: `defined=29 abs=46`
  - `Starshine pass runtime (ms): 2618.045`
  - `Binaryen pass runtime (ms): 482170.000`
  - `Starshine pass at least as fast: yes`
- The original first differing function was representation drift in the `select`/`if` family after the `code-pushing` + no-structure cleanup neighborhood. The latest pass work fixed the real byte-efficiency issues around tail fallthrough and empty-then inversion in Starshine output. TO005 remains open because the same function still has a real extra-local materialization gap: Binaryen lowers the block result directly into `$2`, while Starshine still routes it through an extra local before copying to `$2`.

The older backlog entry that treated `/tmp/self-opt-tuple-current` as a tuple-pass blocker is now retired as a parity blocker.

What changed:

- the saved raw normalized-WAT hunk still begins at printed WAT `func $3639`
- that label is the defined-function ordinal in the `wasm-opt -S` text, not the absolute CLI function index
- on the saved compare pair there are `21` imported funcs ahead of it, so printed `func $3639` maps to absolute `Func[3660]`
- `starshine --print-func 3660 /tmp/self-opt-tuple-current/starshine.wasm` and the same command on `binaryen.wasm` match exactly on the project’s decoded canonical pretty-print surface
- the old red status was therefore a compare-surface bug, not a proven tuple rewrite bug

The compare tool now reflects that conclusion:

- `scripts/lib/self-optimize-compare-task.ts` still records whether raw normalized WAT text matches
- when raw normalized WAT differs, it now falls back to per-function canonical comparison through `--print-func`
- that fallback ports the same body-local alpha-normalization and scalar-ladder reordering logic already used by the native tuple parity tests
- when it does find a real function-level mismatch, it now records unambiguous artifacts as `func-definedN-absM.*` instead of the older ambiguous `func3639.*` style

Current interpretation:

- full tuple-only self-opt parity is no longer blocked by a known `func $3639` tuple rewrite bug
- the full tuple-only self-opt compare has now been rerun end-to-end with the upgraded canonical fallback
- raw normalized WAT text is still not a usable tuple parity oracle on the full artifact, but canonical per-function comparison is now green on current head
- tuple-only runtime is still materially slower than Binaryen, so performance work remains real even though the old raw WAT hunk is no longer a correctness blocker

Fresh full-artifact evidence on `2026-04-10`:

- `bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --starshine-bin _build/native/release/build/cmd/cmd.exe --out-dir /tmp/self-opt-tuple-full-canonical-2026-04-10 --tuple-optimization`
  - `Canonical wasm equal: no`
  - `Normalized WAT text equal: no`
  - `Canonical function compare equal: yes`
  - `Normalized WAT equal: yes`
  - `Starshine runtime (ms): 5328.045`
  - `Binaryen runtime (ms): 334.375`
  - `Starshine pass runtime (ms): 966.501`
  - `Binaryen pass runtime (ms): 4.331`
- `bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --starshine-bin _build/native/release/build/cmd/cmd.exe --out-dir /tmp/self-opt-tuple-full-smalllocals-2026-04-10 --tuple-optimization`
  - `Canonical wasm equal: no`
  - `Normalized WAT text equal: no`
  - `Canonical function compare equal: yes`
  - `Normalized WAT equal: yes`
  - `Starshine runtime (ms): 5295.675`
  - `Binaryen runtime (ms): 317.250`
  - `Starshine pass runtime (ms): 965.752`
  - `Binaryen pass runtime (ms): 2.666`

Fresh kept-tree pass-trace diagnosis on the same artifact:

- `cmd.exe --tracing pass --debug-serial-passes --tuple-optimization ...`
  - `4462` functions visited
  - `18` functions changed
  - total tuple pass time `277790 us`
  - the previous unchanged-function hot quartet (`Func 3612`, `1553`, `1525`, `1673`) is no longer the main story after the shared seed-scan plus stamped duplicate-lane slices
  - the current hot functions are:
    - `Func 1673`: `101831 us`
    - `Func 148`: `14719 us`
    - `Func 2389`: `10152 us`
    - `Func 1905`: `6557 us`
    - `Func 3660`: `5725 us`

Fresh current-tree full-artifact reruns after the candidate-filter rewrite:

- `bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --starshine-bin _build/native/release/build/cmd/cmd.exe --out-dir /tmp/self-opt-tuple-full-candidatefilter-2026-04-10 --tuple-optimization`
  - `Canonical wasm equal: no`
  - `Normalized WAT text equal: no`
  - `Canonical function compare equal: yes`
  - `Normalized WAT equal: yes`
  - `Starshine runtime (ms): 5634.347`
  - `Binaryen runtime (ms): 406.502`
  - `Starshine pass runtime (ms): 361.452`
  - `Binaryen pass runtime (ms): 3.711`
- `bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --starshine-bin _build/native/release/build/cmd/cmd.exe --out-dir /tmp/self-opt-tuple-full-candidatefilter-rerun-2026-04-10 --tuple-optimization`
  - `Canonical wasm equal: no`
  - `Normalized WAT text equal: no`
  - `Canonical function compare equal: yes`
  - `Normalized WAT equal: yes`
  - `Starshine runtime (ms): 5114.578`
  - `Binaryen runtime (ms): 377.363`
  - `Starshine pass runtime (ms): 325.221`
  - `Binaryen pass runtime (ms): 3.741`

Fresh reduced performance evidence taken on `2026-04-10`:

- `bun scripts/self-optimize-compare.ts /tmp/tuple-host-tail-live0.wasm --out-dir /tmp/self-opt-tuple-tail-live0-2026-04-10 --tuple-optimization`
  - `Canonical wasm equal: no`
  - `Normalized WAT equal: no`
  - `Starshine runtime (ms): 32.204`
  - `Binaryen runtime (ms): 3.066`
  - `Starshine pass runtime (ms): 0.515`
  - `Binaryen pass runtime (ms): 0.015`
- `bun scripts/self-optimize-compare.ts /tmp/tuple-host-tail-live0.wasm --out-dir /tmp/self-opt-tuple-tail-live0-visitmarks-2026-04-10 --tuple-optimization`
  - `Canonical wasm equal: no`
  - `Normalized WAT equal: no`
  - `Starshine runtime (ms): 31.959`
  - `Binaryen runtime (ms): 3.220`
  - `Starshine pass runtime (ms): 0.547`
  - `Binaryen pass runtime (ms): 0.017`
- `bun scripts/self-optimize-compare.ts /tmp/tuple-host-tail-live0.wasm --out-dir /tmp/self-opt-tuple-tail-live0-querysummary-2026-04-10 --tuple-optimization`
  - `Canonical wasm equal: no`
  - `Normalized WAT equal: no`
  - `Starshine runtime (ms): 43.497`
  - `Binaryen runtime (ms): 3.938`
  - `Starshine pass runtime (ms): 0.757`
  - `Binaryen pass runtime (ms): 0.020`
- `bun scripts/self-optimize-compare.ts /tmp/tuple-host-tail-live0.wasm --out-dir /tmp/self-opt-tuple-tail-live0-forwardcache-2026-04-10 --tuple-optimization`
  - `Canonical wasm equal: no`
  - `Normalized WAT equal: no`
  - `Starshine runtime (ms): 33.691`
  - `Binaryen runtime (ms): 3.097`
  - `Starshine pass runtime (ms): 0.601`
  - `Binaryen pass runtime (ms): 0.016`
- `bun scripts/self-optimize-compare.ts /tmp/tuple-host-tail-live0.wasm --out-dir /tmp/self-opt-tuple-tail-live0-emptysummary-2026-04-10 --tuple-optimization`
  - `Canonical wasm equal: no`
  - `Normalized WAT equal: no`
  - `Starshine runtime (ms): 35.406`
  - `Binaryen runtime (ms): 2.993`
  - `Starshine pass runtime (ms): 0.511`
  - `Binaryen pass runtime (ms): 0.014`
- `bun scripts/self-optimize-compare.ts /tmp/tuple-host-tail-live0.wasm --out-dir /tmp/self-opt-tuple-tail-live0-sharedmarks-2026-04-10 --tuple-optimization`
  - `Canonical wasm equal: no`
  - `Normalized WAT equal: no`
  - `Starshine runtime (ms): 36.952`
  - `Binaryen runtime (ms): 3.674`
  - `Starshine pass runtime (ms): 0.547`
  - `Binaryen pass runtime (ms): 0.016`
- `bun scripts/self-optimize-compare.ts /tmp/tuple-host-tail-live0.wasm --out-dir /tmp/self-opt-tuple-tail-live0-cleanupfast-2026-04-10 --tuple-optimization`
  - `Canonical wasm equal: no`
  - `Normalized WAT equal: no`
  - `Starshine runtime (ms): 42.026`
  - `Binaryen runtime (ms): 3.471`
  - `Starshine pass runtime (ms): 0.565`
  - `Binaryen pass runtime (ms): 0.017`

Accuracy notes:

- this doc update did rerun the reduced self-opt compare on the committed `tail-live0` repro
- this doc update also reran the isolated fuzz lanes after the newer direct-use summary, forwarded-use memoization, no-group summary-skip, and small-locals analysis slices
- this doc update did rerun the full `tests/node/dist/starshine-debug-wasi.wasm --tuple-optimization` pipeline with the upgraded canonical fallback, and the full-artifact parity claim above now comes from that fresh rerun rather than only from the saved pair replay
- this doc update also reran the full artifact after replacing the weak no-op screen plus duplicated seed walk with a shared precise seed scan
- this doc update reran the direct debug-artifact tuple pass trace on the cleaned kept tree after backing out the child-index, incremental local-group-id, and prescan experiments
- the reduced timing ladder now has a clearer shape:
  - stamped visit-buffer reuse was parity-safe but did not materially improve the reduced timing gap
  - direct-use summary construction alone regressed the reduced timing repro
  - forwarded-use memoization recovered most of that regression
  - skipping summary construction for no-group functions brought reduced pass time down further to `0.511 ms`, slightly better than the earlier visit-buffer-only `0.547 ms`
- the later shared-mark and cleanup-fast-path experiments did not improve the reduced repro beyond that `0.511 ms` checkpoint
- the newer candidate-filter slice did materially improve the full artifact:
  - full tuple pass time dropped from roughly `966 ms` to a `325-361 ms` band on repeated reruns
  - the key code change was structural, not heuristic: tuple-opt now performs one shared precise seed scan instead of a weak whole-function screen plus a second weak screen plus a second seed walk, and seed discovery now uses stamped local marks instead of per-producer linear duplicate-local checks plus reverse-array rebuilding
  - the old unchanged-function hot quartet mostly disappeared from the pass trace, which is strong evidence that the earlier runtime debt really was candidate-screen churn rather than later rewrite work
- the later stamped duplicate-lane work in result-block and scalar-forward collectors is also kept:
  - the cleaned direct pass trace now totals `277790 us` across `4462` visited functions with `18` changed
  - that is lower than the earlier `340626 us` candidate-filter trace and consistent with the saved full-artifact self-opt win
- the next performance slice should therefore target candidate-heavy query-summary and copy-link work inside the remaining outlier `Func 1673`, not more no-group screening or scratch-array cleanup alone
- the current kept-tree trace keeps the same diagnosis:
  - `Func 1673` remains the real tuple-pass bottleneck at `101831 us`
  - the heaviest `analysis:use-def` functions are different (`3612`, `1553`, `1525`), which matters for total pipeline wall time but not for the tuple pass timer that self-opt compare reports
- the full-artifact claims above and the reduced timing numbers are both fresh local measurements from this round

## Signoff Rule

Do not call tuple-opt done until all of these are true:

- the explicit pass remains green on reduced native Binaryen comparison
- the remaining exact-shape white-box failures are resolved or intentionally rebaselined
- the pass lands in the real Binaryen slot with feature-off coverage
- `moon build --target native --release src/cmd` followed by `bun scripts/pass-fuzz-compare.ts --pass tuple-optimization --count 10000 ... --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe` is acceptable on current head
- the full debug-artifact compare stays canonically green enough to remain out of the active parity-blocker backlog

## Sources

- Archived note: [`../../../raw/research/0076-2026-04-01-tuple-optimization-binaryen-port-plan.md`](../../../raw/research/0076-2026-04-01-tuple-optimization-binaryen-port-plan.md)
- Follow-up health rerun: [`../../../raw/research/0079-2026-04-11-pass-fuzz-health-round-two.md`](../../../raw/research/0079-2026-04-11-pass-fuzz-health-round-two.md)
- Active backlog: [`../../../../../agent-todo.md`](../../../../../agent-todo.md)
- Recent checkpoint record: [`../../../../../CHANGELOG.md`](../../../../../CHANGELOG.md)
- Implementation: [`../../../../../src/passes/tuple_optimization.mbt`](../../../../../src/passes/tuple_optimization.mbt)
