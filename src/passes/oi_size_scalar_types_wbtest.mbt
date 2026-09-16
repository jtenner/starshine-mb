///|
test "OI size followup scalar_types saved case 3 passes" {
  let input = @binary.decode_module(
    Bytes::from_array([
      0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00, 0x01, 0x11, 0x04, 0x60, 0x00,
      0x00, 0x60, 0x00, 0x01, 0x7f, 0x5f, 0x02, 0x7f, 0x01, 0x7f, 0x01, 0x5e, 0x7f,
      0x01, 0x03, 0x04, 0x03, 0x00, 0x01, 0x01, 0x06, 0x06, 0x01, 0x7f, 0x01, 0x41,
      0x00, 0x0b, 0x07, 0x07, 0x01, 0x03, 0x72, 0x75, 0x6e, 0x00, 0x00, 0x0a, 0x2a,
      0x03, 0x10, 0x01, 0x01, 0x7f, 0x41, 0x0a, 0x10, 0x01, 0xfb, 0x00, 0x02, 0xfb,
      0x02, 0x02, 0x00, 0x1a, 0x0b, 0x0b, 0x00, 0x23, 0x00, 0x41, 0x01, 0x6a, 0x24,
      0x00, 0x41, 0x0b, 0x0b, 0x0b, 0x00, 0x23, 0x00, 0x41, 0x01, 0x6a, 0x24, 0x00,
      0x41, 0x1d, 0x0b,
    ]),
  ).unwrap()
  let output = run_hot_pipeline(input, HotPipelineOptions::new(), [
    "optimize-instructions",
  ]).unwrap()
  assert_true(@validate.validate_module(output).is_ok())
  @debug.assert_eq(output.type_sec.unwrap().0.length(), 3)
}

///|
test "OI size followup scalar types preserve arithmetic effects and remap live names" {
  let input = pass_test_module_from_wat(
    "(module (type (array i32)) (type (struct (field i32))) (type (func (result (ref 1)))) (global (mut i32) (i32.const 0)) (func (type 2) global.get 0 i32.const 1 i32.add global.set 0 struct.new_default 1))",
  ).with_name_sec(
    @lib.NameSec::new(
      type_names=Some(
        @lib.NameMap::new([
          @lib.NameAssoc::new(0U, @lib.Name::from_string("dead")),
          @lib.NameAssoc::new(1U, @lib.Name::from_string("live")),
        ]),
      ),
    ),
  )
  let output = pass_cleanup_unused_type_groups(input)
  @debug.assert_eq(output.type_sec.unwrap().0.length(), 2)
  assert_true(@validate.validate_module(output).is_ok())
  let @lib.Func(_, @lib.Expr(before)) = input.code_sec.unwrap().0[0]
  let @lib.Func(_, @lib.Expr(after)) = output.code_sec.unwrap().0[0]
  @debug.assert_eq(after[0:4].to_array(), before[0:4].to_array())
  @debug.assert_eq(
    after.last(),
    Some(@lib.Instruction::struct_new_default(@lib.TypeIdx::new(0U))),
  )
  @debug.assert_eq(
    output.name_sec.unwrap().type_names,
    Some(
      @lib.NameMap::new([
        @lib.NameAssoc::new(0U, @lib.Name::from_string("live")),
      ]),
    ),
  )
}
