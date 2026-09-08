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

The global propagation pass is also available through
`passes::propagate_globals_globally_run_module_pass(Module) -> Module` and
`passes::propagate_globals_globally_summary() -> String`. Its generated wrappers
must be kept with the export-name metadata when regenerating the provider.

The `jtenner/starshine/ffi_bridge` package provides the small typed bridges needed by WasmGC consumers that cannot directly construct MoonBit generic arrays or inspect MoonBit `Result` values. It exposes mutable builders for the compiler-facing `ValType`, `RecType`, `TypeIdx`, `Instruction`, and `Func` arrays, an empty `Module` constructor, validation, and an `EncodedModule` byte inspector. These are object-model bridges, not a second command language.

The legacy runtime builder no longer emits `dew_wasi_fd_read` or
`dew_wasi_fd_write`. Dewdrop's Bytes I/O loops now belong to the Dew library and
call raw foreign declarations. The unused private test-assertion body is also
removed; test assertion output uses a normal Dew function and its Bytes write
loop. `runtime_function_builder_new` has no read-function index parameter. Its
write index remains only for Debug text formatting until that migration is
complete. See the
[bridge boundary test](../src/ffi_bridge/ffi_bridge_test.mbt) and the
[runtime dispatcher](../src/ffi_bridge/text_runtime.mbt).

The eight `dew_debug_i8/i16/i32/i64/u8/u16/u32/u64` runtime operations are also
removed. Dew owns integer formatting, sign/width normalization, and bounded
partial-write handling. The existing bridge boundary tests require those names
to stay unsupported. The `dew_debug_f32` and `dew_debug_f64` runtime operations
are removed too. Dew formats exact float bits using one-to-one Wasm reinterpret
operations and the bounded write loop. `dew_debug_v128` is removed as well:
Dew reads the two lanes with one-to-one Wasm instructions and writes the high
lane first. Text formatters still await their library migration; this does not
remove their remaining write dependency.

The removed `dew_array_*` operations and the three
`instructions_push_array_push/pop/iter_next` exports are no longer provided.
Array allocation, mutation, and iteration belong to ordinary Dew functions.
The runtime boundary tests reject all old Array operation names. The old
`dew_map_*` operations and their private Array layout helpers are removed too.
Map storage and lookup use Dew library functions. `runtime_function_builder_new`
accepts only the text type base and write-function index; collection carrier
codes and Option layout arguments no longer exist. Its UTF-8-validator argument
is removed with the old checked Bytes conversion runtime.

Bytes equality, hash, searches, affixes, concatenation, UTF-8 validation, and
checked String conversion are no longer provider runtime operations. Their
ordinary Dew implementations own these algorithms. Bytes storage and unchecked
representation casts are separate migration work.

The 13 old String access, equality, hash, UTF-16 length, search, affix, and
concatenation runtime operations are removed too. Ordinary Dew functions and
selected trait evidence provide these behaviors. The 12 old StringView access,
conversion, UTF-16 length, equality, hash, search, and affix operations are also
removed, with all unused shared text algorithm builders. Text storage, SIMD
storage access, and Debug formatting remain for separate migration. The
two-argument provider constructor is unchanged.

Engine-state fuzz consumers should call the host-safe aggregate entry point rather than the raw `GenValidConfig` and `Result` exports:

```text
ffi_bridge::generate_engine_state_case(root_seed: i64, case_index: i32)
  -> EncodedEngineStateCase
```

Case indexes are one-based. `EncodedEngineStateCase` exposes `is_ok`, root/case seed, case index, selected-profile bytes, generator attempts, static instruction count, outcome and failure-family metadata, module bytes, zero or more ordered support modules, an optional equivalent comparison module, and diagnostic bytes through scalar accessors. JavaScript must pass the root seed as a `BigInt`; use `BigInt.asUintN(64, value)` when reading either unsigned seed accessor. The bridge selects the leaf from the exact `engine-state-all` 136-case cycle and uses the same public case-seed derivation as CLI batch emission. Forty-five leaves include the original execution cases plus forced semantic, resource, decoder, cross-instance, proposal, link-graph, initialization-graph, exception-unwind, type/call, LEB/index, table-reference, mixed-address-memory, trap-commit, metamorphic, compiler-boundary, NaN, invalid-binary, bounded-recursion/multi-value, and GC subtype-cast shapes.

Support modules are in instantiation order. Import each later module from the
previous module's `__link` exports, then import the final support exports into
the primary module. The singular support accessors remain as compatibility
aliases for support module zero. A non-empty comparison module is a distinct
encoding that must produce the same canonical result as the primary module.
The invalid-module profile mutates the encoded bytes after valid AST generation
and reports an expected `compile-failure` family.

The main byte-lifting calls are:

```text
EncodedEngineStateCase::module_byte_length
EncodedEngineStateCase::module_byte_at
EncodedEngineStateCase::support_module_byte_length
EncodedEngineStateCase::support_module_byte_at
EncodedEngineStateCase::support_module_count
EncodedEngineStateCase::support_module_indexed_byte_length
EncodedEngineStateCase::support_module_indexed_byte_at
EncodedEngineStateCase::comparison_module_byte_length
EncodedEngineStateCase::comparison_module_byte_at
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
