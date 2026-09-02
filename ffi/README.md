# Generated WasmGC FFI exports

This workspace contains the generated `jtenner/starshine-ffi/ffi` foreign-library package. It forwards every concrete public function from Starshine's importable MoonBit packages and roots each forwarding function as a WasmGC export.

Build the final module at `dist/ffi/starshine-ffi.wasm`:

```sh
bun ffi build
```

Regenerate source and export metadata after public API changes:

```sh
bun ffi generate
```

Verify checked-in artifacts are current:

```sh
bun ffi check
```

Naming rules:

- methods use `Type::method` when that name is unique across packages;
- colliding methods use `package::Type::method`;
- top-level functions use `package::function`;
- instantiated trait methods use `Trait::Implementer::method`;
- colliding implementer names use `Trait::package::Implementer::method`;
- generated MoonBit wrapper identifiers are implementation details.

The generator reads `pub impl Trait for Type` declarations from every importable Starshine `.mbti` file. It resolves Starshine traits plus the public `Show`, `Eq`, `Hash`, and `Arbitrary` dependency traits, substitutes each concrete implementing type for `Self`, and emits one WasmGC wrapper per trait method and implementer.

Generic impl patterns such as `Decode for T?` and `Match for Array[T]` are instantiated only for matching concrete types that occur in public API signatures and satisfy their trait constraints. This keeps generation finite instead of inventing recursive types indefinitely.

Standalone generic functions, inaccessible private implementing types, and public signatures that expose non-public types remain listed in `src/ffi/unsupported.generated.json` and require explicit concrete wrappers or API changes.

The compiler first exports C-safe wrapper names. The JavaScript build step rewrites only the Wasm export-section strings to the linker-facing names above; function indices and WasmGC signatures are unchanged.

The `jtenner/starshine/ffi_bridge` package provides the small typed bridges needed by WasmGC consumers that cannot directly construct MoonBit generic arrays or inspect MoonBit `Result` values. It exposes mutable builders for the compiler-facing `ValType`, `RecType`, `TypeIdx`, `Instruction`, and `Func` arrays, an empty `Module` constructor, validation, and an `EncodedModule` byte inspector. These are object-model bridges, not a second command language.

Engine-state fuzz consumers should call the host-safe aggregate entry point rather than the raw `GenValidConfig` and `Result` exports:

```text
ffi_bridge::generate_engine_state_case(root_seed: i64, case_index: i32)
  -> EncodedEngineStateCase
```

Case indexes are one-based. `EncodedEngineStateCase` exposes `is_ok`, root/case seed, case index, selected-profile bytes, generator attempts, static instruction count, outcome and failure-family metadata, module bytes, optional support-module bytes, and diagnostic bytes through scalar accessors. JavaScript must pass the root seed as a `BigInt`; use `BigInt.asUintN(64, value)` when reading either unsigned seed accessor. The bridge selects the leaf from the exact `engine-state-all` 80-case cycle and uses the same public case-seed derivation as CLI batch emission. Thirty leaves include the original execution cases plus forced semantic, resource, decoder, cross-instance, and Core 3 capability shapes.

The main byte-lifting calls are:

```text
EncodedEngineStateCase::module_byte_length
EncodedEngineStateCase::module_byte_at
EncodedEngineStateCase::support_module_byte_length
EncodedEngineStateCase::support_module_byte_at
EncodedEngineStateCase::outcome_kind_byte_length
EncodedEngineStateCase::outcome_kind_byte_at
EncodedEngineStateCase::error_byte_length
EncodedEngineStateCase::error_byte_at
```

From this repository, Node can instantiate the distributable with the shared WasmGC runtime loader:

```js
import fs from "node:fs/promises";
import { instantiateWasmGcBytes } from "../node/internal/runtime.js";

const ffi = await instantiateWasmGcBytes(
  await fs.readFile(new URL("../dist/ffi/starshine-ffi.wasm", import.meta.url)),
);
const generated = ffi["ffi_bridge::generate_engine_state_case"](0x5eedn, 1);
if (!ffi["EncodedEngineStateCase::is_ok"](generated)) {
  const length = ffi["EncodedEngineStateCase::error_byte_length"](generated);
  const bytes = Uint8Array.from(
    { length },
    (_, index) => ffi["EncodedEngineStateCase::error_byte_at"](generated, index),
  );
  throw new Error(new TextDecoder().decode(bytes));
}
const length = ffi["EncodedEngineStateCase::module_byte_length"](generated);
const moduleBytes = Uint8Array.from(
  { length },
  (_, index) => ffi["EncodedEngineStateCase::module_byte_at"](generated, index),
);
```

`src/ffi/exports.generated.mbt`, `src/ffi/export-names.generated.json`, `src/ffi/moon.pkg`, and `src/ffi/unsupported.generated.json` are generated files and should not be edited manually.
