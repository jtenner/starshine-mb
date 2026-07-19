---
kind: workflow
status: supported
last_reviewed: 2026-07-19
sources:
  - ../../../tooling/pass-fuzz-compare.md
  - ../../../../../scripts/lib/pass-fuzz-compare-task.ts
  - ../../../../../src/passes/directize_test.mbt
  - ./index.md
---

# `directize` Fuzzing Profile

## Current explicit-v131 closeout

- Regular GenValid, seed `0x5eed`, `.tmp/directize-v131-regular-100000`: `100000/100000` normalized, zero failures.
- Explicit wasm-smith, seed `0x5eed`, `.tmp/directize-v131-wasm-smith-10000`: `9956/10000` compared, `9955` normalized, one generic `drop(unreachable)` representation residual, `44` Binaryen/tool failures, zero validation/property failures.
- Random all-profiles, seed `0x5555`, `.tmp/directize-v131-random-all-10000`: `10000/10000` normalized, zero failures.

There is no dedicated directize GenValid aggregate yet. The focused `src/passes/directize_test.mbt` suite is the pass-specific v131 matrix and passes `8/8`. It covers segment-known calls, mutation barriers, select and return-call lowering, known holes, `ref.func` table defaults, known entries below growth, and unknown newly grown entries. Exact upstream-shaped `ref.func` and imported-global initializer comparisons are canonical/normalized equal under `.tmp/directize-v131-*-init-compare`.

A direct self-hosted replay at `.tmp/directize-v131-o4z-direct-perf2` is canonical/normalized equal at `5,005,879` bytes. Starshine directize pass-local time is `48.986ms` versus Binaryen `37.977ms` (`1.29x`, inside the repo `2x` target), and whole-command time is faster (`680.173ms` versus `837.578ms`). The current five-pass accepted late-tail replay is blocked before directize by the independently tracked simplify-globals/vacuum invalid-local failure in function 10182; directize itself is not reached in that failed replay.
