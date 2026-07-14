---
kind: workflow
status: working
last_reviewed: 2026-07-11
sources:
  - https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/pass.cpp
  - ../../../tooling/pass-fuzz-compare.md
  - ../../../../../scripts/lib/pass-fuzz-compare-task.ts
  - ../../../../../src/passes/optimize.mbt
related:
  - ./index.md
  - ./plain-vs-optimizing-and-safety.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
  - ../../../tooling/pass-fuzz-compare.md
---

# `simplify-globals` Fuzzing Status

## Current status: planned only

Do **not** run or advertise a Starshine-vs-Binaryen `compare-pass` lane for `simplify-globals` today.

- Current Binaryen `main` still registers the plain pass separately from `simplify-globals-optimizing`, but Starshine intentionally keeps the plain name in `pass_registry_boundary_only_names()` in [`src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt).
- The harness allowlist in [`scripts/lib/pass-fuzz-compare-task.ts`](../../../../../scripts/lib/pass-fuzz-compare-task.ts) has no `--simplify-globals` entry. It rejects the request before generation, Starshine dispatch, or Binaryen execution.
- A rejected command, zero compared modules, or a requested count of 10,000 is therefore **admission status**, not a Binaryen-parity result.

Binaryen current-main [`pass.cpp`](https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/pass.cpp) plus the cited local registry and harness sources establish this admission boundary. Use only this harmless roster check while the pass remains unadmitted:

```text
bun fuzz compare-pass --list-passes
```

## Why a generic profile would be misleading

Plain `simplify-globals` is a whole-module global-analysis pass. A useful future lane must deliberately create global initializer dependencies, imported/exported visibility, reads and writes across function bodies, active data/element offsets, and the split between startup propagation and runtime trace propagation. It must also distinguish the plain stop point from `simplify-globals-optimizing`'s nested function-cleanup rerun; see [`plain-vs-optimizing-and-safety.md`](plain-vs-optimizing-and-safety.md).

A default portable batch with no eligible global facts cannot show whether the pass is correct. A green no-op run is not a substitute for the pass's `drop(value)` preservation, type-repair, or global-ordering obligations.

## Future lane template

Publish a runnable lane only after all four eligibility gates in [`../../../tooling/pass-fuzz-compare.md#pass-eligibility-preflight`](../../../tooling/pass-fuzz-compare.md#pass-eligibility-preflight) pass and reduced fixtures cover:

- practical-immutability and imported/exported/global-root boundaries;
- one-time initializer folding plus active data/element offset updates;
- dead and same-as-init `global.set` removal that preserves evaluated values with `drop`;
- `read-only-to-write` positives and actual-node/effect/control bailouts;
- runtime-trace propagation barriers and refined-reference/type-repair cases; and
- proof that plain mode stops before the optimizing sibling's nested cleanup.

```text
moon build --target native --release src/cmd
bun fuzz compare-pass --pass simplify-globals --count 10000 --seed 0x5eed \
  --out-dir .tmp/pass-fuzz-simplify-globals --jobs auto \
  --starshine-bin _build/native/release/build/cmd/cmd.exe \
  --gen-valid-profile <future-global-rewrite-profile> \
  --min-compared <meaningful-global-case-count>
```

This is a future template, not current signoff guidance. Keep focused rewrite and validation fixtures as the primary evidence until the active module pass and generator profile exist.
