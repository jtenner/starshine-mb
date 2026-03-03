///|
test "pretty_print_defined_func resolves signatures locals and typed calls" {
  let type_sec = TypeSec::new([
    RecType::new(
      SubType::comp_type(CompType::func([ValType::i32()], [ValType::i32()])),
    ),
    RecType::new(SubType::comp_type(CompType::func([], [ValType::i32()]))),
  ])
  let main = Func::t_func(
    [ValType::i32(), ValType::i32()],
    TExpr::new([
      TInstr::if_(
        BlockType::type_idx(TypeIdx::new(1U)),
        TInstr::local_get(LocalIdx::new(0U)),
        TExpr::new([TInstr::call(FuncIdx::new(1U), [])]),
        Some(TExpr::new([TInstr::local_get(LocalIdx::new(1U))])),
      ),
    ]),
  )
  let callee = Func::t_func([], TExpr::new([TInstr::i32_const(I32(7))]))
  let mod = Module::new()
    .with_type_sec(type_sec)
    .with_func_sec(FuncSec::new([TypeIdx::new(0U), TypeIdx::new(1U)]))
    .with_code_sec(CodeSec::new([main, callee]))

  let printed = mod.pretty_print_defined_func(0U)
  assert_true(printed.contains("func code[0] abs[0]"))
  assert_true(printed.contains("type_idx: (Type 0) => FuncType"))
  assert_true(printed.contains("[0] I32 (param)"))
  assert_true(printed.contains("[1] I32 (local)"))
  assert_true(printed.contains("- if bt=(Type 1) => FuncType"))
  assert_true(printed.contains("- call (Func 1) => (Type 1) => FuncType"))
  assert_true(printed.contains("- local.get (Local 0) : I32 (param)"))
}

///|
test "pretty_print_func reports imported function signatures" {
  let mod = Module::new()
    .with_import_sec(
      ImportSec::new([
        Import::new(
          Name::from_string("env"),
          Name::from_string("callee"),
          ExternType::func(TypeIdx::new(0U)),
        ),
      ]),
    )
    .with_type_sec(
      TypeSec::new([
        RecType::new(SubType::comp_type(CompType::func([ValType::i64()], []))),
      ]),
    )

  let printed = mod.pretty_print_func(FuncIdx::new(0U))
  assert_true(printed.contains("func abs[0] import"), msg=printed)
  assert_true(printed.contains("module: \"env\""), msg=printed)
  assert_true(printed.contains("field: \"callee\""), msg=printed)
  assert_true(printed.contains("type_idx: (Type 0) => FuncType"), msg=printed)
}
