///|
fn dae2_stack_suffix_perf_fixture(helpers : Int, width : Int) -> @lib.Module {
  let definitions = Array::makei(helpers, fn(i) {
    let calls = Array::make(width, "local.get 0 i32.const 9 call $sink\{i}").join(
      " ",
    )
    "(func $sink\{i} (param i32 i32) local.get 0 global.set $g) (func (export \"run\{i}\") (param i32) loop \{calls} end)"
  }).join(" ")
  pass_test_module_from_wat(
    "(module (global $g (mut i32) (i32.const 0)) \{definitions})",
  )
}

///|
fn dae2_stack_suffix_perf_run(
  it : @bench.T,
  helpers : Int,
  width : Int,
  direct : Bool,
) -> Unit raise {
  let input = dae2_stack_suffix_perf_fixture(helpers, width)
  let saved = @binary.encode_module(input).unwrap()
  let lifts = [0]
  let output = dae2_run_module_pass(input, false, rewrite_lifts=Some(lifts)).unwrap()
  let reference = dae2_run_module_pass(input, false, raw_rewrite=false).unwrap()
  @validate.validate_module(output).unwrap()
  let context = @ir.hot_module_context_from_module(output)
  for i in 0..<helpers {
    assert_eq(
      @ir.hot_module_resolve_func_type(
        context,
        @lib.FuncIdx::new((i * 2).to_uint()),
      ),
      Some(@lib.FuncType::new([@lib.ValType::i32()], [])),
    )
  }
  assert_eq(lifts[0], 0)
  assert_true(
    @binary.encode_module(output).unwrap().length() <=
    @binary.encode_module(reference).unwrap().length(),
  )
  it.bench(fn() {
    it.keep(dae2_run_module_pass(input, false, stack_suffix_rewrite=direct))
  })
  assert_eq(@binary.encode_module(input).unwrap(), saved)
}

///|
test "bench DAE2 structured suffix helpers=1 width=1 existing" (it : @bench.T) {
  dae2_stack_suffix_perf_run(it, 1, 1, false)
}

///|
test "bench DAE2 structured suffix helpers=1 width=1 direct" (it : @bench.T) {
  dae2_stack_suffix_perf_run(it, 1, 1, true)
}

///|
test "bench DAE2 structured suffix helpers=32 width=128 existing" (
  it : @bench.T,
) {
  dae2_stack_suffix_perf_run(it, 32, 128, false)
}

///|
test "bench DAE2 structured suffix helpers=32 width=128 direct" (it : @bench.T) {
  dae2_stack_suffix_perf_run(it, 32, 128, true)
}
