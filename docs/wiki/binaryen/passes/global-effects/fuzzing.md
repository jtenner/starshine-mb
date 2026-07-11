---
kind: workflow
status: working
last_reviewed: 2026-07-11
sources:
  - ./index.md
  - ./metadata-naming-and-consumers.md
  - ./starshine-port-readiness-and-validation.md
  - ../../../tooling/pass-fuzz-compare.md
  - ../../../raw/binaryen/2026-05-06-global-effects-current-main-recheck.md
  - ../../../../../scripts/lib/pass-fuzz-compare-task.ts
  - ../../../../../src/passes/optimize.mbt
related:
  - ./index.md
  - ./metadata-naming-and-consumers.md
  - ./starshine-port-readiness-and-validation.md
  - ../discard-global-effects/index.md
  - ../vacuum/index.md
  - ../simplify-locals/index.md
  - ../../../tooling/pass-fuzz-compare.md
---

# `global-effects` fuzzing status

## Current status: planned only

Do **not** run or advertise a Starshine-vs-Binaryen `compare-pass` smoke lane for `global-effects` today.

- [`src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt) classifies `global-effects` as boundary-only, so the CLI spelling parses but pass expansion rejects it instead of running a transform.
- [`scripts/lib/pass-fuzz-compare-task.ts`](../../../../../scripts/lib/pass-fuzz-compare-task.ts) does not admit `--global-effects` in `SUPPORTED_PASS_FLAGS`; the harness rejects the argument before it generates input or runs either optimizer.
- Upstream publishes this pass as `generate-global-effects`. It produces persistent per-function `Function.effects` metadata, so its standalone Core Wasm text normally remains unchanged. A WAT-only match would not prove summary correctness.

The rejected command is a **status check**, not a smoke result or Binaryen-parity evidence. Follow the four gates in [`../../../tooling/pass-fuzz-compare.md`](../../../tooling/pass-fuzz-compare.md#pass-eligibility-preflight).

Use this harmless command only to inspect the current harness roster:

```text
bun fuzz compare-pass --list-passes
```

## What future signoff must observe

The producer's primary oracle is the summary, not printed WAT. A future implementation needs tests that can inspect, at minimum:

```text
Function A: reads = {g0}, writes = {}, callsUnknown = false
Function B: reads = {g0}, writes = {g1}, callsUnknown = false
Function C: reads/writes = conservative, callsUnknown = true
```

Validate direct reads/writes, call-chain propagation, imported/indirect/`call_ref` conservatism, and recursive SCC convergence before relying on any textual output. Then use a consumer to make the metadata observable in behavior:

1. produce summaries;
2. run `vacuum` or `simplify-locals` on a shape where those facts can enable a legal rewrite;
3. compare the paired pipeline with Binaryen; and
4. run the cleanup sibling to verify stale summaries cannot survive mutation.

See [`starshine-port-readiness-and-validation.md`](starshine-port-readiness-and-validation.md), [`metadata-naming-and-consumers.md`](metadata-naming-and-consumers.md), and [`../discard-global-effects/fuzzing.md`](../discard-global-effects/fuzzing.md).

## Future admission gates

A future lane must not become runnable until all of the following are true:

1. an active Starshine module pass produces persistent per-function global read/write summaries;
2. the registry no longer treats `global-effects` as boundary-only;
3. `SUPPORTED_PASS_FLAGS` accepts the local spelling and maps it explicitly to Binaryen `--generate-global-effects`; and
4. a metadata-observer adapter or in-process test plus a paired consumer corpus provides a meaningful nonzero `--min-compared` threshold.

Only after those gates are green may a **secondary** consumer-composition command resemble:

```text
moon build --target native --release src/cmd
bun fuzz compare-pass --pass global-effects --pass vacuum \
  --count 10000 --seed 0x5eed --out-dir .tmp/pass-fuzz-global-effects-vacuum \
  --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe \
  --min-compared <meaningful-count>
```

This is a future template, not current signoff guidance. Add a companion `global-effects + simplify-locals` lane only after its consumer surface has focused fixtures. Keep `global-effects` alone out of a WAT-only parity claim.

## Required targeted cases before signoff

| Case | Required assertion |
| --- | --- |
| Direct reader/writer | Summary records the exact global-index read/write sets. |
| Defined call chain | Caller summary includes callee facts. |
| Import, indirect call, `call_ref` | Summary stays conservative until a precise target proof exists. |
| Recursive SCC | Solver converges and cannot use an unsound acyclic shortcut. |
| Producer + `vacuum` | Consumer result matches Binaryen only where the summary justifies removal. |
| Producer + `simplify-locals` | Global read/write precision enables only legal movement. |
| Producer + cleanup | `discard-global-effects` removes every persistent summary; later consumers cannot read stale facts. |

Record metadata observations, paired compared-case counts, validation results, and mismatch classifications separately. A standalone unchanged WAT result is not global-effects parity evidence.
