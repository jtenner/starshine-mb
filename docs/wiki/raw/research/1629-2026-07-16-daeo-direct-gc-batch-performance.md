---
kind: research
status: active
created: 2026-07-16
updated: 2026-07-16
sources:
  - ../../../../src/passes/dead_argument_elimination.mbt
  - ../../../../src/passes/dae_optimizing_test.mbt
  - ./1628-2026-07-16-daeo-unbounded-convergence-batching-checkpoint.md
---

# DAEO direct-GC batch performance

## Question

Can the large-module direct-GC batch stop rescanning each large caller once per candidate callee and bring that checkpoint-1628 timer below three seconds without weakening convergence or plain-DAE separation?

## Root cause

The checkpoint-1628 batch iterated candidate callees first and then recursively scanned every direct caller for that one target. On the stripped self-host artifact, static WAT analysis estimated about `23.0M` caller-body line visits per wave even though the module contains about `1.35M` function-body lines. Absolute Func `7691` alone has about `18945` WAT lines and calls `184` candidate callees, so it was traversed `184` times per wave. Four productive waves plus the terminal no-change scan produced the traced `6877877us` direct-GC batch cost.

## Implementation

- Build concrete-GC parameter plans for all eligible boundaries before collecting actuals.
- Mark only caller definitions needed by those plans.
- Traverse each needed caller once and dispatch each active direct call to its callee-indexed plan.
- Skip parameter local-use/caller analysis when no concrete indexed GC parameter exists.
- Skip single-result analysis when the result is not a concrete indexed GC reference.
- Preserve definition-order application. If an earlier transaction touched a later candidate's caller, refresh only that candidate's evidence through the existing single-target collector.
- After each productive wave, restrict the next wave to the changed definitions, their direct callers, and their outgoing direct callees. This retains forward/backward propagation without another global candidate scan.
- Plain `dae` remains unchanged because the batch remains optimizing-only.

## Validation

- `moon info`: passed with pre-existing warnings.
- `moon fmt`: passed; `moon.mod` was restored to the repository's canonical spelling afterward.
- focused DAEO: `331/331` passed.
- full Moon: `8875/8875` passed.
- native release build passed; binary SHA-256 `ac02b98c3649966b5cacb8c6dbefebb36a4918839131a9ca5368ab84fea2ddb0`.
- dedicated DAEO smoke `.tmp/pass-fuzz-daeo-fused-dedicated-1000-20260716`: `1000/1000` normalized, zero mismatches or failures, Binaryen cache `1000/0`.
- regular GenValid smoke `.tmp/pass-fuzz-daeo-fused-regular-1000-20260716`: `1000/1000` normalized, zero mismatches or failures, Binaryen cache `1000/0`.
- output validates with `wasm-tools --features all`.

## Artifact result

Input: `.tmp/daeo-scheduled-current-artifact-20260713/cmd-stripped.wasm`.

Traced result in `.tmp/daeo-active-fused-perf-20260716`:

- direct-GC batch: `1609833us`, down from `6877877us` (`-76.6%`) and below the requested three-second subtarget;
- whole `dae-optimizing` pass: `26782488us`;
- traced command wall time: `27.858s`;
- raw output: `3212606` bytes, `261` bytes smaller than checkpoint 1628;
- Binaryen-v130 no-pass canonical output: `3275058` bytes, `1` byte smaller than checkpoint 1628;
- SHA-256: `e6da34225104ab60a9a93d95f89ce44add64c0b6e0ecebcda856b1768c1aaa86`.

## Classification and next owner

The direct-GC batch performance goal is met, and the output remains valid and slightly smaller. This is not whole-pass performance closeout. The self-host pass is still about `26.8s`; the next measured owners are the first core fixed loop (`5581093us`), post-cleanup core (`4179189us`, including another `2665072us` fixed loop and `875142us` setup), initial setup (`687272us`), unread-parameter batch (`657207us`), and dropped-result batch (`492337us`). Reaching a whole-pass sub-three-second goal requires removing repeated global core/setup work rather than further tuning direct-GC collection.
