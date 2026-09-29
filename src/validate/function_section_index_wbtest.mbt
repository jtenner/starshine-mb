///|
test "function section type indices address the flattened global type space" {
  let module_ = Module::new()
    .with_type_sec(
      TypeSec::new([
        RecType::group([
          SubType::comp_type(CompType::struct_([])),
          SubType::comp_type(CompType::func([], [ValType::i32()])),
        ]),
        RecType::new(SubType::comp_type(CompType::func([], [ValType::i64()]))),
      ]),
    )
    .with_func_sec(FuncSec::new([TypeIdx::new(1U), TypeIdx::new(2U)]))
    .with_code_sec(
      CodeSec::new([
        Func::new(Locals::empty(), Expr::new([Instruction::i32_const(I32(7))])),
        Func::new(Locals::empty(), Expr::new([Instruction::i64_const(I64(8L))])),
      ]),
    )
  validate_module(module_).unwrap()
  // RecIdx is intentionally invalid outside its recursive type declaration.
  let invalid = module_.with_func_sec(
    FuncSec::new([TypeIdx::rec(1U), TypeIdx::new(2U)]),
  )
  assert_true(validate_module(invalid) is Err(_))
}
