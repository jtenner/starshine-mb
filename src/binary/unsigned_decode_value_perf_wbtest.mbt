///|
fn unsigned_decode_value_bench(
  it : @bench.T,
  bytes : Bytes,
  wide : Bool,
) -> Unit {
  it.bench(fn() {
    if wide {
      it.keep(
        (Decode::decode(bytes, 0) : Result[(U64, Int), BinaryDecodeError]),
      )
    } else {
      it.keep(
        (Decode::decode(bytes, 0) : Result[(LocalIdx, Int), BinaryDecodeError]),
      )
    }
  })
}

///|
test "bench unsigned index single byte" (it : @bench.T) {
  unsigned_decode_value_bench(it, b"\x01", false)
}

///|
test "bench unsigned index maximum value" (it : @bench.T) {
  unsigned_decode_value_bench(it, b"\xff\xff\xff\xff\x0f", false)
}

///|
test "bench unsigned index permitted padded zero" (it : @bench.T) {
  unsigned_decode_value_bench(it, b"\x80\x80\x80\x80\x00", false)
}

///|
test "bench unsigned 64 maximum value" (it : @bench.T) {
  unsigned_decode_value_bench(
    it, b"\xff\xff\xff\xff\xff\xff\xff\xff\xff\x01", true,
  )
}

///|
test "bench unsigned index truncated input control" (it : @bench.T) {
  unsigned_decode_value_bench(it, b"\x80", false)
}

///|
test "bench unsigned 64 unused terminal bits control" (it : @bench.T) {
  unsigned_decode_value_bench(
    it, b"\x80\x80\x80\x80\x80\x80\x80\x80\x80\x02", true,
  )
}
