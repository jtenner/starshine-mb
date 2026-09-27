///|
test "numeric grouping obtains parameter facts without a whole-module HOT context" {
  let module = pass_test_module_from_wat(
    "(module (type (func (param i32))) (import \"env\" \"host\" (func (type 0))) (func (export \"run\") (param i32) (local i32 f64 i32) local.get 0 drop))",
  )
  let builds = [0]
  let actual = run_hot_pipeline_raw_group_body_locals_by_type_module(
    module,
    context_builds=Some(builds),
  )
  assert_eq(actual, numeric_group_context_reference_module(module))
  assert_eq(builds[0], 0)
  let @lib.Func(locals, _) = actual.code_sec.unwrap().0[0]
  assert_eq(locals.runs(), [
    @lib.LocalRun::new(2U, @lib.ValType::i32()),
    @lib.LocalRun::new(1U, @lib.ValType::f64()),
  ])
}

///|
test "numeric grouping signature table matches HOT resolution across recursive groups and imports" {
  let module = pass_test_module_from_wat(
    "(module (rec (type (struct (field i32))) (type (func (param i64)))) (type (func (param f64 i32))) (import \"env\" \"host\" (func (type 1))) (func (type 2) (param f64 i32) (local i32 f64 i32)))",
  )
  let context = @ir.hot_module_context_from_module(module)
  let actual = raw_numeric_group_function_params(module)
  assert_eq(actual.length(), 2)
  for i = 0; i < actual.length(); i = i + 1 {
    assert_eq(
      actual[i],
      run_hot_pipeline_required_func_params(
        context,
        @lib.FuncIdx::new(i.to_uint()),
      ),
    )
  }
  assert_eq(
    run_hot_pipeline_raw_group_body_locals_by_type_module(module),
    numeric_group_context_reference_module(module),
  )
}
