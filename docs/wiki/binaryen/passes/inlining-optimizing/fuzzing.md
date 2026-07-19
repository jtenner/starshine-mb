---
kind: workflow
status: supported
last_reviewed: 2026-07-19
sources:
  - ../../../tooling/pass-fuzz-compare.md
  - ../../../../../scripts/lib/pass-fuzz-compare-task.ts
  - ../../../../../src/validate/gen_valid.mbt
  - ./index.md
related:
  - ./starshine-port-readiness-and-validation.md
  - ../inlining/fuzzing.md
---

# `inlining-optimizing` fuzzing and performance

## Current official-v131 closeout

```text
.tmp/pass-fuzz-inlining-optimizing-v131-closeout-10000
pass: inlining-optimizing
profile: inlining-optimizing-all
seed: 0x5eed
jobs: 16
10000/10000 compared
10000 normalized matches
0 mismatches
0 validation failures
0 property failures
0 generator failures
0 command failures
```

The run used:

- `_build/native/release/build/cmd/cmd.exe` from a current native release build;
- `.tmp/binaryen-version-131-bin/bin/wasm-opt` reporting `wasm-opt version 131 (version_131)`;
- explicit wasm-tools `1.251.0`;
- persistent Binaryen oracle caching.

Reproduction shape:

```text
bun fuzz compare-pass --pass inlining-optimizing --count 10000 --seed 0x5eed \
  --gen-valid-profile inlining-optimizing-all --jobs auto \
  --starshine-bin _build/native/release/build/cmd/cmd.exe \
  --wasm-opt-bin .tmp/binaryen-version-131-bin/bin/wasm-opt \
  --out-dir .tmp/pass-fuzz-inlining-optimizing-v131-closeout-10000
```

## Aggregate profile

`inlining-optimizing-all` samples focused direct-wrapper, parameter-spill, return-call, and cleanup-payoff leaves. It is the ordinary dedicated profile for this pass. Use singleton leaves only for targeted reduction or regression work.

The profile complements, rather than replaces, focused tests for toolchain/no-inline policy, complete trivial classes, splitting, EH tail hoisting, multivalue/local repair, roots, metadata, exact nested order, and touched filtering.

## Plain sibling

Plain `inlining` independently reached `10000/10000` normalized matches in `.tmp/pass-fuzz-inlining-v131-closeout-10000`. Keep the two stop points separate in mismatch classification.

## Performance lane

The durable pass-local timing fixture is the inline-heavy helper-chain matrix under `.tmp/io-perf-20260705/measurements/`. It compares Starshine's traced `pass:inlining-optimizing` median with Binaryen `BINARYEN_PASS_DEBUG=1` over 1, 5, 10, 20, 50, and 100 helpers.

Accepted post-repair Starshine/Binaryen ratios are:

- 1 helper: `0.443x`;
- 5 helpers: `0.735x`;
- 10 helpers: `0.797x`;
- 20 helpers: `0.970x`;
- 50 helpers: `0.535x`;
- 100 helpers: `0.246x`.

Reopen performance on repeated median regression above `1x` Binaryen or a new nested-cleanup scaling cliff.

## Mismatch workflow

For any new failure:

1. preserve input, both raw outputs, normalized outputs, and command logs;
2. minimize before implementation;
3. identify direct-engine versus nested-cleanup ownership;
4. classify semantic, validation, size, performance, Starshine win, or tool/oracle failure;
5. add the focused regression first;
6. rerun the dedicated aggregate and the relevant singleton leaf.

Do not hide local-allocation, unreachable-control, or dropped-value differences behind a normalizer without source-backed semantic and size evidence.
