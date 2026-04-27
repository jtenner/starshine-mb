---
kind: concept
status: supported
last_reviewed: 2026-04-27
sources:
  - ../../../raw/binaryen/2026-04-27-const-hoisting-port-readiness-primary-sources.md
  - ../../../raw/binaryen/2026-04-23-const-hoisting-primary-sources.md
  - ../../../raw/binaryen/2026-04-25-const-hoisting-current-main-recheck.md
  - ../../../raw/research/0428-2026-04-27-const-hoisting-port-readiness.md
  - ../../../raw/research/0182-2026-04-21-const-hoisting-binaryen-research.md
  - ../../../raw/research/0225-2026-04-21-const-hoisting-literal-identity-followup.md
  - https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/ConstHoisting.cpp
  - https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/pass.cpp
  - https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/const-hoisting.wast
  - https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/ConstHoisting.cpp
  - https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/const-hoisting.wast
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./size-model-and-boundaries.md
  - ./wat-shapes.md
  - ./starshine-port-readiness-and-validation.md
---

# `const-hoisting` implementation structure and tests

This page is the file-by-file map for Binaryen `const-hoisting`. For Starshine implementation sequencing and validation, see [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md).

## Main implementation file

## `src/passes/ConstHoisting.cpp`

This file contains essentially the whole pass.
That small size is part of the contract: there is no hidden side analysis spread across many neighboring files.

What it defines:

- the pass class `ConstHoisting`
- the `MIN_USES = 2` coarse floor
- collection of literal uses in `visitConst`
- profitability logic in `worthHoisting`
- the actual temp-local rewrite in `hoist`
- function-entry prelude insertion in `visitFunction`
- `createConstHoistingPass()`

What it proves:

- the pass is function-parallel
- only `Const` nodes are candidates
- profitability is based on encoded byte size, not AST size
- only scalar numeric constants are supported today
- the rewrite shape is deliberately one fresh local plus a prelude block

## Registration file

## `src/passes/pass.cpp`

This file proves `const-hoisting` is a real public pass name, not just an internal helper.

What it adds:

- CLI/public registration under the exact pass name `const-hoisting`
- the short public summary text

What it does **not** prove:

- any default preset placement for the pass in the no-DWARF pipeline used by this repo

That distinction matters because this dossier is about the public pass contract, not about claiming the pass already belongs in the current Starshine parity queue.

## Dedicated upstream test file

## `test/lit/passes/const-hoisting.wast`

This is the key behavioral oracle.
It is much richer than the tiny implementation might suggest.

What it proves:

### 1. Exact threshold behavior for signed-LEB `i32`

The file enumerates many repeated integer constants with known encoded byte widths:

- `0`, `63` → 1 byte
- `64`, `8191`, `-65`, `-8192` → 2 bytes
- `8192`, `1048575`, `-8193`, `-1048576` → 3 bytes
- `1048576`, `-1048577` → 4 bytes

The checks show exactly which groups get hoisted and which do not.
That locks down the byte model, not just the broad idea.

### 2. Exact threshold behavior for floats

The file includes:

- repeated `f32.const 0`
- repeated `f64.const 0`

and checks that:

- `f32.const 0` needs 4 appearances
- `f64.const 0` needs only 2 appearances

One small source-reading caveat is worth recording explicitly: the final `$enough-d` example still has a stale inline source comment that says `4 bytes, need 4 appearances`, but the checked output and `ConstHoisting.cpp` both make clear that the real `f64` rule is `8` bytes and `2` appearances.

### 3. Stable prelude ordering

The checked output expects hoisted locals and `local.set`s in a consistent order.
That indirectly proves the implementation is not using arbitrary hash-map iteration.

### 4. Structural output shape

The checked output expects:

- newly added locals
- a first `block` containing the hoist prelude
- a later `block` for the original body contents

So the extra wrapper block is not an accidental current artifact; it is part of the tested contract.

## Freshness check against `main`

A focused 2026-04-25 recheck captured in [`../../../raw/binaryen/2026-04-25-const-hoisting-current-main-recheck.md`](../../../raw/binaryen/2026-04-25-const-hoisting-current-main-recheck.md) compared these teaching surfaces against the existing `version_129` dossier:

- `src/passes/ConstHoisting.cpp`
- `test/lit/passes/const-hoisting.wast`
- `src/passes/pass.cpp`
- `src/literal.h`
- `src/wasm-binary.h`

Result:

- no teaching-relevant drift in the reviewed implementation, helper, registration, or dedicated test surface
- the reviewed official Binaryen GitHub release page for `version_129`, rechecked on 2026-04-23 through [`../../../raw/binaryen/2026-04-23-const-hoisting-primary-sources.md`](../../../raw/binaryen/2026-04-23-const-hoisting-primary-sources.md), still showed publish date **2026-04-01**

That means the `version_129` release tag remains a reliable oracle for this pass at the moment.

## What the source layout does **not** contain

This absence is important too.
There is also no dedicated upstream lit case for:

- `+0.0` versus `-0.0`
- distinct NaN payload buckets

Those float-identity rules are instead source-confirmed from `Literal` equality and hashing in `literal.h`.

There is no separate:

- CFG helper
- effect analysis helper
- liveness pass
- dominance helper
- profitability-tuning option
- SIMD side file
- secondary cleanup pass embedded into the implementation

That absence tells us a lot about the real scope:

- `const-hoisting` is intentionally narrow and intentionally cheap

## Best file-reading order for future work

If someone needs to port or verify the pass later, the fastest reliable reading order is:

1. `src/passes/ConstHoisting.cpp`
   - to understand the real algorithm
2. `test/lit/passes/const-hoisting.wast`
   - to understand the exact thresholds and output shape
3. `src/passes/pass.cpp`
   - to confirm the public name and summary

## Future Starshine porting checklist

When this pass is eventually ported, these are the source-backed obligations to preserve:

- exact public name: `const-hoisting`
- function-local scope
- literal-only candidate surface
- byte-based profitability rule
- unsupported `v128` boundary unless intentionally expanded
- stable hoist ordering
- fresh-local plus entry-prelude rewrite shape
- explicit distinction from default optimize-preset parity work

## Sources

- [`../../../raw/binaryen/2026-04-23-const-hoisting-primary-sources.md`](../../../raw/binaryen/2026-04-23-const-hoisting-primary-sources.md)
- [`../../../raw/binaryen/2026-04-25-const-hoisting-current-main-recheck.md`](../../../raw/binaryen/2026-04-25-const-hoisting-current-main-recheck.md)
- [`../../../raw/research/0182-2026-04-21-const-hoisting-binaryen-research.md`](../../../raw/research/0182-2026-04-21-const-hoisting-binaryen-research.md)
- [`../../../raw/research/0225-2026-04-21-const-hoisting-literal-identity-followup.md`](../../../raw/research/0225-2026-04-21-const-hoisting-literal-identity-followup.md)
- <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/ConstHoisting.cpp>
- <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/literal.h>
- <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/pass.cpp>
- <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/const-hoisting.wast>
- <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/ConstHoisting.cpp>
- <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/const-hoisting.wast>
