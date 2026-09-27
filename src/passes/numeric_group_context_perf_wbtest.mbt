///|
fn numeric_group_context_bench(
  it : @bench.T,
  instructions : Int,
  reference : Bool,
) -> Unit {
  let body = Array::make(instructions, "nop").join(" ")
  let module = pass_test_module_from_wat(
    "(module (func (export \"run\") (param i32) (local i32 f64 i32) \{body} local.get 0 drop))",
  )
  if numeric_group_context_reference_module(module) !=
    run_hot_pipeline_raw_group_body_locals_by_type_module(module) {
    abort("numeric grouping context mismatch")
  }
  it.bench(fn() {
    it.keep(
      if reference {
        numeric_group_context_reference_module(module)
      } else {
        run_hot_pipeline_raw_group_body_locals_by_type_module(module)
      },
    )
  })
}

///|
test "bench local grouping with full HOT context instructions=128" (
  it : @bench.T,
) {
  numeric_group_context_bench(it, 128, true)
}

///|
test "bench local grouping with signature facts instructions=128" (
  it : @bench.T,
) {
  numeric_group_context_bench(it, 128, false)
}

///|
test "bench local grouping with full HOT context instructions=8192" (
  it : @bench.T,
) {
  numeric_group_context_bench(it, 8192, true)
}

///|
test "bench local grouping with signature facts instructions=8192" (
  it : @bench.T,
) {
  numeric_group_context_bench(it, 8192, false)
}
