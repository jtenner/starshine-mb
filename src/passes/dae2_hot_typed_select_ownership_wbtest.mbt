///|
test "DAE2 HOT fallback changed output owns typed Select metadata" {
  let input = pass_test_module_from_wat(
    "(module (func $h (param i32 i32 i32 i64) (result i32) local.get 0 local.get 1 local.get 2 select (result i32)) (func (export \"run\") (param i32 i32 i32) (result i32) local.get 0 local.get 1 local.get 2 i64.const 9 call $h))",
  )
  @validate.validate_module(input).unwrap()
  let saved = @binary.encode_module(input).unwrap()
  for closed_world in [false, true] {
    let output = dae2_run_module_pass(
      input,
      closed_world,
      raw_analysis=false,
      raw_rewrite=false,
      stack_suffix_rewrite=false,
    ).unwrap()
    @validate.validate_module(output).unwrap()
    let @lib.FuncType(params, _) = @ir.hot_module_resolve_func_type(
      @ir.hot_module_context_from_module(output),
      @lib.FuncIdx::new(0U),
    ).unwrap()
    assert_eq(params.length(), 3)
    let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
    let types = raw_structured_select_types(body).unwrap()
    assert_eq(types, [@lib.ValType::i32()])
    types[0] = @lib.ValType::i64()
    assert_eq(@binary.encode_module(input).unwrap(), saved)
  }
}
