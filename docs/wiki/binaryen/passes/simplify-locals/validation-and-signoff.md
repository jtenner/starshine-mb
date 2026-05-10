---
kind: concept
status: working
last_reviewed: 2026-05-06
sources:
  - ../../../raw/research/0541-2026-05-06-simplify-locals-direct-revalidation.md
  - ../../../../../agent-todo.md
  - ../../../../../src/passes/simplify_locals_test.mbt
  - ../../../../../src/passes/pass_manager_wbtest.mbt
  - ../../../../../src/passes/perf_test.mbt
  - ../../../../../src/passes_perf_long/simplify_locals_multivalue_perf_test.mbt
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

- Lean default file:
  - [`src/passes/perf_test.mbt`](../../../../../src/passes/perf_test.mbt)
- Separate long lane:
  - [`src/passes_perf_long/simplify_locals_multivalue_perf_test.mbt`](../../../../../src/passes_perf_long/simplify_locals_multivalue_perf_test.mbt)
- What they prove together:
  - the raw lane skips or rewrites the intended synthetic family
  - no-lift behavior for known no-op shapes
  - the large multivalue synthetic stress families still have an explicit command lane without bloating the default `src/passes` package run
- What they do *not* prove:
  - real artifact parity by itself

## Package-Level Tests

- Baseline package check:
  - `moon test src/passes`
- Separate long perf check when the multivalue stress lane matters:
  - `moon test src/passes_perf_long`
- Why it matters:
  - `moon test src/passes` stays the fast edit-loop command for the pass, raw lane, and surrounding optimizer surfaces
  - the intentionally slower multivalue perf stress lane still exists, but now has an explicit opt-in command instead of stretching the default suite

## Fuzz Compare

### Canonical Lane

- Current post-audit command:
  - `bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass simplify-locals --out-dir .tmp/pass-fuzz-simplify-locals`
- Current 2026-05-06 result:
  - `6759/10000` compared cases, `6759` normalized matches, `0` mismatches, and `20` Binaryen empty-recursion-group parser/canonicalization command failures; see [`0541-2026-05-06-simplify-locals-direct-revalidation.md`](../../../raw/research/0541-2026-05-06-simplify-locals-direct-revalidation.md).
- Historical gen-valid-only command family:
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
- Long pass-fuzz lanes can also fail for harness reasons that are not pass mismatches when they launch Starshine through `moon run`; the earlier 2026-04-10 `simplify-locals` validator-call-tail lane that stopped at `5957` cases is now historical evidence of launcher noise, not the current keep-state.
- The current repo guidance for long simplify-locals signoff is:
  - use a fixed native CLI binary when possible, for example `--starshine-bin _build/native/release/build/cmd/cmd.exe`
  - keep the `moon run` form for convenience and reducer work
  - treat the binary-backed long lane as the cleaner measure when the goal is pass parity and pass runtime rather than launcher reliability
  - if a native artifact replay looks suspiciously unchanged, prefer a forced clean rebuild of `_build/native/release` before trusting the timing or frontier data

## Signoff Ladder

### Minimum Semantic Signoff

- Focused reducer added in source tests
- `moon test src/passes` green
- at least one relevant pass-fuzz lane green

### Stronger Direct-Pass Signoff

- `moon test src/passes` green
- `10000/10000` `gen-valid` pass-fuzz compare green
- no new artifact mismatch category introduced
- for native timing claims, prefer the clean-binary lane over an incremental rebuild if both were run

### Artifact-Sensitive Signoff

- self-opt compare rerun
- frontier moved or stayed categorized honestly
- performance data recorded when the change was motivated by runtime rather than correctness
- if the artifact frontier did not move, record whether the reduced Binaryen probe and the focused synthetic regression did move; that distinction matters for later raw-shape debugging
- if the direct native `--print-func` path is cleaner than the self-opt compare output, record that explicitly; it means the remaining gap is on encoded-output or Binaryen-reparse shape, not on the in-memory raw reducer
- if a change improves self-opt timing but leaves the first mismatch unchanged, record both facts together; that is a real performance win but not a parity retirement
- if a reduced Binaryen probe proves the local transform but the artifact is still red, do not automatically promote the diagnosis to "writeback bug"; first prove that the large artifact actually hits the same reducer boundary

## Current 2026-05-09 Checkpoint

- Source and package checks:
  - `moon fmt` completed.
  - `moon info` completed.
  - `moon test src/passes` passed `817/817`.
  - `moon test` passed `2874/2874`.
- Direct pass-fuzz evidence:
  - `.tmp/pass-fuzz-simplify-locals-genvalid-10000`: `10000/10000` compared, `10000` normalized matches, `0` mismatches, `0` command failures.
  - `.tmp/pass-fuzz-simplify-locals-both-10000-keepgoing`: `9975/10000` compared, `9975` normalized matches, `0` mismatches, `25` command failures classified outside Starshine semantic mismatches.
- Direct debug-artifact replay:
  - `.tmp/sl-artifact-direct-after-typed-if` remains exact-red at `defined=5 abs=22`.
  - The retired first diff was `defined=1 abs=18`; the new first diff is a representation drift where Binaryen keeps `drop (if (result i32) ...)` and Starshine keeps the equivalent void `if`.
  - pass-local timing remains green: Starshine `489.504ms` vs Binaryen `492152.000ms`, `Starshine pass at least as fast: yes`.

## Current Anti-Signoff Patterns

- Do not sign off a cleanup only because printed WAT looks shorter.
- Do not sign off a broad writeback cleanup without a fuzz lane.
- Do not sign off a raw skip only because one function got faster; prove the family and guard it.
- Do not claim full Binaryen parity if the compare is still red and only one frontier family moved.
- Do not rely on a short lane alone for the current keep-state when a long lane was practical; the present 2026-04-10 branch-carrier checkpoint has fresh `10000/10000` evidence in `.tmp/pass-fuzz-sl-branch-terminated-carrier-10k`.

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
