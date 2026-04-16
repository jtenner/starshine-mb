---
kind: concept
status: working
last_reviewed: 2026-04-10
sources:
  - ../../../raw/research/0076-2026-04-01-tuple-optimization-binaryen-port-plan.md
  - ../../../../../src/passes/tuple_optimization_wbtest.mbt
  - ../../../../../src/cmd/cmd_wbtest.mbt
  - ../../../../../src/cmd/cmd_native_wbtest.mbt
  - ../../../../../agent-todo.md
  - ../../../../../CHANGELOG.md
related:
  - ./index.md
  - ./wat-shapes.md
  - ./starshine-hot-ir-strategy.md
  - ./parity.md
---

# `tuple-optimization` Reduced Repros And Evidence

## Why This Page Exists

- Tuple-opt has advanced mostly by reducing one artifact drift family at a time into very small WAT fixtures.
- Those reduced fixtures are now the real design record of the pass.
- This page maps the important repro families to where they live and what they currently prove.

## Families That Are Clearly Landed

These families are currently represented by in-tree reduced tests and are part of the direct pass contract:

- direct multivalue spill seed group
- direct spill bridge carried through a root `local.set`
- pure lane-forwarding copy group
- badness propagation across copy-connected groups
- host `local.tee` spill bridge
- compare-shaped scalar-forward bridge
- one-hop scalar-forward bridge
- mixed direct-producer scalar-forward bridge
- chained mixed scalar-forward bridge
- no-host exact-copy chains that remain scalar after lowering
- nested exact-copy scalar-result carrier family
- nested no-host source copy chain family
- host `local.tee` scalar-result bridge family
- terminal drop-only no-host exact-copy child family
- chained terminal drop-only no-host exact-copy child family
- debug-artifact replay guards for earlier `func 1930` and `func 3598` drift families

Where these live:

- white-box analysis and rewrite fixtures in `src/passes/tuple_optimization_wbtest.mbt`
- black-box shape checks in `src/cmd/cmd_wbtest.mbt`
- direct Binaryen-compare checks in `src/cmd/cmd_native_wbtest.mbt`

## Historical Bug Families That Moved The Artifact Head

The changelog and archived `0076` note record several specific bug families that used to be artifact blockers and are no longer the leading gap:

- no-host root-carrier parity
- overlap-aware exact-copy copyback
- non-canonical synthetic root-carrier copy groups
- nested branch-exit source-root carrier staging
- scrambled root-local-set exact-copy carriers
- source-host-copy passthrough with preserved non-host lanes
- drop-only terminal host-lane suppression
- mixed direct/forwarded scalar-forward bridges from direct producers
- nested rootslot host-copy wrapper bailout
- nested scalar-result exact-copy carrier collection
- function-root host drop-tail anchor-host staging
- native parity-helper correction that compares normalized `.wasm` by function index instead of extracting WAT with `awk`
- appended-local cleanup narrowed to tuple-opt-added locals only

Practical reading rule:

- when the changelog says "the artifact head moved," that means the previous family stopped being the first observable mismatch in the saved artifact compare
- that is valuable progress, but it is not final signoff

## Current Direct Native Compare Evidence

Current branch check on `2026-04-10`:

- `moon test --package jtenner/starshine/cmd --file cmd_native_wbtest.mbt --target native --filter '*tuple-optimization*'`
- result: `15 / 15` passed

What that means:

- the reduced direct Binaryen-compare lane currently agrees with Binaryen on every committed native tuple-opt regression in that file
- this is stronger evidence than older exact-shape string checks, because the native helper now normalizes Binaryen output by decoding `.wasm` by function index

What it does not mean:

- it does not prove preset-slot parity
- it does not prove the larger artifact compare
- it does not automatically prove the larger runtime budget

## Current White-Box Status

Current branch check on `2026-04-10`:

- `moon test --package jtenner/starshine/passes --file tuple_optimization_wbtest.mbt`
- result: `42 / 42` passed

What changed:

- the old six red white-box cases were stale exact-shape expectations, not surviving Binaryen mismatches
- those checks now assert stable scalarization and copyback invariants instead of temp-local numbering or transient carrier scaffolding
- the native Binaryen compare suite remains the stronger source of truth for real parity regressions

