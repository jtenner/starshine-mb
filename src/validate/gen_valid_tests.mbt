///|
test "gen_valid_module_result reports success diagnostics" {
  let config = GenValidConfig::natural_default()
  let generated = match
    gen_valid_module_result(@splitmix.new(seed=0x5eedUL), config) {
    Ok(v) => v
    Err(failure) =>
      fail(
        "expected gen-valid success, got \{failure.validation_error_message}",
      )
  }
  assert_true(generated.attempts >= 1)
  @debug.assert_eq(generated.config_label, "natural")
  @debug.assert_eq(generated.config, config)
  @debug.assert_eq(generated.facts.mode, Natural)
  match validate_module(generated.wasm_module) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected generated module to validate, got \{validation_error_message(err)}",
      )
  }
}

///|
test "gen_valid named profiles expose stable labels and compatibility aliases" {
  @debug.assert_eq(
    gen_valid_profile_name(CoverageForcedAllFeaturesProfile),
    "coverage-forced-all-features",
  )
  @debug.assert_eq(
    gen_valid_profile_name(TopologyHeavyProfile),
    "topology-heavy",
  )
  @debug.assert_eq(
    GenValidConfig::for_profile(NaturalSmallProfile).mode,
    Natural,
  )
  @debug.assert_eq(
    GenValidConfig::for_profile(CoverageForcedPortableProfile),
    GenValidConfig::portable_coverage_forced_default(),
  )
  @debug.assert_eq(
    GenValidConfig::for_profile(BinaryenOraclePortableProfile),
    GenValidConfig::binaryen_oracle_coverage_forced_default(),
  )
  @debug.assert_eq(
    GenValidConfig::for_profile(PassFuzzStressProfile),
    GenValidConfig::binaryen_oracle_coverage_forced_default(),
  )
  @debug.assert_eq(
    gen_valid_config_label(GenValidConfig::for_profile(ValidatorStressProfile)),
    "validator-stress",
  )
  let looked_up = match gen_valid_profile_by_name("Coverage Forced Portable") {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  @debug.assert_eq(looked_up, CoverageForcedPortableProfile)
  match GenValidConfig::profile("not-a-profile") {
    Ok(_) => fail("expected unknown gen-valid profile to fail")
    Err(msg) => {
      assert_true(msg.contains("unknown gen-valid profile"))
      assert_true(msg.contains("natural-small"))
      assert_true(msg.contains("binaryen-oracle-portable"))
      assert_true(msg.contains("topology-heavy"))
    }
  }
}

///|
fn gen_valid_test_total_func_count(mod_ : Module) -> Int {
  let import_funcs = match mod_.import_sec {
    Some(ImportSec(imports)) => {
      let mut count = 0
      for import_ in imports {
        let Import(_, _, extern_type) = import_
        match extern_type {
          FuncExternType(_) => count += 1
          _ => ()
        }
      }
      count
    }
    None => 0
  }
  let defined_funcs = match mod_.func_sec {
    Some(FuncSec(funcs)) => funcs.length()
    None => 0
  }
  import_funcs + defined_funcs
}

///|
fn gen_valid_test_import_module_count(mod_ : Module) -> Int {
  let modules : Array[Name] = []
  match mod_.import_sec {
    Some(ImportSec(imports)) =>
      for import_ in imports {
        let Import(module_name, _, _) = import_
        let mut seen = false
        for existing in modules {
          if existing == module_name {
            seen = true
          }
        }
        if !seen {
          modules.push(module_name)
        }
      }
    None => ()
  }
  modules.length()
}

///|
fn gen_valid_test_has_repeated_export_idx(mod_ : Module) -> Bool {
  match mod_.export_sec {
    Some(ExportSec(exports)) => {
      let seen : Array[ExternIdx] = []
      for export_ in exports {
        let Export(_, idx) = export_
        for prior in seen {
          if prior == idx {
            return true
          }
        }
        seen.push(idx)
      }
      false
    }
    None => false
  }
}

///|
fn gen_valid_test_has_export_named(mod_ : Module, name : String) -> Bool {
  match mod_.export_sec {
    Some(ExportSec(exports)) => {
      for export_ in exports {
        let Export(export_name, _) = export_
        if export_name == Name::new(name) {
          return true
        }
      }
      false
    }
    None => false
  }
}

///|
fn gen_valid_test_has_any_export(mod_ : Module) -> Bool {
  match mod_.export_sec {
    Some(ExportSec(exports)) => !exports.is_empty()
    None => false
  }
}

///|
fn gen_valid_test_has_nonzero_resource_export(mod_ : Module) -> Bool {
  match mod_.export_sec {
    Some(ExportSec(exports)) => {
      for export_ in exports {
        let Export(_, idx) = export_
        match idx {
          TableExternIdx(TableIdx(table_idx)) if table_idx.reinterpret_as_int() >
            0 => return true
          MemExternIdx(MemIdx(mem_idx)) if mem_idx.reinterpret_as_int() > 0 =>
            return true
          GlobalExternIdx(GlobalIdx(global_idx)) if global_idx.reinterpret_as_int() >
            0 => return true
          TagExternIdx(TagIdx(tag_idx)) if tag_idx.reinterpret_as_int() > 0 =>
            return true
          _ => ()
        }
      }
      false
    }
    None => false
  }
}

///|
fn gen_valid_test_has_nonzero_active_elem(mod_ : Module) -> Bool {
  match mod_.elem_sec {
    Some(ElemSec(elems)) => {
      for elem in elems {
        let Elem(mode, _) = elem
        match mode {
          Active(TableIdx(table_idx), _) if table_idx.reinterpret_as_int() > 0 =>
            return true
          _ => ()
        }
      }
      false
    }
    None => false
  }
}

///|
fn gen_valid_test_has_nonzero_active_data(mod_ : Module) -> Bool {
  match mod_.data_sec {
    Some(DataSec(datas)) => {
      for data in datas {
        let Data(mode, _) = data
        match mode {
          Active(MemIdx(mem_idx), _) if mem_idx.reinterpret_as_int() > 0 =>
            return true
          _ => ()
        }
      }
      false
    }
    None => false
  }
}

///|
fn gen_valid_test_non_name_custom_count(mod_ : Module) -> Int {
  let mut count = 0
  for custom in mod_.custom_secs {
    let CustomSec(name, _) = custom
    if name != Name::new("name") {
      count += 1
    }
  }
  count
}

///|
test "topology-heavy profile emits high-index import export topology" {
  let config = GenValidConfig::for_profile(TopologyHeavyProfile)
  assert_true(config.max_defined_funcs >= 16)
  assert_true(config.max_imports >= 12)
  let generated = match
    gen_valid_module_result(@splitmix.new(seed=0xf71003UL), config) {
    Ok(v) => v
    Err(failure) => fail(failure.validation_error_message)
  }
  match validate_module(generated.wasm_module) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected topology-heavy generated module to validate, got \{validation_error_message(err)}",
      )
  }
  assert_true(
    gen_valid_test_total_func_count(generated.wasm_module) >= 10,
    msg="topology-heavy profile should exercise high function indices",
  )
  assert_true(
    gen_valid_test_import_module_count(generated.wasm_module) >= 2,
    msg="topology-heavy profile should use multiple import module names",
  )
  assert_true(
    gen_valid_test_has_repeated_export_idx(generated.wasm_module),
    msg="topology-heavy profile should export the same item under distinct names",
  )
  assert_true(
    gen_valid_test_has_nonzero_resource_export(generated.wasm_module),
    msg="topology-heavy profile should export nonzero table/memory/global/tag indices",
  )
  assert_true(
    gen_valid_test_has_nonzero_active_elem(generated.wasm_module),
    msg="topology-heavy profile should place an active element segment on a nonzero table index",
  )
  assert_true(
    gen_valid_test_has_nonzero_active_data(generated.wasm_module),
    msg="topology-heavy profile should place an active data segment on a nonzero memory index",
  )
  assert_true(
    gen_valid_test_non_name_custom_count(generated.wasm_module) >= 2,
    msg="topology-heavy profile should emit multiple non-name custom sections in the binary-supported leading custom section area",
  )
  assert_true(generated.facts.has_import_export_topology)
  assert_true(generated.facts.has_imports_start_exports)
}

