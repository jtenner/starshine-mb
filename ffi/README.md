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

`src/ffi/exports.generated.mbt`, `src/ffi/export-names.generated.json`, `src/ffi/moon.pkg`, and `src/ffi/unsupported.generated.json` are generated files and should not be edited manually.
