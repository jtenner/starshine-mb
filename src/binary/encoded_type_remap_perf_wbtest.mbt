///|
fn encoded_type_remap_bench(
  it : @bench.T,
  count : Int,
  width : Int,
  changed : Bool,
) -> Unit {
  let before = Array::makei(count, fn(_) {
    encoded_type_remap_fixture(63U, width)
  })
  let after = Array::makei(count, fn(_) {
    encoded_type_remap_fixture(if changed { 64U } else { 63U }, width)
  })
  let first = EncodedModuleSizeState::new(None)
  measure_module_code(before, [], first).unwrap()
  let second = EncodedModuleSizeState::new(Some(first))
  measure_module_code(after, [], second).unwrap()
  for i in 0..<count {
    let expected = @buffer.new()
    Encode::encode(after[i], expected).unwrap()
    if second.sizes[i] != expected.length() {
      abort("type-remap size mismatch")
    }
  }
  it.bench(fn() {
    let initial = EncodedModuleSizeState::new(None)
    measure_module_code(before, [], initial).unwrap()
    let next = EncodedModuleSizeState::new(Some(initial))
    measure_module_code(after, [], next).unwrap()
    it.keep(next.code_size)
  })
}

///|
test "bench exact type remap small changed" (it : @bench.T) {
  encoded_type_remap_bench(it, 1, 8, true)
}

///|
test "bench exact type remap wide changed" (it : @bench.T) {
  encoded_type_remap_bench(it, 64, 128, true)
}

///|
test "bench exact type remap small unchanged" (it : @bench.T) {
  encoded_type_remap_bench(it, 1, 8, false)
}

///|
test "bench exact type remap wide unchanged" (it : @bench.T) {
  encoded_type_remap_bench(it, 64, 128, false)
}
