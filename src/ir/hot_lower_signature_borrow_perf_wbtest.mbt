///|
fn hot_lower_signature_bench(
  it : @bench.T,
  width : Int,
  reference : Bool,
) -> Unit {
  let func = HotFunc::new()
  let params = Array::make(width, @lib.ValType::i32())
  let id = hot_build_resolved_block(
    func,
    @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
    params,
    [],
    [],
  )
  if hot_lower_impl_control_param_types(func, id) != params {
    abort("lowering signature changed")
  }
  it.bench(fn() {
    let actual = hot_lower_impl_control_param_types(func, id)
    it.keep(if reference { actual.copy() } else { actual })
  })
  if hot_lower_impl_control_param_types(func, id) != params {
    abort("lowering mutated signature")
  }
}

///|
test "bench HOT lowering signature width=0 reference" (it : @bench.T) {
  hot_lower_signature_bench(it, 0, true)
}

///|
test "bench HOT lowering signature width=0 borrowed" (it : @bench.T) {
  hot_lower_signature_bench(it, 0, false)
}

///|
test "bench HOT lowering signature width=1 reference" (it : @bench.T) {
  hot_lower_signature_bench(it, 1, true)
}

///|
test "bench HOT lowering signature width=1 borrowed" (it : @bench.T) {
  hot_lower_signature_bench(it, 1, false)
}

///|
test "bench HOT lowering signature width=16 reference" (it : @bench.T) {
  hot_lower_signature_bench(it, 16, true)
}

///|
test "bench HOT lowering signature width=16 borrowed" (it : @bench.T) {
  hot_lower_signature_bench(it, 16, false)
}

///|
test "bench HOT lowering signature width=256 reference" (it : @bench.T) {
  hot_lower_signature_bench(it, 256, true)
}

///|
test "bench HOT lowering signature width=256 borrowed" (it : @bench.T) {
  hot_lower_signature_bench(it, 256, false)
}
