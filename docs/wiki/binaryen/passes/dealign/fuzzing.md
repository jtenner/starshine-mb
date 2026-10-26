---
kind: workflow
status: planned
last_reviewed: 2026-07-18
sources:
  - ../../../tooling/pass-fuzz-compare.md
  - ../../../../../scripts/lib/pass-fuzz-compare-task.ts
  - ../../../../../src/passes/optimize.mbt
related:
  - ./index.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
  - ../../../tooling/pass-fuzz-compare.md
---

# `dealign` Fuzzing Status

## Current status

The harness admits `--dealign`, and Starshine registers it as a module pass. Admission alone does not prove parity.

- [`scripts/lib/pass-fuzz-compare-task.ts`](../../../../../scripts/lib/pass-fuzz-compare-task.ts) admits `--dealign`.
- [`src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt) registers the pass and [`src/passes/dealign.mbt`](../../../../../src/passes/dealign.mbt) implements it.
- Zero compared cases cannot be presented as Binaryen-parity evidence.

The upstream `align=1` rewrite contract is retained in [`./binaryen-strategy.md`](./binaryen-strategy.md) and the port-readiness digest [research note 0389](./index.md). This page corrects only the local lane-admission claim.

## Safe inspection now

```text
bun fuzz compare-pass --list-passes
```

This inspects the current harness roster only. It neither runs `dealign` nor proves parity.

## Historical lane template

This earlier template predates the current signoff rules. Use [`docs/README.md`](../../../../README.md) for the current command and verified Binaryen 133 oracle requirements.

Use this only after every admission gate is satisfied:

```text
moon build --target native --release src/cmd
bun fuzz compare-pass --pass dealign --count 10000 --seed 0x5eed \
  --gen-valid-profile <dealign-memarg-profile> \
  --out-dir .tmp/pass-fuzz-dealign --jobs auto \
  --starshine-bin _build/native/release/build/cmd/cmd.exe \
  --min-compared <meaningful-threshold>
```

### Admission gates

1. **Harness:** verify the direct Binaryen `--dealign` mapping and expose it through `--list-passes`.
2. **Starshine:** retain focused tests for the active owner and dispatcher.
3. **Reachability:** add memory-bearing fixtures or a profile that reaches scalar `load` / `store` and source-confirmed `SIMDLoad` nodes with non-`1` alignments.
4. **Correctness:** set a nonzero `--min-compared` threshold and cover default, `align=1`, and larger explicit alignments while proving that offsets, widths, children, result types, and atomic/bulk-memory non-goals remain intact.

Direct Binaryen before/after fixtures are useful source-oracle preparation while these gates are unmet. They are not a substitute for a Starshine compare-pass lane.
