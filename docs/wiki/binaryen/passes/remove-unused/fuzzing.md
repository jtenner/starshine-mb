---
kind: workflow
status: planned
last_reviewed: 2026-07-11
sources:
  - https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp
  - ../../../tooling/pass-fuzz-compare.md
  - ../../../../../scripts/lib/pass-fuzz-compare-task.ts
  - ../../../../../src/passes/optimize.mbt
related:
  - ./index.md
  - ./historical-lineage-and-modern-supersession.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
  - ../remove-unused-module-elements/index.md
  - ../../../tooling/pass-fuzz-compare.md
---

# `remove-unused` fuzzing status

## Current state: planned, not runnable

Do **not** run or advertise `bun fuzz compare-pass --pass remove-unused ...` as a current parity lane.

- [`scripts/lib/pass-fuzz-compare-task.ts`](../../../../../scripts/lib/pass-fuzz-compare-task.ts) does not admit `--remove-unused` in `SUPPORTED_PASS_FLAGS`, so the harness rejects the request before generation, Binaryen, or Starshine runs.
- [`src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt) keeps `remove-unused` as a **boundary-only** registry name. The active module passes are the differently scoped [`remove-unused-module-elements`](../remove-unused-module-elements/index.md) and `remove-unused-nonfunction-module-elements` siblings.
- A rejected request, zero compared cases, or a nominal 10,000-case command establishes only **admission status**. It is not evidence of historical `remove-unused-functions` behavior, modern RUME parity, output validity, or performance.

Current-main Binaryen [`pass.cpp`](https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp) and its [CLI help fixture](https://github.com/WebAssembly/binaryen/blob/main/test/lit/help/wasm-opt.test) show the modern spelling boundary. It confirms that Binaryen current `main` does not revive the short spelling on the reviewed registration/help surfaces and that the local harness still rejects it.

Safe roster inspection only:

```text
bun fuzz compare-pass --list-passes
```

## Why an ordinary RUME lane is not a substitute

Historical upstream `remove-unused-functions` was a function-only direct-call reachability pass. Modern `remove-unused-module-elements` is broader: it can reason about and rewrite more declaration kinds. Running the active RUME lane therefore cannot prove parity for the historical alias, and silently treating it as an alias would hide a product/registry decision.

Use the active sibling's own workflow page when that is the intended pass: [`../remove-unused-module-elements/fuzzing.md`](../remove-unused-module-elements/fuzzing.md).

## Future executable lanes

Before publishing a real lane, choose one contract explicitly:

1. **Historical compatibility:** implement a new, unambiguous `remove-unused-functions`-style module pass and compare against the historical source horizon; or
2. **Starshine-only alias:** explicitly map `remove-unused` to modern RUME and prove the alias and canonical RUME spelling produce the same outputs.

Either choice needs all of these admission gates:

- an active local registry descriptor and dispatcher route;
- a harness mapping to the correct oracle (historical compatibility or intentional RUME alias);
- direct fixtures for start, exports, active element/table roots, direct-call closure, dead private helpers, and non-function no-change boundaries;
- module validation and function-index/name/metadata remap checks after deletion; and
- a meaningful `--min-compared` threshold plus measured mismatch and size classification.

Future-only template:

```text
moon build --target native --release src/cmd
bun fuzz compare-pass --pass <accepted-spelling> --count 10000 --seed 0x5eed \
  --gen-valid-profile <function-reachability-profile> \
  --out-dir .tmp/pass-fuzz-remove-unused --jobs auto \
  --starshine-bin _build/native/release/build/cmd/cmd.exe \
  --min-compared <meaningful-threshold>
```

Do not replace `<accepted-spelling>` with `remove-unused` until the local registry and harness gates above are intentionally implemented.