///|
test "topology-heavy profile emits explicit no-main and no-export variants" {
  let config = GenValidConfig::for_profile(TopologyHeavyProfile)
  let mut saw_no_main_export = false
  let mut saw_no_export = false
  for offset in 0..<32 {
    let generated = match
      gen_valid_module_result(
        @splitmix.new(seed=0xf71030UL + offset.to_uint64()),
        config,
      ) {
      Ok(v) => v
      Err(failure) => fail(failure.validation_error_message)
    }
    match validate_module(generated.wasm_module) {
      Ok(_) => ()
      Err(err) =>
        fail(
          "expected topology-heavy generated module to validate, got \{validation_error_message(err)}",
        )
    }
    if gen_valid_test_has_any_export(generated.wasm_module) &&
      !gen_valid_test_has_export_named(generated.wasm_module, "main") {
      saw_no_main_export = true
    }
    if !gen_valid_test_has_any_export(generated.wasm_module) {
      saw_no_export = true
      assert_false(generated.facts.has_imports_start_exports)
    }
  }
  assert_true(
    saw_no_main_export,
    msg="topology-heavy profile should sometimes avoid the conventional main export name",
  )
  assert_true(
    saw_no_export,
    msg="topology-heavy profile should sometimes generate modules without exports",
  )
}

