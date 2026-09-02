///|
test "engine-state GenValid profile family resolves stable singleton names and weights" {
  let expected = [
    (EngineStateScalarControlProfile, "engine-state-scalar-control", 3),
    (EngineStateCallsProfile, "engine-state-calls", 2),
    (EngineStateMemoryProfile, "engine-state-memory", 2),
    (EngineStateTableProfile, "engine-state-table", 1),
    (EngineStateSimdProfile, "engine-state-simd", 1),
    (EngineStateImportsProfile, "engine-state-imports", 2),
    (EngineStateInitializationProfile, "engine-state-initialization", 1),
    (EngineStateTrapProfile, "engine-state-trap", 2),
    (EngineStateMixedProfile, "engine-state-mixed", 2),
    (EngineStateTopologyProfile, "engine-state-topology", 4),
    (EngineStateEffectsProfile, "engine-state-effects", 4),
    (EngineStateResourcesProfile, "engine-state-resources", 4),
    (EngineStateBoundariesProfile, "engine-state-boundaries", 3),
    (EngineStateOptimizerShapesProfile, "engine-state-optimizer-shapes", 3),
    (
      EngineStateEquivalentFamiliesProfile,
      "engine-state-equivalent-families",
      6,
    ),
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
test "engine-state aggregate realizes one exact weighted cycle every forty cases" {
  let expected = [
    (EngineStateScalarControlProfile, 3),
    (EngineStateCallsProfile, 2),
    (EngineStateMemoryProfile, 2),
    (EngineStateTableProfile, 1),
    (EngineStateSimdProfile, 1),
    (EngineStateImportsProfile, 2),
    (EngineStateInitializationProfile, 1),
    (EngineStateTrapProfile, 2),
    (EngineStateMixedProfile, 2),
    (EngineStateTopologyProfile, 4),
    (EngineStateEffectsProfile, 4),
    (EngineStateResourcesProfile, 4),
    (EngineStateBoundariesProfile, 3),
    (EngineStateOptimizerShapesProfile, 3),
    (EngineStateEquivalentFamiliesProfile, 6),
  ]
  for item in expected {
    let (profile, wanted) = item
    let mut actual = 0
    for index in 1..<=40 {
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
      EngineStateTopologyProfile,
      EngineStateEffectsProfile,
      EngineStateResourcesProfile,
      EngineStateBoundariesProfile,
      EngineStateOptimizerShapesProfile,
      EngineStateEquivalentFamiliesProfile,
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
fn engine_state_test_defined_body(
  mod_ : Module,
  index : Int,
) -> Array[Instruction] raise {
  match mod_.code_sec {
    Some(CodeSec(funcs)) if index >= 0 && index < funcs.length() => {
      let Func(_, Expr(body)) = funcs[index]
      body
    }
    _ => fail("engine-state defined function index is out of range")
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
    EngineStateTopologyProfile,
    EngineStateEffectsProfile,
    EngineStateResourcesProfile,
    EngineStateBoundariesProfile,
    EngineStateOptimizerShapesProfile,
    EngineStateEquivalentFamiliesProfile,
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

///|
test "engine-state topology and effects leaves force relational execution shapes" {
  let topology = engine_state_test_generate(EngineStateTopologyProfile, 0UL)
  let diamond = engine_state_test_defined_body(topology.wasm_module, 4)
  assert_true(diamond.contains(Instruction::call(FuncIdx::new(6U))))
  assert_true(diamond.contains(Instruction::call(FuncIdx::new(7U))))
  assert_true(diamond.contains(Instruction::call(FuncIdx::new(8U))))
  let dispatch = engine_state_test_defined_body(topology.wasm_module, 3)
  assert_true(
    dispatch.contains(
      Instruction::call_indirect(TypeIdx::new(7U), TableIdx::new(0U)),
    ),
  )

  let left_merge = engine_state_test_defined_body(
    gen_valid_engine_state_effects_module(0UL),
    2,
  )
  let right_merge = engine_state_test_defined_body(
    gen_valid_engine_state_effects_module(8UL),
    2,
  )
  @debug.assert_eq(left_merge[1], Instruction::call(FuncIdx::new(5U)))
  @debug.assert_eq(right_merge[1], Instruction::call(FuncIdx::new(6U)))
}

///|
test "engine-state resources and boundaries leaves force lifecycle and edge shapes" {
  let resources = engine_state_test_generate(EngineStateResourcesProfile, 0UL)
  let copy = engine_state_test_defined_body(resources.wasm_module, 3)
  assert_true(
    copy.contains(Instruction::memory_copy(MemIdx::new(0U), MemIdx::new(0U))),
  )
  assert_true(
    copy.contains(Instruction::table_copy(TableIdx::new(0U), TableIdx::new(0U))),
  )
  match (resources.wasm_module.data_sec, resources.wasm_module.elem_sec) {
    (Some(DataSec(datas)), Some(ElemSec(elems))) => {
      @debug.assert_eq(datas.length(), 2)
      @debug.assert_eq(elems.length(), 2)
    }
    _ => fail("resource lifecycle leaf must contain overlapping segments")
  }

  let boundaries = engine_state_test_generate(EngineStateBoundariesProfile, 0UL)
  let memory = engine_state_test_defined_body(boundaries.wasm_module, 1)
  assert_true(
    memory.contains(
      Instruction::i32_store16(gen_valid_engine_state_memarg(0U, 0UL)),
    ),
  )
  assert_true(
    memory.contains(
      Instruction::i32_load(gen_valid_engine_state_memarg(2U, 0UL)),
    ),
  )
}

///|
test "engine-state diversity leaves accept every forced seed slot without retry bias" {
  let profiles = [
    EngineStateTopologyProfile,
    EngineStateEffectsProfile,
    EngineStateResourcesProfile,
    EngineStateBoundariesProfile,
    EngineStateOptimizerShapesProfile,
    EngineStateEquivalentFamiliesProfile,
  ]
  let seeds = [
    0UL, 8UL, 32UL, 64UL, 128UL, 192UL, 1024UL, 2048UL, 3072UL, 4096UL, 6144UL,
  ]
  for profile in profiles {
    for seed in seeds {
      let generated = engine_state_test_generate(profile, seed)
      @debug.assert_eq(generated.attempts, 1)
    }
  }
}

///|
test "engine-state optimizer and equivalent leaves rotate forced structural variants" {
  let optimizer_local = engine_state_test_defined_body(
    gen_valid_engine_state_optimizer_shapes_module(0UL),
    2,
  )
  let optimizer_block = engine_state_test_defined_body(
    gen_valid_engine_state_optimizer_shapes_module(64UL),
    2,
  )
  let optimizer_drop = engine_state_test_defined_body(
    gen_valid_engine_state_optimizer_shapes_module(128UL),
    2,
  )
  let optimizer_if = engine_state_test_defined_body(
    gen_valid_engine_state_optimizer_shapes_module(192UL),
    2,
  )
  assert_true(
    optimizer_local.contains(Instruction::local_set(LocalIdx::new(1U))),
  )
  assert_true(optimizer_block.any(fn(instr) { instr is Block(_, _) }))
  let mut has_dropped_constant = false
  for i in 0..<(optimizer_drop.length() - 1) {
    match (optimizer_drop[i], optimizer_drop[i + 1]) {
      (I32Const(_), Drop) => has_dropped_constant = true
      _ => ()
    }
  }
  assert_true(has_dropped_constant)
  assert_true(optimizer_if.any(fn(instr) { instr is If(_, _, _) }))

  let equivalent_sub = engine_state_test_defined_body(
    gen_valid_engine_state_equivalent_families_module(0UL),
    1,
  )
  let equivalent_block = engine_state_test_defined_body(
    gen_valid_engine_state_equivalent_families_module(1024UL),
    1,
  )
  let equivalent_if = engine_state_test_defined_body(
    gen_valid_engine_state_equivalent_families_module(2048UL),
    1,
  )
  let equivalent_local = engine_state_test_defined_body(
    gen_valid_engine_state_equivalent_families_module(3072UL),
    1,
  )
  assert_true(equivalent_sub.contains(Instruction::i32_sub()))
  assert_true(equivalent_block.any(fn(instr) { instr is Block(_, _) }))
  assert_true(equivalent_if.any(fn(instr) { instr is If(_, _, _) }))
  assert_true(
    equivalent_local.contains(Instruction::local_set(LocalIdx::new(1U))),
  )
}
