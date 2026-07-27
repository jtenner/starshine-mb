---
kind: workflow
status: supported
last_reviewed: 2026-07-26
sources:
  - ../../../tooling/pass-fuzz-compare.md
  - ../../../../../scripts/lib/pass-fuzz-compare-task.ts
  - ../../../../../src/passes/memory_packing_test.mbt
  - ./parity.md
---

# `memory-packing` Fuzzing Profile

## Required ordinary lane

```sh
bun scripts/pass-fuzz-compare.ts --count 100000 --seed 0x5eed --pass memory-packing --out-dir .tmp/mp-v131-closeout-regular --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --wasm-opt-bin .tmp/binaryen-version-131-bin/bin/wasm-opt --max-failures 2000 --keep-going-after-command-failures
```

Final explicit-v131 result: `100000/100000` normalized, zero command, validation, property, generator, or mismatch failures.

## Explicit wasm-smith lane

```sh
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass memory-packing --wasm-smith --normalize unreachable-control-debris --out-dir .tmp/mp-v131-closeout-wasm-smith --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --wasm-opt-bin .tmp/binaryen-version-131-bin/bin/wasm-opt --max-failures 2000 --keep-going-after-command-failures
```

Final result: `9956/10000` compared, `9955` direct normalized matches plus one `unreachable-control-debris` compare-normalized match, zero mismatches or Starshine/validation/property failures, and `44` Binaryen-only command failures (`39` zero-sized rec groups, one invalid tag index, one table-index failure, and three bad section sizes). The normalized case has no data section and differs only by Starshine retaining an extra `drop(unreachable)` shell; it is pass-independent representation cleanup, not a `memory-packing` semantic mismatch.

## Broad random-profile lane

```sh
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5555 --pass memory-packing --gen-valid-profile random-all-profiles --out-dir .tmp/mp-v131-closeout-random --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --wasm-opt-bin .tmp/binaryen-version-131-bin/bin/wasm-opt --max-failures 2000 --keep-going-after-command-failures
```

Final result: `10000/10000` normalized, zero command, validation, property, generator, or mismatch failures.

## Pass-specific family lanes

`memory-packing-all` is the ordinary aggregate. It deterministically samples randomized family fixtures and records each selected leaf in the batch manifest:

- `memory-packing-active-ranges`
- `memory-packing-active-traps`
- `memory-packing-defined-overlap`
- `memory-packing-passive-splits`
- `memory-packing-segment-ops`
- `memory-packing-memory64`
- `memory-packing-boundaries`

Run the required dedicated lane with:

```sh
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass memory-packing --gen-valid-profile memory-packing-all --out-dir .tmp/mp-v131-closeout-dedicated --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --wasm-opt-bin .tmp/binaryen-version-131-bin/bin/wasm-opt --max-failures 2000 --keep-going-after-command-failures
```

Imported overlap remains a separate option-sensitive family. The compare harness now forwards `--zero-filled-memory` to both tools:

```sh
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass memory-packing --gen-valid-profile memory-packing-imported-overlap --zero-filled-memory --out-dir .tmp/mp-v131-closeout-imported --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --wasm-opt-bin .tmp/binaryen-version-131-bin/bin/wasm-opt --max-failures 2000 --keep-going-after-command-failures
```

The family profiles cover the released overlap rules, active trap retention, active `memory.init` destination bounds checks, passive split/fill/drop-state rewriting, segment-op cleanup, memory64 destination typing, names and no-split boundaries. Focused deterministic fixtures remain the semantic oracle for maximal `2^64` endpoints and decoded legacy-EH traversal.

**Final result:** the dedicated aggregate is `10000/10000` exact, including all seven leaves (`2010` active-ranges, `1284` active-traps, `1264` defined-overlap, `2021` passive-splits, `1382` segment-ops, `1330` memory64, and `709` boundaries). The separate imported option lane is also `10000/10000` exact. Both have zero failures or mismatches.

## O4z evidence

The current debug optimizer was rebuilt at SHA-256 `2327a5fe1b5c08f7249641165875e19e1b4d31abf94e0ec64579142a97fa73ad`. Binaryen v131 produced the slot-3 predecessor `.tmp/mp-v131-final-o4z-slot/prefix-before-memory-packing.wasm` after `duplicate-function-elimination -> remove-unused-module-elements` at SHA-256 `f55dac5aba030c167f8cbd0315ea6904f8ed54ae10891edeb96afd3c73e5803f` and `5,230,186` bytes. Five direct replays are exact at `5,240,308` canonical bytes. Median pass-local time is `64.874ms` Starshine versus `57.179ms` Binaryen (`1.13x`); median whole-command time is `774.931ms` versus `517.938ms`. The combined preflight/data-operation scan reduced Starshine's same-artifact pass median from the pre-fix `117.809ms` to `64.874ms` by avoiding a complete code-section clone when no data-index users exist.
