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
      for func in funcs {
        let Func(_, Expr(instrs)) = func
        if gen_valid_test_has_i32_payload_br_value_block(instrs) {
          has_payload_br = true
        }
      }
      assert_true(
        has_payload_br,
        msg="typed body generator should emit a value block with a typed br payload",
      )
    }
    None => fail("expected generated module to contain code bodies")
  }
}
