///|
test "engine-state GenValid profile family resolves stable singleton names and weights" {
  let expected = [
    (EngineStateScalarControlProfile, "engine-state-scalar-control", 4),
    (EngineStateCallsProfile, "engine-state-calls", 3),
    (EngineStateMemoryProfile, "engine-state-memory", 3),
    (EngineStateTableProfile, "engine-state-table", 2),
    (EngineStateSimdProfile, "engine-state-simd", 2),
    (EngineStateImportsProfile, "engine-state-imports", 2),
    (EngineStateInitializationProfile, "engine-state-initialization", 1),
    (EngineStateTrapProfile, "engine-state-trap", 2),
    (EngineStateMixedProfile, "engine-state-mixed", 1),
  ]
  for item in expected {
    let (profile, name, _) = item
    @debug.assert_eq(gen_valid_profile_name(profile), name)
    match gen_valid_profile_by_name(name) {
      Ok(resolved) => @debug.assert_eq(resolved, profile)
      Err(msg) => fail(msg)
    }
  }
  @debug.assert_eq(
    gen_valid_profile_name(EngineStateAllProfile),
    "engine-state-all",
  )
  assert_true(gen_valid_profile_is_composite(EngineStateAllProfile))
  let members = gen_valid_profile_members(EngineStateAllProfile)
  @debug.assert_eq(members.length(), expected.length())
  for item in expected {
    let (profile, _, weight) = item
    assert_true(members.contains(GenValidProfileMember::new(profile, weight)))
  }
  match gen_valid_profile_by_name("engine-state") {
    Ok(profile) => @debug.assert_eq(profile, EngineStateAllProfile)
    Err(msg) => fail(msg)
  }
}

///|
test "engine-state aggregate realizes one exact weighted cycle every twenty cases" {
  let expected = [
    (EngineStateScalarControlProfile, 4),
    (EngineStateCallsProfile, 3),
    (EngineStateMemoryProfile, 3),
    (EngineStateTableProfile, 2),
    (EngineStateSimdProfile, 2),
    (EngineStateImportsProfile, 2),
    (EngineStateInitializationProfile, 1),
    (EngineStateTrapProfile, 2),
    (EngineStateMixedProfile, 1),
  ]
  for item in expected {
    let (profile, wanted) = item
    let mut actual = 0
    for index in 1..<=20 {
      if gen_valid_profile_leaf_for_case(EngineStateAllProfile, 0xA11UL, index) ==
        profile {
        actual += 1
      }
    }
    @debug.assert_eq(actual, wanted)
  }
}

///|
test "engine-state singleton configs enforce compact deterministic hard budgets" {
  for
    profile in [
      EngineStateScalarControlProfile,
      EngineStateCallsProfile,
      EngineStateMemoryProfile,
      EngineStateTableProfile,
      EngineStateSimdProfile,
      EngineStateImportsProfile,
      EngineStateInitializationProfile,
      EngineStateTrapProfile,
      EngineStateMixedProfile,
    ] {
    let config = GenValidConfig::for_profile(profile)
    assert_true(config.max_defined_funcs >= 4 && config.max_defined_funcs <= 12)
    assert_true(config.max_type_defs <= 12)
    assert_true(config.max_params <= 4)
    assert_true(config.max_results <= 3)
    assert_true(config.max_locals <= 12)
    assert_true(config.max_body_depth <= 5)
    @debug.assert_eq(config.max_instruction_count_budget, Some(512))
    @debug.assert_eq(config.max_module_byte_size_budget, Some(65536))
    assert_false(config.features.allow_relaxed_simd)
    assert_false(config.features.allow_shared_memories)
    assert_false(config.features.allow_atomics)
    assert_false(config.features.allow_memory64)
    assert_false(gen_valid_proposal_feature_enabled(config.features, GcFeature))
    assert_false(
      gen_valid_proposal_feature_enabled(config.features, TailCallsFeature),
    )
    assert_false(
      gen_valid_proposal_feature_enabled(config.features, ExceptionsFeature),
    )
  }
}

///|
fn engine_state_test_generate(
  profile : GenValidProfile,
  seed : UInt64,
) -> GenValidGenerated raise {
  match
    gen_valid_module_result_from_seed(
      seed,
      GenValidConfig::for_profile(profile),
    ) {
    Ok(generated) => generated
    Err(failure) => fail(failure.validation_error_message)
  }
}

