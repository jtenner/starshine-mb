///|
test "simple type cleanup remaps typed code across index width without full sizing" {
  let types : Array[@lib.RecType] = []
  let func_types : Array[@lib.TypeIdx] = []
  let funcs : Array[@lib.Func] = []
  for idx in 0..<128 {
    let params : Array[@lib.ValType] = []
    if idx > 0 {
      for bit in 0..<8 {
        params.push(
          if (idx & (1 << bit)) != 0 {
            @lib.ValType::i64()
          } else {
            @lib.ValType::i32()
          },
        )
      }
    }
    types.push(
      @lib.RecType::new(
        @lib.SubType::comp_type(@lib.CompType::func(params, [])),
      ),
    )
    func_types.push(@lib.TypeIdx::new(idx.to_uint()))
    funcs.push(@lib.Func::new(@lib.Locals::empty(), @lib.Expr::new([])))
  }
  // The last function uses a duplicate whose index needs two LEB bytes.
  types.push(types[0])
  func_types.push(@lib.TypeIdx::new(128U))
  funcs.push(
    @lib.Func::new(
      @lib.Locals::empty(),
      @lib.Expr::new([
        @lib.Instruction::block(
          @lib.BlockType::type_idx(@lib.TypeIdx::new(128U)),
          @lib.Expr::new([]),
        ),
      ]),
    ),
  )
  let before = @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new(types))
    .with_func_sec(@lib.FuncSec::new(func_types))
    .with_code_sec(@lib.CodeSec::new(funcs))
  assert_true(@validate.validate_module(before).is_ok())
  let full_size_checks = [0]
  let after = dfe_cleanup_simple_type_encoding(
    before,
    full_size_checks=Some(full_size_checks),
  )
  assert_eq(after.type_sec.unwrap().0.length(), 128)
  assert_eq(after.func_sec.unwrap().0[128], @lib.TypeIdx::new(0U))
  match after.code_sec.unwrap().0[128] {
    @lib.Func(_, @lib.Expr([@lib.Block(@lib.TypeIdxBlockType(idx), _)])) =>
      assert_eq(idx, @lib.TypeIdx::new(0U))
    _ => fail("typed block was not retained")
  }
  assert_true(@validate.validate_module(after).is_ok())
  assert_true(
    @binary.encode_module(after).unwrap().length() <
    @binary.encode_module(before).unwrap().length(),
  )
  assert_eq(full_size_checks[0], 0)
}
