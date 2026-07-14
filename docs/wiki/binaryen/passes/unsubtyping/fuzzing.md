---
kind: workflow
status: working
last_reviewed: 2026-07-11
sources:
  - https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/unsubtyping-open-world.wast
  - ../../../tooling/pass-fuzz-compare.md
  - ../../../../../scripts/lib/pass-fuzz-compare-task.ts
  - ../../../../../src/passes/optimize.mbt
---

# `unsubtyping` Fuzzing Status

## Current status: planned only

Do **not** run or advertise a Starshine-vs-Binaryen `compare-pass` smoke lane for `unsubtyping` today.

- [`scripts/lib/pass-fuzz-compare-task.ts`](../../../../../scripts/lib/pass-fuzz-compare-task.ts) does not include `--unsubtyping` in `SUPPORTED_PASS_FLAGS`. The harness rejects the argument before it generates or compares a case.
- [`src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt) keeps `unsubtyping` in `pass_registry_boundary_only_names()`, so an otherwise-admitted direct request still ends in the intentional boundary-only error rather than a transform.
- A parser rejection, a Starshine command failure, or zero compared cases is **not** Binaryen-parity evidence. The current verifiable state is the registry/status contract in [`./starshine-strategy.md`](./starshine-strategy.md), not a 10,000-case oracle lane.

Use this harmless discovery command only to inspect the admitted roster:

```text
bun fuzz compare-pass --list-passes
```

The 2026-07-11 upstream recheck also matters for future fixtures: current Binaryen permits explicit open-world invocation but freezes the mode-selected public heap-type surface. A future lane must not incorrectly encode the obsolete `version_130` rule that all open-world requests fail.

## Future runnable template

Enable a comparison lane only after all of these conditions hold:

1. Starshine promotes the pass from `BoundaryOnly` to an active module/type-graph dispatcher entry with focused rewrite fixtures.
2. `SUPPORTED_PASS_FLAGS` admits `--unsubtyping`; `bun fuzz compare-pass --list-passes` then reports it.
3. Focused GC fixtures cover both open-world public-type freeze cases and the closed-world scheduling context, plus casts, descriptors, JS-boundary flow, and trap-preserving descriptor allocation repair.
4. A documented generator/profile produces meaningful comparable cases with an explicit `--min-compared` threshold, feature floors, and normalizer policy.

Candidate command shape once those gates are satisfied:

```text
moon build --target native --release src/cmd
bun fuzz compare-pass --pass unsubtyping --count 10000 --seed 0x5eed \
  --out-dir .tmp/pass-fuzz-unsubtyping --jobs auto \
  --starshine-bin _build/native/release/build/cmd/cmd.exe \
  --min-compared <meaningful-count>
```

This is a **future template**, not current signoff guidance. Record the eventual world-mode fixture policy, generator/profile, required feature facts, normalizers, and replay-artifact contract here before relying on it.
