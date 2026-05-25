///|
fn assert_metamorphic_roundtrip_valid(
  mod : @lib.Module,
) -> Result[Unit, String] {
  match validate_module(mod) {
    Ok(_) => ()
    Err(err) => return Err(validation_error_message(err))
  }
  let encoded = match encode_module(mod) {
    Ok(bytes) => bytes
    Err(msg) => return Err("encode failed: \{msg}")
  }
  let decoded = match decode_module(encoded) {
    Ok(mod) => mod
    Err(msg) => return Err("decode failed: \{msg}")
  }
  match validate_module(decoded) {
    Ok(_) => Ok(())
    Err(err) =>
      Err(
        "decoded transformed module invalid: \{validation_error_message(err)}",
      )
  }
}

///|
fn metamorphic_wbtest_flat_type_count(rec_types : Array[@lib.RecType]) -> Int {
  let mut count = 0
  for rec_type in rec_types {
    match rec_type {
      @lib.SingleRecType(_) => count += 1
      @lib.GroupRecType(group) => count += group.length()
    }
  }
  count
}

///|
test "metamorphic add-custom transform preserves validation and binary roundtrip" {
  let generated = match
    gen_valid_module_result_from_seed(
      0x1036UL,
      GenValidConfig::natural_default(),
    ) {
    Ok(v) => v
    Err(e) =>
      fail("expected valid GenValid seed, got \{e.validation_error_message}")
  }
  let transformed = match
    metamorphic_apply_transform(generated.wasm_module, AddNonNameCustomSection) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  @debug.assert_eq(transformed.transform_id, "add-non-name-custom-section")
  @debug.assert_eq(
    transformed.wasm_module.custom_secs.length(),
    generated.wasm_module.custom_secs.length() + 1,
  )
  match assert_metamorphic_roundtrip_valid(transformed.wasm_module) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "metamorphic leading custom-section transform preserves validation and binary roundtrip" {
  let generated = match
    gen_valid_module_result_from_seed(
      0x1038UL,
      GenValidConfig::natural_default(),
    ) {
    Ok(v) => v
    Err(e) =>
      fail("expected valid GenValid seed, got \{e.validation_error_message}")
  }
  let transformed = match
    metamorphic_apply_transform(
      generated.wasm_module,
      AddLeadingNonNameCustomSection,
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  @debug.assert_eq(
    transformed.transform_id,
    "add-leading-non-name-custom-section",
  )
  @debug.assert_eq(
    transformed.wasm_module.custom_secs.length(),
    generated.wasm_module.custom_secs.length() + 1,
  )
  match transformed.wasm_module.custom_secs[0] {
    @lib.CustomSec(name, _) =>
      @debug.assert_eq(
        name,
        @lib.Name::from_string(
          "starshine.metamorphic.add-leading-non-name-custom-section",
        ),
      )
  }
  match assert_metamorphic_roundtrip_valid(transformed.wasm_module) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "metamorphic custom-section stress transform preserves varied payloads and binary roundtrip" {
  let generated = match
    gen_valid_module_result_from_seed(
      0x1038BUL,
      GenValidConfig::natural_default(),
    ) {
    Ok(v) => v
    Err(e) =>
      fail("expected valid GenValid seed, got \{e.validation_error_message}")
  }
  let transformed = match
    metamorphic_apply_transform(generated.wasm_module, AddCustomSectionStress) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  @debug.assert_eq(transformed.transform_id, "add-custom-section-stress")
  @debug.assert_eq(
    transformed.wasm_module.custom_secs.length(),
    generated.wasm_module.custom_secs.length() + 4,
  )
  let first = generated.wasm_module.custom_secs.length()
  match transformed.wasm_module.custom_secs[first] {
    @lib.CustomSec(name, payload) => {
      @debug.assert_eq(name, @lib.Name::from_string("starshine.fuzz.empty"))
      @debug.assert_eq(payload.length(), 0)
    }
  }
  match transformed.wasm_module.custom_secs[first + 1] {
    @lib.CustomSec(name, payload) => {
      @debug.assert_eq(name, @lib.Name::from_string("starshine.fuzz.bytes"))
      @debug.assert_eq(payload, b"\x00\x01\x7f\x80\xffpayload")
    }
  }
  match transformed.wasm_module.custom_secs[first + 2] {
    @lib.CustomSec(name, payload) => {
      @debug.assert_eq(
        name,
        @lib.Name::from_string("starshine.fuzz.unicode-☄"),
      )
      @debug.assert_eq(payload, b"utf8-name custom payload")
    }
  }
  match transformed.wasm_module.custom_secs[first + 3] {
    @lib.CustomSec(name, payload) => {
      @debug.assert_eq(
        name,
        @lib.Name::from_string("starshine.fuzz.long-payload"),
      )
      @debug.assert_eq(payload.length(), 96)
    }
  }
  match assert_metamorphic_roundtrip_valid(transformed.wasm_module) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "metamorphic type-names transform preserves validation and binary roundtrip" {
  let generated = match
    gen_valid_module_result_from_seed(
      0x1041UL,
      GenValidConfig::natural_default(),
    ) {
    Ok(v) => v
    Err(e) =>
      fail("expected valid GenValid seed, got \{e.validation_error_message}")
  }
  let original_flat_type_count = match generated.wasm_module.type_sec {
    Some(@lib.TypeSec(types)) => metamorphic_wbtest_flat_type_count(types)
    None => 0
  }
  let transformed = match
    metamorphic_apply_transform(generated.wasm_module, AddTypeNamesSection) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  @debug.assert_eq(transformed.transform_id, "add-type-names-section")
  match transformed.wasm_module.name_sec {
    Some(name_sec) =>
      match name_sec.type_names {
        Some(@lib.NameMap(entries)) => {
          @debug.assert_eq(entries.length(), original_flat_type_count)
          if entries.length() > 0 {
            @debug.assert_eq(
              entries[0],
              @lib.NameAssoc::new(
                0U,
                @lib.Name::from_string("metamorphic_type_0"),
              ),
            )
          }
        }
        None => fail("expected transformed type names")
      }
    None => fail("expected transformed name section")
  }
  match assert_metamorphic_roundtrip_valid(transformed.wasm_module) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "metamorphic table-names transform preserves validation and binary roundtrip" {
  let generated = match
    gen_valid_module_result_from_seed(
      0x1043UL,
      GenValidConfig::natural_default(),
    ) {
    Ok(v) => v
    Err(e) =>
      fail("expected valid GenValid seed, got \{e.validation_error_message}")
  }
  let imported_table_count = match generated.wasm_module.import_sec {
    Some(@lib.ImportSec(imports)) => {
      let mut count = 0
      for import_ in imports {
        match import_ {
          @lib.Import(_, _, @lib.TableExternType(_)) => count += 1
          _ => ()
        }
      }
      count
    }
    None => 0
  }
  let defined_table_count = match generated.wasm_module.table_sec {
    Some(@lib.TableSec(tables)) => tables.length()
    None => 0
  }
  let transformed = match
    metamorphic_apply_transform(generated.wasm_module, AddTableNamesSection) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  @debug.assert_eq(transformed.transform_id, "add-table-names-section")
  match transformed.wasm_module.name_sec {
    Some(name_sec) =>
      match name_sec.table_names {
        Some(@lib.NameMap(entries)) => {
          @debug.assert_eq(
            entries.length(),
            imported_table_count + defined_table_count,
          )
          if entries.length() > 0 {
            @debug.assert_eq(
              entries[0],
              @lib.NameAssoc::new(
                0U,
                @lib.Name::from_string("metamorphic_table_0"),
              ),
            )
          }
        }
        None => fail("expected transformed table names")
      }
    None => fail("expected transformed name section")
  }
  match assert_metamorphic_roundtrip_valid(transformed.wasm_module) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "metamorphic memory-names transform preserves validation and binary roundtrip" {
  let generated = match
    gen_valid_module_result_from_seed(
      0x1044UL,
      GenValidConfig::natural_default(),
    ) {
    Ok(v) => v
    Err(e) =>
      fail("expected valid GenValid seed, got \{e.validation_error_message}")
  }
  let imported_memory_count = match generated.wasm_module.import_sec {
    Some(@lib.ImportSec(imports)) => {
      let mut count = 0
      for import_ in imports {
        match import_ {
          @lib.Import(_, _, @lib.MemExternType(_)) => count += 1
          _ => ()
        }
      }
      count
    }
    None => 0
  }
  let defined_memory_count = match generated.wasm_module.mem_sec {
    Some(@lib.MemSec(mems)) => mems.length()
    None => 0
  }
  let transformed = match
    metamorphic_apply_transform(generated.wasm_module, AddMemoryNamesSection) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  @debug.assert_eq(transformed.transform_id, "add-memory-names-section")
  match transformed.wasm_module.name_sec {
    Some(name_sec) =>
      match name_sec.memory_names {
        Some(@lib.NameMap(entries)) => {
          @debug.assert_eq(
            entries.length(),
            imported_memory_count + defined_memory_count,
          )
          if entries.length() > 0 {
            @debug.assert_eq(
              entries[0],
              @lib.NameAssoc::new(
                0U,
                @lib.Name::from_string("metamorphic_memory_0"),
              ),
            )
          }
        }
        None => fail("expected transformed memory names")
      }
    None => fail("expected transformed name section")
  }
  match assert_metamorphic_roundtrip_valid(transformed.wasm_module) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "metamorphic tag-names transform preserves validation and binary roundtrip" {
  let generated = match
    gen_valid_module_result_from_seed(
      0x1047UL,
      GenValidConfig::natural_default(),
    ) {
    Ok(v) => v
    Err(e) =>
      fail("expected valid GenValid seed, got \{e.validation_error_message}")
  }
  let imported_tag_count = match generated.wasm_module.import_sec {
    Some(@lib.ImportSec(imports)) => {
      let mut count = 0
      for import_ in imports {
        match import_ {
          @lib.Import(_, _, @lib.TagExternType(_)) => count += 1
          _ => ()
        }
      }
      count
    }
    None => 0
  }
  let defined_tag_count = match generated.wasm_module.tag_sec {
    Some(@lib.TagSec(tags)) => tags.length()
    None => 0
  }
  let transformed = match
    metamorphic_apply_transform(generated.wasm_module, AddTagNamesSection) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  @debug.assert_eq(transformed.transform_id, "add-tag-names-section")
  match transformed.wasm_module.name_sec {
    Some(name_sec) =>
      match name_sec.tag_names {
        Some(@lib.NameMap(entries)) => {
          @debug.assert_eq(
            entries.length(),
            imported_tag_count + defined_tag_count,
          )
          if entries.length() > 0 {
            @debug.assert_eq(
              entries[0],
              @lib.NameAssoc::new(
                0U,
                @lib.Name::from_string("metamorphic_tag_0"),
              ),
            )
          }
        }
        None => fail("expected transformed tag names")
      }
    None => fail("expected transformed name section")
  }
  match assert_metamorphic_roundtrip_valid(transformed.wasm_module) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "metamorphic label-names transform preserves validation and binary roundtrip" {
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [])),
  )
  let base = @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([func_type]))
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::block(
              @lib.BlockType::void_(),
              @lib.Expr::new([
                @lib.Instruction::loop_(
                  @lib.BlockType::void_(),
                  @lib.Expr::new([]),
                ),
              ]),
            ),
          ]),
        ),
      ]),
    )
  let transformed = match
    metamorphic_apply_transform(base, AddLabelNamesSection) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  @debug.assert_eq(transformed.transform_id, "add-label-names-section")
  match transformed.wasm_module.name_sec {
    Some(name_sec) =>
      match name_sec.label_names {
        Some(@lib.IndirectNameMap(entries)) => {
          @debug.assert_eq(entries.length(), 1)
          match entries[0] {
            @lib.IndirectNameAssoc(func_idx, @lib.NameMap(label_entries)) => {
              @debug.assert_eq(func_idx, 0U)
              @debug.assert_eq(label_entries.length(), 2)
              @debug.assert_eq(
                label_entries[0],
                @lib.NameAssoc::new(
                  0U,
                  @lib.Name::from_string("metamorphic_label_0_0"),
                ),
              )
              @debug.assert_eq(
                label_entries[1],
                @lib.NameAssoc::new(
                  1U,
                  @lib.Name::from_string("metamorphic_label_0_1"),
                ),
              )
            }
          }
        }
        None => fail("expected transformed label names")
      }
    None => fail("expected transformed name section")
  }
  match assert_metamorphic_roundtrip_valid(transformed.wasm_module) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "metamorphic field-names transform preserves validation and binary roundtrip" {
  let struct_type = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::struct_([
        @lib.FieldType::new(
          @lib.StorageType::val_type(@lib.ValType::i32()),
          @lib.Const,
        ),
        @lib.FieldType::new(
          @lib.StorageType::val_type(@lib.ValType::i64()),
          @lib.Var,
        ),
      ]),
    ),
  )
  let array_type = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::array(
        @lib.FieldType::new(
          @lib.StorageType::val_type(@lib.ValType::i32()),
          @lib.Var,
        ),
      ),
    ),
  )
  let base = @lib.Module::new().with_type_sec(
    @lib.TypeSec::new([struct_type, array_type]),
  )
  let transformed = match
    metamorphic_apply_transform(base, AddFieldNamesSection) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  @debug.assert_eq(transformed.transform_id, "add-field-names-section")
  match transformed.wasm_module.name_sec {
    Some(name_sec) =>
      match name_sec.field_names {
        Some(@lib.IndirectNameMap(entries)) => {
          @debug.assert_eq(entries.length(), 1)
          match entries[0] {
            @lib.IndirectNameAssoc(type_idx, @lib.NameMap(field_entries)) => {
              @debug.assert_eq(type_idx, 0U)
              @debug.assert_eq(field_entries.length(), 2)
              @debug.assert_eq(
                field_entries[0],
                @lib.NameAssoc::new(
                  0U,
                  @lib.Name::from_string("metamorphic_field_0_0"),
                ),
              )
              @debug.assert_eq(
                field_entries[1],
                @lib.NameAssoc::new(
                  1U,
                  @lib.Name::from_string("metamorphic_field_0_1"),
                ),
              )
            }
          }
        }
        None => fail("expected transformed field names")
      }
    None => fail("expected transformed name section")
  }
  match assert_metamorphic_roundtrip_valid(transformed.wasm_module) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "metamorphic elem-names transform preserves validation and binary roundtrip" {
  let generated = match
    gen_valid_module_result_from_seed(
      0x1046UL,
      GenValidConfig::natural_default(),
    ) {
    Ok(v) => v
    Err(e) =>
      fail("expected valid GenValid seed, got \{e.validation_error_message}")
  }
  let with_elem = match
    metamorphic_apply_transform(
      generated.wasm_module,
      AddUnusedPassiveFuncrefElementSegment,
    ) {
    Ok(v) => v.wasm_module
    Err(msg) => fail(msg)
  }
  let original_elem_count = match with_elem.elem_sec {
    Some(@lib.ElemSec(elems)) => elems.length()
    None => 0
  }
  let transformed = match
    metamorphic_apply_transform(with_elem, AddElemNamesSection) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  @debug.assert_eq(transformed.transform_id, "add-elem-names-section")
  match transformed.wasm_module.name_sec {
    Some(name_sec) =>
      match name_sec.elem_names {
        Some(@lib.NameMap(entries)) => {
          @debug.assert_eq(entries.length(), original_elem_count)
          if entries.length() > 0 {
            @debug.assert_eq(
              entries[0],
              @lib.NameAssoc::new(
                0U,
                @lib.Name::from_string("metamorphic_elem_0"),
              ),
            )
          }
        }
        None => fail("expected transformed elem names")
      }
    None => fail("expected transformed name section")
  }
  match assert_metamorphic_roundtrip_valid(transformed.wasm_module) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "metamorphic data-names transform preserves validation and binary roundtrip" {
  let generated = match
    gen_valid_module_result_from_seed(
      0x1045UL,
      GenValidConfig::natural_default(),
    ) {
    Ok(v) => v
    Err(e) =>
      fail("expected valid GenValid seed, got \{e.validation_error_message}")
  }
  let with_data = match
    metamorphic_apply_transform(
      generated.wasm_module,
      AddUnusedPassiveDataSegment,
    ) {
    Ok(v) => v.wasm_module
    Err(msg) => fail(msg)
  }
  let original_data_count = match with_data.data_sec {
    Some(@lib.DataSec(datas)) => datas.length()
    None => 0
  }
  let transformed = match
    metamorphic_apply_transform(with_data, AddDataNamesSection) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  @debug.assert_eq(transformed.transform_id, "add-data-names-section")
  match transformed.wasm_module.name_sec {
    Some(name_sec) =>
      match name_sec.data_names {
        Some(@lib.NameMap(entries)) => {
          @debug.assert_eq(entries.length(), original_data_count)
          if entries.length() > 0 {
            @debug.assert_eq(
              entries[0],
              @lib.NameAssoc::new(
                0U,
                @lib.Name::from_string("metamorphic_data_0"),
              ),
            )
          }
        }
        None => fail("expected transformed data names")
      }
    None => fail("expected transformed name section")
  }
  match assert_metamorphic_roundtrip_valid(transformed.wasm_module) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "metamorphic global-names transform preserves validation and binary roundtrip" {
  let generated = match
    gen_valid_module_result_from_seed(
      0x1042UL,
      GenValidConfig::natural_default(),
    ) {
    Ok(v) => v
    Err(e) =>
      fail("expected valid GenValid seed, got \{e.validation_error_message}")
  }
  let imported_global_count = match generated.wasm_module.import_sec {
    Some(@lib.ImportSec(imports)) => {
      let mut count = 0
      for import_ in imports {
        match import_ {
          @lib.Import(_, _, @lib.GlobalExternType(_)) => count += 1
          _ => ()
        }
      }
      count
    }
    None => 0
  }
  let defined_global_count = match generated.wasm_module.global_sec {
    Some(@lib.GlobalSec(globals)) => globals.length()
    None => 0
  }
  let transformed = match
    metamorphic_apply_transform(generated.wasm_module, AddGlobalNamesSection) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  @debug.assert_eq(transformed.transform_id, "add-global-names-section")
  match transformed.wasm_module.name_sec {
    Some(name_sec) =>
      match name_sec.global_names {
        Some(@lib.NameMap(entries)) => {
          @debug.assert_eq(
            entries.length(),
            imported_global_count + defined_global_count,
          )
          if entries.length() > 0 {
            @debug.assert_eq(
              entries[0],
              @lib.NameAssoc::new(
                0U,
                @lib.Name::from_string("metamorphic_global_0"),
              ),
            )
          }
        }
        None => fail("expected transformed global names")
      }
    None => fail("expected transformed name section")
  }
  match assert_metamorphic_roundtrip_valid(transformed.wasm_module) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "metamorphic local-names transform preserves validation and binary roundtrip" {
  let generated = match
    gen_valid_module_result_from_seed(
      0x1040UL,
      GenValidConfig::natural_default(),
    ) {
    Ok(v) => v
    Err(e) =>
      fail("expected valid GenValid seed, got \{e.validation_error_message}")
  }
  let imported_func_count = match generated.wasm_module.import_sec {
    Some(@lib.ImportSec(imports)) => {
      let mut count = 0
      for import_ in imports {
        match import_ {
          @lib.Import(_, _, @lib.FuncExternType(_)) => count += 1
          _ => ()
        }
      }
      count
    }
    None => 0
  }
  let defined_func_count = match generated.wasm_module.func_sec {
    Some(@lib.FuncSec(type_idxs)) => type_idxs.length()
    None => 0
  }
  let transformed = match
    metamorphic_apply_transform(generated.wasm_module, AddLocalNamesSection) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  @debug.assert_eq(transformed.transform_id, "add-local-names-section")
  match transformed.wasm_module.name_sec {
    Some(name_sec) =>
      match name_sec.local_names {
        Some(@lib.IndirectNameMap(entries)) => {
          @debug.assert_eq(
            entries.length(),
            imported_func_count + defined_func_count,
          )
          if entries.length() > 0 {
            match entries[0] {
              @lib.IndirectNameAssoc(func_idx, @lib.NameMap(local_entries)) => {
                @debug.assert_eq(func_idx, 0U)
                if local_entries.length() > 0 {
                  @debug.assert_eq(
                    local_entries[0],
                    @lib.NameAssoc::new(
                      0U,
                      @lib.Name::from_string("metamorphic_local_0_0"),
                    ),
                  )
                }
              }
            }
          }
        }
        None => fail("expected transformed local names")
      }
    None => fail("expected transformed name section")
  }
  match assert_metamorphic_roundtrip_valid(transformed.wasm_module) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "metamorphic function-names transform preserves validation and binary roundtrip" {
  let generated = match
    gen_valid_module_result_from_seed(
      0x103fUL,
      GenValidConfig::natural_default(),
    ) {
    Ok(v) => v
    Err(e) =>
      fail("expected valid GenValid seed, got \{e.validation_error_message}")
  }
  let original_imported_func_count = match generated.wasm_module.import_sec {
    Some(@lib.ImportSec(imports)) => {
      let mut count = 0
      for import_ in imports {
        match import_ {
          @lib.Import(_, _, @lib.FuncExternType(_)) => count += 1
          _ => ()
        }
      }
      count
    }
    None => 0
  }
  let original_defined_func_count = match generated.wasm_module.func_sec {
    Some(@lib.FuncSec(type_idxs)) => type_idxs.length()
    None => 0
  }
  let transformed = match
    metamorphic_apply_transform(generated.wasm_module, AddFunctionNamesSection) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  @debug.assert_eq(transformed.transform_id, "add-function-names-section")
  match transformed.wasm_module.name_sec {
    Some(name_sec) =>
      match name_sec.func_names {
        Some(@lib.NameMap(entries)) => {
          @debug.assert_eq(
            entries.length(),
            original_imported_func_count + original_defined_func_count,
          )
          if entries.length() > 0 {
            @debug.assert_eq(
              entries[0],
              @lib.NameAssoc::new(
                0U,
                @lib.Name::from_string("metamorphic_func_0"),
              ),
            )
          }
        }
        None => fail("expected transformed function names")
      }
    None => fail("expected transformed name section")
  }
  match assert_metamorphic_roundtrip_valid(transformed.wasm_module) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "metamorphic unused funcref-table transform preserves validation and binary roundtrip" {
  let generated = match
    gen_valid_module_result_from_seed(
      0x103dUL,
      GenValidConfig::natural_default(),
    ) {
    Ok(v) => v
    Err(e) =>
      fail("expected valid GenValid seed, got \{e.validation_error_message}")
  }
  let original_table_count = match generated.wasm_module.table_sec {
    Some(@lib.TableSec(tables)) => tables.length()
    None => 0
  }
  let transformed = match
    metamorphic_apply_transform(generated.wasm_module, AddUnusedFuncrefTable) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  @debug.assert_eq(transformed.transform_id, "add-unused-funcref-table")
  match transformed.wasm_module.table_sec {
    Some(@lib.TableSec(tables)) => {
      @debug.assert_eq(tables.length(), original_table_count + 1)
      match tables[tables.length() - 1] {
        @lib.Table(table_type, init) => {
          @debug.assert_eq(
            table_type,
            @lib.TableType::new(
              @lib.RefType::abs(@lib.AbsHeapType::func()),
              @lib.Limits::i32(0U, Some(0U)),
            ),
          )
          @debug.assert_eq(init, None)
        }
      }
    }
    None => fail("expected transformed table section")
  }
  match assert_metamorphic_roundtrip_valid(transformed.wasm_module) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "metamorphic unused passive funcref element transform preserves validation and binary roundtrip" {
  let generated = match
    gen_valid_module_result_from_seed(
      0x103eUL,
      GenValidConfig::natural_default(),
    ) {
    Ok(v) => v
    Err(e) =>
      fail("expected valid GenValid seed, got \{e.validation_error_message}")
  }
  let original_elem_count = match generated.wasm_module.elem_sec {
    Some(@lib.ElemSec(elems)) => elems.length()
    None => 0
  }
  let transformed = match
    metamorphic_apply_transform(
      generated.wasm_module,
      AddUnusedPassiveFuncrefElementSegment,
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  @debug.assert_eq(
    transformed.transform_id,
    "add-unused-passive-funcref-element-segment",
  )
  match transformed.wasm_module.elem_sec {
    Some(@lib.ElemSec(elems)) => {
      @debug.assert_eq(elems.length(), original_elem_count + 1)
      match elems[elems.length() - 1] {
        @lib.Elem(@lib.Passive, @lib.FuncsElemKind(func_idxs)) =>
          @debug.assert_eq(func_idxs, [])
        _ => fail("expected trailing passive empty funcref element segment")
      }
    }
    None => fail("expected transformed element section")
  }
  match assert_metamorphic_roundtrip_valid(transformed.wasm_module) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "metamorphic passive element reshaping preserves func references" {
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [])),
  )
  let base = @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([func_type]))
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new([])),
      ]),
    )
    .with_elem_sec(
      @lib.ElemSec::new([
        @lib.Elem::new(
          @lib.ElemMode::passive(),
          @lib.ElemKind::funcs([@lib.FuncIdx::new(0U)]),
        ),
      ]),
    )
  let transformed = match
    metamorphic_apply_transform(base, ReshapePassiveElementSegments) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  @debug.assert_eq(transformed.transform_id, "reshape-passive-element-segments")
  match transformed.wasm_module.elem_sec {
    Some(@lib.ElemSec(elems)) =>
      match elems[0] {
        @lib.Elem(@lib.Passive, @lib.TypedExprsElemKind(rt, exprs)) => {
          @debug.assert_eq(rt, @lib.RefType::abs(@lib.AbsHeapType::func()))
          @debug.assert_eq(exprs.length(), 1)
          @debug.assert_eq(
            exprs[0],
            @lib.Expr::new([@lib.Instruction::ref_func(@lib.FuncIdx::new(0U))]),
          )
        }
        _ => fail("expected reshaped passive typed ref.func element segment")
      }
    None => fail("expected transformed element section")
  }
  match assert_metamorphic_roundtrip_valid(transformed.wasm_module) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "metamorphic unused empty function-type transform preserves validation and binary roundtrip" {
  let generated = match
    gen_valid_module_result_from_seed(
      0x103cUL,
      GenValidConfig::natural_default(),
    ) {
    Ok(v) => v
    Err(e) =>
      fail("expected valid GenValid seed, got \{e.validation_error_message}")
  }
  let original_rec_type_count = match generated.wasm_module.type_sec {
    Some(@lib.TypeSec(types)) => types.length()
    None => 0
  }
  let original_flat_type_count = match generated.wasm_module.type_sec {
    Some(@lib.TypeSec(types)) => metamorphic_wbtest_flat_type_count(types)
    None => 0
  }
  let transformed = match
    metamorphic_apply_transform(
      generated.wasm_module,
      AddUnusedEmptyFunctionType,
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  @debug.assert_eq(transformed.transform_id, "add-unused-empty-function-type")
  match transformed.wasm_module.type_sec {
    Some(@lib.TypeSec(types)) => {
      @debug.assert_eq(types.length(), original_rec_type_count + 1)
      match types[types.length() - 1] {
        @lib.SingleRecType(
          @lib.CompTypeSubType(_, @lib.FuncCompType(params, results))
        ) => {
          @debug.assert_eq(params, [])
          @debug.assert_eq(results, [])
        }
        _ => fail("expected trailing [] -> [] function type")
      }
    }
    None => fail("expected transformed type section")
  }
  @debug.assert_eq(
    metamorphic_wbtest_flat_type_count(
      match transformed.wasm_module.type_sec {
        Some(@lib.TypeSec(types)) => types
        None => []
      },
    ),
    original_flat_type_count + 1,
  )
  match assert_metamorphic_roundtrip_valid(transformed.wasm_module) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "metamorphic duplicate equivalent function-type transform preserves validation and binary roundtrip" {
  let original_func_type = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::func([@lib.ValType::i32()], [@lib.ValType::i64()]),
    ),
  )
  let base = @lib.Module::new().with_type_sec(
    @lib.TypeSec::new([original_func_type]),
  )
  let transformed = match
    metamorphic_apply_transform(base, AddDuplicateEquivalentFunctionType) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  @debug.assert_eq(
    transformed.transform_id,
    "add-duplicate-equivalent-function-type",
  )
  match transformed.wasm_module.type_sec {
    Some(@lib.TypeSec(types)) => {
      @debug.assert_eq(types.length(), 2)
      @debug.assert_eq(types[0], original_func_type)
      @debug.assert_eq(types[1], original_func_type)
    }
    None => fail("expected transformed type section")
  }
  match assert_metamorphic_roundtrip_valid(transformed.wasm_module) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "metamorphic duplicate equivalent fixed function-type transforms append unused declaration pairs" {
  let base = @lib.Module::new()
  let empty = match
    metamorphic_apply_transform(base, AddDuplicateEquivalentEmptyFunctionTypes) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  @debug.assert_eq(
    empty.transform_id,
    "add-duplicate-equivalent-empty-function-types",
  )
  match empty.wasm_module.type_sec {
    Some(@lib.TypeSec(types)) => {
      @debug.assert_eq(types.length(), 2)
      @debug.assert_eq(types[0], types[1])
      match types[0] {
        @lib.SingleRecType(
          @lib.CompTypeSubType(_, @lib.FuncCompType(params, results))
        ) => {
          @debug.assert_eq(params, [])
          @debug.assert_eq(results, [])
        }
        _ => fail("expected duplicate [] -> [] function types")
      }
    }
    None => fail("expected transformed type section")
  }
  match assert_metamorphic_roundtrip_valid(empty.wasm_module) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }

  let scalar = match
    metamorphic_apply_transform(
      @lib.Module::new(),
      AddDuplicateEquivalentScalarFunctionTypes,
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  @debug.assert_eq(
    scalar.transform_id,
    "add-duplicate-equivalent-scalar-function-types",
  )
  match scalar.wasm_module.type_sec {
    Some(@lib.TypeSec(types)) => {
      @debug.assert_eq(types.length(), 2)
      @debug.assert_eq(types[0], types[1])
      match types[0] {
        @lib.SingleRecType(
          @lib.CompTypeSubType(_, @lib.FuncCompType(params, results))
        ) => {
          @debug.assert_eq(params, [@lib.ValType::i32()])
          @debug.assert_eq(results, [@lib.ValType::i64()])
        }
        _ => fail("expected duplicate i32 -> i64 function types")
      }
    }
    None => fail("expected transformed type section")
  }
  match assert_metamorphic_roundtrip_valid(scalar.wasm_module) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "metamorphic unused empty-function transform preserves validation and binary roundtrip" {
  let generated = match
    gen_valid_module_result_from_seed(
      0x103bUL,
      GenValidConfig::natural_default(),
    ) {
    Ok(v) => v
    Err(e) =>
      fail("expected valid GenValid seed, got \{e.validation_error_message}")
  }
  let original_rec_type_count = match generated.wasm_module.type_sec {
    Some(@lib.TypeSec(types)) => types.length()
    None => 0
  }
  let original_flat_type_count = match generated.wasm_module.type_sec {
    Some(@lib.TypeSec(types)) => metamorphic_wbtest_flat_type_count(types)
    None => 0
  }
  let original_func_count = match generated.wasm_module.func_sec {
    Some(@lib.FuncSec(type_idxs)) => type_idxs.length()
    None => 0
  }
  let original_code_count = match generated.wasm_module.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs.length()
    None => 0
  }
  let transformed = match
    metamorphic_apply_transform(generated.wasm_module, AddUnusedEmptyFunction) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  @debug.assert_eq(transformed.transform_id, "add-unused-empty-function")
  match transformed.wasm_module.type_sec {
    Some(@lib.TypeSec(types)) => {
      @debug.assert_eq(types.length(), original_rec_type_count + 1)
      match types[types.length() - 1] {
        @lib.SingleRecType(
          @lib.CompTypeSubType(_, @lib.FuncCompType(params, results))
        ) => {
          @debug.assert_eq(params, [])
          @debug.assert_eq(results, [])
        }
        _ => fail("expected trailing [] -> [] function type")
      }
    }
    None => fail("expected transformed type section")
  }
  match transformed.wasm_module.func_sec {
    Some(@lib.FuncSec(type_idxs)) => {
      @debug.assert_eq(type_idxs.length(), original_func_count + 1)
      @debug.assert_eq(
        type_idxs[type_idxs.length() - 1],
        @lib.TypeIdx::new(original_flat_type_count.reinterpret_as_uint()),
      )
    }
    None => fail("expected transformed function section")
  }
  match transformed.wasm_module.code_sec {
    Some(@lib.CodeSec(funcs)) => {
      @debug.assert_eq(funcs.length(), original_code_count + 1)
      @debug.assert_eq(
        funcs[funcs.length() - 1],
        @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new([])),
      )
    }
    None => fail("expected transformed code section")
  }
  match assert_metamorphic_roundtrip_valid(transformed.wasm_module) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "metamorphic unused immutable-global transform preserves validation and binary roundtrip" {
  let generated = match
    gen_valid_module_result_from_seed(
      0x103aUL,
      GenValidConfig::natural_default(),
    ) {
    Ok(v) => v
    Err(e) =>
      fail("expected valid GenValid seed, got \{e.validation_error_message}")
  }
  let original_global_count = match generated.wasm_module.global_sec {
    Some(@lib.GlobalSec(globals)) => globals.length()
    None => 0
  }
  let transformed = match
    metamorphic_apply_transform(
      generated.wasm_module,
      AddUnusedImmutableI32Global,
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  @debug.assert_eq(transformed.transform_id, "add-unused-immutable-i32-global")
  match transformed.wasm_module.global_sec {
    Some(@lib.GlobalSec(globals)) => {
      @debug.assert_eq(globals.length(), original_global_count + 1)
      match globals[globals.length() - 1] {
        @lib.Global(global_type, init) => {
          @debug.assert_eq(
            global_type,
            @lib.GlobalType::new(@lib.ValType::i32(), false),
          )
          @debug.assert_eq(
            init,
            @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32(0))]),
          )
        }
      }
    }
    None => fail("expected transformed global section")
  }
  match assert_metamorphic_roundtrip_valid(transformed.wasm_module) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "metamorphic passive-data reshape transform appends varied unused passive segments" {
  let generated = match
    gen_valid_module_result_from_seed(
      0x1039UL,
      GenValidConfig::natural_default(),
    ) {
    Ok(v) => v
    Err(e) =>
      fail("expected valid GenValid seed, got \{e.validation_error_message}")
  }
  let original_data_count = match generated.wasm_module.data_sec {
    Some(@lib.DataSec(datas)) => datas.length()
    None => 0
  }
  let transformed = match
    metamorphic_apply_transform(
      generated.wasm_module,
      AddPassiveDataSegmentShapeStress,
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  @debug.assert_eq(
    transformed.transform_id,
    "add-passive-data-segment-shape-stress",
  )
  match transformed.wasm_module.data_sec {
    Some(@lib.DataSec(datas)) => {
      @debug.assert_eq(datas.length(), original_data_count + 3)
      match datas[original_data_count] {
        @lib.Data(@lib.Passive, payload) => @debug.assert_eq(payload, b"")
        _ => fail("expected first appended passive data segment")
      }
      match datas[original_data_count + 1] {
        @lib.Data(@lib.Passive, payload) =>
          @debug.assert_eq(payload, b"\x00\xffsplit-shape")
        _ => fail("expected second appended passive data segment")
      }
      match datas[original_data_count + 2] {
        @lib.Data(@lib.Passive, payload) =>
          @debug.assert_eq(payload, b"starshine metamorphic passive tail")
        _ => fail("expected third appended passive data segment")
      }
    }
    None => fail("expected transformed data section")
  }
  match transformed.wasm_module.data_cnt_sec {
    Some(@lib.DataCntSec(@lib.U32(count))) =>
      @debug.assert_eq(count, (original_data_count + 3).reinterpret_as_uint())
    None => fail("expected transformed data-count section")
  }
  match assert_metamorphic_roundtrip_valid(transformed.wasm_module) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "metamorphic unused passive-data transform preserves validation and binary roundtrip" {
  let generated = match
    gen_valid_module_result_from_seed(
      0x1039UL,
      GenValidConfig::natural_default(),
    ) {
    Ok(v) => v
    Err(e) =>
      fail("expected valid GenValid seed, got \{e.validation_error_message}")
  }
  let original_data_count = match generated.wasm_module.data_sec {
    Some(@lib.DataSec(datas)) => datas.length()
    None => 0
  }
  let transformed = match
    metamorphic_apply_transform(
      generated.wasm_module,
      AddUnusedPassiveDataSegment,
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  @debug.assert_eq(transformed.transform_id, "add-unused-passive-data-segment")
  match transformed.wasm_module.data_sec {
    Some(@lib.DataSec(datas)) => {
      @debug.assert_eq(datas.length(), original_data_count + 1)
      match datas[datas.length() - 1] {
        @lib.Data(@lib.Passive, payload) =>
          @debug.assert_eq(payload, b"starshine metamorphic passive data")
        _ => fail("expected trailing passive data segment")
      }
    }
    None => fail("expected transformed data section")
  }
  match transformed.wasm_module.data_cnt_sec {
    Some(@lib.DataCntSec(@lib.U32(count))) =>
      @debug.assert_eq(count, (original_data_count + 1).reinterpret_as_uint())
    None => fail("expected transformed data-count section")
  }
  match assert_metamorphic_roundtrip_valid(transformed.wasm_module) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "metamorphic module-name transform preserves validation and binary roundtrip" {
  let generated = match
    gen_valid_module_result_from_seed(
      0x1037UL,
      GenValidConfig::natural_default(),
    ) {
    Ok(v) => v
    Err(e) =>
      fail("expected valid GenValid seed, got \{e.validation_error_message}")
  }
  let transformed = match
    metamorphic_apply_transform(generated.wasm_module, AddModuleNameSection) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  @debug.assert_eq(transformed.transform_id, "add-module-name-section")
  match transformed.wasm_module.name_sec {
    Some(name_sec) =>
      match name_sec.module_name {
        Some(name) =>
          @debug.assert_eq(
            name,
            @lib.Name::from_string("starshine.metamorphic.module"),
          )
        None => fail("expected transformed module name")
      }
    None => fail("expected transformed name section")
  }
  match assert_metamorphic_roundtrip_valid(transformed.wasm_module) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "metamorphic local declaration split transform preserves validation and binary roundtrip" {
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [])),
  )
  let base = @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([func_type]))
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::single(3U, @lib.ValType::i32()),
          @lib.Expr::new([]),
        ),
      ]),
    )
  let transformed = match
    metamorphic_apply_transform(base, SplitMergeLocalDeclarations) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  @debug.assert_eq(transformed.transform_id, "split-merge-local-declarations")
  match transformed.wasm_module.code_sec {
    Some(@lib.CodeSec(funcs)) =>
      match funcs[0] {
        @lib.Func(locals, _) => {
          @debug.assert_eq(locals.length(), 3)
          @debug.assert_eq(locals.run_count(), 2)
          let runs = locals.runs()
          @debug.assert_eq(runs[0], @lib.LocalRun::new(1U, @lib.ValType::i32()))
          @debug.assert_eq(runs[1], @lib.LocalRun::new(2U, @lib.ValType::i32()))
        }
      }
    None => fail("expected transformed code section")
  }
  match assert_metamorphic_roundtrip_valid(transformed.wasm_module) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "metamorphic unused i32 local transform preserves validation and binary roundtrip" {
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [])),
  )
  let base = @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([func_type]))
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::single(1U, @lib.ValType::i64()),
          @lib.Expr::new([]),
        ),
      ]),
    )
  let transformed = match
    metamorphic_apply_transform(base, AddUnusedI32LocalToDefinedFunctions) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  @debug.assert_eq(
    transformed.transform_id,
    "add-unused-i32-local-to-defined-functions",
  )
  match transformed.wasm_module.code_sec {
    Some(@lib.CodeSec(funcs)) =>
      match funcs[0] {
        @lib.Func(locals, _) => {
          @debug.assert_eq(locals.length(), 2)
          @debug.assert_eq(locals[0], @lib.ValType::i64())
          @debug.assert_eq(locals[1], @lib.ValType::i32())
        }
      }
    None => fail("expected transformed code section")
  }
  match assert_metamorphic_roundtrip_valid(transformed.wasm_module) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "metamorphic leading nop transform preserves validation and binary roundtrip" {
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [])),
  )
  let base = @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([func_type]))
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([@lib.Instruction::nop()]),
        ),
      ]),
    )
  let transformed = match
    metamorphic_apply_transform(base, AddLeadingNopToDefinedFunctions) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  @debug.assert_eq(
    transformed.transform_id,
    "add-leading-nop-to-defined-functions",
  )
  match transformed.wasm_module.code_sec {
    Some(@lib.CodeSec(funcs)) =>
      match funcs[0] {
        @lib.Func(_, @lib.Expr(instrs)) => {
          @debug.assert_eq(instrs.length(), 2)
          @debug.assert_eq(instrs[0], @lib.Instruction::nop())
          @debug.assert_eq(instrs[1], @lib.Instruction::nop())
        }
      }
    None => fail("expected transformed code section")
  }
  match assert_metamorphic_roundtrip_valid(transformed.wasm_module) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "metamorphic trailing nop transform preserves validation and binary roundtrip" {
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [])),
  )
  let base = @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([func_type]))
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([@lib.Instruction::nop()]),
        ),
      ]),
    )
  let transformed = match
    metamorphic_apply_transform(base, AddTrailingNopToDefinedFunctions) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  @debug.assert_eq(
    transformed.transform_id,
    "add-trailing-nop-to-defined-functions",
  )
  match transformed.wasm_module.code_sec {
    Some(@lib.CodeSec(funcs)) =>
      match funcs[0] {
        @lib.Func(_, @lib.Expr(instrs)) => {
          @debug.assert_eq(instrs.length(), 2)
          @debug.assert_eq(instrs[0], @lib.Instruction::nop())
          @debug.assert_eq(instrs[1], @lib.Instruction::nop())
        }
      }
    None => fail("expected transformed code section")
  }
  match assert_metamorphic_roundtrip_valid(transformed.wasm_module) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "metamorphic leading i32 const drop transform preserves validation and binary roundtrip" {
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [])),
  )
  let base = @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([func_type]))
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([@lib.Instruction::nop()]),
        ),
      ]),
    )
  let transformed = match
    metamorphic_apply_transform(base, AddLeadingI32ConstDropToDefinedFunctions) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  @debug.assert_eq(
    transformed.transform_id,
    "add-leading-i32-const-drop-to-defined-functions",
  )
  match transformed.wasm_module.code_sec {
    Some(@lib.CodeSec(funcs)) =>
      match funcs[0] {
        @lib.Func(_, @lib.Expr(instrs)) => {
          @debug.assert_eq(instrs.length(), 3)
          @debug.assert_eq(instrs[0], @lib.Instruction::i32_const(0))
          @debug.assert_eq(instrs[1], @lib.Instruction::drop())
          @debug.assert_eq(instrs[2], @lib.Instruction::nop())
        }
      }
    None => fail("expected transformed code section")
  }
  match assert_metamorphic_roundtrip_valid(transformed.wasm_module) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "metamorphic trailing i32 const drop transform preserves validation and binary roundtrip" {
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [@lib.ValType::i32()])),
  )
  let base = @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([func_type]))
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([@lib.Instruction::i32_const(7)]),
        ),
      ]),
    )
  let transformed = match
    metamorphic_apply_transform(base, AddTrailingI32ConstDropToDefinedFunctions) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  @debug.assert_eq(
    transformed.transform_id,
    "add-trailing-i32-const-drop-to-defined-functions",
  )
  match transformed.wasm_module.code_sec {
    Some(@lib.CodeSec(funcs)) =>
      match funcs[0] {
        @lib.Func(_, @lib.Expr(instrs)) => {
          @debug.assert_eq(instrs.length(), 3)
          @debug.assert_eq(instrs[0], @lib.Instruction::i32_const(7))
          @debug.assert_eq(instrs[1], @lib.Instruction::i32_const(0))
          @debug.assert_eq(instrs[2], @lib.Instruction::drop())
        }
      }
    None => fail("expected transformed code section")
  }
  match assert_metamorphic_roundtrip_valid(transformed.wasm_module) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "metamorphic leading memory.size drop transform requires memory and roundtrips" {
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [])),
  )
  let base = @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([func_type]))
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_mem_sec(
      @lib.MemSec::new([@lib.MemType::new(@lib.Limits::i32(1U, None))]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([@lib.Instruction::nop()]),
        ),
      ]),
    )
  let transformed = match
    metamorphic_apply_transform(
      base,
      AddLeadingMemorySizeDropToDefinedFunctions,
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  @debug.assert_eq(
    transformed.transform_id,
    "add-leading-memory-size-drop-to-defined-functions",
  )
  match transformed.wasm_module.code_sec {
    Some(@lib.CodeSec(funcs)) =>
      match funcs[0] {
        @lib.Func(_, @lib.Expr(instrs)) => {
          @debug.assert_eq(instrs.length(), 3)
          @debug.assert_eq(
            instrs[0],
            @lib.Instruction::memory_size(@lib.MemIdx::new(0U)),
          )
          @debug.assert_eq(instrs[1], @lib.Instruction::drop())
          @debug.assert_eq(instrs[2], @lib.Instruction::nop())
        }
      }
    None => fail("expected transformed code section")
  }
  match assert_metamorphic_roundtrip_valid(transformed.wasm_module) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "metamorphic trailing memory.size drop transform skips modules without memories" {
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [])),
  )
  let base = @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([func_type]))
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([@lib.Instruction::nop()]),
        ),
      ]),
    )
  match
    metamorphic_apply_transform(
      base,
      AddTrailingMemorySizeDropToDefinedFunctions,
    ) {
    Ok(_) =>
      fail("expected memory.size transform without memory to be rejected")
    Err(msg) =>
      @debug.assert_eq(
        msg, "metamorphic transform add-trailing-memory-size-drop-to-defined-functions requires at least one valid memory index",
      )
  }
}

