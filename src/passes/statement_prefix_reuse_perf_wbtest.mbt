///|
fn sl_prefix_bench(it : @bench.T, width : Int, reference : Bool) -> Unit {
  let body = sl_prefix_fixture(width)
  let env = @validate.Env::new()
  let expected = sl_prefix_reference(body, env, false)
  if run_hot_pipeline_raw_simplify_locals_statement_prefix_end(body, env, false) !=
    expected {
    abort("prefix mismatch")
  }
  it.bench(fn() {
    it.keep(
      if reference {
        sl_prefix_reference(body, env, false)
      } else {
        run_hot_pipeline_raw_simplify_locals_statement_prefix_end(
          body, env, false,
        )
      },
    )
  })
}

///|
test "bench reuse-campaign statement prefix width=16 reference" (it : @bench.T) {
  sl_prefix_bench(it, 16, true)
}

///|
test "bench reuse-campaign statement prefix width=16 incremental" (
  it : @bench.T,
) {
  sl_prefix_bench(it, 16, false)
}

///|
test "bench reuse-campaign statement prefix width=256 reference" (it : @bench.T) {
  sl_prefix_bench(it, 256, true)
}

///|
test "bench reuse-campaign statement prefix width=256 incremental" (
  it : @bench.T,
) {
  sl_prefix_bench(it, 256, false)
}
