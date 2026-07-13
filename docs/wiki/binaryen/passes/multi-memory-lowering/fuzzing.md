---
kind: workflow
status: working
last_reviewed: 2026-07-11
sources:
  - ../../../raw/binaryen/2026-07-11-multi-memory-lowering-custom-page-size-recheck.md
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/MultiMemoryLowering.cpp
  - ../../../tooling/pass-fuzz-compare.md
  - ../../../../../scripts/lib/pass-fuzz-compare-task.ts
  - ../../../../../src/passes/optimize.mbt
related:
  - ./index.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
  - ../../../wasm-multi-memory-boundary.md
  - ../../../wasm-custom-page-sizes-boundary.md
  - ../../../tooling/pass-fuzz-compare.md
---

# `multi-memory-lowering` Fuzzing Profile

## Current status: planned, not runnable

Do **not** run or advertise a compare-pass smoke lane yet. Both upstream spellings are absent from the harness `SUPPORTED_PASS_FLAGS` allowlist in [`scripts/lib/pass-fuzz-compare-task.ts`](../../../../../scripts/lib/pass-fuzz-compare-task.ts), and Starshine has no active registry, dispatcher, or transform owner for either spelling:

- `multi-memory-lowering`;
- `multi-memory-lowering-with-bounds-checks`.

Therefore this command fails at the harness admission check before it generates a module or invokes either optimizer; it is **not** parity evidence:

```text
bun fuzz compare-pass --pass multi-memory-lowering ...
```

This follows the four-gate rule in [`../../../tooling/pass-fuzz-compare.md#pass-eligibility-preflight`](../../../tooling/pass-fuzz-compare.md#pass-eligibility-preflight): a runnable lane requires an implemented and publicly admitted Starshine transform **and** a matching harness allowlist entry. `bun fuzz compare-pass --list-passes` is safe status inspection, but it is not evidence that a missing pass is supported.

## Why a generic generated lane would be insufficient

Even after admission, random ordinary single-memory modules would mostly exercise the pass's zero/one-memory no-op path. A useful profile must deliberately construct multiple selected memories and observe the whole-module rewrite:

| Required case | What it proves |
| --- | --- |
| Two memories with active data in memory `1` | Declaration merge, offset-global creation, and data-mode retargeting. |
| Scalar and bulk operations targeting memory `1` | Base-offset addition and independent source/destination repair for `memory.copy`. |
| Virtual `memory.size` | The output still exposes the selected original memory's page count, not the combined memory's count. |
| Last and non-last `memory.grow` | The helper preserves the old-size / failure-sentinel contract; non-last growth moves later bytes and updates later base offsets. |
| Unsupported imports, exports, or mismatched memory properties | The pass deliberately rejects or matches the documented Binaryen boundary instead of silently changing ABI. |
| Checked sibling out-of-range access | `multi-memory-lowering-with-bounds-checks` traps at the original virtual-memory boundary. |
| Non-default equal custom page sizes, once local representation exists | Input equality, combined declaration propagation, byte layout, and virtual size/grow agree. Current Binaryen output propagation remains an upstream verification boundary, so this is not a positive case yet. |

The local WAST surface currently defaults several high-level memory operators to memory `0`; early fixtures may therefore need direct core/binary construction rather than text roundtrips. See [`starshine-port-readiness-and-validation.md`](starshine-port-readiness-and-validation.md) and [`../../../wasm-multi-memory-boundary.md`](../../../wasm-multi-memory-boundary.md).

## Future runnable lane

Only after the four admission gates and a targeted multi-memory generator/profile exist, begin with the unchecked pass. Build a fresh native binary and require a meaningful number of **multi-memory** comparable cases rather than merely a high requested count:

```text
moon build --target native --release src/cmd
bun fuzz compare-pass --pass multi-memory-lowering --count 10000 --seed 0x5eed \
  --out-dir .tmp/pass-fuzz-multi-memory-lowering --jobs auto \
  --starshine-bin _build/native/release/build/cmd/cmd.exe \
  --min-compared <meaningful-multi-memory-count> \
  --gen-valid-profile <future-multi-memory-profile>
```

The checked sibling needs its own lane and reduced trap fixtures:

```text
bun fuzz compare-pass --pass multi-memory-lowering-with-bounds-checks ...
```

Do not publish either command as runnable until its name is admitted by both the local registry and `SUPPORTED_PASS_FLAGS`. Keep the unchecked and checked siblings separate: matching the combined-memory layout does not prove the checked sibling's trap behavior.

## Signoff requirements

Before claiming parity, preserve and replay reduced cases for declaration/data/body rewriting, both `memory.copy` indexes, virtual size/grow helpers, non-last grow byte movement, import/export/property rejection, feature cleanup, and checked-sibling traps. If custom page sizes become representable locally, add a non-default page-size lane only after upstream output behavior is resolved; Binaryen's current owner checks and uses equal input page sizes but does not visibly assign the output `pageSizeLog2` in the reviewed combined-memory construction. That uncertainty is documented in [`../../../raw/binaryen/2026-07-11-multi-memory-lowering-custom-page-size-recheck.md`](../../../raw/binaryen/2026-07-11-multi-memory-lowering-custom-page-size-recheck.md).
