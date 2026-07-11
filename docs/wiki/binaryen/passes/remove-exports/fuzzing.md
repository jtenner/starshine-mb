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

# `remove-exports` Fuzzing Status

## Current Status: Planned Only

Do **not** run or copy a `compare-pass --pass remove-exports` command as current parity evidence. `remove-exports` fails the pass-eligibility preflight in [`../../../tooling/pass-fuzz-compare.md`](../../../tooling/pass-fuzz-compare.md): it is absent from the harness `SUPPORTED_PASS_FLAGS` list and has no active Starshine registry/dispatcher implementation. The harness rejects the argument before it generates an input or runs Starshine or Binaryen.

That rejection is a status check, not a failed smoke lane and not parity evidence. It cannot show that Starshine preserves the host-visible ABI policy required by this pass.

The upstream behavior remains planning input: Binaryen filters matching `Export` entries by parameterized wildcard patterns, while retaining definitions and index spaces. See [`index.md`](index.md) and [`../../../raw/binaryen/2026-07-11-mark-js-called-remove-exports-current-main-recheck.md`](../../../raw/binaryen/2026-07-11-mark-js-called-remove-exports-current-main-recheck.md).

## Before a Runnable Lane Exists

A future implementation must pass all four gates:

1. add an admitted canonical harness flag in `SUPPORTED_PASS_FLAGS`;
2. add an active Starshine registry and dispatcher implementation, rather than a boundary-only rejection;
3. map the local spelling to Binaryen's public `--remove-exports` flag and pass its pattern argument correctly; and
4. generate export-bearing modules with a meaningful nonzero compared-case threshold.

Targeted fixtures must cover matching and nonmatching function/table/memory/global/tag exports as supported, comma/newline pattern lists, preserved definitions and index spaces, start/active-segment behavior, and explicit host-ABI policy. A runnable `10,000`-case compare lane is appropriate only after those conditions hold; it must not silently turn a default optimization preset into export removal.
