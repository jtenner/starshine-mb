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
  - ../../../tooling/pass-fuzz-compare.md
---

# `minify-imports` Fuzzing Status

## Current status: planned only

Do **not** run or advertise a Starshine-vs-Binaryen `compare-pass` smoke lane for `minify-imports` today.

- Starshine has no active, boundary-only, or removed registry entry for `minify-imports` in [`src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt). An explicit request reaches the unknown-pass error path instead of a transform.
- [`scripts/lib/pass-fuzz-compare-task.ts`](../../../../../scripts/lib/pass-fuzz-compare-task.ts) does not include `--minify-imports` in `SUPPORTED_PASS_FLAGS`. The harness rejects the argument before generating a module or invoking either optimizer.
- A rejected command, command failure, or zero compared cases is a **status check**, not Binaryen-parity evidence. Apply the four admission gates in [`../../../tooling/pass-fuzz-compare.md`](../../../tooling/pass-fuzz-compare.md#pass-eligibility-preflight).

Use this harmless discovery command only to inspect the current harness roster:

```text
bun fuzz compare-pass --list-passes
```

`minify-imports` must remain absent until Starshine deliberately implements and admits the ABI-visible module pass.

## Why ordinary GenValid is insufficient by itself

The upstream pass rewrites only qualifying `env` / `wasi_` import **base names**, emits a JSON map on a separate output channel, and must leave custom-module import bases, export names, import module names, entity kinds, and indices unchanged. Generic modules commonly have no imports, while a green output comparison would not by itself check stdout map parity.

Before a runnable lane exists, focused fixtures must cover at least:

- `env` and `wasi_` function, table, memory, global, and tag import positives where the local representation supports the fixture;
- a `host`-module negative that preserves its base name;
- preservation of export names and import module names in plain mode;
- repeated old base names from different modules, generated-name collisions, and deterministic traversal;
- binary/WAT round trips and rebuilt import lookup maps after declaration mutation; and
- JSON rows containing old module, old base, and new base, captured separately from wasm/WAT output.

See [`./wat-shapes.md`](./wat-shapes.md) for module shapes and [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md) for implementation order.

## Future runnable template

Enable a comparison lane only after all of the following are true:

1. an active Starshine module pass performs the documented plain `env` / `wasi_` import-base rewrite and exposes a testable JSON-map output channel;
2. the registry admits `minify-imports` rather than taking the unknown-pass path;
3. `SUPPORTED_PASS_FLAGS` admits `--minify-imports` and `bun fuzz compare-pass --list-passes` reports it; and
4. an import-bearing generator profile or fixture corpus produces meaningful comparable cases with an explicit `--min-compared` threshold, while a companion assertion checks the JSON map.

Candidate command shape once those gates are satisfied:

```text
moon build --target native --release src/cmd
bun fuzz compare-pass --pass minify-imports --count 10000 --seed 0x5eed \
  --out-dir .tmp/pass-fuzz-minify-imports --jobs auto \
  --starshine-bin _build/native/release/build/cmd/cmd.exe \
  --min-compared <meaningful-count>
```

This is a **future template**, not current signoff guidance. Record the eventual import-bearing profile or corpus, feature floors, JSON-map assertion mechanism, normalizers (normally none for ABI names), and replay-artifact contract before relying on it.
