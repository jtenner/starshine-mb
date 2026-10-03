///|
// Common buffer construction/consumption remains inside both measured paths.
fn leb_scalar_error_bench(
  it : @bench.T,
  kind : Int,
  before : Bool,
) -> Unit raise {
  let expected = @buffer.new()
  let actual = @buffer.new()
  let bits = if kind == 3 { 64 } else { 32 }
  let unsigned = if kind == 1 { 0xffffffffUL } else { 0UL }
  let signed = if kind == 3 { -1L << 63 } else { -1L }
  if kind < 2 {
    leb_scalar_original_encode_unsigned(unsigned, expected, bits).unwrap()
    assert_eq(encode_unsigned_error(unsigned, actual, bits), None)
  } else {
    leb_scalar_original_encode_signed(signed, expected, bits).unwrap()
    assert_eq(encode_signed_error(signed, actual, bits), None)
  }
  assert_eq(actual.to_bytes(), expected.to_bytes())
  it.bench(fn() {
    let buffer = @buffer.new()
    if kind < 2 {
      if before {
        it.keep(leb_scalar_original_encode_unsigned(unsigned, buffer, bits))
      } else {
        it.keep(encode_unsigned_error(unsigned, buffer, bits))
      }
    } else if before {
      it.keep(leb_scalar_original_encode_signed(signed, buffer, bits))
    } else {
      it.keep(encode_signed_error(signed, buffer, bits))
    }
    it.keep(buffer.length())
  })
}

///|
test "bench LEB scalar unsigned32 zero before" (it : @bench.T) {
  leb_scalar_error_bench(it, 0, true)
}

///|
test "bench LEB scalar unsigned32 zero current" (it : @bench.T) {
  leb_scalar_error_bench(it, 0, false)
}

///|
test "bench LEB scalar unsigned32 max before" (it : @bench.T) {
  leb_scalar_error_bench(it, 1, true)
}

///|
test "bench LEB scalar unsigned32 max current" (it : @bench.T) {
  leb_scalar_error_bench(it, 1, false)
}

///|
test "bench LEB scalar signed32 negative before" (it : @bench.T) {
  leb_scalar_error_bench(it, 2, true)
}

///|
test "bench LEB scalar signed32 negative current" (it : @bench.T) {
  leb_scalar_error_bench(it, 2, false)
}

///|
test "bench LEB scalar signed64 minimum before" (it : @bench.T) {
  leb_scalar_error_bench(it, 3, true)
}

///|
test "bench LEB scalar signed64 minimum current" (it : @bench.T) {
  leb_scalar_error_bench(it, 3, false)
}
