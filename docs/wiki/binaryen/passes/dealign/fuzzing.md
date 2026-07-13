---
kind: workflow
status: planned
last_reviewed: 2026-07-11
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

## Current status: planned-only

Do **not** run or advertise a Starshine-vs-Binaryen `compare-pass` smoke lane for `dealign` today.

- `--dealign` is absent from `SUPPORTED_PASS_FLAGS` in [`scripts/lib/pass-fuzz-compare-task.ts`](../../../../../scripts/lib/pass-fuzz-compare-task.ts), so the harness rejects the request before it generates a module or invokes either optimizer.
- `dealign` is absent from Starshine's active, boundary-only, and removed registry lists in [`src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt). An explicit request therefore reaches the unknown-pass path; it does not execute a transform.
- Thus a parser rejection, unknown-pass error, or zero compared cases cannot be presented as Binaryen-parity evidence.

The upstream `align=1` rewrite contract is retained in [`./binaryen-strategy.md`](./binaryen-strategy.md) and the port-readiness digest [`../../../raw/research/0389-2026-04-26-dealign-port-readiness.md`](../../../raw/research/0389-2026-04-26-dealign-port-readiness.md). This page corrects only the local lane-admission claim.

## Safe inspection now

```text
bun fuzz compare-pass --list-passes
```

This inspects the current harness roster only. It neither runs `dealign` nor proves parity.

## Future runnable-lane template

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

1. **Harness:** add `--dealign` to `SUPPORTED_PASS_FLAGS`, verify the direct Binaryen `--dealign` mapping, and expose it through `--list-passes`.
2. **Starshine:** choose an honest registry status, then add an active owner/dispatcher and focused tests; unknown-pass behavior is not a transform.
3. **Reachability:** add memory-bearing fixtures or a profile that reaches scalar `load` / `store` and source-confirmed `SIMDLoad` nodes with non-`1` alignments.
4. **Correctness:** set a nonzero `--min-compared` threshold and cover default, `align=1`, and larger explicit alignments while proving that offsets, widths, children, result types, and atomic/bulk-memory non-goals remain intact.

Direct Binaryen before/after fixtures are useful source-oracle preparation while these gates are unmet. They are not a substitute for a Starshine compare-pass lane.
