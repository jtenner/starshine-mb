///|
fn dae2_single_row_bench(
  it : @bench.T,
  locals : Int,
  reference : Bool,
) -> Unit raise {
  let decls = Array::make(locals, "i32").join(" ")
  let target = locals - 1
  let input = pass_test_module_from_wat(
    "(module (func (result i32) (local \{decls}) i32.const 7 local.set \{target} local.get \{target}))",
  )
  let func = @ir.hot_lift_func(input, @lib.FuncIdx::new(0U))
  let facts = dae2_scan_write_facts(func)
  let saved = @ir.hot_lower_func(func)
  let expected = dae2_single_row_reference_entry(func, known_writes=facts.sole)
  assert_eq(dae2_entry_read_sources(func, known_writes=facts.sole), expected)
  it.bench(fn() {
    it.keep(
      if reference {
        dae2_single_row_reference_entry(func, known_writes=facts.sole)
      } else {
        dae2_entry_read_sources(func, known_writes=facts.sole)
      },
    )
  })
  assert_eq(@ir.hot_lower_func(func), saved)
}

///|
test "bench single entry local count 1 V79 predecessor" (it : @bench.T) {
  dae2_single_row_bench(it, 1, true)
}

///|
test "bench single entry local count 1 scalar proof" (it : @bench.T) {
  dae2_single_row_bench(it, 1, false)
}

///|
test "bench single entry local count 64 V79 predecessor" (it : @bench.T) {
  dae2_single_row_bench(it, 64, true)
}

///|
test "bench single entry local count 64 scalar proof" (it : @bench.T) {
  dae2_single_row_bench(it, 64, false)
}

///|
test "bench single entry local count 4096 V79 predecessor" (it : @bench.T) {
  dae2_single_row_bench(it, 4096, true)
}

///|
test "bench single entry local count 4096 scalar proof" (it : @bench.T) {
  dae2_single_row_bench(it, 4096, false)
}