## Current Black-Box Shape Surface

Current branch check on `2026-04-10`:

- `moon test --package jtenner/starshine/cmd --file cmd_wbtest.mbt --filter '*tuple-optimization*'`
- result: `7 / 7` passed

Interpretation:

- the committed command-surface tuple regressions are green again
- the previous chained host-copy `tail-live0` black-box failure was a stale exact-shape expectation, not a surviving reduced Binaryen mismatch
- direct native compare stays green on the same family, so the remaining open work is now pre-lower carrier debt plus artifact/perf proof

## Current `tail-live0` Carrier Status

- direct native Binaryen parity for `terminal drop-only host copy groups` and `chained host-copy tail-live0` is green again
- the black-box lowered-module `tail-live0` regression is green again too
- the remaining debt in this family is no longer a current reduced Binaryen mismatch:
  - raw rewritten HOT still retains one live `TupleMake` before lower
  - pass-manager lowering currently promotes that tuple node before `hot_lower`
  - the reduced self-opt compare is still red and slow even though the reduced native parity lane is green

## Historical Fuzz Evidence

Fresh current-head fuzz evidence on `2026-04-10`:

- `/tmp/pass-fuzz-tuple-gen-valid-2026-04-10` => `1000 / 1000` compared, `1000` normalized matches, `0` mismatches, `0` validation failures, `0` generator failures, `0` command failures
- `/tmp/pass-fuzz-tuple-smith-2026-04-10` => `199 / 200` compared, `199` normalized matches, `0` mismatches, `0` validation failures, `0` generator failures, `1` command failure
- the single current `wasm-smith` command failure is `case-000029-wasm-smith`, class `binaryen-rec-group-zero`, where Binaryen rejects the input with `Recursion groups of size zero not supported`
- `/tmp/pass-fuzz-tuple-gen-valid-visitmarks-2026-04-10` => `1000 / 1000` compared, `1000` normalized matches, `0` mismatches, `0` validation failures, `0` generator failures, `0` command failures
- `/tmp/pass-fuzz-tuple-smith-visitmarks-2026-04-10` => `199 / 200` compared, `199` normalized matches, `0` mismatches, `0` validation failures, `0` generator failures, `1` command failure
- the stamped visit-buffer refactor did not change the single `wasm-smith` failure classification: it is still `case-000029-wasm-smith`, class `binaryen-rec-group-zero`, where Binaryen rejects the input with `Recursion groups of size zero not supported`
- `/tmp/pass-fuzz-tuple-gen-valid-forwardcache-2026-04-10` => `1000 / 1000` compared, `1000` normalized matches, `0` mismatches, `0` validation failures, `0` generator failures, `0` command failures
- `/tmp/pass-fuzz-tuple-smith-forwardcache-2026-04-10` => `199 / 200` compared, `199` normalized matches, `0` mismatches, `0` validation failures, `0` generator failures, `1` command failure
- the forwarded-use memoization slice also kept the same lone `wasm-smith` failure classification: `case-000029-wasm-smith`, class `binaryen-rec-group-zero`
- `/tmp/pass-fuzz-tuple-gen-valid-emptysummary-2026-04-10` => `1000 / 1000` compared, `1000` normalized matches, `0` mismatches, `0` validation failures, `0` generator failures, `0` command failures
- `/tmp/pass-fuzz-tuple-smith-emptysummary-2026-04-10` => `199 / 200` compared, `199` normalized matches, `0` mismatches, `0` validation failures, `0` generator failures, `1` command failure
- the no-group summary skip likewise kept the same lone `wasm-smith` failure classification: `case-000029-wasm-smith`, class `binaryen-rec-group-zero`
- `/tmp/pass-fuzz-tuple-gen-valid-bincurrent-2026-04-10` => `1000 / 1000` compared, `1000` normalized matches, `0` mismatches, `0` validation failures, `0` generator failures, `0` command failures
- `/tmp/pass-fuzz-tuple-smith-bincurrent-2026-04-10` => `199 / 200` compared, `199` normalized matches, `0` mismatches, `0` validation failures, `0` generator failures, `1` command failure
- the rebuilt direct-binary current-tree smith lane still has the same lone `binaryen-rec-group-zero` failure at case `29`
- `/tmp/pass-fuzz-tuple-gen-valid-wbrefresh-2026-04-10` => `1000 / 1000` compared, `1000` normalized matches, `0` mismatches, `0` validation failures, `0` generator failures, `0` command failures
- `/tmp/pass-fuzz-tuple-smith-wbrefresh-2026-04-10` => `199 / 200` compared, `199` normalized matches, `0` mismatches, `0` validation failures, `0` generator failures, `1` command failure
- the refreshed short direct-binary lane after the white-box rebases still has the same lone `binaryen-rec-group-zero` failure at case `29`
- `/tmp/pass-fuzz-tuple-gen-valid-10000-bin-sharedmarks-2026-04-10` => `10000 / 10000` compared, `10000` normalized matches, `0` mismatches, `0` validation failures, `0` generator failures, `0` command failures
- `/tmp/pass-fuzz-tuple-gen-valid-10000-emptysummary-2026-04-10` => `2124 / 10000` compared, then `20` repeated missing-output validation failures in the `moon run` launcher path, not semantic mismatches

