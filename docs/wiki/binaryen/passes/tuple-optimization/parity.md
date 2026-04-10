---
kind: comparison
status: working
last_reviewed: 2026-04-10
sources:
  - ../../../raw/research/0076-2026-04-01-tuple-optimization-binaryen-port-plan.md
  - ../../../../../src/passes/tuple_optimization.mbt
  - ../../../../../src/passes/tuple_optimization_wbtest.mbt
  - ../../../../../src/cmd/cmd_test.mbt
  - ../../../../../src/cmd/cmd_native_wbtest.mbt
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../agent-todo.md
  - ../../../../../CHANGELOG.md
related:
  - ./index.md
  - ./scheduler-and-gates.md
  - ./reduced-repros-and-evidence.md
  - ../../no-dwarf-default-optimize-path.md
---

# `tuple-optimization` Binaryen Parity

## Durable Conclusions

- Starshine's tuple-opt should be judged first against Binaryen, not against a home-grown notion of "reasonable multivalue cleanup."
- The explicit pass surface is real and useful today, but it is not yet preset-slot parity.
- The isolated pass has strong direct parity evidence on reduced and fuzzed lanes.
- Exact-shape drift still exists in white-box and one black-box carrier family, and full artifact parity is still not signed off.

## Current In-Tree Status

- The implementation lives in [`../../../../../src/passes/tuple_optimization.mbt`](../../../../../src/passes/tuple_optimization.mbt).
- Focused white-box coverage lives in [`../../../../../src/passes/tuple_optimization_wbtest.mbt`](../../../../../src/passes/tuple_optimization_wbtest.mbt).
- CLI and emitted-module shape checks live in [`../../../../../src/cmd/cmd_test.mbt`](../../../../../src/cmd/cmd_test.mbt).
- Direct native Binaryen comparison lives in [`../../../../../src/cmd/cmd_native_wbtest.mbt`](../../../../../src/cmd/cmd_native_wbtest.mbt).
- Preset placement is still intentionally deferred in [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt).

## Current Direct Test Evidence

Fresh local checks taken for this doc update on `2026-04-10`:

- `moon test --package jtenner/starshine/cmd --file cmd_native_wbtest.mbt --target native --filter '*tuple-optimization*'`
  - result: `13 / 13` passed
- `moon test --package jtenner/starshine/passes --file tuple_optimization_wbtest.mbt`
  - result: `33 / 41` passed, `8` failed
- `moon test --package jtenner/starshine/cmd --file cmd_test.mbt --filter '*tuple-optimization*'`
  - result: `6 / 7` passed, `1` failed

Interpretation:

- direct reduced Binaryen comparison is currently green
- the remaining failures are concentrated in exact-shape or lowering families rather than broad semantic divergence across the committed native compare lane

## Current Green Surface

The branch is already in good shape on these fronts:

- explicit pass registration and CLI execution
- scalar-only explicit no-op behavior
- reduced direct spill, copy-chain, host-tee, mixed scalar-forward, nested no-host, and nested scalar-result parity families in the native compare suite
- historical and backlog-recorded isolated fuzz lanes with zero semantic mismatches on comparable cases

## Current Red Surface

Parity is not signed off yet because all of these are still open:

- exact-shape white-box drift in eight committed tuple-opt rewrite fixtures
- one black-box command-surface typed-carrier failure on chained host-copy `tail-live0`
- preset slot still not enabled in the real Binaryen neighborhood
- the last recorded full artifact compare is still red and still treated as an active blocker
- tuple-only runtime remains well behind Binaryen on the artifact replay

## Remaining White-Box Failures

The exact failing tests on current head are:

1. staged host local-set root chain
2. root local-set exact-copy scalarization
3. single-use exact-copy scalarization from host-tee source
4. lane-ordered scrambled exact-copy scalarization
5. overlapping exact-copy scalarization from host-tee source
6. nested branch-exit source-root scalar copyback
7. redundant `tuple.make` suppression in chained host-copy `tail-live0`
8. lowering of chained host-copy `tail-live0` with downstream host tees

These failures cluster around one theme:

- carrier construction and post-rewrite exact shape remain unstable in the hardest host-copy and nested root families

## Standing Fuzz Evidence

The currently recorded project evidence still includes:

- a clean `gen-valid` direct compare run at `10000 / 10000`
- smaller current-head clean reruns at `1000 / 1000`
- `wasm-smith` comparable cases at `165 / 165` before only Binaryen parser failures consume the failure budget

These are still meaningful, but they are not enough for final signoff because:

- they cover the explicit pass in isolation
- they do not substitute for exact preset-slot proof
- they do not close the remaining deterministic carrier and artifact families

## Preset And Scheduler Gap

The pass is still absent from `optimize` and `shrink`.

That is intentional, not an oversight:

- Binaryen wants `code-pushing -> tuple-optimization -> simplify-locals-nostructure`
- Starshine does not yet have that exact neighborhood represented in public presets
- enabling tuple-opt in an approximate slot would blur the difference between "explicit pass parity" and "preset parity"

## Artifact And Performance Gap

The active backlog still records the remaining artifact problem as:

- latest kept tuple-only compare path: `/tmp/self-opt-tuple-current`
- leading recorded mismatch later in `func $3639`
- tuple-only runtime still far slower than Binaryen

Accuracy note:

- this doc update did not rerun the full self-opt compare because that command remains permission-gated project work
- the artifact and runtime claims above are therefore the latest recorded project evidence, not a fresh replay

## Signoff Rule

Do not call tuple-opt done until all of these are true:

- the explicit pass remains green on reduced native Binaryen comparison
- the remaining exact-shape white-box and command-surface carrier failures are resolved or intentionally rebaselined
- the pass lands in the real Binaryen slot with feature-off coverage
- `bun scripts/pass-fuzz-compare.ts --pass tuple-optimization --count 10000 ...` is acceptable on current head
- the full debug-artifact compare is green enough to remove it from the active backlog

## Sources

- Archived note: [`../../../raw/research/0076-2026-04-01-tuple-optimization-binaryen-port-plan.md`](../../../raw/research/0076-2026-04-01-tuple-optimization-binaryen-port-plan.md)
- Active backlog: [`../../../../../agent-todo.md`](../../../../../agent-todo.md)
- Recent checkpoint record: [`../../../../../CHANGELOG.md`](../../../../../CHANGELOG.md)
- Implementation: [`../../../../../src/passes/tuple_optimization.mbt`](../../../../../src/passes/tuple_optimization.mbt)

