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
StringBuilder still uses the shared temporary length builder.

The provider test checks that a removed name neither selects a runtime function
nor appends one to the function table. The public FFI method signatures are
unchanged by this removal.

Sources: [runtime dispatcher](../../../src/ffi_bridge/text_runtime.mbt),
[boundary tests](../../../src/ffi_bridge/ffi_bridge_test.mbt).
