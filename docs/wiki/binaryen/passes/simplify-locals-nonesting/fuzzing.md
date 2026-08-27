---
kind: workflow
status: supported
last_reviewed: 2026-07-27
sources:
  - ../../../tooling/pass-fuzz-compare.md
  - ../../../../../scripts/lib/pass-fuzz-compare-task.ts
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/simplify_locals_variants_test.mbt
  - ../../../../../src/validate/gen_valid.mbt
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./flatness-variant-boundaries.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
  - ../../../tooling/pass-fuzz-compare.md
  - ../simplify-locals/transform-family-inventory.md
  - ../tracker.md
---

# `simplify-locals-nonesting` fuzzing

## Current status

The direct compare lane is runnable and the Binaryen-v131 renewal is complete.

- canonical Starshine pass: `simplify-locals-nonesting`
- compatibility alias: `simplify-locals-no-nesting`
- Binaryen oracle flag: `--simplify-locals-nonesting`
- harness alias mapping: active
- dedicated aggregate profile: `simplify-locals-nonesting`
- refreshed aggregate: `10000/10000`, `7684` exact plus `2316` strictly smaller Starshine outputs (`-6..-2` bytes), zero failures
- refreshed idempotence: `1000/1000`, zero property failures
- final v131 closeout: complete on 2026-07-27
- 2026-08-27 linear root-hazard performance repair: regular GenValid `10000/10000` normalized with zero failures; dedicated comparable cases `7235/10000` = `5026` normalized + `2209` strictly smaller canonical Starshine outputs, zero canonical size losses and zero Starshine failures; `2765` family-coverage cases are Binaryen-v131 `bad node code 31` parser/tool failures

## Initial smoke

After a fresh native release build, the regular GenValid lane ran:

```text
bun fuzz compare-pass --pass simplify-locals-nonesting --count 1000 --seed 41000 \
  --jobs auto \
  --starshine-bin _build/native/release/build/cmd/cmd.exe \
  --out-dir .tmp/pass-fuzz-simplify-locals-nonesting-genvalid-1000-initial
```

Result:

- compared: `1000/1000`;
- normalized matches: `1000`;
- compare-normalized matches: `0`;
- mismatches: `0`;
- validation failures: `0`;
- property failures: `0`;
- generator failures: `0`;
- command failures: `0`.

This proves initial direct compatibility on the regular generator distribution. It does not prove the flatness-specific family matrix.

## Why the dedicated profile must be flatness-aware

The profile must distinguish:

- copy retargeting that adds no depth;
- non-copy movement into a direct `local.set` value;
- forbidden non-copy movement under `drop`, calls, arithmetic, select, returns, branch payloads, and control conditions;
- fresh-tee and structure-result negatives;
- equivalent-local and dead-write cleanup;
- effect, trap, memory, global, table, atomic, and EH barriers;
- explicit input tees versus lift-fused set/get traffic;
- `flatten -> simplify-locals-nonesting` neighborhood shapes.

A generic valid-module lane can miss these policy boundaries even when every case normalizes.

## Dedicated profile

The aggregate selects the shared `local-traffic`, `structure-result`, `flat-parent`, `effect-order`, and `stress` leaves with nonesting-specific flat-parent generation. At seed `0x5eed`, the final `10000`-case lane selected `3107/1546/3031/1523/793` local/structure/flat/effect/stress cases.

## Final command

```text
moon build --target native --release src/cmd
bun fuzz compare-pass --pass simplify-locals-nonesting --count 10000 --seed 0x5eed \
  --gen-valid-profile simplify-locals-nonesting \
  --out-dir .tmp/pass-fuzz-simplify-locals-nonesting-10000 --jobs auto \
  --starshine-bin _build/native/release/build/cmd/cmd.exe \
  --min-compared <profile-backed-threshold>
```

Final evidence: regular GenValid `100000/100000` raw matches; wasm-smith `6719/6719` comparable matches with shared Binaryen parser failures; dedicated `7684` matches plus `2316` strictly smaller effect/stress cleanups; random-all `8018` matches plus `965` strictly smaller SSA-smoke cleanups. The final `1000`-case idempotence lane had zero property failures, and the Node runtime lane had zero semantic mismatches.

## 2026-08-27 performance-repair replay

The output-preserving root-hazard scan rewrite was followed by two fresh bounded lanes using native SHA-256 recorded in the WALL evidence directory:

- regular GenValid: `10000/10000` normalized matches, zero mismatches, validation, property, generator, or command failures, and `10000/10000` canonical size equality;
- dedicated `simplify-locals-nonesting`: `7235` Binaryen-parseable comparisons, `5026` normalized matches, `2209` canonical-smaller Starshine outputs, zero canonical-larger outputs, and zero Starshine validation/property/generator failures. All `2765` command failures are selected `simplify-locals-family-coverage` inputs rejected by Binaryen v131 with `bad node code 31`; they are tool/parser failures and do not count as semantic evidence either way.

Artifacts are `.tmp/pass-fuzz-simplify-locals-nonesting-linear-hazard-final-regular-10000` and `.tmp/pass-fuzz-simplify-locals-nonesting-linear-hazard-complete-10000`. The final formatted timing evidence is `.tmp/slnonesting-perf-fix-20260827/final-formatted-timing/median.json`.

## Classification rule

Do not classify a mismatch as safe because both outputs validate or Starshine is smaller. Inspect the transform family and classify it as a Starshine win, parity gap, size-losing difference, unknown/risky difference, validation failure, tool failure, or true semantic mismatch. A retained output-shape difference requires source-backed semantics and measured benefit; otherwise align to Binaryen.
