---
kind: workflow
status: working
last_reviewed: 2026-07-11
sources:
  - ../../../tooling/pass-fuzz-compare.md
  - ../../../../../scripts/lib/pass-fuzz-compare-task.ts
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/registry_test.mbt
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./flatness-variant-boundaries.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
  - ../../../tooling/pass-fuzz-compare.md
  - ../tracker.md
---

# `simplify-locals-nonesting` Fuzzing Status

## Current status: planned only

Do **not** run or advertise a `compare-pass --pass simplify-locals-nonesting` command as Starshine-vs-Binaryen parity evidence today.

The spelling mismatch makes the current situation especially easy to misread:

- Binaryen's public pass spelling is `simplify-locals-nonesting`.
- Starshine tracks only `simplify-locals-no-nesting`, and that local alias is **Removed** in [`src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt), not an active transform.
- The harness's `SUPPORTED_PASS_FLAGS` set in [`scripts/lib/pass-fuzz-compare-task.ts`](../../../../../scripts/lib/pass-fuzz-compare-task.ts) admits neither spelling.
- The harness has no local alias mapping to Binaryen's `--simplify-locals-nonesting` flag.

Consequently, `--pass simplify-locals-nonesting` is rejected by the harness before generation or either optimizer runs; `simplify-locals-no-nesting` would still be rejected by Starshine as removed if it reached the registry. Neither outcome is a smoke result, command-failure result, or parity comparison.

Use this discovery command only to inspect the current admitted roster:

```text
bun fuzz compare-pass --list-passes
```

## Why the profile must be flatness-aware

This Binaryen variant is not simply “simplify locals with fewer rewrites.” Its defining contract is to preserve flatness: it must not create new tees, structure, or ordinary expression nesting while still performing allowed flat local-copy and cleanup work. See [`binaryen-strategy.md`](binaryen-strategy.md), [`flatness-variant-boundaries.md`](flatness-variant-boundaries.md), and [`wat-shapes.md`](wat-shapes.md).

A generic valid-module lane cannot establish that boundary. Future generation must distinguish:

- flat copy and local-set value-position positives;
- sinks that would introduce nesting and must remain unchanged;
- fresh-tee and structure-synthesis negatives;
- late equivalent-copy and dead-set cleanup;
- effects, traps, branches, and exception-handling barriers; and
- `flatten -> simplify-locals-nonesting` interaction shapes without treating the sibling as `flatten` itself.

## Before a runnable lane exists

A future implementation must pass all four [pass-eligibility gates](../../../tooling/pass-fuzz-compare.md#pass-eligibility-preflight):

1. add an active local implementation and dispatcher path rather than a removed-name rejection;
2. decide and document the public local spelling (preserve `simplify-locals-no-nesting`, add upstream spelling, or support both);
3. admit that spelling in `SUPPORTED_PASS_FLAGS` and map it explicitly to Binaryen `--simplify-locals-nonesting`; and
4. add a flatness-aware generator/profile with a meaningful nonzero `--min-compared` threshold.

Only then should the wiki publish a runnable 10,000-case command.

## Future command template

This is a **future-only** template:

```text
moon build --target native --release src/cmd
bun fuzz compare-pass --pass <chosen-local-spelling> --count 10000 --seed 0x5eed \
  --gen-valid-profile simplify-locals-nonesting-flat \
  --out-dir .tmp/pass-fuzz-simplify-locals-nonesting --jobs auto \
  --starshine-bin _build/native/release/build/cmd/cmd.exe \
  --min-compared <meaningful-count>
```

The future run report must preserve the requested local spelling and verify the mapped Binaryen flag through `result.json`'s `binaryenPassFlags` field.

## Required targeted tests before signoff

| Case | Required assertion |
| --- | --- |
| Flat local-copy chain | Allowed retargeting preserves a flat shape. |
| `local.set` value-position sink | A permitted flat sink remains available without creating nesting. |
| Call/arithmetic/drop/branch operand sink | Remains unchanged when moving the value would create ordinary nesting. |
| Multiple-use source | Does not introduce a fresh `local.tee`. |
| Block/if/loop result opportunity | Does not synthesize structure or result carriers. |
| Equivalent-copy and dead-set tail | Late cleanup still occurs where flatness permits it. |
| Effect/trap/EH barrier | No movement changes execution order, trapping, or exceptional control flow. |
| Local alias and upstream spelling | Unsupported requests fail honestly before landing; admitted spelling and Binaryen alias are asserted after landing. |

A normalized match after these gates is pass-local evidence only. Keep raw bytes, names, diagnostics, and unexercised flatness-sensitive syntax under dedicated tests rather than treating generic canonical WAT equality as complete proof.
