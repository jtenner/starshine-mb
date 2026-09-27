///|
fn precompute_module_env_bench(
  it : @bench.T,
  name : String,
  count : Int,
) -> Unit {
  let mod_ = pass_test_module_from_wat(
    "(module (func (param i32) (result i32) block (result i32) local.get 0 end))",
  )
  let fixture = mod_
    .with_func_sec(
      @lib.FuncSec::new(Array::make(count, mod_.func_sec.unwrap().0[0])),
    )
    .with_code_sec(
      @lib.CodeSec::new(Array::make(count, mod_.code_sec.unwrap().0[0])),
    )
  @validate.validate_module(fixture).unwrap()
  let options = HotPipelineOptions::new(validate_final_module=false)
  let expected = [@lib.Instruction::local_get(@lib.LocalIdx::new(0U))]
  let output = run_hot_pipeline(fixture, options, [name]).unwrap()
  @validate.validate_module(output).unwrap()
  for func in output.code_sec.unwrap().0 {
    let @lib.Func(_, @lib.Expr(body)) = func
    if body != expected {
      abort("precompute module fixture lost block flattening")
    }
  }
  it.bench(fn() { it.keep(run_hot_pipeline(fixture, options, [name])) })
}

///|
test "bench precompute module cleanup functions=128" (it : @bench.T) {
  precompute_module_env_bench(it, "precompute", 128)
}

///|
test "bench precompute module cleanup functions=512" (it : @bench.T) {
  precompute_module_env_bench(it, "precompute", 512)
}

///|
test "bench precompute propagate module cleanup functions=128" (it : @bench.T) {
  precompute_module_env_bench(it, "precompute-propagate", 128)
}

///|
test "bench precompute propagate module cleanup functions=512" (it : @bench.T) {
  precompute_module_env_bench(it, "precompute-propagate", 512)
}