///|
test "gen_valid_module_with_config remains deterministic compatibility wrapper" {
  let config = GenValidConfig::binaryen_oracle_coverage_forced_default()
  let generated = match
    gen_valid_module_result(@splitmix.new(seed=0x51eedUL), config) {
    Ok(v) => v
    Err(failure) => fail(failure.validation_error_message)
  }
  let wrapped = gen_valid_module_with_config(
    @splitmix.new(seed=0x51eedUL),
    config,
  )
  @debug.assert_eq(wrapped, generated.wasm_module)
  @debug.assert_eq(generated.config_label, "binaryen-oracle-coverage-forced")
}

///|
fn gen_valid_test_count_local_set_instrs(instrs : Array[Instruction]) -> Int {
  let mut count = 0
  for instr in instrs {
    count += match instr {
      LocalSet(_) => 1
      Block(_, Expr(body)) | Loop(_, Expr(body)) | TryTable(_, _, Expr(body)) =>
        gen_valid_test_count_local_set_instrs(body)
      If(_, then_body, else_body) => {
        let else_count = match else_body {
          Some(body) => gen_valid_test_count_local_set_instrs(body)
          None => 0
        }
        gen_valid_test_count_local_set_instrs(then_body) + else_count
      }
      _ => 0
    }
  }
  count
}

///|
fn gen_valid_test_has_i64_const_local_set(instrs : Array[Instruction]) -> Bool {
  for i = 0; i + 1 < instrs.length(); i = i + 1 {
    match (instrs[i], instrs[i + 1]) {
      (I64Const(_), LocalSet(_)) => return true
      _ => ()
    }
  }
  for instr in instrs {
    match instr {
      Block(_, Expr(body)) | Loop(_, Expr(body)) | TryTable(_, _, Expr(body)) =>
        if gen_valid_test_has_i64_const_local_set(body) {
          return true
        }
      If(_, then_body, else_body) => {
        if gen_valid_test_has_i64_const_local_set(then_body) {
          return true
        }
        match else_body {
          Some(body) if gen_valid_test_has_i64_const_local_set(body) =>
            return true
          _ => ()
        }
      }
      _ => ()
    }
  }
  false
}

///|
fn gen_valid_test_has_i32_payload_br_value_block(
  instrs : Array[Instruction],
) -> Bool {
  for instr in instrs {
    match instr {
      Block(ValTypeBlockType(vt), Expr(body)) if vt == ValType::i32() => {
        for i = 0; i + 1 < body.length(); i = i + 1 {
          match (body[i], body[i + 1]) {
            (I32Const(_), Br(label)) if label == LabelIdx::new(0U) =>
              return true
            _ => ()
          }
        }
        if gen_valid_test_has_i32_payload_br_value_block(body) {
          return true
        }
      }
      Block(_, Expr(body)) | Loop(_, Expr(body)) | TryTable(_, _, Expr(body)) =>
        if gen_valid_test_has_i32_payload_br_value_block(body) {
          return true
        }
      If(_, then_body, else_body) => {
        if gen_valid_test_has_i32_payload_br_value_block(then_body) {
          return true
        }
        match else_body {
          Some(body) if gen_valid_test_has_i32_payload_br_value_block(body) =>
            return true
          _ => ()
        }
      }
      _ => ()
    }
  }
  false
}

