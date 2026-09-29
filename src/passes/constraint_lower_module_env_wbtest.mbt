///|
test "constraint lowering uses one supplied module environment for typed cleanup" {
  for ty in ["i32", "i64"] {
    let input = pass_test_module_from_wat(
      "(module (type $result (func (result \{ty}))) (func (export \"run\") (result \{ty}) block (type $result) \{ty}.const 7 end))",
    )
    let original = @binary.encode_module(input).unwrap()
    let env = @validate.Env::new().with_module(input)
    let calls = [0]
    let func = input.code_sec.unwrap().0[0]
    let output = run_hot_pipeline_canonicalize_lowered_func_for_descriptor(
      func,
      "constraint-analysis",
      Some(func),
      @lib.FuncIdx::new(0U),
      input,
      module_env_provider=Some(fn() {
        calls[0] += 1
        env
      }),
    )
    assert_eq(calls[0], 1)
    let @lib.Func(_, @lib.Expr(body)) = output
    assert_eq(body.length(), 1)
    assert_eq(
      body[0],
      if ty == "i32" {
        @lib.Instruction::i32_const(@lib.I32(7))
      } else {
        @lib.Instruction::i64_const(@lib.I64(7L))
      },
    )
    @validate.validate_module(input.with_code_sec(@lib.CodeSec::new([output]))).unwrap()
    assert_eq(@binary.encode_module(input).unwrap(), original)
  }
}