///|
test "metamorphic leading table.size drop transform requires table and roundtrips" {
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [])),
  )
  let base = @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([func_type]))
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_table_sec(
      @lib.TableSec::new([
        @lib.Table::new(
          @lib.TableType::new(
            @lib.RefType::abs(@lib.AbsHeapType::func()),
            @lib.Limits::i32(0U, None),
          ),
          None,
        ),
      ]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([@lib.Instruction::nop()]),
        ),
      ]),
    )
  let transformed = match
    metamorphic_apply_transform(base, AddLeadingTableSizeDropToDefinedFunctions) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  @debug.assert_eq(
    transformed.transform_id,
    "add-leading-table-size-drop-to-defined-functions",
  )
  match transformed.wasm_module.code_sec {
    Some(@lib.CodeSec(funcs)) =>
      match funcs[0] {
        @lib.Func(_, @lib.Expr(instrs)) => {
          @debug.assert_eq(instrs.length(), 3)
          @debug.assert_eq(
            instrs[0],
            @lib.Instruction::table_size(@lib.TableIdx::new(0U)),
          )
          @debug.assert_eq(instrs[1], @lib.Instruction::drop())
          @debug.assert_eq(instrs[2], @lib.Instruction::nop())
        }
      }
    None => fail("expected transformed code section")
  }
  match assert_metamorphic_roundtrip_valid(transformed.wasm_module) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "metamorphic trailing table.size drop transform skips modules without tables" {
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [])),
  )
  let base = @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([func_type]))
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([@lib.Instruction::nop()]),
        ),
      ]),
    )
  match
    metamorphic_apply_transform(
      base,
      AddTrailingTableSizeDropToDefinedFunctions,
    ) {
    Ok(_) => fail("expected table.size transform without table to be rejected")
    Err(msg) =>
      @debug.assert_eq(
        msg, "metamorphic transform add-trailing-table-size-drop-to-defined-functions requires at least one valid table index",
      )
  }
}

