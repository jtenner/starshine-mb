---
kind: workflow
status: planned
last_reviewed: 2026-07-11
sources:
  - ../../../raw/fuzzing/2026-07-11-pass-fuzz-admission-boundary-audit.md
  - ../../../tooling/pass-fuzz-compare.md
  - ../../../../../scripts/lib/pass-fuzz-compare-task.ts
  - ../../../../../src/passes/optimize.mbt
related:
  - ./index.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
  - ../monomorphize-always/index.md
  - ../../../tooling/pass-fuzz-compare.md
---

# `monomorphize` fuzzing status

## Current status: planned only

Do **not** run or advertise `bun fuzz compare-pass --pass monomorphize ...` as a current smoke lane.

- `SUPPORTED_PASS_FLAGS` in [`scripts/lib/pass-fuzz-compare-task.ts`](../../../../../scripts/lib/pass-fuzz-compare-task.ts) does not include `monomorphize` or `monomorphize-always`; parsing therefore stops before a comparison begins.
- [`src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt) deliberately tracks both names as **boundary-only**, so an admitted request would still not run a local cloning transform.
- The parsed `--monomorphize-min-benefit` option is not evidence that the pass exists; implementation, registry, dispatcher, and harness admission are separate requirements.
- A rejected command or zero compared cases proves only current status. It cannot establish parity with Binaryen's call-context builder, clone construction, or usefulness gate.

Use this harmless discovery command only to inspect admitted names:

```text
bun fuzz compare-pass --list-passes
```

## Future executable lane

A future lane must explicitly choose the public `monomorphize` behavior versus testing-oriented `monomorphize-always`, then satisfy all four preflight gates from [`../../../tooling/pass-fuzz-compare.md`](../../../tooling/pass-fuzz-compare.md#pass-eligibility-preflight).

Directed corpus/profile requirements include:

- direct constant and refined-reference call contexts;
- effect-order and movable-context barriers;
- cloned-signature, parameter-to-local, local-index, and name repair;
- dropped-result and return-call boundaries;
- recursive/imported/indirect-call bailouts; and
- usefulness-threshold retain/reject cases, separately from the `-always` variant.

Only after those shapes are executable in Starshine and comparable to the right Binaryen public flag should a lane resemble:

```text
moon build --target native --release src/cmd
bun fuzz compare-pass --pass monomorphize --count 10000 --seed 0x5eed \
  --gen-valid-profile <call-context-specialization-profile> \
  --out-dir .tmp/pass-fuzz-monomorphize --jobs auto \
  --starshine-bin _build/native/release/build/cmd/cmd.exe \
  --min-compared <meaningful-threshold>
```

The command is a **future template**, not current parity guidance.
