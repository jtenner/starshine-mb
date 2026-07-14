---
kind: workflow
status: planned
last_reviewed: 2026-07-11
sources:
  - https://github.com/WebAssembly/binaryen/blob/main/src/passes/TypeMerging.cpp
  - ../../../tooling/pass-fuzz-compare.md
  - ../../../../../scripts/lib/pass-fuzz-compare-task.ts
  - ../../../../../src/passes/optimize.mbt
  - ../../../tooling/pass-fuzz-compare.md
  - ../../../../../scripts/lib/pass-fuzz-compare-task.ts
  - ../../../../../src/passes/optimize.mbt
related:
  - ./index.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
  - ../../../tooling/pass-fuzz-compare.md
---

# `type-merging` fuzzing status

## Current status: planned only

Do **not** run or advertise `bun fuzz compare-pass --pass type-merging ...` as a Starshine-vs-Binaryen smoke lane today.

- [`scripts/lib/pass-fuzz-compare-task.ts`](../../../../../scripts/lib/pass-fuzz-compare-task.ts) does not admit `type-merging` in `SUPPORTED_PASS_FLAGS`, so parsing stops before an input is generated or either optimizer runs.
- [`src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt) retains the name as **boundary-only**. If the harness admitted it, current Starshine would still reject the request instead of executing a transform.
- The current Binaryen pass is real, but upstream registration is not Starshine/harness admission; see the local pass-eligibility preflight and harness/registry sources cited above.
- A parser rejection, boundary-only error, or zero compared cases is status evidence only—not parity evidence.

Use this command only to inspect the harness roster:

```text
bun fuzz compare-pass --list-passes
```

## Future executable lane

A future lane needs all four compare-pass preflight gates plus a directed GC type-graph corpus with an explicit non-open-world policy. Generic valid modules do not prove this module-wide transform; the current Binaryen owner threads `worldMode` through admission, candidate selection, and rewriting.

Minimum fixtures/profile coverage:

- GC plus every supported world-mode gate, including an Open-world rejection case;
- private versus exported/public heap types;
- supertype and sibling merge positives;
- ordinary and exact cast, `ref.test`, `br_on_cast*`, and `call_indirect` blockers;
- recursive groups and descriptor chains; and
- post-rewrite type-use repair and validation.

Only after Starshine has an active implementation, the harness maps the public Binaryen flag, and the generator can create those cases should a command resemble:

```text
moon build --target native --release src/cmd
bun fuzz compare-pass --pass type-merging --count 10000 --seed 0x5eed \
  --gen-valid-profile <non-open-world-gc-type-graph-profile> \
  --out-dir .tmp/pass-fuzz-type-merging --jobs auto \
  --starshine-bin _build/native/release/build/cmd/cmd.exe \
  --min-compared <meaningful-threshold>
```

This is a **future template**, not current signoff guidance. Classify later differences using source-backed type-graph and validation evidence, not output validity alone.