Standing larger evidence still includes the clean historical `gen-valid` lane at `10000 / 10000`.

Current interpretation:

- the isolated explicit pass is not showing semantic mismatches on the broad fuzz lane that currently compares successfully
- the white-box tuple file is now green again and no longer represents a separate parity blocker
- the remaining work is concentrated in artifact replay signoff and runtime families, plus Binaryen parser-family noise outside Starshine semantics

## Raw WAT False-Positive Probe

The branch now keeps one deliberate probe for the old full-artifact confusion:

- reduced source: the new two-lane exact-copy chain fixture now lives in `src/passes/tuple_optimization_wbtest.mbt` and `src/cmd/cmd_native_wbtest.mbt`
- raw normalized WAT for that reduced fixture still differs materially between Binaryen and Starshine after `wasm-opt -S --strip-debug`
- direct tuple parity still stays green on the same fixture:
  - white-box pipeline: `tuple.make` and `tuple.extract` are gone on the pass surface
  - native Binaryen compare: green on the canonical decoded function surface

Why this matters:

- it proves that raw `wasm-opt -S --strip-debug` text is too strict to use as the only tuple parity oracle
- Binaryen and Starshine can still differ in tuple-local scaffolding and local materialization style while decoding to the same canonical function body under the native tuple parity helper
- that is why `self-optimize-compare` now falls back to canonical per-function pretty comparison when raw normalized WAT differs

## Standing Artifact Evidence

The remaining artifact status is now:

- full tuple-only artifact compare has now been freshly rerun through the canonical-function fallback
- the older saved compare path remains `/tmp/self-opt-tuple-current` as historical evidence, but it is no longer the only kept artifact proof
- the old raw hunk at printed WAT `func $3639` is no longer treated as a proven tuple-pass bug
- tuple-only runtime is still far slower than Binaryen

Fresh full-artifact reruns on `2026-04-10`:

- `bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --starshine-bin _build/native/release/build/cmd/cmd.exe --out-dir /tmp/self-opt-tuple-full-canonical-2026-04-10 --tuple-optimization`
- result:
  - `Normalized WAT text equal: no`
  - `Canonical function compare equal: yes`
  - `Normalized WAT equal: yes`
  - `Starshine runtime (ms): 5328.045`
  - `Binaryen runtime (ms): 334.375`
  - `Starshine pass runtime (ms): 966.501`
  - `Binaryen pass runtime (ms): 4.331`
- `bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --starshine-bin _build/native/release/build/cmd/cmd.exe --out-dir /tmp/self-opt-tuple-full-smalllocals-2026-04-10 --tuple-optimization`
- result:
  - `Normalized WAT text equal: no`
  - `Canonical function compare equal: yes`
  - `Normalized WAT equal: yes`
  - `Starshine runtime (ms): 5295.675`
  - `Binaryen runtime (ms): 317.250`
  - `Starshine pass runtime (ms): 965.752`
  - `Binaryen pass runtime (ms): 2.666`

