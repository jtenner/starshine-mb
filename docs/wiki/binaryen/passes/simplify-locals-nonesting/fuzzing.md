---
kind: workflow
status: working
last_reviewed: 2026-07-17
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

The direct compare lane is runnable.

- canonical Starshine pass: `simplify-locals-nonesting`
- compatibility alias: `simplify-locals-no-nesting`
- Binaryen oracle flag: `--simplify-locals-nonesting`
- harness alias mapping: active
- dedicated aggregate profile: not yet implemented
- final closeout: not yet complete

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

## Required profile shape

Add one deterministic aggregate profile and leaf aliases grouped around the source-owned family inventory:

1. `copy-retarget`;
2. `set-value-parent`;
3. `ordinary-consumer-negative`;
4. `no-tee`;
5. `no-structure`;
6. `equivalent-and-dead-cleanup`;
7. `effects-and-traps`;
8. `control-and-eh`;
9. `lift-fused-tee-boundary`;
10. `stress`.

Each leaf needs a meaningful nonzero compared-case threshold and direct profile tests proving the intended family is generated.

## Final command template

After the aggregate profile lands:

```text
moon build --target native --release src/cmd
bun fuzz compare-pass --pass simplify-locals-nonesting --count 10000 --seed 0x5eed \
  --gen-valid-profile simplify-locals-nonesting \
  --out-dir .tmp/pass-fuzz-simplify-locals-nonesting-10000 --jobs auto \
  --starshine-bin _build/native/release/build/cmd/cmd.exe \
  --min-compared <profile-backed-threshold>
```

Also run low-feature, trap/effect, and stress lanes. Add `--wasm-smith` only for the explicitly separate external-generator lane.

## Classification rule

Do not classify a mismatch as safe because both outputs validate or Starshine is smaller. Inspect the transform family and classify it as a Starshine win, parity gap, size-losing difference, unknown/risky difference, validation failure, tool failure, or true semantic mismatch. A retained output-shape difference requires source-backed semantics and measured benefit; otherwise align to Binaryen.
