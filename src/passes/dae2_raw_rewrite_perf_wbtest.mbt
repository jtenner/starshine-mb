///|
// Compare the same qualified analysis with either a HOT mutation arena or
// direct mutation. Exact output, active signatures, and ownership are checked
// outside the measured loop. Producer and pipeline controls live alongside it.
fn dae2_raw_rewrite_bench(
  it : @bench.T,
  helpers : Int,
  width : Int,
  direct : Bool,
) -> Unit {
  let input = dae2_raw_analysis_fixture(helpers, width)
  let saved = @binary.encode_module(input).unwrap()
  let lifts = [0]
  let output = dae2_run_module_pass(input, false, rewrite_lifts=Some(lifts)).unwrap()
  let reference = dae2_run_module_pass(input, false, raw_rewrite=false).unwrap()
  @validate.validate_module(output).unwrap()
  if lifts[0] != 0 ||
    @binary.encode_module(output).unwrap() !=
    @binary.encode_module(reference).unwrap() {
    abort("direct scalar rewrite retained HOT lifts or changed output")
  }
  let context = @ir.hot_module_context_from_module(output)
  for index in 0..<helpers {
    if @ir.hot_module_resolve_func_type(
        context,
        @lib.FuncIdx::new((index * 2).to_uint()),
      ) !=
      Some(@lib.FuncType::new([@lib.ValType::i32()], [@lib.ValType::i32()])) {
      abort("direct rewrite benchmark did not remove the two dead parameters")
    }
  }
  it.bench(fn() {
    it.keep(dae2_run_module_pass(input, false, raw_rewrite=direct))
  })
  if @binary.encode_module(input).unwrap() != saved {
    abort("direct scalar rewrite benchmark mutated input")
  }
}

///|
test "bench DAE2 scalar mutation helpers=1 width=1 HOT" (it : @bench.T) {
  dae2_raw_rewrite_bench(it, 1, 1, false)
}

///|
test "bench DAE2 scalar mutation helpers=1 width=1 direct" (it : @bench.T) {
  dae2_raw_rewrite_bench(it, 1, 1, true)
}

///|
test "bench DAE2 scalar mutation helpers=32 width=128 HOT" (it : @bench.T) {
  dae2_raw_rewrite_bench(it, 32, 128, false)
}

///|
test "bench DAE2 scalar mutation helpers=32 width=128 direct" (it : @bench.T) {
  dae2_raw_rewrite_bench(it, 32, 128, true)
}
