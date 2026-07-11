---
kind: workflow
status: planned
last_reviewed: 2026-07-11
sources:
  - ../../../raw/binaryen/2026-07-11-type-generalizing-v130-current-main-recheck.md
  - ../../../tooling/pass-fuzz-compare.md
  - ../../../../../scripts/lib/pass-fuzz-compare-task.ts
  - ../../../../../src/passes/optimize.mbt
related:
  - ./index.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
---

# `type-generalizing` fuzzing status

## Current state: planned, not runnable

Do **not** treat a normal `bun fuzz compare-pass --pass type-generalizing ...` command as a Starshine parity lane.

- [`src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt) classifies local `type-generalizing` as **BoundaryOnly**, so no implementation runs.
- [`scripts/lib/pass-fuzz-compare-task.ts`](../../../../../scripts/lib/pass-fuzz-compare-task.ts) does not admit `type-generalizing` in `SUPPORTED_PASS_FLAGS`.
- Upstream's reviewed spelling is hidden `experimental-type-generalizing`, registered with `registerTestPass(...)` and marked not yet sound. A local `type-generalizing` spelling would need an explicit oracle mapping rather than an assumed flag substitution.

A rejected command or zero compared cases is admission-status evidence only. It proves neither Binaryen behavior nor Starshine parity.

Safe inspection only:

```text
bun fuzz compare-pass --list-passes
```

## Future executable lane

Publish a comparison command only after all four gates hold:

1. Starshine has an active, deliberately experimental implementation with focused tests.
2. The registry moves the local name out of `BoundaryOnly` and records its user-facing experimental policy.
3. The harness admits that local spelling and maps it explicitly to Binaryen's hidden `--experimental-type-generalizing` invocation.
4. A profile/fixture corpus covers CFG joins, local/stack requirements, direct calls, `call_ref`, global/table constraints, and guarded GC aggregate shapes with a meaningful `--min-compared` threshold.

Future-only command shape:

```text
moon build --target native --release src/cmd
bun fuzz compare-pass --pass type-generalizing --count 10000 --seed 0x5eed \
  --gen-valid-profile <type-generalizing-profile> \
  --out-dir .tmp/pass-fuzz-type-generalizing --jobs auto \
  --starshine-bin _build/native/release/build/cmd/cmd.exe \
  --min-compared <meaningful-threshold>
```

Because upstream marks this pass not yet sound, direct fixture/lit comparison should precede broad generation. Classify future differences from the transform contract and validation evidence, never from output validity alone.
