---
kind: workflow
status: working
last_reviewed: 2026-07-11
sources:
  - ../../../tooling/pass-fuzz-compare.md
  - ../../../../../scripts/lib/pass-fuzz-compare-task.ts
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/pass_manager.mbt
related:
  - ./index.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
  - ../minify-imports/fuzzing.md
  - ../../../tooling/pass-fuzz-compare.md
---

# `minify-imports-and-exports` Fuzzing Status

## Current status: planned only

Do **not** run or advertise a Starshine-vs-Binaryen `compare-pass` smoke lane for `minify-imports-and-exports` today.

- Starshine has no active, boundary-only, or removed registry entry for this name (or its `-and-modules` sibling) in [`src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt). Explicit requests take the unknown-pass path instead of a transform.
- [`scripts/lib/pass-fuzz-compare-task.ts`](../../../../../scripts/lib/pass-fuzz-compare-task.ts) does not include `--minify-imports-and-exports` in `SUPPORTED_PASS_FLAGS`. The harness rejects the argument before it generates input or invokes either optimizer.
- Therefore a rejected command, command failure, or zero compared cases is a **status check**, not Binaryen-parity evidence. Apply the four admission gates in [`../../../tooling/pass-fuzz-compare.md`](../../../tooling/pass-fuzz-compare.md#pass-eligibility-preflight).

Use this harmless discovery command only to inspect the current harness roster:

```text
bun fuzz compare-pass --list-passes
```

The pass must remain absent until Starshine deliberately implements and admits the ABI-visible module transform.

## Why ordinary GenValid is insufficient by itself

This family changes import base names and export names; `minify-imports-and-exports-and-modules` additionally changes import module names. Generic modules commonly lack the necessary declarations, and normalized WAT equality alone would not exercise the JSON map emitted alongside the transformed module.

Before a runnable lane exists, focused fixtures must cover at least:

- qualifying `env` / `wasi_` import-base positives plus export-name positives for functions, tables, memories, globals, and tags where locally representable;
- custom-module import negatives under this pass, then positives only for the `-and-modules` sibling;
- preservation of all `ExternType`, `ExternIdx`, internal index-space, function-body, and type-section facts;
- deterministic generated-name order, collisions, repeated names, and map-row order;
- separate import-map `[oldModule, oldBase, newBase]` and export-map `[oldExport, newExport]` assertions; and
- binary/WAT round trips plus an explicit host-linking test or policy note, because changing names is ABI-visible.

See [`./wat-shapes.md`](./wat-shapes.md), [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md), and the narrower sibling's [`../minify-imports/fuzzing.md`](../minify-imports/fuzzing.md).

## Future runnable template

Enable a comparison lane only after all of the following are true:

1. an active Starshine module pass implements import-base/export-name rewriting and its documented JSON-map channel;
2. the registry admits the public spelling rather than taking the unknown-pass path;
3. `SUPPORTED_PASS_FLAGS` admits `--minify-imports-and-exports` and `bun fuzz compare-pass --list-passes` reports it; and
4. an import/export-bearing generator profile or fixture corpus produces meaningful comparable cases with an explicit `--min-compared` threshold and companion map assertions.

Candidate command shape once those gates are satisfied:

```text
moon build --target native --release src/cmd
bun fuzz compare-pass --pass minify-imports-and-exports --count 10000 --seed 0x5eed \
  --out-dir .tmp/pass-fuzz-minify-imports-and-exports --jobs auto \
  --starshine-bin _build/native/release/build/cmd/cmd.exe \
  --min-compared <meaningful-count>
```

This is a **future template**, not current signoff guidance. Document the eventual profile or corpus, exact JSON-map assertion mechanism, `-and-modules` sibling coverage, and replay-artifact contract before treating a run as parity evidence.
