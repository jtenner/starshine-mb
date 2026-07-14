---
kind: workflow
status: working
last_reviewed: 2026-07-11
sources:
  - ../../../tooling/pass-fuzz-compare.md
  - ../../../raw/binaryen/2026-07-11-de-nan-current-main-fuzzing-reconciliation.md
  - ../../../../../scripts/lib/pass-fuzz-compare-task.ts
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/registry_test.mbt
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
  - ../../../tooling/pass-fuzz-compare.md
  - ../tracker.md
---

# `de-nan` / Binaryen `denan` Fuzzing Status

## Current status: planned only

Do **not** run or advertise `bun fuzz compare-pass --pass de-nan` as Starshine-vs-Binaryen parity evidence today.

The pass fails the [pass-eligibility preflight](../../../tooling/pass-fuzz-compare.md#pass-eligibility-preflight) before a module is generated or either optimizer runs:

- The harness's `SUPPORTED_PASS_FLAGS` allowlist in [`scripts/lib/pass-fuzz-compare-task.ts`](../../../../../scripts/lib/pass-fuzz-compare-task.ts) does not admit `--de-nan`.
- Starshine's [`src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt) records `de-nan` as **Removed**, and [`src/passes/registry_test.mbt`](../../../../../src/passes/registry_test.mbt) asserts that status. A request is rejected rather than dispatched to a transform.
- The harness has no alias from the local spelling `--de-nan` to Binaryen's public `--denan` flag.

A parser or removed-pass rejection proves only the current local admission status. It is **not** a smoke result, command-failure result, or Binaryen-parity result.

Use this harmless discovery command only to inspect the current admitted roster:

```text
bun fuzz compare-pass --list-passes
```

`de-nan` should remain absent until Starshine deliberately implements and admits it. The July reconciliation and upstream source context are captured in [`../../../raw/binaryen/2026-07-11-de-nan-current-main-fuzzing-reconciliation.md`](../../../raw/binaryen/2026-07-11-de-nan-current-main-fuzzing-reconciliation.md).

## Why an ordinary generic lane is not enough

Binaryen's public pass is `denan`: a behavior-changing NaN-to-zero instrumentation pass, not a normal semantics-preserving optimizer. It replaces NaN constants with zero, adds helper calls for nonconstant floating/SIMD producers inside functions, and sanitizes defined-function float/vector parameters. See [`binaryen-strategy.md`](binaryen-strategy.md) and [`wat-shapes.md`](wat-shapes.md).

A future lane therefore needs more than arbitrary valid Wasm:

- **NaN-bearing scalar inputs:** `f32` and `f64` constants and computed producers must occur often enough to exercise both constant replacement and helper wrapping.
- **Context split:** global constant repair is legal, but helper calls are function-body-only; a generator must retain both contexts.
- **Structural negative cases:** `local.get` and result-fallthrough shells must not be double-wrapped.
- **Entry and helper cases:** defined versus imported function parameters and user helper-name collisions need deliberate fixtures.
- **SIMD split:** `v128` NaN lanes and the lane-wise helper strategy need a separate feature-enabled lane rather than being inferred from scalar coverage.

A normalized WAT match cannot by itself justify the intentional user-visible change from NaN to zero. Focused tests must first establish that this is the requested product behavior.

## Before a runnable lane exists

A future implementation must pass all four admission gates:

1. **Starshine transform:** replace the removed-name entry with an active module-owned implementation and dispatcher path; do not silently turn the removed spelling into a no-op.
2. **Harness admission:** add the chosen canonical local spelling to `SUPPORTED_PASS_FLAGS`.
3. **Oracle mapping:** add and test an explicit alias from local `--de-nan` to Binaryen `--denan`; verify the resulting `binaryenPassFlags` field in `result.json`.
4. **Surface admission:** add a focused scalar profile and a SIMD-capable profile/corpus, each with a meaningful nonzero `--min-compared` threshold.

Only after those gates and the targeted tests below are green should this page publish a runnable 10,000-case command.

## Future command templates

These are **future-only** templates, not commands to run against the current checkout.

```text
moon build --target native --release src/cmd
bun fuzz compare-pass --pass de-nan --count 10000 --seed 0x5eed \
  --gen-valid-profile denan-scalar --out-dir .tmp/pass-fuzz-de-nan-scalar \
  --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe \
  --min-compared <meaningful-count>
```

After scalar behavior is accepted, run a separately classified SIMD lane rather than folding SIMD coverage into an unlabelled generic run:

```text
bun fuzz compare-pass --pass de-nan --count 10000 --seed 0x5eed \
  --gen-valid-profile denan-simd --require-feature simd \
  --out-dir .tmp/pass-fuzz-de-nan-simd --jobs auto \
  --starshine-bin _build/native/release/build/cmd/cmd.exe \
  --min-compared <meaningful-count>
```

The exact profile names are intentionally placeholders. Define them only with generators that prove the required shapes and record selected-profile/feature facts in the run manifest.

## Required targeted tests before signoff

| Case | Required assertion |
| --- | --- |
| NaN global initializer | Becomes a zero constant without inserting an illegal helper call outside a function. |
| NaN `f32` / `f64` body constant | Becomes zero directly, not an unnecessary helper call. |
| Nonconstant scalar producer | Receives the same-typed helper call while preserving value/control placement. |
| Defined float/vector parameter | Is sanitized at function entry. |
| Imported function | Receives no synthetic body/entry repair. |
| `local.get` and result-fallthrough shells | Stay unwrapped; children, not pass-through structure, carry any repair. |
| Existing `deNan32` / `deNan64` names | Generated helper names remain collision-safe. |
| SIMD NaN lane | Uses the source-backed lane-wise strategy; non-SIMD modules do not gain a SIMD helper. |
| Repeated pass / helper body boundary | Does not instrument generated helpers or create unbounded wrapper growth. |
| Explicit `de-nan` request before landing | Continues to fail as removed, so unsupported behavior cannot masquerade as success. |

When a lane exists, report requested and compared counts, raw and cleanup-normalized counts, validation outcomes, alias mapping, selected generator/profile facts, and the judgment for every mismatch. Do not call a match proof of raw-byte, debug/name, custom-section, or unexercised host/runtime behavior.
