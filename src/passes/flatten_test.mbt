///|
fn flatten_test_classify(text : String) -> FlattenFlatnessReport {
  flatten_classify_hot(pass_test_lift_first_func(text))
}

///|
test "flatten classifier accepts explicit returns with simple operands" {
  let report = flatten_test_classify(
    "(module (func (param i32) (result i32) local.get 0 return))",
  )
  @debug.assert_eq(report, FlattenFlatnessReport::empty())
  assert_true(report.is_flat())
}

///|
test "flatten classifier reports rich operands tees and implicit body values" {
  let report = flatten_test_classify(
    "(module (func (param i32) (result i32) (local i32) local.get 0 i32.const 1 i32.add local.tee 1))",
  )
  @debug.assert_eq(report.rich_operand_count, 1)
  @debug.assert_eq(report.local_tee_count, 1)
  @debug.assert_eq(report.body_value_flow_count, 1)
  assert_false(report.is_flat())
}

///|
test "flatten classifier reports value carrying control" {
  let report = flatten_test_classify(
    "(module (func (param i32) (result i32) local.get 0 if (result i32) i32.const 1 else i32.const 2 end))",
  )
  @debug.assert_eq(report.value_control_count, 1)
  @debug.assert_eq(report.body_value_flow_count, 1)
  assert_false(report.is_flat())
}

///|
test "flatten classifier reports upstream unsupported try-table" {
  let func = @ir.HotFunc::new()
  let try_table = @ir.hot_build_try_table(func, @lib.BlockType::void_(), [], [])
  @ir.hot_root_append(func, try_table)
  let report = flatten_classify_hot(func)
  @debug.assert_eq(report.unsupported_count, 1)
  assert_false(report.is_flat())
}
