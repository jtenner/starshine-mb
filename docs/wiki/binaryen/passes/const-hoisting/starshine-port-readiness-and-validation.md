---
kind: concept
status: supported
last_reviewed: 2026-05-06
sources:
  - ../../../raw/binaryen/2026-05-06-const-hoisting-current-main-recheck.md
  - ../../../raw/wasm/2026-06-04-leb128-current-refresh.md
  - ../../../raw/wasm/2026-05-20-leb128-binary-integer-encoding-refresh.md
  - ../../../raw/research/0508-2026-05-06-const-hoisting-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-27-const-hoisting-port-readiness-primary-sources.md
  - ../../../raw/binaryen/2026-04-23-const-hoisting-primary-sources.md
  - ../../../raw/binaryen/2026-04-25-const-hoisting-current-main-recheck.md
  - ../../../raw/research/0428-2026-04-27-const-hoisting-port-readiness.md
  - ../../../raw/research/0276-2026-04-23-const-hoisting-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0354-2026-04-25-const-hoisting-current-main-code-map.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/ir/hot_core.mbt
  - ../../../../../src/ir/hot_builders.mbt
  - ../../../../../src/ir/hot_lift.mbt
  - ../../../../../src/ir/hot_lower.mbt
  - ../../../../../src/ir/hot_mutate.mbt
  - ../../../../../src/binary/encode.mbt
  - ../../../../../agent-todo.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./size-model-and-boundaries.md
  - ./literal-bit-identity-zero-signs-and-nan-payloads.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../../../binary/leb128-and-integer-encoding.md
  - ../precompute/index.md
  - ../optimize-added-constants/index.md
  - ../tracker.md
---

# Starshine `const-hoisting` port readiness and validation

This page turns the current source-backed dossier into an implementation-readiness ladder. It does **not** claim Starshine implements the pass today.

## Current local state

Starshine currently treats `const-hoisting` as a removed name:

- [`src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt) lists `const-hoisting` in `pass_registry_removed_names()`.
- The same registry path rejects removed pass flags instead of silently accepting or no-oping them.
- No `src/passes/const_hoisting.mbt` owner file exists today.
- No focused Starshine `const-hoisting` test file or pass-fuzz compare entry exists today.
- [`agent-todo.md`](../../../../../agent-todo.md) has no active `const-hoisting` implementation slice today.

That is a healthy boundary while the pass is unimplemented: future work must add real behavior and tests before moving the name out of the removed registry.

## Binaryen contract to preserve

The pass should be read as a function-local raw-size transform over already-materialized scalar constants:

1. walk one function and collect every `Const` node,
2. group uses by exact `Literal` identity,
3. measure integer literal payload width with signed LEB helpers,
4. treat `f32` and `f64` payloads as fixed 4-byte and 8-byte values,
5. reject `v128`,
6. compute `before = num * size` and `after = size + 2 + 2 * num`,
7. hoist only when `after < before`,
8. append one fresh local per profitable bucket,
9. emit one entry-prelude `local.set` initialized from the first recorded literal,
10. replace all recorded use sites with `local.get`, including the first original use.

The key citation chain is the current-main source recheck in [`../../../raw/binaryen/2026-04-27-const-hoisting-port-readiness-primary-sources.md`](../../../raw/binaryen/2026-04-27-const-hoisting-port-readiness-primary-sources.md), which points to official Binaryen `ConstHoisting.cpp`, `pass.cpp`, `literal.h`, `wasm-binary.h`, `wasm-builder.h`, and the dedicated `const-hoisting.wast` lit file.

## Starshine code locations to connect

### Registry and request behavior

- [`src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt): removed-name registration and future active registry / dispatcher landing zone.

Implementation rule: keep the name removed until a mutating pass is wired with focused tests. Do not change only the registry.

### HOT scalar-constant surface

- [`src/ir/hot_core.mbt`](../../../../../src/ir/hot_core.mbt): `HotOp::Const` plus `HotConstPayload::I32Const`, `I64Const`, `F32Const`, and `F64Const` are the minimal candidate surface.
- [`src/ir/hot_lift.mbt`](../../../../../src/ir/hot_lift.mbt): lifts scalar numeric constants into HOT side-table payloads.
- [`src/ir/hot_lower.mbt`](../../../../../src/ir/hot_lower.mbt): lowers HOT constants and local get/set nodes back into library instructions.

Implementation rule: do not include `RefNullConst` or `StringConst` in the first slice. Binaryen's reviewed contract is scalar numeric literal hoisting, not generic constant pooling.

### HOT local-construction surface

- [`src/ir/hot_builders.mbt`](../../../../../src/ir/hot_builders.mbt): builds typed `local.get` and `local.set` nodes.
- [`src/ir/hot_mutate.mbt`](../../../../../src/ir/hot_mutate.mbt): `hot_append_body_local(...)` appends fresh body locals and bumps the HOT revision.

Implementation rule: create one fresh local per profitable literal bucket, preserve deterministic bucket order, and keep the initializer before the rewritten uses.

### Byte-size accounting surface

- [`src/binary/encode.mbt`](../../../../../src/binary/encode.mbt): signed-LEB emission helpers and scalar-const encoding are the local ingredients for Binaryen-compatible thresholds.
- [`binary/leb128-and-integer-encoding.md`](../../../binary/leb128-and-integer-encoding.md): shared Starshine contract for bounded LEB byte widths, valid overlong decode behavior, and the `size_signed(...)` / `size_unsigned(...)` helper model.