///|
fn engine_state_test_name_text(name : Name) -> String {
  let Name(value) = name
  value.to_string()
}

///|
fn engine_state_test_import_name(import_ : Import) -> String {
  let Import(_, field, _) = import_
  engine_state_test_name_text(field)
}

///|
fn engine_state_test_function_import_names(mod_ : Module) -> Array[String] {
  let names : Array[String] = []
  match mod_.import_sec {
    Some(ImportSec(imports)) =>
      for import_ in imports {
        let Import(_, _, extern_type) = import_
        match extern_type {
          FuncExternType(_) =>
            names.push(engine_state_test_import_name(import_))
          _ => ()
        }
      }
    None => ()
  }
  names
}

///|
fn engine_state_test_start_body(mod_ : Module) -> Array[Instruction] raise {
  let import_count = engine_state_test_function_import_names(mod_).length()
  match (mod_.start_sec, mod_.code_sec) {
    (Some(StartSec(FuncIdx(start))), Some(CodeSec(funcs))) => {
      let defined = start.reinterpret_as_int() - import_count
      if defined < 0 || defined >= funcs.length() {
        fail("engine-state start must be a defined function")
      }
      let Func(_, Expr(body)) = funcs[defined]
      body
    }
    _ => fail("engine-state module must have one defined start")
  }
}

///|
fn engine_state_test_has_adjacent_mark(
  instrs : Array[Instruction],
  event : Int,
) -> Bool {
  let mut i = 0
  while i + 1 < instrs.length() {
    match (instrs[i], instrs[i + 1]) {
      (I32Const(I32(value)), Call(FuncIdx(2U))) if value == event => return true
      _ => ()
    }
    i += 1
  }
  false
}

///|
fn engine_state_test_has_reachable_workload_call(mod_ : Module) -> Bool raise {
  let import_count = engine_state_test_function_import_names(mod_).length()
  let start_body = engine_state_test_start_body(mod_)
  for instr in start_body {
    match instr {
      Call(FuncIdx(target)) if target.reinterpret_as_int() >= import_count =>
        return true
      _ => ()
    }
  }
  false
}

///|
fn engine_state_test_has_synthetic_export(
  mod_ : Module,
  kind : String,
  index : UInt,
) -> Bool {
  match mod_.export_sec {
    Some(ExportSec(exports)) =>
      for export_ in exports {
        let Export(name, extern_idx) = export_
        if engine_state_test_name_text(name).starts_with("__fuzz_\{kind}_") {
          match (kind, extern_idx) {
            ("memory", MemExternIdx(MemIdx(actual))) if actual == index =>
              return true
            ("table", TableExternIdx(TableIdx(actual))) if actual == index =>
              return true
            ("global", GlobalExternIdx(GlobalIdx(actual))) if actual == index =>
              return true
            _ => ()
          }
        }
      }
    None => ()
  }
  false
}

///|
fn engine_state_test_resource_counts(mod_ : Module) -> (Int, Int, Int) {
  let mut tables = 0
  let mut memories = 0
  let mut globals = 0
  match mod_.import_sec {
    Some(ImportSec(imports)) =>
      for import_ in imports {
        let Import(_, _, extern_type) = import_
        match extern_type {
          TableExternType(_) => tables += 1
          MemExternType(_) => memories += 1
          GlobalExternType(_) => globals += 1
          _ => ()
        }
      }
    None => ()
  }
  match mod_.table_sec {
    Some(TableSec(items)) => tables += items.length()
    None => ()
  }
  match mod_.mem_sec {
    Some(MemSec(items)) => memories += items.length()
    None => ()
  }
  match mod_.global_sec {
    Some(GlobalSec(items)) => globals += items.length()
    None => ()
  }
  (tables, memories, globals)
}

///|
fn engine_state_test_all_segments_active(mod_ : Module) -> Bool {
  match mod_.data_sec {
    Some(DataSec(datas)) =>
      for data in datas {
        let Data(mode, _) = data
        match mode {
          Active(_, _) => ()
          Passive => return false
        }
      }
    None => ()
  }
  match mod_.elem_sec {
    Some(ElemSec(elems)) =>
      for elem in elems {
        let Elem(mode, _) = elem
        match mode {
          Active(_, _) => ()
          Passive | Declarative => return false
        }
      }
    None => ()
  }
  true
}