///|
test "metamorphic nested identity block transform wraps value body to fixed depth and roundtrips" {
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [@lib.ValType::i32()])),
  )
  let base = @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([func_type]))
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([@lib.Instruction::i32_const(7)]),
        ),
      ]),
    )
  let transformed = match
    metamorphic_apply_transform(
      base,
      WrapDefinedFunctionBodiesInNestedIdentityBlocks,
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  @debug.assert_eq(
    transformed.transform_id,
    "wrap-defined-function-bodies-in-nested-identity-blocks",
  )
  match transformed.wasm_module.code_sec {
    Some(@lib.CodeSec(funcs)) =>
      match funcs[0] {
        @lib.Func(_, @lib.Expr(instrs)) => {
          @debug.assert_eq(instrs.length(), 1)
          @debug.assert_eq(
            instrs[0],
            @lib.Instruction::block(
              @lib.BlockType::val_type(@lib.ValType::i32()),
              @lib.Expr::new([
                @lib.Instruction::block(
                  @lib.BlockType::val_type(@lib.ValType::i32()),
                  @lib.Expr::new([
                    @lib.Instruction::block(
                      @lib.BlockType::val_type(@lib.ValType::i32()),
                      @lib.Expr::new([@lib.Instruction::i32_const(7)]),
                    ),
                  ]),
                ),
              ]),
            ),
          )
        }
      }
    None => fail("expected transformed code section")
  }
  match assert_metamorphic_roundtrip_valid(transformed.wasm_module) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "metamorphic identity block expression transform wraps value body and roundtrips" {
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [@lib.ValType::i32()])),
  )
  let base = @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([func_type]))
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([@lib.Instruction::i32_const(7)]),
        ),
      ]),
    )
  let transformed = match
    metamorphic_apply_transform(base, WrapDefinedFunctionBodiesInIdentityBlock) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  @debug.assert_eq(
    transformed.transform_id,
    "wrap-defined-function-bodies-in-identity-block",
  )
  match transformed.wasm_module.code_sec {
    Some(@lib.CodeSec(funcs)) =>
      match funcs[0] {
        @lib.Func(_, @lib.Expr(instrs)) => {
          @debug.assert_eq(instrs.length(), 1)
          @debug.assert_eq(
            instrs[0],
            @lib.Instruction::block(
              @lib.BlockType::val_type(@lib.ValType::i32()),
              @lib.Expr::new([@lib.Instruction::i32_const(7)]),
            ),
          )
        }
      }
    None => fail("expected transformed code section")
  }
  match assert_metamorphic_roundtrip_valid(transformed.wasm_module) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "metamorphic block-wrapped i32 const drop transforms preserve stack and roundtrip" {
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [@lib.ValType::i32()])),
  )
  let base = @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([func_type]))
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([@lib.Instruction::i32_const(7)]),
        ),
      ]),
    )
  let transformed = match
    metamorphic_apply_transform(
      base,
      AddLeadingBlockWrappedI32ConstDropToDefinedFunctions,
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  @debug.assert_eq(
    transformed.transform_id,
    "add-leading-block-wrapped-i32-const-drop-to-defined-functions",
  )
  match transformed.wasm_module.code_sec {
    Some(@lib.CodeSec(funcs)) =>
      match funcs[0] {
        @lib.Func(_, @lib.Expr(instrs)) => {
          @debug.assert_eq(instrs.length(), 2)
          @debug.assert_eq(
            instrs[0],
            @lib.Instruction::block(
              @lib.BlockType::void_(),
              @lib.Expr::new([
                @lib.Instruction::i32_const(0),
                @lib.Instruction::drop(),
              ]),
            ),
          )
          @debug.assert_eq(instrs[1], @lib.Instruction::i32_const(7))
        }
      }
    None => fail("expected transformed code section")
  }
  match assert_metamorphic_roundtrip_valid(transformed.wasm_module) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "metamorphic loop-wrapped i32 const drop transforms preserve stack and roundtrip" {
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [@lib.ValType::i32()])),
  )
  let base = @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([func_type]))
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([@lib.Instruction::i32_const(7)]),
        ),
      ]),
    )
  let transformed = match
    metamorphic_apply_transform(
      base,
      AddLeadingLoopWrappedI32ConstDropToDefinedFunctions,
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  @debug.assert_eq(
    transformed.transform_id,
    "add-leading-loop-wrapped-i32-const-drop-to-defined-functions",
  )
  match transformed.wasm_module.code_sec {
    Some(@lib.CodeSec(funcs)) =>
      match funcs[0] {
        @lib.Func(_, @lib.Expr(instrs)) => {
          @debug.assert_eq(instrs.length(), 2)
          @debug.assert_eq(
            instrs[0],
            @lib.Instruction::loop_(
              @lib.BlockType::void_(),
              @lib.Expr::new([
                @lib.Instruction::i32_const(0),
                @lib.Instruction::drop(),
              ]),
            ),
          )
          @debug.assert_eq(instrs[1], @lib.Instruction::i32_const(7))
        }
      }
    None => fail("expected transformed code section")
  }
  match assert_metamorphic_roundtrip_valid(transformed.wasm_module) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "metamorphic trailing empty void block transform preserves validation and binary roundtrip" {
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [@lib.ValType::i32()])),
  )
  let base = @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([func_type]))
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([@lib.Instruction::i32_const(7)]),
        ),
      ]),
    )
  let transformed = match
    metamorphic_apply_transform(
      base,
      AddTrailingEmptyVoidBlockToDefinedFunctions,
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  @debug.assert_eq(
    transformed.transform_id,
    "add-trailing-empty-void-block-to-defined-functions",
  )
  match transformed.wasm_module.code_sec {
    Some(@lib.CodeSec(funcs)) =>
      match funcs[0] {
        @lib.Func(_, @lib.Expr(instrs)) => {
          @debug.assert_eq(instrs.length(), 2)
          @debug.assert_eq(instrs[0], @lib.Instruction::i32_const(7))
          @debug.assert_eq(
            instrs[1],
            @lib.Instruction::block(@lib.BlockType::void_(), @lib.Expr::new([])),
          )
        }
      }
    None => fail("expected transformed code section")
  }
  match assert_metamorphic_roundtrip_valid(transformed.wasm_module) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "metamorphic leading empty void block transform preserves validation and binary roundtrip" {
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [@lib.ValType::i32()])),
  )
  let base = @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([func_type]))
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([@lib.Instruction::i32_const(7)]),
        ),
      ]),
    )
  let transformed = match
    metamorphic_apply_transform(
      base,
      AddLeadingEmptyVoidBlockToDefinedFunctions,
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  @debug.assert_eq(
    transformed.transform_id,
    "add-leading-empty-void-block-to-defined-functions",
  )
  match transformed.wasm_module.code_sec {
    Some(@lib.CodeSec(funcs)) =>
      match funcs[0] {
        @lib.Func(_, @lib.Expr(instrs)) => {
          @debug.assert_eq(instrs.length(), 2)
          @debug.assert_eq(
            instrs[0],
            @lib.Instruction::block(@lib.BlockType::void_(), @lib.Expr::new([])),
          )
          @debug.assert_eq(instrs[1], @lib.Instruction::i32_const(7))
        }
      }
    None => fail("expected transformed code section")
  }
  match assert_metamorphic_roundtrip_valid(transformed.wasm_module) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "metamorphic leading empty void loop transform preserves validation and binary roundtrip" {
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [@lib.ValType::i32()])),
  )
  let base = @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([func_type]))
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([@lib.Instruction::i32_const(7)]),
        ),
      ]),
    )
  let transformed = match
    metamorphic_apply_transform(base, AddLeadingEmptyVoidLoopToDefinedFunctions) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  @debug.assert_eq(
    transformed.transform_id,
    "add-leading-empty-void-loop-to-defined-functions",
  )
  match transformed.wasm_module.code_sec {
    Some(@lib.CodeSec(funcs)) =>
      match funcs[0] {
        @lib.Func(_, @lib.Expr(instrs)) => {
          @debug.assert_eq(instrs.length(), 2)
          @debug.assert_eq(
            instrs[0],
            @lib.Instruction::loop_(@lib.BlockType::void_(), @lib.Expr::new([])),
          )
          @debug.assert_eq(instrs[1], @lib.Instruction::i32_const(7))
        }
      }
    None => fail("expected transformed code section")
  }
  match assert_metamorphic_roundtrip_valid(transformed.wasm_module) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "metamorphic reverse custom sections transform preserves validation and binary roundtrip" {
  let base = @lib.Module::new().with_custom_secs([
    @lib.CustomSec::new(@lib.Name::from_string("alpha"), b"a"),
    @lib.CustomSec::new(@lib.Name::from_string("beta"), b"b"),
  ])
  let transformed = match
    metamorphic_apply_transform(base, ReverseCustomSections) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  @debug.assert_eq(transformed.transform_id, "reverse-custom-sections")
  match transformed.wasm_module.custom_secs {
    [@lib.CustomSec(name0, payload0), @lib.CustomSec(name1, payload1)] => {
      @debug.assert_eq(name0, @lib.Name::from_string("beta"))
      @debug.assert_eq(payload0, b"b")
      @debug.assert_eq(name1, @lib.Name::from_string("alpha"))
      @debug.assert_eq(payload1, b"a")
    }
    _ => fail("expected reversed custom sections")
  }
  match assert_metamorphic_roundtrip_valid(transformed.wasm_module) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "metamorphic prefixed export aliases transform preserves existing entries and unique names" {
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [])),
  )
  let base = @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([func_type]))
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new([])),
      ]),
    )
    .with_export_sec(
      @lib.ExportSec::new([
        @lib.Export::new(
          @lib.Name::from_string("run"),
          @lib.ExternIdx::func(@lib.FuncIdx::new(0U)),
        ),
        @lib.Export::new(
          @lib.Name::from_string("metamorphic_prefixed_alias_run"),
          @lib.ExternIdx::func(@lib.FuncIdx::new(0U)),
        ),
      ]),
    )
  let transformed = match
    metamorphic_apply_transform(base, AddPrefixedExportAliases) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  @debug.assert_eq(transformed.transform_id, "add-prefixed-export-aliases")
  match transformed.wasm_module.export_sec {
    Some(@lib.ExportSec(exports)) => {
      @debug.assert_eq(exports.length(), 4)
      match exports[0] {
        @lib.Export(name, _) =>
          @debug.assert_eq(name, @lib.Name::from_string("run"))
      }
      match exports[1] {
        @lib.Export(name, _) =>
          @debug.assert_eq(
            name,
            @lib.Name::from_string("metamorphic_prefixed_alias_run"),
          )
      }
      @debug.assert_eq(
        exports[2],
        @lib.Export::new(
          @lib.Name::from_string("metamorphic_prefixed_alias_run_1"),
          @lib.ExternIdx::func(@lib.FuncIdx::new(0U)),
        ),
      )
      @debug.assert_eq(
        exports[3],
        @lib.Export::new(
          @lib.Name::from_string(
            "metamorphic_prefixed_alias_metamorphic_prefixed_alias_run",
          ),
          @lib.ExternIdx::func(@lib.FuncIdx::new(0U)),
        ),
      )
    }
    None => fail("expected transformed export section")
  }
  match assert_metamorphic_roundtrip_valid(transformed.wasm_module) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "metamorphic suffixed export aliases transform preserves validation and unique names" {
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [])),
  )
  let base = @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([func_type]))
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new([])),
      ]),
    )
    .with_export_sec(
      @lib.ExportSec::new([
        @lib.Export::new(
          @lib.Name::from_string("run"),
          @lib.ExternIdx::func(@lib.FuncIdx::new(0U)),
        ),
      ]),
    )
  let transformed = match
    metamorphic_apply_transform(base, AddSuffixedExportAliases) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  @debug.assert_eq(transformed.transform_id, "add-suffixed-export-aliases")
  match transformed.wasm_module.export_sec {
    Some(@lib.ExportSec(exports)) => {
      @debug.assert_eq(exports.length(), 2)
      match exports[0] {
        @lib.Export(name, _) =>
          @debug.assert_eq(name, @lib.Name::from_string("run"))
      }
      @debug.assert_eq(
        exports[1],
        @lib.Export::new(
          @lib.Name::from_string("run_metamorphic_alias"),
          @lib.ExternIdx::func(@lib.FuncIdx::new(0U)),
        ),
      )
    }
    None => fail("expected transformed export section")
  }
  match assert_metamorphic_roundtrip_valid(transformed.wasm_module) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "metamorphic kind-specific export alias transforms preserve unique names" {
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [])),
  )
  let base = @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([func_type]))
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_table_sec(
      @lib.TableSec::new([
        @lib.Table::new(
          @lib.TableType::new(
            @lib.RefType::abs(@lib.AbsHeapType::func()),
            @lib.Limits::i32(1U, None),
          ),
          None,
        ),
      ]),
    )
    .with_mem_sec(
      @lib.MemSec::new([@lib.MemType::new(@lib.Limits::i32(1U, None))]),
    )
    .with_global_sec(
      @lib.GlobalSec::new([
        @lib.Global::new(
          @lib.GlobalType::new(@lib.ValType::i32(), false),
          @lib.Expr::new([@lib.Instruction::i32_const(7)]),
        ),
      ]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new([])),
      ]),
    )
    .with_export_sec(
      @lib.ExportSec::new([
        @lib.Export::new(
          @lib.Name::from_string("run"),
          @lib.ExternIdx::func(@lib.FuncIdx::new(0U)),
        ),
        @lib.Export::new(
          @lib.Name::from_string("table"),
          @lib.ExternIdx::table(@lib.TableIdx::new(0U)),
        ),
        @lib.Export::new(
          @lib.Name::from_string("mem"),
          @lib.ExternIdx::mem(@lib.MemIdx::new(0U)),
        ),
        @lib.Export::new(
          @lib.Name::from_string("global"),
          @lib.ExternIdx::global(@lib.GlobalIdx::new(0U)),
        ),
        @lib.Export::new(
          @lib.Name::from_string("metamorphic_func_alias_0"),
          @lib.ExternIdx::func(@lib.FuncIdx::new(0U)),
        ),
      ]),
    )
  let transformed = match
    metamorphic_apply_transform(base, AddFunctionExportAliases) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  @debug.assert_eq(transformed.transform_id, "add-function-export-aliases")
  match transformed.wasm_module.export_sec {
    Some(@lib.ExportSec(exports)) => {
      @debug.assert_eq(exports.length(), 7)
      @debug.assert_eq(
        exports[5],
        @lib.Export::new(
          @lib.Name::from_string("metamorphic_func_alias_0_1"),
          @lib.ExternIdx::func(@lib.FuncIdx::new(0U)),
        ),
      )
      @debug.assert_eq(
        exports[6],
        @lib.Export::new(
          @lib.Name::from_string("metamorphic_func_alias_1"),
          @lib.ExternIdx::func(@lib.FuncIdx::new(0U)),
        ),
      )
    }
    None => fail("expected transformed export section")
  }
  let table_transformed = match
    metamorphic_apply_transform(transformed.wasm_module, AddTableExportAliases) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match table_transformed.wasm_module.export_sec {
    Some(@lib.ExportSec(exports)) => {
      @debug.assert_eq(exports.length(), 8)
      @debug.assert_eq(
        exports[7],
        @lib.Export::new(
          @lib.Name::from_string("metamorphic_table_alias_0"),
          @lib.ExternIdx::table(@lib.TableIdx::new(0U)),
        ),
      )
    }
    None => fail("expected transformed export section")
  }
  let mem_transformed = match
    metamorphic_apply_transform(
      table_transformed.wasm_module,
      AddMemoryExportAliases,
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match mem_transformed.wasm_module.export_sec {
    Some(@lib.ExportSec(exports)) => {
      @debug.assert_eq(exports.length(), 9)
      @debug.assert_eq(
        exports[8],
        @lib.Export::new(
          @lib.Name::from_string("metamorphic_memory_alias_0"),
          @lib.ExternIdx::mem(@lib.MemIdx::new(0U)),
        ),
      )
    }
    None => fail("expected transformed export section")
  }
  let global_transformed = match
    metamorphic_apply_transform(
      mem_transformed.wasm_module,
      AddGlobalExportAliases,
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match global_transformed.wasm_module.export_sec {
    Some(@lib.ExportSec(exports)) => {
      @debug.assert_eq(exports.length(), 10)
      @debug.assert_eq(
        exports[9],
        @lib.Export::new(
          @lib.Name::from_string("metamorphic_global_alias_0"),
          @lib.ExternIdx::global(@lib.GlobalIdx::new(0U)),
        ),
      )
    }
    None => fail("expected transformed export section")
  }
  match assert_metamorphic_roundtrip_valid(global_transformed.wasm_module) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "metamorphic imported and defined function export aliases do not shift indices" {
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [])),
  )
  let base = @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([func_type]))
    .with_import_sec(
      @lib.ImportSec::new([
        @lib.Import::new(
          @lib.Name::new("env"),
          @lib.Name::new("imported"),
          @lib.ExternType::func(@lib.TypeIdx::new(0U)),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new([])),
      ]),
    )
    .with_export_sec(
      @lib.ExportSec::new([
        @lib.Export::new(
          @lib.Name::from_string("imp"),
          @lib.ExternIdx::func(@lib.FuncIdx::new(0U)),
        ),
        @lib.Export::new(
          @lib.Name::from_string("def"),
          @lib.ExternIdx::func(@lib.FuncIdx::new(1U)),
        ),
      ]),
    )
  let imported = match
    metamorphic_apply_transform(base, AddImportedFunctionExportAliases) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  @debug.assert_eq(
    imported.transform_id,
    "add-imported-function-export-aliases",
  )
  match imported.wasm_module.export_sec {
    Some(@lib.ExportSec(exports)) => {
      @debug.assert_eq(exports.length(), 3)
      @debug.assert_eq(
        exports[2],
        @lib.Export::new(
          @lib.Name::from_string("metamorphic_imported_func_alias_0"),
          @lib.ExternIdx::func(@lib.FuncIdx::new(0U)),
        ),
      )
    }
    None => fail("expected imported alias export section")
  }
  let defined = match
    metamorphic_apply_transform(
      imported.wasm_module,
      AddDefinedFunctionExportAliases,
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  @debug.assert_eq(defined.transform_id, "add-defined-function-export-aliases")
  match defined.wasm_module.export_sec {
    Some(@lib.ExportSec(exports)) => {
      @debug.assert_eq(exports.length(), 4)
      @debug.assert_eq(
        exports[3],
        @lib.Export::new(
          @lib.Name::from_string("metamorphic_defined_func_alias_0"),
          @lib.ExternIdx::func(@lib.FuncIdx::new(1U)),
        ),
      )
    }
    None => fail("expected defined alias export section")
  }
  match assert_metamorphic_roundtrip_valid(defined.wasm_module) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "metamorphic export aliases transform preserves validation and binary roundtrip" {
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [])),
  )
  let base = @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([func_type]))
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new([])),
      ]),
    )
    .with_export_sec(
      @lib.ExportSec::new([
        @lib.Export::new(
          @lib.Name::from_string("run"),
          @lib.ExternIdx::func(@lib.FuncIdx::new(0U)),
        ),
      ]),
    )
  let transformed = match metamorphic_apply_transform(base, AddExportAliases) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  @debug.assert_eq(transformed.transform_id, "add-export-aliases")
  match transformed.wasm_module.export_sec {
    Some(@lib.ExportSec(exports)) => {
      @debug.assert_eq(exports.length(), 2)
      @debug.assert_eq(
        exports[1],
        @lib.Export::new(
          @lib.Name::from_string("metamorphic_alias_0"),
          @lib.ExternIdx::func(@lib.FuncIdx::new(0U)),
        ),
      )
    }
    None => fail("expected transformed export section")
  }
  match assert_metamorphic_roundtrip_valid(transformed.wasm_module) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "metamorphic trailing empty void loop transform preserves validation and binary roundtrip" {
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [@lib.ValType::i32()])),
  )
  let base = @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([func_type]))
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([@lib.Instruction::i32_const(7)]),
        ),
      ]),
    )
  let transformed = match
    metamorphic_apply_transform(
      base,
      AddTrailingEmptyVoidLoopToDefinedFunctions,
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  @debug.assert_eq(
    transformed.transform_id,
    "add-trailing-empty-void-loop-to-defined-functions",
  )
  match transformed.wasm_module.code_sec {
    Some(@lib.CodeSec(funcs)) =>
      match funcs[0] {
        @lib.Func(_, @lib.Expr(instrs)) => {
          @debug.assert_eq(instrs.length(), 2)
          @debug.assert_eq(instrs[0], @lib.Instruction::i32_const(7))
          @debug.assert_eq(
            instrs[1],
            @lib.Instruction::loop_(@lib.BlockType::void_(), @lib.Expr::new([])),
          )
        }
      }
    None => fail("expected transformed code section")
  }
  match assert_metamorphic_roundtrip_valid(transformed.wasm_module) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "metamorphic unused numeric locals transform preserves validation and binary roundtrip" {
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [])),
  )
  let base = @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([func_type]))
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([@lib.ValType::i32()]),
          @lib.Expr::new([]),
        ),
      ]),
    )
  let transformed = match
    metamorphic_apply_transform(base, AddUnusedNumericLocalsToDefinedFunctions) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  @debug.assert_eq(
    transformed.transform_id,
    "add-unused-numeric-locals-to-defined-functions",
  )
  match transformed.wasm_module.code_sec {
    Some(@lib.CodeSec(funcs)) =>
      match funcs[0] {
        @lib.Func(locals, @lib.Expr(instrs)) => {
          @debug.assert_eq(
            locals,
            @lib.Locals::from_types([
              @lib.ValType::i32(),
              @lib.ValType::i64(),
              @lib.ValType::f32(),
              @lib.ValType::f64(),
            ]),
          )
          @debug.assert_eq(instrs.length(), 0)
        }
      }
    None => fail("expected transformed code section")
  }
  match assert_metamorphic_roundtrip_valid(transformed.wasm_module) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "metamorphic unused reference locals transform preserves validation and binary roundtrip" {
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [])),
  )
  let base = @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([func_type]))
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([@lib.ValType::i32()]),
          @lib.Expr::new([]),
        ),
      ]),
    )
  let transformed = match
    metamorphic_apply_transform(
      base,
      AddUnusedReferenceLocalsToDefinedFunctions,
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  @debug.assert_eq(
    transformed.transform_id,
    "add-unused-reference-locals-to-defined-functions",
  )
  match transformed.wasm_module.code_sec {
    Some(@lib.CodeSec(funcs)) =>
      match funcs[0] {
        @lib.Func(locals, @lib.Expr(instrs)) => {
          @debug.assert_eq(
            locals,
            @lib.Locals::from_types([
              @lib.ValType::i32(),
              @lib.ValType::funcref(),
              @lib.ValType::externref(),
            ]),
          )
          @debug.assert_eq(instrs.length(), 0)
        }
      }
    None => fail("expected transformed code section")
  }
  match assert_metamorphic_roundtrip_valid(transformed.wasm_module) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "metamorphic unused GC reference locals transform preserves validation and binary roundtrip" {
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [])),
  )
  let base = @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([func_type]))
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([@lib.ValType::i32()]),
          @lib.Expr::new([]),
        ),
      ]),
    )
  let transformed = match
    metamorphic_apply_transform(
      base,
      AddUnusedGcReferenceLocalsToDefinedFunctions,
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  @debug.assert_eq(
    transformed.transform_id,
    "add-unused-gc-reference-locals-to-defined-functions",
  )
  match transformed.wasm_module.code_sec {
    Some(@lib.CodeSec(funcs)) =>
      match funcs[0] {
        @lib.Func(locals, @lib.Expr(instrs)) => {
          @debug.assert_eq(
            locals,
            @lib.Locals::from_types([
              @lib.ValType::i32(),
              @lib.ValType::anyref(),
              @lib.ValType::i31ref_nullable(),
              @lib.ValType::stringref(),
            ]),
          )
          @debug.assert_eq(instrs.length(), 0)
        }
      }
    None => fail("expected transformed code section")
  }
  match assert_metamorphic_roundtrip_valid(transformed.wasm_module) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "metamorphic leading ref i31 get_s drop transform preserves validation and binary roundtrip" {
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [@lib.ValType::i32()])),
  )
  let base = @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([func_type]))
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::new([]),
          @lib.Expr::new([@lib.Instruction::i32_const(7)]),
        ),
      ]),
    )
  let transformed = match
    metamorphic_apply_transform(
      base,
      AddLeadingRefI31GetSDropToDefinedFunctions,
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  @debug.assert_eq(
    transformed.transform_id,
    "add-leading-ref-i31-get-s-drop-to-defined-functions",
  )
  match transformed.wasm_module.code_sec {
    Some(@lib.CodeSec(funcs)) =>
      match funcs[0] {
        @lib.Func(locals, @lib.Expr(instrs)) => {
          @debug.assert_eq(locals, @lib.Locals::new([]))
          @debug.assert_eq(instrs.length(), 5)
          @debug.assert_eq(instrs[0], @lib.Instruction::i32_const(31))
          @debug.assert_eq(instrs[1], @lib.Instruction::ref_i31())
          @debug.assert_eq(instrs[2], @lib.Instruction::i31_get_s())
          @debug.assert_eq(instrs[3], @lib.Instruction::drop())
          @debug.assert_eq(instrs[4], @lib.Instruction::i32_const(7))
        }
      }
    None => fail("expected transformed code section")
  }
  match assert_metamorphic_roundtrip_valid(transformed.wasm_module) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "metamorphic leading ref.eq over i31 drop transform preserves validation and binary roundtrip" {
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [@lib.ValType::i32()])),
  )
  let base = @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([func_type]))
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::new([]),
          @lib.Expr::new([@lib.Instruction::i32_const(7)]),
        ),
      ]),
    )
  let transformed = match
    metamorphic_apply_transform(base, AddLeadingRefEqI31DropToDefinedFunctions) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  @debug.assert_eq(
    transformed.transform_id,
    "add-leading-ref-eq-i31-drop-to-defined-functions",
  )
  match transformed.wasm_module.code_sec {
    Some(@lib.CodeSec(funcs)) =>
      match funcs[0] {
        @lib.Func(_, @lib.Expr(instrs)) => {
          @debug.assert_eq(instrs.length(), 7)
          @debug.assert_eq(instrs[0], @lib.Instruction::i32_const(31))
          @debug.assert_eq(instrs[1], @lib.Instruction::ref_i31())
          @debug.assert_eq(instrs[2], @lib.Instruction::i32_const(32))
          @debug.assert_eq(instrs[3], @lib.Instruction::ref_i31())
          @debug.assert_eq(instrs[4], @lib.Instruction::ref_eq())
          @debug.assert_eq(instrs[5], @lib.Instruction::drop())
          @debug.assert_eq(instrs[6], @lib.Instruction::i32_const(7))
        }
      }
    None => fail("expected transformed code section")
  }
  match assert_metamorphic_roundtrip_valid(transformed.wasm_module) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "metamorphic leading ref.eq drop transform preserves validation and binary roundtrip" {
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [@lib.ValType::i32()])),
  )
  let base = @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([func_type]))
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::new([]),
          @lib.Expr::new([@lib.Instruction::i32_const(7)]),
        ),
      ]),
    )
  let transformed = match
    metamorphic_apply_transform(base, AddLeadingRefEqDropToDefinedFunctions) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  @debug.assert_eq(
    transformed.transform_id,
    "add-leading-ref-eq-drop-to-defined-functions",
  )
  match transformed.wasm_module.code_sec {
    Some(@lib.CodeSec(funcs)) =>
      match funcs[0] {
        @lib.Func(_, @lib.Expr(instrs)) => {
          @debug.assert_eq(instrs.length(), 5)
          @debug.assert_eq(
            instrs[0],
            @lib.Instruction::ref_null(
              @lib.HeapType::abs(@lib.AbsHeapType::eq()),
            ),
          )
          @debug.assert_eq(
            instrs[1],
            @lib.Instruction::ref_null(
              @lib.HeapType::abs(@lib.AbsHeapType::eq()),
            ),
          )
          @debug.assert_eq(instrs[2], @lib.Instruction::ref_eq())
          @debug.assert_eq(instrs[3], @lib.Instruction::drop())
          @debug.assert_eq(instrs[4], @lib.Instruction::i32_const(7))
        }
      }
    None => fail("expected transformed code section")
  }
  match assert_metamorphic_roundtrip_valid(transformed.wasm_module) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "metamorphic leading any.convert_extern drop transform preserves validation and binary roundtrip" {
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [@lib.ValType::i32()])),
  )
  let base = @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([func_type]))
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::new([]),
          @lib.Expr::new([@lib.Instruction::i32_const(7)]),
        ),
      ]),
    )
  let transformed = match
    metamorphic_apply_transform(
      base,
      AddLeadingAnyConvertExternDropToDefinedFunctions,
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  @debug.assert_eq(
    transformed.transform_id,
    "add-leading-any-convert-extern-drop-to-defined-functions",
  )
  match transformed.wasm_module.code_sec {
    Some(@lib.CodeSec(funcs)) =>
      match funcs[0] {
        @lib.Func(locals, @lib.Expr(instrs)) => {
          @debug.assert_eq(locals, @lib.Locals::new([]))
          @debug.assert_eq(instrs.length(), 4)
          @debug.assert_eq(
            instrs[0],
            @lib.Instruction::ref_null(
              @lib.HeapType::abs(@lib.AbsHeapType::extern_()),
            ),
          )
          @debug.assert_eq(instrs[1], @lib.Instruction::any_convert_extern())
          @debug.assert_eq(instrs[2], @lib.Instruction::drop())
          @debug.assert_eq(instrs[3], @lib.Instruction::i32_const(7))
        }
      }
    None => fail("expected transformed code section")
  }
  match assert_metamorphic_roundtrip_valid(transformed.wasm_module) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "metamorphic trailing extern.convert_any drop transform preserves validation and binary roundtrip" {
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [@lib.ValType::i32()])),
  )
  let base = @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([func_type]))
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::new([]),
          @lib.Expr::new([@lib.Instruction::i32_const(7)]),
        ),
      ]),
    )
  let transformed = match
    metamorphic_apply_transform(
      base,
      AddTrailingExternConvertAnyDropToDefinedFunctions,
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  @debug.assert_eq(
    transformed.transform_id,
    "add-trailing-extern-convert-any-drop-to-defined-functions",
  )
  match transformed.wasm_module.code_sec {
    Some(@lib.CodeSec(funcs)) =>
      match funcs[0] {
        @lib.Func(locals, @lib.Expr(instrs)) => {
          @debug.assert_eq(locals, @lib.Locals::new([]))
          @debug.assert_eq(instrs.length(), 4)
          @debug.assert_eq(instrs[0], @lib.Instruction::i32_const(7))
          @debug.assert_eq(
            instrs[1],
            @lib.Instruction::ref_null(
              @lib.HeapType::abs(@lib.AbsHeapType::any()),
            ),
          )
          @debug.assert_eq(instrs[2], @lib.Instruction::extern_convert_any())
          @debug.assert_eq(instrs[3], @lib.Instruction::drop())
        }
      }
    None => fail("expected transformed code section")
  }
  match assert_metamorphic_roundtrip_valid(transformed.wasm_module) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "metamorphic leading nullable ref.test null-success drop transform preserves validation and binary roundtrip" {
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [@lib.ValType::i32()])),
  )
  let base = @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([func_type]))
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::new([]),
          @lib.Expr::new([@lib.Instruction::i32_const(7)]),
        ),
      ]),
    )
  let transformed = match
    metamorphic_apply_transform(
      base,
      AddLeadingNullableRefTestDropToDefinedFunctions,
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  @debug.assert_eq(
    transformed.transform_id,
    "add-leading-nullable-ref-test-drop-to-defined-functions",
  )
  match transformed.wasm_module.code_sec {
    Some(@lib.CodeSec(funcs)) =>
      match funcs[0] {
        @lib.Func(_, @lib.Expr(instrs)) => {
          @debug.assert_eq(instrs.length(), 4)
          @debug.assert_eq(
            instrs[0],
            @lib.Instruction::ref_null(
              @lib.HeapType::abs(@lib.AbsHeapType::eq()),
            ),
          )
          @debug.assert_eq(
            instrs[1],
            @lib.Instruction::ref_test(
              true,
              @lib.HeapType::abs(@lib.AbsHeapType::eq()),
            ),
          )
          @debug.assert_eq(instrs[2], @lib.Instruction::drop())
          @debug.assert_eq(instrs[3], @lib.Instruction::i32_const(7))
        }
      }
    None => fail("expected transformed code section")
  }
  match assert_metamorphic_roundtrip_valid(transformed.wasm_module) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "metamorphic trailing nullable ref.cast null-success drop transform preserves validation and binary roundtrip" {
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [@lib.ValType::i32()])),
  )
  let base = @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([func_type]))
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::new([]),
          @lib.Expr::new([@lib.Instruction::i32_const(7)]),
        ),
      ]),
    )
  let transformed = match
    metamorphic_apply_transform(
      base,
      AddTrailingNullableRefCastDropToDefinedFunctions,
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  @debug.assert_eq(
    transformed.transform_id,
    "add-trailing-nullable-ref-cast-drop-to-defined-functions",
  )
  match transformed.wasm_module.code_sec {
    Some(@lib.CodeSec(funcs)) =>
      match funcs[0] {
        @lib.Func(_, @lib.Expr(instrs)) => {
          @debug.assert_eq(instrs.length(), 4)
          @debug.assert_eq(instrs[0], @lib.Instruction::i32_const(7))
          @debug.assert_eq(
            instrs[1],
            @lib.Instruction::ref_null(
              @lib.HeapType::abs(@lib.AbsHeapType::eq()),
            ),
          )
          @debug.assert_eq(
            instrs[2],
            @lib.Instruction::ref_cast(
              true,
              @lib.HeapType::abs(@lib.AbsHeapType::eq()),
            ),
          )
          @debug.assert_eq(instrs[3], @lib.Instruction::drop())
        }
      }
    None => fail("expected transformed code section")
  }
  match assert_metamorphic_roundtrip_valid(transformed.wasm_module) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "metamorphic leading ref null is-null drop transform preserves validation and binary roundtrip" {
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [@lib.ValType::i32()])),
  )
  let base = @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([func_type]))
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::new([]),
          @lib.Expr::new([@lib.Instruction::i32_const(7)]),
        ),
      ]),
    )
  let transformed = match
    metamorphic_apply_transform(
      base,
      AddLeadingRefNullIsNullDropToDefinedFunctions,
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  @debug.assert_eq(
    transformed.transform_id,
    "add-leading-ref-null-is-null-drop-to-defined-functions",
  )
  match transformed.wasm_module.code_sec {
    Some(@lib.CodeSec(funcs)) =>
      match funcs[0] {
        @lib.Func(locals, @lib.Expr(instrs)) => {
          @debug.assert_eq(locals, @lib.Locals::new([]))
          @debug.assert_eq(instrs.length(), 4)
          @debug.assert_eq(
            instrs[0],
            @lib.Instruction::ref_null(
              @lib.HeapType::abs(@lib.AbsHeapType::extern_()),
            ),
          )
          @debug.assert_eq(instrs[1], @lib.Instruction::ref_is_null())
          @debug.assert_eq(instrs[2], @lib.Instruction::drop())
          @debug.assert_eq(instrs[3], @lib.Instruction::i32_const(7))
        }
      }
    None => fail("expected transformed code section")
  }
  match assert_metamorphic_roundtrip_valid(transformed.wasm_module) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "metamorphic leading ref null drop transform preserves validation and binary roundtrip" {
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [@lib.ValType::i32()])),
  )
  let base = @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([func_type]))
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::new([]),
          @lib.Expr::new([@lib.Instruction::i32_const(7)]),
        ),
      ]),
    )
  let transformed = match
    metamorphic_apply_transform(base, AddLeadingRefNullDropToDefinedFunctions) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  @debug.assert_eq(
    transformed.transform_id,
    "add-leading-ref-null-drop-to-defined-functions",
  )
  match transformed.wasm_module.code_sec {
    Some(@lib.CodeSec(funcs)) =>
      match funcs[0] {
        @lib.Func(locals, @lib.Expr(instrs)) => {
          @debug.assert_eq(locals, @lib.Locals::new([]))
          @debug.assert_eq(instrs.length(), 3)
          @debug.assert_eq(
            instrs[0],
            @lib.Instruction::ref_null(
              @lib.HeapType::abs(@lib.AbsHeapType::extern_()),
            ),
          )
          @debug.assert_eq(instrs[1], @lib.Instruction::drop())
          @debug.assert_eq(instrs[2], @lib.Instruction::i32_const(7))
        }
      }
    None => fail("expected transformed code section")
  }
  match assert_metamorphic_roundtrip_valid(transformed.wasm_module) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "metamorphic leading v128 const drop transform preserves validation and binary roundtrip" {
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [@lib.ValType::i32()])),
  )
  let base = @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([func_type]))
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::new([]),
          @lib.Expr::new([@lib.Instruction::i32_const(7)]),
        ),
      ]),
    )
  let transformed = match
    metamorphic_apply_transform(base, AddLeadingV128ConstDropToDefinedFunctions) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  @debug.assert_eq(
    transformed.transform_id,
    "add-leading-v128-const-drop-to-defined-functions",
  )
  match transformed.wasm_module.code_sec {
    Some(@lib.CodeSec(funcs)) =>
      match funcs[0] {
        @lib.Func(locals, @lib.Expr(instrs)) => {
          @debug.assert_eq(locals, @lib.Locals::new([]))
          @debug.assert_eq(instrs.length(), 3)
          @debug.assert_eq(
            instrs[0],
            @lib.Instruction::v128_const(
              b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00',
              b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00',
            ),
          )
          @debug.assert_eq(instrs[1], @lib.Instruction::drop())
          @debug.assert_eq(instrs[2], @lib.Instruction::i32_const(7))
        }
      }
    None => fail("expected transformed code section")
  }
  match assert_metamorphic_roundtrip_valid(transformed.wasm_module) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "metamorphic trailing v128 const drop transform preserves validation and binary roundtrip" {
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [@lib.ValType::i32()])),
  )
  let base = @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([func_type]))
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::new([]),
          @lib.Expr::new([@lib.Instruction::i32_const(7)]),
        ),
      ]),
    )
  let transformed = match
    metamorphic_apply_transform(
      base,
      AddTrailingV128ConstDropToDefinedFunctions,
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  @debug.assert_eq(
    transformed.transform_id,
    "add-trailing-v128-const-drop-to-defined-functions",
  )
  match transformed.wasm_module.code_sec {
    Some(@lib.CodeSec(funcs)) =>
      match funcs[0] {
        @lib.Func(_, @lib.Expr(instrs)) => {
          @debug.assert_eq(instrs.length(), 3)
          @debug.assert_eq(instrs[0], @lib.Instruction::i32_const(7))
          @debug.assert_eq(
            instrs[1],
            @lib.Instruction::v128_const(
              b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00',
              b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00',
            ),
          )
          @debug.assert_eq(instrs[2], @lib.Instruction::drop())
        }
      }
    None => fail("expected transformed code section")
  }
  match assert_metamorphic_roundtrip_valid(transformed.wasm_module) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "metamorphic SIMD unary computed-drop transforms preserve validation and binary roundtrip" {
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [@lib.ValType::i32()])),
  )
  let base = @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([func_type]))
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::new([]),
          @lib.Expr::new([@lib.Instruction::i32_const(7)]),
        ),
      ]),
    )
  let cases : Array[(MetamorphicValidTransform, String, @lib.Instruction)] = [
    (
      AddLeadingV128NotDropToDefinedFunctions,
      "add-leading-v128-not-drop-to-defined-functions",
      @lib.Instruction::v128_not(),
    ),
    (
      AddTrailingV128NotDropToDefinedFunctions,
      "add-trailing-v128-not-drop-to-defined-functions",
      @lib.Instruction::v128_not(),
    ),
    (
      AddLeadingI8x16AllTrueDropToDefinedFunctions,
      "add-leading-i8x16-all-true-drop-to-defined-functions",
      @lib.Instruction::i8x16_all_true(),
    ),
    (
      AddTrailingI16x8BitmaskDropToDefinedFunctions,
      "add-trailing-i16x8-bitmask-drop-to-defined-functions",
      @lib.Instruction::i16x8_bitmask(),
    ),
    (
      AddLeadingI32x4BitmaskDropToDefinedFunctions,
      "add-leading-i32x4-bitmask-drop-to-defined-functions",
      @lib.Instruction::i32x4_bitmask(),
    ),
    (
      AddTrailingI64x2AllTrueDropToDefinedFunctions,
      "add-trailing-i64x2-all-true-drop-to-defined-functions",
      @lib.Instruction::i64x2_all_true(),
    ),
  ]
  for case in cases {
    let (transform, expected_id, expected_op) = case
    let transformed = match metamorphic_apply_transform(base, transform) {
      Ok(v) => v
      Err(msg) => fail(msg)
    }
    @debug.assert_eq(transformed.transform_id, expected_id)
    match transformed.wasm_module.code_sec {
      Some(@lib.CodeSec(funcs)) =>
        match funcs[0] {
          @lib.Func(_, @lib.Expr(instrs)) => {
            @debug.assert_eq(instrs.length(), 4)
            if expected_id.contains("leading") {
              @debug.assert_eq(instrs[0], metamorphic_v128_zero_const())
              @debug.assert_eq(instrs[1], expected_op)
              @debug.assert_eq(instrs[2], @lib.Instruction::drop())
              @debug.assert_eq(instrs[3], @lib.Instruction::i32_const(7))
            } else {
              @debug.assert_eq(instrs[0], @lib.Instruction::i32_const(7))
              @debug.assert_eq(instrs[1], metamorphic_v128_zero_const())
              @debug.assert_eq(instrs[2], expected_op)
              @debug.assert_eq(instrs[3], @lib.Instruction::drop())
            }
          }
        }
      None => fail("expected transformed code section")
    }
    match assert_metamorphic_roundtrip_valid(transformed.wasm_module) {
      Ok(_) => ()
      Err(msg) => fail(msg)
    }
  }
}

