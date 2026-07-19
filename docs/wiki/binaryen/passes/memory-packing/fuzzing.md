---
kind: workflow
status: supported
last_reviewed: 2026-07-19
sources:
  - ../../../tooling/pass-fuzz-compare.md
  - ../../../../../scripts/lib/pass-fuzz-compare-task.ts
  - ../../../../../src/passes/memory_packing_test.mbt
  - ./parity.md
---

# `memory-packing` Fuzzing Profile

## Required ordinary lane

```sh
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass memory-packing --out-dir .tmp/mp-v131-regular-10000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --wasm-opt-bin .tmp/binaryen-version-131-bin/bin/wasm-opt --keep-going-after-command-failures
```

Current explicit-v131 result: `10000/10000` normalized, zero command, validation, property, generator, or mismatch failures.

## Explicit wasm-smith lane

```sh
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass memory-packing --wasm-smith --out-dir .tmp/mp-v131-wasm-smith-10000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --wasm-opt-bin .tmp/binaryen-version-131-bin/bin/wasm-opt --keep-going-after-command-failures
```

Current result: `9956/10000` compared, `9955` direct normalized matches, one raw residual, `44` Binaryen/tool command failures, and zero validation or property failures. The sole residual, `case-009332-wasm-smith`, has no data section and differs only by Starshine retaining an extra `drop(unreachable)` shell. Agent classification: generic representation drift outside `memory-packing`, not a pass semantic mismatch.

## Broad random-profile lane

```sh
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass memory-packing --gen-valid-profile random-all-profiles --out-dir .tmp/mp-v131-random-all-10000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --wasm-opt-bin .tmp/binaryen-version-131-bin/bin/wasm-opt --max-failures 2000 --keep-going-after-command-failures
```

Current result: `10000/10000` normalized, zero command, validation, property, generator, or mismatch failures.

## Pass-specific focused lane

There is no `memory-packing-all` GenValid aggregate yet. The released v131 overlap change is option-sensitive and is locked by focused module fixtures instead:

- defined-memory source-order trampling;
- imported zero and nonzero tramplers under `zero_filled_memory`;
- partial trampling and segment-order preservation;
- out-of-bounds trampler and unrelated out-of-bounds imported bailouts;
- maximal imported memory64, including a segment ending exactly at `2^64`;
- high memory64 startup-trap preservation; and
- dynamic-offset conservative bailout.

The focused `src/passes/memory_packing_test.mbt` suite passes `37/37`. Exact explicit-v131 self-compares are canonical-equal for both the defined overlap (`33` bytes) and imported nonzero trampler (`46` bytes).

A future dedicated aggregate should generate active/passive packing families and must carry the `zero_filled_memory` optimizer option separately from pass names. Until the compare harness has first-class non-pass option forwarding, do not pretend an ordinary generated lane exercises imported-overlap admission.

## O4z evidence

The rebuilt slot-3 predecessor is `.tmp/mp-v131-o4z-slot/prefix-before-memory-packing.wasm`. Direct replay at `.tmp/mp-v131-o4z-slot/direct` is canonical and normalized equal at `4,954,978` bytes. Pass-local timing is `101.821ms` Starshine versus `61.168ms` Binaryen (`1.66x`, inside the repo `2x` target); whole-command time is `776.671ms` versus `520.314ms`.