///|
fn gen_valid_test_has_i32_payload_br_if_value_block(
  instrs : Array[Instruction],
) -> Bool {
  for instr in instrs {
    match instr {
      Block(ValTypeBlockType(vt), Expr(body)) if vt == ValType::i32() => {
        for i = 0; i + 2 < body.length(); i = i + 1 {
          match (body[i], body[i + 1], body[i + 2]) {
            (I32Const(_), I32Const(_), BrIf(label)) if label ==
              LabelIdx::new(0U) => return true
            _ => ()
          }
        }
        if gen_valid_test_has_i32_payload_br_if_value_block(body) {
          return true
        }
      }
      Block(_, Expr(body)) | Loop(_, Expr(body)) | TryTable(_, _, Expr(body)) =>
        if gen_valid_test_has_i32_payload_br_if_value_block(body) {
          return true
        }
      If(_, then_body, else_body) => {
        if gen_valid_test_has_i32_payload_br_if_value_block(then_body) {
          return true
        }
        match else_body {
          Some(body) if gen_valid_test_has_i32_payload_br_if_value_block(body) =>
            return true
          _ => ()
        }
      }
      _ => ()
    }
  }
  false
}

///|
fn gen_valid_test_has_i32_payload_br_table_value_block(
  instrs : Array[Instruction],
) -> Bool {
  for instr in instrs {
    match instr {
      Block(ValTypeBlockType(vt), Expr(body)) if vt == ValType::i32() => {
        for i = 0; i + 2 < body.length(); i = i + 1 {
          match (body[i], body[i + 1], body[i + 2]) {
            (I32Const(_), I32Const(_), BrTable(targets, default_label)) if default_label ==
              LabelIdx::new(0U) &&
              targets.length() > 0 &&
              targets[0] == LabelIdx::new(0U) => return true
            _ => ()
          }
        }
        if gen_valid_test_has_i32_payload_br_table_value_block(body) {
          return true
        }
      }
      Block(_, Expr(body)) | Loop(_, Expr(body)) | TryTable(_, _, Expr(body)) =>
        if gen_valid_test_has_i32_payload_br_table_value_block(body) {
          return true
        }
      If(_, then_body, else_body) => {
        if gen_valid_test_has_i32_payload_br_table_value_block(then_body) {
          return true
        }
        match else_body {
          Some(body) if gen_valid_test_has_i32_payload_br_table_value_block(
              body,
            ) => return true
          _ => ()
        }
      }
      _ => ()
    }
  }
  false
}

///|
fn gen_valid_test_has_i32_result_loop(instrs : Array[Instruction]) -> Bool {
  for instr in instrs {
    match instr {
      Loop(ValTypeBlockType(vt), Expr(body)) if vt == ValType::i32() => {
        for inner in body {
          match inner {
            I32Const(_) => return true
            _ => ()
          }
        }
        if gen_valid_test_has_i32_result_loop(body) {
          return true
        }
      }
      Block(_, Expr(body)) | Loop(_, Expr(body)) | TryTable(_, _, Expr(body)) =>
        if gen_valid_test_has_i32_result_loop(body) {
          return true
        }
      If(_, then_body, else_body) => {
        if gen_valid_test_has_i32_result_loop(then_body) {
          return true
        }
        match else_body {
          Some(body) if gen_valid_test_has_i32_result_loop(body) => return true
          _ => ()
        }
      }
      _ => ()
    }
  }
  false
}