///|
test "metamorphic SIMD splat computed-drop transforms use scalar constants and preserve validation" {
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [@lib.ValType::i32()])),
  )
  let base = @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([func_type]))
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::new([]),
          @lib.Expr::new([@lib.Instruction::i32_const(7)]),
        ),
      ]),
    )
  let cases : Array[
    (MetamorphicValidTransform, String, @lib.Instruction, @lib.Instruction),
  ] = [
    (
      AddLeadingI8x16SplatDropToDefinedFunctions,
      "add-leading-i8x16-splat-drop-to-defined-functions",
      @lib.Instruction::i32_const(1),
      @lib.Instruction::i8x16_splat(),
    ),
    (
      AddTrailingI16x8SplatDropToDefinedFunctions,
      "add-trailing-i16x8-splat-drop-to-defined-functions",
      @lib.Instruction::i32_const(2),
      @lib.Instruction::i16x8_splat(),
    ),
    (
      AddLeadingI32x4SplatDropToDefinedFunctions,
      "add-leading-i32x4-splat-drop-to-defined-functions",
      @lib.Instruction::i32_const(3),
      @lib.Instruction::i32x4_splat(),
    ),
    (
      AddTrailingI64x2SplatDropToDefinedFunctions,
      "add-trailing-i64x2-splat-drop-to-defined-functions",
      @lib.Instruction::i64_const(4L),
      @lib.Instruction::i64x2_splat(),
    ),
    (
      AddLeadingF32x4SplatDropToDefinedFunctions,
      "add-leading-f32x4-splat-drop-to-defined-functions",
      @lib.Instruction::f32_const(5.0),
      @lib.Instruction::f32x4_splat(),
    ),
    (
      AddTrailingF64x2SplatDropToDefinedFunctions,
      "add-trailing-f64x2-splat-drop-to-defined-functions",
      @lib.Instruction::f64_const(6.0),
      @lib.Instruction::f64x2_splat(),
    ),
  ]
  for case in cases {
    let (transform, expected_id, scalar_const, expected_op) = case
    let transformed = match metamorphic_apply_transform(base, transform) {
      Ok(v) => v
      Err(msg) => fail(msg)
    }
    @debug.assert_eq(transformed.transform_id, expected_id)
    match transformed.wasm_module.code_sec {
      Some(@lib.CodeSec(funcs)) =>
        match funcs[0] {
          @lib.Func(_, @lib.Expr(instrs)) => {
            @debug.assert_eq(instrs.length(), 4)
            if expected_id.contains("leading") {
              @debug.assert_eq(instrs[0], scalar_const)
              @debug.assert_eq(instrs[1], expected_op)
              @debug.assert_eq(instrs[2], @lib.Instruction::drop())
              @debug.assert_eq(instrs[3], @lib.Instruction::i32_const(7))
            } else {
              @debug.assert_eq(instrs[0], @lib.Instruction::i32_const(7))
              @debug.assert_eq(instrs[1], scalar_const)
              @debug.assert_eq(instrs[2], expected_op)
              @debug.assert_eq(instrs[3], @lib.Instruction::drop())
            }
          }
        }
      None => fail("expected transformed code section")
    }
    match assert_metamorphic_roundtrip_valid(transformed.wasm_module) {
      Ok(_) => ()
      Err(msg) => fail(msg)
    }
  }
}

///|
test "metamorphic SIMD lane extract computed-drop transforms use legal lane immediates" {
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [@lib.ValType::i32()])),
  )
  let base = @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([func_type]))
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::new([]),
          @lib.Expr::new([@lib.Instruction::i32_const(7)]),
        ),
      ]),
    )
  let cases : Array[(MetamorphicValidTransform, String, @lib.Instruction)] = [
    (
      AddLeadingI8x16ExtractLaneSDropToDefinedFunctions,
      "add-leading-i8x16-extract-lane-s-drop-to-defined-functions",
      @lib.Instruction::i8x16_extract_lane_s(@lib.LaneIdx::new(15)),
    ),
    (
      AddTrailingI8x16ExtractLaneUDropToDefinedFunctions,
      "add-trailing-i8x16-extract-lane-u-drop-to-defined-functions",
      @lib.Instruction::i8x16_extract_lane_u(@lib.LaneIdx::new(14)),
    ),
    (
      AddLeadingI16x8ExtractLaneSDropToDefinedFunctions,
      "add-leading-i16x8-extract-lane-s-drop-to-defined-functions",
      @lib.Instruction::i16x8_extract_lane_s(@lib.LaneIdx::new(7)),
    ),
    (
      AddTrailingI16x8ExtractLaneUDropToDefinedFunctions,
      "add-trailing-i16x8-extract-lane-u-drop-to-defined-functions",
      @lib.Instruction::i16x8_extract_lane_u(@lib.LaneIdx::new(6)),
    ),
    (
      AddLeadingI32x4ExtractLaneDropToDefinedFunctions,
      "add-leading-i32x4-extract-lane-drop-to-defined-functions",
      @lib.Instruction::i32x4_extract_lane(@lib.LaneIdx::new(3)),
    ),
    (
      AddTrailingI64x2ExtractLaneDropToDefinedFunctions,
      "add-trailing-i64x2-extract-lane-drop-to-defined-functions",
      @lib.Instruction::i64x2_extract_lane(@lib.LaneIdx::new(1)),
    ),
    (
      AddLeadingF32x4ExtractLaneDropToDefinedFunctions,
      "add-leading-f32x4-extract-lane-drop-to-defined-functions",
      @lib.Instruction::f32x4_extract_lane(@lib.LaneIdx::new(3)),
    ),
    (
      AddTrailingF64x2ExtractLaneDropToDefinedFunctions,
      "add-trailing-f64x2-extract-lane-drop-to-defined-functions",
      @lib.Instruction::f64x2_extract_lane(@lib.LaneIdx::new(1)),
    ),
  ]
  for case in cases {
    let (transform, expected_id, expected_op) = case
    let transformed = match metamorphic_apply_transform(base, transform) {
      Ok(v) => v
      Err(msg) => fail(msg)
    }
    @debug.assert_eq(transformed.transform_id, expected_id)
    match transformed.wasm_module.code_sec {
      Some(@lib.CodeSec(funcs)) =>
        match funcs[0] {
          @lib.Func(_, @lib.Expr(instrs)) => {
            @debug.assert_eq(instrs.length(), 4)
            if expected_id.contains("leading") {
              @debug.assert_eq(instrs[0], metamorphic_v128_zero_const())
              @debug.assert_eq(instrs[1], expected_op)
              @debug.assert_eq(instrs[2], @lib.Instruction::drop())
              @debug.assert_eq(instrs[3], @lib.Instruction::i32_const(7))
            } else {
              @debug.assert_eq(instrs[0], @lib.Instruction::i32_const(7))
              @debug.assert_eq(instrs[1], metamorphic_v128_zero_const())
              @debug.assert_eq(instrs[2], expected_op)
              @debug.assert_eq(instrs[3], @lib.Instruction::drop())
            }
          }
        }
      None => fail("expected transformed code section")
    }
    match assert_metamorphic_roundtrip_valid(transformed.wasm_module) {
      Ok(_) => ()
      Err(msg) => fail(msg)
    }
  }
}

///|
test "metamorphic SIMD lane replace computed-drop transforms use legal lane immediates" {
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [@lib.ValType::i32()])),
  )
  let base = @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([func_type]))
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::new([]),
          @lib.Expr::new([@lib.Instruction::i32_const(7)]),
        ),
      ]),
    )
  let cases : Array[
    (MetamorphicValidTransform, String, @lib.Instruction, @lib.Instruction),
  ] = [
    (
      AddLeadingI8x16ReplaceLaneDropToDefinedFunctions,
      "add-leading-i8x16-replace-lane-drop-to-defined-functions",
      @lib.Instruction::i32_const(11),
      @lib.Instruction::i8x16_replace_lane(@lib.LaneIdx::new(15)),
    ),
    (
      AddTrailingI16x8ReplaceLaneDropToDefinedFunctions,
      "add-trailing-i16x8-replace-lane-drop-to-defined-functions",
      @lib.Instruction::i32_const(22),
      @lib.Instruction::i16x8_replace_lane(@lib.LaneIdx::new(6)),
    ),
    (
      AddLeadingI32x4ReplaceLaneDropToDefinedFunctions,
      "add-leading-i32x4-replace-lane-drop-to-defined-functions",
      @lib.Instruction::i32_const(33),
      @lib.Instruction::i32x4_replace_lane(@lib.LaneIdx::new(3)),
    ),
    (
      AddTrailingI64x2ReplaceLaneDropToDefinedFunctions,
      "add-trailing-i64x2-replace-lane-drop-to-defined-functions",
      @lib.Instruction::i64_const(44L),
      @lib.Instruction::i64x2_replace_lane(@lib.LaneIdx::new(0)),
    ),
    (
      AddLeadingF32x4ReplaceLaneDropToDefinedFunctions,
      "add-leading-f32x4-replace-lane-drop-to-defined-functions",
      @lib.Instruction::f32_const(1.5F),
      @lib.Instruction::f32x4_replace_lane(@lib.LaneIdx::new(3)),
    ),
    (
      AddTrailingF64x2ReplaceLaneDropToDefinedFunctions,
      "add-trailing-f64x2-replace-lane-drop-to-defined-functions",
      @lib.Instruction::f64_const(2.5),
      @lib.Instruction::f64x2_replace_lane(@lib.LaneIdx::new(0)),
    ),
  ]
  for case in cases {
    let (transform, expected_id, expected_scalar, expected_op) = case
    let transformed = match metamorphic_apply_transform(base, transform) {
      Ok(v) => v
      Err(msg) => fail(msg)
    }
    @debug.assert_eq(transformed.transform_id, expected_id)
    match transformed.wasm_module.code_sec {
      Some(@lib.CodeSec(funcs)) =>
        match funcs[0] {
          @lib.Func(_, @lib.Expr(instrs)) => {
            @debug.assert_eq(instrs.length(), 5)
            if expected_id.contains("leading") {
              @debug.assert_eq(instrs[0], metamorphic_v128_zero_const())
              @debug.assert_eq(instrs[1], expected_scalar)
              @debug.assert_eq(instrs[2], expected_op)
              @debug.assert_eq(instrs[3], @lib.Instruction::drop())
              @debug.assert_eq(instrs[4], @lib.Instruction::i32_const(7))
            } else {
              @debug.assert_eq(instrs[0], @lib.Instruction::i32_const(7))
              @debug.assert_eq(instrs[1], metamorphic_v128_zero_const())
              @debug.assert_eq(instrs[2], expected_scalar)
              @debug.assert_eq(instrs[3], expected_op)
              @debug.assert_eq(instrs[4], @lib.Instruction::drop())
            }
          }
        }
      None => fail("expected transformed code section")
    }
    match assert_metamorphic_roundtrip_valid(transformed.wasm_module) {
      Ok(_) => ()
      Err(msg) => fail(msg)
    }
  }
}

///|
test "metamorphic SIMD shift computed-drop transforms use constant vectors and legal counts" {
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [@lib.ValType::i32()])),
  )
  let base = @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([func_type]))
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::new([]),
          @lib.Expr::new([@lib.Instruction::i32_const(7)]),
        ),
      ]),
    )
  let cases : Array[(MetamorphicValidTransform, String, @lib.Instruction)] = [
    (
      AddLeadingI8x16ShlDropToDefinedFunctions,
      "add-leading-i8x16-shl-drop-to-defined-functions",
      @lib.Instruction::i8x16_shl(),
    ),
    (
      AddTrailingI16x8ShrSDropToDefinedFunctions,
      "add-trailing-i16x8-shr-s-drop-to-defined-functions",
      @lib.Instruction::i16x8_shr_s(),
    ),
    (
      AddLeadingI32x4ShrUDropToDefinedFunctions,
      "add-leading-i32x4-shr-u-drop-to-defined-functions",
      @lib.Instruction::i32x4_shr_u(),
    ),
    (
      AddTrailingI64x2ShlDropToDefinedFunctions,
      "add-trailing-i64x2-shl-drop-to-defined-functions",
      @lib.Instruction::i64x2_shl(),
    ),
  ]
  for case in cases {
    let (transform, expected_id, expected_op) = case
    let transformed = match metamorphic_apply_transform(base, transform) {
      Ok(v) => v
      Err(msg) => fail(msg)
    }
    @debug.assert_eq(transformed.transform_id, expected_id)
    match transformed.wasm_module.code_sec {
      Some(@lib.CodeSec(funcs)) =>
        match funcs[0] {
          @lib.Func(_, @lib.Expr(instrs)) => {
            @debug.assert_eq(instrs.length(), 5)
            if expected_id.contains("leading") {
              @debug.assert_eq(instrs[0], metamorphic_v128_zero_const())
              @debug.assert_eq(instrs[1], @lib.Instruction::i32_const(3))
              @debug.assert_eq(instrs[2], expected_op)
              @debug.assert_eq(instrs[3], @lib.Instruction::drop())
              @debug.assert_eq(instrs[4], @lib.Instruction::i32_const(7))
            } else {
              @debug.assert_eq(instrs[0], @lib.Instruction::i32_const(7))
              @debug.assert_eq(instrs[1], metamorphic_v128_zero_const())
              @debug.assert_eq(instrs[2], @lib.Instruction::i32_const(3))
              @debug.assert_eq(instrs[3], expected_op)
              @debug.assert_eq(instrs[4], @lib.Instruction::drop())
            }
          }
        }
      None => fail("expected transformed code section")
    }
    match assert_metamorphic_roundtrip_valid(transformed.wasm_module) {
      Ok(_) => ()
      Err(msg) => fail(msg)
    }
  }
}

