///|
test "hot lift derives defined indices without scanning imports" {
  @debug.assert_eq(
    hot_lift_impl_defined_code_index(100, 73, @lib.FuncIdx::new(27U)),
    Some(0),
  )
  @debug.assert_eq(
    hot_lift_impl_defined_code_index(100, 73, @lib.FuncIdx::new(99U)),
    Some(72),
  )
  @debug.assert_eq(
    hot_lift_impl_defined_code_index(100, 73, @lib.FuncIdx::new(26U)),
    None,
  )
}

///|
test "hot lift validation locals preserve compressed declaration runs" {
  let body_locals = @lib.Locals::new([
    @lib.LocalRun::new(4096U, @lib.ValType::i32()),
  ])
  let combined = hot_lift_impl_validation_locals(
    [@lib.ValType::i32(), @lib.ValType::i64()],
    body_locals,
  )
  @debug.assert_eq(combined.length(), 4098)
  @debug.assert_eq(combined.runs().length(), 3)
  @debug.assert_eq(combined[0], @lib.ValType::i32())
  @debug.assert_eq(combined[1], @lib.ValType::i64())
  @debug.assert_eq(combined[4097], @lib.ValType::i32())
}

///|
test "hot lift known function results build one validation environment" {
  let env_build_visits = [0]
  match
    hot_lift_impl_body_with_context_result(
      @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32(7))]),
      HotLocals::new(),
      hot_module_context_from_module(@lib.Module::new()),
      @lib.BlockType::val_type(@lib.ValType::i32()),
      known_return_types=Some([@lib.ValType::i32()]),
      env_build_visits=Some(env_build_visits),
    ) {
    Ok(func) => {
      @debug.assert_eq(hot_root_count(func), 1)
      @debug.assert_eq(env_build_visits[0], 1)
    }
    Err(err) => fail("expected known-result lift success, got \{err}")
  }
}