Fresh kept-tree trace evidence on the same artifact:

- `_build/native/release/build/cmd/cmd.exe --tracing pass --debug-serial-passes --tuple-optimization ...`
- result:
  - `4462` functions visited
  - `18` functions changed
  - total tuple pass time `277790 us`
  - hottest functions:
    - `Func 1673`: `101831 us`
    - `Func 148`: `14719 us`
    - `Func 2389`: `10152 us`
    - `Func 1905`: `6557 us`
    - `Func 3660`: `5725 us`
- interpretation:
  - the old unchanged-function hot quartet is no longer dominating after the shared seed-scan rewrite
  - the current runtime debt is narrower and now concentrated in one real outlier (`Func 1673`) plus a smaller tail of candidate-heavy functions
  - the old `Func[3660]` parity focus is still not where most of tuple-opt time is going

Fresh current-tree full-artifact reruns after the candidate-filter rewrite:

- `bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --starshine-bin _build/native/release/build/cmd/cmd.exe --out-dir /tmp/self-opt-tuple-full-candidatefilter-2026-04-10 --tuple-optimization`
- result:
  - `Canonical function compare equal: yes`
  - `Normalized WAT equal: yes`
  - `Starshine runtime (ms): 5634.347`
  - `Binaryen runtime (ms): 406.502`
  - `Starshine pass runtime (ms): 361.452`
  - `Binaryen pass runtime (ms): 3.711`
- `bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --starshine-bin _build/native/release/build/cmd/cmd.exe --out-dir /tmp/self-opt-tuple-full-candidatefilter-rerun-2026-04-10 --tuple-optimization`
- result:
  - `Canonical function compare equal: yes`
  - `Normalized WAT equal: yes`
  - `Starshine runtime (ms): 5114.578`
  - `Binaryen runtime (ms): 377.363`
  - `Starshine pass runtime (ms): 325.221`
  - `Binaryen pass runtime (ms): 3.741`
- interpretation:
  - this slice finally moved the full-artifact runtime needle, not just reduced micro-repros
  - the strongest evidence is the drop from the earlier `~966 ms` full pass band to a repeated `325-361 ms` band without any parity regression
  - the newer cleaned direct pass trace at `277790 us` across `4462` visited / `18` changed is consistent with that saved self-opt win even though this doc update did not rerun the full self-opt compare after backing out the non-winning experiments

Fresh reduced repro performance evidence on `2026-04-10`:

- `bun scripts/self-optimize-compare.ts /tmp/tuple-host-tail-live0.wasm --out-dir /tmp/self-opt-tuple-tail-live0-2026-04-10 --tuple-optimization`
- result:
  - `Canonical wasm equal: no`
  - `Normalized WAT equal: no`
  - `Starshine runtime (ms): 32.204`
  - `Binaryen runtime (ms): 3.066`
  - `Starshine pass runtime (ms): 0.515`
  - `Binaryen pass runtime (ms): 0.015`
- `bun scripts/self-optimize-compare.ts /tmp/tuple-host-tail-live0.wasm --out-dir /tmp/self-opt-tuple-tail-live0-visitmarks-2026-04-10 --tuple-optimization`
- result:
  - `Canonical wasm equal: no`
  - `Normalized WAT equal: no`
  - `Starshine runtime (ms): 31.959`
  - `Binaryen runtime (ms): 3.220`
  - `Starshine pass runtime (ms): 0.547`
  - `Binaryen pass runtime (ms): 0.017`
- `bun scripts/self-optimize-compare.ts /tmp/tuple-host-tail-live0.wasm --out-dir /tmp/self-opt-tuple-tail-live0-querysummary-2026-04-10 --tuple-optimization`
- result:
  - `Canonical wasm equal: no`
  - `Normalized WAT equal: no`
  - `Starshine runtime (ms): 43.497`
  - `Binaryen runtime (ms): 3.938`
  - `Starshine pass runtime (ms): 0.757`
  - `Binaryen pass runtime (ms): 0.020`
