///|
fn precompute_raw_identity_bench(
  it : @bench.T,
  count : Int,
  active : Bool,
) -> Unit {
  let mod_ = pass_test_module_from_wat(
    if active {
      "(module (func (result i32) i32.const 1 i32.const 2 i32.add))"
    } else {
      "(module (func (param i32) (result i32) local.get 0))"
    },
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
  let result = run_hot_pipeline(fixture, options, ["precompute"]).unwrap()
  @validate.validate_module(result).unwrap()
  let @lib.Func(_, @lib.Expr(body)) = result.code_sec.unwrap().0[0]
  let expected = if active {
    [@lib.Instruction::i32_const(@lib.I32(3))]
  } else {
    [@lib.Instruction::local_get(@lib.LocalIdx::new(0U))]
  }
  if body != expected ||
    fixture.code_sec.unwrap().0[0] != mod_.code_sec.unwrap().0[0] {
    abort("precompute benchmark changed folds or input ownership")
  }
  it.bench(fn() { it.keep(run_hot_pipeline(fixture, options, ["precompute"])) })
}

///|
test "bench precompute unchanged functions=16" (it : @bench.T) {
  precompute_raw_identity_bench(it, 16, false)
}

///|
test "bench precompute scalar-folds functions=16" (it : @bench.T) {
  precompute_raw_identity_bench(it, 16, true)
}

///|
test "bench precompute unchanged functions=128" (it : @bench.T) {
  precompute_raw_identity_bench(it, 128, false)
}

///|
test "bench precompute scalar-folds functions=128" (it : @bench.T) {
  precompute_raw_identity_bench(it, 128, true)
}

///|
test "bench precompute unchanged functions=1024" (it : @bench.T) {
  precompute_raw_identity_bench(it, 1024, false)
}

///|
test "bench precompute scalar-folds functions=1024" (it : @bench.T) {
  precompute_raw_identity_bench(it, 1024, true)
}
