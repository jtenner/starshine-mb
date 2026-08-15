# Starshine WebAssembly Component

This directory turns Starshine's Core WebAssembly toolkit into a portable WebAssembly Component Model artifact with a checked-in WIT contract.

## Beginner Mental Model

- **WIT** is an interface definition language: it describes portable function names, parameters, results, records, enums, and errors, but not function bodies.
- An **interface** groups related types and functions. This package exports `metadata`, `modules`, and `core-ir`.
- A **resource** is an opaque, owned handle to state stored inside the component. Resources let WIT represent recursive structures without trying to copy a recursive value graph across the boundary.
- A **world** is the complete contract of one component: what it imports and exports. World `starshine` imports nothing and exports all three interfaces.
- The **Canonical ABI** defines how WIT values such as strings and byte lists are lowered into a Core Wasm module's memory and lifted back into consumer-language values.
- A **component** packages Core Wasm code together with its typed world. Consumer tools read that world and generate native-looking Rust, JavaScript, TypeScript, or other language bindings.

The build flow is:

```text
starshine.wit -> wit-bindgen MoonBit glue -> linear Core Wasm
               -> embed typed world -> component Wasm
               -> consumer bindgen -> language-native API
```

## Important Target Boundary

The component is built from the same Starshine MoonBit sources as the `wasm-gc` build, but it is **not** a WIT wrapper around the existing raw WasmGC binary.

MoonBit's current `wit-bindgen` guest bindings implement the Canonical ABI with linear memory and are generated for the `wasm` target. The raw WasmGC artifact exposes MoonBit GC/reference values that WIT cannot describe directly. Consumers should therefore use:

- the raw `wasm-gc` artifact through the existing JavaScript adapter when they specifically need MoonBit's JS/GC ABI; or
- `starshine.component.wasm` and this WIT world for language-neutral Component Model bindings.

## Public World

[`wit/starshine.wit`](./wit/starshine.wit) defines world `starshine` with three exported interfaces:

- `metadata`: version, implementation target, and portable capability discovery;
- `modules`: discover every GenValid profile and active optimizer pass/preset, generate deterministic valid Core Wasm, validate Wasm, decode/validate/re-encode Wasm, parse WAT/WAST module text to Wasm, and run preset or named Starshine optimizer passes;
- `core-ir`: construct complete Core WebAssembly modules from typed resources covering every module section, reachable core type, and instruction constructor in Starshine's public `lib` API, then validate or encode the result.

`metadata` and `modules` exchange ordinary portable WIT values. `core-ir` uses opaque WIT resources because WIT value types cannot be recursively defined: an instruction can own nested expressions, and expressions contain instructions. The resource handles are portable across generated language bindings while the recursive MoonBit values remain inside the component. Starshine's optimizer-only `HotFunc`, CFG, SSA, analysis overlays, and mutation APIs are intentionally not part of this public world.

## Module Generation

`modules.available-generator-profiles()` returns every canonical Starshine GenValid profile name. `modules.generate-valid-wasm(...)` accepts a profile and `u64` seed, resolves aggregate profiles to a deterministic leaf profile, generates and validates a Core module, and returns its encoded bytes, resolved profile name, and generation attempt count.

The same profile and seed produce the same bytes. Different seeds provide a reproducible stream of cases. Profiles control module shape and enabled WebAssembly features; start with `natural-small` for compact general-purpose modules. Specialized pass profiles intentionally generate shapes aimed at a particular optimizer pass.

This generates **Core WebAssembly modules**, not Component Model components. The returned bytes can be passed directly to `validate-wasm`, `optimize-wasm`, or another Core Wasm tool.

## Full Core IR Construction

[`wit/core-ir.generated.wit`](./wit/core-ir.generated.wit) is generated from [`../src/lib/pkg.generated.mbti`](../src/lib/pkg.generated.mbti). The current contract contains **88 resource types and 851 typed constructors** reachable from `Module`. It covers module sections, indices, recursive type groups, imports and exports, functions and locals, globals, tables, memories, tags, elements, data segments, names/custom metadata, expressions, and the complete public instruction-constructor surface.

The top-level operations are:

- `empty-module()` for a blank module;
- typed static resource constructors such as `val-type.i32`, `instruction.i32-const`, `expr.create`, and `module.with-code-sec`;
- `parse-module(wat)` and `decode-module(wasm)` to obtain the same resource model from existing input;
- `validate-module(module)` and `encode-module(module)` for checked output.

Constructors borrow their resource arguments and return a new owned resource. `module.with-*` follows Starshine's immutable module API and returns a new module resource rather than mutating the original handle. Generated bindings expose resource destruction—for example Jco classes implement `[Symbol.dispose]()`—and consumers should dispose superseded modules and temporary resources during long-running compiler workloads. The component reuses dropped resource slots.

This is a **Core Wasm construction boundary**, not a serialization of arbitrary MoonBit objects and not an optimizer IR API. Consumers choose section and index order explicitly, just as they would when constructing a Core module in-process. `validate-module` reports cross-section, index, and instruction-typing mistakes before encoding.

## Generate And Build

