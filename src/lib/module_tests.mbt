///|
test "pretty_print_defined_func resolves signatures and locals for raw funcs" {
  let type_sec = TypeSec::new([
    RecType::new(
      SubType::comp_type(CompType::func([ValType::i32()], [ValType::i32()])),
    ),
    RecType::new(SubType::comp_type(CompType::func([], [ValType::i32()]))),
  ])
  let main = Func::new(
    Locals::from_types([ValType::i32()]),
    Expr([
      LocalGet(LocalIdx::new(0U)),
      If(
        BlockType::type_idx(TypeIdx::new(1U)),
        [Call(FuncIdx::new(1U))],
        Some([LocalGet(LocalIdx::new(1U))]),
      ),
    ]),
  )
  let callee = Func::new(Locals::empty(), Expr([I32Const(I32(7))]))
  let mod = Module::new()
    .with_type_sec(type_sec)
    .with_func_sec(FuncSec::new([TypeIdx::new(0U), TypeIdx::new(1U)]))
    .with_code_sec(CodeSec::new([main, callee]))

  let printed = mod.pretty_print_defined_func(0U)
  assert_true(printed.contains("func code[0] abs[0]"))
  assert_true(printed.contains("type_idx: (Type 0 (Func [I32] -> [I32]))"))
  assert_true(printed.contains("[0] I32 (param)"))
  assert_true(printed.contains("[1] I32 (local)"))
  assert_true(printed.contains("body_raw:"))
  assert_true(printed.contains("local.get"))
  assert_true(printed.contains("call"))
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
  assert_true(
    printed.contains("type_idx: (Type 0 (Func [I64] -> []))"),
    msg=printed,
  )
}

///|
test "without_name_sec clears the structured name section" {
  let mod = Module::new().with_name_sec(
    NameSec::new(
      func_names=Some(NameMap::new([NameAssoc::new(0U, Name::new("f"))])),
    ),
  )
  assert_true(mod.name_sec is Some(_))
  assert_eq(mod.without_name_sec().name_sec, None)
}
///|
test "with_name_sec and without_name_sec clear cached raw name payload" {
  let mod = Module::new()
    .with_name_sec(
      NameSec::new(
        func_names=Some(NameMap::new([NameAssoc::new(0U, Name::new("f"))])),
      ),
    )
    .with_raw_name_sec_payload(b"raw")
  assert_eq(mod.raw_name_sec_payload, Some(b"raw"))
  let replaced = mod.with_name_sec(
    NameSec::new(
      func_names=Some(NameMap::new([NameAssoc::new(0U, Name::new("g"))])),
    ),
  )
  assert_eq(replaced.raw_name_sec_payload, None)
  assert_eq(replaced.without_name_sec().raw_name_sec_payload, None)
}
