///|
test "numeric local grouping skips legacy body scan when declaration types are unique" {
  let input = pass_test_module_from_wat(
    "(module (func (local i32 i64 f32 f64) local.get 0 drop))",
  )
  @validate.validate_module(input).unwrap()
  let guard_scans = [0]
  let output = oi_group_numeric_locals_if_smaller(
    input,
    legacy_guard_scans=Some(guard_scans),
  )
  assert_eq(output, input)
  @validate.validate_module(output).unwrap()
  assert_eq(guard_scans[0], 0)
}

///|
test "numeric local grouping intentionally skips unsupported reference declaration runs" {
  let input = pass_test_module_from_wat(
    "(module (func (local externref i32 externref)))",
  )
  @validate.validate_module(input).unwrap()
  let guard_scans = [0]
  let output = oi_group_numeric_locals_if_smaller(
    input,
    legacy_guard_scans=Some(guard_scans),
  )
  assert_eq(output, input)
  @validate.validate_module(output).unwrap()
  assert_eq(guard_scans[0], 0)
}

///|
test "numeric local grouping still remaps repeated declaration types" {
  let input = pass_test_module_from_wat(
    "(module (func (local i32 i64 i32) local.get 2 drop))",
  )
  @validate.validate_module(input).unwrap()
  let guard_scans = [0]
  let output = oi_group_numeric_locals_if_smaller(
    input,
    legacy_guard_scans=Some(guard_scans),
  )
  @validate.validate_module(output).unwrap()
  assert_eq(guard_scans[0], 1)
  assert_true(
    @binary.encode_module(output).unwrap().length() <
    @binary.encode_module(input).unwrap().length(),
  )
  let @lib.Func(locals, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
  assert_eq(locals.runs().length(), 2)
  match body {
    [@lib.LocalGet(@lib.LocalIdx(1U)), @lib.Drop] => ()
    _ => fail("repeated local type was not remapped")
  }
}
