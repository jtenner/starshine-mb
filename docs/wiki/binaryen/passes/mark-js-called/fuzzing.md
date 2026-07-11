---
kind: workflow
status: working
last_reviewed: 2026-07-11
sources:
  - ../../../tooling/pass-fuzz-compare.md
  - ../../../raw/binaryen/2026-07-11-mark-js-called-remove-exports-current-main-recheck.md
  - ../../../../../scripts/lib/pass-fuzz-compare-task.ts
  - ../../../../../src/passes/optimize.mbt
related:
  - ./index.md
  - ../../../tooling/pass-fuzz-compare.md
  - ../tracker.md
---

# `mark-js-called` Fuzzing Status

## Current Status: Planned Only

Do **not** run or copy a `compare-pass --pass mark-js-called` command as current parity evidence. `mark-js-called` fails the pass-eligibility preflight in [`../../../tooling/pass-fuzz-compare.md`](../../../tooling/pass-fuzz-compare.md): it is absent from the harness `SUPPORTED_PASS_FLAGS` list and has no active Starshine registry/dispatcher implementation. The harness rejects the argument before input generation or either optimizer executes.

That rejection proves only current tooling status. It does not compare Starshine with Binaryen and must not be reported as a smoke result, a command failure, or parity evidence.

The upstream behavior remains useful planning input: Binaryen recognizes `configureAll` calls and synthesizes `binaryen.js.called` metadata for referred functions. See [`index.md`](index.md) and [`../../../raw/binaryen/2026-07-11-mark-js-called-remove-exports-current-main-recheck.md`](../../../raw/binaryen/2026-07-11-mark-js-called-remove-exports-current-main-recheck.md).

## Before a Runnable Lane Exists

A future implementation must pass all four gates:

1. add an admitted canonical harness flag in `SUPPORTED_PASS_FLAGS`;
2. add an active Starshine registry and dispatcher implementation, rather than a boundary-only rejection;
3. map the local spelling to Binaryen's public `--mark-js-called` flag; and
4. add a generator/profile that can create a `configureAll` intrinsic shape and require a nonzero meaningful compared-case count.

The first targeted tests should distinguish existing `(@binaryen.js.called)` annotation carriage from configureAll-driven synthesis, keep unrelated annotations intact, and cover the separately handled start-function intrinsic path. Only after those tests and an active pass exist should a command template become a runnable `10,000`-case signoff lane.
