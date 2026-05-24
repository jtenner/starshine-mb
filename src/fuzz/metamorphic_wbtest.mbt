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
test "metamorphic smoke applies deterministic transform to GenValid source" {
  let stats = match run_validate_valid_metamorphic_fuzz("smoke", 0x1036UL) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  @debug.assert_eq(stats.profile, "smoke")
  @debug.assert_eq(stats.generated, 1)
  @debug.assert_eq(stats.transformed, 8)
  @debug.assert_eq(stats.validated, 8)
  assert_true(stats.transform_ids.contains("add-non-name-custom-section"))
  assert_true(
    stats.transform_ids.contains("add-leading-non-name-custom-section"),
  )
  assert_true(stats.transform_ids.contains("add-module-name-section"))
  assert_true(stats.transform_ids.contains("add-unused-passive-data-segment"))
  assert_true(stats.transform_ids.contains("add-unused-immutable-i32-global"))
  assert_true(stats.transform_ids.contains("add-unused-empty-function"))
  assert_true(stats.transform_ids.contains("add-unused-empty-function-type"))
  assert_true(stats.transform_ids.contains("add-unused-funcref-table"))
}
