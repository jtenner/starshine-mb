---
kind: workflow
status: planned
last_reviewed: 2026-07-11
sources:
  - https://github.com/WebAssembly/binaryen/blob/main/src/passes/RemoveUnusedTypes.cpp
  - ../../../tooling/pass-fuzz-compare.md
  - ../../../../../scripts/lib/pass-fuzz-compare-task.ts
  - ../../../../../src/passes/optimize.mbt
related:
  - ./index.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
  - ../../tooling/pass-fuzz-compare.md
---

# `remove-unused-types` Fuzzing Profile

## Current status: planned-only

Do **not** run or advertise this as a runnable `compare-pass` lane today.

`remove-unused-types` is absent from the harness `SUPPORTED_PASS_FLAGS` allowlist in [`scripts/lib/pass-fuzz-compare-task.ts`](../../../../../scripts/lib/pass-fuzz-compare-task.ts), so `bun fuzz compare-pass --pass remove-unused-types ...` is rejected during argument parsing. It is also a boundary-only registry name in [`src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt), not an active Starshine transform. A 10,000-case command that stops at either gate is not Binaryen-parity evidence.

The upstream owner is linked in the page metadata; the local registry and harness sources cited above establish the admission boundary.

## Safe inspection now

```sh
bun fuzz compare-pass --list-passes
```

This only verifies current harness admission. It is not a run of this pass and it supplies no oracle evidence.

## Future runnable-lane template

Use this only after all four gates below are true:

```sh
moon build --target native --release src/cmd
bun fuzz compare-pass \
  --count 10000 --seed 0x5eed --pass remove-unused-types \
  --out-dir .tmp/pass-fuzz-remove-unused-types --jobs auto \
  --starshine-bin _build/native/release/build/cmd/cmd.exe \
  --min-compared <meaningful-threshold>
```

### Admission gates

1. **Harness:** add the canonical spelling to `SUPPORTED_PASS_FLAGS` and test its Binaryen flag mapping.
2. **Starshine:** replace the boundary-only entry with an active module-pass dispatcher and focused tests; an owner file must exist.
3. **Oracle:** confirm the exact Binaryen invocation and world-mode requirements on targeted fixtures. The current-main helper interface needs a separate world-mode semantic review before this page claims a final open-world policy.
4. **Reachability:** add a GC/rec-group-aware input profile or fixtures that actually reach private/public heap-type rebuilding, and set a nonzero `--min-compared` threshold.

Before a general generator lane exists, use targeted upstream preparation fixtures with `wasm-opt --closed-world --remove-unused-types` as described in [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md). Those fixtures test Binaryen's transform shape; they do not make the absent Starshine pass comparable.

## Future coverage priorities

A real lane should include private singleton deletion, unused member removal from an old rec group, used private dependency retention, public-anchor retention, private subtype/public-supertype shapes, descriptor/described dependencies, and full module type-use remapping. Every output must validate before normalized comparison.