///|
test "engine-state success leaves emit deterministic driven observable modules" {
  let profiles = [
    EngineStateScalarControlProfile,
    EngineStateCallsProfile,
    EngineStateMemoryProfile,
    EngineStateTableProfile,
    EngineStateSimdProfile,
    EngineStateImportsProfile,
    EngineStateInitializationProfile,
    EngineStateMixedProfile,
  ]
  for profile in profiles {
    let first = engine_state_test_generate(profile, 0xE651A7EUL)
    let second = engine_state_test_generate(profile, 0xE651A7EUL)
    match validate_module(first.wasm_module) {
      Ok(_) => ()
      Err(err) => fail(validation_error_message(err))
    }
    @debug.assert_eq(
      @binary.encode_module(first.wasm_module),
      @binary.encode_module(second.wasm_module),
    )
    @debug.assert_eq(
      engine_state_test_function_import_names(first.wasm_module),
      ["input_i32", "input_i64", "mark", "observe_i32", "observe_i64"],
    )
    assert_true(
      engine_state_test_has_reachable_workload_call(first.wasm_module),
    )
    assert_true(
      engine_state_test_has_adjacent_mark(
        engine_state_test_start_body(first.wasm_module),
        0x7fffffff,
      ),
      msg="successful engine-state start must emit completion marker",
    )
    assert_true(engine_state_test_all_segments_active(first.wasm_module))
    let bytes = match @binary.encode_module(first.wasm_module) {
      Ok(value) => value
      Err(err) => fail("\{err}")
    }
    assert_true(bytes.length() <= 65536)
    let (tables, memories, globals) = engine_state_test_resource_counts(
      first.wasm_module,
    )
    for index in 0..<tables {
      assert_true(
        engine_state_test_has_synthetic_export(
          first.wasm_module,
          "table",
          index.reinterpret_as_uint(),
        ),
      )
    }
    for index in 0..<memories {
      assert_true(
        engine_state_test_has_synthetic_export(
          first.wasm_module,
          "memory",
          index.reinterpret_as_uint(),
        ),
      )
    }
    for index in 0..<globals {
      assert_true(
        engine_state_test_has_synthetic_export(
          first.wasm_module,
          "global",
          index.reinterpret_as_uint(),
        ),
      )
    }
  }
}

///|
test "engine-state scalar and calls leaves execute float and multi-value results" {
  let scalar = engine_state_test_generate(
    EngineStateScalarControlProfile,
    0xF10A7UL,
  )
  let scalar_start = engine_state_test_start_body(scalar.wasm_module)
  assert_true(scalar_start.contains(Instruction::i32_reinterpret_f32()))
  assert_true(scalar_start.contains(Instruction::i64_reinterpret_f64()))
  assert_true(
    scalar_start.any(fn(instr) { instr == Instruction::call(FuncIdx::new(8U)) }),
  )
  let calls = engine_state_test_generate(EngineStateCallsProfile, 0xCA115UL)
  let calls_start = engine_state_test_start_body(calls.wasm_module)
  assert_true(
    calls_start.any(fn(instr) { instr == Instruction::call(FuncIdx::new(8U)) }),
  )
  assert_true(calls_start.contains(Instruction::i32_reinterpret_f32()))
  assert_true(calls_start.contains(Instruction::i64_reinterpret_f64()))
}

///|
test "engine-state trap leaf emits an observable prefix and one intended frontier" {
  for seed in 0UL..<6UL {
    let generated = engine_state_test_generate(EngineStateTrapProfile, seed)
    match validate_module(generated.wasm_module) {
      Ok(_) => ()
      Err(err) => fail(validation_error_message(err))
    }
    @debug.assert_eq(
      engine_state_test_function_import_names(generated.wasm_module),
      ["input_i32", "input_i64", "mark", "observe_i32", "observe_i64"],
    )
    let start = engine_state_test_start_body(generated.wasm_module)
    assert_true(engine_state_test_has_adjacent_mark(start, 0x70000000))
    assert_false(engine_state_test_has_adjacent_mark(start, 0x7fffffff))
    assert_true(
      engine_state_test_has_reachable_workload_call(generated.wasm_module),
    )
    let (tables, memories, globals) = engine_state_test_resource_counts(
      generated.wasm_module,
    )
    assert_true(tables > 0 && memories > 0 && globals > 0)
  }
}
