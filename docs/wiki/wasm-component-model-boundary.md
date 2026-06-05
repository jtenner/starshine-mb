---
kind: concept
status: supported
last_reviewed: 2026-06-05
sources:
  - raw/wasm/2026-06-05-component-model-boundary-refresh.md
  - raw/wasm/2026-06-04-webassembly-active-proposal-routing-current-refresh.md
  - ../../src/lib/types.mbt
  - ../../src/binary/decode.mbt
  - ../../src/wast/parser.mbt
  - ../../src/validate/gen_valid.mbt
related:
  - wasm-feature-status-and-proposal-boundaries.md
  - binary/module-section-map.md
  - binary/function-import-export-and-code-sections.md
  - wast/static-assertion-harness.md
  - tooling/node-package-surface.md
  - tooling/external-validator-adapters.md
---

# WebAssembly Component Model Boundary

## Overview

Use this page when a bug report, fixture idea, package request, or external tool result mentions the **WebAssembly Component Model**, **WIT**, **worlds**, **WASI Preview 2**, or the **Canonical ABI**. These are related to WebAssembly, but they are not the same artifact as the Core WebAssembly modules Starshine currently parses, validates, optimizes, fuzzes, and packages.

For a beginner: a Core WebAssembly module is the familiar `module` with functions, memories, tables, globals, imports, exports, code, data, and custom sections. A Component Model component is a higher-level packaging and interoperability layer. It can contain Core modules, but it also describes interfaces, instances, lifted/lowered functions, and host-language data passing through the Canonical ABI.

The current primary-source bridge is [`raw/wasm/2026-06-05-component-model-boundary-refresh.md`](raw/wasm/2026-06-05-component-model-boundary-refresh.md). It rechecked the official proposals tracker, the Component Model repository, the MVP explainer, WIT documentation, Canonical ABI documentation, and current Starshine source evidence. The durable status is:

- **Standards status:** the official proposals tracker currently routes `Component Model` as an active Phase-1 feature-proposal row, not a finished/Core 3.0 feature.
- **Starshine status:** no documented local support for component binaries, WIT, component text, worlds, component validation, or Canonical ABI lift/lower exists today.
- **Boundary rule:** do not cite Starshine acceptance of Core WebAssembly modules as Component Model support, and do not cite Component Model documentation as evidence that a Starshine WAST/binary/validator path should accept a shape without a focused local implementation slice.

## Layer Split

```text
WIT interface/world files
        |
        v
Component Model component text/binary
  - component definitions
  - component instances
  - imports/exports at component level
  - core modules embedded inside components
  - Canonical ABI lift/lower adapters
        |
        v
Core WebAssembly modules
  - type/import/function/table/memory/global/export/start/elem/code/data sections
  - ordinary WAST `(module ...)` text
  - Starshine's current binary decode, validation, optimizer, and fuzzing surfaces
```

The important phrase is **embedded inside**. A component may carry a core module, but a core module alone is not a component. Starshine owns the bottom box today. The Component Model adds at least two boundaries that Starshine does not currently represent:

1. **Interface boundary:** WIT packages, interfaces, and worlds describe typed imports/exports at a language-neutral level. WIT is not a Core WebAssembly instruction language.
2. **Canonical ABI boundary:** `lift` / `lower` operations bridge component functions to core functions by specifying how strings, records, variants, lists, resources, and other interface types move through core memories and functions.

## Current Starshine Evidence

| Starshine layer | Current evidence | Component Model interpretation |
| --- | --- | --- |
| Core module representation | [`src/lib/types.mbt`](../../src/lib/types.mbt) defines `Module` as ordinary core sections: type, import, function, table, memory, global, export, start, element, data-count, code, data, name/custom/stringrefs, and local function annotations. | No component, WIT, world, component-instance, component-function, or Canonical ABI representation exists in the core model. |
| Binary decode | [`src/binary/decode.mbt`](../../src/binary/decode.mbt) decodes the standard core module preamble plus core sections into `Module`. | A component binary should not be treated as a core module just because both are WebAssembly-family artifacts. A future component decoder needs its own policy and tests. |
| WAST parser/harness | [`src/wast/parser.mbt`](../../src/wast/parser.mbt) parses `module` commands, quoted/binary modules, `register`, `invoke`, and static assertions over module definitions. | No `(component ...)` grammar, WIT parser, component instance syntax, or component assertion harness exists. |
| Validation | [`src/validate/validate.mbt`](../../src/validate/validate.mbt) and [`src/validate/typecheck.mbt`](../../src/validate/typecheck.mbt) validate Core module declarations and function bodies. | They do not validate component imports/exports, worlds, adapter graph correctness, or Canonical ABI lowering. |
| Generator / fuzzing | [`src/validate/gen_valid.mbt`](../../src/validate/gen_valid.mbt) has local feature gates for Core/proposal-shaped surfaces such as GC, tail calls, exceptions, SIMD, relaxed SIMD, atomics, bulk memory, multi-memory, memory64, extended const, and reference types. | There is no Component Model or WIT gate; generated valid Core modules are not generated components. |
| Node package | [`tooling/node-package-surface.md`](tooling/node-package-surface.md) documents a partial ESM boundary for Starshine's current binary/text/validation/command toolkit. | The package does not expose WIT parsing, component composition, WASI Preview 2 component adapters, or Canonical ABI helpers. |

