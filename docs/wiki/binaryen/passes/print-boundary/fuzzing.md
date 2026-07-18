---
kind: workflow
status: working
last_reviewed: 2026-07-18
sources:
  - https://github.com/WebAssembly/binaryen/blob/version_131/src/passes/PrintBoundary.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_131/test/lit/passes/print-boundary.wast
  - ../../../raw/research/1573-2026-07-18-binaryen-version-131-release-impact-audit.md
  - https://github.com/WebAssembly/binaryen/blob/main/src/passes/PrintBoundary.cpp
  - ../../../tooling/pass-fuzz-compare.md
  - ../../../../../scripts/lib/pass-fuzz-compare-task.ts
related:
  - ./index.md
  - ../../../tooling/pass-fuzz-compare.md
  - ../tracker.md
---

# `print-boundary` Validation Status

## Current Status: Planned Only

Do **not** run or advertise `bun fuzz compare-pass --pass print-boundary` as current evidence. `print-boundary` is absent from the harness `SUPPORTED_PASS_FLAGS` list and has no Starshine registry/dispatcher implementation. The harness would reject the flag before generating a module or invoking either tool.

More fundamentally, normal compare-pass compares transformed Wasm. `print-boundary` is a no-mutation import/export JSON protocol (written to stdout unless an output file is requested), so matching output modules would not prove its behavior even if the name were admitted.

## Correct Future Test Strategy

A port needs a dedicated stdout snapshot lane, not only a Wasm-diff lane:

1. an empty module plus imports and exports for every external kind;
2. the exact `imports` / `exports` record schema, deterministic ordering, and JSON parsing rather than substring matching;
3. module/base/export-name escaping plus stdout versus explicit-output-file routing;
4. recursive function-signature references that prove the configured depth cutoff terminates;
5. unchanged encoded Wasm bytes before/after reporting; and
6. validation before/after reporting to catch accidental inspection-time mutation.

Only add a harness lane after the command schema, output channel, cutoff policy, active registry/dispatcher route, and a JSON-aware oracle are all defined. A successful ordinary `wasm-opt -S` comparison is insufficient because it ignores the signal this pass exists to produce.

The released v131 owner/fixture and recursive-type repair are documented by [`PrintBoundary.cpp`](https://github.com/WebAssembly/binaryen/blob/version_131/src/passes/PrintBoundary.cpp), the [focused fixture](https://github.com/WebAssembly/binaryen/blob/version_131/test/lit/passes/print-boundary.wast), and [PR #8786](https://github.com/WebAssembly/binaryen/pull/8786).
