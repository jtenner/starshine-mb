---
kind: workflow
status: working
last_reviewed: 2026-07-11
sources:
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../scripts/lib/pass-fuzz-compare-task.ts
  - ../../../tooling/pass-fuzz-compare.md
  - ./index.md
  - ./starshine-port-readiness-and-validation.md
related:
  - ./index.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
  - ../../../tooling/pass-fuzz-compare.md
---

# `reorder-functions` fuzzing status

## Current status: planned only

Do **not** run or advertise a Starshine-vs-Binaryen `compare-pass` lane for `reorder-functions` or `reorder-functions-by-name` today.

- [`src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt) keeps both shipped names in `pass_registry_boundary_only_names()`. Starshine recognizes them but rejects an explicit execution request; it has no active module pass.
- [`scripts/lib/pass-fuzz-compare-task.ts`](../../../../../scripts/lib/pass-fuzz-compare-task.ts) has neither spelling in `SUPPORTED_PASS_FLAGS`. The harness rejects either `--pass` argument before it generates input or invokes an optimizer.
- The separate open upstream proposal `reorder-functions-by-similarity` is absent from both current Binaryen and Starshine registries. It is not an alias and cannot have a local parity lane; see [`compression-oriented-similarity-proposal.md`](compression-oriented-similarity-proposal.md).

A rejected command, or a command that compares zero meaningful cases, is a **status check**, not Binaryen-parity evidence. The previous copied 10,000-case command was invalid for the current repository and is superseded by this page.

## Safe discovery command

Use the harness roster only to inspect supported active pass names:

```text
bun fuzz compare-pass --list-passes
```

This does not establish semantic parity.

## Admission gates for a future lane

Create a runnable lane only after all of these are true:

1. Starshine has an active, behavior-tested module implementation and public registry entry.
2. `SUPPORTED_PASS_FLAGS` accepts the exact canonical local spelling.
3. Fixtures cover the future total function-index permutation: import prefix, `func_sec` / `code_sec` pairing, direct and tail calls, `ref.func` remapping, start, exports, element segments, initializer expressions, names, and annotations.
4. Binaryen oracle evidence fixes the intended contract: shipped direct-call/start/export/element scoring with descending-name ties for `reorder-functions`, or a separately landed and source-captured contract for any future similarity pass.

Only then prepare a native binary and use the documented signoff shape:

```text
moon build --target native --release src/cmd
bun fuzz compare-pass --count 10000 --seed 0x5eed --pass <active-canonical-name> --out-dir .tmp/pass-fuzz-<active-canonical-name> --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe
```

Use a documented dedicated GenValid profile if one exists at that time. A declaration-order pass should also get targeted non-random fixtures because a binary/text diff alone can hide an incorrect `FuncIdx` remap.

## Related pages

- [`index.md`](index.md) — shipped Binaryen contract and current Starshine boundary-only status.
- [`starshine-strategy.md`](starshine-strategy.md) — required module-wide permutation/remap surface.
- [`starshine-port-readiness-and-validation.md`](starshine-port-readiness-and-validation.md) — future validation ladder.
- [`compression-oriented-similarity-proposal.md`](compression-oriented-similarity-proposal.md) — open upstream proposal boundary.