///|
fn gen_valid_test_has_nested_return(instrs : Array[Instruction]) -> Bool {
  for instr in instrs {
    match instr {
      Block(_, Expr(body)) | Loop(_, Expr(body)) | TryTable(_, _, Expr(body)) => {
        for inner in body {
          match inner {
            Return => return true
            _ => ()
          }
        }
        if gen_valid_test_has_nested_return(body) {
          return true
        }
      }
      If(_, then_body, else_body) => {
        for inner in then_body {
          match inner {
            Return => return true
            _ => ()
          }
        }
        if gen_valid_test_has_nested_return(then_body) {
          return true
        }
        match else_body {
          Some(body) => {
            for inner in body {
              match inner {
                Return => return true
                _ => ()
              }
            }
            if gen_valid_test_has_nested_return(body) {
              return true
            }
          }
          None => ()
        }
      }
      _ => ()
    }
  }
  false
}

///|
fn gen_valid_test_module_local_set_count(mod_ : Module) -> Int {
  match mod_.code_sec {
    Some(CodeSec(funcs)) => {
      let mut count = 0
      for func in funcs {
        let Func(_, Expr(instrs)) = func
        count += gen_valid_test_count_local_set_instrs(instrs)
      }
      count
    }
    None => 0
  }
}

///|
fn gen_valid_test_module_has_i64_const_local_set(mod_ : Module) -> Bool {
  match mod_.code_sec {
    Some(CodeSec(funcs)) =>
      for func in funcs {
        let Func(_, Expr(instrs)) = func
        if gen_valid_test_has_i64_const_local_set(instrs) {
          return true
        }
      }
    None => ()
  }
  false
}

///|
fn gen_valid_test_func_type_results(
  mod_ : Module,
  type_idx : TypeIdx,
) -> Array[ValType]? {
  let wanted = match type_idx {
    TypeIdx(type_idx_u) | RecIdx(type_idx_u) => type_idx_u.reinterpret_as_int()
  }
  match mod_.type_sec {
    Some(TypeSec(types)) => {
      let mut cursor = 0
      for rec_type in types {
        match rec_type {
          SingleRecType(SubType(_, _, _, FuncCompType(_, results)))
          | SingleRecType(CompTypeSubType(_, FuncCompType(_, results))) =>
            if cursor == wanted {
              return Some(results)
            }
          GroupRecType(group) =>
            for subtype in group {
              match subtype {
                SubType(_, _, _, FuncCompType(_, results))
                | CompTypeSubType(_, FuncCompType(_, results)) =>
                  if cursor == wanted {
                    return Some(results)
                  }
                _ => ()
              }
              cursor += 1
            }
          _ => ()
        }
        match rec_type {
          SingleRecType(_) => cursor += 1
          GroupRecType(_) => ()
        }
      }
      None
    }
    None => None
  }
}

///|
fn gen_valid_test_has_multivalue_typeidx_block(
  mod_ : Module,
  instrs : Array[Instruction],
) -> Bool {
  for instr in instrs {
    match instr {
      Block(TypeIdxBlockType(type_idx), Expr(body)) => {
        match gen_valid_test_func_type_results(mod_, type_idx) {
          Some(results) if results.length() > 1 => return true
          _ => ()
        }
        if gen_valid_test_has_multivalue_typeidx_block(mod_, body) {
          return true
        }
      }
      Block(_, Expr(body)) | Loop(_, Expr(body)) | TryTable(_, _, Expr(body)) =>
        if gen_valid_test_has_multivalue_typeidx_block(mod_, body) {
          return true
        }
      If(_, then_body, else_body) => {
        if gen_valid_test_has_multivalue_typeidx_block(mod_, then_body) {
          return true
        }
        match else_body {
          Some(body) if gen_valid_test_has_multivalue_typeidx_block(mod_, body) =>
            return true
          _ => ()
        }
      }
      _ => ()
    }
  }
  false
}

///|
fn gen_valid_test_val_type_is_exact_ref(vt : ValType) -> Bool {
  match vt {
    RefTypeValType(rt) => rt.is_exact()
    _ => false
  }
}

///|
fn gen_valid_test_module_has_exact_ref_local(mod_ : Module) -> Bool {
  match mod_.code_sec {
    Some(CodeSec(funcs)) =>
      for func in funcs {
        let Func(locals, _) = func
        for vt in locals.iter() {
          if gen_valid_test_val_type_is_exact_ref(vt) {
            return true
          }
        }
      }
    None => ()
  }
  false
}

