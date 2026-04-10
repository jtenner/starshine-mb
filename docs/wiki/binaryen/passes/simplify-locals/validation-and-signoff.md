---
kind: concept
status: working
last_reviewed: 2026-04-10
sources:
  - ../../../../../agent-todo.md
  - ../../../../../src/passes/simplify_locals_test.mbt
  - ../../../../../src/passes/pass_manager_wbtest.mbt
  - ../../../../../src/passes/perf_test.mbt
  - ../../../../../scripts/pass-fuzz-compare.ts
  - ../../../../../scripts/self-optimize-compare.ts
related:
  - ./index.md
  - ./parity.md
  - ./raw-lane-and-writeback.md
  - ./performance-and-artifact-frontiers.md
  - ../../no-dwarf-default-optimize-path.md
---

# `simplify-locals` Validation And Signoff

## Why This Page Exists

- `simplify-locals` has enough moving parts now that "tests passed" is not a meaningful signoff sentence by itself.
- The pass spans:
  - lifted HOT-IR semantics
  - exact writeback cleanup
  - raw exact rewrites
  - raw no-op skip heuristics
  - artifact-scale performance work
- Different lanes prove different things. This page is the durable map of those lanes.

## Local Source Tests

### Focused Pass Tests

- Main file:
  - [`src/passes/simplify_locals_test.mbt`](../../../../../src/passes/simplify_locals_test.mbt)
- What it proves:
  - reduced semantic families
  - negative boundaries
  - structure rewrites
  - exact writeback cleanup reducers
  - selected traced raw-lane reducers

### Raw-Lane Whitebox Tests

- Main file:
  - [`src/passes/pass_manager_wbtest.mbt`](../../../../../src/passes/pass_manager_wbtest.mbt)
- What it proves:
  - skip reasons
  - exact artifact-family expectations
  - some traced raw-lane result shapes

### Perf Tests

- Main file:
  - [`src/passes/perf_test.mbt`](../../../../../src/passes/perf_test.mbt)
- What it proves:
  - the raw lane skips or rewrites the intended synthetic family
  - no-lift behavior for known no-op shapes
- What it does *not* prove:
  - real artifact parity by itself

## Package-Level Tests

- Baseline package check:
  - `moon test src/passes`
- Why it matters:
  - this is still the fastest way to ensure the pass, raw lane, and surrounding optimizer surfaces remain coherent together

## Fuzz Compare

### Canonical Lane

- Command family:
  - `bun scripts/pass-fuzz-compare.ts --pass simplify-locals --generator gen-valid --count 10000 --min-compared 10000`

### What It Proves

- Normalized output parity against Binaryen on a large reduced corpus.
- Regression protection for narrow exact and raw-lane changes that might look harmless on the artifact but are globally wrong.

### What It Does Not Prove

- It does not prove artifact performance.
- It does not prove exact printed-wasm parity on a single large debug artifact.
- It does not prove that a no-op skip is worth its maintenance cost.

## Self-Optimize Compare

### Canonical Lane

- Command family:
  - `bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --simplify-locals`

### What It Proves

- Real large-artifact parity pressure against the repo's current debug artifact.
- The actual frontier order of remaining diffs.
- Pass-time and wall-time measurements in a realistic large-module setting.

### Caveat

- This lane is sensitive to the exact checked-in or regenerated artifact.
- A moved frontier must be documented carefully; sometimes a regenerated artifact invalidates stale notes.

## Traced Native Replay

### Why It Exists

- The native traced replay is often the only practical source of truth for large artifact hotspot families and raw-skip reasons.

### What It Proves

- Which functions actually lift
- which functions skip raw and why
- where the pass spends time
- whether a supposedly-important hotspot family is actually still alive

### Caveat

- The native wbtest harness has been unstable enough that traced CLI replay remains the reliable artifact source of truth for some skip families.

## Signoff Ladder

### Minimum Semantic Signoff

- Focused reducer added in source tests
- `moon test src/passes` green
- at least one relevant pass-fuzz lane green

### Stronger Direct-Pass Signoff

- `moon test src/passes` green
- `10000/10000` `gen-valid` pass-fuzz compare green
- no new artifact mismatch category introduced

### Artifact-Sensitive Signoff

- self-opt compare rerun
- frontier moved or stayed categorized honestly
- performance data recorded when the change was motivated by runtime rather than correctness

## Current Anti-Signoff Patterns

- Do not sign off a cleanup only because printed WAT looks shorter.
- Do not sign off a broad writeback cleanup without a fuzz lane.
- Do not sign off a raw skip only because one function got faster; prove the family and guard it.
- Do not claim full Binaryen parity if the compare is still red and only one frontier family moved.

## Current Project Rule

- Correctness first.
- Binaryen parity second.
- performance heuristics third.
- That ordering matters for simplify-locals because several artifact-scale performance ideas were only safe to keep after the fuzz and compare lanes stayed green.

## Maintenance Rule

- Update this page when:
  - a new validation lane becomes required
  - a lane stops being trustworthy
  - a signoff bar changes
  - an anti-pattern becomes strong enough to deserve a permanent warning
