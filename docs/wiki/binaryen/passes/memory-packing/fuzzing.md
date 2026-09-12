---
kind: workflow
status: supported
last_reviewed: 2026-09-12
sources:
  - ../../../tooling/pass-fuzz-compare.md
  - ../../../../../scripts/lib/pass-fuzz-compare-task.ts
  - ../../../../../src/passes/memory_packing_test.mbt
  - ./parity.md
---

# `memory-packing` Fuzzing Profile

> **Comparison baseline — September 10, 2026:** new comparisons use [Binaryen 132](../../release-horizon-and-oracles.md). This supersedes older current/latest-baseline wording below. Recorded v131 sources, commands, artifacts and results retain their historical version and do not establish v132 signoff.

## September 12, 2026 correctness repair evidence

The verified Binaryen 132 aggregate command is:

```sh
moon build --target native --release src/cmd
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass memory-packing --gen-valid-profile memory-packing-all --out-dir .tmp/optimizer-memory-packing-final-10000 --jobs auto --max-subprocesses 8 --max-mismatch-artifacts 20 --starshine-bin _build/native/release/build/cmd/cmd.exe --gen-valid-bin _build/native/release/build/fuzz/fuzz.exe --require-binaryen-version 132 --max-failures 20000 --keep-going-after-command-failures --no-reduce-mismatches
```

The generator was prebuilt by the first lane; its profile code is unchanged.
Final results: 10,000 compared; 5,267 normalized matches; 0 cleanup-normalized
matches; 4,733 canonical differences; 0 validation, generator, property, or
command failures. Binaryen cache: 10,000 hits / 0 misses; failure-cache and
semantic-cache counters are zero. Twenty mismatch bundles were retained and
4,713 suppressed. All seven aggregate leaves were selected: active ranges
2,010; active traps 1,284; defined overlap 1,264; boundaries 709; segment ops
1,382; passive splits 2,021; memory64 1,330.

These classifications are **agent judgments**, not semantic verdicts from the
canonical comparison harness:

| Family | Cases | Canonical byte delta vs Binaryen | Judgment and evidence |
| --- | ---: | ---: | --- |
| Active zero-length segment ops | 1,382 | -8,292 | Starshine win: a smaller page-count check also preserves valid zero-length operations at full Memory32 capacity, where Binaryen's byte-size shift wraps. |
| Dynamic Memory64 passive copies | 1,330 | +75,810 | Correctness win with a size cost: full preflight prevents observed partial writes before trapping. |
| Constant passive copies | 2,021 | +54,567 | Size-losing parity gap: conservative lifetime and destination guards remain; no measured Starshine advantage is claimed for this family. |

Final aggregate raw sizes: Starshine 675,147 / Binaryen 551,138 bytes,
smaller/equal/larger 5,940/0/4,060. Canonical sizes: 673,223 / 551,138 bytes,
smaller/equal/larger 1,382/5,267/3,351. Constant destination folding reduced
Starshine's canonical total by 126,758 bytes compared with the initial full
arithmetic preflight. No pass-local timing conclusion is drawn from concurrent
validation runs.

All 20 saved representative cases were re-optimized with the final native
binary, validated, and executed with function/memory exports added solely for
observation. Repeated calls, memory growth, and boundary arguments produced 120
calls per implementation. Starshine matched original traps and complete memory
in every case; Binaryen matched 15/20, with five Memory64 cases exposing partial
writes. This is sampled execution evidence, not execution of all 10,000 cases.
The independent [runtime regression suite](../../../../../scripts/test/optimizer-correctness-runtime.ts)
contains the original 125 cases plus two imported-global alias regressions. It
also covers active runtime emptiness, zero-byte storage, independent drops,
omitted/retained ranges, operand effects, and full 4 GiB Memory32 boundaries.
See [the semantic contract](./segment-op-rewrites-and-traps.md#september-12-correctness-invariants)
for the arithmetic proof and explicit Binaryen counterexamples. Keep the
constant-copy size gap open; this repair does not claim complete output parity.


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
