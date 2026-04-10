---
kind: concept
status: working
last_reviewed: 2026-04-10
sources:
  - ../../../raw/research/0076-2026-04-01-tuple-optimization-binaryen-port-plan.md
  - ../../../../../src/passes/tuple_optimization_wbtest.mbt
  - ../../../../../src/cmd/cmd_test.mbt
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
- black-box shape checks in `src/cmd/cmd_test.mbt`
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
- result: `13 / 13` passed

What that means:

- the reduced direct Binaryen-compare lane currently agrees with Binaryen on every committed native tuple-opt regression in that file
- this is stronger evidence than older exact-shape string checks, because the native helper now normalizes Binaryen output by decoding `.wasm` by function index

What it does not mean:

- it does not prove preset-slot parity
- it does not prove the larger artifact compare
- it does not automatically prove every white-box shape expectation is still current

## Current White-Box Drift Families

Current branch check on `2026-04-10`:

- `moon test --package jtenner/starshine/passes --file tuple_optimization_wbtest.mbt`
- result: `33 / 41` passed, `8` failed

The failing tests are currently:

1. `tuple-optimization rewrite keeps a staged host local.set root chain`
2. `tuple-optimization rewrite scalarizes exact copy groups through a root local.set lane`
3. `tuple-optimization rewrite scalarizes single-use exact copy groups from a host tee source`
4. `tuple-optimization rewrite scalarizes lane-ordered scrambled exact copy groups`
5. `tuple-optimization rewrite scalarizes overlapping exact copy groups from a host tee source`
6. `tuple-optimization rewrite stages nested branch-exit source roots through scalar copyback`
7. `tuple-optimization rewrite avoids redundant tuple.make carriers in chained host-copy tail-live0 rewrites`
8. `tuple-optimization lowered chained host-copy tail-live0 keeps downstream host tees`

Why this matters:

- these are not "the pass is completely broken" failures
- they are exact-shape or lowering-family failures on specific carrier construction paths
- they are also exactly the families future tuple work should continue to target

## Current Black-Box Shape Drift Family

Current branch check on `2026-04-10`:

- `moon test --package jtenner/starshine/cmd --file cmd_test.mbt --filter '*tuple-optimization*'`
- result: `6 / 7` passed, `1` failed

The remaining failing black-box test is:

1. `run_cmd_with_adapter tuple-optimization stages chained host-copy tail-live0 repro through typed carriers`

Interpretation:

- the pass still has one committed command-surface exact-shape gap around the typed-carrier handling of the chained host-copy `tail-live0` family
- this aligns with the hardest remaining white-box host-copy drift family rather than contradicting it

## Historical Fuzz Evidence

The standing backlog and archived note still record strong isolated-pass fuzz evidence:

- clean `gen-valid` lane historical max: `10000 / 10000` normalized matches
- current-head direct `gen-valid` rerun cited in backlog: `1000 / 1000` normalized matches
- `wasm-smith` comparable lane historical/current shape: `165 / 165` normalized matches before the cutoff is consumed by Binaryen parser failures

Current interpretation:

- the isolated explicit pass is not showing semantic mismatches on the broad fuzz lane that currently compares successfully
- the remaining work is concentrated in deterministic exact-shape and artifact replay families, plus Binaryen parser-family noise outside Starshine semantics

## Standing Artifact Evidence

The current backlog still treats these as open:

- full tuple-only artifact compare is not signed off
- the last kept compare path remains `/tmp/self-opt-tuple-current`
- the current recorded leading artifact hunk is later in `func $3639`
- tuple-only runtime is still far slower than Binaryen

Important accuracy note:

- this documentation update did not rerun the full self-opt compare
- the artifact claims above are therefore the currently recorded project evidence, not a fresh `2026-04-10` rerun

## Practical Rule For New Bugs

- If a new bug reproduces in `cmd_native_wbtest`, treat it as a parity bug first.
- If it only reproduces in `tuple_optimization_wbtest`, classify whether the failure is:
  - stale expectation
  - HOT rewrite drift
  - lowering drift
- If it only reproduces in the full artifact replay, reduce it until it lands in one of the committed family buckets above.

