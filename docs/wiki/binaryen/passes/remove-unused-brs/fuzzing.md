---
kind: workflow
status: working
last_reviewed: 2026-07-18
sources:
  - ../../../raw/research/1647-2026-07-17-remove-unused-brs-batch-writeback-and-validity.md
  - ../../../tooling/pass-fuzz-compare.md
  - ../../../../../scripts/lib/pass-fuzz-compare-task.ts
---

# `remove-unused-brs` Fuzzing Profile

Recommended smoke lane: run the ordinary GenValid compare-pass lane for this pass:

```sh
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass remove-unused-brs --out-dir .tmp/pass-fuzz-remove-unused-brs --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe
```

Dedicated GenValid profile: `remove-unused-brs-all` now exists as an experimental RUB-focused aggregate. Aliases `remove-unused-brs`, `remove-unused-brs-closeout`, `remove-unused-brs-all-profiles`, `rub`, and `rub-closeout` resolve to it. The aggregate currently samples compact `remove-unused-brs-control`, `remove-unused-brs-switch`, and `remove-unused-brs-cleanup` leaves and records the selected leaf in `genValidSelectedProfileCounts`; the targeted `remove-unused-brs-gc` singleton exists but is intentionally excluded from the closeout aggregate because early smoke evidence showed boundary-heavy GC output drift.

Current DAEO-prefix repair status (2026-07-17): note [`1647`](../../../raw/research/1647-2026-07-17-remove-unused-brs-batch-writeback-and-validity.md) adds rollback-capable changed-function batch validation plus fail-closed multivalue-carrier, nullable-return/non-null-result, and giant-table convergence guards. The final explicit-native regular lane is `10000/10000` with `1520` normalized plus `8480` cleanup-normalized and zero mismatches/failures. The dedicated runtime sample reproduces the accepted `115`-mismatch side-effect-free family with zero validation failures and Node runtime `89` equal results / `26` equal traps / `0` semantic mismatches. Direct current-artifact RUB falls from `580.178s` and invalid output to valid deterministic `3.239s` / `3.068s` repeats; three productive applications reach a byte-identical fixed point.

Current RUB-Q signoff status (2026-06-29): notes [research note 1386](./index.md) and [research note 1387](./index.md) refresh the final-lane status. Completed green lanes include regular GenValid `100000/100000` at `.tmp/pass-fuzz-remove-unused-brs-rub-q-regular-100000-normalized-rerun-long` (`14604` normalized, `85396` cleanup-normalized, `0` mismatches/failures), regular GenValid `10000/10000` (`1520` normalized, `8480` cleanup-normalized, `0` mismatches/failures), explicit wasm-smith `9956/10000` (`9954` normalized, `2` cleanup-normalized, `0` mismatches, `44` Binaryen/oracle command failures), and broad named `pass-fuzz-stress` `10000/10000` (`1397` normalized, `8603` cleanup-normalized, `0` mismatches/failures). The prior regular `100000` timeout remains only partial/historical evidence.

Dedicated-profile closeout uses an approved substitute rather than normalized-green output. The older compact `1000` run at `.tmp/pass-fuzz-remove-unused-brs-rub-q-dedicated-all-1000-compact-norm3` produced `1000` Starshine validation failures before Binaryen comparison (`remove-unused-brs-control=487`, `remove-unused-brs-switch=338`, `remove-unused-brs-cleanup=175`), and note [research note 1388](./index.md) reduced the suffix-loss shape. Note [research note 1389](./index.md) supersedes that validation blocker for current source: the reduced CLI replay validates when using the current `_build/native/release/build/cmd/cmd.exe` binary, the new binary-decode public pipeline regression passes, and current dedicated smokes report `0` Starshine validation failures. The absorbed dedicated-classification probes establish the approved substitute directly: a capped current-binary run compared `115` mismatches with zero validation/generator/property/command failures, while a runtime-enabled sample checked `35/35` as equal (`27` equal results, `8` equal traps). The profile disables calls/imports/memory/table/tag/element/data/tail-call surfaces; sampled effect facts also exclude global/exception/atomic effects. Reduced constant-`br_if` and same-target-`br_table` cases show Starshine deleting dead structured shells that Binaryen leaves. Normalized size favors Starshine in every sampled mismatch (`115/115`, `-12527` bytes; runtime sample `35/35`, `-3832` bytes), though raw size is mixed. RUB-Q is therefore closed as an explicit Starshine win under the approved-substitute clause. Reopen on a current-binary validation failure, runtime mismatch, effectful case, mismatch outside dead-shell/pure-selector-drop/payload-forwarding, unaccepted size loss, or source drift.
