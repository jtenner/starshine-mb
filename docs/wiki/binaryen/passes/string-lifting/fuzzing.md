---
kind: workflow
status: working
last_reviewed: 2026-07-11
sources:
  - ../../../tooling/pass-fuzz-compare.md
  - ../../../../../scripts/lib/pass-fuzz-compare-task.ts
  - ../../../../../src/passes/optimize.mbt
---

# `string-lifting` Fuzzing Status

## Current status: planned only

Do **not** run or advertise a Starshine-vs-Binaryen `compare-pass` smoke lane for `string-lifting` today.

- The comparison harness's `SUPPORTED_PASS_FLAGS` set in [`scripts/lib/pass-fuzz-compare-task.ts`](../../../../../scripts/lib/pass-fuzz-compare-task.ts) does not admit `--string-lifting`. The argument is rejected before input generation or either optimizer executes.
- Starshine has no `string-lifting` registry entry in [`src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt). Its string literal plumbing and `string-gathering` pass are prerequisites, not an executable lifting transform.
- That parser rejection is a **status check**, not a failed smoke lane or Binaryen-parity evidence. A successful process with no comparisons would not be parity evidence either; see the four required gates in [`../../../tooling/pass-fuzz-compare.md`](../../../tooling/pass-fuzz-compare.md#pass-eligibility-preflight).

Use this harmless discovery command only to inspect the harness roster:

```text
bun fuzz compare-pass --list-passes
```

`string-lifting` should remain absent until Starshine deliberately implements and admits the transform.

## Future runnable template

Enable a comparison lane only after all of the following are true:

1. an active Starshine module/boundary pass recognizes magic and JSON string-constant imports plus exact `wasm:js-string` helper signatures, lifts the supported operations, enables Strings, and refinalizes;
2. `SUPPORTED_PASS_FLAGS` admits `--string-lifting` and `bun fuzz compare-pass --list-passes` reports it;
3. the local spelling maps to Binaryen's public `--string-lifting` flag; and
4. focused import/helper fixtures and a generator/profile produce a meaningful compared surface with an explicit `--min-compared` threshold.

Candidate command shape once those prerequisites are true:

```text
moon build --target native --release src/cmd
bun fuzz compare-pass --pass string-lifting --count 10000 --seed 0x5eed \
  --out-dir .tmp/pass-fuzz-string-lifting --jobs auto \
  --starshine-bin _build/native/release/build/cmd/cmd.exe \
  --min-compared <meaningful-count>
```

The command is a **future template**, not current guidance. Before treating it as signoff, add fixture-backed coverage for magic and JSON constants, exact valid helper signatures, fatal recognized-helper signature mismatches, unknown/wrong-module preservation, module-code users, cast-repair boundaries, final Strings-feature enablement, and output validation. Record any eventual GenValid profile, feature floors, normalizers, and replay-artifact contract here.
