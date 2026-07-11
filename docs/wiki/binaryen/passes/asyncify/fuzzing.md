---
kind: workflow
status: working
last_reviewed: 2026-07-11
sources:
  - ../../../tooling/pass-fuzz-compare.md
  - ../../../../../scripts/lib/pass-fuzz-compare-task.ts
  - ../../../../../src/passes/optimize.mbt
  - ./host-runtime-contract-and-reentrancy.md
related:
  - ./index.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
  - ./host-runtime-contract-and-reentrancy.md
  - ../../../tooling/pass-fuzz-compare.md
---

# `asyncify` fuzzing status

## Current status: planned only

Do **not** run or advertise a Starshine-vs-Binaryen `compare-pass` smoke lane for `asyncify` today.

- [`scripts/lib/pass-fuzz-compare-task.ts`](../../../../../scripts/lib/pass-fuzz-compare-task.ts) does not include `--asyncify` in `SUPPORTED_PASS_FLAGS`; the harness rejects the flag during argument parsing, before it generates an input or runs either optimizer.
- Starshine has no `asyncify` entry in active, boundary-only, or removed registry lists in [`src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt), so there is no local transform or dispatcher route to compare.
- That rejection is a **status check**, not a failed smoke lane or Binaryen-parity evidence. A command that compared zero cases would not be evidence either; apply the four gates in [`../../../tooling/pass-fuzz-compare.md`](../../../tooling/pass-fuzz-compare.md#pass-eligibility-preflight).

Use this harmless discovery command only to inspect the current harness roster:

```text
bun fuzz compare-pass --list-passes
```

`asyncify` should remain absent until Starshine deliberately implements and admits it.

## What a future lane must prove

A runnable lane requires all four general preflight gates plus Asyncify-specific evidence:

1. **Harness admission:** `SUPPORTED_PASS_FLAGS` admits `--asyncify` and `--list-passes` reports it.
2. **Starshine admission:** an active module pass accepts the spelling and runs a source-defined subset, rather than returning an unknown/boundary-only error.
3. **Oracle and input admission:** the spelling maps to Binaryen's public `--asyncify` flag, and fixtures/profile inputs contain configured async roots, direct and indirect call paths, and live locals that can make the pass act.
4. **Runtime admission:** static canonical output comparison is supplemented by a host-driven unwind/rewind execution test. That test must state whether nested/reentrant entry is rejected or supported; see [`host-runtime-contract-and-reentrancy.md`](host-runtime-contract-and-reentrancy.md).

A generic random GenValid lane alone is insufficient for the last gate: it does not establish a cooperating async host protocol merely by producing valid Core Wasm modules.

## Future command template

Only after those gates and direct fixtures are green may a native comparison lane resemble:

```text
moon build --target native --release src/cmd
bun fuzz compare-pass --pass asyncify --count 10000 --seed 0x5eed \
  --gen-valid-profile <asyncify-capable-profile> \
  --out-dir .tmp/pass-fuzz-asyncify --jobs auto \
  --starshine-bin _build/native/release/build/cmd/cmd.exe \
  --min-compared <meaningful-count>
```

This is a **future template**, not current execution guidance. Before using it for signoff, add fixture-backed positives and negatives for: one direct async import, a transitive caller, an unchanged non-async function, conservative and ignored indirect-call policies, one saved scalar local, no-memory synthesis, memory64 pointer width, the chosen EH/catch policy, tail-call rejection, and host-driven unwind/rewind with the chosen nested-entry policy.
