---
kind: workflow
status: working
last_reviewed: 2026-07-11
sources:
  - ../../../raw/binaryen/2026-07-11-memory64-lowering-alias-current-main-recheck.md
  - ../../../tooling/pass-fuzz-compare.md
  - ../../../../../scripts/lib/pass-fuzz-compare-task.ts
  - ../../../../../src/passes/optimize.mbt
related:
  - ./index.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
  - ../../../tooling/pass-fuzz-compare.md
---

# `memory64-lowering` / `table64-lowering` Fuzzing Profile

## Current status: planned, not runnable

Do **not** run or advertise a Starshine `compare-pass` smoke lane today.

- Starshine has no active, boundary-only, or removed registry entry for either upstream spelling in [`src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt); requests are unknown-pass failures, not transforms.
- Neither `--memory64-lowering` nor `--table64-lowering` is in `SUPPORTED_PASS_FLAGS` in [`scripts/lib/pass-fuzz-compare-task.ts`](../../../../../scripts/lib/pass-fuzz-compare-task.ts), so the harness rejects either name before generation or oracle execution.
- A rejected command, zero compared cases, or a Binaryen-only run is **not** Starshine parity evidence.

Binaryen publishes two names for one combined transform: either alias lowers applicable memory64 **and** table64 surfaces. The official mixed fixture runs both spellings against the same expected output; see [`../../../raw/binaryen/2026-07-11-memory64-lowering-alias-current-main-recheck.md`](../../../raw/binaryen/2026-07-11-memory64-lowering-alias-current-main-recheck.md). A future local harness must preserve that alias contract instead of treating one command as memory-only and the other as table-only.

## Required admission before a runnable lane

The four gates in [`../../../tooling/pass-fuzz-compare.md#pass-eligibility-preflight`](../../../tooling/pass-fuzz-compare.md#pass-eligibility-preflight) must all pass:

1. Starshine accepts both public names and dispatches them to the **same** implemented module transform.
2. `SUPPORTED_PASS_FLAGS` admits both names and records the matching Binaryen flags.
3. Reduced fixtures establish declaration, active-segment, dynamic-wrap, high-`MemArg.offset`, size/grow, bulk, and table-width behavior.
4. A feature-capable profile creates meaningful memory64/table64 cases and the lane sets a nonzero `--min-compared` threshold.

The generic portable generator is insufficient by itself: most cases have no memory64/table64 declaration, so a large requested count could still exercise only no-op input.

## Future lane template

After those gates exist, use mixed memory/table fixtures first and require equal behavior through both public aliases:

```text
moon build --target native --release src/cmd
bun fuzz compare-pass --pass memory64-lowering --count 10000 --seed 0x5eed \
  --out-dir .tmp/pass-fuzz-memory64-lowering --jobs auto \
  --starshine-bin _build/native/release/build/cmd/cmd.exe \
  --gen-valid-profile <future-memory64-table64-profile> \
  --min-compared <meaningful-featured-count>

bun fuzz compare-pass --pass table64-lowering ...
```

Before calling either lane signoff, compare both aliases on the same mixed modules and retain reduced fixtures for dynamic `i64` operands, static high offsets, active data/element offsets, grow failure sentinels, mixed-width copy/fill/init positions, SIMD/atomic addresses, and table64 operations. Keep local `memory.fill` and table typing caveats visible through [`starshine-port-readiness-and-validation.md`](starshine-port-readiness-and-validation.md).
