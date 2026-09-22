---
kind: workflow
status: working
last_reviewed: 2026-09-22
sources:
  - ../../../tooling/pass-fuzz-compare.md
  - ../../../../../scripts/lib/pass-fuzz-compare-task.ts
---

# `local-cse` Fuzzing Profile

The September 22 shared-memory repair passed red-first direct and nested DAE
regressions, the full 12,053-test suite, and a verified-v132 regular GenValid
lane at `.tmp/pass-safety-final-local-cse-10000`: 10,000/10,000 canonical
matches, zero failures. The native binary and full validation matrix are
recorded in the [safety audit](../../../ir2/architecture-rules.md#september-22-eight-agent-pass-safety-audit).
The directed shared-memory tests cover concurrency-sensitive observations
that this regular profile does not generate.

Recommended smoke lane: run the ordinary GenValid compare-pass lane for this pass:

```sh
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass local-cse --out-dir .tmp/pass-fuzz-local-cse --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe
```

Dedicated GenValid profile: none documented for this pass yet.

If a future audit adds a pass-specific GenValid profile, update this page with the profile name, intended smoke/closeout count, any required `--require-feature` floors or `--normalize` flags, and the manifest fields needed for replay triage.
