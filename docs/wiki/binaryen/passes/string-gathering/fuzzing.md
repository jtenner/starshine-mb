---
kind: workflow
status: working
last_reviewed: 2026-10-19
sources:
  - ../../../tooling/pass-fuzz-compare.md
  - ../../../../../scripts/lib/pass-fuzz-compare-task.ts
---

# `string-gathering` Fuzzing Profile

## October 19 table-rebuild repair

The ordinary 10,000-case lane selects `binaryen-oracle-portable` for every
case. All compare, with zero validation, generator, property or command
failures, but all differ structurally from verified Binaryen 133. The 20
retained outputs match the fresh starting baseline byte for byte; their
canonical text differs only by Binaryen's empty-else `nop` instructions.
Every canonical output is smaller, saving 29,981 total bytes. Raw encoding
still loses in 3,844 cases and grows by 2,768 aggregate bytes. Keep this as
open writer/parity work; smaller canonical output does not close the raw gap
or classify unretained differences.

This portable profile has no string operations and does not exercise gathering.
The focused table/global-index and inline-string tests cover the new helper.
See the [repair record](../../../tooling/validation-gates.md#october-19-2026--pass-review-corrections)
for full counters, sample replay evidence and validation limits.


Recommended smoke lane: run the ordinary GenValid compare-pass lane for this pass:

```sh
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass string-gathering --out-dir .tmp/pass-fuzz-string-gathering --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe
```

Dedicated GenValid profile: none documented for this pass yet.

If a future audit adds a pass-specific GenValid profile, update this page with the profile name, intended smoke/closeout count, any required `--require-feature` floors or `--normalize` flags, and the manifest fields needed for replay triage.
