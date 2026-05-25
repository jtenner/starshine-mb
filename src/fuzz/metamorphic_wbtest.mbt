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
  @debug.assert_eq(stats.transformed, 55)
  @debug.assert_eq(stats.validated, 55)
  assert_true(stats.transform_ids.contains("add-non-name-custom-section"))
  assert_true(
    stats.transform_ids.contains("add-leading-non-name-custom-section"),
  )
  assert_true(stats.transform_ids.contains("add-custom-section-stress"))
  assert_true(stats.transform_ids.contains("add-module-name-section"))
  assert_true(stats.transform_ids.contains("add-unused-passive-data-segment"))
  assert_true(stats.transform_ids.contains("add-unused-immutable-i32-global"))
  assert_true(stats.transform_ids.contains("add-unused-empty-function"))
  assert_true(stats.transform_ids.contains("add-unused-empty-function-type"))
  assert_true(
    stats.transform_ids.contains("add-duplicate-equivalent-function-type"),
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
