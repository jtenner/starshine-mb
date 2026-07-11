---
kind: workflow
status: working
last_reviewed: 2026-07-11
sources:
  - ../../../tooling/pass-fuzz-compare.md
  - ../../../../../scripts/lib/pass-fuzz-compare-task.ts
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/remove_unused_names_test.mbt
related:
  - ./index.md
  - ./starshine-hot-ir-strategy.md
  - ../../../tooling/pass-fuzz-compare.md
---

# `remove-unused-names` fuzzing profile

## Current runnable lane

`remove-unused-names` is active in both the Starshine registry and the compare-pass harness. Use the repository wrapper and an explicitly fresh native binary:

```text
moon build --target native --release src/cmd
bun fuzz compare-pass --pass remove-unused-names --count 10000 --seed 0x5eed \
  --out-dir .tmp/pass-fuzz-remove-unused-names --jobs auto \
  --starshine-bin _build/native/release/build/cmd/cmd.exe
```

The direct lane validates generated inputs and compares normalized output with Binaryen. It is pass-targeted evidence, not proof that the three repeated preset placements compose correctly with every surrounding cleanup pass.

## Coverage boundaries

No dedicated GenValid profile is documented today. Ordinary generated modules are useful broad coverage, but the focused MoonBit suite remains necessary for the local structural families that a random module may miss:

- same-typed block-chain peeling and target retagging;
- dead-label loop demotion versus live continue targets;
- `br_if`, `br_table`, `try_table`, and delegate label-use handling;
- preservation of non-label name metadata and removal of stale label-name maps; and
- repeated `remove-unused-names -> remove-unused-brs -> remove-unused-names` scheduling.

See [`../../../../../src/passes/remove_unused_names_test.mbt`](../../../../../src/passes/remove_unused_names_test.mbt) and [`starshine-hot-ir-strategy.md`](starshine-hot-ir-strategy.md) for those exact local contracts.

## Future profile rule

If a future audit adds a pass-specific GenValid profile, record its name, intended smoke/closeout count, required `--require-feature` floors or `--normalize` flags, and replay-manifest expectations here. Do not replace the focused label/metadata fixtures with a profile name alone.