///|
fn gen_valid_test_has_exact_ref_local_flow_block(
  instrs : Array[Instruction],
) -> Bool {
  for instr in instrs {
    match instr {
      Block(ValTypeBlockType(vt), Expr(body)) if gen_valid_test_val_type_is_exact_ref(
          vt,
        ) => {
        let mut saw_set = false
        let mut saw_get = false
        for nested in body {
          match nested {
            LocalSet(_) => saw_set = true
            LocalGet(_) => saw_get = true
            _ => ()
          }
        }
        if saw_set && saw_get {
          return true
        }
        if gen_valid_test_has_exact_ref_local_flow_block(body) {
          return true
        }
      }
      Block(_, Expr(body)) | Loop(_, Expr(body)) | TryTable(_, _, Expr(body)) =>
        if gen_valid_test_has_exact_ref_local_flow_block(body) {
          return true
        }
      If(_, then_body, else_body) => {
        if gen_valid_test_has_exact_ref_local_flow_block(then_body) {
          return true
        }
        match else_body {
          Some(body) if gen_valid_test_has_exact_ref_local_flow_block(body) =>
            return true
          _ => ()
        }
      }
      _ => ()
    }
  }
  false
}

///|
fn gen_valid_test_module_has_exact_ref_local_flow_block(mod_ : Module) -> Bool {
  match mod_.code_sec {
    Some(CodeSec(funcs)) =>
      for func in funcs {
        let Func(_, Expr(instrs)) = func
        if gen_valid_test_has_exact_ref_local_flow_block(instrs) {
          return true
        }
      }
    None => ()
  }
  false
}

///|
fn gen_valid_test_has_mutual_struct_array_group(mod_ : Module) -> Bool {
  match mod_.type_sec {
    Some(TypeSec(types)) => {
      let mut cursor = 0
      for rec_type in types {
        match rec_type {
          GroupRecType(group) if group.length() >= 2 =>
            for i = 0; i < group.length(); i = i + 1 {
              for j = 0; j < group.length(); j = j + 1 {
                if i != j {
                  let struct_idx = TypeIdx::new(
                    (cursor + i).reinterpret_as_uint(),
                  )
                  let array_idx = TypeIdx::new(
                    (cursor + j).reinterpret_as_uint(),
                  )
                  let mut struct_refs_array = false
                  let mut array_refs_struct = false
                  match group[i] {
                    SubType(_, _, _, StructCompType(fields))
                    | CompTypeSubType(_, StructCompType(fields)) =>
                      for field in fields {
                        match field {
                          FieldType(
                            ValTypeStorageType(
                              RefTypeValType(
                                HeapTypeRefType(_, _, HeapType(target))
                              )
                            ),
                            _
                          ) if target == array_idx => struct_refs_array = true
                          _ => ()
                        }
                      }
                    _ => ()
                  }
                  match group[j] {
                    SubType(_, _, _, ArrayCompType(field))
                    | CompTypeSubType(_, ArrayCompType(field)) =>
                      match field {
                        FieldType(
                          ValTypeStorageType(
                            RefTypeValType(
                              HeapTypeRefType(_, _, HeapType(target))
                            )
                          ),
                          _
                        ) if target == struct_idx => array_refs_struct = true
                        _ => ()
                      }
                    _ => ()
                  }
                  if struct_refs_array && array_refs_struct {
                    return true
                  }
                }
              }
            }
          _ => ()
        }
        match rec_type {
          SingleRecType(_) => cursor += 1
          GroupRecType(group) => cursor += group.length()
        }
      }
      false
    }
    None => false
  }
}

