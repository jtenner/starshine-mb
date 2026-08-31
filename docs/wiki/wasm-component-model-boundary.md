---
kind: concept
status: supported
last_reviewed: 2026-08-30
sources:
  - https://nodejs.org/api/wasi.html
  - https://github.com/WebAssembly/WASI
  - https://wasi.dev/roadmap
  - https://component-model.bytecodealliance.org/
  - https://github.com/WebAssembly/proposals
  - https://github.com/WebAssembly/component-model
  - https://github.com/WebAssembly/component-model/blob/main/design/mvp/Explainer.md
  - https://component-model.bytecodealliance.org/design/wit.html
  - https://component-model.bytecodealliance.org/advanced/canonical-abi.html
  - https://github.com/WebAssembly/proposals
  - ../../src/lib/types.mbt
  - ../../src/binary/decode.mbt
  - ../../src/wast/parser.mbt
  - ../../src/validate/gen_valid.mbt
  - ../../src/lib/pkg.generated.mbti
  - ../../component/wit/core-ir.generated.wit
  - ../../scripts/lib/core-ir-generation.ts
  - ../../scripts/test/component-consumer-smoke.mjs
related:
  - tooling/wasi-runner-and-preview-boundary.md
  - wasm-feature-status-and-proposal-boundaries.md
  - binary/module-section-map.md
  - binary/function-import-export-and-code-sections.md
  - wast/static-assertion-harness.md
  - tooling/node-package-surface.md
  - wasm-esm-integration-boundary.md
  - tooling/external-validator-adapters.md
---

# WebAssembly Component Model Boundary

## Overview

Use this page when a bug report, fixture idea, package request, or external tool result mentions the **WebAssembly Component Model**, **WIT**, **worlds**, **WASI Preview 2 / WASI 0.2**, **WASI Preview 3 / WASI 0.3**, or the **Canonical ABI**. These are related to WebAssembly, but they are not the same artifact as the Core WebAssembly modules Starshine currently parses, validates, optimizes, fuzzes, and packages.

For a beginner: a Core WebAssembly module is the familiar `module` with functions, memories, tables, globals, imports, exports, code, data, and custom sections. A Component Model component is a higher-level packaging and interoperability layer. It can contain Core modules, but it also describes interfaces, instances, lifted/lowered functions, and host-language data passing through the Canonical ABI.