///|
test "metamorphic SIMD bitwise binary computed-drop transforms preserve validation and binary roundtrip" {
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [@lib.ValType::i32()])),
  )
  let base = @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([func_type]))
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::new([]),
          @lib.Expr::new([@lib.Instruction::i32_const(7)]),
        ),
      ]),
    )
  let cases : Array[(MetamorphicValidTransform, String, @lib.Instruction, Int)] = [
    (
      AddLeadingV128AndDropToDefinedFunctions,
      "add-leading-v128-and-drop-to-defined-functions",
      @lib.Instruction::v128_and(),
      5,
    ),
    (
      AddTrailingV128AndnotDropToDefinedFunctions,
      "add-trailing-v128-andnot-drop-to-defined-functions",
      @lib.Instruction::v128_andnot(),
      5,
    ),
    (
      AddLeadingV128OrDropToDefinedFunctions,
      "add-leading-v128-or-drop-to-defined-functions",
      @lib.Instruction::v128_or(),
      5,
    ),
    (
      AddTrailingV128XorDropToDefinedFunctions,
      "add-trailing-v128-xor-drop-to-defined-functions",
      @lib.Instruction::v128_xor(),
      5,
    ),
    (
      AddLeadingV128BitselectDropToDefinedFunctions,
      "add-leading-v128-bitselect-drop-to-defined-functions",
      @lib.Instruction::v128_bitselect(),
      6,
    ),
    (
      AddTrailingV128BitselectDropToDefinedFunctions,
      "add-trailing-v128-bitselect-drop-to-defined-functions",
      @lib.Instruction::v128_bitselect(),
      6,
    ),
  ]
  for case in cases {
    let (transform, expected_id, expected_op, expected_len) = case
    let transformed = match metamorphic_apply_transform(base, transform) {
      Ok(v) => v
      Err(msg) => fail(msg)
    }
    @debug.assert_eq(transformed.transform_id, expected_id)
    match transformed.wasm_module.code_sec {
      Some(@lib.CodeSec(funcs)) =>
        match funcs[0] {
          @lib.Func(_, @lib.Expr(instrs)) => {
            @debug.assert_eq(instrs.length(), expected_len)
            if expected_id.contains("leading") {
              @debug.assert_eq(instrs[0], metamorphic_v128_zero_const())
              @debug.assert_eq(instrs[1], metamorphic_v128_zero_const())
              let op_index = if expected_len == 5 { 2 } else { 3 }
              if expected_len == 6 {
                @debug.assert_eq(instrs[2], metamorphic_v128_zero_const())
              }
              @debug.assert_eq(instrs[op_index], expected_op)
              @debug.assert_eq(instrs[op_index + 1], @lib.Instruction::drop())
              @debug.assert_eq(
                instrs[expected_len - 1],
                @lib.Instruction::i32_const(7),
              )
            } else {
              @debug.assert_eq(instrs[0], @lib.Instruction::i32_const(7))
              @debug.assert_eq(instrs[1], metamorphic_v128_zero_const())
              @debug.assert_eq(instrs[2], metamorphic_v128_zero_const())
              let op_index = if expected_len == 5 { 3 } else { 4 }
              if expected_len == 6 {
                @debug.assert_eq(instrs[3], metamorphic_v128_zero_const())
              }
              @debug.assert_eq(instrs[op_index], expected_op)
              @debug.assert_eq(instrs[op_index + 1], @lib.Instruction::drop())
            }
          }
        }
      None => fail("expected transformed code section")
    }
    match assert_metamorphic_roundtrip_valid(transformed.wasm_module) {
      Ok(_) => ()
      Err(msg) => fail(msg)
    }
  }
}

///|
test "metamorphic leading i64 const drop transform preserves validation and binary roundtrip" {
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [@lib.ValType::i32()])),
  )
  let base = @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([func_type]))
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::new([]),
          @lib.Expr::new([@lib.Instruction::i32_const(7)]),
        ),
      ]),
    )
  let transformed = match
    metamorphic_apply_transform(base, AddLeadingI64ConstDropToDefinedFunctions) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  @debug.assert_eq(
    transformed.transform_id,
    "add-leading-i64-const-drop-to-defined-functions",
  )
  match transformed.wasm_module.code_sec {
    Some(@lib.CodeSec(funcs)) =>
      match funcs[0] {
        @lib.Func(locals, @lib.Expr(instrs)) => {
          @debug.assert_eq(locals, @lib.Locals::new([]))
          @debug.assert_eq(instrs.length(), 3)
          @debug.assert_eq(instrs[0], @lib.Instruction::i64_const(@lib.I64(0L)))
          @debug.assert_eq(instrs[1], @lib.Instruction::drop())
          @debug.assert_eq(instrs[2], @lib.Instruction::i32_const(7))
        }
      }
    None => fail("expected transformed code section")
  }
  match assert_metamorphic_roundtrip_valid(transformed.wasm_module) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "metamorphic leading f32 const drop transform preserves validation and binary roundtrip" {
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [@lib.ValType::i32()])),
  )
  let base = @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([func_type]))
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::new([]),
          @lib.Expr::new([@lib.Instruction::i32_const(7)]),
        ),
      ]),
    )
  let transformed = match
    metamorphic_apply_transform(base, AddLeadingF32ConstDropToDefinedFunctions) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  @debug.assert_eq(
    transformed.transform_id,
    "add-leading-f32-const-drop-to-defined-functions",
  )
  match transformed.wasm_module.code_sec {
    Some(@lib.CodeSec(funcs)) =>
      match funcs[0] {
        @lib.Func(locals, @lib.Expr(instrs)) => {
          @debug.assert_eq(locals, @lib.Locals::new([]))
          @debug.assert_eq(instrs.length(), 3)
          @debug.assert_eq(
            instrs[0],
            @lib.Instruction::f32_const(@lib.F32(0.0)),
          )
          @debug.assert_eq(instrs[1], @lib.Instruction::drop())
          @debug.assert_eq(instrs[2], @lib.Instruction::i32_const(7))
        }
      }
    None => fail("expected transformed code section")
  }
  match assert_metamorphic_roundtrip_valid(transformed.wasm_module) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "metamorphic trailing f32 const drop transform preserves validation and binary roundtrip" {
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [@lib.ValType::i32()])),
  )
  let base = @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([func_type]))
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::new([]),
          @lib.Expr::new([@lib.Instruction::i32_const(7)]),
        ),
      ]),
    )
  let transformed = match
    metamorphic_apply_transform(base, AddTrailingF32ConstDropToDefinedFunctions) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  @debug.assert_eq(
    transformed.transform_id,
    "add-trailing-f32-const-drop-to-defined-functions",
  )
  match transformed.wasm_module.code_sec {
    Some(@lib.CodeSec(funcs)) =>
      match funcs[0] {
        @lib.Func(locals, @lib.Expr(instrs)) => {
          @debug.assert_eq(locals, @lib.Locals::new([]))
          @debug.assert_eq(instrs.length(), 3)
          @debug.assert_eq(instrs[0], @lib.Instruction::i32_const(7))
          @debug.assert_eq(
            instrs[1],
            @lib.Instruction::f32_const(@lib.F32(0.0)),
          )
          @debug.assert_eq(instrs[2], @lib.Instruction::drop())
        }
      }
    None => fail("expected transformed code section")
  }
  match assert_metamorphic_roundtrip_valid(transformed.wasm_module) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "metamorphic leading false if transform preserves validation and binary roundtrip" {
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [@lib.ValType::i32()])),
  )
  let base = @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([func_type]))
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::new([]),
          @lib.Expr::new([@lib.Instruction::i32_const(7)]),
        ),
      ]),
    )
  let transformed = match
    metamorphic_apply_transform(base, AddLeadingFalseIfToDefinedFunctions) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  @debug.assert_eq(
    transformed.transform_id,
    "add-leading-false-if-to-defined-functions",
  )
  match transformed.wasm_module.code_sec {
    Some(@lib.CodeSec(funcs)) =>
      match funcs[0] {
        @lib.Func(locals, @lib.Expr(instrs)) => {
          @debug.assert_eq(locals, @lib.Locals::new([]))
          @debug.assert_eq(instrs.length(), 3)
          @debug.assert_eq(instrs[0], @lib.Instruction::i32_const(0))
          @debug.assert_eq(
            instrs[1],
            @lib.Instruction::if_(@lib.BlockType::void_(), [], None),
          )
          @debug.assert_eq(instrs[2], @lib.Instruction::i32_const(7))
        }
      }
    None => fail("expected transformed code section")
  }
  match assert_metamorphic_roundtrip_valid(transformed.wasm_module) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "metamorphic leading true if transform preserves validation and binary roundtrip" {
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [@lib.ValType::i32()])),
  )
  let base = @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([func_type]))
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::new([]),
          @lib.Expr::new([@lib.Instruction::i32_const(7)]),
        ),
      ]),
    )
  let transformed = match
    metamorphic_apply_transform(base, AddLeadingTrueIfToDefinedFunctions) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  @debug.assert_eq(
    transformed.transform_id,
    "add-leading-true-if-to-defined-functions",
  )
  match transformed.wasm_module.code_sec {
    Some(@lib.CodeSec(funcs)) =>
      match funcs[0] {
        @lib.Func(locals, @lib.Expr(instrs)) => {
          @debug.assert_eq(locals, @lib.Locals::new([]))
          @debug.assert_eq(instrs.length(), 3)
          @debug.assert_eq(instrs[0], @lib.Instruction::i32_const(1))
          @debug.assert_eq(
            instrs[1],
            @lib.Instruction::if_(@lib.BlockType::void_(), [], None),
          )
          @debug.assert_eq(instrs[2], @lib.Instruction::i32_const(7))
        }
      }
    None => fail("expected transformed code section")
  }
  match assert_metamorphic_roundtrip_valid(transformed.wasm_module) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "metamorphic leading i32 eqz drop transform preserves validation and binary roundtrip" {
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [@lib.ValType::i32()])),
  )
  let base = @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([func_type]))
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::new([]),
          @lib.Expr::new([@lib.Instruction::i32_const(7)]),
        ),
      ]),
    )
  let transformed = match
    metamorphic_apply_transform(base, AddLeadingI32EqzDropToDefinedFunctions) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  @debug.assert_eq(
    transformed.transform_id,
    "add-leading-i32-eqz-drop-to-defined-functions",
  )
  match transformed.wasm_module.code_sec {
    Some(@lib.CodeSec(funcs)) =>
      match funcs[0] {
        @lib.Func(locals, @lib.Expr(instrs)) => {
          @debug.assert_eq(locals, @lib.Locals::new([]))
          @debug.assert_eq(instrs.length(), 4)
          @debug.assert_eq(instrs[0], @lib.Instruction::i32_const(0))
          @debug.assert_eq(instrs[1], @lib.Instruction::i32_eqz())
          @debug.assert_eq(instrs[2], @lib.Instruction::drop())
          @debug.assert_eq(instrs[3], @lib.Instruction::i32_const(7))
        }
      }
    None => fail("expected transformed code section")
  }
  match assert_metamorphic_roundtrip_valid(transformed.wasm_module) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "metamorphic trailing i32 eqz drop transform preserves validation and binary roundtrip" {
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [@lib.ValType::i32()])),
  )
  let base = @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([func_type]))
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::new([]),
          @lib.Expr::new([@lib.Instruction::i32_const(7)]),
        ),
      ]),
    )
  let transformed = match
    metamorphic_apply_transform(base, AddTrailingI32EqzDropToDefinedFunctions) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  @debug.assert_eq(
    transformed.transform_id,
    "add-trailing-i32-eqz-drop-to-defined-functions",
  )
  match transformed.wasm_module.code_sec {
    Some(@lib.CodeSec(funcs)) =>
      match funcs[0] {
        @lib.Func(locals, @lib.Expr(instrs)) => {
          @debug.assert_eq(locals, @lib.Locals::new([]))
          @debug.assert_eq(instrs.length(), 4)
          @debug.assert_eq(instrs[0], @lib.Instruction::i32_const(7))
          @debug.assert_eq(instrs[1], @lib.Instruction::i32_const(0))
          @debug.assert_eq(instrs[2], @lib.Instruction::i32_eqz())
          @debug.assert_eq(instrs[3], @lib.Instruction::drop())
        }
      }
    None => fail("expected transformed code section")
  }
  match assert_metamorphic_roundtrip_valid(transformed.wasm_module) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "metamorphic leading i64 eqz drop transform preserves validation and binary roundtrip" {
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [@lib.ValType::i32()])),
  )
  let base = @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([func_type]))
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::new([]),
          @lib.Expr::new([@lib.Instruction::i32_const(7)]),
        ),
      ]),
    )
  let transformed = match
    metamorphic_apply_transform(base, AddLeadingI64EqzDropToDefinedFunctions) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  @debug.assert_eq(
    transformed.transform_id,
    "add-leading-i64-eqz-drop-to-defined-functions",
  )
  match transformed.wasm_module.code_sec {
    Some(@lib.CodeSec(funcs)) =>
      match funcs[0] {
        @lib.Func(locals, @lib.Expr(instrs)) => {
          @debug.assert_eq(locals, @lib.Locals::new([]))
          @debug.assert_eq(instrs.length(), 4)
          @debug.assert_eq(instrs[0], @lib.Instruction::i64_const(0L))
          @debug.assert_eq(instrs[1], @lib.Instruction::i64_eqz())
          @debug.assert_eq(instrs[2], @lib.Instruction::drop())
          @debug.assert_eq(instrs[3], @lib.Instruction::i32_const(7))
        }
      }
    None => fail("expected transformed code section")
  }
  match assert_metamorphic_roundtrip_valid(transformed.wasm_module) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "metamorphic trailing i64 eqz drop transform preserves validation and binary roundtrip" {
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [@lib.ValType::i32()])),
  )
  let base = @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([func_type]))
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::new([]),
          @lib.Expr::new([@lib.Instruction::i32_const(7)]),
        ),
      ]),
    )
  let transformed = match
    metamorphic_apply_transform(base, AddTrailingI64EqzDropToDefinedFunctions) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  @debug.assert_eq(
    transformed.transform_id,
    "add-trailing-i64-eqz-drop-to-defined-functions",
  )
  match transformed.wasm_module.code_sec {
    Some(@lib.CodeSec(funcs)) =>
      match funcs[0] {
        @lib.Func(locals, @lib.Expr(instrs)) => {
          @debug.assert_eq(locals, @lib.Locals::new([]))
          @debug.assert_eq(instrs.length(), 4)
          @debug.assert_eq(instrs[0], @lib.Instruction::i32_const(7))
          @debug.assert_eq(instrs[1], @lib.Instruction::i64_const(0L))
          @debug.assert_eq(instrs[2], @lib.Instruction::i64_eqz())
          @debug.assert_eq(instrs[3], @lib.Instruction::drop())
        }
      }
    None => fail("expected transformed code section")
  }
  match assert_metamorphic_roundtrip_valid(transformed.wasm_module) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "metamorphic leading f32 abs drop transform preserves validation and binary roundtrip" {
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [@lib.ValType::i32()])),
  )
  let base = @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([func_type]))
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::new([]),
          @lib.Expr::new([@lib.Instruction::i32_const(7)]),
        ),
      ]),
    )
  let transformed = match
    metamorphic_apply_transform(base, AddLeadingF32AbsDropToDefinedFunctions) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  @debug.assert_eq(
    transformed.transform_id,
    "add-leading-f32-abs-drop-to-defined-functions",
  )
  match transformed.wasm_module.code_sec {
    Some(@lib.CodeSec(funcs)) =>
      match funcs[0] {
        @lib.Func(locals, @lib.Expr(instrs)) => {
          @debug.assert_eq(locals, @lib.Locals::new([]))
          @debug.assert_eq(instrs.length(), 4)
          @debug.assert_eq(instrs[0], @lib.Instruction::f32_const(0.0))
          @debug.assert_eq(instrs[1], @lib.Instruction::f32_abs())
          @debug.assert_eq(instrs[2], @lib.Instruction::drop())
          @debug.assert_eq(instrs[3], @lib.Instruction::i32_const(7))
        }
      }
    None => fail("expected transformed code section")
  }
  match assert_metamorphic_roundtrip_valid(transformed.wasm_module) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "metamorphic trailing f32 abs drop transform preserves validation and binary roundtrip" {
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [@lib.ValType::i32()])),
  )
  let base = @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([func_type]))
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::new([]),
          @lib.Expr::new([@lib.Instruction::i32_const(7)]),
        ),
      ]),
    )
  let transformed = match
    metamorphic_apply_transform(base, AddTrailingF32AbsDropToDefinedFunctions) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  @debug.assert_eq(
    transformed.transform_id,
    "add-trailing-f32-abs-drop-to-defined-functions",
  )
  match transformed.wasm_module.code_sec {
    Some(@lib.CodeSec(funcs)) =>
      match funcs[0] {
        @lib.Func(locals, @lib.Expr(instrs)) => {
          @debug.assert_eq(locals, @lib.Locals::new([]))
          @debug.assert_eq(instrs.length(), 4)
          @debug.assert_eq(instrs[0], @lib.Instruction::i32_const(7))
          @debug.assert_eq(instrs[1], @lib.Instruction::f32_const(0.0))
          @debug.assert_eq(instrs[2], @lib.Instruction::f32_abs())
          @debug.assert_eq(instrs[3], @lib.Instruction::drop())
        }
      }
    None => fail("expected transformed code section")
  }
  match assert_metamorphic_roundtrip_valid(transformed.wasm_module) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "metamorphic leading f32 neg drop transform preserves validation and binary roundtrip" {
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [@lib.ValType::i32()])),
  )
  let base = @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([func_type]))
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::new([]),
          @lib.Expr::new([@lib.Instruction::i32_const(7)]),
        ),
      ]),
    )
  let transformed = match
    metamorphic_apply_transform(base, AddLeadingF32NegDropToDefinedFunctions) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  @debug.assert_eq(
    transformed.transform_id,
    "add-leading-f32-neg-drop-to-defined-functions",
  )
  match transformed.wasm_module.code_sec {
    Some(@lib.CodeSec(funcs)) =>
      match funcs[0] {
        @lib.Func(locals, @lib.Expr(instrs)) => {
          @debug.assert_eq(locals, @lib.Locals::new([]))
          @debug.assert_eq(instrs.length(), 4)
          @debug.assert_eq(instrs[0], @lib.Instruction::f32_const(0.0))
          @debug.assert_eq(instrs[1], @lib.Instruction::f32_neg())
          @debug.assert_eq(instrs[2], @lib.Instruction::drop())
          @debug.assert_eq(instrs[3], @lib.Instruction::i32_const(7))
        }
      }
    None => fail("expected transformed code section")
  }
  match assert_metamorphic_roundtrip_valid(transformed.wasm_module) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "metamorphic trailing f32 neg drop transform preserves validation and binary roundtrip" {
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [@lib.ValType::i32()])),
  )
  let base = @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([func_type]))
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::new([]),
          @lib.Expr::new([@lib.Instruction::i32_const(7)]),
        ),
      ]),
    )
  let transformed = match
    metamorphic_apply_transform(base, AddTrailingF32NegDropToDefinedFunctions) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  @debug.assert_eq(
    transformed.transform_id,
    "add-trailing-f32-neg-drop-to-defined-functions",
  )
  match transformed.wasm_module.code_sec {
    Some(@lib.CodeSec(funcs)) =>
      match funcs[0] {
        @lib.Func(locals, @lib.Expr(instrs)) => {
          @debug.assert_eq(locals, @lib.Locals::new([]))
          @debug.assert_eq(instrs.length(), 4)
          @debug.assert_eq(instrs[0], @lib.Instruction::i32_const(7))
          @debug.assert_eq(instrs[1], @lib.Instruction::f32_const(0.0))
          @debug.assert_eq(instrs[2], @lib.Instruction::f32_neg())
          @debug.assert_eq(instrs[3], @lib.Instruction::drop())
        }
      }
    None => fail("expected transformed code section")
  }
  match assert_metamorphic_roundtrip_valid(transformed.wasm_module) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "metamorphic leading f64 neg drop transform preserves validation and binary roundtrip" {
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [@lib.ValType::i32()])),
  )
  let base = @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([func_type]))
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::new([]),
          @lib.Expr::new([@lib.Instruction::i32_const(7)]),
        ),
      ]),
    )
  let transformed = match
    metamorphic_apply_transform(base, AddLeadingF64NegDropToDefinedFunctions) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  @debug.assert_eq(
    transformed.transform_id,
    "add-leading-f64-neg-drop-to-defined-functions",
  )
  match transformed.wasm_module.code_sec {
    Some(@lib.CodeSec(funcs)) =>
      match funcs[0] {
        @lib.Func(locals, @lib.Expr(instrs)) => {
          @debug.assert_eq(locals, @lib.Locals::new([]))
          @debug.assert_eq(instrs.length(), 4)
          @debug.assert_eq(instrs[0], @lib.Instruction::f64_const(0.0))
          @debug.assert_eq(instrs[1], @lib.Instruction::f64_neg())
          @debug.assert_eq(instrs[2], @lib.Instruction::drop())
          @debug.assert_eq(instrs[3], @lib.Instruction::i32_const(7))
        }
      }
    None => fail("expected transformed code section")
  }
  match assert_metamorphic_roundtrip_valid(transformed.wasm_module) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "metamorphic trailing f64 neg drop transform preserves validation and binary roundtrip" {
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [@lib.ValType::i32()])),
  )
  let base = @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([func_type]))
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::new([]),
          @lib.Expr::new([@lib.Instruction::i32_const(7)]),
        ),
      ]),
    )
  let transformed = match
    metamorphic_apply_transform(base, AddTrailingF64NegDropToDefinedFunctions) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  @debug.assert_eq(
    transformed.transform_id,
    "add-trailing-f64-neg-drop-to-defined-functions",
  )
  match transformed.wasm_module.code_sec {
    Some(@lib.CodeSec(funcs)) =>
      match funcs[0] {
        @lib.Func(locals, @lib.Expr(instrs)) => {
          @debug.assert_eq(locals, @lib.Locals::new([]))
          @debug.assert_eq(instrs.length(), 4)
          @debug.assert_eq(instrs[0], @lib.Instruction::i32_const(7))
          @debug.assert_eq(instrs[1], @lib.Instruction::f64_const(0.0))
          @debug.assert_eq(instrs[2], @lib.Instruction::f64_neg())
          @debug.assert_eq(instrs[3], @lib.Instruction::drop())
        }
      }
    None => fail("expected transformed code section")
  }
  match assert_metamorphic_roundtrip_valid(transformed.wasm_module) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
fn assert_metamorphic_unary_drop_transform(
  transform : MetamorphicValidTransform,
  expected_id : String,
  unary : @lib.Instruction,
  leading : Bool,
) -> Result[Unit, String] {
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [@lib.ValType::i32()])),
  )
  let base = @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([func_type]))
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::new([]),
          @lib.Expr::new([@lib.Instruction::i32_const(7)]),
        ),
      ]),
    )
  let transformed = match metamorphic_apply_transform(base, transform) {
    Ok(v) => v
    Err(msg) => return Err(msg)
  }
  if transformed.transform_id != expected_id {
    return Err("unexpected transform id")
  }
  match transformed.wasm_module.code_sec {
    Some(@lib.CodeSec(funcs)) =>
      match funcs[0] {
        @lib.Func(locals, @lib.Expr(instrs)) => {
          if locals != @lib.Locals::new([]) {
            return Err("unexpected locals")
          }
          if instrs.length() != 4 {
            return Err("unexpected instruction count")
          }
          let zero = if expected_id.contains("f64") {
            @lib.Instruction::f64_const(0.0)
          } else {
            @lib.Instruction::f32_const(0.0)
          }
          if leading {
            if instrs[0] != zero ||
              instrs[1] != unary ||
              instrs[2] != @lib.Instruction::drop() ||
              instrs[3] != @lib.Instruction::i32_const(7) {
              return Err("unexpected leading unary/drop body")
            }
          } else if instrs[0] != @lib.Instruction::i32_const(7) ||
            instrs[1] != zero ||
            instrs[2] != unary ||
            instrs[3] != @lib.Instruction::drop() {
            return Err("unexpected trailing unary/drop body")
          }
        }
      }
    None => return Err("expected transformed code section")
  }
  assert_metamorphic_roundtrip_valid(transformed.wasm_module)
}

///|
fn assert_metamorphic_binary_drop_transform(
  transform : MetamorphicValidTransform,
  expected_id : String,
  binary : @lib.Instruction,
  leading : Bool,
) -> Result[Unit, String] {
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [@lib.ValType::i32()])),
  )
  let base = @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([func_type]))
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::new([]),
          @lib.Expr::new([@lib.Instruction::i32_const(7)]),
        ),
      ]),
    )
  let transformed = match metamorphic_apply_transform(base, transform) {
    Ok(v) => v
    Err(msg) => return Err(msg)
  }
  if transformed.transform_id != expected_id {
    return Err("unexpected transform id")
  }
  match transformed.wasm_module.code_sec {
    Some(@lib.CodeSec(funcs)) =>
      match funcs[0] {
        @lib.Func(locals, @lib.Expr(instrs)) => {
          if locals != @lib.Locals::new([]) {
            return Err("unexpected locals")
          }
          if instrs.length() != 5 {
            return Err("unexpected instruction count")
          }
          let zero = if expected_id.contains("f64") {
            @lib.Instruction::f64_const(0.0)
          } else if expected_id.contains("f32") {
            @lib.Instruction::f32_const(0.0)
          } else if expected_id.contains("i64") {
            @lib.Instruction::i64_const(0L)
          } else {
            @lib.Instruction::i32_const(0)
          }
          if leading {
            if instrs[0] != zero ||
              instrs[1] != zero ||
              instrs[2] != binary ||
              instrs[3] != @lib.Instruction::drop() ||
              instrs[4] != @lib.Instruction::i32_const(7) {
              return Err("unexpected leading binary/drop body")
            }
          } else if instrs[0] != @lib.Instruction::i32_const(7) ||
            instrs[1] != zero ||
            instrs[2] != zero ||
            instrs[3] != binary ||
            instrs[4] != @lib.Instruction::drop() {
            return Err("unexpected trailing binary/drop body")
          }
        }
      }
    None => return Err("expected transformed code section")
  }
  assert_metamorphic_roundtrip_valid(transformed.wasm_module)
}