- `bun scripts/self-optimize-compare.ts /tmp/tuple-host-tail-live0.wasm --out-dir /tmp/self-opt-tuple-tail-live0-forwardcache-2026-04-10 --tuple-optimization`
- result:
  - `Canonical wasm equal: no`
  - `Normalized WAT equal: no`
  - `Starshine runtime (ms): 33.691`
  - `Binaryen runtime (ms): 3.097`
  - `Starshine pass runtime (ms): 0.601`
  - `Binaryen pass runtime (ms): 0.016`
- `bun scripts/self-optimize-compare.ts /tmp/tuple-host-tail-live0.wasm --out-dir /tmp/self-opt-tuple-tail-live0-emptysummary-2026-04-10 --tuple-optimization`
- result:
  - `Canonical wasm equal: no`
  - `Normalized WAT equal: no`
  - `Starshine runtime (ms): 35.406`
  - `Binaryen runtime (ms): 2.993`
  - `Starshine pass runtime (ms): 0.511`
  - `Binaryen pass runtime (ms): 0.014`
- `bun scripts/self-optimize-compare.ts /tmp/tuple-host-tail-live0.wasm --out-dir /tmp/self-opt-tuple-tail-live0-sharedmarks-2026-04-10 --tuple-optimization`
- result:
  - `Canonical wasm equal: no`
  - `Normalized WAT equal: no`
  - `Starshine runtime (ms): 36.952`
  - `Binaryen runtime (ms): 3.674`
  - `Starshine pass runtime (ms): 0.547`
  - `Binaryen pass runtime (ms): 0.016`
- `bun scripts/self-optimize-compare.ts /tmp/tuple-host-tail-live0.wasm --out-dir /tmp/self-opt-tuple-tail-live0-cleanupfast-2026-04-10 --tuple-optimization`
- result:
  - `Canonical wasm equal: no`
  - `Normalized WAT equal: no`
  - `Starshine runtime (ms): 42.026`
  - `Binaryen runtime (ms): 3.471`
  - `Starshine pass runtime (ms): 0.565`
  - `Binaryen pass runtime (ms): 0.017`

Important accuracy note:

- this documentation update did rerun the reduced `tail-live0` self-opt compare
- this documentation update also reran the isolated fuzz lanes after the newer direct-use summary, forwarded-use memoization, and no-group summary-skip slices
- this documentation update also reran the full debug-artifact self-opt compare with the upgraded canonical per-function fallback
- the reduced timing ladder now has a clearer shape:
  - stamped visit-buffer reuse was parity-safe but did not materially improve the reduced timing gap
  - direct-use summary construction alone regressed the reduced timing repro
  - forwarded-use memoization recovered most of that regression
  - skipping summary construction for no-group functions brought reduced pass time down further to `0.511 ms`, slightly better than the earlier visit-buffer-only `0.547 ms`
- the later shared-mark and cleanup-fast-path experiments did not beat that `0.511 ms` reduced pass baseline
- an additional local cleanup-query experiment was tried and rejected before landing; the kept pass implementation is still the earlier `0.511 ms` checkpointed path
- the later small-locals / single-write-cache analysis slice is also now measured on the full artifact: it keeps parity green and full pass time effectively flat, but it does not move the main runtime budget enough to count as a real speedup
- the current long-lane parity picture is also clearer:
  - the `moon run` launcher path hit repeated missing-output failures after case `2124`
  - direct replay of the first recorded failing input still writes valid output
  - the direct native binary path completes `10000 / 10000` cleanly
- the next performance slice should target unchanged-function candidate analysis and candidate-heavy query-summary cost, not more scratch-array cleanup or traversal-mark reuse alone
- the full-artifact claims above are now fresh `2026-04-10` replay evidence

## Practical Rule For New Bugs

- If a new bug reproduces in `cmd_native_wbtest`, treat it as a parity bug first.
- If it only reproduces in `tuple_optimization_wbtest`, classify whether the failure is:
  - stale expectation
  - HOT rewrite drift
  - lowering drift
- If it only reproduces in the full artifact replay, reduce it until it lands in one of the committed family buckets above.
