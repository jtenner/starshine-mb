///|
test "vacuum preserves return that discards ambient stack values" {
  let wat =
    #|(module
    #|  (func (export "main") (param i32 i64) (result i32)
    #|    local.get 0 local.get 1 i32.const 42 return))
  for passes in [["vacuum"], ["optimize"]] {
    let optimized = pass_test_run_pipeline(
      wat,
      passes,
      options=HotPipelineOptions::new(optimize_level=4, shrink_level=1),
    ).unwrap()
    @validate.validate_module(o4z_canonicalize_final_size_candidate(optimized)).unwrap()
  }
}

///|
test "vacuum preserves stack unwinding around a constructor result call" {
  let wat =
    #|(module
    #|  (func $read (param i32) (result i32) local.get 0)
    #|  (func (export "main") (param i32 i64) (result i32) (local i32)
    #|    local.get 0 local.get 1 i32.const 42 call $read
    #|    return local.set 2 i32.const 0))
  let optimized = pass_test_run_pipeline(wat, ["vacuum"]).unwrap()
  @validate.validate_module(o4z_canonicalize_final_size_candidate(optimized)).unwrap()
}

///|
test "vacuum still removes final return with exactly the function results" {
  let wat = "(module (func (export \"main\") (result i32) i32.const 42 return))"
  let optimized = o4z_canonicalize_final_size_candidate(
    pass_test_run_pipeline(wat, ["vacuum"]).unwrap(),
  )
  @validate.validate_module(optimized).unwrap()
  let body = match optimized.code_sec {
    Some(@lib.CodeSec([@lib.Func(_, @lib.Expr(body))])) => body
    _ => fail("expected one function after vacuum")
  }
  @debug.assert_eq(body, [@lib.Instruction::i32_const(@lib.I32(42))])
}
