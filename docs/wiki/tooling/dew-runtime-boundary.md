# Dew runtime boundary

The raw FFI exposes Core instruction constructors. The temporary text runtime
dispatcher is a separate compatibility surface; it must not grow into a second
implementation of Dew library algorithms.

`dew_bytes_load_u8x16` and `dew_string_load_u8x16` are intentionally unsupported
by that dispatcher. Dew now owns the bounds check and logical-byte-to-vector
algorithm. This does not remove Core `v128.load`, lane instructions, or array
instructions. Builder storage operations still remain in the
temporary dispatcher.

`dew_bytes_byte_length` is also removed. Dew binds its checked primitive Bytes
heap to the Core `struct.get` instruction with physical field immediate 2.
The provider no longer builds a separate length function. This does not
remove the Core field-read constructor or builder operations.

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
Core operation and no longer selects `dew_string_view_as_bytes`.
`dew_bytes_to_string_unchecked` and the final shared rewrap helper are now
removed too. Dew checks UTF-8 before checked Bytes-to-String conversion; the
raw Core cast itself does not validate text. These changes remove the text
conversion compatibility entries, not the remaining storage algorithms.

StringBuilder append, append-view, and append-ASCII now use Dew functions too.
A private typed Core `ref.cast` exposes the same mutable builder as BytesBuilder;
it does not copy storage or reset consumed state. Dew converts String or StringView
with the existing raw text casts and checks the ASCII range before byte append.
The three `dew_string_builder_append`, `dew_string_builder_append_view`, and
`dew_string_builder_append_ascii` dispatcher entries are removed. The remaining
append helpers serve BytesBuilder only. Byte copying, growth, scalar encoding,
capacity allocation, and finish still need migration; this does not close that work.

Bytes views now use an ordinary Dew function with a declared V128-array/start/
length struct. Typed Core casts preserve the shared backing array. Dew checks
the logical range and start addition before constructing the result. The old
`dew_bytes_view` dispatcher entry and its private body builder are removed.
String/StringView slicing follows the same storage path described below;
builder storage remains separate work.

String and StringView range functions now use the checked Dew Bytes view and
perform their UTF-8 boundary checks in Dew. The end of the source is a valid
boundary without a byte read. This also fixes empty views at an exact V128
array boundary: the former runtime tried to read the next array element.
The `dew_string_view` and `dew_string_view_view` entries and shared private
body builder are removed. Builder algorithms still remain.

Bytes byte access now also runs in Dew over declared array/start/length fields.
It checks the logical index and start addition, then uses Core array and lane
instructions. The preamble reaches this body through an ordinary private import;
ordering and Facet use library calls too. `dew_bytes_byte_at` and its separate
body builder are removed. The internal byte-copy helper remains only for the
builder algorithms that have not moved yet.

The public FFI method signatures are unchanged by these removals.

Sources: [runtime dispatcher](../../../src/ffi_bridge/text_runtime.mbt),
[boundary tests](../../../src/ffi_bridge/ffi_bridge_test.mbt).
