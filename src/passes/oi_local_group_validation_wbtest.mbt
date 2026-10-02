///|
test "OI local grouping validates only replaced bodies with imported indices" {
  let input = pass_test_module_from_wat(
    "(module (import \"host\" \"f\" (func (param i32) (result i32))) (func (export \"run\") (result i32) (local i32 f64 i32) i32.const 41 local.set 2 local.get 2 call 0) (func (result i32) i32.const 7))",
  )
  let input_bytes = @binary.encode_module(input).unwrap()
  let before = input.code_sec.unwrap().0
  let grouped = run_hot_pipeline_raw_group_body_locals_by_type_module(input)
  let after = grouped.code_sec.unwrap().0
  let selected = oi_local_group_changed_bodies(input, grouped)
  assert_eq(selected.length(), 1)
  assert_eq(selected[0].0, @lib.FuncIdx::new(1U))
  assert_true(physical_equal(selected[0].1, after[0]))
  assert_true(physical_equal(before[1], after[1]))
  assert_true(oi_validate_local_group_changed_bodies(input, grouped))
  @validate.validate_module(grouped).unwrap()
  assert_eq(@binary.encode_module(input).unwrap(), input_bytes)
}

///|
test "OI local grouping body validation rejects stale local indices" {
  let input = oi_local_group_parity_fixture()
  let grouped = run_hot_pipeline_raw_group_body_locals_by_type_module(input)
  let @lib.Func(locals, _) = grouped.code_sec.unwrap().0[0]
  let invalid = grouped.with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(
        locals,
        @lib.Expr::new([@lib.Instruction::local_get(@lib.LocalIdx::new(3U))]),
      ),
    ]),
  )
  assert_false(oi_validate_local_group_changed_bodies(input, invalid))
  assert_true(@validate.validate_module(invalid).is_err())
  assert_eq(oi_local_group_changed_bodies(input, input).length(), 0)
}
