///|
fn structured_lifetime_summary_bench(it : @bench.T, count : Int) -> Unit {
  let body = structured_lifetime_summary_fixture(count)
  if run_hot_pipeline_raw_simplify_locals_has_call_result_structured_lifetime(
      body,
    ) {
    abort("unrelated structured reads must not block cleanup")
  }
  it.bench(fn() {
    it.keep(
      run_hot_pipeline_raw_simplify_locals_has_call_result_structured_lifetime(
        body,
      ),
    )
  })
}

///|
test "bench structured lifetime candidate prefixes=128" (it : @bench.T) {
  structured_lifetime_summary_bench(it, 128)
}

///|
test "bench structured lifetime candidate prefixes=256" (it : @bench.T) {
  structured_lifetime_summary_bench(it, 256)
}
