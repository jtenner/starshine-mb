---
kind: concept
status: working
last_reviewed: 2026-04-21
sources:
  - ../../../raw/research/0216-2026-04-21-constant-field-null-test-folding-source-confirmation-followup.md
  - ../../../raw/research/0169-2026-04-21-constant-field-null-test-folding-binaryen-research.md
  - ./index.md
related:
  - ./binaryen-strategy.md
  - ./two-bucket-subtype-partitions-and-nonnullable-ref-test-gates.md
  - ./wat-shapes.md
  - ../constant-field-propagation/implementation-structure-and-tests.md
---

# Upstream implementation structure and tests for `constant-field-null-test-folding` / `cfp-reftest`

## Main file map

| File | Why it matters |
| --- | --- |
| `src/passes/ConstantFieldPropagation.cpp` | Core implementation for both plain `cfp` and variant `cfp-reftest`; contains the mode bit, the ordinary field-fact engine, and the narrow `optimizeUsingRefTest(...)` path |
| `src/passes/pass.cpp` | Registers the public pass names `cfp` and `cfp-reftest`, proving that the variant is a real upstream CLI surface rather than only an internal option |
| `src/ir/possible-constant.h` | Defines the tiny replacement domain that still constrains the variant: one literal, one immutable global, or unknown |
| `src/ir/struct-utils.h` | Provides the struct field scanning and value-propagation helpers the variant inherits from ordinary CFP |
| `test/lit/passes/cfp-reftest.wast` | Dedicated public test file for the variant-only rewrite surface |
| `test/lit/passes/cfp.wast` | Baseline CFP contract file; useful for understanding which shapes belong only to the variant |
| `test/lit/passes/gto_and_cfp_in_O.wast` | Confirms the practical closed-world scheduler neighborhood where CFP-family passes matter |

## What each file proves

## 1. `ConstantFieldPropagation.cpp`

This one file is the most important source.
It proves all of the following:

- `cfp-reftest` is not a separate pass engine
- the variant is implemented by the same pass class as plain `cfp`
- the mode switch controls whether the `ref.test` rescue path is available
- the variant still depends on the same field-fact collection and rewrite machinery as the base pass

The practical porting rule is:

- read this file as “ordinary CFP plus one extra rewrite mode,” not as “a separate null-test pass.”

## 2. `pass.cpp`

This file proves the public naming contract.
It registers:

- `cfp`
- `cfp-reftest`

That matters because the local registry name `constant-field-null-test-folding` does not appear upstream.
So `pass.cpp` is the source-backed anchor for the naming split the local dossier must preserve.

It also proves that upstream users can request the variant directly.
That is why the variant deserves a first-class local dossier even though it reuses the same implementation file.

## 3. `possible-constant.h`

This helper file matters because it keeps the variant honest.
Even when `cfp-reftest` adds its extra `ref.test`-guarded `select`, the payloads still come from the same tiny tracked value domain as plain CFP.

That means the variant is not free to synthesize arbitrary values.
It still works inside the same representable replacement lattice.

## 4. `struct-utils.h`

This helper file matters because the variant only exists on top of ordinary struct-field analysis.
The pass still needs:

- field scanning
- subtype-aware value propagation
- field-level aggregation

So `struct-utils.h` is part of the real variant contract even though the local pass name does not mention structs at all.

## 5. `cfp-reftest.wast`

This file is the clearest official teaching aid for the variant itself.
It proves that:

- the public pass surface exists independently
- Binaryen expects dedicated test coverage for the variant
- the intended visible output includes `ref.test`-guarded selection only for narrow approved shapes
- the positive public surface is tiny: one exact-two-bucket subtype partition family, plus nearby nullable-base and bailout checks

This lit file is the main reason the local registry entry should not stay buried only as a footnote under the parent CFP dossier.

## 6. `cfp.wast`

This file remains useful because it separates ordinary CFP expectations from variant-only behavior.
When a shape stays in `cfp.wast` but not the dedicated variant file, the safe reading is:

- plain CFP behavior is still the base contract
- `cfp-reftest` only extends it in the narrow extra family

## 7. `gto_and_cfp_in_O.wast`

This file helps anchor the family in the broader closed-world cluster.
It is useful for explaining why this variant belongs beside `remove-unused-types`, `gto`, and `gsi`, not beside hot local or general control-flow optimizers.

## The main implementation lesson

The biggest lesson from the upstream source layout is simple:

- the variant is **structurally small**
- but it sits on top of **large inherited CFP machinery**

So a future Starshine implementation should preserve that layering:

1. build the ordinary CFP field-fact engine first
2. only then add the extra two-bucket `ref.test` rewrite mode

## Test-reading guidance

When reading the official tests, the safest order is:

1. read `cfp.wast` for the parent pass contract
2. read `cfp-reftest.wast` for the extra variant-only cases
3. use `gto_and_cfp_in_O.wast` to understand where the family fits in the wider closed-world cluster

That ordering keeps beginners from over-attributing all CFP behavior to the variant.

## Freshness note

The reviewed local dossier is anchored to Binaryen `version_129`.
A future thread should check whether current `main` changes:

- the public registration names
- the exact two-bucket matcher rules
- or the dedicated test surface

If it does, record that drift explicitly instead of silently rewriting this `version_129` contract.

## Future-port checklist

A future Starshine port should preserve all of these source-backed facts:

- one shared implementation family for `cfp` and `cfp-reftest`
- one real upstream public registration for `cfp-reftest`
- one tiny allowed replacement domain inherited from CFP
- one dedicated lit file proving the variant surface
- continued dependence on the same struct-field analysis helpers as plain CFP

## Sources

- [`../../../raw/research/0216-2026-04-21-constant-field-null-test-folding-source-confirmation-followup.md`](../../../raw/research/0216-2026-04-21-constant-field-null-test-folding-source-confirmation-followup.md)
- [`../../../raw/research/0169-2026-04-21-constant-field-null-test-folding-binaryen-research.md`](../../../raw/research/0169-2026-04-21-constant-field-null-test-folding-binaryen-research.md)
- [`./index.md`](./index.md)
- [`../constant-field-propagation/implementation-structure-and-tests.md`](../constant-field-propagation/implementation-structure-and-tests.md)
- Binaryen `version_129` sources:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/ConstantFieldPropagation.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/possible-constant.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/struct-utils.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/cfp-reftest.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/cfp.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/gto_and_cfp_in_O.wast>
