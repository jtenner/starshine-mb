# Dew runtime boundary

The raw FFI exposes Core instruction constructors. The temporary text runtime
dispatcher is a separate compatibility surface; it must not grow into a second
implementation of Dew library algorithms.

`dew_bytes_load_u8x16` and `dew_string_load_u8x16` are intentionally unsupported
by that dispatcher. Dew now owns the bounds check and logical-byte-to-vector
algorithm. This does not remove Core `v128.load`, lane instructions, or array
instructions. Text storage access and builder support still remain in the
temporary dispatcher.

`dew_bytes_byte_length` is also removed. Dew binds its checked primitive Bytes
heap to the Core `struct.get` instruction with physical field immediate 2.
The provider no longer builds a separate length function. This does not
remove the Core field-read constructor, byte access, or builder operations.

BytesBuilder length now uses two raw scalar field reads: consumed state at 2
and logical length at 1. Dew performs the consumed-state check before reading
the length. `dew_bytes_builder_byte_length` no longer selects a runtime body.
StringBuilder now follows the same rule with its own primitive heap owner.
`dew_string_builder_byte_length` and the now-unused shared length builder are
removed. Dew owns both lifetime checks; Core field-read constructors remain.

BytesBuilder's default constructor is also a Dew function. It requests 64
bytes through the existing capacity constructor, preserving the former four
V128 chunks. `dew_bytes_builder_new` no longer selects a provider body. The
capacity allocator, growth, and finish paths remain temporary runtime support.
StringBuilder now selects the same default in Dew. Its old default entry and
the allocator's default-mode branch are removed. The remaining allocator takes
an explicit byte capacity and computes its chunk count without a library default.

The provider test checks that a removed name neither selects a runtime function
nor appends one to the function table. String-to-Bytes conversion now uses the
consumer's typed Core `ref.cast` recipe; `dew_string_as_bytes` and its wrapper
allocation helper are removed. StringView-to-Bytes now uses the same typed
Core operation and no longer selects `dew_string_view_as_bytes`. The shared
rewrap helper remains only for unchecked Bytes-to-String conversion.

The public FFI method signatures are unchanged by this removal.

Sources: [runtime dispatcher](../../../src/ffi_bridge/text_runtime.mbt),
[boundary tests](../../../src/ffi_bridge/ffi_bridge_test.mbt).
