///|
fn h2l_default_probe_fixture(fields : Int) -> @lib.Module {
  let source = StringBuilder::new()
  source.write_string("(module (type (struct")
  for _ in 0..<fields {
    source.write_string(" (field i32)")
  }
  source.write_string(")) (func (drop (struct.new_default 0))))")
  pass_test_module_from_wat(source.to_string())
}

///|
fn h2l_default_probe_alloc(hot : @ir.HotFunc) -> Int {
  for node = 0; node < @ir.hot_node_count(hot); node = node + 1 {
    if @ir.hot_node_exact_instr(hot, node) is Some(@lib.StructNewDefault(_)) {
      return node
    }
  }
  abort("Heap2Local default probe fixture lacks struct.new_default")
}

///|
test "Heap2Local default-field eligibility leaves the node arena unchanged" {
  let fixture = h2l_default_probe_fixture(8)
  let ctx = @ir.hot_module_context_from_module(fixture)
  let hot = @ir.hot_lift_func(fixture, @lib.FuncIdx::new(0U))
  let alloc = h2l_default_probe_alloc(hot)
  let before = @ir.hot_node_count(hot)
  assert_true(h2l_supported_struct_new_fields(hot, ctx, alloc) is Some(_))
  assert_eq(@ir.hot_node_count(hot), before)
}

///|
test "Heap2Local default-array eligibility leaves the node arena unchanged" {
  let fixture = pass_test_module_from_wat(
    "(module (type (array (mut i32))) (func (drop (array.new_default 0 (i32.const 4)))))",
  )
  let ctx = @ir.hot_module_context_from_module(fixture)
  let hot = @ir.hot_lift_func(fixture, @lib.FuncIdx::new(0U))
  let mut alloc = -1
  for node = 0; node < @ir.hot_node_count(hot); node = node + 1 {
    if @ir.hot_node_exact_instr(hot, node) is Some(@lib.ArrayNewDefault(_)) {
      alloc = node
    }
  }
  assert_true(alloc >= 0)
  let before = @ir.hot_node_count(hot)
  assert_true(h2l_supported_array_init(hot, ctx, alloc) is Some(_))
  assert_eq(@ir.hot_node_count(hot), before)
}

///|
fn h2l_default_probe_bench(it : @bench.T, fields : Int) -> Unit {
  let fixture = h2l_default_probe_fixture(fields)
  let ctx = @ir.hot_module_context_from_module(fixture)
  it.bench(fn() {
    let hot = @ir.hot_lift_func(fixture, @lib.FuncIdx::new(0U))
    let alloc = h2l_default_probe_alloc(hot)
    for _ in 0..<16 {
      it.keep(h2l_supported_struct_new_fields(hot, ctx, alloc))
    }
    it.keep(hot)
  })
}

///|
test "bench Heap2Local default-field probe fields=16" (it : @bench.T) {
  h2l_default_probe_bench(it, 16)
}

///|
test "bench Heap2Local default-field probe fields=64" (it : @bench.T) {
  h2l_default_probe_bench(it, 64)
}
