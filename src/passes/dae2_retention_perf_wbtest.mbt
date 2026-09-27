///|
fn dae2_analysis_bench(it : @bench.T, count : Int) -> Unit {
  let input = dae2_retention_fixture(count)
  @validate.validate_module(input).unwrap()
  @validate.validate_module(dae2_run_module_pass(input, false).unwrap()).unwrap()
  it.bench(fn() { it.keep(dae2_run_module_pass(input, false).unwrap()) })
}

///|
test "bench reuse-campaign dae2 analysis functions=64" (it : @bench.T) {
  dae2_analysis_bench(it, 32)
}

///|
test "bench reuse-campaign dae2 analysis functions=1024" (it : @bench.T) {
  dae2_analysis_bench(it, 512)
}