///|
test "metamorphic f32 and f64 sqrt drop transforms preserve validation and binary roundtrip" {
  match
    assert_metamorphic_unary_drop_transform(
      AddLeadingF32SqrtDropToDefinedFunctions,
      "add-leading-f32-sqrt-drop-to-defined-functions",
      @lib.Instruction::f32_sqrt(),
      true,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
  match
    assert_metamorphic_unary_drop_transform(
      AddTrailingF32SqrtDropToDefinedFunctions,
      "add-trailing-f32-sqrt-drop-to-defined-functions",
      @lib.Instruction::f32_sqrt(),
      false,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
  match
    assert_metamorphic_unary_drop_transform(
      AddLeadingF64SqrtDropToDefinedFunctions,
      "add-leading-f64-sqrt-drop-to-defined-functions",
      @lib.Instruction::f64_sqrt(),
      true,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
  match
    assert_metamorphic_unary_drop_transform(
      AddTrailingF64SqrtDropToDefinedFunctions,
      "add-trailing-f64-sqrt-drop-to-defined-functions",
      @lib.Instruction::f64_sqrt(),
      false,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "metamorphic f32 and f64 add/sub/mul/div drop transforms preserve validation and binary roundtrip" {
  match
    assert_metamorphic_binary_drop_transform(
      AddLeadingF32AddDropToDefinedFunctions,
      "add-leading-f32-add-drop-to-defined-functions",
      @lib.Instruction::f32_add(),
      true,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
  match
    assert_metamorphic_binary_drop_transform(
      AddTrailingF32AddDropToDefinedFunctions,
      "add-trailing-f32-add-drop-to-defined-functions",
      @lib.Instruction::f32_add(),
      false,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
  match
    assert_metamorphic_binary_drop_transform(
      AddLeadingF32SubDropToDefinedFunctions,
      "add-leading-f32-sub-drop-to-defined-functions",
      @lib.Instruction::f32_sub(),
      true,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
  match
    assert_metamorphic_binary_drop_transform(
      AddTrailingF32SubDropToDefinedFunctions,
      "add-trailing-f32-sub-drop-to-defined-functions",
      @lib.Instruction::f32_sub(),
      false,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
  match
    assert_metamorphic_binary_drop_transform(
      AddLeadingF64AddDropToDefinedFunctions,
      "add-leading-f64-add-drop-to-defined-functions",
      @lib.Instruction::f64_add(),
      true,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
  match
    assert_metamorphic_binary_drop_transform(
      AddTrailingF64AddDropToDefinedFunctions,
      "add-trailing-f64-add-drop-to-defined-functions",
      @lib.Instruction::f64_add(),
      false,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
  match
    assert_metamorphic_binary_drop_transform(
      AddLeadingF64SubDropToDefinedFunctions,
      "add-leading-f64-sub-drop-to-defined-functions",
      @lib.Instruction::f64_sub(),
      true,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
  match
    assert_metamorphic_binary_drop_transform(
      AddTrailingF64SubDropToDefinedFunctions,
      "add-trailing-f64-sub-drop-to-defined-functions",
      @lib.Instruction::f64_sub(),
      false,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
  match
    assert_metamorphic_binary_drop_transform(
      AddLeadingF32MulDropToDefinedFunctions,
      "add-leading-f32-mul-drop-to-defined-functions",
      @lib.Instruction::f32_mul(),
      true,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
  match
    assert_metamorphic_binary_drop_transform(
      AddTrailingF32MulDropToDefinedFunctions,
      "add-trailing-f32-mul-drop-to-defined-functions",
      @lib.Instruction::f32_mul(),
      false,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
  match
    assert_metamorphic_binary_drop_transform(
      AddLeadingF32DivDropToDefinedFunctions,
      "add-leading-f32-div-drop-to-defined-functions",
      @lib.Instruction::f32_div(),
      true,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
  match
    assert_metamorphic_binary_drop_transform(
      AddTrailingF32DivDropToDefinedFunctions,
      "add-trailing-f32-div-drop-to-defined-functions",
      @lib.Instruction::f32_div(),
      false,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
  match
    assert_metamorphic_binary_drop_transform(
      AddLeadingF64MulDropToDefinedFunctions,
      "add-leading-f64-mul-drop-to-defined-functions",
      @lib.Instruction::f64_mul(),
      true,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
  match
    assert_metamorphic_binary_drop_transform(
      AddTrailingF64MulDropToDefinedFunctions,
      "add-trailing-f64-mul-drop-to-defined-functions",
      @lib.Instruction::f64_mul(),
      false,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
  match
    assert_metamorphic_binary_drop_transform(
      AddLeadingF64DivDropToDefinedFunctions,
      "add-leading-f64-div-drop-to-defined-functions",
      @lib.Instruction::f64_div(),
      true,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
  match
    assert_metamorphic_binary_drop_transform(
      AddTrailingF64DivDropToDefinedFunctions,
      "add-trailing-f64-div-drop-to-defined-functions",
      @lib.Instruction::f64_div(),
      false,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
  match
    assert_metamorphic_binary_drop_transform(
      AddLeadingF32MinDropToDefinedFunctions,
      "add-leading-f32-min-drop-to-defined-functions",
      @lib.Instruction::f32_min(),
      true,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
  match
    assert_metamorphic_binary_drop_transform(
      AddTrailingF32MinDropToDefinedFunctions,
      "add-trailing-f32-min-drop-to-defined-functions",
      @lib.Instruction::f32_min(),
      false,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
  match
    assert_metamorphic_binary_drop_transform(
      AddLeadingF32MaxDropToDefinedFunctions,
      "add-leading-f32-max-drop-to-defined-functions",
      @lib.Instruction::f32_max(),
      true,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
  match
    assert_metamorphic_binary_drop_transform(
      AddTrailingF32MaxDropToDefinedFunctions,
      "add-trailing-f32-max-drop-to-defined-functions",
      @lib.Instruction::f32_max(),
      false,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
  match
    assert_metamorphic_binary_drop_transform(
      AddLeadingF64MinDropToDefinedFunctions,
      "add-leading-f64-min-drop-to-defined-functions",
      @lib.Instruction::f64_min(),
      true,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
  match
    assert_metamorphic_binary_drop_transform(
      AddTrailingF64MinDropToDefinedFunctions,
      "add-trailing-f64-min-drop-to-defined-functions",
      @lib.Instruction::f64_min(),
      false,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
  match
    assert_metamorphic_binary_drop_transform(
      AddLeadingF64MaxDropToDefinedFunctions,
      "add-leading-f64-max-drop-to-defined-functions",
      @lib.Instruction::f64_max(),
      true,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
  match
    assert_metamorphic_binary_drop_transform(
      AddTrailingF64MaxDropToDefinedFunctions,
      "add-trailing-f64-max-drop-to-defined-functions",
      @lib.Instruction::f64_max(),
      false,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
  match
    assert_metamorphic_binary_drop_transform(
      AddLeadingF32CopysignDropToDefinedFunctions,
      "add-leading-f32-copysign-drop-to-defined-functions",
      @lib.Instruction::f32_copysign(),
      true,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
  match
    assert_metamorphic_binary_drop_transform(
      AddTrailingF32CopysignDropToDefinedFunctions,
      "add-trailing-f32-copysign-drop-to-defined-functions",
      @lib.Instruction::f32_copysign(),
      false,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
  match
    assert_metamorphic_binary_drop_transform(
      AddLeadingF64CopysignDropToDefinedFunctions,
      "add-leading-f64-copysign-drop-to-defined-functions",
      @lib.Instruction::f64_copysign(),
      true,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
  match
    assert_metamorphic_binary_drop_transform(
      AddTrailingF64CopysignDropToDefinedFunctions,
      "add-trailing-f64-copysign-drop-to-defined-functions",
      @lib.Instruction::f64_copysign(),
      false,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "metamorphic i32 and i64 equality drop transforms preserve validation and binary roundtrip" {
  match
    assert_metamorphic_binary_drop_transform(
      AddLeadingI32EqDropToDefinedFunctions,
      "add-leading-i32-eq-drop-to-defined-functions",
      @lib.Instruction::i32_eq(),
      true,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
  match
    assert_metamorphic_binary_drop_transform(
      AddTrailingI32EqDropToDefinedFunctions,
      "add-trailing-i32-eq-drop-to-defined-functions",
      @lib.Instruction::i32_eq(),
      false,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
  match
    assert_metamorphic_binary_drop_transform(
      AddLeadingI32NeDropToDefinedFunctions,
      "add-leading-i32-ne-drop-to-defined-functions",
      @lib.Instruction::i32_ne(),
      true,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
  match
    assert_metamorphic_binary_drop_transform(
      AddTrailingI32NeDropToDefinedFunctions,
      "add-trailing-i32-ne-drop-to-defined-functions",
      @lib.Instruction::i32_ne(),
      false,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
  match
    assert_metamorphic_binary_drop_transform(
      AddLeadingI64EqDropToDefinedFunctions,
      "add-leading-i64-eq-drop-to-defined-functions",
      @lib.Instruction::i64_eq(),
      true,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
  match
    assert_metamorphic_binary_drop_transform(
      AddTrailingI64EqDropToDefinedFunctions,
      "add-trailing-i64-eq-drop-to-defined-functions",
      @lib.Instruction::i64_eq(),
      false,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
  match
    assert_metamorphic_binary_drop_transform(
      AddLeadingI64NeDropToDefinedFunctions,
      "add-leading-i64-ne-drop-to-defined-functions",
      @lib.Instruction::i64_ne(),
      true,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
  match
    assert_metamorphic_binary_drop_transform(
      AddTrailingI64NeDropToDefinedFunctions,
      "add-trailing-i64-ne-drop-to-defined-functions",
      @lib.Instruction::i64_ne(),
      false,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "metamorphic i32 and i64 signed relational drop transforms preserve validation and binary roundtrip" {
  match
    assert_metamorphic_binary_drop_transform(
      AddLeadingI32LtSDropToDefinedFunctions,
      "add-leading-i32-lt-s-drop-to-defined-functions",
      @lib.Instruction::i32_lt_s(),
      true,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
  match
    assert_metamorphic_binary_drop_transform(
      AddTrailingI32LtSDropToDefinedFunctions,
      "add-trailing-i32-lt-s-drop-to-defined-functions",
      @lib.Instruction::i32_lt_s(),
      false,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
  match
    assert_metamorphic_binary_drop_transform(
      AddLeadingI32GtSDropToDefinedFunctions,
      "add-leading-i32-gt-s-drop-to-defined-functions",
      @lib.Instruction::i32_gt_s(),
      true,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
  match
    assert_metamorphic_binary_drop_transform(
      AddTrailingI32GtSDropToDefinedFunctions,
      "add-trailing-i32-gt-s-drop-to-defined-functions",
      @lib.Instruction::i32_gt_s(),
      false,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
  match
    assert_metamorphic_binary_drop_transform(
      AddLeadingI64LtSDropToDefinedFunctions,
      "add-leading-i64-lt-s-drop-to-defined-functions",
      @lib.Instruction::i64_lt_s(),
      true,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
  match
    assert_metamorphic_binary_drop_transform(
      AddTrailingI64LtSDropToDefinedFunctions,
      "add-trailing-i64-lt-s-drop-to-defined-functions",
      @lib.Instruction::i64_lt_s(),
      false,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
  match
    assert_metamorphic_binary_drop_transform(
      AddLeadingI64GtSDropToDefinedFunctions,
      "add-leading-i64-gt-s-drop-to-defined-functions",
      @lib.Instruction::i64_gt_s(),
      true,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
  match
    assert_metamorphic_binary_drop_transform(
      AddTrailingI64GtSDropToDefinedFunctions,
      "add-trailing-i64-gt-s-drop-to-defined-functions",
      @lib.Instruction::i64_gt_s(),
      false,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
  match
    assert_metamorphic_binary_drop_transform(
      AddLeadingI32LeSDropToDefinedFunctions,
      "add-leading-i32-le-s-drop-to-defined-functions",
      @lib.Instruction::i32_le_s(),
      true,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
  match
    assert_metamorphic_binary_drop_transform(
      AddTrailingI32LeSDropToDefinedFunctions,
      "add-trailing-i32-le-s-drop-to-defined-functions",
      @lib.Instruction::i32_le_s(),
      false,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
  match
    assert_metamorphic_binary_drop_transform(
      AddLeadingI32GeSDropToDefinedFunctions,
      "add-leading-i32-ge-s-drop-to-defined-functions",
      @lib.Instruction::i32_ge_s(),
      true,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
  match
    assert_metamorphic_binary_drop_transform(
      AddTrailingI32GeSDropToDefinedFunctions,
      "add-trailing-i32-ge-s-drop-to-defined-functions",
      @lib.Instruction::i32_ge_s(),
      false,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
  match
    assert_metamorphic_binary_drop_transform(
      AddLeadingI64LeSDropToDefinedFunctions,
      "add-leading-i64-le-s-drop-to-defined-functions",
      @lib.Instruction::i64_le_s(),
      true,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
  match
    assert_metamorphic_binary_drop_transform(
      AddTrailingI64LeSDropToDefinedFunctions,
      "add-trailing-i64-le-s-drop-to-defined-functions",
      @lib.Instruction::i64_le_s(),
      false,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
  match
    assert_metamorphic_binary_drop_transform(
      AddLeadingI64GeSDropToDefinedFunctions,
      "add-leading-i64-ge-s-drop-to-defined-functions",
      @lib.Instruction::i64_ge_s(),
      true,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
  match
    assert_metamorphic_binary_drop_transform(
      AddTrailingI64GeSDropToDefinedFunctions,
      "add-trailing-i64-ge-s-drop-to-defined-functions",
      @lib.Instruction::i64_ge_s(),
      false,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
  match
    assert_metamorphic_binary_drop_transform(
      AddLeadingI32LtUDropToDefinedFunctions,
      "add-leading-i32-lt-u-drop-to-defined-functions",
      @lib.Instruction::i32_lt_u(),
      true,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
  match
    assert_metamorphic_binary_drop_transform(
      AddTrailingI32LtUDropToDefinedFunctions,
      "add-trailing-i32-lt-u-drop-to-defined-functions",
      @lib.Instruction::i32_lt_u(),
      false,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
  match
    assert_metamorphic_binary_drop_transform(
      AddLeadingI32GtUDropToDefinedFunctions,
      "add-leading-i32-gt-u-drop-to-defined-functions",
      @lib.Instruction::i32_gt_u(),
      true,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
  match
    assert_metamorphic_binary_drop_transform(
      AddTrailingI32GtUDropToDefinedFunctions,
      "add-trailing-i32-gt-u-drop-to-defined-functions",
      @lib.Instruction::i32_gt_u(),
      false,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
  match
    assert_metamorphic_binary_drop_transform(
      AddLeadingI64LtUDropToDefinedFunctions,
      "add-leading-i64-lt-u-drop-to-defined-functions",
      @lib.Instruction::i64_lt_u(),
      true,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
  match
    assert_metamorphic_binary_drop_transform(
      AddTrailingI64LtUDropToDefinedFunctions,
      "add-trailing-i64-lt-u-drop-to-defined-functions",
      @lib.Instruction::i64_lt_u(),
      false,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
  match
    assert_metamorphic_binary_drop_transform(
      AddLeadingI64GtUDropToDefinedFunctions,
      "add-leading-i64-gt-u-drop-to-defined-functions",
      @lib.Instruction::i64_gt_u(),
      true,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
  match
    assert_metamorphic_binary_drop_transform(
      AddTrailingI64GtUDropToDefinedFunctions,
      "add-trailing-i64-gt-u-drop-to-defined-functions",
      @lib.Instruction::i64_gt_u(),
      false,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
  match
    assert_metamorphic_binary_drop_transform(
      AddLeadingI32LeUDropToDefinedFunctions,
      "add-leading-i32-le-u-drop-to-defined-functions",
      @lib.Instruction::i32_le_u(),
      true,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
  match
    assert_metamorphic_binary_drop_transform(
      AddTrailingI32LeUDropToDefinedFunctions,
      "add-trailing-i32-le-u-drop-to-defined-functions",
      @lib.Instruction::i32_le_u(),
      false,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
  match
    assert_metamorphic_binary_drop_transform(
      AddLeadingI32GeUDropToDefinedFunctions,
      "add-leading-i32-ge-u-drop-to-defined-functions",
      @lib.Instruction::i32_ge_u(),
      true,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
  match
    assert_metamorphic_binary_drop_transform(
      AddTrailingI32GeUDropToDefinedFunctions,
      "add-trailing-i32-ge-u-drop-to-defined-functions",
      @lib.Instruction::i32_ge_u(),
      false,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
  match
    assert_metamorphic_binary_drop_transform(
      AddLeadingI64LeUDropToDefinedFunctions,
      "add-leading-i64-le-u-drop-to-defined-functions",
      @lib.Instruction::i64_le_u(),
      true,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
  match
    assert_metamorphic_binary_drop_transform(
      AddTrailingI64LeUDropToDefinedFunctions,
      "add-trailing-i64-le-u-drop-to-defined-functions",
      @lib.Instruction::i64_le_u(),
      false,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
  match
    assert_metamorphic_binary_drop_transform(
      AddLeadingI64GeUDropToDefinedFunctions,
      "add-leading-i64-ge-u-drop-to-defined-functions",
      @lib.Instruction::i64_ge_u(),
      true,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
  match
    assert_metamorphic_binary_drop_transform(
      AddTrailingI64GeUDropToDefinedFunctions,
      "add-trailing-i64-ge-u-drop-to-defined-functions",
      @lib.Instruction::i64_ge_u(),
      false,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "metamorphic i32 and i64 bitwise drop transforms preserve validation and binary roundtrip" {
  match
    assert_metamorphic_binary_drop_transform(
      AddLeadingI32AndDropToDefinedFunctions,
      "add-leading-i32-and-drop-to-defined-functions",
      @lib.Instruction::i32_and(),
      true,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
  match
    assert_metamorphic_binary_drop_transform(
      AddTrailingI32AndDropToDefinedFunctions,
      "add-trailing-i32-and-drop-to-defined-functions",
      @lib.Instruction::i32_and(),
      false,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
  match
    assert_metamorphic_binary_drop_transform(
      AddLeadingI32OrDropToDefinedFunctions,
      "add-leading-i32-or-drop-to-defined-functions",
      @lib.Instruction::i32_or(),
      true,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
  match
    assert_metamorphic_binary_drop_transform(
      AddTrailingI32OrDropToDefinedFunctions,
      "add-trailing-i32-or-drop-to-defined-functions",
      @lib.Instruction::i32_or(),
      false,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
  match
    assert_metamorphic_binary_drop_transform(
      AddLeadingI32XorDropToDefinedFunctions,
      "add-leading-i32-xor-drop-to-defined-functions",
      @lib.Instruction::i32_xor(),
      true,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
  match
    assert_metamorphic_binary_drop_transform(
      AddTrailingI32XorDropToDefinedFunctions,
      "add-trailing-i32-xor-drop-to-defined-functions",
      @lib.Instruction::i32_xor(),
      false,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
  match
    assert_metamorphic_binary_drop_transform(
      AddLeadingI64AndDropToDefinedFunctions,
      "add-leading-i64-and-drop-to-defined-functions",
      @lib.Instruction::i64_and(),
      true,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
  match
    assert_metamorphic_binary_drop_transform(
      AddTrailingI64AndDropToDefinedFunctions,
      "add-trailing-i64-and-drop-to-defined-functions",
      @lib.Instruction::i64_and(),
      false,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
  match
    assert_metamorphic_binary_drop_transform(
      AddLeadingI64OrDropToDefinedFunctions,
      "add-leading-i64-or-drop-to-defined-functions",
      @lib.Instruction::i64_or(),
      true,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
  match
    assert_metamorphic_binary_drop_transform(
      AddTrailingI64OrDropToDefinedFunctions,
      "add-trailing-i64-or-drop-to-defined-functions",
      @lib.Instruction::i64_or(),
      false,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
  match
    assert_metamorphic_binary_drop_transform(
      AddLeadingI64XorDropToDefinedFunctions,
      "add-leading-i64-xor-drop-to-defined-functions",
      @lib.Instruction::i64_xor(),
      true,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
  match
    assert_metamorphic_binary_drop_transform(
      AddTrailingI64XorDropToDefinedFunctions,
      "add-trailing-i64-xor-drop-to-defined-functions",
      @lib.Instruction::i64_xor(),
      false,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
fn assert_metamorphic_integer_shift_drop_transform(
  transform : MetamorphicValidTransform,
  expected_id : String,
  shift : @lib.Instruction,
  leading : Bool,
) -> Result[Unit, String] {
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [@lib.ValType::i32()])),
  )
  let base = @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([func_type]))
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::new([]),
          @lib.Expr::new([@lib.Instruction::i32_const(7)]),
        ),
      ]),
    )
  let transformed = match metamorphic_apply_transform(base, transform) {
    Ok(v) => v
    Err(msg) => return Err(msg)
  }
  if transformed.transform_id != expected_id {
    return Err("unexpected transform id")
  }
  match transformed.wasm_module.code_sec {
    Some(@lib.CodeSec(funcs)) =>
      match funcs[0] {
        @lib.Func(locals, @lib.Expr(instrs)) => {
          if locals != @lib.Locals::new([]) {
            return Err("unexpected locals")
          }
          if instrs.length() != 5 {
            return Err("unexpected instruction count")
          }
          let value = if expected_id.contains("i64") {
            @lib.Instruction::i64_const(0L)
          } else {
            @lib.Instruction::i32_const(0)
          }
          if leading {
            if instrs[0] != value ||
              instrs[1] != value ||
              instrs[2] != shift ||
              instrs[3] != @lib.Instruction::drop() ||
              instrs[4] != @lib.Instruction::i32_const(7) {
              return Err("unexpected leading shift/drop body")
            }
          } else if instrs[0] != @lib.Instruction::i32_const(7) ||
            instrs[1] != value ||
            instrs[2] != value ||
            instrs[3] != shift ||
            instrs[4] != @lib.Instruction::drop() {
            return Err("unexpected trailing shift/drop body")
          }
        }
      }
    None => return Err("expected transformed code section")
  }
  assert_metamorphic_roundtrip_valid(transformed.wasm_module)
}

///|
fn assert_metamorphic_integer_unary_drop_transform(
  transform : MetamorphicValidTransform,
  expected_id : String,
  unary : @lib.Instruction,
  leading : Bool,
) -> Result[Unit, String] {
  let zero = if expected_id.contains("i64") &&
    !expected_id.contains("extend-i32") {
    @lib.Instruction::i64_const(0L)
  } else {
    @lib.Instruction::i32_const(0)
  }
  assert_metamorphic_typed_unary_drop_transform(
    transform, expected_id, zero, unary, leading,
  )
}

///|
fn assert_metamorphic_typed_unary_drop_transform(
  transform : MetamorphicValidTransform,
  expected_id : String,
  operand : @lib.Instruction,
  unary : @lib.Instruction,
  leading : Bool,
) -> Result[Unit, String] {
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [@lib.ValType::i32()])),
  )
  let base = @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([func_type]))
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::new([]),
          @lib.Expr::new([@lib.Instruction::i32_const(7)]),
        ),
      ]),
    )
  let transformed = match metamorphic_apply_transform(base, transform) {
    Ok(v) => v
    Err(msg) => return Err(msg)
  }
  if transformed.transform_id != expected_id {
    return Err("unexpected transform id")
  }
  match transformed.wasm_module.code_sec {
    Some(@lib.CodeSec(funcs)) =>
      match funcs[0] {
        @lib.Func(locals, @lib.Expr(instrs)) => {
          if locals != @lib.Locals::new([]) {
            return Err("unexpected locals")
          }
          if instrs.length() != 4 {
            return Err("unexpected instruction count")
          }
          if leading {
            if instrs[0] != operand ||
              instrs[1] != unary ||
              instrs[2] != @lib.Instruction::drop() ||
              instrs[3] != @lib.Instruction::i32_const(7) {
              return Err("unexpected leading unary/drop body")
            }
          } else if instrs[0] != @lib.Instruction::i32_const(7) ||
            instrs[1] != operand ||
            instrs[2] != unary ||
            instrs[3] != @lib.Instruction::drop() {
            return Err("unexpected trailing unary/drop body")
          }
        }
      }
    None => return Err("expected transformed code section")
  }
  assert_metamorphic_roundtrip_valid(transformed.wasm_module)
}

///|
test "metamorphic demote/promote drop transforms preserve validation and binary roundtrip" {
  match
    assert_metamorphic_typed_unary_drop_transform(
      AddLeadingF32DemoteF64DropToDefinedFunctions,
      "add-leading-f32-demote-f64-drop-to-defined-functions",
      @lib.Instruction::f64_const(1.0),
      @lib.Instruction::f32_demote_f64(),
      true,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
  match
    assert_metamorphic_typed_unary_drop_transform(
      AddTrailingF32DemoteF64DropToDefinedFunctions,
      "add-trailing-f32-demote-f64-drop-to-defined-functions",
      @lib.Instruction::f64_const(1.0),
      @lib.Instruction::f32_demote_f64(),
      false,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
  match
    assert_metamorphic_typed_unary_drop_transform(
      AddLeadingF64PromoteF32DropToDefinedFunctions,
      "add-leading-f64-promote-f32-drop-to-defined-functions",
      @lib.Instruction::f32_const(1.0),
      @lib.Instruction::f64_promote_f32(),
      true,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
  match
    assert_metamorphic_typed_unary_drop_transform(
      AddTrailingF64PromoteF32DropToDefinedFunctions,
      "add-trailing-f64-promote-f32-drop-to-defined-functions",
      @lib.Instruction::f32_const(1.0),
      @lib.Instruction::f64_promote_f32(),
      false,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "metamorphic reinterpret drop transforms preserve validation and binary roundtrip" {
  match
    assert_metamorphic_typed_unary_drop_transform(
      AddLeadingI32ReinterpretF32DropToDefinedFunctions,
      "add-leading-i32-reinterpret-f32-drop-to-defined-functions",
      @lib.Instruction::f32_const(0.0),
      @lib.Instruction::i32_reinterpret_f32(),
      true,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
  match
    assert_metamorphic_typed_unary_drop_transform(
      AddTrailingI32ReinterpretF32DropToDefinedFunctions,
      "add-trailing-i32-reinterpret-f32-drop-to-defined-functions",
      @lib.Instruction::f32_const(0.0),
      @lib.Instruction::i32_reinterpret_f32(),
      false,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
  match
    assert_metamorphic_typed_unary_drop_transform(
      AddLeadingI64ReinterpretF64DropToDefinedFunctions,
      "add-leading-i64-reinterpret-f64-drop-to-defined-functions",
      @lib.Instruction::f64_const(0.0),
      @lib.Instruction::i64_reinterpret_f64(),
      true,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
  match
    assert_metamorphic_typed_unary_drop_transform(
      AddTrailingI64ReinterpretF64DropToDefinedFunctions,
      "add-trailing-i64-reinterpret-f64-drop-to-defined-functions",
      @lib.Instruction::f64_const(0.0),
      @lib.Instruction::i64_reinterpret_f64(),
      false,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
  match
    assert_metamorphic_typed_unary_drop_transform(
      AddLeadingF32ReinterpretI32DropToDefinedFunctions,
      "add-leading-f32-reinterpret-i32-drop-to-defined-functions",
      @lib.Instruction::i32_const(0),
      @lib.Instruction::f32_reinterpret_i32(),
      true,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
  match
    assert_metamorphic_typed_unary_drop_transform(
      AddTrailingF32ReinterpretI32DropToDefinedFunctions,
      "add-trailing-f32-reinterpret-i32-drop-to-defined-functions",
      @lib.Instruction::i32_const(0),
      @lib.Instruction::f32_reinterpret_i32(),
      false,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
  match
    assert_metamorphic_typed_unary_drop_transform(
      AddLeadingF64ReinterpretI64DropToDefinedFunctions,
      "add-leading-f64-reinterpret-i64-drop-to-defined-functions",
      @lib.Instruction::i64_const(0L),
      @lib.Instruction::f64_reinterpret_i64(),
      true,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
  match
    assert_metamorphic_typed_unary_drop_transform(
      AddTrailingF64ReinterpretI64DropToDefinedFunctions,
      "add-trailing-f64-reinterpret-i64-drop-to-defined-functions",
      @lib.Instruction::i64_const(0L),
      @lib.Instruction::f64_reinterpret_i64(),
      false,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "metamorphic i32.wrap_i64 and i64.extend_i32 drop transforms preserve validation and binary roundtrip" {
  match
    assert_metamorphic_integer_unary_drop_transform(
      AddLeadingI32WrapI64DropToDefinedFunctions,
      "add-leading-i32-wrap-i64-drop-to-defined-functions",
      @lib.Instruction::i32_wrap_i64(),
      true,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
  match
    assert_metamorphic_integer_unary_drop_transform(
      AddTrailingI32WrapI64DropToDefinedFunctions,
      "add-trailing-i32-wrap-i64-drop-to-defined-functions",
      @lib.Instruction::i32_wrap_i64(),
      false,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
  match
    assert_metamorphic_integer_unary_drop_transform(
      AddLeadingI64ExtendI32SDropToDefinedFunctions,
      "add-leading-i64-extend-i32-s-drop-to-defined-functions",
      @lib.Instruction::i64_extend_i32s(),
      true,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
  match
    assert_metamorphic_integer_unary_drop_transform(
      AddTrailingI64ExtendI32SDropToDefinedFunctions,
      "add-trailing-i64-extend-i32-s-drop-to-defined-functions",
      @lib.Instruction::i64_extend_i32s(),
      false,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
  match
    assert_metamorphic_integer_unary_drop_transform(
      AddLeadingI64ExtendI32UDropToDefinedFunctions,
      "add-leading-i64-extend-i32-u-drop-to-defined-functions",
      @lib.Instruction::i64_extend_i32u(),
      true,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
  match
    assert_metamorphic_integer_unary_drop_transform(
      AddTrailingI64ExtendI32UDropToDefinedFunctions,
      "add-trailing-i64-extend-i32-u-drop-to-defined-functions",
      @lib.Instruction::i64_extend_i32u(),
      false,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "metamorphic i32 and i64 sign-extension drop transforms preserve validation and binary roundtrip" {
  match
    assert_metamorphic_integer_unary_drop_transform(
      AddLeadingI32Extend8SDropToDefinedFunctions,
      "add-leading-i32-extend8-s-drop-to-defined-functions",
      @lib.Instruction::i32_extend8s(),
      true,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
  match
    assert_metamorphic_integer_unary_drop_transform(
      AddTrailingI32Extend8SDropToDefinedFunctions,
      "add-trailing-i32-extend8-s-drop-to-defined-functions",
      @lib.Instruction::i32_extend8s(),
      false,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
  match
    assert_metamorphic_integer_unary_drop_transform(
      AddLeadingI32Extend16SDropToDefinedFunctions,
      "add-leading-i32-extend16-s-drop-to-defined-functions",
      @lib.Instruction::i32_extend16s(),
      true,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
  match
    assert_metamorphic_integer_unary_drop_transform(
      AddTrailingI32Extend16SDropToDefinedFunctions,
      "add-trailing-i32-extend16-s-drop-to-defined-functions",
      @lib.Instruction::i32_extend16s(),
      false,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
  match
    assert_metamorphic_integer_unary_drop_transform(
      AddLeadingI64Extend8SDropToDefinedFunctions,
      "add-leading-i64-extend8-s-drop-to-defined-functions",
      @lib.Instruction::i64_extend8s(),
      true,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
  match
    assert_metamorphic_integer_unary_drop_transform(
      AddTrailingI64Extend8SDropToDefinedFunctions,
      "add-trailing-i64-extend8-s-drop-to-defined-functions",
      @lib.Instruction::i64_extend8s(),
      false,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
  match
    assert_metamorphic_integer_unary_drop_transform(
      AddLeadingI64Extend16SDropToDefinedFunctions,
      "add-leading-i64-extend16-s-drop-to-defined-functions",
      @lib.Instruction::i64_extend16s(),
      true,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
  match
    assert_metamorphic_integer_unary_drop_transform(
      AddTrailingI64Extend16SDropToDefinedFunctions,
      "add-trailing-i64-extend16-s-drop-to-defined-functions",
      @lib.Instruction::i64_extend16s(),
      false,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
  match
    assert_metamorphic_integer_unary_drop_transform(
      AddLeadingI64Extend32SDropToDefinedFunctions,
      "add-leading-i64-extend32-s-drop-to-defined-functions",
      @lib.Instruction::i64_extend32s(),
      true,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
  match
    assert_metamorphic_integer_unary_drop_transform(
      AddTrailingI64Extend32SDropToDefinedFunctions,
      "add-trailing-i64-extend32-s-drop-to-defined-functions",
      @lib.Instruction::i64_extend32s(),
      false,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "metamorphic i32 and i64 clz/ctz/popcnt drop transforms preserve validation and binary roundtrip" {
  match
    assert_metamorphic_integer_unary_drop_transform(
      AddLeadingI32ClzDropToDefinedFunctions,
      "add-leading-i32-clz-drop-to-defined-functions",
      @lib.Instruction::i32_clz(),
      true,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
  match
    assert_metamorphic_integer_unary_drop_transform(
      AddTrailingI32ClzDropToDefinedFunctions,
      "add-trailing-i32-clz-drop-to-defined-functions",
      @lib.Instruction::i32_clz(),
      false,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
  match
    assert_metamorphic_integer_unary_drop_transform(
      AddLeadingI32CtzDropToDefinedFunctions,
      "add-leading-i32-ctz-drop-to-defined-functions",
      @lib.Instruction::i32_ctz(),
      true,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
  match
    assert_metamorphic_integer_unary_drop_transform(
      AddTrailingI32CtzDropToDefinedFunctions,
      "add-trailing-i32-ctz-drop-to-defined-functions",
      @lib.Instruction::i32_ctz(),
      false,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
  match
    assert_metamorphic_integer_unary_drop_transform(
      AddLeadingI32PopcntDropToDefinedFunctions,
      "add-leading-i32-popcnt-drop-to-defined-functions",
      @lib.Instruction::i32_popcnt(),
      true,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
  match
    assert_metamorphic_integer_unary_drop_transform(
      AddTrailingI32PopcntDropToDefinedFunctions,
      "add-trailing-i32-popcnt-drop-to-defined-functions",
      @lib.Instruction::i32_popcnt(),
      false,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
  match
    assert_metamorphic_integer_unary_drop_transform(
      AddLeadingI64ClzDropToDefinedFunctions,
      "add-leading-i64-clz-drop-to-defined-functions",
      @lib.Instruction::i64_clz(),
      true,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
  match
    assert_metamorphic_integer_unary_drop_transform(
      AddTrailingI64ClzDropToDefinedFunctions,
      "add-trailing-i64-clz-drop-to-defined-functions",
      @lib.Instruction::i64_clz(),
      false,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
  match
    assert_metamorphic_integer_unary_drop_transform(
      AddLeadingI64CtzDropToDefinedFunctions,
      "add-leading-i64-ctz-drop-to-defined-functions",
      @lib.Instruction::i64_ctz(),
      true,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
  match
    assert_metamorphic_integer_unary_drop_transform(
      AddTrailingI64CtzDropToDefinedFunctions,
      "add-trailing-i64-ctz-drop-to-defined-functions",
      @lib.Instruction::i64_ctz(),
      false,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
  match
    assert_metamorphic_integer_unary_drop_transform(
      AddLeadingI64PopcntDropToDefinedFunctions,
      "add-leading-i64-popcnt-drop-to-defined-functions",
      @lib.Instruction::i64_popcnt(),
      true,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
  match
    assert_metamorphic_integer_unary_drop_transform(
      AddTrailingI64PopcntDropToDefinedFunctions,
      "add-trailing-i64-popcnt-drop-to-defined-functions",
      @lib.Instruction::i64_popcnt(),
      false,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "metamorphic i32 and i64 shift/rotate drop transforms preserve validation and binary roundtrip" {
  match
    assert_metamorphic_integer_shift_drop_transform(
      AddLeadingI32ShlDropToDefinedFunctions,
      "add-leading-i32-shl-drop-to-defined-functions",
      @lib.Instruction::i32_shl(),
      true,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
  match
    assert_metamorphic_integer_shift_drop_transform(
      AddTrailingI32ShlDropToDefinedFunctions,
      "add-trailing-i32-shl-drop-to-defined-functions",
      @lib.Instruction::i32_shl(),
      false,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
  match
    assert_metamorphic_integer_shift_drop_transform(
      AddLeadingI32ShrSDropToDefinedFunctions,
      "add-leading-i32-shr-s-drop-to-defined-functions",
      @lib.Instruction::i32_shr_s(),
      true,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
  match
    assert_metamorphic_integer_shift_drop_transform(
      AddTrailingI32ShrSDropToDefinedFunctions,
      "add-trailing-i32-shr-s-drop-to-defined-functions",
      @lib.Instruction::i32_shr_s(),
      false,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
  match
    assert_metamorphic_integer_shift_drop_transform(
      AddLeadingI32ShrUDropToDefinedFunctions,
      "add-leading-i32-shr-u-drop-to-defined-functions",
      @lib.Instruction::i32_shr_u(),
      true,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
  match
    assert_metamorphic_integer_shift_drop_transform(
      AddTrailingI32ShrUDropToDefinedFunctions,
      "add-trailing-i32-shr-u-drop-to-defined-functions",
      @lib.Instruction::i32_shr_u(),
      false,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
  match
    assert_metamorphic_integer_shift_drop_transform(
      AddLeadingI64ShlDropToDefinedFunctions,
      "add-leading-i64-shl-drop-to-defined-functions",
      @lib.Instruction::i64_shl(),
      true,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
  match
    assert_metamorphic_integer_shift_drop_transform(
      AddTrailingI64ShlDropToDefinedFunctions,
      "add-trailing-i64-shl-drop-to-defined-functions",
      @lib.Instruction::i64_shl(),
      false,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
  match
    assert_metamorphic_integer_shift_drop_transform(
      AddLeadingI64ShrSDropToDefinedFunctions,
      "add-leading-i64-shr-s-drop-to-defined-functions",
      @lib.Instruction::i64_shr_s(),
      true,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
  match
    assert_metamorphic_integer_shift_drop_transform(
      AddTrailingI64ShrSDropToDefinedFunctions,
      "add-trailing-i64-shr-s-drop-to-defined-functions",
      @lib.Instruction::i64_shr_s(),
      false,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
  match
    assert_metamorphic_integer_shift_drop_transform(
      AddLeadingI64ShrUDropToDefinedFunctions,
      "add-leading-i64-shr-u-drop-to-defined-functions",
      @lib.Instruction::i64_shr_u(),
      true,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
  match
    assert_metamorphic_integer_shift_drop_transform(
      AddTrailingI64ShrUDropToDefinedFunctions,
      "add-trailing-i64-shr-u-drop-to-defined-functions",
      @lib.Instruction::i64_shr_u(),
      false,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
  match
    assert_metamorphic_integer_shift_drop_transform(
      AddLeadingI32RotlDropToDefinedFunctions,
      "add-leading-i32-rotl-drop-to-defined-functions",
      @lib.Instruction::i32_rotl(),
      true,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
  match
    assert_metamorphic_integer_shift_drop_transform(
      AddTrailingI32RotlDropToDefinedFunctions,
      "add-trailing-i32-rotl-drop-to-defined-functions",
      @lib.Instruction::i32_rotl(),
      false,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
  match
    assert_metamorphic_integer_shift_drop_transform(
      AddLeadingI32RotrDropToDefinedFunctions,
      "add-leading-i32-rotr-drop-to-defined-functions",
      @lib.Instruction::i32_rotr(),
      true,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
  match
    assert_metamorphic_integer_shift_drop_transform(
      AddTrailingI32RotrDropToDefinedFunctions,
      "add-trailing-i32-rotr-drop-to-defined-functions",
      @lib.Instruction::i32_rotr(),
      false,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
  match
    assert_metamorphic_integer_shift_drop_transform(
      AddLeadingI64RotlDropToDefinedFunctions,
      "add-leading-i64-rotl-drop-to-defined-functions",
      @lib.Instruction::i64_rotl(),
      true,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
  match
    assert_metamorphic_integer_shift_drop_transform(
      AddTrailingI64RotlDropToDefinedFunctions,
      "add-trailing-i64-rotl-drop-to-defined-functions",
      @lib.Instruction::i64_rotl(),
      false,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
  match
    assert_metamorphic_integer_shift_drop_transform(
      AddLeadingI64RotrDropToDefinedFunctions,
      "add-leading-i64-rotr-drop-to-defined-functions",
      @lib.Instruction::i64_rotr(),
      true,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
  match
    assert_metamorphic_integer_shift_drop_transform(
      AddTrailingI64RotrDropToDefinedFunctions,
      "add-trailing-i64-rotr-drop-to-defined-functions",
      @lib.Instruction::i64_rotr(),
      false,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "metamorphic f32 and f64 equality drop transforms preserve validation and binary roundtrip" {
  match
    assert_metamorphic_binary_drop_transform(
      AddLeadingF32EqDropToDefinedFunctions,
      "add-leading-f32-eq-drop-to-defined-functions",
      @lib.Instruction::f32_eq(),
      true,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
  match
    assert_metamorphic_binary_drop_transform(
      AddTrailingF32EqDropToDefinedFunctions,
      "add-trailing-f32-eq-drop-to-defined-functions",
      @lib.Instruction::f32_eq(),
      false,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
  match
    assert_metamorphic_binary_drop_transform(
      AddLeadingF32NeDropToDefinedFunctions,
      "add-leading-f32-ne-drop-to-defined-functions",
      @lib.Instruction::f32_ne(),
      true,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
  match
    assert_metamorphic_binary_drop_transform(
      AddTrailingF32NeDropToDefinedFunctions,
      "add-trailing-f32-ne-drop-to-defined-functions",
      @lib.Instruction::f32_ne(),
      false,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
  match
    assert_metamorphic_binary_drop_transform(
      AddLeadingF64EqDropToDefinedFunctions,
      "add-leading-f64-eq-drop-to-defined-functions",
      @lib.Instruction::f64_eq(),
      true,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
  match
    assert_metamorphic_binary_drop_transform(
      AddTrailingF64EqDropToDefinedFunctions,
      "add-trailing-f64-eq-drop-to-defined-functions",
      @lib.Instruction::f64_eq(),
      false,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
  match
    assert_metamorphic_binary_drop_transform(
      AddLeadingF64NeDropToDefinedFunctions,
      "add-leading-f64-ne-drop-to-defined-functions",
      @lib.Instruction::f64_ne(),
      true,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
  match
    assert_metamorphic_binary_drop_transform(
      AddTrailingF64NeDropToDefinedFunctions,
      "add-trailing-f64-ne-drop-to-defined-functions",
      @lib.Instruction::f64_ne(),
      false,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
  match
    assert_metamorphic_binary_drop_transform(
      AddLeadingF32LtDropToDefinedFunctions,
      "add-leading-f32-lt-drop-to-defined-functions",
      @lib.Instruction::f32_lt(),
      true,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
  match
    assert_metamorphic_binary_drop_transform(
      AddTrailingF32LtDropToDefinedFunctions,
      "add-trailing-f32-lt-drop-to-defined-functions",
      @lib.Instruction::f32_lt(),
      false,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
  match
    assert_metamorphic_binary_drop_transform(
      AddLeadingF32GtDropToDefinedFunctions,
      "add-leading-f32-gt-drop-to-defined-functions",
      @lib.Instruction::f32_gt(),
      true,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
  match
    assert_metamorphic_binary_drop_transform(
      AddTrailingF32GtDropToDefinedFunctions,
      "add-trailing-f32-gt-drop-to-defined-functions",
      @lib.Instruction::f32_gt(),
      false,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
  match
    assert_metamorphic_binary_drop_transform(
      AddLeadingF64LtDropToDefinedFunctions,
      "add-leading-f64-lt-drop-to-defined-functions",
      @lib.Instruction::f64_lt(),
      true,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
  match
    assert_metamorphic_binary_drop_transform(
      AddTrailingF64LtDropToDefinedFunctions,
      "add-trailing-f64-lt-drop-to-defined-functions",
      @lib.Instruction::f64_lt(),
      false,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
  match
    assert_metamorphic_binary_drop_transform(
      AddLeadingF64GtDropToDefinedFunctions,
      "add-leading-f64-gt-drop-to-defined-functions",
      @lib.Instruction::f64_gt(),
      true,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
  match
    assert_metamorphic_binary_drop_transform(
      AddTrailingF64GtDropToDefinedFunctions,
      "add-trailing-f64-gt-drop-to-defined-functions",
      @lib.Instruction::f64_gt(),
      false,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
  match
    assert_metamorphic_binary_drop_transform(
      AddLeadingF32LeDropToDefinedFunctions,
      "add-leading-f32-le-drop-to-defined-functions",
      @lib.Instruction::f32_le(),
      true,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
  match
    assert_metamorphic_binary_drop_transform(
      AddTrailingF32LeDropToDefinedFunctions,
      "add-trailing-f32-le-drop-to-defined-functions",
      @lib.Instruction::f32_le(),
      false,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
  match
    assert_metamorphic_binary_drop_transform(
      AddLeadingF32GeDropToDefinedFunctions,
      "add-leading-f32-ge-drop-to-defined-functions",
      @lib.Instruction::f32_ge(),
      true,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
  match
    assert_metamorphic_binary_drop_transform(
      AddTrailingF32GeDropToDefinedFunctions,
      "add-trailing-f32-ge-drop-to-defined-functions",
      @lib.Instruction::f32_ge(),
      false,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
  match
    assert_metamorphic_binary_drop_transform(
      AddLeadingF64LeDropToDefinedFunctions,
      "add-leading-f64-le-drop-to-defined-functions",
      @lib.Instruction::f64_le(),
      true,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
  match
    assert_metamorphic_binary_drop_transform(
      AddTrailingF64LeDropToDefinedFunctions,
      "add-trailing-f64-le-drop-to-defined-functions",
      @lib.Instruction::f64_le(),
      false,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
  match
    assert_metamorphic_binary_drop_transform(
      AddLeadingF64GeDropToDefinedFunctions,
      "add-leading-f64-ge-drop-to-defined-functions",
      @lib.Instruction::f64_ge(),
      true,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
  match
    assert_metamorphic_binary_drop_transform(
      AddTrailingF64GeDropToDefinedFunctions,
      "add-trailing-f64-ge-drop-to-defined-functions",
      @lib.Instruction::f64_ge(),
      false,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "metamorphic f32 and f64 ceil/floor/trunc/nearest drop transforms preserve validation and binary roundtrip" {
  match
    assert_metamorphic_unary_drop_transform(
      AddLeadingF32CeilDropToDefinedFunctions,
      "add-leading-f32-ceil-drop-to-defined-functions",
      @lib.Instruction::f32_ceil(),
      true,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
  match
    assert_metamorphic_unary_drop_transform(
      AddTrailingF32CeilDropToDefinedFunctions,
      "add-trailing-f32-ceil-drop-to-defined-functions",
      @lib.Instruction::f32_ceil(),
      false,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
  match
    assert_metamorphic_unary_drop_transform(
      AddLeadingF32FloorDropToDefinedFunctions,
      "add-leading-f32-floor-drop-to-defined-functions",
      @lib.Instruction::f32_floor(),
      true,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
  match
    assert_metamorphic_unary_drop_transform(
      AddTrailingF32FloorDropToDefinedFunctions,
      "add-trailing-f32-floor-drop-to-defined-functions",
      @lib.Instruction::f32_floor(),
      false,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
  match
    assert_metamorphic_unary_drop_transform(
      AddLeadingF64CeilDropToDefinedFunctions,
      "add-leading-f64-ceil-drop-to-defined-functions",
      @lib.Instruction::f64_ceil(),
      true,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
  match
    assert_metamorphic_unary_drop_transform(
      AddTrailingF64CeilDropToDefinedFunctions,
      "add-trailing-f64-ceil-drop-to-defined-functions",
      @lib.Instruction::f64_ceil(),
      false,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
  match
    assert_metamorphic_unary_drop_transform(
      AddLeadingF64FloorDropToDefinedFunctions,
      "add-leading-f64-floor-drop-to-defined-functions",
      @lib.Instruction::f64_floor(),
      true,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
  match
    assert_metamorphic_unary_drop_transform(
      AddTrailingF64FloorDropToDefinedFunctions,
      "add-trailing-f64-floor-drop-to-defined-functions",
      @lib.Instruction::f64_floor(),
      false,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
  match
    assert_metamorphic_unary_drop_transform(
      AddLeadingF32TruncDropToDefinedFunctions,
      "add-leading-f32-trunc-drop-to-defined-functions",
      @lib.Instruction::f32_trunc(),
      true,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
  match
    assert_metamorphic_unary_drop_transform(
      AddTrailingF32TruncDropToDefinedFunctions,
      "add-trailing-f32-trunc-drop-to-defined-functions",
      @lib.Instruction::f32_trunc(),
      false,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
  match
    assert_metamorphic_unary_drop_transform(
      AddLeadingF32NearestDropToDefinedFunctions,
      "add-leading-f32-nearest-drop-to-defined-functions",
      @lib.Instruction::f32_nearest(),
      true,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
  match
    assert_metamorphic_unary_drop_transform(
      AddTrailingF32NearestDropToDefinedFunctions,
      "add-trailing-f32-nearest-drop-to-defined-functions",
      @lib.Instruction::f32_nearest(),
      false,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
  match
    assert_metamorphic_unary_drop_transform(
      AddLeadingF64TruncDropToDefinedFunctions,
      "add-leading-f64-trunc-drop-to-defined-functions",
      @lib.Instruction::f64_trunc(),
      true,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
  match
    assert_metamorphic_unary_drop_transform(
      AddTrailingF64TruncDropToDefinedFunctions,
      "add-trailing-f64-trunc-drop-to-defined-functions",
      @lib.Instruction::f64_trunc(),
      false,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
  match
    assert_metamorphic_unary_drop_transform(
      AddLeadingF64NearestDropToDefinedFunctions,
      "add-leading-f64-nearest-drop-to-defined-functions",
      @lib.Instruction::f64_nearest(),
      true,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
  match
    assert_metamorphic_unary_drop_transform(
      AddTrailingF64NearestDropToDefinedFunctions,
      "add-trailing-f64-nearest-drop-to-defined-functions",
      @lib.Instruction::f64_nearest(),
      false,
    ) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "metamorphic leading f64 abs drop transform preserves validation and binary roundtrip" {
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [@lib.ValType::i32()])),
  )
  let base = @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([func_type]))
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::new([]),
          @lib.Expr::new([@lib.Instruction::i32_const(7)]),
        ),
      ]),
    )
  let transformed = match
    metamorphic_apply_transform(base, AddLeadingF64AbsDropToDefinedFunctions) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  @debug.assert_eq(
    transformed.transform_id,
    "add-leading-f64-abs-drop-to-defined-functions",
  )
  match transformed.wasm_module.code_sec {
    Some(@lib.CodeSec(funcs)) =>
      match funcs[0] {
        @lib.Func(locals, @lib.Expr(instrs)) => {
          @debug.assert_eq(locals, @lib.Locals::new([]))
          @debug.assert_eq(instrs.length(), 4)
          @debug.assert_eq(instrs[0], @lib.Instruction::f64_const(0.0))
          @debug.assert_eq(instrs[1], @lib.Instruction::f64_abs())
          @debug.assert_eq(instrs[2], @lib.Instruction::drop())
          @debug.assert_eq(instrs[3], @lib.Instruction::i32_const(7))
        }
      }
    None => fail("expected transformed code section")
  }
  match assert_metamorphic_roundtrip_valid(transformed.wasm_module) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "metamorphic trailing f64 abs drop transform preserves validation and binary roundtrip" {
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [@lib.ValType::i32()])),
  )
  let base = @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([func_type]))
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::new([]),
          @lib.Expr::new([@lib.Instruction::i32_const(7)]),
        ),
      ]),
    )
  let transformed = match
    metamorphic_apply_transform(base, AddTrailingF64AbsDropToDefinedFunctions) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  @debug.assert_eq(
    transformed.transform_id,
    "add-trailing-f64-abs-drop-to-defined-functions",
  )
  match transformed.wasm_module.code_sec {
    Some(@lib.CodeSec(funcs)) =>
      match funcs[0] {
        @lib.Func(locals, @lib.Expr(instrs)) => {
          @debug.assert_eq(locals, @lib.Locals::new([]))
          @debug.assert_eq(instrs.length(), 4)
          @debug.assert_eq(instrs[0], @lib.Instruction::i32_const(7))
          @debug.assert_eq(instrs[1], @lib.Instruction::f64_const(0.0))
          @debug.assert_eq(instrs[2], @lib.Instruction::f64_abs())
          @debug.assert_eq(instrs[3], @lib.Instruction::drop())
        }
      }
    None => fail("expected transformed code section")
  }
  match assert_metamorphic_roundtrip_valid(transformed.wasm_module) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "metamorphic trailing true if transform preserves validation and binary roundtrip" {
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [@lib.ValType::i32()])),
  )
  let base = @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([func_type]))
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::new([]),
          @lib.Expr::new([@lib.Instruction::i32_const(7)]),
        ),
      ]),
    )
  let transformed = match
    metamorphic_apply_transform(base, AddTrailingTrueIfToDefinedFunctions) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  @debug.assert_eq(
    transformed.transform_id,
    "add-trailing-true-if-to-defined-functions",
  )
  match transformed.wasm_module.code_sec {
    Some(@lib.CodeSec(funcs)) =>
      match funcs[0] {
        @lib.Func(locals, @lib.Expr(instrs)) => {
          @debug.assert_eq(locals, @lib.Locals::new([]))
          @debug.assert_eq(instrs.length(), 3)
          @debug.assert_eq(instrs[0], @lib.Instruction::i32_const(7))
          @debug.assert_eq(instrs[1], @lib.Instruction::i32_const(1))
          @debug.assert_eq(
            instrs[2],
            @lib.Instruction::if_(@lib.BlockType::void_(), [], None),
          )
        }
      }
    None => fail("expected transformed code section")
  }
  match assert_metamorphic_roundtrip_valid(transformed.wasm_module) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "metamorphic trailing false if transform preserves validation and binary roundtrip" {
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [@lib.ValType::i32()])),
  )
  let base = @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([func_type]))
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::new([]),
          @lib.Expr::new([@lib.Instruction::i32_const(7)]),
        ),
      ]),
    )
  let transformed = match
    metamorphic_apply_transform(base, AddTrailingFalseIfToDefinedFunctions) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  @debug.assert_eq(
    transformed.transform_id,
    "add-trailing-false-if-to-defined-functions",
  )
  match transformed.wasm_module.code_sec {
    Some(@lib.CodeSec(funcs)) =>
      match funcs[0] {
        @lib.Func(locals, @lib.Expr(instrs)) => {
          @debug.assert_eq(locals, @lib.Locals::new([]))
          @debug.assert_eq(instrs.length(), 3)
          @debug.assert_eq(instrs[0], @lib.Instruction::i32_const(7))
          @debug.assert_eq(instrs[1], @lib.Instruction::i32_const(0))
          @debug.assert_eq(
            instrs[2],
            @lib.Instruction::if_(@lib.BlockType::void_(), [], None),
          )
        }
      }
    None => fail("expected transformed code section")
  }
  match assert_metamorphic_roundtrip_valid(transformed.wasm_module) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "metamorphic leading f64 const drop transform preserves validation and binary roundtrip" {
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [@lib.ValType::i32()])),
  )
  let base = @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([func_type]))
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::new([]),
          @lib.Expr::new([@lib.Instruction::i32_const(7)]),
        ),
      ]),
    )
  let transformed = match
    metamorphic_apply_transform(base, AddLeadingF64ConstDropToDefinedFunctions) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  @debug.assert_eq(
    transformed.transform_id,
    "add-leading-f64-const-drop-to-defined-functions",
  )
  match transformed.wasm_module.code_sec {
    Some(@lib.CodeSec(funcs)) =>
      match funcs[0] {
        @lib.Func(locals, @lib.Expr(instrs)) => {
          @debug.assert_eq(locals, @lib.Locals::new([]))
          @debug.assert_eq(instrs.length(), 3)
          @debug.assert_eq(
            instrs[0],
            @lib.Instruction::f64_const(@lib.F64(0.0)),
          )
          @debug.assert_eq(instrs[1], @lib.Instruction::drop())
          @debug.assert_eq(instrs[2], @lib.Instruction::i32_const(7))
        }
      }
    None => fail("expected transformed code section")
  }
  match assert_metamorphic_roundtrip_valid(transformed.wasm_module) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "metamorphic trailing f64 const drop transform preserves validation and binary roundtrip" {
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [@lib.ValType::i32()])),
  )
  let base = @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([func_type]))
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::new([]),
          @lib.Expr::new([@lib.Instruction::i32_const(7)]),
        ),
      ]),
    )
  let transformed = match
    metamorphic_apply_transform(base, AddTrailingF64ConstDropToDefinedFunctions) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  @debug.assert_eq(
    transformed.transform_id,
    "add-trailing-f64-const-drop-to-defined-functions",
  )
  match transformed.wasm_module.code_sec {
    Some(@lib.CodeSec(funcs)) =>
      match funcs[0] {
        @lib.Func(locals, @lib.Expr(instrs)) => {
          @debug.assert_eq(locals, @lib.Locals::new([]))
          @debug.assert_eq(instrs.length(), 3)
          @debug.assert_eq(instrs[0], @lib.Instruction::i32_const(7))
          @debug.assert_eq(
            instrs[1],
            @lib.Instruction::f64_const(@lib.F64(0.0)),
          )
          @debug.assert_eq(instrs[2], @lib.Instruction::drop())
        }
      }
    None => fail("expected transformed code section")
  }
  match assert_metamorphic_roundtrip_valid(transformed.wasm_module) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "metamorphic trailing i64 const drop transform preserves validation and binary roundtrip" {
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [@lib.ValType::i32()])),
  )
  let base = @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([func_type]))
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::new([]),
          @lib.Expr::new([@lib.Instruction::i32_const(7)]),
        ),
      ]),
    )
  let transformed = match
    metamorphic_apply_transform(base, AddTrailingI64ConstDropToDefinedFunctions) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  @debug.assert_eq(
    transformed.transform_id,
    "add-trailing-i64-const-drop-to-defined-functions",
  )
  match transformed.wasm_module.code_sec {
    Some(@lib.CodeSec(funcs)) =>
      match funcs[0] {
        @lib.Func(locals, @lib.Expr(instrs)) => {
          @debug.assert_eq(locals, @lib.Locals::new([]))
          @debug.assert_eq(instrs.length(), 3)
          @debug.assert_eq(instrs[0], @lib.Instruction::i32_const(7))
          @debug.assert_eq(instrs[1], @lib.Instruction::i64_const(@lib.I64(0L)))
          @debug.assert_eq(instrs[2], @lib.Instruction::drop())
        }
      }
    None => fail("expected transformed code section")
  }
  match assert_metamorphic_roundtrip_valid(transformed.wasm_module) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "metamorphic trailing ref null drop transform preserves validation and binary roundtrip" {
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [@lib.ValType::i32()])),
  )
  let base = @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([func_type]))
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::new([]),
          @lib.Expr::new([@lib.Instruction::i32_const(7)]),
        ),
      ]),
    )
  let transformed = match
    metamorphic_apply_transform(base, AddTrailingRefNullDropToDefinedFunctions) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  @debug.assert_eq(
    transformed.transform_id,
    "add-trailing-ref-null-drop-to-defined-functions",
  )
  match transformed.wasm_module.code_sec {
    Some(@lib.CodeSec(funcs)) =>
      match funcs[0] {
        @lib.Func(locals, @lib.Expr(instrs)) => {
          @debug.assert_eq(locals, @lib.Locals::new([]))
          @debug.assert_eq(instrs.length(), 3)
          @debug.assert_eq(instrs[0], @lib.Instruction::i32_const(7))
          @debug.assert_eq(
            instrs[1],
            @lib.Instruction::ref_null(
              @lib.HeapType::abs(@lib.AbsHeapType::extern_()),
            ),
          )
          @debug.assert_eq(instrs[2], @lib.Instruction::drop())
        }
      }
    None => fail("expected transformed code section")
  }
  match assert_metamorphic_roundtrip_valid(transformed.wasm_module) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "metamorphic trailing ref null is-null drop transform preserves validation and binary roundtrip" {
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [@lib.ValType::i32()])),
  )
  let base = @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([func_type]))
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::new([]),
          @lib.Expr::new([@lib.Instruction::i32_const(7)]),
        ),
      ]),
    )
  let transformed = match
    metamorphic_apply_transform(
      base,
      AddTrailingRefNullIsNullDropToDefinedFunctions,
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  @debug.assert_eq(
    transformed.transform_id,
    "add-trailing-ref-null-is-null-drop-to-defined-functions",
  )
  match transformed.wasm_module.code_sec {
    Some(@lib.CodeSec(funcs)) =>
      match funcs[0] {
        @lib.Func(locals, @lib.Expr(instrs)) => {
          @debug.assert_eq(locals, @lib.Locals::new([]))
          @debug.assert_eq(instrs.length(), 4)
          @debug.assert_eq(instrs[0], @lib.Instruction::i32_const(7))
          @debug.assert_eq(
            instrs[1],
            @lib.Instruction::ref_null(
              @lib.HeapType::abs(@lib.AbsHeapType::extern_()),
            ),
          )
          @debug.assert_eq(instrs[2], @lib.Instruction::ref_is_null())
          @debug.assert_eq(instrs[3], @lib.Instruction::drop())
        }
      }
    None => fail("expected transformed code section")
  }
  match assert_metamorphic_roundtrip_valid(transformed.wasm_module) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "metamorphic unused v128 locals transform preserves validation and binary roundtrip" {
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [])),
  )
  let base = @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([func_type]))
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([@lib.ValType::i32()]),
          @lib.Expr::new([]),
        ),
      ]),
    )
  let transformed = match
    metamorphic_apply_transform(base, AddUnusedV128LocalToDefinedFunctions) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  @debug.assert_eq(
    transformed.transform_id,
    "add-unused-v128-local-to-defined-functions",
  )
  match transformed.wasm_module.code_sec {
    Some(@lib.CodeSec(funcs)) =>
      match funcs[0] {
        @lib.Func(locals, @lib.Expr(instrs)) => {
          @debug.assert_eq(
            locals,
            @lib.Locals::from_types([@lib.ValType::i32(), @lib.ValType::v128()]),
          )
          @debug.assert_eq(instrs.length(), 0)
        }
      }
    None => fail("expected transformed code section")
  }
  match assert_metamorphic_roundtrip_valid(transformed.wasm_module) {
    Ok(_) => ()
    Err(msg) => fail(msg)
  }
}

///|
test "metamorphic smoke applies deterministic transform to GenValid source" {
  let stats = match run_validate_valid_metamorphic_fuzz("smoke", 0x1036UL) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  @debug.assert_eq(stats.profile, "smoke")
  @debug.assert_eq(stats.generated, 1)
  @debug.assert_eq(stats.transformed, 410)
  @debug.assert_eq(stats.validated, 410)
  assert_true(
    stats.transform_ids.contains(
      "add-leading-block-wrapped-i32-const-drop-to-defined-functions",
    ),
  )
  assert_true(
    stats.transform_ids.contains(
      "add-trailing-block-wrapped-i32-const-drop-to-defined-functions",
    ),
  )
  assert_true(
    stats.transform_ids.contains(
      "add-leading-loop-wrapped-i32-const-drop-to-defined-functions",
    ),
  )
  assert_true(
    stats.transform_ids.contains(
      "add-trailing-loop-wrapped-i32-const-drop-to-defined-functions",
    ),
  )
  assert_true(stats.transform_ids.contains("add-non-name-custom-section"))
  assert_true(
    stats.transform_ids.contains("add-leading-non-name-custom-section"),
  )
  assert_true(stats.transform_ids.contains("add-custom-section-stress"))
  assert_true(stats.transform_ids.contains("reshape-passive-element-segments"))
  assert_true(
    stats.transform_ids.contains("add-passive-data-segment-shape-stress"),
  )
  assert_true(
    stats.transform_ids.contains(
      "add-leading-memory-size-drop-to-defined-functions",
    ),
  )
  assert_true(
    stats.transform_ids.contains(
      "add-leading-table-size-drop-to-defined-functions",
    ),
  )
  assert_true(
    stats.transform_ids.contains(
      "add-trailing-table-size-drop-to-defined-functions",
    ),
  )
  assert_true(
    stats.transform_ids.contains(
      "add-trailing-memory-size-drop-to-defined-functions",
    ),
  )
  assert_true(
    stats.transform_ids.contains(
      "add-leading-ref-null-is-null-drop-to-defined-functions",
    ),
  )
  assert_true(
    stats.transform_ids.contains(
      "add-leading-nullable-ref-test-drop-to-defined-functions",
    ),
  )
  assert_true(
    stats.transform_ids.contains(
      "add-trailing-nullable-ref-cast-drop-to-defined-functions",
    ),
  )
  assert_true(
    stats.transform_ids.contains(
      "add-leading-any-convert-extern-drop-to-defined-functions",
    ),
  )
  assert_true(
    stats.transform_ids.contains(
      "add-trailing-extern-convert-any-drop-to-defined-functions",
    ),
  )
  assert_true(
    stats.transform_ids.contains(
      "add-leading-ref-i31-get-s-drop-to-defined-functions",
    ),
  )
  assert_true(
    stats.transform_ids.contains("add-leading-ref-eq-drop-to-defined-functions"),
  )
  assert_true(
    stats.transform_ids.contains(
      "add-leading-ref-eq-i31-drop-to-defined-functions",
    ),
  )
  assert_true(
    stats.transform_ids.contains(
      "add-trailing-ref-eq-drop-to-defined-functions",
    ),
  )
  assert_true(
    stats.transform_ids.contains(
      "add-trailing-ref-null-is-null-drop-to-defined-functions",
    ),
  )
  assert_true(
    stats.transform_ids.contains(
      "add-leading-i8x16-splat-drop-to-defined-functions",
    ),
  )
  assert_true(
    stats.transform_ids.contains(
      "add-leading-i8x16-shl-drop-to-defined-functions",
    ),
  )
  assert_true(
    stats.transform_ids.contains(
      "add-leading-i8x16-extract-lane-s-drop-to-defined-functions",
    ),
  )
  assert_true(
    stats.transform_ids.contains(
      "add-leading-i8x16-replace-lane-drop-to-defined-functions",
    ),
  )
  assert_true(
    stats.transform_ids.contains(
      "add-trailing-i64x2-shr-u-drop-to-defined-functions",
    ),
  )
  assert_true(
    stats.transform_ids.contains(
      "add-leading-i32-clz-drop-to-defined-functions",
    ),
  )
  assert_true(
    stats.transform_ids.contains(
      "add-trailing-i64-popcnt-drop-to-defined-functions",
    ),
  )
  assert_true(
    stats.transform_ids.contains(
      "add-leading-i32-extend8-s-drop-to-defined-functions",
    ),
  )
  assert_true(
    stats.transform_ids.contains(
      "add-trailing-i64-extend32-s-drop-to-defined-functions",
    ),
  )
  assert_true(
    stats.transform_ids.contains(
      "add-leading-f32-convert-i32-s-drop-to-defined-functions",
    ),
  )
  assert_true(
    stats.transform_ids.contains(
      "add-trailing-f32-convert-i64-u-drop-to-defined-functions",
    ),
  )
  assert_true(
    stats.transform_ids.contains(
      "add-leading-f64-convert-i32-s-drop-to-defined-functions",
    ),
  )
  assert_true(
    stats.transform_ids.contains(
      "add-trailing-f64-convert-i32-u-drop-to-defined-functions",
    ),
  )
  assert_true(
    stats.transform_ids.contains(
      "add-leading-f64-convert-i64-s-drop-to-defined-functions",
    ),
  )
  assert_true(
    stats.transform_ids.contains(
      "add-trailing-f64-convert-i64-u-drop-to-defined-functions",
    ),
  )
  assert_true(
    stats.transform_ids.contains(
      "add-leading-i32-trunc-sat-f32-s-drop-to-defined-functions",
    ),
  )
  assert_true(
    stats.transform_ids.contains(
      "add-trailing-i64-trunc-sat-f64-u-drop-to-defined-functions",
    ),
  )
  assert_true(
    stats.transform_ids.contains(
      "add-leading-f32-demote-f64-drop-to-defined-functions",
    ),
  )
  assert_true(
    stats.transform_ids.contains(
      "add-trailing-f64-promote-f32-drop-to-defined-functions",
    ),
  )
  assert_true(
    stats.transform_ids.contains(
      "add-leading-i32-wrap-i64-drop-to-defined-functions",
    ),
  )
  assert_true(
    stats.transform_ids.contains(
      "add-trailing-i32-wrap-i64-drop-to-defined-functions",
    ),
  )
  assert_true(
    stats.transform_ids.contains(
      "add-leading-i64-extend-i32-s-drop-to-defined-functions",
    ),
  )
  assert_true(
    stats.transform_ids.contains(
      "add-trailing-i64-extend-i32-u-drop-to-defined-functions",
    ),
  )
  assert_true(stats.transform_ids.contains("add-module-name-section"))
  assert_true(stats.transform_ids.contains("add-unused-passive-data-segment"))
  assert_true(stats.transform_ids.contains("add-unused-immutable-i32-global"))
  assert_true(stats.transform_ids.contains("add-unused-empty-function"))
  assert_true(stats.transform_ids.contains("add-unused-empty-function-type"))
  assert_true(
    stats.transform_ids.contains("add-duplicate-equivalent-function-type"),
  )
  assert_true(
    stats.transform_ids.contains("add-imported-function-export-aliases"),
  )
  assert_true(
    stats.transform_ids.contains("add-defined-function-export-aliases"),
  )
  assert_true(
    stats.transform_ids.contains(
      "add-duplicate-equivalent-empty-function-types",
    ),
  )
  assert_true(
    stats.transform_ids.contains(
      "add-duplicate-equivalent-scalar-function-types",
    ),
  )
  assert_true(stats.transform_ids.contains("add-unused-funcref-table"))
  assert_true(
    stats.transform_ids.contains("add-unused-passive-funcref-element-segment"),
  )
  assert_true(stats.transform_ids.contains("add-function-names-section"))
  assert_true(stats.transform_ids.contains("add-local-names-section"))
  assert_true(stats.transform_ids.contains("add-label-names-section"))
  assert_true(stats.transform_ids.contains("add-type-names-section"))
  assert_true(stats.transform_ids.contains("add-global-names-section"))
  assert_true(stats.transform_ids.contains("add-table-names-section"))
  assert_true(stats.transform_ids.contains("add-memory-names-section"))
  assert_true(stats.transform_ids.contains("add-data-names-section"))
  assert_true(stats.transform_ids.contains("add-elem-names-section"))
  assert_true(stats.transform_ids.contains("add-tag-names-section"))
  assert_true(stats.transform_ids.contains("add-field-names-section"))
  assert_true(
    stats.transform_ids.contains(
      "wrap-defined-function-bodies-in-identity-block",
    ),
  )
  assert_true(stats.transform_ids.contains("split-merge-local-declarations"))
  assert_true(
    stats.transform_ids.contains("add-unused-i32-local-to-defined-functions"),
  )
  assert_true(
    stats.transform_ids.contains(
      "add-unused-numeric-locals-to-defined-functions",
    ),
  )
  assert_true(
    stats.transform_ids.contains(
      "add-unused-reference-locals-to-defined-functions",
    ),
  )
  assert_true(
    stats.transform_ids.contains("add-unused-v128-local-to-defined-functions"),
  )
  assert_true(
    stats.transform_ids.contains(
      "add-leading-v128-const-drop-to-defined-functions",
    ),
  )
  assert_true(
    stats.transform_ids.contains(
      "add-trailing-v128-const-drop-to-defined-functions",
    ),
  )
  assert_true(
    stats.transform_ids.contains(
      "add-leading-v128-not-drop-to-defined-functions",
    ),
  )
  assert_true(
    stats.transform_ids.contains(
      "add-trailing-i64x2-bitmask-drop-to-defined-functions",
    ),
  )
  assert_true(
    stats.transform_ids.contains(
      "add-unused-gc-reference-locals-to-defined-functions",
    ),
  )
  assert_true(
    stats.transform_ids.contains(
      "add-leading-ref-null-drop-to-defined-functions",
    ),
  )
  assert_true(
    stats.transform_ids.contains(
      "add-trailing-ref-null-drop-to-defined-functions",
    ),
  )
  assert_true(
    stats.transform_ids.contains(
      "add-leading-i64-const-drop-to-defined-functions",
    ),
  )
  assert_true(
    stats.transform_ids.contains(
      "add-trailing-i64-const-drop-to-defined-functions",
    ),
  )
  assert_true(
    stats.transform_ids.contains(
      "add-leading-f32-const-drop-to-defined-functions",
    ),
  )
  assert_true(
    stats.transform_ids.contains(
      "add-trailing-f32-const-drop-to-defined-functions",
    ),
  )
  assert_true(
    stats.transform_ids.contains(
      "add-leading-f64-const-drop-to-defined-functions",
    ),
  )
  assert_true(
    stats.transform_ids.contains(
      "add-trailing-f64-const-drop-to-defined-functions",
    ),
  )
  assert_true(
    stats.transform_ids.contains(
      "add-leading-i32-eqz-drop-to-defined-functions",
    ),
  )
  assert_true(
    stats.transform_ids.contains(
      "add-trailing-i32-eqz-drop-to-defined-functions",
    ),
  )
  assert_true(
    stats.transform_ids.contains(
      "add-leading-i64-eqz-drop-to-defined-functions",
    ),
  )
  assert_true(
    stats.transform_ids.contains(
      "add-trailing-i64-eqz-drop-to-defined-functions",
    ),
  )
  assert_true(
    stats.transform_ids.contains(
      "add-leading-f32-abs-drop-to-defined-functions",
    ),
  )
  assert_true(
    stats.transform_ids.contains(
      "add-trailing-f32-abs-drop-to-defined-functions",
    ),
  )
  assert_true(
    stats.transform_ids.contains(
      "add-leading-f64-abs-drop-to-defined-functions",
    ),
  )
  assert_true(
    stats.transform_ids.contains(
      "add-trailing-f64-abs-drop-to-defined-functions",
    ),
  )
  assert_true(
    stats.transform_ids.contains(
      "add-leading-f32-trunc-drop-to-defined-functions",
    ),
  )
  assert_true(
    stats.transform_ids.contains(
      "add-trailing-f32-nearest-drop-to-defined-functions",
    ),
  )
  assert_true(
    stats.transform_ids.contains(
      "add-leading-f64-trunc-drop-to-defined-functions",
    ),
  )
  assert_true(
    stats.transform_ids.contains(
      "add-trailing-f64-nearest-drop-to-defined-functions",
    ),
  )
  assert_true(
    stats.transform_ids.contains(
      "add-leading-f32-min-drop-to-defined-functions",
    ),
  )
  assert_true(
    stats.transform_ids.contains(
      "add-trailing-f32-min-drop-to-defined-functions",
    ),
  )
  assert_true(
    stats.transform_ids.contains(
      "add-leading-f32-max-drop-to-defined-functions",
    ),
  )
  assert_true(
    stats.transform_ids.contains(
      "add-trailing-f32-max-drop-to-defined-functions",
    ),
  )
  assert_true(
    stats.transform_ids.contains(
      "add-leading-f64-min-drop-to-defined-functions",
    ),
  )
  assert_true(
    stats.transform_ids.contains(
      "add-trailing-f64-min-drop-to-defined-functions",
    ),
  )
  assert_true(
    stats.transform_ids.contains(
      "add-leading-f64-max-drop-to-defined-functions",
    ),
  )
  assert_true(
    stats.transform_ids.contains(
      "add-trailing-f64-max-drop-to-defined-functions",
    ),
  )
  assert_true(
    stats.transform_ids.contains(
      "add-leading-f32-copysign-drop-to-defined-functions",
    ),
  )
  assert_true(
    stats.transform_ids.contains(
      "add-trailing-f32-copysign-drop-to-defined-functions",
    ),
  )
  assert_true(
    stats.transform_ids.contains(
      "add-leading-f64-copysign-drop-to-defined-functions",
    ),
  )
  assert_true(
    stats.transform_ids.contains(
      "add-trailing-f64-copysign-drop-to-defined-functions",
    ),
  )
  assert_true(
    stats.transform_ids.contains("add-leading-f32-eq-drop-to-defined-functions"),
  )
  assert_true(
    stats.transform_ids.contains(
      "add-trailing-f32-eq-drop-to-defined-functions",
    ),
  )
  assert_true(
    stats.transform_ids.contains("add-leading-f32-ne-drop-to-defined-functions"),
  )
  assert_true(
    stats.transform_ids.contains(
      "add-trailing-f32-ne-drop-to-defined-functions",
    ),
  )
  assert_true(
    stats.transform_ids.contains("add-leading-f64-eq-drop-to-defined-functions"),
  )
  assert_true(
    stats.transform_ids.contains(
      "add-trailing-f64-eq-drop-to-defined-functions",
    ),
  )
  assert_true(
    stats.transform_ids.contains("add-leading-f64-ne-drop-to-defined-functions"),
  )
  assert_true(
    stats.transform_ids.contains(
      "add-trailing-f64-ne-drop-to-defined-functions",
    ),
  )
  assert_true(
    stats.transform_ids.contains(
      "add-leading-i32-lt-s-drop-to-defined-functions",
    ),
  )
  assert_true(
    stats.transform_ids.contains(
      "add-trailing-i64-gt-s-drop-to-defined-functions",
    ),
  )
  assert_true(
    stats.transform_ids.contains("add-leading-false-if-to-defined-functions"),
  )
  assert_true(
    stats.transform_ids.contains("add-trailing-false-if-to-defined-functions"),
  )
  assert_true(
    stats.transform_ids.contains("add-leading-nop-to-defined-functions"),
  )
  assert_true(
    stats.transform_ids.contains("add-trailing-nop-to-defined-functions"),
  )
  assert_true(
    stats.transform_ids.contains(
      "add-leading-i32-const-drop-to-defined-functions",
    ),
  )
  assert_true(
    stats.transform_ids.contains(
      "add-trailing-i32-const-drop-to-defined-functions",
    ),
  )
  assert_true(
    stats.transform_ids.contains(
      "add-trailing-empty-void-block-to-defined-functions",
    ),
  )
  assert_true(
    stats.transform_ids.contains(
      "add-leading-empty-void-block-to-defined-functions",
    ),
  )
  assert_true(
    stats.transform_ids.contains(
      "add-leading-empty-void-loop-to-defined-functions",
    ),
  )
  assert_true(
    stats.transform_ids.contains(
      "add-trailing-empty-void-loop-to-defined-functions",
    ),
  )
  assert_true(stats.transform_ids.contains("add-export-aliases"))
  assert_true(stats.transform_ids.contains("add-prefixed-export-aliases"))
  assert_true(stats.transform_ids.contains("add-suffixed-export-aliases"))
  assert_true(stats.transform_ids.contains("reverse-custom-sections"))
}