///|
fn gen_valid_test_has_descriptor_final_open_matrix(mod_ : Module) -> Bool {
  match mod_.type_sec {
    Some(TypeSec(types)) => {
      let mut cursor = 0
      for rec_type in types {
        match rec_type {
          GroupRecType(group) if group.length() >= 4 => {
            let base_described = TypeIdx::new(cursor.reinterpret_as_uint())
            let base_descriptor = TypeIdx::new(
              (cursor + 1).reinterpret_as_uint(),
            )
            let leaf_described = TypeIdx::new(
              (cursor + 2).reinterpret_as_uint(),
            )
            let leaf_descriptor = TypeIdx::new(
              (cursor + 3).reinterpret_as_uint(),
            )
            match (group[0], group[1], group[2], group[3]) {
              (
                SubType(false, [], base_meta, StructCompType(_)),
                SubType(false, [], desc_meta, StructCompType(_)),
                SubType(true, leaf_supers, leaf_meta, StructCompType(_)),
                SubType(true, desc_supers, leaf_desc_meta, StructCompType(_)),
              ) =>
                if base_meta.descriptor == Some(base_descriptor) &&
                  desc_meta.describes == Some(base_described) &&
                  leaf_meta.descriptor == Some(leaf_descriptor) &&
                  leaf_desc_meta.describes == Some(leaf_described) &&
                  leaf_supers.length() == 1 &&
                  leaf_supers[0] == base_described &&
                  desc_supers.length() == 1 &&
                  desc_supers[0] == base_descriptor {
                  return true
                }
              _ => ()
            }
          }
          _ => ()
        }
        match rec_type {
          SingleRecType(_) => cursor += 1
          GroupRecType(group) => cursor += group.length()
        }
      }
      false
    }
    None => false
  }
}

///|
test "GC-heavy GenValid emits descriptor final-open subtype matrix" {
  let config = GenValidConfig::for_profile(GcHeavyProfile)
  let generated = match
    gen_valid_module_result(@splitmix.new(seed=0xf71006UL), config) {
    Ok(v) => v
    Err(failure) => fail(failure.validation_error_message)
  }
  match validate_module(generated.wasm_module) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected descriptor final-open matrix generated module to validate, got \{validation_error_message(err)}",
      )
  }
  assert_true(generated.facts.has_subtyping_topology)
  assert_true(
    gen_valid_test_has_descriptor_final_open_matrix(generated.wasm_module),
    msg="GC-heavy generation should include open descriptor/describes supertypes with final descriptor/describes subtypes",
  )
}

///|
test "coverage-forced GenValid emits mutually recursive struct and array topology" {
  let config = GenValidConfig::for_profile(GcHeavyProfile)
  let generated = match
    gen_valid_module_result(@splitmix.new(seed=0xf71005UL), config) {
    Ok(v) => v
    Err(failure) => fail(failure.validation_error_message)
  }
  match validate_module(generated.wasm_module) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected mutual struct/array topology generated module to validate, got \{validation_error_message(err)}",
      )
  }
  assert_true(generated.facts.has_subtyping_topology)
  assert_true(generated.facts.has_rich_gc_field_plans)
  assert_true(
    gen_valid_test_has_mutual_struct_array_group(generated.wasm_module),
    msg="GC-heavy generation should include a rec group where a struct field references an array sibling and the array element references the struct sibling",
  )
}

///|
test "natural GenValid organically emits recursive GC topology families" {
  let config = GenValidConfig::natural_default()
  let mut saw_subtyping_topology = false
  let mut saw_mutual_struct_array = false
  let mut saw_descriptor_matrix = false
  for offset in 0..<128 {
    let generated = match
      gen_valid_module_result(
        @splitmix.new(seed=0xf71040UL + offset.to_uint64()),
        config,
      ) {
      Ok(v) => v
      Err(failure) => fail(failure.validation_error_message)
    }
    match validate_module(generated.wasm_module) {
      Ok(_) => ()
      Err(err) =>
        fail(
          "expected natural recursive-topology generated module to validate, got \{validation_error_message(err)}",
        )
    }
    saw_subtyping_topology = saw_subtyping_topology ||
      generated.facts.has_subtyping_topology
    saw_mutual_struct_array = saw_mutual_struct_array ||
      gen_valid_test_has_mutual_struct_array_group(generated.wasm_module)
    saw_descriptor_matrix = saw_descriptor_matrix ||
      gen_valid_test_has_descriptor_final_open_matrix(generated.wasm_module)
  }
  assert_true(
    saw_subtyping_topology,
    msg="natural generation should organically produce subtype topology over a bounded seed lane",
  )
  assert_true(
    saw_mutual_struct_array,
    msg="natural generation should organically produce mutually recursive struct/array rec groups, not only coverage-forced preludes",
  )
  assert_true(
    saw_descriptor_matrix,
    msg="natural generation should organically produce descriptor/describes subtype matrices, not only coverage-forced preludes",
  )
}