## Concrete Examples

### Core module shape Starshine can reason about

```wat
(module
  (func $add (param i32 i32) (result i32)
    local.get 0
    local.get 1
    i32.add)
  (export "add" (func $add)))
```

This is in Starshine's normal lane: WAST can parse and lower it, the core model stores a `Module`, the binary codec can encode/decode equivalent bytes, validation checks the function body and export, and optimizer passes can reason about the body with the usual trap/effect/index invariants.

### Component-shaped idea that is out of scope today

```wat
(component
  (core module $m
    (func (export "add") (param i32 i32) (result i32)
      local.get 0 local.get 1 i32.add))
  ;; real components also connect imports, instances, functions, and Canonical ABI adapters
)
```

Do not add this as a normal Starshine WAST fixture and expect the existing parser or validator to own it. A focused component slice would first need a component text/binary representation and a policy for embedded core modules. If the goal is only to test the core `$m` module, extract the `(core module ...)` payload into an ordinary Core module fixture and state that the test is not component coverage.

### WIT is an interface description, not a replacement for WAST

```wit
package example:math;

interface ops {
  add: func(a: u32, b: u32) -> u32;
}

world calculator {
  export ops;
}
```

This describes a component interface/world. It does not contain a Core WebAssembly function body and should not be routed through Starshine's WAST parser, binary module decoder, or Core module validator. A future WIT-facing Starshine API would be a new package/tooling surface.

## Correct Routing For Future Work

Use this decision table before filing or accepting component-shaped work:

| Request or evidence | Route it as | Do not claim |
| --- | --- | --- |
| A `.wasm` file that is actually a Core module | Ordinary Starshine binary decode/validation/optimization evidence. | Component Model support. |
| A component binary, `.wit`, `.wac`, or WASI Preview 2 component adapter request | New Component Model boundary/design work. | A small WAST syntax gap or ordinary module-section bug without source review. |
| A runtime/tool says it supports components | Implementation-availability evidence; use [`tooling/external-validator-adapters.md`](tooling/external-validator-adapters.md) style classification if comparing tools. | Standards status, Starshine support, or pass-oracle parity. |
| A component embeds a Core module that Starshine can decode when extracted | Core-module subset evidence only. | Whole-component validation, composition, Canonical ABI, or WIT support. |
| A Node package consumer asks for WIT or Preview-2 helpers | Public API design request tied to [`tooling/node-package-surface.md`](tooling/node-package-surface.md) and release policy. | Existing wrapper drift inside `./wast` or `./validate`. |

## Implementation Readiness Checklist

If Starshine intentionally adds Component Model support later, the first design should answer these questions before code lands:

1. **Input formats:** Will Starshine accept component binaries, component text, WIT, WAC/composition files, or only extracted Core modules?
2. **Representation:** Is there a new component AST beside `@lib.Module`, or does component support live outside the optimizer entirely?
3. **Core-module extraction:** Which APIs safely extract embedded Core modules, and how is provenance preserved when reporting diagnostics or optimizer rewrites?
4. **Validation:** Which component validation rules are checked locally, which are delegated to an external tool, and how are errors classified separately from Core module validation errors?
5. **Canonical ABI:** Are lift/lower adapters modeled, generated, or ignored? How are interface strings/lists/resources represented without confusing them with Core GC/stringref instructions?
6. **Fuzzing:** Does GenValid grow a component generator, or do component tests stay in a separate adapter suite?
7. **Node/public API:** Which export subpath owns WIT/component APIs, and how are package tests and release artifacts updated?
8. **Optimizer boundary:** Are optimizer passes allowed to rewrite embedded Core modules independently, or must they preserve component-level import/export/canonical-adapter contracts?

Until those questions have answers and tests, keep component artifacts out of ordinary Starshine pass signoff and Core-module conformance claims.

## Sources

- Focused source bridge: [`raw/wasm/2026-06-05-component-model-boundary-refresh.md`](raw/wasm/2026-06-05-component-model-boundary-refresh.md)
- Broad active-proposal routing bridge: [`raw/wasm/2026-06-04-webassembly-active-proposal-routing-current-refresh.md`](raw/wasm/2026-06-04-webassembly-active-proposal-routing-current-refresh.md)
- Feature-status router: [`wasm-feature-status-and-proposal-boundaries.md`](wasm-feature-status-and-proposal-boundaries.md)
- Core module map: [`binary/module-section-map.md`](binary/module-section-map.md), [`binary/function-import-export-and-code-sections.md`](binary/function-import-export-and-code-sections.md)
- Local implementation anchors: [`../../src/lib/types.mbt`](../../src/lib/types.mbt), [`../../src/binary/decode.mbt`](../../src/binary/decode.mbt), [`../../src/wast/parser.mbt`](../../src/wast/parser.mbt), [`../../src/validate/gen_valid.mbt`](../../src/validate/gen_valid.mbt)