From the repository root:

```bash
bun component generate
bun component build
bun component check
```

The commands install pinned `wit-bindgen-cli` `0.60.0` under `.tmp/component-tools` when `WIT_BINDGEN_BIN` or `--wit-bindgen` is not supplied.

`build` and `check` produce ignored local artifacts under `dist/component/`:

- `starshine.component.wasm`: validated component binary;
- `starshine.wit`: WIT extracted back from the built component;
- `starshine.runtime-internalized.wasm`: intermediate core module with known MoonBit runtime imports replaced by deterministic fail-closed definitions.

Useful overrides:

```bash
bun component build --wit-bindgen /path/to/wit-bindgen
bun component build --wasm-tools /path/to/wasm-tools
bun component build --moon /path/to/moon
bun component build --out-dir artifacts/component
bun component build --debug
```

## Regeneration Contract

`component/implementation/metadata.mbt` and `modules.mbt` are handwritten. `component/wit/core-ir.generated.wit` and `component/implementation/core_ir.generated.mbt` are generated from the public `lib` `.mbti`; `component/gen/` and `component/world/` are generated by `wit-bindgen`. `bun component generate` synchronizes all generated files.

The automation:

1. derives the reachable Core module constructor graph from `src/lib/pkg.generated.mbti` and generates the resource-backed WIT and MoonBit adapter;
2. generates Canonical ABI bindings in a staging directory;
3. patches the generated MoonBit module to depend on the local `jtenner/starshine` checkout;
4. copies interface implementations into the generated interface packages and type-checks the large Core IR package directly;
5. builds the Canonical ABI core module with MoonBit's linear `wasm` target;
6. prints named WAT, removes only the exact known retained MoonBit filesystem/time imports, and relocates their local stubs after every retained Component Model resource import; symbolic function references preserve behavior while WAT ordering remains valid;
7. reparses and validates the self-contained core module;
8. embeds world `starshine` with Canonical ABI string encoding `utf16`, matching MoonBit's linear string representation;
9. creates the component, validates it, and extracts its WIT for inspection.

Generation fails if a known runtime import disappears, changes shape, or a new `__moonbit_*_unstable` import appears. That makes MoonBit runtime drift an explicit maintenance event instead of silently granting host capabilities.

## Consumer Bindings

Consumers bind against [`wit/starshine.wit`](./wit/starshine.wit) or extract the equivalent contract from `starshine.component.wasm`. Use the Component Model tooling for the consumer language/runtime—for example, Wasmtime's component bindgen support for Rust or Jco for JavaScript.

The required CI release-artifact job pins Jco `1.28.1`, generates JavaScript/TypeScript bindings, and executes `scripts/test/component-consumer-smoke.mjs` against the public API. The equivalent manual flow is:

```bash
npx @bytecodealliance/jco@1.28.1 transpile \
  dist/component/starshine.component.wasm \
  -o generated/starshine
```

```js
import { coreIr, metadata, modules } from "./generated/starshine/starshine.component.js";

console.log(metadata.version());
console.table(modules.availablePasses());
console.log(modules.availableGeneratorProfiles());

const generated = modules.generateValidWasm({
  profile: "natural-small",
  seed: 0x5eedn, // WIT u64 maps to JavaScript BigInt.
});
modules.validateWasm(generated.wasm);
console.log(generated.profile, generated.attempts, generated.wasm.length);

const i32 = coreIr.ValType.i32();
const funcType = coreIr.CompType.funcValue([], [i32]);
const subtype = coreIr.SubType.compType(
  funcType,
  coreIr.TypeMetadata.create(undefined, undefined, false),
);
const typeSection = coreIr.TypeSec.create([coreIr.RecType.create(subtype)]);
const functionSection = coreIr.FuncSec.create([coreIr.TypeIdx.create(0)]);
const body = coreIr.Expr.create([
  coreIr.Instruction.i32Const(coreIr.I32.create(7)),
]);
const codeSection = coreIr.CodeSec.create([
  coreIr.FuncIr.create(coreIr.Locals.empty(), body),
]);
let constructed = coreIr.emptyModule();
constructed = coreIr.Module.withTypeSec(constructed, typeSection);
constructed = coreIr.Module.withFuncSec(constructed, functionSection);
constructed = coreIr.Module.withCodeSec(constructed, codeSection);
coreIr.validateModule(constructed);
const constructedWasm = coreIr.encodeModule(constructed);
modules.validateWasm(constructedWasm);

const wasm = modules.watToWasm('(module (func (export "run")))');
modules.validateWasm(wasm);

const optimized = modules.optimizeWasm(wasm, {
  preset: "optimize",
  additionalPasses: [],
  closedWorld: false,
  trapsNeverHappen: false,
  ignoreImplicitTraps: false,
  zeroFilledMemory: false,
  optimizeLevel: 2,
  shrinkLevel: 0,
});
```

WIT `result` errors are surfaced by Jco as `ComponentError`; the structured diagnostic is available on the error payload.

The WIT package is versioned as `jtenner:starshine-component@0.1.1`. Treat WIT changes with the same compatibility care as any public API change.