Implementation rule: do not approximate integer widths from value ranges by hand unless tests prove exact parity with signed-LEB emission. The pass is a binary-size pass, so byte accounting is part of correctness, and the shared LEB page owns the byte-layer caveats rather than this pass dossier.

## First useful implementation slice

A minimal mutating slice should support only scalar numeric literal buckets.

Positive integer example:

```wat
(func
  (drop (i32.const 8192))
  (drop (i32.const 8192))
  (drop (i32.const 8192))
  (drop (i32.const 8192))
  (drop (i32.const 8192))
  (drop (i32.const 8192))
)
```

Expected shape:

```wat
(func
  (local i32)
  (block
    (local.set 0 (i32.const 8192))
  )
  (block
    (drop (local.get 0))
    (drop (local.get 0))
    ...
  )
)
```

Positive float example:

```wat
(func
  (drop (f64.const 0))
  (drop (f64.const 0))
)
```

Expected shape:

- one fresh `f64` local,
- one entry-prelude `local.set`,
- two rewritten `local.get` uses.

## Required negative tests before enabling the pass

Focused tests should prove these bails:

- one-byte and two-byte signed-LEB constants remain inline,
- 3-byte signed-LEB constants with only five uses remain inline,
- `f32` with only three uses remains inline,
- `+0.0` and `-0.0` do not combine into one float bucket,
- distinct NaN payloads do not combine into one bucket,
- `v128.const` remains unchanged,
- nonliteral repeated computations remain unchanged,
- repeats in different functions are considered separately,
- already-unreachable surrounding structure is not used as an excuse to drop constants; that belongs to other cleanup passes.

## Validation ladder

1. Add analyzer-only tests that report candidate buckets and byte thresholds without mutating.
2. Add focused mutation tests for `i32`, `i64`, `f32`, and `f64` threshold positives.
3. Add threshold negatives and exact-literal-bucket tests for signed zeros and NaN payloads.
4. Add structural-output tests for deterministic local ordering and entry-prelude insertion.
5. Add reduced `v128` and nonliteral-computation no-op tests.
6. Run `moon test src/passes` and `moon test src/cmd` for registry and pass execution behavior.
7. Add a pass-fuzz compare entry only after focused fixtures match Binaryen's isolated `--const-hoisting` / `--pass const-hoisting` output.
8. Compare against Binaryen in isolated explicit-pass mode before considering any preset placement.

## Explicit non-goals for the first slice

Do not include these in the first local implementation:

- global or module-wide literal pooling,
- nonliteral common-subexpression sharing,
- `ref.null` or `string.const` hoisting,
- `v128` hoisting,
- gzip-aware profitability,
- zero-special-case elimination of the prelude initializer,
- broad locals cleanup after the new prelude block.

Those either belong to different passes or are upstream TODOs, not current Binaryen `const-hoisting` behavior.

## Open design question

Binaryen immediately emits a prelude block and relies on later cleanup such as `merge-blocks` for structural polish. The safest Starshine first port should match that structure closely. A later local improvement may choose a cleaner equivalent HOT root shape, but only after isolated Binaryen-oracle tests prove the output canonicalizes the same way.

## Sources

- [`../../../raw/binaryen/2026-05-06-const-hoisting-current-main-recheck.md`](../../../raw/binaryen/2026-05-06-const-hoisting-current-main-recheck.md)
- [`../../../raw/wasm/2026-06-04-leb128-current-refresh.md`](../../../raw/wasm/2026-06-04-leb128-current-refresh.md)
- [`../../../raw/research/0508-2026-05-06-const-hoisting-current-main-recheck.md`](../../../raw/research/0508-2026-05-06-const-hoisting-current-main-recheck.md)
- [`../../../raw/binaryen/2026-04-27-const-hoisting-port-readiness-primary-sources.md`](../../../raw/binaryen/2026-04-27-const-hoisting-port-readiness-primary-sources.md)
- [`../../../raw/research/0428-2026-04-27-const-hoisting-port-readiness.md`](../../../raw/research/0428-2026-04-27-const-hoisting-port-readiness.md)
- [`../../../raw/binaryen/2026-04-23-const-hoisting-primary-sources.md`](../../../raw/binaryen/2026-04-23-const-hoisting-primary-sources.md)
- [`../../../raw/binaryen/2026-04-25-const-hoisting-current-main-recheck.md`](../../../raw/binaryen/2026-04-25-const-hoisting-current-main-recheck.md)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../../../../../src/ir/hot_core.mbt`](../../../../../src/ir/hot_core.mbt)
- [`../../../../../src/ir/hot_builders.mbt`](../../../../../src/ir/hot_builders.mbt)
- [`../../../../../src/ir/hot_lift.mbt`](../../../../../src/ir/hot_lift.mbt)
- [`../../../../../src/ir/hot_lower.mbt`](../../../../../src/ir/hot_lower.mbt)
- [`../../../../../src/ir/hot_mutate.mbt`](../../../../../src/ir/hot_mutate.mbt)
- [`../../../../../src/binary/encode.mbt`](../../../../../src/binary/encode.mbt)
