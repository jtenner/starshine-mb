# Dew runtime boundary

The raw FFI exposes Core instruction constructors. The temporary text runtime
dispatcher is a separate compatibility surface; it must not grow into a second
implementation of Dew library algorithms.

`dew_bytes_load_u8x16` and `dew_string_load_u8x16` are intentionally unsupported
by that dispatcher. Dew now owns the bounds check and logical-byte-to-vector
algorithm. This does not remove Core `v128.load`, lane instructions, or array
instructions. Text storage access and builder support still remain in the
temporary dispatcher.

The provider test checks that a removed name neither selects a runtime function
nor appends one to the function table. The public FFI method signatures are
unchanged by this removal.

Sources: [runtime dispatcher](../../../src/ffi_bridge/text_runtime.mbt),
[boundary tests](../../../src/ffi_bridge/ffi_bridge_test.mbt).
