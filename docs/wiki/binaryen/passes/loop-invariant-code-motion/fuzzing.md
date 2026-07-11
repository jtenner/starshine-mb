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

# `loop-invariant-code-motion` / Binaryen `licm` Fuzzing Status

## Current state: planned, not runnable

Do **not** treat `bun fuzz compare-pass --pass loop-invariant-code-motion ...` as a current smoke lane.

- [`scripts/lib/pass-fuzz-compare-task.ts`](../../../../../scripts/lib/pass-fuzz-compare-task.ts) owns the accepted `--pass` names. `SUPPORTED_PASS_FLAGS` does **not** include `loop-invariant-code-motion` or Binaryen's public `licm`, so the harness rejects either spelling before generating or comparing a case.
- [`src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt) classifies `loop-invariant-code-motion` as **Removed**. An explicit local request intentionally rejects rather than dispatching a transform.
- A parser rejection, removed-pass diagnostic, or zero compared cases is a status check, **not** Binaryen-parity evidence. See [`./starshine-port-readiness-and-validation.md`](starshine-port-readiness-and-validation.md) for the still-open alias and implementation decisions.

Safe inspection only:

```text
bun fuzz compare-pass --list-passes
```

## Future executable lane

Publish a real comparison command only after all four admission gates hold:

1. Starshine replaces the removed entry with an active LICM implementation and focused loop-entry/effect/local-dependency tests.
2. The project chooses and documents its public spelling (`licm`, the local long name, or both).
3. The harness admits the chosen local spelling and maps it explicitly to Binaryen `--licm`.
4. A loop-aware profile or fixture corpus proves meaningful coverage of safe prefix motion and effect, trap, control-transfer, and local-set bailouts, with a nonzero `--min-compared` threshold.

Future-only command shape:

```text
moon build --target native --release src/cmd
bun fuzz compare-pass --pass <chosen-local-spelling> --count 10000 --seed 0x5eed \
  --gen-valid-profile <licm-loop-prefix-profile> \
  --out-dir .tmp/pass-fuzz-licm --jobs auto \
  --starshine-bin _build/native/release/build/cmd/cmd.exe \
  --min-compared <meaningful-threshold>
```

Until then, direct Binaryen `--licm` fixture runs are upstream-shape research, not a Starshine comparison lane. Any future mismatch still needs an explicit parity, validation, size, or performance judgment rather than a generic “valid output” label.
