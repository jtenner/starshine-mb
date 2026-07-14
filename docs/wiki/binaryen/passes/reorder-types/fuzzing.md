---
kind: workflow
status: working
last_reviewed: 2026-07-11
sources:
  - ../../../tooling/pass-fuzz-compare.md
  - ../../../../../scripts/lib/pass-fuzz-compare-task.ts
  - ../../../../../src/passes/optimize.mbt
related:
  - ./index.md
  - ./ordering-cost-model-and-boundaries.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
  - ../../../tooling/pass-fuzz-compare.md
---

# `reorder-types` Fuzzing Profile

## Current status: planned, not runnable

Starshine lists `reorder-types` as `BoundaryOnly`, so an explicit request intentionally fails before execution. The compare harness also does not admit `--reorder-types` in `SUPPORTED_PASS_FLAGS`. The former generic smoke command could not compare this transform and must not be treated as parity evidence.

## Why a future lane needs a dedicated type profile

`reorder-types` is a closed-world GC type-layout rewrite. A normal generated module can be valid while containing no reorderable private type graph, no relevant predecessor/described-type edges, and no index-byte-cost choice. Meaningful testing must prove whole-module type remapping, not merely no crashes.

Before documenting a runnable lane, require:

- active module-pass dispatch plus a harness flag/Oracle mapping;
- closed-world GC input generation with public/private type visibility facts;
- rec-group, subtype, descriptor/describee, and type-index-bearing module surfaces;
- fixtures that distinguish byte-cost improving order from forbidden public-type movement; and
- validator plus binary decode/encode roundtrip checks for remapped type indices.

The full safety boundary is [`ordering-cost-model-and-boundaries.md`](ordering-cost-model-and-boundaries.md); use it to classify profiles and replay artifacts.

## Future lane template

```text
moon build --target native --release src/cmd
bun fuzz compare-pass --pass reorder-types --count 10000 --seed 0x5eed \
  --out-dir .tmp/pass-fuzz-reorder-types --jobs auto \
  --starshine-bin _build/native/release/build/cmd/cmd.exe \
  --gen-valid-profile <future-closed-world-gc-type-profile> \
  --require-feature gc --min-compared <meaningful-reorderable-count>
```

The harness must also be able to convey the closed-world policy used by the local pass. Until then, direct fixture/oracle comparison and the documented boundary-only status are the valid evidence, not a rejected command.
