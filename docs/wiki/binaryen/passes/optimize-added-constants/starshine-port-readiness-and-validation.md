---
kind: concept
status: supported
last_reviewed: 2026-05-05
sources:
  - ../../../raw/binaryen/2026-05-05-optimize-added-constants-current-main-recheck.md
  - ../../../raw/research/0465-2026-05-05-optimize-added-constants-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-27-optimize-added-constants-port-readiness-primary-sources.md
  - ../../../raw/binaryen/2026-04-24-optimize-added-constants-primary-sources.md
  - ../../../raw/research/0418-2026-04-27-optimize-added-constants-port-readiness.md
  - ../../../raw/research/0300-2026-04-24-optimize-added-constants-primary-sources-and-starshine-followup.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/cli/cli.mbt
  - ../../../../../src/cmd/cmd.mbt
  - ../../../../../src/ir/hot_core.mbt
  - ../../../../../src/ir/hot_side_tables.mbt
  - ../../../../../src/ir/hot_builders.mbt
  - ../../../../../src/ir/hot_lift.mbt
  - ../../../../../src/ir/hot_lower.mbt
  - ../../../../../src/lib/types.mbt
  - ../../../../../src/binary/decode.mbt
  - ../../../../../src/binary/encode.mbt
  - ../../../../../src/wast/lexer.mbt
  - ../../../../../src/wast/keywords.mbt
  - ../../../../../src/validate/typecheck.mbt
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./low-memory-threshold-overflow-and-offset-merge-rules.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../optimize-added-constants-propagate/index.md
  - ../tracker.md
---

# Starshine `optimize-added-constants` port readiness and validation

This page turns the current source-backed dossier into an implementation-readiness ladder. It does **not** claim Starshine implements the pass today.

## Current local state

Starshine currently treats `optimize-added-constants` as a removed name:

- [`src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt) lists `optimize-added-constants` and `optimize-added-constants-propagate` in `pass_registry_removed_names()`.
- The same registry path rejects removed pass flags instead of silently accepting them.
- No `src/passes/optimize_added_constants.mbt` owner file exists today.
- No focused Starshine test file or pass-fuzz compare entry exists for this pass today.

That is a healthy boundary while the pass is unimplemented: future work must add real behavior and tests before moving the name out of the removed registry.

## Binaryen contract to preserve

The plain pass should be read as the direct-address half of Binaryen's shared `OptimizeAddedConstants.cpp` engine:

1. require `--low-memory-unused`,
2. skip no-memory modules as no-ops,
3. inspect only `Load` and `Store` pointer operands,
4. fold `base + const` and `const + base` when the constant is nonnegative and below `LowMemoryBound`,
5. require the merged total memory offset to remain below `LowMemoryBound`,
6. normalize `const-pointer + existing-offset` only when unsigned overflow is impossible,
7. leave `local.set` / `local.get` propagation to [`../optimize-added-constants-propagate/index.md`](../optimize-added-constants-propagate/index.md).

The key citation chain is the 2026-05-05 source-anchor digest in [`../../../raw/binaryen/2026-05-05-optimize-added-constants-current-main-recheck.md`](../../../raw/binaryen/2026-05-05-optimize-added-constants-current-main-recheck.md), plus the earlier current-main source recheck in [`../../../raw/binaryen/2026-04-27-optimize-added-constants-port-readiness-primary-sources.md`](../../../raw/binaryen/2026-04-27-optimize-added-constants-port-readiness-primary-sources.md), which together point to official Binaryen `OptimizeAddedConstants.cpp`, `pass.cpp`, `pass.h`, and the plain `low-memory-unused`, memory64, and no-memory tests.

## Starshine code locations to connect

### Registry and request behavior

- [`src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt): removed-name registration and future active registry / dispatcher landing zone.

Implementation rule: keep the name removed until a mutating pass is wired with focused tests. Do not change only the registry.

### Option plumbing

- [`src/cli/cli.mbt`](../../../../../src/cli/cli.mbt): parses `--low-memory-unused`, `--no-low-memory-unused`, and `--low-memory-bound`.
- [`src/cmd/cmd.mbt`](../../../../../src/cmd/cmd.mbt): `OptimizeOptions` stores `low_memory_unused` and `low_memory_bound`, defaults them to `false` and `1024`, and accepts config / environment values.

Implementation rule: a faithful first port should reject or no-op when `low_memory_unused` is false. For Binaryen-oracle parity, compare with `1024` even if Starshine later chooses to expose custom bounds as a deliberate extension; the 2026-05-05 source-anchor digest makes the exact local option and memory-op surfaces easy to find before that decision is made.

