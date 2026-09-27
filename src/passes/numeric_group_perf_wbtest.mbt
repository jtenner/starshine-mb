///|
fn numeric_group_bench(
  it : @bench.T,
  runs : Int,
  grouped : Bool,
  reference : Bool,
) -> Unit {
  let locals = @lib.Locals::new(
    Array::makei(runs, fn(i) {
      @lib.LocalRun::new(
        16U,
        if grouped || i % 2 == 0 {
          @lib.ValType::i32()
        } else {
          @lib.ValType::f64()
        },
      )
    }),
  )
  let func = @lib.Func::new(locals, @lib.Expr::new([]))
  if numeric_group_reference_func(func, []) !=
    run_hot_pipeline_raw_group_body_locals_by_type_func(func, []) {
    abort("numeric grouping mismatch")
  }
  it.bench(fn() {
    it.keep(
      if reference {
        numeric_group_reference_func(func, [])
      } else {
        run_hot_pipeline_raw_group_body_locals_by_type_func(func, [])
      },
    )
  })
}

///|
test "bench numeric grouping indexed runs=32" (it : @bench.T) {
  numeric_group_bench(it, 32, false, true)
}

///|
test "bench numeric grouping compressed runs=32" (it : @bench.T) {
  numeric_group_bench(it, 32, false, false)
}

///|
test "bench numeric grouping indexed runs=128" (it : @bench.T) {
  numeric_group_bench(it, 128, false, true)
}

///|
test "bench numeric grouping compressed runs=128" (it : @bench.T) {
  numeric_group_bench(it, 128, false, false)
}

///|
test "bench numeric grouping indexed already-grouped locals=2048" (
  it : @bench.T,
) {
  numeric_group_bench(it, 128, true, true)
}

///|
test "bench numeric grouping compressed already-grouped locals=2048" (
  it : @bench.T,
) {
  numeric_group_bench(it, 128, true, false)
}
