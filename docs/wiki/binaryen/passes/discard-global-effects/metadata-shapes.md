---
kind: concept
status: supported
last_reviewed: 2026-05-05
sources:
  - ../../../raw/binaryen/2026-05-05-discard-global-effects-current-main-recheck.md
  - ../../../raw/binaryen/2026-05-05-discard-global-effects-current-main-line-anchor-refresh.md
  - ../../../raw/research/0460-2026-05-05-discard-global-effects-current-main-recheck.md
  - ../../../raw/research/0493-2026-05-05-discard-global-effects-current-main-line-anchor-refresh.md
  - ../../../raw/binaryen/2026-04-26-discard-global-effects-implementation-test-map.md
  - ../../../raw/binaryen/2026-04-25-discard-global-effects-primary-sources.md
  - ../../../raw/research/0353-2026-04-25-discard-global-effects-source-dossier.md
  - ./index.md
related:
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
  - ../global-effects/wat-shapes.md
---

# `discard-global-effects` metadata and module shapes

## Scope

This page is the shape catalog for [`./index.md`](./index.md).

Unlike ordinary pass shape pages, these examples use **metadata shapes** rather than instruction-only WAT shapes, because the reviewed Binaryen pass clears function effect summaries instead of rewriting Wasm bodies. The 2026-05-05 current-main recheck and line-anchor refresh keep that shape unchanged.

## Shape 1: no stored summaries

Before:

```text
module
  func $a effects = none
  func $b effects = none
```

After `discard-global-effects`:

```text
module
  func $a effects = none
  func $b effects = none
```

This is a no-op. It is still valid for the pass to run, because clearing absent summaries is harmless.

## Shape 2: generated summaries are cleared

Before:

```text
module
  func $pure effects = Some(no memory writes, no global writes, no traps)
  func $writer effects = Some(global write)
```

After explicit `discard-global-effects`, or after Binaryen's pass runner invalidates summaries before an effect-adding pass:

```text
module
  func $pure effects = none
  func $writer effects = none
```

The function bodies remain unchanged. The point is to remove the analysis facts, not to change code.

## Shape 3: stale summary after an effect-adding transform

Before an effect-adding transform:

```text
func $f effects = Some(no writes)
body:
  i32.const 1
```

After a later pass injects a call or store, the old summary would be stale:

```text
func $f effects = Some(no writes)  ; stale
body:
  call $may_write
  i32.const 1
```

After `discard-global-effects`:

```text
func $f effects = none
body:
  call $may_write
  i32.const 1
```

This is the safety-critical shape. A consumer must not remove or reorder `$f` as if the old summary were still true. [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md) maps the `pass.cpp` / `pass.h` capability hook behind that automatic invalidation rule.

## Shape 4: producer / consumer / cleanup pipeline

A typical lifecycle shape is:

```text
generate-global-effects
  -> later pass uses call summaries
  -> effect-adding pass runs
  -> discard-global-effects
  -> future consumers recompute or stay conservative
```

The cleanup pass is therefore best understood with [`../global-effects/index.md`](../global-effects/index.md), [`../vacuum/index.md`](../vacuum/index.md), and [`../simplify-locals/index.md`](../simplify-locals/index.md): the producer can make later passes stronger, while the cleanup sibling prevents those stronger facts from leaking past their valid lifetime.

## Shape 5: imports and unknown calls

Imports and indirect calls are already conservative in `generate-global-effects`.

`discard-global-effects` does not re-run that analysis and does not inspect imported bodies. It simply clears any stored summary state associated with functions in the module.

## Shape 6: validation shape is unchanged

Because the pass does not edit instructions:

- block/loop/if result types do not change,
- locals do not change,
- function signatures do not change,
- imports/exports do not change,
- data/table/memory/global sections do not change.

A standalone printed WAT diff is therefore not a reliable validation oracle. Prefer metadata inspection or composed pass tests.

## Caveats

- Do not model this as `drop`, `nop`, or dead-code cleanup. It is not [`../vacuum/index.md`](../vacuum/index.md).
- Do not model it as re-running effect inference. That is [`../global-effects/index.md`](../global-effects/index.md).
- Do not claim it is locally implemented in Starshine; [`./starshine-strategy.md`](./starshine-strategy.md) records the current local gap.
