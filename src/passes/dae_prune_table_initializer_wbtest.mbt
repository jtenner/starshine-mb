///|
fn dae_table_init_fixture(index : UInt32, include_unused : Bool) -> @lib.Module {
  let retained = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [])),
  )
  let types = if include_unused {
    [
      @lib.RecType::new(
        @lib.SubType::comp_type(@lib.CompType::func([@lib.ValType::i64()], [])),
      ),
      retained,
    ]
  } else {
    [retained]
  }
  let ref_ = @lib.RefType::new(
    true,
    @lib.HeapType::new(@lib.TypeIdx::new(index)),
  )
  @lib.Module::new()
  .with_type_sec(@lib.TypeSec::new(types))
  .with_table_sec(
    @lib.TableSec::new([
      @lib.Table::new(
        @lib.TableType::new(ref_, @lib.Limits::i32(1U, None)),
        Some(@lib.Expr::new([@lib.Instruction::ref_null_type(ref_)])),
      ),
    ]),
  )
}

///|
fn dae_table_init_checked_prune() -> (@lib.Module, @lib.Module, Bytes) raise {
  let input = dae_table_init_fixture(1U, true)
  @validate.validate_module(input).unwrap()
  let before = @binary.encode_module(input).unwrap()
  let output = dae_prune_unused_simple_func_types(input)
  // These behavior gates precede both independent required assertions.
  assert_eq(input.type_sec.unwrap().0.length(), 2)
  assert_eq(output.type_sec.unwrap().0.length(), 1)
  assert_eq(output.type_sec.unwrap().0[0], input.type_sec.unwrap().0[1])
  assert_eq(output.func_sec, None)
  assert_eq(output.code_sec, None)
  let @lib.Table(table_type, _) = output.table_sec.unwrap().0[0]
  assert_eq(
    table_type,
    @lib.TableType::new(
      @lib.RefType::new(true, @lib.HeapType::new(@lib.TypeIdx::new(0U))),
      @lib.Limits::i32(1U, None),
    ),
  )
  assert_eq(@binary.encode_module(input).unwrap(), before)
  (input, output, before)
}

///|
test "DAE productive type pruning remaps the typed table initializer index" {
  let (input, output, before) = dae_table_init_checked_prune()
  let @lib.Table(_, initializer) = output.table_sec.unwrap().0[0]
  assert_eq(
    initializer,
    Some(
      @lib.Expr::new([
        @lib.Instruction::ref_null_type(
          @lib.RefType::new(true, @lib.HeapType::new(@lib.TypeIdx::new(0U))),
        ),
      ]),
    ),
  )
  let expected = dae_table_init_fixture(0U, false)
  @validate.validate_module(expected).unwrap()
  @validate.validate_module(output).unwrap()
  assert_eq(
    @binary.encode_module(output).unwrap(),
    @binary.encode_module(expected).unwrap(),
  )
  assert_eq(@binary.encode_module(input).unwrap(), before)
}

///|
test "DAE productive type pruning retains valid typed table initializer output" {
  let (input, output, before) = dae_table_init_checked_prune()
  // Independent positive validity assertion: no expected-invalid success.
  @validate.validate_module(output).unwrap()
  let expected = dae_table_init_fixture(0U, false)
  @validate.validate_module(expected).unwrap()
  assert_eq(
    @binary.encode_module(output).unwrap(),
    @binary.encode_module(expected).unwrap(),
  )
  assert_eq(@binary.encode_module(input).unwrap(), before)
}
