---
kind: research
status: complete
created: 2026-07-02
sources:
  - ../../binaryen/passes/reorder-locals/fuzzing.md
  - ../../binaryen/passes/reorder-locals/parity.md
  - ../../binaryen/passes/reorder-locals/index.md
  - ../../../../src/validate/gen_valid.mbt
  - ../../../../src/validate/gen_valid_tests.mbt
  - ../../../../src/fuzz/main_wbtest.mbt
  - ../../../../src/passes/reorder_locals.mbt
  - ../../../../scripts/lib/pass-fuzz-compare-task.ts
  - ../../../../scripts/lib/self-optimize-compare-task.ts
---

# `reorder-locals` O4Z Audit Closeout

Date: 2026-07-02.
Local oracle: `wasm-opt version 130 (version_130)`.
Native Starshine binary used for compare and timing lanes: `_build/native/release/build/cmd/cmd.exe`.

## Source and algorithm inventory

The preceding source refresh (`1400-2026-07-02-reorder-locals-v130-source-inventory.md`) found no `version_129` -> `version_130` owner/lit drift for `src/passes/ReorderLocals.cpp` or the dedicated Binaryen `reorder-locals` tests. The direct algorithm contract remains:

- parameters are stable;
- only body locals reorder;
- `local.get`, `local.set`, and `local.tee` all count as local accesses;
- body locals sort by descending access count;
- nonzero-count ties break by first observed access;
- the final zero-count suffix is dropped;
- local-name metadata must be repaired and raw name payloads invalidated.

No new direct transform gap was found in the Starshine implementation.

## Dedicated GenValid profile added

Added pass-specific GenValid leaves plus aggregate:

- `reorder-locals-hot-sort`: high-index locals with repeated hot accesses, first-use ordering, and tee coverage;
- `reorder-locals-unused-trim`: high-index write-only/accessed locals plus unused suffix pressure;
- `reorder-locals-name-repair`: name custom section coverage for remapped/dropped locals;
- `reorder-locals-all`: weighted aggregate (`hot-sort` weight 3, `unused-trim` weight 2, `name-repair` weight 1).

Red-first coverage was added in:

- `src/validate/gen_valid_tests.mbt` for profile resolution, aliases, aggregate leaf selection, generated validity, and local-table facts;
- `src/fuzz/main_wbtest.mbt` for manifest `config_label`, `selected_profile`, and local/name feature facts.

## Compare evidence

All compare-pass lanes below used seed `0x5eed` and pass `reorder-locals`.

| Lane | Command summary | Result |
| --- | --- | --- |
| Dedicated GenValid aggregate | `--count 10000 --gen-valid-profile reorder-locals-all --out-dir .tmp/pass-fuzz-reorder-locals-genvalid-10000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe` | `10000/10000` compared; `10000` normalized matches; zero mismatches, validation failures, generator failures, command failures, or property failures. |
| Ordinary GenValid | `--count 10000 --out-dir .tmp/pass-fuzz-reorder-locals-v130-genvalid --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe` | `10000/10000` compared; `10000` normalized matches; zero mismatches, validation failures, generator failures, command failures, or property failures. |
| Random all-profiles GenValid | `--count 10000 --gen-valid-profile random-all-profiles --out-dir .tmp/pass-fuzz-reorder-locals-random-all-10000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe` | `10000/10000` compared; `10000` normalized matches; zero mismatches, validation failures, generator failures, command failures, or property failures. |
| External wasm-smith | `--count 10000 --wasm-smith --keep-going-after-command-failures --normalize unreachable-control-debris --out-dir .tmp/pass-fuzz-reorder-locals-wasm-smith-10000-unreachable-normalized --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe` | `9956/10000` compared; `9955` raw normalized matches; `1` compare-normalized unreachable-control-debris match; zero remaining mismatches, validation failures, generator failures, or property failures; `44` Binaryen/oracle command failures. |

The external-generator raw residual was `case-009332-wasm-smith`: Binaryen dropped `drop(unreachable)` debris inside unreachable control while Starshine preserved it. The `unreachable-control-debris` normalizer erased exactly this shape. This is classified as a non-`reorder-locals` unreachable/control-debris canonicalization difference, not a sorter/name/local-index parity gap.

## Timing evidence

A measurement-only sample over 30 even-spaced inputs from the dedicated aggregate wrote `.tmp/rl-perf-probe-dedicated-30/summary.md`.

- `30/30` timing commands completed.
- Pass-local medians: Starshine `0.020500 ms`, Binaryen `0.011000 ms`.
- Pass-local means: Starshine `0.021333 ms`, Binaryen `0.011967 ms`.
- Pass-local max: Starshine `0.032000 ms`, Binaryen `0.019000 ms`.
- Median ratio: `1.738636x`; max ratio: `2.818182x`.

The pass is far below the repo's `<1s` pass-local target on this dedicated profile. Ratio outliers are dominated by sub-0.05ms timer granularity; no performance blocker remains for the O4Z audit.

## Scheduler and invariant closeout

Starshine continues to claim the explicit module pass plus exactly one public `optimize`/`shrink` slot in the proven tuple/no-structure neighborhood:

```text
code-pushing -> tuple-optimization -> simplify-locals-nostructure -> vacuum -> reorder-locals -> remove-unused-brs
```

The extra Binaryen no-DWARF scheduler slots remain intentionally unclaimed until their ordered neighborhoods are audited under `[O4Z-PRESET-BEHAVIOR]`. They are not a direct `reorder-locals` transform blocker.

`[AUDIT006-E]` is resolved for this pass by the inline comment in `src/passes/reorder_locals.mbt`: function-section type references are module-global `TypeIdx` values after decode/validation; a `RecIdx` in that position is an invariant failure, not a valid user-input shape to support.

## Validation commands run

- Red-first compile failure for missing `ReorderLocals*Profile` constructors in `src/validate/gen_valid_tests.mbt`.
- `moon test --package jtenner/starshine/validate --file gen_valid_tests.mbt`
- `moon test --package jtenner/starshine/fuzz --file main_wbtest.mbt`
- `moon info`
- `moon fmt`
- `moon build --target native --release src/cmd`
- `moon test --package jtenner/starshine/passes --file reorder_locals_test.mbt`
- Compare and timing lanes listed above.

## Conclusion

`[O4Z-AUDIT-RL]` is complete for the explicit `reorder-locals` module pass. Direct `version_130` source parity, focused coverage, dedicated generated coverage, four-lane compare evidence, pass-local timing, current scheduler claim, and the local `TypeIdx` invariant comment are all current as of 2026-07-02.