The official proposal tracker, Component Model repository/MVP explainer, WIT and Canonical ABI documentation, the [WASI roadmap](https://wasi.dev/roadmap), the [Node `node:wasi` API](https://nodejs.org/api/wasi.html), and current Starshine source evidence support the following durable status:

- **Standards status:** the Component Model remains under active standardization and incremental stabilization, with WIT and the Canonical ABI defined in the Component Model repository and user-facing documentation.
- **Starshine status:** Starshine now has a focused **producer/export facade** under [`../../component/`](../../component/). It generates MoonBit Canonical ABI bindings from [`../../component/wit/starshine.wit`](../../component/wit/starshine.wit), builds a validated component, and exports metadata, byte/text module operations, and a generated resource-backed API for constructing complete Core modules. Starshine still does not parse, represent, validate, optimize, or rewrite arbitrary component binaries or component text internally.
- **Boundary rule:** do not cite the export facade as general component parsing/validation support, and do not cite Starshine acceptance of Core WebAssembly modules as evidence that its ordinary WAST/binary/validator path accepts component artifacts.

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
| Node package | [`tooling/node-package-surface.md`](tooling/node-package-surface.md) documents the ESM-first JavaScript wrapper and raw WasmGC adapter boundary; [`tooling/wasi-runner-and-preview-boundary.md`](tooling/wasi-runner-and-preview-boundary.md) documents the Preview 1 Core-module runner; Wasm ESM Integration is routed separately through [`wasm-esm-integration-boundary.md`](wasm-esm-integration-boundary.md). | The raw Node WasmGC artifact remains JS-adapter-specific. The portable WIT component is a separate build from the same source packages, not a WIT description of MoonBit GC-reference exports. |
| Component export facade | [`../../component/wit/starshine.wit`](../../component/wit/starshine.wit), generated [`../../component/wit/core-ir.generated.wit`](../../component/wit/core-ir.generated.wit), [`../../component/README.md`](../../component/README.md), and [`../../scripts/lib/component-task.ts`](../../scripts/lib/component-task.ts) define and automate a generated component producer. | Focused language-neutral consumption exists for `metadata`, `modules`, and resource-backed Core-module construction through `core-ir`; arbitrary component input, component composition, component text, embedded-core rewrite support, and optimizer-internal IR remain outside the facade. |

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

## Implemented Portable Export Facade

The checked-in WIT package is `jtenner:starshine-component@0.1.1`, world `starshine`:

- `metadata` exports the Starshine version, implementation target, and capability descriptions.
- `modules` exchanges only portable WIT values: strings, `list<u8>`, records, enums, and `result` diagnostics.
- `core-ir` uses WIT resources as portable opaque handles to recursive Core Wasm values stored inside the component. Its generated contract currently contains 88 resources and 852 typed constructors reachable from `@lib.Module`. Package-qualified representation-owned parameters are omitted from the `@lib`-rooted constructor graph, so the component does not construct `compiler.facts` records directly.
- `core-ir.empty-module`, section/type/index/instruction constructors, and immutable `module.with-*` methods build arbitrary Core modules from scratch; `parse-module` and `decode-module` enter the same resource model from existing inputs, while `validate-module` and `encode-module` produce checked output.
- `modules.available-generator-profiles` exposes every canonical Starshine GenValid profile name.
- `modules.generate-valid-wasm` accepts a profile plus `u64` seed, deterministically resolves aggregate profiles to a leaf, generates and validates a Core module, and returns encoded bytes plus resolved-profile and attempt metadata.
- `modules.available-passes` derives its catalog from the authoritative Starshine registry and exposes every active function pass, module pass, and preset while excluding boundary-only and removed entries.
- `modules.validate-wasm` decodes and validates a Core module.
- `modules.roundtrip-wasm` decodes, validates, and re-encodes a Core module.
- `modules.wat-to-wasm` parses WAT/WAST module text, validates it, and encodes Core Wasm.
- `modules.optimize-wasm` runs a preset and/or additional named Starshine passes with explicit pipeline options.

WIT forbids recursively defined value types, so the facade does not copy `@lib.Module` or recursive instruction trees as records/variants. Instead, generated `core-ir` resources preserve typed construction while keeping the actual MoonBit values internal. This exposes the complete public Core module constructor graph without exposing MoonBit GC references. Optimizer-only `HotFunc`, CFG, SSA, analysis overlays, and mutation APIs remain intentionally excluded because they have different lifecycle and stability contracts. GenValid generation and Core IR encoding both produce Core Wasm bytes, not arbitrary Component Model binaries.

The component uses `gen_valid_module_from_seed(...)`, a lightweight public GenValid result path that preserves the generated module, config label, and attempt count without computing the exhaustive `GenValidFeatureFacts` ledger. The full in-process generator API still layers feature-fact collection on the same deterministic result. This separation is required for linear-Wasm consumers because the exhaustive opcode-count matcher compiles to a function exceeding V8's per-function local limit, while module generation itself remains component-compatible.

Build automation is `bun component <generate|build|check>`. It derives `core-ir.generated.wit` and `core_ir.generated.mbt` from `src/lib/pkg.generated.mbti`, pins `wit-bindgen-cli` `0.60.0`, generates into a staging directory, resolves the parent checkout through `component/moon.work`, copies implementations into generated interface packages, directly type-checks the generated Core IR package, builds the fully qualified `jtenner/starshine-component/gen` output with MoonBit target `wasm`, embeds Canonical ABI string encoding `utf16` to match MoonBit's `init_array16` representation, validates the intermediate and final artifacts with `wasm-tools`, and extracts the built WIT to `dist/component/starshine.wit`.

The target choice is deliberate. Current MoonBit `wit-bindgen` output implements the MVP Canonical ABI with linear-memory helpers and links for target `wasm`; copying those exports to `wasm-gc` fails against different MoonBit runtime internals. The raw WasmGC module's GC/reference ABI is therefore not advertised as WIT. Both artifacts execute Starshine source code, but they are distinct ABI products.

The linear build retains MoonBit filesystem/time imports through transitive packages even though the public component world grants no such capabilities. The build prints named WAT, removes only the exact known imports, and relocates deterministic fail-closed local definitions after all retained Component Model resource imports; symbolic references let the WAT parser recompute function indices safely. Generation fails if a known import changes or a new `__moonbit_*_unstable` import appears. External consumer smoke on August 15, 2026 used Jco `1.28.1` to generate JavaScript/TypeScript bindings and successfully called version/capability discovery, generator-profile discovery, deterministic generation with a JavaScript `BigInt` seed, generated-module validation, generation diagnostics, pass discovery, WAT conversion, binary roundtrip, a real optimizer preset, and typed construction/validation/encoding of a `() -> i32` Core module through `core-ir` resources.

## Correct Routing For Future Work

Use this decision table before filing or accepting component-shaped work:

| Request or evidence | Route it as | Do not claim |
| --- | --- | --- |
| A `.wasm` file that is actually a Core module | Ordinary Starshine binary decode/validation/optimization evidence. | Component Model support. |
| A component binary, `.wit`, `.wac`, WASI Preview 2 / WASI 0.2 component adapter request, or WASI Preview 3 / WASI 0.3 native-async API request | New Component Model boundary/design work, with Preview 1 runner separation through [`tooling/wasi-runner-and-preview-boundary.md`](tooling/wasi-runner-and-preview-boundary.md). | A small WAST syntax gap, ordinary module-section bug, or existing `wasi_snapshot_preview1` runner feature without source review. |
| A runtime/tool says it supports components | Implementation-availability evidence; use [`tooling/external-validator-adapters.md`](tooling/external-validator-adapters.md) style classification if comparing tools. | Standards status, Starshine support, or pass-oracle parity. |
| A component embeds a Core module that Starshine can decode when extracted | Core-module subset evidence only. | Whole-component validation, composition, Canonical ABI, or WIT support. |
| A consumer asks for the declared Starshine WIT operations or Core module construction | Route to [`../../component/README.md`](../../component/README.md), `component/wit/starshine.wit`, generated `component/wit/core-ir.generated.wit`, and the validated component artifact. | General component parsing, a direct wrapper around the raw WasmGC ABI, optimizer-internal HOT/CFG/SSA access, or arbitrary MoonBit object exposure. |
| A Node package consumer asks for additional WIT, composition, or Preview-2 helpers | New public API design tied to the component facade, [`tooling/node-package-surface.md`](tooling/node-package-surface.md), and release policy. | Existing wrapper drift inside `./wast` or `./validate`. |
| A consumer asks to import `.wasm` from JavaScript with `import source` or an instance-phase `.wasm` import | Wasm ESM Integration / Node package loader design through [`wasm-esm-integration-boundary.md`](wasm-esm-integration-boundary.md). | Component Model, WIT, or Canonical ABI support. |

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

The focused export facade answers these questions only for its declared world. Keep arbitrary component artifacts out of ordinary Starshine pass signoff and Core-module conformance claims, and treat any expansion beyond `metadata`, `modules`, and the generated `core-ir` constructor graph as a new public WIT design slice with generated-binding, artifact-validation, and consumer tests.

## Sources

- Component Model sources: <https://github.com/WebAssembly/proposals>, <https://github.com/WebAssembly/component-model>, <https://github.com/WebAssembly/component-model/blob/main/design/mvp/Explainer.md>, <https://component-model.bytecodealliance.org/design/wit.html>, and <https://component-model.bytecodealliance.org/advanced/canonical-abi.html>.
- Shared Core/proposal status source: [WebAssembly proposals tracker](https://github.com/WebAssembly/proposals)
- Feature-status router: [`wasm-feature-status-and-proposal-boundaries.md`](wasm-feature-status-and-proposal-boundaries.md)
- WASI runner / Preview boundary: [`tooling/wasi-runner-and-preview-boundary.md`](tooling/wasi-runner-and-preview-boundary.md), [Node `node:wasi`](https://nodejs.org/api/wasi.html), [WebAssembly/WASI](https://github.com/WebAssembly/WASI), and the [WASI roadmap](https://wasi.dev/roadmap)
- ESM Integration boundary: [`wasm-esm-integration-boundary.md`](wasm-esm-integration-boundary.md)
- Core module map: [`binary/module-section-map.md`](binary/module-section-map.md), [`binary/function-import-export-and-code-sections.md`](binary/function-import-export-and-code-sections.md)
- Local implementation anchors: [`../../src/lib/types.mbt`](../../src/lib/types.mbt), [`../../src/binary/decode.mbt`](../../src/binary/decode.mbt), [`../../src/wast/parser.mbt`](../../src/wast/parser.mbt), [`../../src/validate/gen_valid.mbt`](../../src/validate/gen_valid.mbt)