///|
test "coverage-forced GenValid routes exact refs through locals and block results" {
  let config = GenValidConfig::coverage_forced_default()
  let generated = match
    gen_valid_module_result(@splitmix.new(seed=0xf71004UL), config) {
    Ok(v) => v
    Err(failure) => fail(failure.validation_error_message)
  }
  match validate_module(generated.wasm_module) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected exact-ref coverage-forced generated module to validate, got \{validation_error_message(err)}",
      )
  }
  assert_true(generated.facts.uses_ref_types)
  assert_true(generated.facts.has_gc_constructors)
  assert_true(
    gen_valid_test_module_has_exact_ref_local(generated.wasm_module),
    msg="coverage-forced GC topology should declare at least one exact-reference local",
  )
  assert_true(
    gen_valid_test_module_has_exact_ref_local_flow_block(generated.wasm_module),
    msg="coverage-forced GC topology should route an exact reference through local.set/local.get inside an exact block result",
  )
}

///|
test "control-heavy profile uses typed GenValid body generator slice" {
  let config = GenValidConfig::for_profile(ControlHeavyProfile)
  assert_true(config.features.allow_typed_body_generator)
  let generated = match
    gen_valid_module_result(@splitmix.new(seed=0x71002UL), config) {
    Ok(v) => v
    Err(failure) => fail(failure.validation_error_message)
  }
  match validate_module(generated.wasm_module) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected typed-body generated module to validate, got \{validation_error_message(err)}",
      )
  }
  assert_true(generated.facts.has_branch_heavy_control)
  assert_true(generated.facts.has_local_tee)
  assert_true(generated.facts.exact_opcode_counts.local_tee > 0)
  assert_true(
    gen_valid_test_module_local_set_count(generated.wasm_module) > 0,
    msg="typed body generator should emit stack-planned local.set coverage",
  )
  assert_true(
    gen_valid_test_module_has_i64_const_local_set(generated.wasm_module),
    msg="typed body generator should widen beyond the original i32-only local slice",
  )
  match generated.wasm_module.code_sec {
    Some(CodeSec(funcs)) => {
      let mut has_payload_br = false
      let mut has_payload_br_if = false
      let mut has_payload_br_table = false
      let mut has_multivalue_block = false
      let mut has_i32_result_loop = false
      let mut has_nested_return = false
      for func in funcs {
        let Func(_, Expr(instrs)) = func
        if gen_valid_test_has_i32_payload_br_value_block(instrs) {
          has_payload_br = true
        }
        if gen_valid_test_has_i32_payload_br_if_value_block(instrs) {
          has_payload_br_if = true
        }
        if gen_valid_test_has_i32_payload_br_table_value_block(instrs) {
          has_payload_br_table = true
        }
        if gen_valid_test_has_multivalue_typeidx_block(
            generated.wasm_module,
            instrs,
          ) {
          has_multivalue_block = true
        }
        if gen_valid_test_has_i32_result_loop(instrs) {
          has_i32_result_loop = true
        }
        if gen_valid_test_has_nested_return(instrs) {
          has_nested_return = true
        }
      }
      assert_true(
        has_payload_br,
        msg="typed body generator should emit a value block with a typed br payload",
      )
      assert_true(
        has_payload_br_if,
        msg="typed body generator should emit a value block with br_if payload and fallthrough values",
      )
      assert_true(
        has_payload_br_table,
        msg="typed body generator should emit a value block with br_table payload and matching target arities",
      )
      assert_true(
        has_multivalue_block,
        msg="typed body generator should emit a multi-value TypeIdx block",
      )
      assert_true(
        has_i32_result_loop,
        msg="typed body generator should emit a value-producing loop where block result typing is valid",
      )
      assert_true(
        has_nested_return,
        msg="typed body generator should emit a return from nested control in a return-typed function",
      )
    }
    None => fail("expected generated module to contain code bodies")
  }
}
