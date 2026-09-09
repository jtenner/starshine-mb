# Dew runtime boundary

The raw FFI exposes Core instruction constructors. Runtime text and builder
algorithms now live in Dew library functions, not provider-generated bodies.
This includes text/Bytes access, views, conversion checks, searches, builder
allocation, growth, append, UTF-8 scalar encoding, and finish.

The retired runtime-function protocol remains only as a rejection boundary:
it creates no functions. Its public bridge methods remain until the consumer
removes the legacy physical function kind. This is not a second implementation
of any library algorithm. Boundary tests require removed names to leave the
function table unchanged.

## Library storage and checks

Bytes views use a declared V128-array/start/length struct. Builders use a
declared mutable V128-array/length/consumed struct. Explicit typed Core casts
retain shared storage and aliases; they do not reset consumed state.

Dew checks logical bounds and overflow before access or mutation. Growth uses
Core array copy. Aligned appends copy complete chunks; unaligned appends use
lane swizzles and masked writes, with exact byte tails. Finish consumes all
builder aliases and shares the backing array with the immutable result.

StringBuilder uses this same Dew storage path. Its capacity and finish
functions are ordinary wrappers. Scalar encoding rejects surrogates and
values above U+10FFFF, reserves the complete one-to-four-byte encoding before
writing, then emits its canonical UTF-8 bytes. No StringBuilder runtime entry
or private scalar-encoding body remains.

## Text identity and boundaries

Core reference casts do not validate UTF-8. Checked Bytes-to-String conversion
validates in Dew before casting; String and StringView carry that precondition.
StringView range checks use the selected logical range, not a source spelling.

The source end is a valid UTF-8 boundary without a byte read. This fixes empty
views at exact V128 array ends, where the former runtime read the next element.
Byte reads check the logical index and start addition before Core array/lane
instructions. The preamble reaches that body through an ordinary private import.

The public FFI method signatures are unchanged by these algorithm removals.
Core array, field, reference, and vector instruction constructors remain.

Sources: [retired runtime boundary](../../../src/ffi_bridge/text_runtime.mbt),
[bridge methods](../../../src/ffi_bridge/ffi_bridge.mbt),
[boundary tests](../../../src/ffi_bridge/ffi_bridge_test.mbt).
