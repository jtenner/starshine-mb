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

# `signature-pruning` Fuzzing Status

## Current status: planned only

Do **not** run or advertise a Starshine-vs-Binaryen `compare-pass` smoke lane for `signature-pruning` today.

- [`src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt) keeps the name in `pass_registry_boundary_only_names()`. Starshine rejects an explicit request; it has no active module or HOT implementation.
- [`scripts/lib/pass-fuzz-compare-task.ts`](../../../../../scripts/lib/pass-fuzz-compare-task.ts) does not include `--signature-pruning` in `SUPPORTED_PASS_FLAGS`. The harness rejects the argument before generating input or invoking either optimizer.
- Therefore, a rejected command—or a future command that compares zero useful cases—is a **status check**, not Binaryen-parity evidence. Follow the four admission gates in [`../../../tooling/pass-fuzz-compare.md`](../../../tooling/pass-fuzz-compare.md#pass-eligibility-preflight).

Use this harmless discovery command only to inspect the harness roster:

```text
bun fuzz compare-pass --list-passes
```

`signature-pruning` must remain absent until Starshine deliberately implements and admits a closed-world module transform.

## Why ordinary GenValid is insufficient by itself

The upstream pass is GC- and closed-world-gated, returns unchanged when a table exists, and rewrites nominal function heap types along with direct `call` and `call_ref` users. An ordinary random module lane will not prove those prerequisites or the crucial type-rewrite properties.

Before a runnable lane exists, focused fixtures must cover at least:

- no-GC, open-world, and any-table no-op/rejection policy;
- private versus imported/public/tag/continuation/JS-called/subtyped heap-type blockers;
- shared-heap-type siblings where one live parameter blocks the whole family;
- direct calls, then library/binary `call_ref` and `return_call_ref` cases until ordinary `call_ref` WAST text is supported;
- constant-actual promotion, effectful-actual localization, and the single extra iteration;
- distinct nominal heap types that converge to the same textual function shape but must remain distinct; and
- validator and binary round-trip checks after parameter, call-operand, and type-section rewrites.

See [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md) for the implementation order and [`./wat-shapes.md`](./wat-shapes.md) for concrete before/after shapes.

## Future runnable template

Enable a comparison lane only after all of the following are true:

1. an active Starshine module pass implements the closed-world heap-type rewrite, including functions, direct calls, callee locals, and its documented `call_ref` coverage;
2. the registry no longer classifies the pass as boundary-only;
3. `SUPPORTED_PASS_FLAGS` admits `--signature-pruning` and `bun fuzz compare-pass --list-passes` reports it; and
4. a focused GC/closed-world generator profile or fixture corpus produces meaningful comparable cases with an explicit `--min-compared` threshold.

Candidate command shape once those gates are satisfied:

```text
moon build --target native --release src/cmd
bun fuzz compare-pass --pass signature-pruning --count 10000 --seed 0x5eed \
  --out-dir .tmp/pass-fuzz-signature-pruning --jobs auto \
  --starshine-bin _build/native/release/build/cmd/cmd.exe \
  --min-compared <meaningful-count>
```

This is a **future template**, not current signoff guidance. Record the eventual generator/profile, required feature floors, normalizers, fixture corpus, and replay-artifact contract here before relying on it.
