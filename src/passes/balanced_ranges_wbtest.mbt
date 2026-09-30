///|
fn sl_balanced_range_fixture(
  body : String,
  type_ : String,
) -> (@lib.Module, @validate.Env, Array[@lib.Instruction]) {
  let input = pass_test_module_from_wat(
    "(module (import \"env\" \"produce\" (func $produce (result \{type_}))) (import \"env\" \"consume\" (func $consume (param \{type_}))) (import \"env\" \"tick\" (func $tick)) (func (export \"run\") (local \{type_}) \{body}))",
  )
  @validate.validate_module(input).unwrap()
  let @lib.Func(locals, @lib.Expr(instrs)) = input.code_sec.unwrap().0[0]
  let env = @validate.Env::new()
    .with_module(input)
    .with_locals(locals)
    .with_return_type(Some([]))
  (input, env, instrs)
}

///|
test "balanced statement ranges preserve values effect order and exact capture decisions" {
  for type_ in ["i32", "i64", "externref"] {
    for
      (body, count) in [
        ("call $produce local.set 0 nop local.get 0 call $consume", 1),
        (
          "call $produce local.set 0 call $tick nop local.get 0 call $consume", 1,
        ),
        (
          "call $produce local.set 0 nop local.get 0 call $consume local.get 0 call $consume",
          0,
        ),
        (
          "call $produce local.set 0 nop local.get 0 call $consume call $produce local.set 0 nop local.get 0 call $consume",
          2,
        ),
        (
          "call $produce local.set 0 i32.const 0 i32.const 0 i32.div_s drop local.get 0 call $consume",
          1,
        ),
        ("call $produce local.set 0 block nop end local.get 0 call $consume", 0),
        ("call $produce call $consume nop", 0),
      ] {
      let (input, env, instrs) = sl_balanced_range_fixture(body, type_)
      let saved = @binary.encode_module(input).unwrap()
      let actual = run_hot_pipeline_raw_simplify_locals_rewrite_balanced_statement_local_gets_flat(
        instrs, env,
      )
      let expected = sl_balanced_range_reference(instrs, env)
      assert_eq(actual, expected)
      assert_eq(actual.1, count)
      let @lib.Func(locals, _) = input.code_sec.unwrap().0[0]
      @validate.validate_module(
        input.with_code_sec(
          @lib.CodeSec::new([@lib.Func::new(locals, @lib.Expr::new(actual.0))]),
        ),
      ).unwrap()
      assert_eq(@binary.encode_module(input).unwrap(), saved)
    }
  }
}
