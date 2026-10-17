///|
fn module_name_section_fixture() -> @lib.Module {
  @lib.Module::new()
  .with_type_sec(
    @lib.TypeSec::new([
      @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
      @lib.RecType::new(
        @lib.SubType::comp_type(
          @lib.CompType::struct_([
            @lib.FieldType::new(
              @lib.StorageType::val_type(@lib.ValType::i32()),
              @lib.Mut::const_(),
            ),
          ]),
        ),
      ),
    ]),
  )
  .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
  .with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(
        @lib.Locals::single(1U, @lib.ValType::i32()),
        @lib.Expr::new([
          @lib.Instruction::block(@lib.BlockType::void_(), @lib.Expr::new([])),
        ]),
      ),
    ]),
  )
}

///|
fn module_name_section_map(index : UInt32) -> @lib.NameMap {
  @lib.NameMap::new([
    @lib.NameAssoc::new(index, @lib.Name::from_string("entry")),
  ])
}

///|
fn module_name_section_indirect(
  outer : UInt32,
  inner : UInt32,
) -> @lib.IndirectNameMap {
  @lib.IndirectNameMap::new([
    @lib.IndirectNameAssoc::new(outer, module_name_section_map(inner)),
  ])
}

///|
test "name section wrapper accepts valid names without mutating module ownership" {
  let input = module_name_section_fixture().with_name_sec(
    @lib.NameSec::new(
      module_name=Some(@lib.Name::from_string("module")),
      func_names=Some(module_name_section_map(0U)),
      local_names=Some(module_name_section_indirect(0U, 0U)),
      label_names=Some(module_name_section_indirect(0U, 0U)),
      type_names=Some(module_name_section_map(1U)),
      field_names=Some(module_name_section_indirect(1U, 0U)),
    ),
  )
  validate_module(input).unwrap()
  let saved = @binary.encode_module(input).unwrap()
  let names = input.name_sec.unwrap()
  assert_eq(validate_module_name_section(input), Ok(()))
  assert_true(physical_equal(input.name_sec.unwrap(), names))
  assert_eq(@binary.encode_module(input).unwrap(), saved)
  assert_eq(validate_module_name_section(input.without_name_sec()), Ok(()))
  assert_eq(
    validate_module_name_section(validate_name_section_fixture_module()),
    Ok(()),
  )
}

///|
test "name section wrapper rejects intentionally invalid name indices and field kinds exactly" {
  let input = module_name_section_fixture()
  for
    names in [
      @lib.NameSec::new(func_names=Some(module_name_section_map(1U))),
      @lib.NameSec::new(local_names=Some(module_name_section_indirect(0U, 1U))),
      @lib.NameSec::new(label_names=Some(module_name_section_indirect(0U, 1U))),
      @lib.NameSec::new(type_names=Some(module_name_section_map(2U))),
      @lib.NameSec::new(table_names=Some(module_name_section_map(0U))),
      @lib.NameSec::new(memory_names=Some(module_name_section_map(0U))),
      @lib.NameSec::new(global_names=Some(module_name_section_map(0U))),
      @lib.NameSec::new(elem_names=Some(module_name_section_map(0U))),
      @lib.NameSec::new(data_names=Some(module_name_section_map(0U))),
      @lib.NameSec::new(field_names=Some(module_name_section_indirect(0U, 0U))),
      @lib.NameSec::new(field_names=Some(module_name_section_indirect(1U, 1U))),
      @lib.NameSec::new(tag_names=Some(module_name_section_map(0U))),
    ] {
    let candidate = input.with_name_sec(names)
    let expected = validate_name_sec(
      candidate,
      Env::new().with_module(candidate),
      0,
    )
    assert_true(expected is Err(_))
    assert_eq(validate_module_name_section(candidate), expected)
  }
}

///|
test "name section wrapper keeps imported and defined local and label index spaces distinct" {
  let input = validate_import_name_section_fixture_module()
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::single(1U, @lib.ValType::i32()),
          @lib.Expr::new([
            @lib.Instruction::block(@lib.BlockType::void_(), @lib.Expr::new([])),
          ]),
        ),
      ]),
    )
    .with_name_sec(
      @lib.NameSec::new(
        local_names=Some(
          @lib.IndirectNameMap::new([
            @lib.IndirectNameAssoc::new(0U, module_name_section_map(0U)),
            @lib.IndirectNameAssoc::new(1U, module_name_section_map(1U)),
          ]),
        ),
        label_names=Some(module_name_section_indirect(1U, 0U)),
      ),
    )
  validate_module(input).unwrap()
  assert_eq(validate_module_name_section(input), Ok(()))
  // Imports have parameter names, but no declared locals or body labels.
  for
    names in [
      @lib.NameSec::new(local_names=Some(module_name_section_indirect(0U, 1U))),
      @lib.NameSec::new(label_names=Some(module_name_section_indirect(0U, 0U))),
    ] {
    let candidate = input.with_name_sec(names)
    let expected = validate_name_sec(
      candidate,
      Env::new().with_module(candidate),
      1,
    )
    assert_true(expected is Err(_))
    assert_eq(validate_module_name_section(candidate), expected)
  }
}
