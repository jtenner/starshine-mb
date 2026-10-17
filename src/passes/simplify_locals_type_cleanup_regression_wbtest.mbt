///|
test "simplify locals prunes dead plain signatures and retains public type roots" {
  let input = pass_test_module_from_wat(
    "(module (type $dead (func (param f64 f64))) " +
    "(type $callback (func (param i64) (result i64))) " +
    "(type $entry (func (param i32) (result i32))) " +
    "(type $event (func (param i64))) " +
    "(global (export \"callback\") (ref null $callback) (ref.null $callback)) " +
    "(tag (export \"event\") (type $event)) " +
    "(func (export \"f\") (type $entry) (param i32) (result i32) (local i32) " +
    "local.get 0 local.set 1 local.get 1))",
  )
  ignore(@validate.validate_module(input).unwrap())
  assert_eq(input.type_sec.unwrap().0.length(), 4)
  let expected = pass_test_module_from_wat(
    "(module (type $callback (func (param i64) (result i64))) " +
    "(type $entry (func (param i32) (result i32))) " +
    "(type $event (func (param i64))) " +
    "(global (export \"callback\") (ref null $callback) (ref.null $callback)) " +
    "(tag (export \"event\") (type $event)) " +
    "(func (export \"f\") (type $entry) (param i32) (result i32) local.get 0))",
  )
  ignore(@validate.validate_module(expected).unwrap())
  assert_eq(expected.type_sec.unwrap().0.length(), 3)
  for name in ["simplify-locals", "simplify-locals-nostructure"] {
    let output = run_hot_pipeline(input, HotPipelineOptions::new(), [name]).unwrap()
    let decoded = @binary.decode_module(@binary.encode_module(output).unwrap()).unwrap()
    ignore(@validate.validate_module(decoded).unwrap())
    assert_eq(decoded.type_sec.unwrap().0.length(), 3)
    assert_eq(decoded.func_sec, expected.func_sec)
    assert_eq(decoded.global_sec, expected.global_sec)
    assert_eq(decoded.tag_sec, expected.tag_sec)
    assert_eq(decoded.export_sec, input.export_sec)
    assert_true(
      @binary.encode_module(decoded).unwrap().length() <
      @binary.encode_module(input).unwrap().length(),
    )
    for argument in [-2147483648, -1, 0, 10, 2147483647] {
      assert_eq(
        tuple_prefix_execute(decoded.code_sec.unwrap().0[0], arguments=[
          argument,
        ]),
        (Some(argument), []),
      )
    }
  }
}

///|
test "simplify locals type cleanup remaps unselected typed blocks after writeback" {
  let input = pass_test_module_from_wat(
    "(module (type (func (param f64 f64))) " +
    "(type (func (param i32) (result i32))) " +
    "(type (func (param i32 i32) (result i32 i32))) " +
    "(func (type 1) (param i32) (result i32) (local i32) local.get 0 local.set 1 local.get 1) " +
    "(func (type 1) (param i32) (result i32) local.get 0 i32.const 7 block (type 2) end drop))",
  )
  ignore(@validate.validate_module(input).unwrap())
  for name in ["simplify-locals", "simplify-locals-nostructure"] {
    let descriptor = pass_registry_lookup(name).unwrap().descriptor.unwrap()
    for stack in [false, true] {
      let output = if stack {
        run_hot_pipeline_apply_hot_pass_stack_to_touched(
          input,
          [descriptor],
          [true, false],
          HotPipelineOptions::new(),
        ).unwrap()
      } else {
        run_hot_pipeline_apply_hot_pass_to_touched(
          input,
          descriptor,
          [true, false],
          HotPipelineOptions::new(),
        ).unwrap()
      }
      let decoded = @binary.decode_module(
        @binary.encode_module(output).unwrap(),
      ).unwrap()
      ignore(@validate.validate_module(decoded).unwrap())
      assert_eq(decoded.type_sec.unwrap().0.length(), 2)
      assert_eq(decoded.func_sec.unwrap().0, [
        @lib.TypeIdx::new(0U),
        @lib.TypeIdx::new(0U),
      ])
      let @lib.Func(_, @lib.Expr(body)) = decoded.code_sec.unwrap().0[1]
      assert_eq(body, [
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::i32_const(7),
        @lib.Instruction::block(
          @lib.BlockType::type_idx(@lib.TypeIdx::new(1U)),
          @lib.Expr::new([]),
        ),
        @lib.Instruction::drop(),
      ])
      for argument in [-2147483648, -1, 0, 10, 2147483647] {
        for func in decoded.code_sec.unwrap().0 {
          assert_eq(
            tuple_prefix_execute(func, arguments=[argument]),
            (Some(argument), []),
          )
        }
      }
    }
  }
}
