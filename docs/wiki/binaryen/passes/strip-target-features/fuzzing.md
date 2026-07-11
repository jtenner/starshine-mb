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
  - ./starshine-port-readiness-and-validation.md
  - ../../../tooling/pass-fuzz-compare.md
---

# `strip-target-features` fuzzing status

## Current status: planned only

Do **not** run or advertise a Starshine-vs-Binaryen `compare-pass` lane for `strip-target-features` today.

- [`src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt) contains neither sibling name in its active, boundary-only, or removed registry lists, so Starshine rejects an explicit request as unknown.
- [`scripts/lib/pass-fuzz-compare-task.ts`](../../../../../scripts/lib/pass-fuzz-compare-task.ts) does not include `--strip-target-features` or `--emit-target-features` in `SUPPORTED_PASS_FLAGS`, so the harness rejects either spelling before generating input or invoking an optimizer.
- A rejected command—or a future command with no meaningful comparisons—is a **status check**, not Binaryen-parity evidence. Follow the four admission gates in [`../../../tooling/pass-fuzz-compare.md`](../../../tooling/pass-fuzz-compare.md#pass-eligibility-preflight).

Use this harmless command only to inspect the current harness roster:

```text
bun fuzz compare-pass --list-passes
```

## Why ordinary generated modules are not enough

This pass changes non-executing output metadata rather than instructions. A useful future oracle corpus must deliberately preserve the distinction between target-feature metadata and executable semantics:

- `target_features` present versus already absent;
- one or more unrelated opaque custom sections, especially `producers`;
- a structured name section; and
- feature-using executable content whose code and validation result do not change when metadata is removed.

Therefore, a generic GenValid-only lane is insufficient unless the generator or fixture adapter can deliberately attach the needed custom-section shapes. See [`./wat-shapes.md`](./wat-shapes.md) and [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md).

## Future runnable template

Enable a comparison lane only after all of the following are true:

1. Starshine has an active module/output-metadata pass with a documented representation policy for `target_features`;
2. `strip-target-features` is admitted by the active registry, and `emit-target-features` has an explicit sibling status;
3. `SUPPORTED_PASS_FLAGS` admits the active spelling and `bun fuzz compare-pass --list-passes` reports it; and
4. a fixture corpus or generator profile creates target-feature, unrelated-custom-section, and feature-use cases with an explicit `--min-compared` threshold.

Candidate command shape once those gates are satisfied:

```text
moon build --target native --release src/cmd
bun fuzz compare-pass --pass strip-target-features --count 10000 --seed 0x5eed \
  --out-dir .tmp/pass-fuzz-strip-target-features --jobs auto \
  --starshine-bin _build/native/release/build/cmd/cmd.exe \
  --min-compared <meaningful-count>
```

This is a **future template**, not current signoff guidance. Record the eventual fixture/profile, exact metadata representation, normalizers, and replay-artifact contract here before using it as parity evidence.