### HOT memory-op landing zone

- [`src/ir/hot_core.mbt`](../../../../../src/ir/hot_core.mbt): `HotOp::Load`, `HotOp::Store`, `HotOp::Binary`, and `HotOp::Const` are the minimal node families needed for direct folds.
- [`src/ir/hot_side_tables.mbt`](../../../../../src/ir/hot_side_tables.mbt): `HotOp::Load` and `HotOp::Store` carry `HotSideTableKind::MemArgTable` payloads.
- [`src/ir/hot_builders.mbt`](../../../../../src/ir/hot_builders.mbt): `hot_build_load(...)` and `hot_build_store(...)` allocate `HotMemArg` payloads from `MemArg`.
- [`src/ir/hot_lift.mbt`](../../../../../src/ir/hot_lift.mbt): lifts scalar memory instructions into HOT `Load` / `Store` nodes.
- [`src/ir/hot_lower.mbt`](../../../../../src/ir/hot_lower.mbt): lowers exact HOT memory nodes back into ordinary instructions.
- [`src/lib/types.mbt`](../../../../../src/lib/types.mbt): `MemArg(U32, MemIdx?, U64)` stores alignment, optional memory index, and offset.

Implementation rule: prefer a small HOT pass that rewrites the memory op's `MemArg` and replaces only the address child. It should not introduce local analysis or helper locals in the plain pass.

### Roundtrip and validation surfaces

- [`src/binary/decode.mbt`](../../../../../src/binary/decode.mbt) and [`src/binary/encode.mbt`](../../../../../src/binary/encode.mbt): prove rewritten offsets survive binary roundtrips.
- [`src/wast/lexer.mbt`](../../../../../src/wast/lexer.mbt) and [`src/wast/keywords.mbt`](../../../../../src/wast/keywords.mbt): expose text `offset=` spellings for focused fixtures.
- [`src/validate/typecheck.mbt`](../../../../../src/validate/typecheck.mbt): final guard that the rewritten memory op remains well typed.

Implementation rule: validation should include WAT fixtures, binary roundtrip checks, and Binaryen output comparison under `--low-memory-unused`.

## First mutating slice

A minimal useful slice should support exactly these shapes:

```wat
(i32.load
  (i32.add
    (local.get $base)
    (i32.const 8)))
```

into:

```wat
(i32.load offset=8
  (local.get $base))
```

and the commuted variant:

```wat
(i32.load
  (i32.add
    (i32.const 8)
    (local.get $base)))
```

The same rule should cover stores by rewriting the address child while preserving the value child.

## Required negative tests before enabling the pass

Focused tests should prove these bails:

- `low_memory_unused=false` does not mutate or rejects according to the chosen local policy,
- `1024` does not fold when the Binaryen parity bound is used,
- negative constants do not fold,
- `existing_offset + added_const >= 1024` does not fold,
- non-add arithmetic does not fold,
- local-carrier forms do not fold in the plain pass,
- memory64 constant-pointer overflow does not normalize,
- no-memory modules remain no-ops.

## Validation ladder

1. Add focused Starshine WAT tests for direct load and store folds.
2. Add focused threshold and negative tests: `1023` yes, `1024` no, negative no, merged-offset too-large no.
3. Add constant-pointer normalization tests with memory32 and memory64 overflow boundaries.
4. Add a no-memory no-op test.
5. Run `moon test src/passes` and `moon test src/cmd` for registry / CLI behavior.
6. Add a pass-fuzz compare entry only after focused fixtures match Binaryen with `--low-memory-unused`.
7. Run `moon build --target native --release src/cmd` followed by `bun fuzz compare-pass --pass optimize-added-constants ... --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe` with Binaryen configured for the low-memory assumption; do not compare ordinary no-DWARF preset output because the pass is not a default open-world blocker.

## Explicit non-goals for the plain pass

Do not include these in the first plain slice:

- `LazyLocalGraph` local-pair propagation,
- helper-local insertion,
- dead address-carrier cleanup,
- repeated propagation iterations,
- generic add/sub reassociation,
- precompute-style constant evaluation outside memory addresses.

Those either belong to [`../optimize-added-constants-propagate/index.md`](../optimize-added-constants-propagate/index.md) or to neighboring optimization passes.

## Open design question

Starshine already exposes `low_memory_bound` as a configurable option. Binaryen's reviewed source uses the fixed `PassOptions::LowMemoryBound = 1024` contract. The safest future policy is:

- use `1024` for Binaryen parity mode,
- treat any configurable-bound behavior as a deliberate Starshine extension,
- document and test the extension separately if it is enabled.
